# Zano Feature Integration Analysis

> **Purpose**: Deep analysis of the Zano codebase for feature extraction and integration
> into RKZ (Monero fork). This document is the research input for ROADMAP.md — it is
> intentionally exhaustive. Do not implement anything without separate discussion.
>
> **Zano path**: `/home/anon/GitHub/zano/src/`
> **RKZ (Rackz) path**: `/home/anon/GitHub/rackz/src/`

---

## 1. Architectural Similarity Assessment

Both codebases descend from the same CryptoNote reference implementation (2012–13).
The surface-level similarity is high: identical epee networking stack, same LMDB
approach, near-identical P2P handshake, ring-signature model, and key-derivation
scheme. Below the surface the two have diverged substantially.

### Structural Mapping

| Zano module                              | Rackz equivalent                                         | Similarity                                          |
| ---------------------------------------- | -------------------------------------------------------- | --------------------------------------------------- |
| `src/currency_core/`                     | `src/cryptonote_core/` + `src/cryptonote_basic/`         | Medium — same purpose, different class shapes       |
| `src/currency_core/blockchain_storage.*` | `src/cryptonote_core/blockchain.cpp`                     | Medium — same role, Zano's is ~60% larger           |
| `src/currency_core/currency_basic.h`     | `src/cryptonote_basic/cryptonote_basic.h` + `tx_extra.h` | Low — Zano's is 3× bigger with typed variants       |
| `src/currency_core/currency_config.h`    | `src/cryptonote_config.h`                                | High — same concept, different values               |
| `src/wallet/wallet2.*`                   | `src/wallet/wallet2.*`                                   | Low — same filename, completely different internals |
| `src/rpc/core_rpc_server.*`              | `src/rpc/core_rpc_server.*`                              | Medium — same pattern, different endpoints          |
| `src/p2p/`                               | `src/p2p/`                                               | High — both use epee P2P                            |
| `src/crypto/`                            | `src/crypto/`                                            | Medium — same primitives, Zano adds Zarcanum crypto |
| `src/serialization/`                     | `src/serialization/`                                     | High — both use epee binary/KV serialization        |

### The Fundamental Structural Divergence: `tx_extra`

This is the single most important architectural difference for feature integration.

**Rackz (Monero)**:

```cpp
// src/cryptonote_basic/tx_extra.h
// tx_extra is std::vector<uint8_t> stored in transaction_prefix.
// Parsed via parse_tx_extra() into a typed variant for in-memory use:
typedef boost::variant<
  tx_extra_padding,
  tx_extra_pub_key,
  tx_extra_nonce,           // carries payment_id, encrypted_payment_id
  tx_extra_merge_mining_tag,
  tx_extra_additional_pub_keys,
  tx_extra_mysterious_minergate
> tx_extra_field;
// 6 types. Raw bytes on wire.
```

**Zano**:

```cpp
// src/currency_core/currency_basic.h
// tx_extra is typed on the wire — no raw-byte intermediate.
typedef boost::mpl::vector23<
  tx_service_attachment,    // generic plugin data (market, escrow, etc.)
  tx_comment,
  tx_payer, tx_receiver,
  tx_derivation_hint,
  tx_crypto_checksum,
  etc_tx_time,
  etc_tx_details_unlock_time, etc_tx_details_unlock_time2,
  etc_tx_details_expiration_time,
  etc_tx_details_flags, etc_tx_flags16_t,
  crypto::public_key,
  extra_attachment_info,
  extra_alias_entry,        // ← alias feature
  extra_user_data,
  extra_padding,
  std::string,
  tx_payer_old, tx_receiver_old,
  extra_alias_entry_old,
  zarcanum_tx_data_v1,
  asset_descriptor_operation  // ← token feature
> all_payload_types;
typedef boost::make_variant_over<all_payload_types>::type payload_items_v;
// 23 types. Typed objects on wire.
// PLUS a separate `attachment` vector for large service payloads.
```

**Integration strategy**: Rackz's `tx_extra_field` variant can be extended with new
types using the same `VARIANT_TAG` mechanism already present. New tags must be
allocated from a free range (e.g., `0x10`+) and gated behind hardfork version checks.
This is additive and does not break existing transactions.

---

## 2. Feature Inventory

Features extracted from Zano source, confirmed present and active:

| #   | Feature                                   | Zano source(s)                                           | Status in Zano                     |
| --- | ----------------------------------------- | -------------------------------------------------------- | ---------------------------------- |
| A   | **Aliases**                               | `currency_basic.h`, `blockchain_storage.cpp`, wallet RPC | Live/mainnet                       |
| B   | **Native Token / Asset System**           | `currency_basic.h`, `blockchain_storage.cpp`, wallet RPC | Live (HF4+)                        |
| C   | **Service Attachment Framework**          | `bc_attachments_service_manager.h`, `currency_basic.h`   | Live (prerequisite)                |
| D   | **Decentralised Marketplace**             | `bc_offers_service.*`, `offers_service_basics.h`         | Live/mainnet                       |
| E   | **Escrow Contracts**                      | `bc_escrow_service.h`, `wallet2_escrow.cpp`              | Implemented, RPC **commented out** |
| F   | **Ionic Swaps** (cross-asset atomic swap) | wallet RPC                                               | Live (HF4+)                        |
| G   | **HTLC** (Hash Time-Lock Contracts)       | `currency_basic.h` (`txout_htlc`, `txin_htlc`)           | Live                               |
| H   | **Auditable Addresses**                   | `currency_basic.h` (`account_public_address::flags`)     | Live                               |
| I   | **Confidential Assets (Zarcanum)**        | `crypto/zarcanum.*`, `currency_basic.h` (ZC types)       | Live (HF4+)                        |

---

## 3. Feature Deep-Dive

### Difficulty Scale

```
1–3  = Isolated, low-risk; port data structs + logic with moderate adaptation
4–6  = Non-trivial; requires new consensus paths, DB schema additions
7–8  = Complex; requires hardfork, significant consensus + wallet changes
9–10 = Extreme; novel cryptography or full subsystem re-architecture required
```

---

### Feature A — Aliases

**Difficulty: 6 / 10**

#### What It Does

Maps a human-readable short name (`@alice`) to a Rackz address on-chain.
Registration costs a fee proportional to name length (shorter = more expensive;
the fee burns to a null address). Names can carry an optional tracking (view) key
and a text comment. Names can be updated (re-pointed to a new address) by the
original owner via a signature proof.

#### How Zano Implements It

1. `extra_alias_entry` struct embedded in `tx.extra`:
   ```cpp
   struct extra_alias_entry {
     std::string m_alias;
     account_public_address m_address;
     std::string m_text_comment;
     std::vector<crypto::secret_key> m_view_key;  // optional, for "auditable" aliases
     std::vector<crypto::signature> m_sign;        // required for updates
   };
   ```
2. `blockchain_storage::validate_alias_reward()` — validates the fee is sufficient
   (based on `get_alias_coast()` which implements the fee schedule).
3. `blockchain_storage::get_alias_info()` / `get_alias_by_address()` — DB lookups.
4. `blockchain_storage::prevalidate_alias_info()` — validates format, signature.
5. Stored in the blockchain DB (not a separate file, unlike offers).
6. `alias_helper.h` — wallet-side `@alias` resolution when constructing transfers.
7. Wallet RPC: `register_alias`, `update_alias`.
8. Daemon RPC: `COMMAND_RPC_GET_ALIAS_DETAILS`, `COMMAND_RPC_GET_ALIASES_BY_ADDRESS`.

#### Integration Points in Rackz

| Layer          | What changes                                                             | Rackz file(s)                             |
| -------------- | ------------------------------------------------------------------------ | ----------------------------------------- |
| **Protocol**   | New `tx_extra_field` type `tx_extra_alias_entry` + tag `0x10`            | `src/cryptonote_basic/tx_extra.h`         |
| **Protocol**   | Add struct definitions                                                   | `src/cryptonote_basic/cryptonote_basic.h` |
| **Consensus**  | Validate alias entry in `add_transaction_to_pool()` and block processing | `src/cryptonote_core/blockchain.cpp`      |
| **Consensus**  | Alias fee schedule constant(s)                                           | `src/cryptonote_config.h` (red-zone)      |
| **Database**   | New LMDB sub-database for alias→address and address→alias maps           | `src/blockchain_db/lmdb/db_lmdb.cpp/.h`   |
| **Daemon RPC** | `get_alias_details`, `get_aliases_by_address`, `get_all_aliases`         | `src/rpc/core_rpc_server.*`               |
| **Wallet**     | `@alias` resolution in `transfer()`                                      | `src/wallet/wallet2.cpp`                  |
| **Wallet RPC** | `register_alias`, `update_alias`                                         | `src/wallet/wallet_rpc_server.*`          |
| **CLI**        | `transfer @alice <amount>` syntax                                        | `src/simplewallet/simplewallet.cpp`       |

#### Code Reusable Directly from Zano

- `extra_alias_entry` / `extra_alias_entry_base` struct definitions — transplant
  verbatim after namespace rename (`currency::` → `cryptonote::`).
- `alias_helper.h` — the `get_transfer_address_cb()` template; requires adapting
  the RPC proxy call but the logic is identical.
- Fee schedule constants from `currency_config.h` (`ALIAS_COAST_PERIOD`,
  `ALIAS_MINIMUM_PUBLIC_SHORT_NAME_ALLOWED`, `ALIAS_VALID_CHARS`,
  `ALIAS_COMMENT_MAX_SIZE_BYTES`) — adapt values as desired.
- `validate_alias_name()` utility function — transplant as-is.

#### What Must Be Rewritten

- All DB storage calls (`m_db_aliases`, etc.) — Zano uses its own DB abstraction;
  Rackz uses `BlockchainDB` interface in `src/blockchain_db/`.
- Blockchain validation integration — method signatures differ
  (`validate_tx_for_hardfork_specific_terms()` vs Monero's `check_tx_inputs()`).
- The fee-validation path must be threaded through Rackz's `check_tx_semantics()`.

#### Blockers

- None structural. Requires hardfork gating (`HF_VERSION_ALIASES`).
- The alias → DB schema must be defined before testnet launch (schema is
  consensus-critical once aliases are registered).

#### Opportunity to Improve

- **Hierarchical namespaces**: support dot-separated paths (`pay.alice.rkz`,
  `shop.alice.rkz`). Parent-name ownership grants sub-name registration authority;
  fee is proportional to path depth. This mirrors ENS sub-domains without smart
  contracts.
- **Alias expiry and renewal**: add an optional `expires_at` block height to the
  alias entry. Expired names become re-claimable, preventing long-term squatting
  by dormant wallets. Renewal is a standard alias-update tx with a fee.
- **Alias forwarding**: allow `m_address` to be another alias rather than a direct
  address. Enables rebranding without notifying all senders (`old.rkz` →
  `new.rkz`).
- **Structured metadata map**: replace `m_text_comment` with a bounded
  `std::map<std::string, std::string>` (max 10 keys, 128 bytes each) for typed
  fields: `avatar_hash`, `website`, `pgp_fp`, `nostr_pubkey`, `signal_id`, etc.
  Clients can display relevant fields; unknown keys are ignored.
- **AI agent registry**: an alias with `type=agent` in its metadata map and fields
  `endpoint`, `model`, `capabilities`, `pub_key` creates an on-chain AI agent
  directory. Agents can invoice, pay, and receive payments using their alias with
  no human in the loop. Zero additional protocol work — the alias infrastructure
  handles it.

---

### Feature B — Native Token / Asset System (Non-Confidential Mode)

**Difficulty: 8 / 10**

> There are two implementation tiers: **non-confidential** (transparent amounts,
> explicit `asset_id` on outputs) and **confidential** (Zarcanum, see Feature I).
> This section covers non-confidential only, which is implementable without new
> cryptography.

#### What It Does

Permits third parties to register, mint, update metadata, burn, and transfer custom
tokens on-chain. Each asset is identified by a `crypto::public_key` used as an
`asset_id`. The native coin has a fixed `asset_id = native_coin_asset_id` (a
pre-agreed curve point). Asset ownership is controlled by an owner key pair; only
the owner can mint or update.

#### How Zano Implements It

1. `asset_descriptor_base` — the asset metadata struct (supply caps, ticker,
   decimal point, owner key, meta_info JSON blob).
2. `asset_descriptor_operation` embedded in `tx.extra`:
   - `REGISTER` (1) — creates the asset, sets descriptor, burns a registration fee
   - `EMIT` (2) — mints new supply to owner's address
   - `UPDATE` (3) — updates mutable metadata fields
   - `PUBLIC_BURN` (4) — permanently destroys tokens
3. `blockchain_storage::validate_asset_operation()` — validates the operation,
   checks owner signature proof (`asset_operation_ownership_proof`).
4. `blockchain_storage::get_asset_info()` / `get_assets()` / `get_assets_count()`.
5. Asset storage in the blockchain DB: asset_id → `asset_descriptor_base`.
6. Wallet tracks per-asset balance independently. `getbalance` returns
   `std::list<asset_balance_entry>`.
7. Wallet RPC: `deploy_asset`, `emit_asset`, `update_asset`, `burn_asset`,
   `transfer_asset_ownership`.
8. Daemon RPC: `COMMAND_RPC_GET_ASSET_INFO`, `COMMAND_RPC_GET_ASSETS_LIST`.

#### Integration Points in Rackz

| Layer               | What changes                                                            | Rackz file(s)                             |
| ------------------- | ----------------------------------------------------------------------- | ----------------------------------------- |
| **Protocol**        | New `tx_extra_field` type for `asset_descriptor_operation` + tag `0x11` | `src/cryptonote_basic/tx_extra.h`         |
| **Protocol**        | `asset_descriptor_base`, `asset_descriptor_operation` structs           | `src/cryptonote_basic/cryptonote_basic.h` |
| **Output model**    | Add `asset_id` field to `txout_to_tagged_key` (or new output type)      | `src/cryptonote_basic/cryptonote_basic.h` |
| **Consensus**       | Asset operation validation (ownership proof, supply cap checks)         | `src/cryptonote_core/blockchain.cpp`      |
| **Consensus**       | Registration fee constant                                               | `src/cryptonote_config.h` (red-zone)      |
| **Database**        | New LMDB sub-DB for asset_id → descriptor; per-asset output index       | `src/blockchain_db/lmdb/db_lmdb.cpp/.h`   |
| **Wallet scanning** | Track per-asset balance during blockchain scan                          | `src/wallet/wallet2.cpp`                  |
| **Wallet**          | Asset construction for transfer, emit, burn                             | `src/wallet/wallet2.cpp`                  |
| **Wallet RPC**      | deploy/emit/update/burn/transfer_ownership                              | `src/wallet/wallet_rpc_server.*`          |
| **Daemon RPC**      | `get_asset_info`, `get_assets_list`                                     | `src/rpc/core_rpc_server.*`               |

#### Code Reusable Directly from Zano

- `asset_descriptor_base`, `asset_descriptor_with_id`, `asset_descriptor_operation`
  struct definitions — transplant verbatim (namespace adaptation only).
- `asset_operation_proof`, `asset_operation_ownership_proof` proof structures.
- `validate_ado_ownership()` logic from `blockchain_storage.cpp` — adaptable
  (~40 lines of proof verification; uses `crypto::check_signature` which exists
  in both codebases).
- `COMMAND_RPC_GET_ASSET_INFO` / `COMMAND_RPC_GET_ASSETS_LIST` command structs.

#### What Must Be Rewritten

- Output model: Rackz's current `txout_to_tagged_key` (view-tag output) has no
  `asset_id` field. Adding one to non-ZC outputs requires a new output type or
  extending the existing type behind a hardfork gate. This is the most invasive
  change.
- All DB storage (asset registry, per-asset global output index).
- Wallet scanning: Rackz's `process_new_transaction()` in `wallet2.cpp` (~1000
  lines) needs to identify and accumulate per-asset amounts.
- Fee for registration needs to be defined and validated.

#### Blockers

- **Output type extension** is consensus-critical and requires a hardfork.
- Without confidential assets (Zarcanum), asset amounts are visible to all
  observers. This is a deliberate trade-off for v1 — document it clearly.
- The asset_id must be deterministically derivable from the registration tx's
  extra data (Zano derives it as a hash of the descriptor + optional salt). This
  scheme must be defined before testnet.

#### Opportunity to Improve

- **Non-fungible tokens (NFTs)**: add `is_nft: bool` and `token_id: uint64` to
  the output type carrying `asset_id`. Two outputs with the same `asset_id` but
  different `token_id` are distinct collectibles within a collection. The
  `total_max_supply` becomes the collection size.
- **Creator royalties**: add `creator_royalty_bp: uint16` (basis points) and
  `creator_address` to `asset_descriptor_base`. At consensus, every transfer pays
  `royalty_bp / 10000 * amount` to `creator_address`. Royalties become trustless —
  no marketplace contract needed.
- **Metadata standard**: define a canonical JSON schema for `meta_info`:
  ```json
  {
    "name": "...",
    "symbol": "...",
    "image_hash": "...",
    "description": "...",
    "external_url": "...",
    "attributes": [{ "trait_type": "...", "value": "..." }],
    "ai_description": "..."
  }
  ```
  Compatible with ERC-1155 / OpenSea metadata conventions for tooling reuse.
  The `ai_description` field provides a plain-language summary for LLM
  consumption in search results, arbitration, and wallet display.
- **Locked supply**: add `supply_locked: bool` to `asset_descriptor_base`. Once
  set `true` via an UPDATE operation, no further EMIT is possible — a provable
  deflationary guarantee for token holders.
- **Governance primitive**: tokens with a `voting_contract_alias` in their
  metadata enable snapshot-based on-chain governance. Token balance at a specific
  block height = vote weight. No smart contract required — a daemon-side index
  query satisfies the snapshot.

---

### Feature C — Service Attachment Framework

**Difficulty: 4 / 10**

> This is a **prerequisite** for the Marketplace (Feature D) and Escrow (Feature E).
> It is a plugin pattern; it has no consensus-visible state of its own.

#### What It Does

Provides a generic, extensible mechanism to embed structured service-specific data
in transactions and have it routed to registered service handlers at block
processing time. Think of it as a plugin bus sitting alongside the blockchain.

#### How Zano Implements It

1. `tx_service_attachment` struct in `tx.attachment` (or `tx.extra`):
   ```cpp
   struct tx_service_attachment {
     std::string service_id;   // "M" = marketplace, "E" = escrow
     std::string instruction;  // "ADD", "UPD", "DEL", etc.
     std::string body;         // JSON-encoded payload (optionally encrypted/deflated)
     std::vector<crypto::public_key> security;
     uint8_t flags;            // ENCRYPT_BODY, DEFLATE_BODY, etc.
   };
   ```
2. `i_bc_service` interface — all services implement `handle_entry_push()`,
   `handle_entry_pop()`, `validate_entry()`.
3. `bc_attachment_services_manager` — holds a `std::map<service_id, i_bc_service*>`,
   dispatches to registered services during block processing.
4. `blockchain_storage` calls `m_services_mgr.handle_entry_push/pop()` at block
   connect/disconnect time.

#### Integration Points in Rackz

| Layer         | What changes                                                            | Rackz file(s)                                                   |
| ------------- | ----------------------------------------------------------------------- | --------------------------------------------------------------- |
| **Protocol**  | New `tx_extra_field` type `tx_extra_service_attachment` + tag `0x12`    | `src/cryptonote_basic/tx_extra.h`                               |
| **Consensus** | `i_bc_service` interface + `bc_attachment_services_manager` (new files) | `src/cryptonote_core/bc_service.h`, `bc_service_manager.h/.cpp` |
| **Consensus** | Hook manager into `blockchain::add_new_block()` / reorganize path       | `src/cryptonote_core/blockchain.cpp`                            |

#### Code Reusable Directly from Zano

- `bc_attachments_service_manager.h` — transplant with namespace change (~52 lines).
- `i_bc_service` interface definition — transplant verbatim.
- `tx_service_attachment` struct — transplant verbatim.
- `TX_SERVICE_ATTACHMENT_*` flags — transplant verbatim.

#### What Must Be Rewritten

- The hook call sites in `blockchain.cpp` — Zano's `blockchain_storage.cpp` calls
  the manager; Rackz's `blockchain.cpp` will need the equivalent hooks in
  `add_transaction_to_pool()`, `pop_block_from_blockchain()`.

#### Opportunity to Improve

- **Schema versioning in service_id**: use `"SERVICE:VERSION"` format (e.g.,
  `"M:2"`, `"ARB:1"`). Services increment version when their body schema breaks
  backward compatibility. Nodes that don't understand a version skip it gracefully.
- **Selective field encryption**: extend `flags` to support per-field keys. Public
  fields (title, price, category) stay plaintext for indexing; sensitive fields
  (contacts, personal details) are encrypted to the counterparty's view key.
  Currently Zano encrypts the entire body or nothing.
- **Content-addressed off-chain data**: standardise a `data_hash: crypto::hash`
  field in bodies for large payloads (images, legal documents, delivery proofs).
  The hash commits to content on IPFS/Arweave; only the hash lives on-chain.
  Nodes can optionally pin referenced content. This bounds blockchain growth
  regardless of attachment size.
- **Typed service registry**: hardcode a well-known registry of service IDs
  (`"M"` = marketplace, `"ARB"` = arbitration, `"ACK"` = delivery ack, etc.) and
  their body schemas. Unknown IDs are allowed and silently ignored by nodes that
  don't implement them, enabling third-party services without protocol changes.

---

### Feature D — Decentralised Marketplace

**Difficulty: 7 / 10** (requires Feature C first; with C done, ~5/10 incremental)

#### What It Does

Any user can post a buy/sell offer on-chain. Offers are stored in a daemon-side
in-memory index (rebuilt from blockchain on restart). Offers carry: type
(buy/sell), primary amount, target amount, currency identifiers, location, contacts,
expiry, and a signature for owner-controlled cancellation or update. Offers expire
after a configurable period (30 days default in Zano). Listing the market is
a daemon RPC call with rich filtering.

#### How Zano Implements It

1. `offer_details` struct — the offer payload, JSON-serialised into
   `tx_service_attachment.body` with `service_id = "M"`.
2. Instructions: `ADD` (post offer), `UPD` (update), `DEL` (cancel).
3. `bc_offers_service` — implements `i_bc_service`. Maintains a
   `boost::multi_index_container<odeh>` indexed by id, timestamp, amounts,
   exchange rate, payment types, contacts, location, name.
4. On `handle_entry_push`: deserialise JSON body → insert/update in container.
5. On `handle_entry_pop`: reverse the operation (for reorgs).
6. Data serialised to `market.bin` on shutdown; rebuilt from blockchain if absent.
7. Wallet creates a special tx carrying the offer attachment. The attachment's
   `security` field contains a one-time pubkey that later authorises updates/cancels.
8. Wallet RPC: `marketplace_get_offers_ex`, `marketplace_push_offer`,
   `marketplace_push_update_offer`, `marketplace_cancel_offer`.

#### Integration Points in Rackz

| Layer            | What changes                                                                              | Rackz file(s)                                      |
| ---------------- | ----------------------------------------------------------------------------------------- | -------------------------------------------------- |
| **Framework**    | Feature C (service attachment)                                                            | See above                                          |
| **Core service** | `bc_offers_service` implementation                                                        | New `src/cryptonote_core/bc_offers_service.h/.cpp` |
| **Data structs** | `offer_details`, `offer_details_ex`, `cancel_offer`, `update_offer`, `core_offers_filter` | New `src/cryptonote_core/offers_service_basics.h`  |
| **Registration** | Register `bc_offers_service` in daemon startup                                            | `src/daemon/executor.cpp`                          |
| **Daemon RPC**   | `marketplace_get_offers`, `marketplace_get_offers_ex`                                     | `src/rpc/core_rpc_server.*`                        |
| **Wallet**       | Offer tx construction                                                                     | `src/wallet/wallet2.cpp`                           |
| **Wallet RPC**   | marketplace\_\* methods                                                                   | `src/wallet/wallet_rpc_server.*`                   |

#### Code Reusable Directly from Zano

- `offers_service_basics.h` — `offer_details`, `offer_details_ex`, `cancel_offer`,
  `update_offer`, `core_offers_filter` — transplant almost verbatim (~196 lines).
- `bc_offers_service.h` — class definition and all template method implementations
  — transplant with namespace + storage API changes (~251 lines, ~50% verbatim).
- `bc_offers_service.cpp` — the push/pop/validate implementations —
  ~60–70% transplantable; the multi_index logic is portable, DB calls differ.
- `offers_services_helpers.h/.cpp` — serialisation helpers, filter matching —
  largely transplantable.
- `BC_OFFERS_SERVICE_ID`, `BC_OFFERS_SERVICE_INSTRUCTION_*` constants — verbatim.

#### What Must Be Rewritten

- `bc_offers_service::serialize()` — Zano persists to Boost.Serialization archive;
  Rackz should use its own persistence or rebuild from blockchain.
- Wallet offer-tx construction — Zano's wallet builds the attachment in `wallet2.cpp`;
  the equivalent must be written for Rackz's wallet2, referencing the encrypted
  attachment scheme.

#### Observations

- The marketplace stores **no consensus-critical state** — it's a replayed
  index like a search cache. This means bugs in the marketplace code cannot
  corrupt the blockchain. Risk is low.
- Offers are publicly visible (no privacy). This is intentional for a marketplace.
- The 30-day expiry (`OFFER_MAXIMUM_LIFE_TIME`) is enforced by the service, not
  consensus, so it can be tuned without a hardfork.

#### Opportunity to Improve

##### On "Data API" vs "Marketplace"

**Keep it as a structured marketplace service.** The Service Attachment Framework
(Feature C) already provides the generic data API layer — any application can publish
any data under a custom `service_id` (`"BLOG"`, `"VOTE"`, `"REGISTRY"`, etc.). The
marketplace's unique value is a **searchable, indexed schema** that daemon nodes can
filter by price, category, location, and condition without downloading full tx blobs.
Turning the marketplace into a raw data API would lose this entirely.

The right model: the marketplace (`service_id = "M"`) is one well-defined application
of the generic framework. Document clearly that the framework is open and that nothing
prevents third parties from building other services alongside it.

##### Zano Schema Critique — Fields to Remove

| Field                                   | Reason for removal                                   |
| --------------------------------------- | ---------------------------------------------------- |
| `bonus`                                 | Vague; fold into `description`                       |
| `primary` / `target` as strings         | Redundant with `asset_id` system                     |
| `deal_option` ("full amount, by parts") | Replace with `quantity` + `min_order_quantity`       |
| `preview_url` (single string)           | Replace with content-addressed `media_hashes[]`      |
| `payment_types`                         | Always on-chain; replace with `accepted_asset_ids[]` |

##### Proposed `offer_details_v2` Schema

The most critical missing field in Zano's schema is `title` — there is no listing
title at all. The schema below covers physical goods (socks, yachts), digital goods,
services, real estate, and financial instruments.

```
// Item identity
title                string        REQUIRED. "2023 Volvo XC60" or "6-pack merino socks"
description          string        Full description; markdown allowed.
listing_type         enum          SELL_FIXED | SELL_AUCTION | BUY_REQUEST |
                                   SWAP | FREE | SERVICE_OFFER
item_type            enum          PHYSICAL | DIGITAL | SERVICE | REAL_ESTATE |
                                   VEHICLE | COLLECTIBLE | FINANCIAL | OTHER
category             string        Slash-delimited taxonomy path:
                                   "Clothing/Hosiery/Socks"
                                   "Vehicles/Marine/Sailing Yachts"
                                   "Services/Technology/Software Development"
condition            enum          NEW | LIKE_NEW | GOOD | FAIR | POOR |
                                   FOR_PARTS | DIGITAL_NA
quantity             uint64        Available stock (1 for unique items, 0 = unlimited)
quantity_unit        string        "each" | "pair" | "kg" | "sqm" | "hours" | "litre"
min_order_quantity   uint64        Minimum purchasable quantity
identifiers          map<str,str>  {"VIN":"WBA...","ISBN":"978...","GTIN":"...","SKU":"..."}

// Pricing
price_amount         uint64        In atomic units of price_asset_id
price_asset_id       public_key    Which coin/token the price is denominated in
price_type           enum          FIXED | AUCTION | NEGOTIABLE | MAKE_OFFER
min_bid_amount       uint64        Auction minimum bid
auction_end_height   uint64        Block height at which auction closes

// Location and delivery
seller_country       string        ISO 3166-1 alpha-2: "US", "MT", "GB", "DE"
seller_region        string        Free text: state, county, city district
ships_to             []string      Country codes or ["WORLDWIDE"] or ["LOCAL_ONLY"]
delivery_method      enum          PHYSICAL_SHIPPING | LOCAL_PICKUP |
                                   DIGITAL_DELIVERY | ESCROW_WITH_INSPECTION
estimated_delivery_days uint32     Calendar days from payment to delivery
shipping_included    bool          Is shipping cost included in price_amount?

// Contract terms — the fields an AI arbitrator needs
acceptance_criteria  string        Structured or natural language definition of
                                   successful delivery. This is the most important
                                   field for AI-assisted dispute resolution.
                                   Example: "Item arrives undamaged within 14 days,
                                   photographs match listing exactly, all stated
                                   accessories are included in the package."
dispute_window_hours uint32        Hours after delivery the buyer may raise a dispute.
                                   0 = no disputes accepted (digital goods, etc.)
return_policy        enum          NO_RETURNS | RETURNS_7D | RETURNS_30D | CUSTOM
return_policy_detail string        Plain-language detail when return_policy = CUSTOM
arbitration_service_alias string   @alias of chosen arbitration service.
                                   Empty = mutual agreement required to resolve.
arbitration_policy_hash   hash     Content hash (IPFS/sha256) of the full arbitration
                                   rules document. Parties agree to these rules by
                                   initiating an escrow referencing this offer.

// Category-specific attributes
attributes           map<str,str>  Open key-value store for category-specific fields.
                                   Nodes do not index these; clients parse by category.
                                   Examples:
                                     Socks:  {"material":"wool","size":"EU40-43","color":"navy"}
                                     Laptop: {"brand":"Lenovo","ram_gb":"16","storage":"512 SSD"}
                                     Yacht:  {"loa_m":"12.5","hull":"GRP","engine":"Volvo D2-50",
                                              "year":"2015","flag_state":"MT"}
                                     Service:{"skill":"Solidity","timeline_days":"30",
                                              "deliverable":"GitHub repository"}

// Media (content-addressed; not URL-dependent)
media_hashes         []hash        sha256 or IPFS CIDs of images and documents.
                                   The hash is the authoritative reference;
                                   arbitrators verify evidence against these hashes.
media_urls           []string      Optional convenience mirrors. Not indexed.

// Contacts (selectively encrypted per Feature C improvement)
contacts             string        Encrypted to counterparty's view key by default.

// Metadata
expiration_days      uint32        Days until listing auto-expires
language             string        ISO 639-1: "en", "es", "zh", "ar"
tags                 []string      Free-text searchable tags, max 10
security             public_key    Owner pubkey for update/cancel auth (from Zano)
```

##### AI Arbitration Design

The `acceptance_criteria`, `dispute_window_hours`, `arbitration_service_alias`,
`arbitration_policy_hash`, `media_hashes`, and `attributes` fields collectively
form a complete, machine-parseable contract. The arbitration flow uses two new
service IDs built on Feature C:

- `"ACK"` — delivery acknowledgement / delivery proof
- `"ARB"` — dispute open, respond, and ruling

```
1. LISTING
   Seller posts offer_v2 with acceptance_criteria and arbitration_service_alias.

2. ESCROW (Feature E, 2-of-3 variant — see Feature E improvement)
   Buyer creates escrow tx referencing offer_tx_hash.
   Keys: buyer_key  +  seller_key  +  arbitrator_key
   (arbitrator_key resolved from arbitration_service_alias via alias lookup)
   Funds locked in 2-of-3 multisig output.

3. DELIVERY
   Seller posts delivery proof tx (service_id = "ACK"):
     - offer_tx_hash, tracking_number_hash, carrier, estimated_arrival_height
   Dispute window timer starts.
   If no dispute within dispute_window_hours → protocol timelock auto-releases
   to seller (no arbitrator interaction needed).

4. DISPUTE (if buyer raises one within window)
   Buyer posts dispute tx (service_id = "ARB", instruction = "OPEN"):
     - offer_tx_hash, escrow_tx_hash
     - dispute_type:  NON_DELIVERY | NOT_AS_DESCRIBED | QUALITY_DEFECT |
                      PARTIAL_DELIVERY | FRAUD
     - claim_amount_bp:  0–10000  (percentage of escrow claimed by buyer)
     - statement:  buyer's plain-language account
     - evidence_hashes[]:  sha256 of photos, messages, tracking screenshots

5. SELLER RESPONSE
   Seller posts response tx (service_id = "ARB", instruction = "RESPOND"):
     - statement:  seller's counter-statement
     - evidence_hashes[]:  seller's evidence

6. AI RULING
   The arbitration service (an AI agent identified by its alias address) fetches
   both "ARB" attachments from the chain, then:
     a. Compares acceptance_criteria against dispute evidence
     b. Evaluates dispute_type against structured attributes and media_hashes
     c. Cross-references seller's reputation (prior trade tx hashes)
     d. Produces a structured ruling and posts ruling tx:
          - buyer_fraction_bp:  0–10000
          - ruling_rationale:  LLM-generated reasoning text
          - arbiter_signature:  signed by arbitration_service key

   What AI can rule on deterministically:
     NON_DELIVERY:     Did the ACK tx exist? Is tracking hash valid? → buyer wins.
     NOT_AS_DESCRIBED: Do listing attributes and media_hashes match dispute photos?
                       Semantic image comparison against listing images.
     QUALITY_DEFECT:   Does condition enum + acceptance_criteria set a clear bar?
                       Evidence photos evaluated against the stated standard.
     FRAUD:            Repeated dispute pattern across same seller security pubkey
                       → flag, escalate to human arbitration DAO.

7. RESOLUTION
   Ruling posts on-chain. Escrow (2-of-3): arbitrator_key + one party = 2 sigs.
   buyer_fraction_bp determines the split.
   Funds released, escrow closed.
```

The AI arbitrator's effectiveness scales directly with the quality of
`acceptance_criteria`. Sellers who write vague criteria bear the risk of adverse
rulings. Clients should surface this to sellers at listing time with examples.

##### Indexed vs Non-Indexed Fields

The daemon's multi-index container indexes the following fields for filtering:
`price_amount`, `price_asset_id`, `listing_type`, `item_type`, `category`,
`condition`, `seller_country`, `quantity`, `expiration_days`.

The `attributes` map, `description`, `acceptance_criteria`, `media_hashes`, and
`contacts` are stored but **not indexed** — they are opaque blobs to the daemon.
LLM-powered search can run client-side over downloaded offer blobs. This keeps
the daemon index simple and consensus-safe.

---

### Feature E — Escrow Contracts

**Difficulty: 8 / 10**

> **Note**: Zano's contract wallet RPC endpoints are **commented out** in
> `wallet_rpc_server.h` (lines 140–145). The implementation exists but appears to
> be disabled in the current release. The wallet-side code in `wallet2_escrow.cpp`
> is ~490 lines and compilable.

#### What It Does

2-of-2 multisig-based escrow between two parties (buyer A, seller B). Lifecycle:

1. A sends a _proposal tx_ carrying encrypted contract details and a partially-signed
   _template tx_ (which locks the escrow funds in a multisig output).
2. B sees the proposal, validates it, and signs the template to activate the contract.
3. Resolution: either normal release (B fulfils), mutual cancel, or burn (dispute).
4. Each resolution path requires a distinct pre-constructed tx template signed by
   the appropriate party.

Uses `txin_multisig` / `txout_multisig` for the escrow holding output, and
`TX_FLAG_SIGNATURE_MODE_SEPARATE` for partial signing across parties.

#### How Zano Implements It

- `bc_escrow_service.h`: protocol constants, `contract_private_details`,
  `contract_public_details`, `proposal_body`, `escrow_relese_templates_body`.
- `wallet2_escrow.cpp`: `validate_escrow_proposal()`, `create_escrow_proposal()`,
  `accept_escrow_proposal()`, `release_escrow_contract()`.
- Encrypted service attachment (`TX_SERVICE_ATTACHMENT_ENCRYPT_BODY`) carries
  `contract_private_details` only visible to the counterparty.
- State is tracked entirely per-wallet; no shared blockchain state (unlike aliases).

#### Integration Points in Rackz

| Layer            | What changes                                             | Rackz file(s)                                 |
| ---------------- | -------------------------------------------------------- | --------------------------------------------- |
| **Framework**    | Feature C (service attachment)                           | See above                                     |
| **Protocol**     | `txin_multisig`, `txout_multisig` new input/output types | `src/cryptonote_basic/cryptonote_basic.h`     |
| **Protocol**     | `TX_FLAG_SIGNATURE_MODE_SEPARATE` flag                   | `src/cryptonote_basic/cryptonote_basic.h`     |
| **Consensus**    | Validate multisig outputs / partial signatures           | `src/cryptonote_core/blockchain.cpp`          |
| **Data structs** | `contract_private_details`, `proposal_body`, etc.        | New `src/cryptonote_core/bc_escrow_service.h` |
| **Wallet**       | Proposal creation, validation, accept, release           | New `src/wallet/wallet2_escrow.cpp`           |
| **Wallet RPC**   | contracts\_\* methods                                    | `src/wallet/wallet_rpc_server.*`              |

#### Code Reusable Directly from Zano

- `bc_escrow_service.h` struct definitions — ~146 lines, transplant with
  namespace change.
- `wallet2_escrow.cpp` validation logic — `validate_escrow_proposal()` is the
  most complex and most portable (~150 lines). The construction functions
  (`create_escrow_proposal`) require more adaptation to Rackz's wallet2 internals.

#### Blockers

- **Monero's multisig is fundamentally different from Zano's**. Monero uses
  threshold key aggregation (Schnorr/RingCT-compatible multisig); Zano uses a
  `txout_multisig` output type with an explicit key list and `minimum_sigs` counter.
  These are not wire-compatible.
  **Decision required**: implement Zano-style multisig output type (new consensus
  path), or build escrow on top of Monero's existing multisig (complex key exchange,
  no protocol-level escrow construct). Zano-style is cleaner and the code is reusable.
- `TX_FLAG_SIGNATURE_MODE_SEPARATE` is a significant consensus rule change
  (separate signature per input, not over whole tx prefix). Consensus test coverage
  is mandatory before enabling.

#### Opportunity to Improve

- **Three-party escrow with arbitrator**: upgrade from 2-of-2 to 2-of-3 multisig.
  The three keys are: buyer (A), seller (B), and arbitrator (C). Normal resolution
  = A + B (no arbitrator needed). Dispute = C + A (refund) or C + B (release).
  The arbitrator key is resolved from `arbitration_service_alias` in the linked
  marketplace offer. This makes arbitration opt-in and trustless: the arbitrator
  only becomes relevant if a dispute is opened.
- **Milestone payments**: allow a single escrow to contain multiple sequenced
  output tranches, each with its own `milestone_description` and
  `expected_completion_height`. The seller requests release of individual tranches
  as milestones are completed. Essential for: software development contracts,
  construction work, yacht builds, large B2B purchase orders.
- **Time-locked auto-release**: if the buyer does not post a dispute tx within
  `dispute_window_hours` after the seller's ACK tx, a protocol-enforced timelock
  releases funds to the seller automatically. Eliminates the buyer-holds-seller-
  hostage attack vector that plagues 2-of-2 escrow.
- **Partial dispute resolution**: allow the ruling to specify `buyer_fraction_bp`
  (0–10000 basis points) for any split rather than winner-takes-all. This is the
  natural outcome for quality disputes: "item was 70% as described — return 30%."
- **Escrow–marketplace binding**: embed `offer_tx_hash` in the escrow creation tx.
  The escrow inherits `acceptance_criteria`, `dispute_window_hours`, and
  `arbitration_service_alias` from the referenced offer. This creates a
  cryptographically verifiable, tamper-proof audit trail for every trade.

---

### Feature F — Ionic Swaps (Cross-Asset Atomic Swap)

**Difficulty: 7 / 10** (requires Feature B — assets — to be useful)

#### What It Does

Trustless atomic swap between two different assets held by two parties, settled in a
single transaction. Party A proposes a swap specifying asset amounts and types.
Party B validates and accepts. The single resulting tx atomically moves both asset
amounts.

Implemented at the wallet level only — no special consensus rule needed because
it piggybacks on the asset system's multi-asset output model.

#### How Zano Implements It

- `wallet_rpc_server.h`: `ionic_swap_generate_proposal`, `ionic_swap_get_proposal_info`,
  `ionic_swap_accept_proposal`.
- Likely uses the `TX_FLAG_SIGNATURE_MODE_SEPARATE` mechanism to allow partial
  signing by each party, similar to escrow but without multisig outputs.
- Proposal is serialised and shared off-chain (e.g., as a hex blob).

#### Integration Points in Rackz

Depends entirely on Feature B (assets). Once assets exist and outputs carry `asset_id`,
ionic swaps are a wallet-level feature requiring no additional consensus changes.

#### Code Reusable Directly from Zano

- The wallet-side proposal/accept logic (~moderate reuse once asset tx construction
  is in place).

#### Opportunity to Improve

- **Marketplace integration**: when a marketplace offer has `listing_type = SWAP`
  and specifies both a `price_asset_id` and a target asset+amount in `attributes`,
  the buying wallet can one-click generate an ionic swap proposal from the offer.
  The offer index becomes a live swap order book with no additional protocol work.
- **Partial fills**: allow accepting a fraction of a swap proposal (buy 5 of 10
  listed tokens). The unfilled portion remains as an active offer. Requires a
  `remaining_quantity` field tracked in the offer service index.
- **On-chain price oracle reference**: a `service_id = "ORACLE"` could publish
  signed price feeds (e.g., RKZ/USD). Ionic swap proposals can optionally reference
  an oracle for fair-rate enforcement, preventing front-running in illiquid asset
  pairs without requiring an off-chain price discovery mechanism.

---

### Feature G — HTLC (Hash Time-Lock Contracts)

**Difficulty: 5 / 10**

#### What It Does

An output that can be:

- Spent by a _redeem key_ before a block/timestamp expiry, by providing the preimage
  of a hash (`htlc_origin`).
- Spent by a _refund key_ after expiry (without providing preimage).

Enables trustless cross-chain atomic swaps with external blockchains (BTC, ETH, etc.)
since the hash-lock is a standard HTLC mechanism.

#### How Zano Implements It

```cpp
// currency_basic.h
struct txout_htlc {
  crypto::hash htlc_hash;    // SHA256 or RIPEMD160 of the secret
  uint8_t flags;             // hash type selector
  uint64_t expiration;       // block height or timestamp
  crypto::public_key pkey_redeem; // can spend before expiry with preimage
  crypto::public_key pkey_refund; // can spend after expiry
};

struct txin_htlc : public txin_to_key {
  std::string hltc_origin;   // the preimage (empty for refund path)
};
```

Validated in `blockchain_storage::check_tx_input(txin_htlc...)`.

#### Integration Points in Rackz

| Layer          | What changes                                                  | Rackz file(s)                             |
| -------------- | ------------------------------------------------------------- | ----------------------------------------- |
| **Protocol**   | `txout_htlc`, `txin_htlc` new types                           | `src/cryptonote_basic/cryptonote_basic.h` |
| **Consensus**  | Validate HTLC spending conditions (hash check + expiry check) | `src/cryptonote_core/blockchain.cpp`      |
| **Wallet**     | HTLC output creation and spending                             | `src/wallet/wallet2.cpp`                  |
| **Wallet RPC** | htlc_create_output, htlc_spend                                | `src/wallet/wallet_rpc_server.*`          |

#### Code Reusable Directly from Zano

- `txout_htlc`, `txin_htlc` struct definitions — transplant verbatim.
- `CURRENCY_TXOUT_HTLC_FLAGS_HASH_TYPE_MASK` constant — transplant.
- Hash validation logic from `blockchain_storage::check_tx_input(txin_htlc...)` —
  ~40–60 lines, largely portable (SHA256/RIPEMD160 available in both codebases).

#### Notes

- Rackz's existing `timelock` mechanism already supports height/timestamp-based
  output locking. HTLC adds the _hash_ dimension on top.
- No new cryptography required — SHA256 is already used extensively.

#### Opportunity to Improve

- **Cross-chain atomic swaps (advertise prominently)**: Rackz's SHA256 and
  RIPEMD160 HTLC hash types directly match Bitcoin's BIP-199 HTLC standard. This
  enables trustless BTC ↔ RKZ atomic swaps with no third party and no bridge
  contract. This is a significant differentiator that should be documented as a
  first-class feature, not an implementation detail.
- **Multi-hop routing**: compose two-party HTLC channels across intermediate
  routing nodes (A → relay R → B, same hash secret on both hops). This is the
  foundational primitive for Lightning-style instant payments without a full
  Lightning implementation — just the existing HTLC primitive used recursively.
- **Watcher towers**: add an optional `watcher_alias` field to `txout_htlc`.
  Wallets that cannot remain online delegate HTLC timeout monitoring to a watcher
  service (identified by its alias). The watcher broadcasts the refund tx if the
  counterparty goes silent. Essential for mobile wallet UX.
- **Scriptless HTLC via adaptor signatures**: once the Seraphis research matures,
  adaptor signatures can replace explicit hash preimage reveals, making HTLC
  redemption on-chain indistinguishable from a normal signature. This is a
  long-horizon privacy improvement, not needed for v1.

---

### Feature H — Auditable Addresses

**Difficulty: 3 / 10**

#### What It Does

A special address format where the view key is embedded in the address itself
(or shared with a third party), allowing selective audit of incoming transactions
without spending capability. Useful for exchanges and regulated entities.

#### How Zano Implements It

```cpp
// currency_basic.h
#define ACCOUNT_PUBLIC_ADDRESS_FLAG_AUDITABLE 0x01

struct account_public_address {
  crypto::public_key spend_public_key;
  crypto::public_key view_public_key;
  uint8_t flags;  // ← added byte

  bool is_auditable() const {
    return (flags & ACCOUNT_PUBLIC_ADDRESS_FLAG_AUDITABLE) != 0;
  }
};
```

Auditable addresses have a distinct Base58 prefix (`aZx`). They appear in aliases
with an embedded `m_view_key`.

#### Integration Points in Rackz

| Layer                | What changes                                                                | Rackz file(s)                             |
| -------------------- | --------------------------------------------------------------------------- | ----------------------------------------- |
| **Protocol**         | Add `flags` byte to address struct (requires hardfork + new address format) | `src/cryptonote_basic/cryptonote_basic.h` |
| **Address encoding** | New Base58 prefix for auditable addresses                                   | `src/cryptonote_config.h` (red-zone)      |
| **Wallet**           | Generate/decode auditable addresses                                         | `src/wallet/wallet2.cpp`                  |

#### Observations

- Monero already has a view-key sharing mechanism (but not encoded in the address
  format). Auditable addresses formalise this in the address itself.
- This is a relatively small change but requires a hardfork for the new address
  prefix and wire format.

#### Opportunity to Improve

- **Time-bounded view keys**: generate an audit envelope that reveals transactions
  only within a specific block-height range [N1, N2]. Auditors (regulators,
  accountants) receive a scoped key with a defined expiry. Analogous to Monero's
  `restore_height` but with an enforced upper bound. Critical for periodic
  compliance reporting without lifetime wallet exposure.
- **Asset-selective disclosure**: an auditable address flag that reveals only
  specific `asset_id` balances while hiding native RKZ balance. Useful for
  stablecoin issuers or token treasuries that must publish token holdings without
  disclosing native coin positions.
- **Balance range proofs**: allow a wallet to prove "my balance of asset X is
  ≥ threshold T" without revealing the exact amount. Directly useful for
  credit-scoring and collateral applications: prove you can cover a trade without
  revealing total wealth. Builds on Pedersen commitment arithmetic already present
  in RingCT.
- **Voluntary KYC anchor**: an auditable address paired with a signed off-chain
  attestation from a KYC provider creates a privacy-preserving identity layer.
  The user proves to specific parties they are verified without broadcasting that
  fact on-chain. Useful for regulated marketplaces requiring seller verification.

---

### Feature I — Confidential Assets (Zarcanum)

**Difficulty: 10 / 10 — Do not pursue until all other features are stable**

#### What It Does

Full confidential multi-asset system where both the amount _and the asset type_ of
every output are cryptographically hidden from third-party observers. Based on the
Zarcanum paper by Sowle (Zano's lead cryptographer). This is a novel construction
on top of Bulletproof+ and CLSAG.

#### How Zano Implements It

- New output type `tx_out_zarcanum` with: `stealth_address`, `concealing_point`,
  `amount_commitment`, `blinded_asset_id`, `encrypted_amount`, `mix_attr`.
- New input type `txin_zc_input`.
- New signature type `ZC_sig` (CLSAG-GGX, a variant of CLSAG with an extra G
  component for asset blinding).
- New proof types: `zc_outs_range_proof` (BPP + vector aggregation),
  `zc_balance_proof` (double Schnorr), `zc_asset_surjection_proof` (BGE proofs).
- `zarcanum_sig` — full PoS-compatible Zarcanum proof for staked outputs.
- The cryptographic implementation is in `src/crypto/zarcanum.*`,
  `src/crypto/range_proofs.*`, and related files.

#### Blockers

- This is a **completely novel cryptographic protocol** not present in any Monero
  codebase. Porting it requires:
  1. Porting all of `src/crypto/zarcanum.*`, `src/crypto/range_proofs.*`,
     `src/crypto/eth_signature.*`, and associated primitives.
  2. Full cryptographic security review before testnet deployment.
  3. New output format and corresponding wallet scanning code (completely new).
  4. New consensus rules for all ZC transaction types.
- Monero's Seraphis research (currently in `src/seraphis_crypto/`, which is a
  stub in Rackz) pursues similar goals but is not production-ready.
- **Recommendation**: treat Zarcanum as a 18–24 month research item. Ship
  features A–G without confidential asset support. Non-confidential assets (Feature B)
  provide immediate utility.

#### Opportunity to Improve

- **Monitor Monero Seraphis**: `src/seraphis_crypto/` in Rackz is currently a stub
  of Monero's next-generation transaction protocol, which pursues similar
  confidential multi-asset properties via different cryptographic means. If Seraphis
  stabilises before Rackz reaches Phase 5, it may be a lower-risk foundation than
  porting Zarcanum in full. Track both research tracks.
- **Interim semi-private assets**: before full Zarcanum, consider a
  "masked-amount assets" mode where asset output amounts use existing Pedersen
  commitments (borrowing from RingCT) but `asset_id` remains visible. This provides
  amount privacy without the BGE surjection proof system and is implementable with
  existing cryptographic primitives. A meaningful privacy improvement at ~6/10
  difficulty rather than 10/10.
- **Cross-chain confidential bridges**: once Zarcanum is live, the
  `blinded_asset_id` mechanism could back a privacy-preserving bridge — lock a
  token on an external chain, mint a confidential wrapped version on RKZ. Long-
  horizon research item; include in Phase 5 scope.

---

## 4. Shared Infrastructure Observations

### Epee Serialization Compatibility

Both codebases use the same epee binary_archive and KV serialization.
Zano-derived structs using `BEGIN_SERIALIZE()` / `FIELD()` / `VARINT_FIELD()` will
compile and serialize identically in Rackz after namespace adaptation. This is the
most significant code-reuse enabler.

### DB Abstraction Gap

Zano uses a custom `tools::db::basic_key_to_array_accessor` and related templates.
Rackz uses `BlockchainDB` in `src/blockchain_db/` (LMDB backend). All Zano DB calls
in `blockchain_storage.cpp` must be rewritten against `BlockchainDB`. This is
mechanical but voluminous (~300–500 lines per feature for the storage layer).

### Cryptographic Primitives

- Both use `crypto::cn_fast_hash()`, `crypto::check_signature()`, `crypto::generate_signature()` with identical function signatures.
- SHA256 via `crypto::cn_fast_hash()` equivalent and OpenSSL are available in both.
- The `check_signature(hash, pubkey, sig)` function is wire-compatible.

### Logging

Both use the same epee logging macros (`LOG_PRINT_L1`, `LOG_ERROR`, etc.) —
transplanted log lines work without change.

### Error Handling Convention (IMPORTANT)

Rackz follows layer-specific patterns that Zano does not enforce:

- `cryptonote_core/` code: `CHECK_AND_ASSERT_MES(cond, false, msg)` + `return bool`
- `wallet/` code: `THROW_WALLET_EXCEPTION(exc_type, msg)`

Zano uses a mix. When transplanting Zano code, verify the error-handling style
matches the destination layer.

---

## 5. Recommended Implementation Order

The following order minimises blockers and provides incremental testable milestones:

```
Phase 1 — Foundation (prerequisite for everything else)
  C. Service Attachment Framework
     → Adds tx_service_attachment to tx_extra; registers plugin manager in blockchain

Phase 2 — High Value, Moderate Complexity
  G. HTLC                   (self-contained, no deps)
  H. Auditable Addresses    (small, self-contained)
  A. Aliases                (high user value, medium complexity)

Phase 3 — Token Economy
  B. Native Tokens (non-confidential)
     → Requires hardfork, output type extension, DB schema, wallet scanning

Phase 4 — DeFi Layer
  D. Marketplace            (depends on Phase 1 + Phase 3 assets for token markets)
  F. Ionic Swaps            (depends on Phase 3)
  E. Escrow Contracts       (depends on Phase 1; revisit Monero multisig question)

Phase 5 — Research
  I. Zarcanum / Confidential Assets
     → Only after Phases 1–4 are stable on mainnet
```

---

## 6. File Summary by Feature

### Files to Create (New)

| File                                          | Feature | Source in Zano                       |
| --------------------------------------------- | ------- | ------------------------------------ |
| `src/cryptonote_core/bc_service.h`            | C       | `bc_attachments_service_manager.h`   |
| `src/cryptonote_core/bc_service_manager.cpp`  | C       | `bc_attachments_service_manager.cpp` |
| `src/cryptonote_core/offers_service_basics.h` | D       | `offers_service_basics.h`            |
| `src/cryptonote_core/bc_offers_service.h`     | D       | `bc_offers_service.h`                |
| `src/cryptonote_core/bc_offers_service.cpp`   | D       | `bc_offers_service.cpp`              |
| `src/cryptonote_core/bc_escrow_service.h`     | E       | `bc_escrow_service.h`                |
| `src/wallet/wallet2_escrow.cpp`               | E       | `wallet2_escrow.cpp`                 |
| `tests/unit_tests/aliases_test.cpp`           | A       | —                                    |
| `tests/unit_tests/assets_test.cpp`            | B       | —                                    |
| `tests/unit_tests/htlc_test.cpp`              | G       | —                                    |

### Files Modified (Existing Rackz)

| File                                      | Features      | Nature of Change                                       |
| ----------------------------------------- | ------------- | ------------------------------------------------------ |
| `src/cryptonote_basic/tx_extra.h`         | A B C D E G H | New `tx_extra_field` variant types + tags              |
| `src/cryptonote_basic/cryptonote_basic.h` | A B E G H     | New structs, output types                              |
| `src/cryptonote_config.h` (**red-zone**)  | A B H         | Fee constants, new address prefixes                    |
| `src/cryptonote_core/blockchain.cpp`      | A B C E G     | Validation hooks, service manager integration          |
| `src/blockchain_db/lmdb/db_lmdb.cpp/.h`   | A B           | New LMDB sub-databases                                 |
| `src/wallet/wallet2.cpp`                  | A B D E F G H | Asset tracking, alias resolution, HTLC, offer creation |
| `src/wallet/wallet_rpc_server.*`          | A B D E F G   | New RPC handlers                                       |
| `src/rpc/core_rpc_server.*`               | A B D         | New daemon RPC endpoints                               |
| `src/simplewallet/simplewallet.cpp`       | A             | `@alias` syntax in `transfer` command                  |
| `src/daemon/executor.cpp`                 | C D           | Register service plugins at startup                    |

### Red-Zone Files Touched

| File                      | Feature | Change                                                                 |
| ------------------------- | ------- | ---------------------------------------------------------------------- |
| `src/cryptonote_config.h` | A, B, H | Alias fee constants, asset registration fee, new address prefix values |

---

## 7. Cross-Cutting Observations

### Privacy Implications of Non-Confidential Assets

Rackz inherits Monero's strong privacy (RingCT, Bulletproofs+, CLSAG). Adding
non-confidential asset outputs creates **heterogeneous output sets**: native RKZ
outputs are hidden-amount, while asset outputs would have visible amounts. This
reduces the ring-signature anonymity set for asset outputs — ring members would
be distinguishable by whether they carry asset_id. Mitigation options:

1. Require asset outputs to always use the same ring-size rules as native outputs.
2. Maintain separate global output indices per asset_id (Zano's approach).
3. Long-term: pursue confidential assets (Zarcanum) for asset outputs too.

This is not a blocker for Feature B but must be documented in the security model.

### Serialization Versioning

Zano uses `DEFINE_SERIALIZATION_VERSION` / `BEGIN_VERSIONED_SERIALIZE` macros
for forward-compatible structs. Rackz does not have these macros. When transplanting
Zano structs that use versioned serialization (especially `asset_descriptor_base`
with its v0/v1/v2 versioning), either:

- Introduce the versioning macros (worth doing for new complex structs), or
- Simplify to a single version (acceptable for v1 implementation).

### Hardfork Gating

Every feature above introduces new transaction rules. Each must be:

1. Assigned a hardfork version number (`HF_VERSION_*` constant).
2. Rejected at the mempool / consensus layer below that height.
3. Gated in the wallet (don't produce new tx types before the hardfork activates).

This work is ~50–100 lines per feature but is non-negotiable for mainnet safety.

### Testing Requirements (per AGENTS.md yellow/green zone rules)

Each Phase 2–4 feature requires before merge:

- Unit test in `tests/unit_tests/<feature>_test.cpp`
- At minimum: struct serialization round-trip, validation acceptance, validation rejection
- Wallet-layer features: run existing wallet tests after changes
- Consensus-layer features: chaingen scenario in `tests/core_tests/`
