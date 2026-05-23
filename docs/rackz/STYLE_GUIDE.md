# Rackz C++ Style Guide

This guide documents the _actual_ conventions observed in the rackz codebase.
It is derived from inspection of the source — not aspirational targets.
Follow these conventions for all new code so it is indistinguishable from the
surrounding code.

---

## File Structure

### Header files

```cpp
// Copyright (c) 2014-2024, The Monero Project
// ...standard BSD licence block...

#pragma once                 // Always #pragma once, never #ifndef guards

// System / STL headers first
#include <vector>
#include <unordered_map>

// Boost headers
#include <boost/optional.hpp>

// Project headers (no leading path — relative or via include_dirs)
#include "span.h"
#include "crypto/hash.h"
#include "cryptonote_basic/cryptonote_basic.h"
```

### Implementation files

```cpp
// ...licence block...

// System / STL
#include <algorithm>
#include <cstdio>

// Boost
#include <boost/filesystem.hpp>

// Project (own header first, then dependencies)
#include "blockchain.h"
#include "include_base_utils.h"
#include "cryptonote_basic/cryptonote_basic_impl.h"

// Set the log category for this translation unit
#undef MONERO_DEFAULT_LOG_CATEGORY
#define MONERO_DEFAULT_LOG_CATEGORY "blockchain"
```

**Rules:**

- `#pragma once` in every header. No `#ifndef`/`#define` guards.
- In `.cpp` files: system → boost → project includes, in that loose order.
- Set `MONERO_DEFAULT_LOG_CATEGORY` near the top of every `.cpp` that logs.

---

## Naming Conventions

| Construct               | Style                        | Examples                                               |
| ----------------------- | ---------------------------- | ------------------------------------------------------ |
| Classes                 | `PascalCase`                 | `Blockchain`, `HardFork`, `BlockchainDB`               |
| Structs (POD / data)    | `snake_case_t`               | `output_data_t`, `tx_data_t`, `txpool_tx_meta_t`       |
| Exception classes       | `UPPER_SNAKE_CASE`           | `DB_EXCEPTION`, `BLOCK_DNE`, `TX_DNE`, `OUTPUT_DNE`    |
| Functions / methods     | `snake_case`                 | `get_blocks`, `have_tx`, `scan_outputkeys_for_indexes` |
| Member variables        | `m_` prefix + `snake_case`   | `m_db`, `m_blockchain_lock`, `m_db_sync_mode`          |
| Local variables         | `snake_case`                 | `top_block`, `cumulative_weight`                       |
| Namespaces              | `snake_case` / single word   | `cryptonote`, `crypto`, `tools`, `rct`                 |
| Free constants / macros | `UPPER_SNAKE_CASE`           | `MONERO_DEFAULT_LOG_CATEGORY`, `MERROR_VER`            |
| Type aliases            | `snake_case` (via `typedef`) | `ring_signature`, `difficulty_type`                    |

---

## Brace and Indentation Style

**Allman style** — opening brace on its own line for functions, classes,
namespaces, and control flow.

```cpp
bool Blockchain::have_tx(const crypto::hash &id) const
{
  LOG_PRINT_L3("Blockchain::" << __func__);
  CRITICAL_REGION_LOCAL(m_blockchain_lock);
  return m_db->tx_exists(id);
}

namespace cryptonote
{
  struct txout_to_key
  {
    txout_to_key(): key() { }
    crypto::public_key key;
  };
}  // namespace cryptonote
```

- **Indent**: 2 spaces. No tabs.
- **Column limit**: 120 characters (`.clang-format` enforces this).
- **Function separators**: `//---...` lines are used in some files between
  function definitions — follow the local file style.
- **Namespace close**: `}  // namespace foo` comment on closing brace.

---

## Type Aliases

The codebase uses `typedef` extensively. Do not change existing typedefs.
New code may use `using` for type aliases (C++17) but `typedef` is equally
acceptable and is the dominant form in this codebase.

```cpp
// existing codebase style — both are fine
typedef std::vector<crypto::signature> ring_signature;
typedef boost::variant<txin_gen, txin_to_key> txin_v;

// C++17 style, acceptable for new code
using ring_signature = std::vector<crypto::signature>;
```

---

## Enums

The codebase has both old-style `enum` (dominant in core) and `enum class`
(used in newer files: `relay_method`, `relay_category`, `message_type`).

- **Existing unscoped enums**: do not change.
- **New enums**: prefer `enum class` with an explicit underlying type.

```cpp
// existing style (do not change)
enum blockchain_db_sync_mode { db_defaultsync, db_async };

// new code style
enum class relay_method : std::uint8_t { none, local, fluff, stem };
```

---

## Optional Values

Both `boost::optional` (legacy, ~336 uses in src/) and `std::optional`
(C++17, used in newer code) are present.

- **New code**: use `std::optional<T>`.
- **Existing `boost::optional`**: do not mass-migrate; leave in place.

```cpp
// new code
std::optional<output_data_t> get_output(uint64_t amount, uint64_t index) const;

// legacy — leave as-is
boost::optional<crypto::hash> get_block_hash(uint64_t height) const;
```

---

## Error Handling

Error handling is **layer-specific**. Do not change the dominant pattern for
the layer you are in.

### `src/cryptonote_core/` — CHECK_AND_ASSERT_MES + return bool

```cpp
bool Blockchain::init(BlockchainDB* db, ...)
{
  CHECK_AND_ASSERT_MES(db != nullptr, false, "null BlockchainDB passed to init");
  CHECK_AND_ASSERT_MES(db->is_open(), false, "BlockchainDB not open");
  // ...
  return true;
}
```

`CHECK_AND_ASSERT_MES(cond, retval, message)` — logs the message and returns
`retval` if `cond` is false.

`CHECK_AND_ASSERT_THROW_MES(cond, message)` — throws on failure; used for
catastrophic/unrecoverable conditions.

### `src/wallet/` — THROW_WALLET_EXCEPTION

```cpp
THROW_WALLET_EXCEPTION_IF(!r, error::wallet_internal_error, "Failed to parse ...");
```

Wallet code uses exceptions widely. `THROW_WALLET_EXCEPTION` and
`THROW_WALLET_EXCEPTION_IF` are the idiomatic form.

### RPC / general — bool + error string

RPC handlers typically fill a `res.status` / `res.error` field and return bool.

### Re-throwing

Catastrophic DB errors are caught and re-thrown with logging:

```cpp
catch (const std::exception& e)
{
  LOG_ERROR("Unrecoverable DB error: " << e.what());
  throw;
}
```

---

## Logging

Logging uses **easylogging++** via epee macros. Each `.cpp` file sets its
log category near the top:

```cpp
#undef MONERO_DEFAULT_LOG_CATEGORY
#define MONERO_DEFAULT_LOG_CATEGORY "blockchain"
```

| Macro                 | Level   | Use                                 |
| --------------------- | ------- | ----------------------------------- |
| `MDEBUG(msg)`         | debug   | Verbose internal state              |
| `MINFO(msg)`          | info    | Normal operation events             |
| `MWARNING(msg)`       | warning | Recoverable unexpected conditions   |
| `MERROR(msg)`         | error   | Errors worth operator attention     |
| `MGINFO(msg)`         | info    | Global info (no category prefix)    |
| `MGINFO_GREEN(msg)`   | info    | Highlighted success (e.g. reorg)    |
| `LOG_PRINT_L3(msg)`   | level 3 | Fine-grained trace (function entry) |
| `MCERROR("cat", msg)` | error   | Error in a specific category        |

**Never log** private view keys, spend keys, decrypted amounts, or mnemonics.

---

## Threading and Locking

```cpp
// Lock object (typically a private member)
mutable epee::critical_section m_blockchain_lock;

// RAII acquisition (preferred — unlocks on any exit, including exceptions)
CRITICAL_REGION_LOCAL(m_blockchain_lock);

// Acquire a second lock (avoids redefining the same variable name)
CRITICAL_REGION_LOCAL1(m_tx_pool);

// std::mutex is also used in newer code
std::mutex m_txpool_notifier_mutex;
std::lock_guard<std::mutex> lock(m_txpool_notifier_mutex);
```

- Always prefer `CRITICAL_REGION_LOCAL` over manual `lock()` / `unlock()`.
- Document locking preconditions in comments: `// Requires m_blockchain_lock held`.
- Never acquire locks in alphabetical order without documenting the intended acquisition order.

---

## Memory and Key Material

```cpp
// Sensitive key material: use epee's mlocked scrubbed wrapper
using secret_key = epee::mlocked<tools::scrubbed<ec_scalar>>;

// Clearing a key buffer: always memwipe(), never memset() alone
// memset() can be optimised away by the compiler; memwipe() uses volatile writes
memwipe(key_buf, sizeof(key_buf));
```

- Use `epee::mlocked<tools::scrubbed<T>>` for long-lived key material.
- Call `memwipe()` on stack buffers before return if they contained key data.
- `OPENSSL_cleanse()` is an alternative for OpenSSL-allocated key buffers.

---

## Serialization

Structs that are serialized use epee macros inside the struct definition:

```cpp
struct txout_to_tagged_key
{
  crypto::public_key key;
  crypto::view_tag view_tag;

  BEGIN_SERIALIZE_OBJECT()
    FIELD(key)
    FIELD(view_tag)
  END_SERIALIZE()
};
```

Key-value (JSON/RPC) serialization uses `KV_SERIALIZE`:

```cpp
KV_SERIALIZE(amount)
KV_SERIALIZE(key_image)
```

Do not add serialization macros to classes that are not serialized.

---

## Key Epee Macros

| Macro                                  | Purpose                                                |
| -------------------------------------- | ------------------------------------------------------ |
| `CHECK_AND_ASSERT_MES(c, r, msg)`      | Assert `c`; log `msg`; return `r` on failure           |
| `CHECK_AND_ASSERT_THROW_MES(c, msg)`   | Assert `c`; throw `std::runtime_error(msg)` on failure |
| `THROW_WALLET_EXCEPTION(e, ...)`       | Throw typed wallet exception (wallet layer only)       |
| `THROW_WALLET_EXCEPTION_IF(c, e, ...)` | Conditional wallet exception                           |
| `AUTO_VAL_INIT(v)`                     | Value-initialise a struct (zero-fills POD)             |
| `CRITICAL_REGION_LOCAL(lock)`          | RAII lock acquisition                                  |
| `CRITICAL_REGION_LOCAL1(lock)`         | RAII lock acquisition (second lock in same scope)      |

---

## Namespaces

- All core types live in `namespace cryptonote`.
- Cryptographic primitives live in `namespace crypto`.
- Wallet code lives in `namespace tools`.
- RingCT lives in `namespace rct`.
- `using namespace epee;` is acceptable in `.cpp` files (used in rpc/).
- Never `using namespace std;` in any header file.
- Never `using namespace std;` or `using namespace boost;` in `.cpp` files.

---

## Const Correctness

```cpp
// Non-mutating methods must be marked const
bool have_tx(const crypto::hash &id) const;

// Pass large objects by const reference
bool get_blocks(uint64_t start, size_t count,
                std::vector<std::pair<blobdata, block>>& blocks) const;

// Mutable members that are modified even on logically-const operations
mutable epee::critical_section m_blockchain_lock;
mutable crypto::hash m_long_term_block_weights_cache_tip_hash;
```

---

## New Code Best Practices

These rules apply to **all new code** written in rackz. They do not retroactively
apply to existing code and must not be used to trigger reformats of legacy files.
They are derived from a comparison of the Linux Kernel Coding Style with the Rackz
codebase; where the kernel's guidance was language-agnostic and demonstrably safer,
it has been adopted.

### Function Length

New functions should not exceed approximately 50 lines. If a function requires more
than 8 local variables or contains more than 3 levels of nesting, split it.

This rule does not apply to existing functions in `wallet2.cpp`, `blockchain.cpp`,
or other legacy files — only to new functions added from this point forward.

```cpp
// Prefer: one job per function
bool verify_input(const txin_to_key& in, const crypto::hash& tx_prefix_hash) const;
bool verify_output(const tx_out& out, uint64_t height) const;
bool verify_transaction(const transaction& tx) const; // calls the above
```

### Brace Consistency

When any branch of a conditional requires braces, **all** branches get braces.
This prevents the class of bug exemplified by Apple's SSL goto-fail (CVE-2014-1266).

```cpp
// BAD — unsafe if someone adds a statement to the else branch later
if (condition)
  do_this();
else {
  do_that();
  cleanup();
}

// GOOD — both branches explicit
if (condition)
{
  do_this();
}
else
{
  do_that();
  cleanup();
}
```

Single-statement branches with no sibling may omit braces only when the statement
fits on one line and there is no else clause:

```cpp
if (!m_db)
  return false;
```

### Comment Philosophy

Comments explain **what** and **why** — never **how**. Code that needs an explanation
of how it works should be rewritten to be obvious.

```cpp
// BAD — explains the obvious
i++;  // increment i

// BAD — explains mechanism, not purpose
// Loop through the vector checking each hash
for (const auto& h : hashes) { ... }

// GOOD — explains purpose and invariant
// All inputs must have been seen before; reject any ring member that is
// in the future relative to the block we are validating.
for (const auto& ref : ring) { ... }
```

Function-head comments (Doxygen on public headers) state purpose, preconditions,
postconditions, and any consensus invariants the caller must uphold.

### Multi-Statement Macros

New multi-statement macros must be wrapped in `do { } while(0)` to behave correctly
in all contexts (single-statement `if` branches, comma expressions, etc.).

```cpp
// BAD — breaks in: if (cond) MY_MACRO(x); else foo();
#define MY_MACRO(x)  log(x); validate(x)

// GOOD
#define MY_MACRO(x)  do { log(x); validate(x); } while(0)
```

Prefer `constexpr` functions, `static inline` functions, or templates over new
function-like macros wherever possible.

### `inline` Discipline

Do not annotate non-trivial functions with `inline`. Reserve the keyword for
functions of 1–3 lines where it genuinely eliminates call overhead. The compiler
inlines static functions automatically when beneficial.

### Type Alias Readability

For new type aliases, use `using` (C++17) rather than `typedef`. The underlying
type remains visible at the declaration site, which is consistent with the Linux
kernel principle of not obscuring type identity.

```cpp
// Prefer for new code
using block_id_by_height = std::vector<crypto::hash>;

// Acceptable but not preferred for new code
typedef std::vector<crypto::hash> block_id_by_height;
```

Never use a type alias solely to hide that a parameter is a pointer or a struct.

### Naming — Descriptive Over Abbreviated

New function and variable names must be descriptive. Single-letter names are
acceptable only for trivial loop indices (`i`, `j`) and mathematical variables
with established notation (`n`, `r`, `s` in cryptographic contexts).

```cpp
// BAD
uint64_t cnt = 0;
for (size_t i = 0; i < v.size(); ++i) { if (chk(v[i])) ++cnt; }

// GOOD
uint64_t valid_output_count = 0;
for (const auto& output : outputs)
{
  if (is_valid_output(output))
    ++valid_output_count;
}
```

### Return Value Conventions

- **Predicates** (`have_tx`, `is_valid`, `exists`, `check_*`) → return `bool`
- **Action commands** (`add_tx`, `pop_block`, `init`) → return `bool` (true = success) via `CHECK_AND_ASSERT_MES`
- **Never** return `-1` / `0` as an error code in a function that elsewhere returns `bool`
- **Never** mix integer error codes and bool-as-success in the same layer

### One Declaration Per Line

Declare one variable per line. This leaves room for an inline comment explaining
the variable's role and avoids initialisation ambiguity.

```cpp
// BAD
uint64_t amount, fee, change;

// GOOD
uint64_t amount = 0;   // total output value
uint64_t fee    = 0;   // miner fee deducted from inputs
uint64_t change = 0;   // remainder returned to sender
```

---

## Architecture Layer Rules

These are the **actual enforced rules** based on the current codebase.
See `AGENTS.md` for the full table.

| Layer                  | May NOT include                              |
| ---------------------- | -------------------------------------------- |
| `src/crypto/`          | wallet/, daemon/, rpc/, cryptonote_protocol/ |
| `src/ringct/`          | wallet/, daemon/, cryptonote_protocol/       |
| `src/cryptonote_core/` | wallet/                                      |
| `src/net/`             | cryptonote_core/, wallet/                    |
| `src/p2p/`             | wallet/                                      |

**Notes on real-world exceptions that already exist:**

- `blockchain.h` includes `rpc/core_rpc_server_commands_defs.h` — this is a
  shared type definitions header (response/request structs), not the RPC server
  implementation. This is an accepted existing coupling.
- `ringct/rctSigs.cpp` includes `device/device.hpp` — the hardware wallet
  device abstraction used during signing. This is permitted.
- New code must not introduce _new_ upward dependencies beyond these existing
  exceptions.
