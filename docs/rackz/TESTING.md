# Rackz — Local Testing Guide

## Prerequisites

```bash
# Configure (only needed once)
mkdir -p build/release
cmake -S . -B build/release -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTS=OFF

# Build daemon and wallet
make -C build/release -j$(nproc) daemon simplewallet
```

Binaries land in `build/release/bin/`:

- `rackzd` — daemon
- `rackz-wallet-cli` — CLI wallet

---

## Create a wallet

Always create the wallet **before** starting the daemon, so you have an address to mine to.

```bash
# Stagenet wallet
./build/release/bin/rackz-wallet-cli --stagenet --generate-new-wallet ~/rackz-stagenet.wallet
```

The CLI will prompt for:

1. A wallet password (can be empty for testing)
2. A language for the seed phrase (choose English)

It prints your address on creation — it starts with `S` for stagenet (`T` for testnet, `R` for mainnet).
Copy that address; you'll pass it to `--start-mining` below.

To open an existing wallet later:

```bash
./build/release/bin/rackz-wallet-cli --stagenet --wallet-file ~/rackz-stagenet.wallet
```

Useful wallet commands once inside the CLI:

```
balance          # show balance
address          # show your address again
refresh          # sync with daemon
help             # full command list
exit             # quit
```

---

## Option A — Single-node stagenet (quickest, self-contained)

Run one local node in stagenet mode. No peers needed; it mines to itself.

```bash
# Terminal 1 — start the daemon
#   --offline             = no P2P (silences peer-seeking logs)
#   --fixed-difficulty 1  = keep difficulty at 1 (otherwise it shoots to 7260+
#                           after the first few fast blocks and 1 thread cant keep up)
./build/release/bin/rackzd --stagenet --log-level 1 --non-interactive --offline --fixed-difficulty 1

# Terminal 2 — start mining via HTTP RPC endpoint (replace <your-address>)
curl -s http://127.0.0.1:42760/start_mining \
  -d '{"miner_address":"<your-address>","threads_count":1,"do_background_mining":false,"ignore_battery":true}' \
  -H 'Content-Type: application/json'

# Terminal 3 — open the wallet to watch balances
./build/release/bin/rackz-wallet-cli --stagenet --wallet-file ~/rackz-stagenet.wallet
```

> **Why `/start_mining` and not `/json_rpc`?** `start_mining` is a plain HTTP endpoint, not a JSON-RPC method. Calling `/json_rpc` with `"method":"start_mining"` returns `"Method not found"`.
>
> **Why `--offline`?** Without it, the daemon endlessly tries to find peers and prints `Failed to connect to any, trying seeds`. `--offline` disables P2P entirely — perfect for solo testing. Mining and wallet RPC still work normally.

Stagenet ports: P2P `42759`, RPC `42760`.

Data directory: `~/.rackz/stagenet/`

### Gotchas

| Symptom | Cause | Fix |
|---|---|---|
| `"Method not found"` from `/json_rpc` | `start_mining` is a plain HTTP endpoint, not JSON-RPC. | Use `curl … /start_mining` with a plain JSON body (no `jsonrpc`/`method` wrapper). |
| Miner finds blocks then stops | Difficulty retargeted to 7260+ after the first few fast blocks. 1 RandomX thread cannot keep up. | Restart daemon with `--fixed-difficulty 1`. |
| Endless `Failed to connect to any, trying seeds` | Daemon is looking for peers that don't exist. | Restart daemon with `--offline` (disables P2P entirely; RPC still works). |
| Wallet refresh error: *reorg exceeds maximum allowed depth* | Wallet was created/opened against an older/higher daemon, so its cached `refresh-from-block-height` is above the current chain tip. | In the wallet CLI: `set refresh-from-block-height 0` then `refresh`. |
| `Balance: 0` even though blocks were found | Mining rewards were sent to a different address than the wallet's. Check with `address` in the wallet. | Stop mining (`/stop_mining`), then restart with the wallet's actual address. |
| `unlocked balance: 0` | Coinbase rewards are locked for ~60 blocks (consensus maturity rule). | Wait; run `balance` periodically. The wallet shows `N block(s) to unlock`. |

---

## Option B — Two nodes (local machine + Raspberry Pi)

### Raspberry Pi (seed/peer node)

```bash
# On the Pi — build first (ARM, same cmake steps)
./build/release/bin/rackzd \
  --stagenet \
  --no-igd \
  --log-level 1 \
  --p2p-bind-ip 0.0.0.0 \
  --non-interactive
```

Note the Pi's local IP (e.g. `192.168.1.50`).

### Local machine (your node)

```bash
./build/release/bin/rackzd \
  --stagenet \
  --add-exclusive-node 192.168.1.50:42759 \
  --log-level 1 \
  --non-interactive
```

The `--add-exclusive-node` flag connects your node directly to the Pi, bypassing DNS seed lookup (which is disabled for Rackz anyway).

---

## Option C — Testnet (same steps, different flag)

Replace `--stagenet` with `--testnet` everywhere.

Testnet ports: P2P `32759`, RPC `32760`.
Data directory: `~/.rackz/testnet/`

---

## Verify Rackz branding

```bash
./build/release/bin/rackzd --version
# Expected: Rackz 'Nibiru' (v0.1.0.0-...)

./build/release/bin/rackzd --help | head -3
# Expected: Rackz 'Nibiru' ...
```

---

## Mine a block manually (stagenet)

```bash
# RPC call to start mining to an address
curl -s http://127.0.0.1:42760/json_rpc -d '{
  "jsonrpc":"2.0","id":"0","method":"start_mining",
  "params":{"do_background_mining":false,"ignore_battery":true,
            "miner_address":"<your-stagenet-address>","threads_count":1}
}' -H 'Content-Type: application/json'
```

---

## Key network parameters

|                | Mainnet     | Testnet             | Stagenet             |
| -------------- | ----------- | ------------------- | -------------------- |
| P2P port       | 22759       | 32759               | 42759                |
| RPC port       | 22760       | 32760               | 42760                |
| Address prefix | `Rx`        | `Tx`                | `Sx`                 |
| Data dir       | `~/.rackz/` | `~/.rackz/testnet/` | `~/.rackz/stagenet/` |

---

## Known limitations (pre-mainnet)

- No public seed nodes exist yet — use `--add-exclusive-node` for multi-node testing.
- Genesis TX is a burn tx (unspendable); all spendable coins come from mining.
- Mainnet genesis timestamp is `0` (placeholder); set to launch date before mainnet.
