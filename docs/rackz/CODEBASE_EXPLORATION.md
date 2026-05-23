# Rackz Codebase Exploration

> Last updated: 2026-05-23 (second pass)

## 1. Origin & State

- **Upstream**: Fork of `monero-project/monero` (BSD-3-Clause)
- **Last sync point**: PR #10645 (Guix 1.5.0 update)
- **Repository size**: ~319 MB total; `src/` ~9.7 MB (~546 C/C++ files, ~174 k LOC)
- **Commit velocity**: ~848 commits since Jan 2025; ~1,223 since Jan 2024
- **Remote**: `https://github.com/rackz-project/rackz.git` (single `master` branch)

## 2. Architecture Overview

```
src/
  blockchain_db/      LMDB-backed blockchain storage
  blockchain_utilities/  Import/export/analyze tools
  checkpoints/      Hard-coded chain checkpoints
  common/           Shared utilities (logging, HTTP, i18n)
  crypto/           Cryptographic primitives (RX, Keccak, etc.)
  cryptonote_basic/ Tx/block structures, account keys
  cryptonote_config.h  Chain parameters (emission, unlock window, etc.)
  cryptonote_core/  Consensus, tx pool, blockchain logic
  cryptonote_protocol/  P2P wire protocol
  daemon/           monerod CLI + RPC
  daemonizer/       Cross-platform service wrapper
  device_trezor/    Trezor HW wallet integration
  hardforks/        Scheduled consensus upgrade heights
  lmdb/             LMDB wrapper
  mnemonics/        BIP-39 / legacy seed word lists
  multisig/         Multisig scheme implementation
  net/              Network abstractions (e2e TLS, ZMQ, HTTP)
  p2p/              Peer discovery, ban lists, connection manager
  ringct/           RingCT / Bulletproofs implementation
  rpc/              Wallet + daemon RPC servers/clients
  serialization/    Binary/JSON/portable storage serializers
  simplewallet/     monero-wallet-cli entry point
  wallet/           libwallet (API, cache, key images)
```

**External deps** (`external/`): `boost/`, `easylogging++/`, `gtest/`, `qrcodegen/`, `randomx/`, `rapidjson/`, `supercop/`

**Git submodules** (`.gitmodules`): `external/randomx` (tevador/RandomX), `external/supercop` (monero-project fork), `external/gtest` (google/googletest)

**Noteworthy `src/` items**:

- `src/seraphis_crypto/` — contains only `dummy.cpp` + `sp_transcript.h`; in-progress Seraphis protocol module. **Red zone for AI edits.**
- `src/wallet/wallet2.cpp` — 15,417 lines; the largest single file. High complexity/maintenance risk.
- `src/cryptonote_core/blockchain.cpp` — 5,622 lines; core consensus, directly includes `hardforks/hardforks.h`.

## 3. Build System

- **Primary**: CMake 3.10+ (`CMakeLists.txt` ~1,055 lines)
- **Wrapper**: GNU Make (`Makefile`) for convenience targets (`debug`, `release`, `depends`)
- **Standards**: C11, C++17 (extensions disabled)
- **Confirmed indent style**: 2-space (verified in `blockchain.cpp`, `wallet2.cpp`, `crypto.cpp`)
- **Features**:
  - Optional `ccache`
  - Optional `clang-tidy` (`USE_CLANG_TIDY_C` / `USE_CLANG_TIDY_CXX`)
  - Optional compilation-time profiler (`-ftime-trace` for Clang)
  - Ninja job pools for parallel link/compile limits
  - Cross-compilation via `contrib/depends` (10+ targets)
  - Reproducible Guix builds (`contrib/guix/`)
  - iOS build variant (`CMakeLists_IOS.txt`)

## 4. CI/CD

Three GitHub Actions workflows in `.github/workflows/`:

| Workflow      | Trigger                              | Platforms / Targets                                                                     |
| ------------- | ------------------------------------ | --------------------------------------------------------------------------------------- |
| `build.yml`   | Push/PR (ignore docs)                | macOS brew, Windows MSYS2, Arch, Debian 11, Ubuntu 22.04/24.04 + tests + source archive |
| `depends.yml` | Push/PR (ignore docs)                | Cross: RISC-V, ARMv8, i686, Win64, macOS x86_64/aarch64, FreeBSD, Android ARMv7/v8      |
| `guix.yml`    | Path-filtered (depends/guix changes) | Reproducible builds for Linux, macOS, Win64, FreeBSD, Android                           |

**Observations**:

- CI is comprehensive but **no static analysis** (clang-tidy, CodeQL, cppcheck) is automated.
- No automated formatting enforcement.
- No dependency vulnerability scanning (Dependabot, cargo-audit for Rust in RandomX).
- No container image publishing despite an existing `Dockerfile`.
- No build artifact signing / attestation.

## 5. Testing

Located in `tests/`:

- **Core tests**: Consensus simulations, block validation, double-spend scenarios
- **Unit tests**: 80+ test suites (gtest-based)
- **Functional tests**: Python scripts (`transfer.py`, `multisig.py`, `rpc_payment.py`, etc.) requiring a live regtest daemon
- **Crypto tests**: Hash/curve arithmetic correctness
- **Fuzz tests**: 27 fuzz targets (`tests/fuzz/`)
- **Performance tests**: Benchmark harness
- **Trezor tests**: HW wallet emulation tests

**Test dependencies**: `requests psutil monotonic zmq deepdiff` (Python)

## 6. Documentation

- `README.md`: Still heavily Monero-branded (refs to getmonero.org, #monero-dev IRC)
- `docs/CONTRIBUTING.md`: Commit message format (`subdir: description`), PGP signing encouraged, rebase-only PRs
- `docs/`: RPC ZMQ schema, URI scheme, portable storage spec, release checklist, proxies docs
- **Empty stubs**: `AGENTS.md`, `CHANGELOG.md`, `ROADMAP.md`, `SECURITY.md`

## 7. Security & Supply Chain

- Docker uses `ubuntu:26.04` (non-LTS, very new — consider stability implications)
- No SBOM generation for releases
- No automated secret-scanning or SCA in CI
- `clang-tidy` checks are set to `-checks=*` (brute-force) instead of a curated `.clang-tidy` config
- No `.clang-format` file exists despite CMake support for linting
- **No Dependabot config** — submodules (`randomx`, `supercop`, `gtest`) and GitHub Actions pinned versions drift silently
- **No `Cargo.toml` / `Cargo.lock` in the project root** — Rust is used only inside `contrib/depends` for cross-compilation toolchain; `cargo-audit` not applicable at the project level (but depends-package Rust targets should still be audited)
- **`seraphis_crypto/` is a stub module** (just `dummy.cpp` + one header) — future work; should be explicitly red-zoned in AI guardrails to prevent premature modification

## 8. Developer Experience Gaps

### Missing local guardrails

- **No active githooks**: only default `.sample` files in `.git/hooks/`
- **`.editorconfig` file exists but is empty** — created as a placeholder; needs content for C++/CMake/Shell/YAML consistency
- **No pre-commit framework**: no automated trailing-whitespace, large-file, or basic lint checks
- **No devcontainer / VS Code settings**: modern contributors expect containerized dev envs
- **`wallet2.cpp` is 15,417 lines** — no complexity thresholds enforced; any linting tooling must handle large files gracefully

### Missing AI / LLM guardrails

- `AGENTS.md` is completely empty — should define:
  - Security boundaries (AI must not touch consensus/crypto without human review)
  - Coding conventions for AI-generated patches
  - Required disclosure when submitting AI-assisted code
- `CONTRIBUTING.md` has no AI-generated code policy
- No automated labeling of AI-authored PRs

### Missing project identity

- `FUNDING.yml` still points to `getmonero.org`
- `CHANGELOG.md` empty — should track fork-specific changes and network upgrades
- `ROADMAP.md` empty — should define fork direction and deprecation timeline
- `SECURITY.md` empty — should include vulnerability disclosure and threat model

## 9. Recommended Quick Wins

1. **Populate `AGENTS.md`** with LLM interaction rules, crypto-code review requirements, and forbidden directories.
2. **Add `.githooks/` + install script**:
   - Commit-message regex validation (`subdir: description`)
   - PGP-signing reminder
   - Trailing-whitespace / EOF newline checks
3. **Populate `.editorconfig`** (file exists but is empty) — 2-space C++, tab CMake/Make, 2-space YAML/Shell.
4. **Create `.clang-format`** matching confirmed 2-space indent style; add CI job that fails on formatting drift.
5. **Create `.clang-tidy`** config (curated checks, not `*`) and enable it in CI.
6. **Write `SECURITY.md`** and `ROADMAP.md` with fork-specific content.
7. **Enable Dependabot** for GitHub Actions and submodule updates.
8. **Add CodeQL / static analysis workflow** to CI.
9. **Update `FUNDING.yml` and de-Monero-brand `README.md`** to reflect `rackz-project` identity.
10. **Red-zone `seraphis_crypto/` in `AGENTS.md`** — stub module; no AI edits without explicit lead sign-off.
