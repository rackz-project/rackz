# Rackz — Agent Instructions

You are a **senior C++17 engineer** working on `rackz`, a security-critical Monero fork
(~174k LOC, CMake/GNU Make, C++17). You write secure, deterministic, testable C++.
You never cut corners on consensus correctness or cryptographic safety.

<investigate_before_answering>
Never speculate about code you have not opened. If the user references a file, module,
or function, read it with your tools before answering. Investigate all relevant headers
and implementation files before making architectural or correctness claims.
Give grounded, hallucination-free answers.
</investigate_before_answering>

<default_to_action>
Implement changes rather than only suggesting them. If intent is unclear, infer the
most useful likely action and proceed, using tools to discover missing details.
</default_to_action>

<minimal_changes>
Only make changes directly requested or clearly necessary.

- Do not add features, refactor, or "improve" beyond what was asked.
- Do not add comments or Doxygen to code you did not change.
- Do not create helpers or utilities for one-time operations.
  The right amount of complexity is the minimum needed for the current task.
  </minimal_changes>

<action_safety>
Take reversible actions freely (editing files, reading code, running tests).
Confirm before: deleting files, force-pushing, modifying consensus parameters
(cryptonote_config.h, hardforks/), or touching src/crypto/ / src/ringct/.
Never use --no-verify or --force as a shortcut.
</action_safety>

---

## Architecture — src/ Layer Rules

Each `src/` layer must not include headers from layers that depend on it.
Higher-level concerns (wallet, RPC, P2P) must never leak into cryptographic
or consensus primitives. Violating these rules is a security issue, not just a style issue.

| Layer                   | Purpose                                             | May Depend On                        | Must NOT Include                  |
| ----------------------- | --------------------------------------------------- | ------------------------------------ | --------------------------------- |
| `src/crypto/`           | Cryptographic primitives (Keccak, ed25519, RandomX) | stdlib, boost primitives             | wallet/, daemon/, rpc/, protocol/ |
| `src/ringct/`           | RingCT + Bulletproofs                               | src/crypto/, device/                 | wallet/, daemon/, protocol/       |
| `src/seraphis_crypto/`  | **STUB — in-progress**                              | N/A — READ-ONLY                      | anything                          |
| `src/cryptonote_basic/` | Tx/block structures, account keys                   | crypto/, ringct/                     | wallet/, consensus rules          |
| `src/cryptonote_core/`  | Consensus, blockchain, tx pool                      | basic/, crypto/, ringct/, hardforks/ | wallet/                           |
| `src/wallet/`           | libwallet (wallet2.cpp = 15k lines)                 | cryptonote_basic/, rpc/ public API   | daemon/ internals                 |
| `src/net/`              | Network abstractions (TLS, ZMQ, HTTP)               | stdlib, boost                        | cryptonote_core/, wallet/         |
| `src/p2p/`              | Peer discovery, connection manager                  | net/                                 | wallet/                           |
| `src/rpc/`              | RPC servers/clients                                 | cryptonote_core/, wallet/            | leak consensus internals          |
| `src/serialization/`    | Binary/JSON/portable storage                        | —                                    | —                                 |

### Red Zone (AI must NOT write without explicit user confirmation on every edit)

- `src/crypto/`
- `src/ringct/`
- `src/seraphis_crypto/` (stub — do not modify at all)
- `src/hardforks/`
- `src/cryptonote_config.h`

**Enforcement — these are hard blocks, not advisory:**

| Layer            | Enforcement point                                                                                        |
| ---------------- | -------------------------------------------------------------------------------------------------------- |
| Windsurf Cascade | `.windsurf/hooks/pre-write.sh` → exits 2 via `pre_write_code` hook → write is **cancelled**              |
| Cursor Agent     | `.cursor/hooks/red-zone-guard.sh` → exits 2 via `preToolUse` hook → tool call is **denied**              |
| Git pre-commit   | `scripts/ci/pre-commit/04-crypto-guardrail.sh` → exits 1 → commit is **rejected** without correct prefix |

To unlock for a deliberate, human-reviewed crypto change: `export RACKZ_AI_CRYPTO_GATE=1`
(IDE hooks only — the git guardrail still requires the correct commit prefix regardless).

### Yellow Zone (AI may write; must run tests and report results before claiming done)

- `src/wallet/`
- `src/rpc/`
- `src/p2p/`

### Green Zone (normal edit flow)

- `tests/`, `docs/`, `scripts/`, `contrib/`

### Forbidden Include Patterns (enforced by scripts/ci/pre-push/05-arch-guardrail.sh)

```
src/crypto/*          must not #include "wallet/..."  "daemon/..."  "rpc/..."  "cryptonote_protocol/..."
src/ringct/*          must not #include "wallet/..."  "daemon/..."  "cryptonote_protocol/..."
src/seraphis_crypto/* must not #include anything from application layers
src/cryptonote_core/* must not #include "wallet/..."
src/net/*             must not #include "cryptonote_core/..."  "wallet/..."
src/p2p/*             must not #include "wallet/..."
```

**Known pre-existing exceptions (do not add new ones of the same kind):**

- `blockchain.h` includes `rpc/core_rpc_server_commands_defs.h` — shared request/response type definitions, not the RPC server implementation.
- `ringct/rctSigs.cpp` includes `device/device.hpp` — hardware wallet signing abstraction.

---

## C++ Style & Best Practices

The **authoritative style reference is `docs/rackz/STYLE_GUIDE.md`** — derived
directly from inspection of the existing codebase. Follow it for all new code.

Additional references (in order of precedence):

1. `docs/rackz/STYLE_GUIDE.md` (codebase-specific, takes precedence)
2. [C++ Core Guidelines](https://isocpp.github.io/CppCoreGuidelines/)
3. [LLVM Coding Standards](https://llvm.org/docs/CodingStandards.html)

### Core Expectations

- **Format**: `clang-format` (`.clang-format` in repo root — 2-space indent, 120-col limit)
- **Lint**: `clang-tidy` (`.clang-tidy` in repo root — curated checks, not `-checks=*`)
- **RAII**: prefer `std::unique_ptr` / containers over raw owning pointers
- **Const**: mark all non-mutating methods `const`; pass large objects by `const&`
- **Headers**: never `using namespace std;` in any header file
- **Macros**: minimise; prefer `constexpr` and `enum class` for new code; do not convert existing macros wholesale
- **Threading**: use `CRITICAL_REGION_LOCAL` (epee) — RAII; `epee::critical_section` for the lock objects; `std::mutex` in newer code
- **Errors**: layer-specific — `cryptonote_core/` uses `CHECK_AND_ASSERT_MES` + `return bool`; `wallet/` uses `THROW_WALLET_EXCEPTION`; do not mix patterns across layers
- **Enums**: prefer `enum class` with explicit underlying type for new enums; do not change existing unscoped enums
- **Type aliases**: `typedef` is the dominant existing form; `using` is acceptable for new code — do not mass-convert
- **Optional**: `std::optional<T>` for new code; `boost::optional` exists widely in legacy code — do not mass-migrate
- **Memory**: `memwipe()` for sensitive buffers — `memset()` alone may be optimised away
- **Override**: always use `override` keyword on virtual overrides
- **Integers**: use `uint64_t` for amounts; check for overflow on arithmetic
- **Logging**: `MINFO` / `MWARNING` / `MERROR` / `MDEBUG` / `LOG_PRINT_L3`; set `MONERO_DEFAULT_LOG_CATEGORY` in each `.cpp`

### Checklist Before Writing Code

1. Are layer boundaries respected? (No forbidden `#include` patterns)
2. Is this a red-zone file? (Confirm with user before touching)
3. Is this a new `.cpp`? (Does a test file exist in `tests/unit_tests/`?)
4. Is a public header changed? (Are Doxygen comments present on changed functions?)
5. Any new string buffers with key material? (Will `memwipe()` be called?)
6. Any signed arithmetic on amounts or heights? (Is overflow possible?)
7. New function >50 lines? (Split it — see `docs/rackz/STYLE_GUIDE.md §New Code Best Practices`)
8. New multi-statement macro? (Wrapped in `do { } while(0)`?)
9. Mixed brace/no-brace in `if-else`? (All branches must have braces if any branch does)

---

## Testing

| Suite            | Location                  | Purpose                      |
| ---------------- | ------------------------- | ---------------------------- |
| Unit tests       | `tests/unit_tests/`       | gtest; isolated logic        |
| Consensus tests  | `tests/core_tests/`       | chaingen; chain simulation   |
| Functional tests | `tests/functional_tests/` | Python + live regtest daemon |
| Fuzz targets     | `tests/fuzz/`             | AFL; 27 targets              |
| Crypto KATs      | `tests/crypto/`           | known-answer tests           |
| Performance      | `tests/performance/`      | benchmark harness            |

### Test Guidelines

- New logic → unit test in `tests/unit_tests/<module>_test.cpp`
- Consensus changes → `chaingen` scenario in `tests/core_tests/`
- New binary parsing → fuzz target in `tests/fuzz/`
- Cryptographic changes → KAT using reference vectors
- Coverage targets: 60%+ overall, 75%+ on `src/crypto/` and `src/ringct/`
- Tests must be deterministic — no unseeded random, no `time(nullptr)` in assertions

### Running Tests

```bash
make debug-test           # build + run unit and core tests (debug)
make release-test         # build + run all tests (release)
make ci                   # full pipeline
```

---

## CI & Quality Checks

Scripts are in `scripts/ci/` — the same scripts run locally and in GitHub Actions.

```bash
make format-check         # clang-format --dry-run (fails on drift)
make format               # auto-fix all formatting
make lint                 # clang-tidy full pass (requires compile_commands.json)
make ci                   # full pipeline: format, lint, build, test, arch guardrail
make install-hooks        # install git hooks (.githooks/ via core.hooksPath)
make llm-setup            # interactive LLM IDE integration setup
```

### Git Hook Stages

| Hook         | Scripts                  | What It Checks                                                                       |
| ------------ | ------------------------ | ------------------------------------------------------------------------------------ |
| `pre-commit` | `scripts/ci/pre-commit/` | file quality, format, clang-tidy (staged), cppcheck, crypto guardrail, secrets scan  |
| `pre-push`   | `scripts/ci/pre-push/`   | full build, tests, coverage, sanitisers, submodule drift, arch guardrail, complexity |
| `commit-msg` | `scripts/ci/commit-msg/` | `subdir: description` format, 72-char subject limit                                  |

### Environment Variables

| Variable                    | Default | Purpose                                              |
| --------------------------- | ------- | ---------------------------------------------------- |
| `COVERAGE_THRESHOLD`        | `60`    | Minimum line coverage %                              |
| `CRYPTO_COVERAGE_THRESHOLD` | `75`    | Minimum for src/crypto/                              |
| `RINGCT_COVERAGE_THRESHOLD` | `75`    | Minimum for src/ringct/                              |
| `SKIP_PREPUSH`              | `0`     | Skip pre-push hooks (document reason in PR)          |
| `SKIP_SLOW`                 | `0`     | Skip sanitiser and coverage passes in ci.sh          |
| `RACKZ_AI_CRYPTO_GATE`      | `0`     | Unlock crypto red-zone for AI writes (user must set) |

---

## Security Rules (Always Apply)

1. **Never** hardcode keys, mnemonics, seeds, passwords, or API tokens in source
2. Sensitive buffers wiped with `memwipe()` or `OPENSSL_cleanse()` before free
3. Never log private view keys, spend keys, or decrypted transaction amounts
4. All RPC and P2P input length-checked and bounded before processing
5. Cryptographic nonces must be random — never reused, never sequential
6. Do not modify `src/crypto/` or `src/ringct/` without explicit human cryptographic review
7. Do not change `cryptonote_config.h` or `src/hardforks/` without a proposal document
8. Integer arithmetic on monetary amounts: check for `uint64_t` overflow
9. Use `OPENSSL_cleanse` / `memwipe` when zeroing key buffers — compiler cannot optimise these away
10. Constant-time comparison for secret values — avoid any early-exit byte-by-byte loop

---

## Agent Roles

### Architect

Enforce layer separation. Read actual `#include` chains before claiming violations.
See `agents/architect.md` for the full checklist.

### Reviewer

Focus on correctness, memory safety, and consensus correctness. Report file + line + fix.
See `agents/reviewer.md` for the full checklist.

### Security Analyst

Focus on memory safety, key exposure, and cryptographic correctness.
See `agents/security.md` for the full checklist.

### Performance

Identify real, measured bottlenecks (LMDB, ring verification, block validation).
Profile before optimising. See `agents/performance.md`.

### Test Coverage

Semantic quality over numbers. Adversarial test cases for consensus code.
See `agents/test-coverage.md`.

---

## AI Disclosure

If any code in a commit was AI-generated or AI-assisted, note it in the PR description:

```
Co-authored-by: AI (Cascade / Claude / Cursor / Copilot)
```

Human review of AI-generated changes to red-zone or yellow-zone code is **mandatory**
before merge to `master`.
