# Rackz Fork Configuration Reference

This document catalogues every location in the codebase that must change to
transform upstream Monero into a distinct Rackz network, explains **why** each
change is required, and flags suggested improvements beyond simple renaming.

> **Status of `docs/rackz/CRYPTO_NOTE_EDIT.md`**: That file is a generic
> CryptoNote 1.x forking guide written before Monero diverged significantly.
> It still conveys the right _concepts_ (name, emission, ports, address prefix,
> genesis block) but the paths, struct names, and CMake targets it references are
> **wrong for this codebase**. Use this document instead; retire the old one.

---

## Upstream Remote

```bash
# Already added:
git remote add upstream https://github.com/monero-project/monero

# Fetch upstream tags for cherry-pick reference:
git fetch upstream --tags
```

To cherry-pick a Monero fix: `git cherry-pick <hash>`, then record it in
`CHANGELOG.md` under `### Upstream Sync`.

---

## Change Categories

| Priority | Category                | Red-zone? | Notes                                                  |
| -------- | ----------------------- | --------- | ------------------------------------------------------ |
| **P0**   | Network identity        | Yes       | Must change — nodes will join Monero mainnet otherwise |
| **P0**   | Binary names            | No        | User-visible immediately on install                    |
| **P1**   | Hardfork schedule       | Yes       | Must define a Rackz-native fork history                |
| **P1**   | Wallet file magic       | No        | Prevents accidental cross-chain key file use           |
| **P1**   | URI scheme & unit names | No        | User-facing wallet UX                                  |
| **P2**   | Version/release name    | No        | Branding; affects `--version` output                   |
| **P2**   | Daemon display strings  | No        | Startup banners, help text                             |
| **P2**   | DNS infrastructure      | No        | Checkpoint and update URLs                             |
| **P3**   | Environment variables   | No        | `MONERO_LOGS` → `RACKZ_LOGS`                           |
| **P3**   | Data directory          | Automatic | Derives from `CRYPTONOTE_NAME`                         |

---

## P0 — Network Identity

> **Red-zone.** Requires `export RACKZ_AI_CRYPTO_GATE=1` to unlock AI writes,
> and a `cryptonote_config.h:` commit prefix. Human review mandatory.

### `src/cryptonote_config.h`

#### Coin name and data-dir root

```cpp
// Current (Monero):
#define CRYPTONOTE_NAME  "bitmonero"

// Change to:
#define CRYPTONOTE_NAME  "rackz"
```

This single constant drives:

- Default data directory: `~/.rackz/` (Unix) / `%APPDATA%\rackz\` (Windows)
- Default config file name: `rackz.conf`
- Default log file name: `rackz.log`

No other file needs editing for the data-dir path — `src/common/util.cpp`
`get_default_data_dir()` constructs it from `CRYPTONOTE_NAME` at runtime.

#### Address prefixes

The Base58 prefix determines the leading character(s) of all wallet addresses.
Current Monero mainnet values give addresses starting with **"4"**.

Use the [CryptoNote prefix generator](https://cryptonotestarter.org/tools.html)
to select a prefix that gives Rackz addresses a recognisable starting character.

```cpp
namespace config
{
  // Current Monero mainnet — addresses start with "4"
  uint64_t const CRYPTONOTE_PUBLIC_ADDRESS_BASE58_PREFIX             = 18;
  uint64_t const CRYPTONOTE_PUBLIC_INTEGRATED_ADDRESS_BASE58_PREFIX  = 19;
  uint64_t const CRYPTONOTE_PUBLIC_SUBADDRESS_BASE58_PREFIX          = 42;

  // CONFIRMED Rackz mainnet — prefix 0x1415 = 5141; addresses start with "Rx"
  uint64_t const CRYPTONOTE_PUBLIC_ADDRESS_BASE58_PREFIX             = 5141;  // "Rx..." CONFIRMED
  uint64_t const CRYPTONOTE_PUBLIC_INTEGRATED_ADDRESS_BASE58_PREFIX  = 5142;  // verify with prefix tool
  uint64_t const CRYPTONOTE_PUBLIC_SUBADDRESS_BASE58_PREFIX          = 5143;  // verify with prefix tool

  // Testnet and stagenet prefixes must not collide with mainnet.
  // Recommend selecting values that produce a visually distinct first character
  // (e.g. "T..." for testnet, "S..." for stagenet) — verify with:
  //   https://cryptonotestarter.org/tools.html
  namespace testnet  { uint64_t const CRYPTONOTE_PUBLIC_ADDRESS_BASE58_PREFIX = 5153; } // TBD
  namespace stagenet { uint64_t const CRYPTONOTE_PUBLIC_ADDRESS_BASE58_PREFIX = 5163; } // TBD
}
```

#### Network ID (UUID)

**Most critical change.** If unchanged, Rackz nodes will handshake with and
attempt to connect to live Monero peers.

```cpp
namespace config
{
  // Current Monero mainnet (REPLACE):
  boost::uuids::uuid const NETWORK_ID = { {
      0x12, 0x30, 0xF1, 0x71, 0x61, 0x04, 0x41, 0x61,
      0x17, 0x31, 0x00, 0x82, 0x16, 0xA1, 0xA1, 0x10
  } };

  // CONFIRMED Rackz mainnet (cryptographically random):
  boost::uuids::uuid const NETWORK_ID = { {
      0x4C, 0x68, 0x28, 0x1A, 0x6B, 0x8C, 0xF3, 0x24,
      0x90, 0x41, 0x53, 0x63, 0xDF, 0xD1, 0xD5, 0x39
  } };

  namespace testnet
  {
    // CONFIRMED Rackz testnet (cryptographically random):
    boost::uuids::uuid const NETWORK_ID = { {
        0x0E, 0x41, 0xE8, 0x13, 0xA4, 0xBE, 0xAC, 0x8F,
        0x96, 0x24, 0xAF, 0x1B, 0xB4, 0xBF, 0xCC, 0xF2
    } };
  }

  namespace stagenet
  {
    // CONFIRMED Rackz stagenet (cryptographically random):
    boost::uuids::uuid const NETWORK_ID = { {
        0xD2, 0x0F, 0xE9, 0xE6, 0x4F, 0x70, 0xF8, 0xCD,
        0xD3, 0x0F, 0x0B, 0x56, 0x55, 0x6B, 0x28, 0x82
    } };
  }
}
```

#### Ports

Monero mainnet uses 18080–18082. Choose a unique range to avoid conflicts.
See https://www.iana.org/assignments/service-names-port-numbers/ for free ranges.

```cpp
namespace config
{
  // Current Monero:
  uint16_t const P2P_DEFAULT_PORT     = 18080;
  uint16_t const RPC_DEFAULT_PORT     = 18081;
  uint16_t const ZMQ_RPC_DEFAULT_PORT = 18082;

  // CONFIRMED Rackz — "RACK" on phone keypad = 7225
  // ("RACKZ" = 72259 exceeds max port 65535; RACK = 7225 is used as the base)
  uint16_t const P2P_DEFAULT_PORT     = 7225;
  uint16_t const RPC_DEFAULT_PORT     = 7226;
  uint16_t const ZMQ_RPC_DEFAULT_PORT = 7227;

  namespace testnet  { uint16_t const P2P_DEFAULT_PORT = 17225; uint16_t const RPC_DEFAULT_PORT = 17226; uint16_t const ZMQ_RPC_DEFAULT_PORT = 17227; }
  namespace stagenet { uint16_t const P2P_DEFAULT_PORT = 27225; uint16_t const RPC_DEFAULT_PORT = 27226; uint16_t const ZMQ_RPC_DEFAULT_PORT = 27227; }
}
```

#### Genesis block

The genesis transaction and nonce must be regenerated for a new chain:

1. Set `GENESIS_TX = ""` and any placeholder nonce
2. Build the daemon
3. Run `./rackzd --print-genesis-tx` to generate the genesis coinbase
4. Copy the printed hex back into `GENESIS_TX`
5. Recompile

```cpp
namespace config
{
  // Current Monero genesis — MUST be replaced:
  std::string const GENESIS_TX    = "013c01ff0001ffffffffffff...";
  uint32_t    const GENESIS_NONCE = 10000;
}
```

#### Message signing domain separator

```cpp
// Current — cross-chain message replay is possible with Monero keys:
const char HASH_KEY_MESSAGE_SIGNING[] = "MoneroMessageSignature";

// Change to prevent Monero-signed messages being valid on Rackz:
const char HASH_KEY_MESSAGE_SIGNING[] = "RackzMessageSignature";
```

> **Note:** Do NOT change `HASH_KEY_BULLETPROOF_EXPONENT`, `HASH_KEY_RINGDB`,
> `HASH_KEY_SUBADDRESS`, `HASH_KEY_CLSAG_ROUND`, or any other cryptographic
> domain separator. These are part of the RingCT/Bulletproof protocol; changing
> them invalidates proofs and is a consensus-breaking cryptographic modification.

#### Fee placeholder

```cpp
// This comment is in the upstream source — it genuinely needs a decision:
uint64_t const DEFAULT_FEE_ATOMIC_XMR_PER_KB = 500; // Just a placeholder!  Change me!
```

---

## P0 — Binary Names

> **Not red-zone.** These are `CMakeLists.txt` files; edit freely.

| File                                      | Current `OUTPUT_NAME`                      | Suggested Rackz name                      |
| ----------------------------------------- | ------------------------------------------ | ----------------------------------------- |
| `src/daemon/CMakeLists.txt`               | `monerod`                                  | `rackzd`                                  |
| `src/simplewallet/CMakeLists.txt`         | `monero-wallet-cli`                        | `rackz-wallet-cli`                        |
| `src/wallet/CMakeLists.txt`               | `monero-wallet-rpc`                        | `rackz-wallet-rpc`                        |
| `src/gen_multisig/CMakeLists.txt`         | `monero-gen-trusted-multisig`              | `rackz-gen-trusted-multisig`              |
| `src/gen_ssl_cert/CMakeLists.txt`         | `monero-gen-ssl-cert`                      | `rackz-gen-ssl-cert`                      |
| `src/blockchain_utilities/CMakeLists.txt` | `monero-blockchain-import`                 | `rackz-blockchain-import`                 |
|                                           | `monero-blockchain-export`                 | `rackz-blockchain-export`                 |
|                                           | `monero-blockchain-mark-spent-outputs`     | `rackz-blockchain-mark-spent-outputs`     |
|                                           | `monero-blockchain-usage`                  | `rackz-blockchain-usage`                  |
|                                           | `monero-blockchain-ancestry`               | `rackz-blockchain-ancestry`               |
|                                           | `monero-blockchain-depth`                  | `rackz-blockchain-depth`                  |
|                                           | `monero-blockchain-stats`                  | `rackz-blockchain-stats`                  |
|                                           | `monero-blockchain-prune-known-spent-data` | `rackz-blockchain-prune-known-spent-data` |
|                                           | `monero-blockchain-prune`                  | `rackz-blockchain-prune`                  |
| `src/debug_utilities/CMakeLists.txt`      | `monero-utils-deserialize`                 | `rackz-utils-deserialize`                 |
|                                           | `monero-utils-object-sizes`                | `rackz-utils-object-sizes`                |
|                                           | `monero-utils-dns-checks`                  | `rackz-utils-dns-checks`                  |

---

## P1 — Hardfork Schedule

> **Red-zone.** `src/hardforks/hardforks.cpp` and `src/hardforks/hardforks.h`.

Current content: the full Monero mainnet fork history from block 1 (2014) through
v16 (2022). For a new Rackz chain starting from block 1:

```cpp
// Minimal fresh-start hardforks — inherit all Monero protocol improvements
// from day one by enabling the latest version immediately.
const hardfork_t mainnet_hard_forks[] = {
  { 1,  1, 0, <rackz_launch_timestamp> },
  { 16, 2, 0, <rackz_launch_timestamp> + 1 },
};
```

> If Rackz is starting from a Monero chain **snapshot** (inheriting existing
> balances), the existing fork heights must be preserved exactly. Discuss this
> decision separately — it is a consensus-design choice.

---

## P1 — Wallet File Magic Strings

> **Yellow-zone.** `src/wallet/wallet2.cpp`. Run wallet tests after changing.

These string constants are embedded in wallet files to identify their type.
Keeping Monero's strings means a Rackz wallet binary can silently open a Monero
wallet file — a key-safety risk.

```cpp
// src/wallet/wallet2.cpp — current Monero values:
#define UNSIGNED_TX_PREFIX              "Monero unsigned tx set\005"
#define SIGNED_TX_PREFIX                "Monero signed tx set\005"
#define MULTISIG_UNSIGNED_TX_PREFIX     "Monero multisig unsigned tx set\001"
#define KEY_IMAGE_EXPORT_FILE_MAGIC     "Monero key image export\003"
#define MULTISIG_EXPORT_FILE_MAGIC      "Monero multisig export\001"
#define OUTPUT_EXPORT_FILE_MAGIC        "Monero output export\004"
static const std::string ASCII_OUTPUT_MAGIC = "MoneroAsciiDataV1";

// Change to (keep version bytes unchanged — they carry format semantics):
#define UNSIGNED_TX_PREFIX              "Rackz unsigned tx set\005"
#define SIGNED_TX_PREFIX                "Rackz signed tx set\005"
#define MULTISIG_UNSIGNED_TX_PREFIX     "Rackz multisig unsigned tx set\001"
#define KEY_IMAGE_EXPORT_FILE_MAGIC     "Rackz key image export\003"
#define MULTISIG_EXPORT_FILE_MAGIC      "Rackz multisig export\001"
#define OUTPUT_EXPORT_FILE_MAGIC        "Rackz output export\004"
static const std::string ASCII_OUTPUT_MAGIC = "RackzAsciiDataV1";
```

---

## P1 — URI Scheme and Denomination Names

> **Yellow-zone.** `src/wallet/wallet2.cpp` (URI) and
> `src/simplewallet/simplewallet.cpp` (unit names).

#### URI scheme

```cpp
// wallet2.cpp — current:
std::string uri = "monero:" + address;
if (uri.substr(0, 7) != "monero:") { error = ...; }

// Change to:
std::string uri = "rackz:" + address;
if (uri.substr(0, 6) != "rackz:") { error = ...; }
```

Register `rackz:` with IANA if the project goes public.

#### Denomination names

```cpp
// simplewallet.cpp — current set_unit() handler:
if (unit == "monero")       decimal_point = 12;
else if (unit == "millinero")  decimal_point = 9;
else if (unit == "micronero")  decimal_point = 6;
else if (unit == "nanonero")   decimal_point = 3;
else if (unit == "piconero")   decimal_point = 0;

// Suggested Rackz equivalents:
if (unit == "rackz")        decimal_point = 12;
else if (unit == "millirackz") decimal_point = 9;
else if (unit == "microrackz") decimal_point = 6;
else if (unit == "nanorackz")  decimal_point = 3;
else if (unit == "picorackz")  decimal_point = 0;
```

Also update the QR address URI scheme in `simplewallet.cpp`:

```cpp
// Current:
const std::string address = "monero:" + m_wallet->get_subaddress_as_str(...);
// Change to:
const std::string address = "rackz:" + m_wallet->get_subaddress_as_str(...);
```

---

## P2 — Version and Release Name

> **Not red-zone.** `src/version.cpp.in` and `src/version.h`.

```cpp
// src/version.cpp.in — current:
#define DEF_MONERO_VERSION          "0.18.1.0"
#define DEF_MONERO_RELEASE_NAME     "Fluorine Fermi"

// CONFIRMED Rackz:
#define DEF_MONERO_VERSION          "0.1.0.0"  // pre-release / testnet phase
#define DEF_MONERO_RELEASE_NAME     "Nibiru"   // v0.1 codename
// v1.0.0.0 "Anu" is reserved for mainnet launch
```

> **Codename convention** — Anunnaki / UAP / Nibiru lore, in planned order:
> `Nibiru` (v0.1 testnet) → `Anu` (v1.0 mainnet launch) → `Enki` → `Enlil`
> → `Inanna` → `Marduk` → `Ninhursag` → `Apkallu` ...

> The variable names (`MONERO_VERSION`, `MONERO_RELEASE_NAME`) appear in
> hundreds of source files via `src/version.h`. Renaming them to `RACKZ_*` is
> cosmetically desirable but touches ~30 call sites. Recommended approach:
> rename `version.h` declarations to `RACKZ_VERSION` etc. and do a single
> targeted sed pass. Defer until after core network changes are working.

---

## P2 — Daemon Display Strings

> **Yellow-zone / not red-zone.**

| File                                  | Change                                                                                                                    |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `src/daemon/executor.cpp`             | `t_executor::NAME = "Monero Daemon"` → `"Rackz Daemon"`                                                                   |
| `src/daemon/command_line_args.h`      | `WINDOWS_SERVICE_NAME = "Monero Daemon"` → `"Rackz Daemon"`                                                               |
| `src/daemon/rpc_command_executor.cpp` | `"monero daily"` / `"monero monthly"` mining output strings                                                               |
| `src/daemonizer/posix_fork.cpp`       | `"/bitmonero.daemon.stdout.stderr"` → `"/rackz.daemon.stdout.stderr"`                                                     |
| `src/simplewallet/simplewallet.cpp`   | Welcome/help strings: all `"Monero"` / `"monero"` occurrences; unit names `monero/millinero/...`; QR URI scheme `monero:` |
| `src/wallet/wallet_args.cpp`          | `"This is the command line monero wallet..."` help text; `getenv("MONERO_LOGS")`                                          |
| `src/wallet/wallet_rpc_server.cpp`    | Usage string: `"monero-wallet-rpc [--wallet-file=...]"` → `"rackz-wallet-rpc [...]"`                                      |
| `src/gen_multisig/gen_multisig.cpp`   | Usage string: `"monero-gen-multisig [...]"` → `"rackz-gen-multisig [...]"`                                                |

Startup banners (`"Monero 'Fluorine Fermi' (v0.18.1.0)"`) will update automatically
once `DEF_MONERO_RELEASE_NAME` and `DEF_MONERO_VERSION` are changed.

---

## P2 — DNS Infrastructure

> **Not red-zone.** Disable or replace; leaving Monero's URLs active means
> Rackz nodes will query Monero's DNS for checkpoints and updates — wrong data.

#### Seed nodes — `src/p2p/net_node.h`

```cpp
// Current Monero seed nodes:
const std::vector<std::string> m_seed_nodes_list =
{ "seeds.moneroseeds.se"
, "seeds.moneroseeds.ae.org"
, "seeds.moneroseeds.ch"
, "seeds.moneroseeds.li"
};

// Replace with Rackz seed node hostnames, or empty for initial launch:
const std::vector<std::string> m_seed_nodes_list = {};
// Add IP/DNS entries as seed nodes are stood up.
```

#### DNS checkpoints — `src/checkpoints/checkpoints.cpp`

```cpp
// Current — queries Monero's moneropulse infrastructure:
static const std::vector<std::string> dns_urls = {
    "checkpoints.moneropulse.se", "checkpoints.moneropulse.org",
    "checkpoints.moneropulse.net", "checkpoints.moneropulse.co"
};
// Similarly for testnet_dns_urls and stagenet_dns_urls.

// Options:
// a) Replace with rackz-equivalent domains when they exist
// b) Return early / disable DNS checkpoints for initial launch:
//    if (true) return true; // DNS checkpoints disabled
```

#### Software update URLs — `src/common/updates.cpp`

```cpp
// Current — queries Monero's moneropulse and getmonero.org:
static const std::vector<std::string> dns_urls = {
    "updates.moneropulse.org", "updates.moneropulse.net", ...
};
const char *base = user ? "https://downloads.getmonero.org/"
                        : "https://updates.getmonero.org/";

// Replace with Rackz infrastructure or disable:
// Return false early to disable update checks until Rackz infra exists.
```

#### Donate address — `src/simplewallet/simplewallet.h` + `src/simplewallet/simplewallet.cpp`

```cpp
// simplewallet.h — hardcoded Monero donation address (MUST replace before launch):
constexpr const char MONERO_DONATION_ADDR[] = "888tNkZrPN6JsEgekjMnABU4...";
// Generate a Rackz mainnet wallet address and replace this.
// Also rename the constant to RACKZ_DONATION_ADDR and update all 4 call sites
// in simplewallet.cpp that reference MONERO_DONATION_ADDR.

// simplewallet.cpp — donate command help text:
tr("Donate <amount> to the development team (donate.getmonero.org).")
// Change to:
tr("Donate <amount> to the Rackz development team (donate.rackz.io).")

// simplewallet.cpp — donate execution message:
"Donating %s %s to The Monero Project (donate.getmonero.org or %s)."
// Change to:
"Donating %s %s to The Rackz Project (donate.rackz.io or %s)."
```

---

## P3 — Environment Variables and i18n

> **Yellow-zone.** `src/wallet/wallet_args.cpp`.

```cpp
// Current:
const char *logs = getenv("MONERO_LOGS");
i18n_set_language("translations", "monero", lang);

// Change to:
const char *logs = getenv("RACKZ_LOGS");
i18n_set_language("translations", "rackz", lang);
```

The `translations/` directory contains `monero_*.ts` locale files. These should
eventually be renamed to `rackz_*.ts` and updated.

---

## Trezor / Hardware Wallet Files

> **Defer for initial launch.** `src/device_trezor/` contains generated protobuf
> files (`messages-monero.pb.h`, ~773 `monero` references) and protocol code
> deeply tied to Trezor firmware's Monero app. These cannot be renamed without
> coordinating a Trezor firmware update. Leave unchanged until Rackz has a
> hardware wallet strategy.

---

## What NOT to Change

The following look like "Monero" strings but must be left untouched:

| Constant                                        | Location              | Why                                                                  |
| ----------------------------------------------- | --------------------- | -------------------------------------------------------------------- |
| `HASH_KEY_BULLETPROOF_EXPONENT = "bulletproof"` | `cryptonote_config.h` | Cryptographic domain separator used in proof generation/verification |
| `HASH_KEY_BULLETPROOF_PLUS_*`                   | `cryptonote_config.h` | Same — part of the Bulletproof+ protocol                             |
| `HASH_KEY_CLSAG_ROUND`, `HASH_KEY_CLSAG_AGG_*`  | `cryptonote_config.h` | CLSAG signature protocol constants                                   |
| `HASH_KEY_RINGDB = "ringdsb"`                   | `cryptonote_config.h` | Ring output DB domain separator                                      |
| `HASH_KEY_SUBADDRESS = "SubAddr"`               | `cryptonote_config.h` | Subaddress derivation                                                |
| `MONERO_DEFAULT_LOG_CATEGORY` macro             | everywhere            | Internal log routing; cosmetic only, ~500 uses                       |
| `MULTISIG_SIGNATURE_MAGIC = "SigMultisigPkV1"`  | `wallet2.cpp`         | Serialisation format version marker                                  |
| Copyright notices                               | all files             | Legal attribution; keep "The Monero Project" as historical credit    |

---

## Tokenomics Configuration

This section catalogues every monetary, emission, and consensus knob in
`src/cryptonote_config.h`, what each one controls, the actual reward formula,
and the recommended Rackz value with rationale.

### Block Reward Formula (verified in `src/cryptonote_basic/cryptonote_basic_impl.cpp:83`)

```cpp
const int target_minutes = DIFFICULTY_TARGET_V2 / 60;                     // = 2 for 120s blocks
const int emission_speed_factor = EMISSION_SPEED_FACTOR_PER_MINUTE - (target_minutes - 1);  // = 19
uint64_t base_reward = (MONEY_SUPPLY - already_generated_coins) >> emission_speed_factor;
if (base_reward < FINAL_SUBSIDY_PER_MINUTE * target_minutes)              // tail floor kicks in
    base_reward = FINAL_SUBSIDY_PER_MINUTE * target_minutes;
// Then apply the block-size penalty if current_block_weight > median_weight
```

So for the default Monero parameters at 120s blocks:

- **Initial block reward** = `(2^64) >> 19` = `2^45` atomic = `35.18 RKZ`
- **Tail-emission floor** = `0.3 RKZ/min × 2` = `0.6 RKZ/block`
- The tail kicks in once `(MONEY_SUPPLY - circulating) >> 19 < 6e11`, i.e. once
  ~99.997% of the asymptotic supply has been emitted (at ~block 2.55M, ~5.8 years
  from genesis at 120s).

---

### 1. Total Supply Asymptote — `MONEY_SUPPLY`

|                    |                                                                   |
| ------------------ | ----------------------------------------------------------------- |
| **Location**       | `cryptonote_config.h:54`                                          |
| **Current**        | `((uint64_t)(-1))` ≈ `1.844674407e19` atomic = **18,446,744 RKZ** |
| **Recommendation** | **Keep `(uint64_t)(-1)`**                                         |

**Rationale.** This is not a hard cap — it is the asymptote that the base-reward
curve approaches. Once base reward drops below the tail floor, total supply
keeps growing forever via tail emission. Changing this number changes the
**shape** of the bit-shift curve in ways that are hard to reason about (the
shift operates on `MONEY_SUPPLY - already_generated`). Picking a "rounder"
number like `21,000,000 × COIN` gains nothing technically and breaks the
arithmetic compatibility with Monero's well-tested reward distribution.

---

### 2. Emission Speed — `EMISSION_SPEED_FACTOR_PER_MINUTE`

|                    |                                                      |
| ------------------ | ---------------------------------------------------- |
| **Location**       | `cryptonote_config.h:55`                             |
| **Current**        | `20` (yields effective shift of 19 with 120s blocks) |
| **Recommendation** | **Keep at `20`**                                     |

**Rationale.** With factor 20 / 120s blocks, the curve emits:

- Year 1: ~5.5 M RKZ (≈ 30% of asymptote)
- Year 2: ~9.5 M RKZ (≈ 51%)
- Year 4: ~13.8 M RKZ (≈ 75%)
- Year 6: ~16.0 M RKZ (≈ 87%)
- Tail begins around year 6

This is already aggressive bootstrapping — over half the supply is mined in
the first two years. Lowering to 19 doubles initial reward (≈70 RKZ/block)
which over-weights early-mined coins and risks a perceived dump-and-flee
distribution. Raising to 21 halves initial reward, which weakens the incentive
to bring hashrate to a brand-new chain. **20 is the right balance for a fresh
launch.**

---

### 3. Tail Emission — `FINAL_SUBSIDY_PER_MINUTE`

|                    |                                                                      |
| ------------------ | -------------------------------------------------------------------- |
| **Location**       | `cryptonote_config.h:56`                                             |
| **Current**        | `300000000000` atomic = **0.3 RKZ/min** = **0.6 RKZ/block** at 120s  |
| **Recommendation** | **Increase to `600000000000`** = **0.6 RKZ/min** = **1.2 RKZ/block** |

**Rationale.** Tail emission is the permanent miner subsidy that replaces the
shrinking base reward — it is what makes Monero security-stable beyond the
emission curve. The amount required is a function of:

1. **Network value at risk** — bigger market cap needs more security spend
2. **Hashrate dispersion** — a smaller, less geographically distributed network
   is _more_ vulnerable to 51% attack per dollar of reward, so it needs _more_
   security per unit of network value
3. **Acceptable inflation rate** — perpetual inflation must stay low enough that
   it doesn't deter holders

Monero's 0.6 XMR/block tail produces ≈0.87 % annual inflation when emission
finishes (declining over time as supply grows). For a smaller network, doubling
this to **1.2 RKZ/block** gives ≈1.75 % initial tail inflation, declining to
~0.9 % within a decade as supply continues to grow. That's still well below
Bitcoin's pre-halving issuance and provides materially stronger long-term miner
security on a network that will have far less hashrate than Monero's.

This is the single most defensible tokenomics improvement in this list.

---

### 4. Block Time — `DIFFICULTY_TARGET_V2`

|                    |                          |
| ------------------ | ------------------------ |
| **Location**       | `cryptonote_config.h:80` |
| **Current**        | `120` seconds            |
| **Recommendation** | **Keep `120`**           |

**Rationale.** Monero originally used 60s and switched to 120s at hardfork v2
specifically because the orphan rate at 60s was hurting miner profitability and
chain stability. Faster blocks tempt users with "snappy confirmations" but:

- Increase orphan rate (network can't propagate before next block found)
- Reduce effective hashrate against attackers (more wasted hashes on orphans)
- Hurt small miners disproportionately (high-latency miners orphan more)
- Provide negligible UX improvement — the relevant confirmation count goes up
  proportionally, so `6 × 60s` = `3 × 120s` = same wait

A new network with fewer well-connected nodes has _worse_ propagation than
Monero, not better. **Keep 120s.** It is the well-tested sweet spot.

---

### 5. Coinbase Unlock Window — `CRYPTONOTE_MINED_MONEY_UNLOCK_WINDOW`

|                    |                                   |
| ------------------ | --------------------------------- |
| **Location**       | `cryptonote_config.h:44`          |
| **Current**        | `60` blocks ≈ **2 hours** at 120s |
| **Recommendation** | **Keep `60`**                     |

**Rationale.** This protects against reorg-induced double-spends from the
miner. A reorg of 60 blocks would require sustaining majority hashrate for 2
hours of wall clock — economically catastrophic for the attacker. There is no
benefit to lowering it (miners can still mine; they just can't _spend_ fresh
coinbase coins for 2 hours). Keep it.

---

### 6. Default Tx Spendable Age — `CRYPTONOTE_DEFAULT_TX_SPENDABLE_AGE`

|                    |                                      |
| ------------------ | ------------------------------------ |
| **Location**       | `cryptonote_config.h:49`             |
| **Current**        | `10` blocks ≈ **20 minutes** at 120s |
| **Recommendation** | **Keep `10`**                        |

**Rationale.** This is the default unlock for ordinary (non-coinbase) tx
outputs — equivalent to ~10 confirmations. Already short. Lowering would
reduce reorg-safety with no compelling UX gain.

---

### 7. Block Size & Penalty Zone — `CRYPTONOTE_BLOCK_GRANTED_FULL_REWARD_ZONE_V5`

|                    |                                           |
| ------------------ | ----------------------------------------- |
| **Location**       | `cryptonote_config.h:61`                  |
| **Current**        | `300_000` bytes = 300 KB full-reward zone |
| **Recommendation** | **Keep `300000`**                         |

**Rationale.** The dynamic block size algorithm allows organic growth (up to
2× the rolling median), and the 300 KB floor is well above current Monero
demand. Increasing it permits larger blocks without penalty, which:

- Marginally raises orphan rate (more bytes to propagate)
- Reduces fees as space-pressure drops
- Bloats the chain faster

Throughput is not Rackz's near-term constraint. Keep the proven value.

---

### 8. Long-Term Block Weight Window — `CRYPTONOTE_LONG_TERM_BLOCK_WEIGHT_WINDOW_SIZE`

|                    |                                        |
| ------------------ | -------------------------------------- |
| **Location**       | `cryptonote_config.h:62`               |
| **Current**        | `100000` blocks ≈ **138 days** at 120s |
| **Recommendation** | **Keep `100000`**                      |

**Rationale.** This is the anti-bloat mechanism (the 1.7× long-term cap) that
prevents a hashrate cartel from permanently inflating block size via short-term
median manipulation. It is one of Monero's strongest scaling-vs-bloat
trade-offs and works well as-is.

---

### 9. Decimal Places — `CRYPTONOTE_DISPLAY_DECIMAL_POINT` & `COIN`

|                    |                                   |
| ------------------ | --------------------------------- |
| **Location**       | `cryptonote_config.h:65,67`       |
| **Current**        | 12 decimal places, `COIN = 10^12` |
| **Recommendation** | **Keep 12 decimals**              |

**Rationale.** 12 decimals (one atomic unit = 1 picorackz) gives sub-cent
precision for any plausible RKZ price, supports the millinero/micronero/etc.
unit hierarchy, and is the assumption baked into hundreds of formatting paths
across the wallet. Changing to 8 (Bitcoin) or 18 (Ethereum) breaks every
parser, fee calculator, and amount-display function in the codebase for no
real user benefit.

---

### 10. Fee Per Byte — `FEE_PER_BYTE` & dynamic fee constants

|                    |                                            |
| ------------------ | ------------------------------------------ |
| **Location**       | `cryptonote_config.h:71-75`                |
| **Current**        | `300000` atomic per byte = `3e-7 RKZ/byte` |
| **Recommendation** | **Keep current values**                    |

**Rationale.** Average ring-CT tx is ≈2 KB → ≈0.0006 RKZ fee. Even at $100/RKZ
that is $0.06 per transaction — extremely competitive. The dynamic fee
algorithm (`DYNAMIC_FEE_PER_KB_BASE_FEE_V5`) automatically scales with the
rolling block reward, so fees adjust to inflation/scarcity without manual
intervention. There is no improvement to be made by setting a different
hardcoded floor.

---

### 11. Minimum Ring Size (privacy) — via `HF_VERSION_MIN_MIXIN_15`

|                    |                                                    |
| ------------------ | -------------------------------------------------- |
| **Location**       | `cryptonote_config.h:182`                          |
| **Current**        | Ring size 16 (mixin 15) enforced from hardfork v15 |
| **Recommendation** | **Enforce ring size 16 from block 1**              |

**Rationale.** Monero raised ring size gradually (4 → 6 → 10 → 11 → 16) over
many hardforks because it could not break backward compatibility with old
unspent outputs. **Rackz starts fresh.** There is no legacy ring-size code path
to support, so the chain should ship with ring size 16 enforced from genesis.

This is achieved automatically by setting the genesis hardfork version to
**v16+** in `src/hardforks/hardforks.cpp` (which is already the recommendation
in the hardfork section above). No `cryptonote_config.h` change needed.

> Going further (ring size 32) is technically possible but doubles transaction
> size, doubles verification cost, and Monero researchers have not committed
> to it as the next step. Stick with 16.

---

### 12. Difficulty Adjustment — `DIFFICULTY_WINDOW`, `DIFFICULTY_LAG`, `DIFFICULTY_CUT`

|                    |                                                                            |
| ------------------ | -------------------------------------------------------------------------- |
| **Location**       | `cryptonote_config.h:82-84`                                                |
| **Current**        | window=720, lag=15, cut=60 (24h of signal, trimmed mean of 600 timestamps) |
| **Recommendation** | **Keep all three values**                                                  |

**Rationale.** This is a well-tuned trimmed-mean adjustment that Monero has
run for years without significant difficulty oscillation issues. Smaller
windows (e.g. LWMA-style 60-block windows favoured by some forks) react
faster to hashrate swings — which is desirable on chains with very volatile
hashrate (small altcoins). For RandomX-mined Rackz, hashrate volatility is
much lower than for GPU-mined chains because RandomX is CPU-only and
multi-purpose CPUs cannot rapidly migrate between coins. **Keep the existing
algorithm.**

---

### 13. Dandelion++ — privacy network parameters

|                    |                                               |
| ------------------ | --------------------------------------------- |
| **Location**       | `cryptonote_config.h:109-114`                 |
| **Current**        | 2 stems, 20% fluff probability, 10-min epochs |
| **Recommendation** | **Keep all values**                           |

**Rationale.** These are the parameters of Monero's transaction-broadcast
anonymisation layer. They have been specifically analysed for the trade-off
between propagation latency and broadcast-origin obfuscation. Touching them
without a privacy-research justification would be amateur tuning.

---

### 14. Default Fee Placeholder — `DEFAULT_FEE_ATOMIC_XMR_PER_KB`

|                    |                                                          |
| ------------------ | -------------------------------------------------------- |
| **Location**       | `cryptonote_config.h:226`                                |
| **Current**        | `500` (with comment `// Just a placeholder! Change me!`) |
| **Recommendation** | **Set to `300000000`** (`FEE_PER_BYTE × 1024`)           |

**Rationale.** This fallback fires during the first ~100 blocks when the
dynamic fee algorithm has insufficient chain history. At `500` atomic it is
effectively zero, leaving genesis blocks trivially spammable for free.
Setting it to `FEE_PER_BYTE × 1024 = 300_000_000` atomic (0.0003 RKZ/KB)
gives a sensible floor consistent with the rest of the fee schedule.

---

### 15. Mempool Transaction Lifetime — `CRYPTONOTE_MEMPOOL_TX_LIVETIME`

|                    |                                   |
| ------------------ | --------------------------------- |
| **Location**       | `cryptonote_config.h:105`         |
| **Current**        | `86400 * 3` = **3 days**          |
| **Recommendation** | **Reduce to `86400`** = **1 day** |

**Rationale.** During the March 2024 Monero flooding attack, the 3-day
mempool allowed spam to accumulate for 72 hours before self-purging, keeping
nodememory pressure elevated throughout. A 1-day lifetime evicts stale
low-fee spam faster and shortens the effective window for fee-based attacks.
Legitimate transactions confirm within minutes; no real use case exists for a
transaction deliberately sitting in the mempool for 3 days.

---

### 16. Maximum Transaction Pool Weight — `DEFAULT_TXPOOL_MAX_WEIGHT`

|                    |                                                                |
| ------------------ | -------------------------------------------------------------- |
| **Location**       | `cryptonote_config.h:205`                                      |
| **Current**        | `648000000` bytes = **~618 MB** (3 days × 300 KB/block)        |
| **Recommendation** | **Reduce to `216000000`** = **~206 MB** (1 day × 300 KB/block) |

**Rationale.** Consistent with the 1-day mempool lifetime above. 618 MB of
mempool is significant constant RAM overhead; 206 MB matches the new lifetime.
Once the pool is full, the daemon rejects the lowest-fee transactions and
forces fee competition, automatically pricing out spam.

---

### 17. Maximum tx_extra Size — `MAX_TX_EXTRA_SIZE`

|                    |                           |
| ------------------ | ------------------------- |
| **Location**       | `cryptonote_config.h:221` |
| **Current**        | `1060` bytes              |
| **Recommendation** | **Keep `1060`**           |

**Rationale.** This was already tightened by Monero post-flooding-attack.
The comment documents the arithmetic: 1060 bytes is the exact minimum for a
16-output transaction plus 32 bytes of custom data per recipient. Reducing
further would break legitimate multi-output transactions; increasing would
re-open the tx_extra inflation vector used in the 2024 spam attack.

---

## Recommended Tokenomics Diff (summary)

```diff
 // src/cryptonote_config.h

-#define CRYPTONOTE_MEMPOOL_TX_LIVETIME          (86400*3) //seconds, three days
+#define CRYPTONOTE_MEMPOOL_TX_LIVETIME          (86400*1) //seconds, one day

-#define CRYPTONOTE_MEMPOOL_TX_FROM_ALT_BLOCK_LIVETIME  604800 //seconds, one week
+#define CRYPTONOTE_MEMPOOL_TX_FROM_ALT_BLOCK_LIVETIME  (86400*2) //seconds, two days

-#define FINAL_SUBSIDY_PER_MINUTE                ((uint64_t)300000000000) // 3 * pow(10, 11)
+#define FINAL_SUBSIDY_PER_MINUTE                ((uint64_t)600000000000) // 6 * pow(10, 11)

-#define DEFAULT_TXPOOL_MAX_WEIGHT               648000000ull // 3 days at 300000, in bytes
+#define DEFAULT_TXPOOL_MAX_WEIGHT               216000000ull // 1 day at 300000, in bytes

 namespace config
 {
-  uint64_t const DEFAULT_FEE_ATOMIC_XMR_PER_KB = 500; // Just a placeholder!  Change me!
+  uint64_t const DEFAULT_FEE_ATOMIC_XMR_PER_KB = 300000000; // FEE_PER_BYTE * 1024
 }
```

```diff
 // src/hardforks/hardforks.cpp — start at v16 so ring size 16,
 // Bulletproofs+, view tags, and CLSAG are active from genesis.
-const hardfork_t mainnet_hard_forks[] = {
-  { 1,  1, 0, 1341378000 },
-  // ... entire Monero hardfork history through v16 ...
-};
+const hardfork_t mainnet_hard_forks[] = {
+  { 1,  1, 0, <rackz_genesis_timestamp> },
+  { 16, 2, 0, <rackz_genesis_timestamp> + 1 },
+};
```

```diff
 // src/hardforks/hardforks.cpp — all three tables replaced; version_1_till updated

-const hardfork_t testnet_hard_forks[] = { /* 16 entries spanning 2015-2022 */ };
-const uint64_t testnet_hard_fork_version_1_till = 624633;
+const hardfork_t testnet_hard_forks[] = {
+  { 1,  1, 0, 0 },
+  { 16, 2, 0, 0 },
+};
+const uint64_t testnet_hard_fork_version_1_till = 1;

-const hardfork_t stagenet_hard_forks[] = { /* 16 entries spanning 2018-2022 */ };
+const hardfork_t stagenet_hard_forks[] = {
+  { 1,  1, 0, 0 },
+  { 16, 2, 0, 0 },
+};
+// stagenet_hard_fork_version_1_till does not exist — blockchain.cpp hardcodes 0

-const uint64_t mainnet_hard_fork_version_1_till = 1009826;
+const uint64_t mainnet_hard_fork_version_1_till = 1;
```

**Total: 6 changes across 2 files.** Everything else in `cryptonote_config.h`
and `hardforks/hardforks.cpp` stays at upstream values.

---

## Other Pre-Launch Decisions (non-tokenomics)

### Address prefix for brand recognition

**CONFIRMED**: Mainnet prefix `5141` (0x1415) — addresses start with **"Rx"**.
Integrated (5142) and subaddress (5143) prefixes are provisional — verify they
produce non-colliding leading characters with the
[CryptoNote prefix tool](https://cryptonotestarter.org/tools.html) before committing.
Testnet (5153) and stagenet (5163) are placeholders requiring the same verification.

### Disable DNS checkpoint and update systems on first launch

Rather than pointing them at non-existent Rackz infrastructure, disable them
cleanly with a compile-time flag (`RACKZ_DISABLE_DNS_INFRASTRUCTURE`) or early
returns. Re-enable once DNS infrastructure is running.

### Ticker symbol

The codebase does not hardcode "XMR" anywhere user-visible — it only appears
in comments. Commit to **RKZ** as the ticker so denominations, RPC fields, and
wallet UX are consistent from launch.

### Optional: Rackz-overlay header

Rather than scattering Rackz values across many files, a future refactor could
introduce `src/rackz_network_config.h` that overlays only the network-identity
constants. This makes upstream syncs cheaper. **Defer until after launch** —
in-place edits to `cryptonote_config.h` are simpler for the initial fork.

---

## Implementation Order

> Branch: `feat/rackz-network-identity` (current)
> Gate: `export RACKZ_AI_CRYPTO_GATE=1` required for commits 1–4.

1. **Commit 1 — `cryptonote_config.h:` (red-zone)**
   - `CRYPTONOTE_NAME` → `"rackz"`
   - `NETWORK_ID` all three networks (confirmed UUIDs)
   - Ports: 7225/7226/7227, 17225–17227, 27225–27227
   - Address prefixes: 5141/5142/5143 (mainnet)
   - `HASH_KEY_MESSAGE_SIGNING` → `"RackzMessageSignature"`
   - All tokenomics changes (mempool, tail, txpool, fee placeholder)
   - `DEFAULT_FEE_ATOMIC_XMR_PER_KB` → 300000000
   - Genesis TX stub (empty string)

2. **Commit 2 — `hardforks:` (red-zone)**
   - Replace all three hardfork tables with `{1,1,0,0} {16,2,0,1}` form
   - Set `mainnet_hard_fork_version_1_till = 1`
   - Set `testnet_hard_fork_version_1_till = 1`

3. **Commit 3 — Build + genesis generation (red-zone)**
   - `cmake .. && make -j$(nproc) rackzd`
   - `./rackzd --print-genesis-tx` → copy hex back into `GENESIS_TX`
   - Commit with `cryptonote_config.h: set mainnet genesis tx and nonce`

4. **Commit 4 — CMakeLists binary renames (green-zone)**
   - All `OUTPUT_NAME` values across 6 CMakeLists files

5. **Commit 5 — wallet2.cpp (yellow-zone)**
   - File magic strings (`"Rackz ..."`) + URI scheme (`rackz:`)
   - Run: `make debug-test` before committing

6. **Commit 6 — simplewallet (yellow-zone)**
   - Denomination names, donate strings, QR URI scheme
   - Donation address: use placeholder; replace post-launch

7. **Commit 7 — display strings / env vars (green-zone)**
   - `executor.cpp`, `command_line_args.h`, `posix_fork.cpp`
   - `wallet_args.cpp` (`MONERO_LOGS` → `RACKZ_LOGS`)
   - `version.cpp.in`: `"0.1.0.0"` / `"Nibiru"`

8. **Commit 8 — DNS / seed nodes / checkpoints (green-zone)**
   - Empty seed node list
   - Disable moneropulse checkpoint and update URLs

9. **Final: `CHANGELOG.md`** — record all changes under `## [0.1.0] Unreleased`

---

## Locked Launch Parameters

All decisions below are confirmed. Do not change without a documented rationale.

| Parameter                                       | Value                                             | Notes                                                                 |
| ----------------------------------------------- | ------------------------------------------------- | --------------------------------------------------------------------- |
| `CRYPTONOTE_NAME`                               | `"rackz"`                                         | Drives data dir, config, log file names                               |
| Mainnet address prefix                          | `5141` (0x1415)                                   | Addresses start with "Rx"                                             |
| Integrated address prefix                       | `5142`                                            | Verify with prefix tool before commit                                 |
| Subaddress prefix                               | `5143`                                            | Verify with prefix tool before commit                                 |
| Mainnet P2P port                                | `7225`                                            | "RACK" on phone keypad                                                |
| Mainnet RPC port                                | `7226`                                            |                                                                       |
| Mainnet ZMQ port                                | `7227`                                            |                                                                       |
| Testnet ports                                   | `17225–17227`                                     |                                                                       |
| Stagenet ports                                  | `27225–27227`                                     |                                                                       |
| Mainnet NETWORK_ID                              | `4C 68 28 1A 6B 8C F3 24 90 41 53 63 DF D1 D5 39` | Cryptographically random                                              |
| Testnet NETWORK_ID                              | `0E 41 E8 13 A4 BE AC 8F 96 24 AF 1B B4 BF CC F2` | Cryptographically random                                              |
| Stagenet NETWORK_ID                             | `D2 0F E9 E6 4F 70 F8 CD D3 0F 0B 56 55 6B 28 82` | Cryptographically random                                              |
| `FINAL_SUBSIDY_PER_MINUTE`                      | `600000000000`                                    | 2× Monero tail; ~1.75% annual tail inflation                          |
| `CRYPTONOTE_MEMPOOL_TX_LIVETIME`                | `86400` (1 day)                                   | Spam resilience                                                       |
| `CRYPTONOTE_MEMPOOL_TX_FROM_ALT_BLOCK_LIVETIME` | `172800` (2 days)                                 | Proportional to main livetime                                         |
| `DEFAULT_TXPOOL_MAX_WEIGHT`                     | `216000000` (~206 MB)                             | 1 day at 300 KB/block                                                 |
| `DEFAULT_FEE_ATOMIC_XMR_PER_KB`                 | `300000000`                                       | `FEE_PER_BYTE × 1024`; no free genesis blocks                         |
| `HASH_KEY_MESSAGE_SIGNING`                      | `"RackzMessageSignature"`                         | Prevents cross-chain message replay                                   |
| Hardfork table (all nets)                       | v1 @ block 1, v16 @ block 2                       | Full protocol stack from genesis                                      |
| `mainnet_hard_fork_version_1_till`              | `1`                                               | Block 1 is the only v1 block                                          |
| `testnet_hard_fork_version_1_till`              | `1`                                               | Same                                                                  |
| Genesis timestamp                               | `0` (testnet/stagenet); TBD (mainnet)             | Set at mainnet launch date                                            |
| Version string                                  | `"0.1.0.0"`                                       | Testnet/pre-release                                                   |
| Release codename                                | `"Nibiru"`                                        | v0.1; planned sequence: Nibiru → Anu → Enki → Enlil → Inanna → Marduk |
| Ticker                                          | `RKZ`                                             | No code change required; use in docs/comms                            |
| Donation address                                | placeholder                                       | Generate from live mainnet wallet post-launch                         |
