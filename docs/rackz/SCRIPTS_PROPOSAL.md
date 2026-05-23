# Proposal: LLM Guardrail & Dev-Ex Scripts for Rackz

> Reference model: `go-llm-project-structure`
> Target: `rackz` C++ blockchain daemon (CMake/Make, ~174 k LOC)
> Goal: Adapt the Go reference's guardrail, linting, and LLM-flow patterns to modern C++ conventions.
>
> **Confirmed facts from second-pass codebase investigation:**
>
> - Indent: **2-space** (verified `blockchain.cpp`, `wallet2.cpp`, `crypto.cpp`)
> - `.editorconfig` exists but is **empty** — needs population, not creation
> - No `Cargo.toml` at project level — Rust only in `contrib/depends` cross-compilation toolchain
> - `src/seraphis_crypto/` is a stub (`dummy.cpp` only) — must be red-zoned
> - `src/wallet/wallet2.cpp` is 15,417 lines — tooling must handle large files

---

## 1. What the Reference Does Well (Language-Agnostic)

| Pattern                                         | Value                                                                                      |
| ----------------------------------------------- | ------------------------------------------------------------------------------------------ |
| **Centralised scripts in `scripts/ci/`**        | One source of truth; local hooks and GitHub Actions call the same files                    |
| **Thin `.githooks/` wrappers**                  | Easy to install (`git config core.hooksPath .githooks`); logic lives in versioned scripts  |
| **Stage-based script numbering**                | `pre-commit/02-lint.sh`, `pre-push/03-coverage.sh` — explicit ordering                     |
| **`AGENTS.md` as LLM constitution**             | Role, architecture rules, style, testing, security, complexity, coupling — all in one file |
| **`.coupling.yml` / `.gremlins.yml`**           | Config-driven thresholds; scripts read them, not hard-coded                                |
| **LLM hooks (`scripts/llm/hooks/`)**            | Pre-write arch-compliance, post-write test suggestions, context injection                  |
| **Platform configs (`scripts/llm/platforms/`)** | Per-IDE setup (Windsurf, Cursor, Copilot) via YAML-driven generator                        |
| **`Taskfile.yml` / `task`**                     | Modern task runner; cross-platform, self-documenting                                       |

---

## 2. C++ Adaptation Map

### 2.1 Linting & Formatting Stack

| Go tool                | C++ equivalent                                               | Purpose                                                                                                                          |
| ---------------------- | ------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------- |
| `gofmt` / `goimports`  | **`clang-format`**                                           | Automatic code formatting                                                                                                        |
| `golangci-lint`        | **`clang-tidy`** + **`cppcheck`**                            | Static analysis, bugprone checks                                                                                                 |
| `go vet`               | **`clang-tidy` (readability, bugprone)** + **`cppcheck`**    | Compiler-like diagnostics                                                                                                        |
| `govulncheck`          | **Dependabot** (GHA versions) + **submodule drift check**    | Dependency vulnerability scanning — no project-level `Cargo.toml`; Rust is only in `contrib/depends` cross-compilation toolchain |
| `gocyclo` / `gocognit` | **`clang-tidy` (readability-function-cognitive-complexity)** | Complexity limits                                                                                                                |
| `go test -race`        | **`ThreadSanitizer`** / **`AddressSanitizer`**               | Runtime race / memory detection                                                                                                  |
| `go test -cover`       | **`gcov`** / **`lcov`**                                      | Coverage reporting                                                                                                               |

**Proposed configs:**

- `.clang-format` — **2-space indent** (confirmed), 120 col limit, `BreakBeforeBraces: Attach`, `AlwaysBreakTemplateDeclarations: Yes`, `PointerAlignment: Left`
- `.clang-tidy` — Curated checks (not `*`). Key categories: `bugprone-*`, `cppcoreguidelines-*`, `readability-*`, `performance-*`, `modernize-*`, `clang-analyzer-*`. Excludes: `cppcoreguidelines-avoid-magic-numbers` (blockchain constants are intentional), `readability-named-parameter` (legacy code), `readability-function-cognitive-complexity` on `wallet2.cpp` until it is refactored.

### 2.2 Build & Test Orchestration

| Go pattern         | C++ adaptation                                                                           |
| ------------------ | ---------------------------------------------------------------------------------------- |
| `go build ./...`   | `cmake --build build --target all`                                                       |
| `go test ./...`    | `ctest --output-on-failure` (or `make test`)                                             |
| `task ci`          | `task ci` (using [Taskfile](https://taskfile.dev)) or keep `make ci` for consistency     |
| Coverage threshold | `gcov` → `lcov` → parse total line coverage, compare against `${COVERAGE_THRESHOLD:-60}` |

**Note:** Rackz already has a `Makefile`. We can either:

- (A) Add `ci` / `lint` / `format-check` targets to the existing `Makefile`
- (B) Introduce `Taskfile.yml` alongside `Makefile` and slowly migrate

**Decision: (A)** — the existing `Makefile` is already the muscle memory for every Monero dev. Add `scripts/ci/` as the implementation layer; keep `Makefile` targets as thin wrappers. Open question 3 resolved.

---

## 3. Proposed `scripts/` Directory Structure

```
scripts/
  ci/
    ci.sh                    # Single entrypoint: run everything (local + CI)
    pre-commit/
      00-file-quality.sh     # Trailing whitespace, merge conflicts, large files, EOF newline
      01-format-check.sh     # clang-format --dry-run (fail on drift)
      02-clang-tidy.sh       # Run clang-tidy on changed files only
      03-cppcheck.sh         # Optional fast cppcheck on changed files
      04-crypto-guardrail.sh # Forbid AI from touching crypto/ consensus/ without explicit override
      05-secrets.sh          # Detect private keys, mnemonic words, hardcoded constants in commits
      06-build-smoke.sh      # cmake --build quick smoke test (debug, minimal targets)
    pre-push/
      00-build.sh            # Full release build
      01-tests.sh            # ctest --output-on-failure
      02-coverage.sh         # gcov/lcov threshold check
      03-sanitizers.sh       # Build & run tests with ASan + UBSan (optional, slow)
      04-outdated-deps.sh    # Check contrib/depends for known CVEs / submodule drift
      05-arch-guardrail.sh   # Enforce src/ dependency rules (crypto pure, consensus no wallet, etc.)
      06-complexity.sh       # clang-tidy complexity check + custom script for McCabe-like thresholds
    commit-msg/
      00-conventional-commit.sh  # Validate: "subdir: description" (Monero convention)
      01-length.sh             # Subject ≤72 chars, body wrap
    prepare-commit-msg/
      00-branch-prefix.sh    # Optionally inject branch name / ticket ID
  llm/
    llm-setup.sh             # Platform setup (Windsurf, Cursor, Copilot, Claude)
    hooks/
      pre-write-arch-compliance.sh   # Block LLM from importing wallet/ into crypto/, etc.
      pre-write-crypto-gate.sh       # Extra confirmation for crypto/, ringct/, consensus/ edits
      post-write-test-suggestion.sh  # If new .cpp has no _test.cpp / _tests.cpp, suggest one
      post-write-doc-reminder.sh     # If public header changed without doc update, warn
      pre-read-context-injection.sh  # Inject AGENTS.md context before LLM reasoning
    platforms/
      windsurf/
        config.yaml          # Folders, AGENTS.md content, rules/, skills/, hooks.json
      cursor/
        config.yaml
      copilot/
        config.yaml
      claude/
        config.yaml
      continue/
        config.yaml
    rules/
      # Generated by llm-setup.sh per-platform; source of truth is AGENTS.md sections
  setup/
    install-hooks.sh         # git config core.hooksPath .githooks
    install-deps.sh        # Check for clang-format, clang-tidy, cppcheck, cmake, ccache
```

---

## 4. Proposed `.githooks/` Structure

Thin wrappers that delegate to `scripts/ci/<stage>/`:

```
.githooks/
  pre-commit      → runs scripts/ci/pre-commit/*.sh in order
  pre-push        → runs scripts/ci/pre-push/*.sh in order
  commit-msg      → runs scripts/ci/commit-msg/*.sh "$1"
  prepare-commit-msg → runs scripts/ci/prepare-commit-msg/*.sh "$1"
  pre-rebase      → protect master branch
```

**Install:**

```bash
./scripts/setup/install-hooks.sh
# OR simply:
git config core.hooksPath .githooks
chmod +x .githooks/*
```

---

## 5. Rackz-Specific `AGENTS.md` Outline

The Go reference's `AGENTS.md` is ~15 k words. For Rackz, the structure should be:

````
<investigate_before_answering>
  Read relevant files before answering. Never speculate about consensus, crypto, or tx logic.
</investigate_before_answering>

<default_to_action>
  Implement changes rather than only suggesting. Use tools to discover missing details.
</default_to_action>

<minimal_changes>
  Do not refactor beyond the request. Do not add comments to unchanged code.
  Do not introduce helpers for one-time operations.
</minimal_changes>

<action_safety>
  Reversible edits are fine. Confirm before: deleting files, force-pushing, modifying consensus
  parameters (cryptonote_config.h, hardforks/), or touching ringct/ / crypto/.
</action_safety>

---

<role>
  Senior C++ engineer specialising in blockchain consensus, cryptography, and P2P networking.
  You write secure, deterministic, testable C++17. You never cut corners on consensus safety.
</role>

<architecture_rules>
  ## Layer Boundaries in src/

  | Layer | Purity Rule |
  |-------|-------------|
  | `src/crypto/` | Must be pure math / primitives. No blockchain, wallet, or net imports. |
  | `src/ringct/` | Depends only on `src/crypto/`. No wallet, protocol, or daemon logic. |
  | `src/cryptonote_basic/` | Tx/block structures + account primitives. No consensus rules, no wallet logic. |
  | `src/cryptonote_core/` | Consensus, tx pool, blockchain. May depend on basic, crypto, ringct, hardforks. No wallet/. |
  | `src/wallet/` | Wallet logic (`wallet2.cpp` is 15,417 lines). Must not import daemon/ or protocol/ internals directly. |
  | `src/seraphis_crypto/` | **Stub module** (in-progress Seraphis). READ-ONLY for AI. No edits without explicit lead sign-off. |
  | `src/net/` | Network abstractions. Must not import consensus logic. |
  | `src/p2p/` | Peer layer. Depends on net/, not on cryptonote_core/ directly. |
  | `src/rpc/` | RPC servers/clients. Adapts core/ and wallet/; must not leak consensus internals. |

  ## Forbidden Crossings (enforced by scripts/ci/pre-push/05-arch-guardrail.sh)
  - `crypto/` importing `wallet/`, `daemon/`, `rpc/`, `protocol/`
  - `ringct/` importing `wallet/`, `daemon/`, `protocol/`
  - `cryptonote_core/` importing `wallet/`
  - `wallet/` importing `daemon/` internals (except public RPC interfaces)
</architecture_rules>

<cpp_style>
  ## C++ Style & Best Practices

  Authoritative references:
  1. C++ Core Guidelines (https://isocpp.github.io/CppCoreGuidelines/)
  2. LLVM Coding Standards (https://llvm.org/docs/CodingStandards.html)
  3. Google C++ Style Guide (exceptions: 2-space indent, 120 cols, exceptions used in project)

  Core expectations:
  - Format: clang-format (`.clang-format` in repo root)
  - RAII over manual new/delete
  - `std::vector` / `std::string` — no raw ownership without justification
  - Error handling: return `bool` + out-param or `std::optional` / `expected` where available
  - Thread safety: document preconditions; use `epee::sync` primitives where project standard
  - No `using namespace std;` in headers
  - Macros minimised; prefer `constexpr`, `enum class`, templates
</cpp_style>

<testing>
  ## Testing

  - Unit tests: `tests/unit_tests/` (gtest)
  - Core tests: `tests/core_tests/` (consensus simulation)
  - Functional: `tests/functional_tests/` (Python against regtest daemon)
  - Fuzz: `tests/fuzz/` — run with `make fuzz`
  - Crypto: `tests/crypto/` — deterministic, no random seeds without fixture

  Guidelines:
  - New logic → new unit test in `tests/unit_tests/<module>_test.cpp`
  - Consensus changes → update `tests/core_tests/` or add a `chaingen` scenario
  - Coverage target: 60%+ (project baseline), 80%+ on crypto/ and ringct/
</testing>

<ci_checks>
  ## CI & Quality Checks

  Local entrypoints:
  ```bash
  make format-check   # clang-format --dry-run
  make lint           # clang-tidy (curated checks)
  make ci             # full pipeline
````

Git hooks:

- **pre-commit**: format check, clang-tidy (changed files), file quality, crypto-gate, secrets scan
- **pre-push**: full build, tests, coverage, sanitizer smoke, arch-guardrail, complexity
- **commit-msg**: "subdir: description" format, 72-char subject limit
  </ci_checks>

<security>
  ## Security Rules (Always Apply)

- NEVER hardcode keys, mnemonics, or test seeds in source
- NEVER modify `src/crypto/` or `src/ringct/` without explicit human + cryptographic review
- NEVER change consensus parameters (`cryptonote_config.h`, `hardforks/`) without a proposal doc
- All user-facing input (RPC, P2P, wallet CLI) must be length-checked and bounded
- Logging: never log private view keys, spend keys, or decrypted tx amounts
- Prefer `memwipe` / `OPENSSL_cleanse` for sensitive buffers (project convention)
  </security>

<llm_guardrails>

## LLM Self-Guardrails

- **Red zone directories** (`src/crypto/`, `src/ringct/`, `src/seraphis_crypto/`, `src/cryptonote_core/consensus*`,
  `src/hardforks/`, `src/cryptonote_config.h`): LLM may READ but must not WRITE without
  explicit user confirmation on every edit.
- **Yellow zone** (`src/wallet/`, `src/rpc/`, `src/p2p/`): LLM may write, but must run tests
  and report results before claiming completion.
- **Green zone** (`tests/`, `docs/`, `scripts/`, `contrib/`): Normal edit flow.
- **Disclosure**: If code was AI-generated, the LLM must note this in its response so the
  committer can add `Co-authored-by: AI` or an appropriate note in the PR description.
  </llm_guardrails>

````

---

## 6. Proposed New / Updated Config Files

| File | Status | Action |
|------|--------|--------|
| `.clang-format` | **Missing** | Create LLVM-based config (2-space indent, 120 cols, `BreakBeforeBraces: Attach`) |
| `.clang-tidy` | **Missing** | Replace the brute-force `-checks=*` in CMake with a curated config |
| `.editorconfig` | **Exists but EMPTY** | Populate (C++: 2-space; CMake/Make: tab; Shell/YAML: 2-space) — do NOT recreate |
| `.githooks/` | **Missing** | Create directory + install script |
| `scripts/` | **Exists but empty** | Populate with `ci/`, `llm/`, `setup/` subdirs |
| `AGENTS.md` | **Empty** | Write full C++ / blockchain tailored version |
| `SECURITY.md` | **Empty** | Write vulnerability disclosure + AI code policy |

---

## 7. Key Scripts (Detailed)

### `scripts/ci/pre-commit/01-format-check.sh`
```bash
#!/usr/bin/env bash
set -euo pipefail
# Run clang-format --dry-run on changed C++ files; fail if any diff
````

### `scripts/ci/pre-commit/04-crypto-guardrail.sh`

```bash
#!/usr/bin/env bash
# If changed files touch src/crypto/ or src/ringct/, verify that:
# 1. The commit message contains "crypto:" or "ringct:" prefix
# 2. A test file was also modified or added
# 3. No new raw pointer / manual memory management was introduced
```

### `scripts/ci/pre-push/05-arch-guardrail.sh`

```bash
#!/usr/bin/env bash
# Parse #include directives in changed files
# Enforce:
#   src/crypto/*  must not include anything from wallet/, daemon/, rpc/, protocol/
#   src/ringct/*  must not include anything from wallet/, daemon/, protocol/
#   src/cryptonote_core/* must not include wallet/*
#   src/wallet/* must not include daemon/* (except public rpc/ headers)
```

### `scripts/ci/pre-push/06-complexity.sh`

```bash
#!/usr/bin/env bash
# Run clang-tidy with readability-function-cognitive-complexity
# Thresholds per layer:
#   crypto/ : max 15 (must be simple, deterministic)
#   ringct/ : max 20
#   core/   : max 30
#   rpc/ net/ p2p/ : max 40
```

---

## 8. LLM Hooks for C++

Adapted from `scripts/llm/hooks/` in the Go reference:

| Hook                                               | Purpose                             | C++ Implementation                                                                                         |
| -------------------------------------------------- | ----------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `pre-write-arch-compliance.sh`                     | Block forbidden `#include` patterns | `grep '#include'` against changed file, check against `scripts/ci/pre-push/05-arch-guardrail.sh` rules     |
| `pre-write-crypto-gate.sh`                         | Extra friction for crypto/ edits    | If file under `src/crypto/` or `src/ringct/`, require explicit confirmation or `RACKZ_AI_CRYPTO=1` env var |
| `post-write-test-suggestion.sh`                    | Suggest tests for new .cpp          | If new `.cpp` has no matching `tests/*_test.cpp` or `tests/unit_tests/*_test.cpp`, emit suggestion         |
| `post-write-doc-reminder.sh`                       | Doxygen reminder                    | If public header `.h` / `.hpp` changed, check for `                                                        |
| \* @`or`/\*\*` doxygen block on modified functions |
| `pre-read-context-injection.sh`                    | Inject `AGENTS.md` into context     | Print `AGENTS.md` sections relevant to the file being edited                                               |

---

## 9. CI Integration (GitHub Actions)

The existing `.github/workflows/build.yml` should gain steps:

```yaml
- name: format check
  run: ./scripts/ci/pre-commit/01-format-check.sh
- name: clang-tidy
  run: ./scripts/ci/pre-commit/02-clang-tidy.sh
- name: architecture guardrail
  run: ./scripts/ci/pre-push/05-arch-guardrail.sh
- name: coverage threshold
  run: ./scripts/ci/pre-push/02-coverage.sh
```

**Design principle:** The GitHub Actions workflow calls the _same scripts_ as local hooks. One source of truth.

---

## 10. Implementation Roadmap

### Phase 1 — Foundation (immediate)

1. Write `.clang-format` and `.clang-tidy`
2. Create `.editorconfig`
3. Create `scripts/ci/` skeleton + `.githooks/` wrappers
4. Populate `AGENTS.md` with C++ / blockchain content
5. Write `scripts/setup/install-hooks.sh`

### Phase 2 — Local Guardrails

6. Implement `pre-commit` scripts: file quality, format check, clang-tidy (changed files), secrets scan
7. Implement `commit-msg` script: Monero-style "subdir: description" validation
8. Add `Makefile` targets: `make format`, `make format-check`, `make lint`, `make ci`

### Phase 3 — Pre-Push & Architecture

9. Implement `pre-push` scripts: build, tests, coverage, arch-guardrail, complexity
10. Add CI jobs that reuse the same scripts

### Phase 4 — LLM Flow

11. Create `scripts/llm/` with platform configs for Windsurf / Cursor / Claude
12. Implement `llm-setup.sh`
13. Add LLM hooks: crypto-gate, arch-compliance, test suggestions

### Phase 5 — Hardening

14. Populate `SECURITY.md`, `ROADMAP.md`, `CHANGELOG.md`
15. Add Dependabot / submodule update automation
16. Evaluate `cppcheck`, `include-what-you-use`, `codespell` for CI

---

## 11. Risk & Mitigation

| Risk                                             | Mitigation                                                                                  |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------- |
| `clang-format` on 174 k LOC creates massive diff | Run once in a dedicated "style" commit; exempt from blame via `.git-blame-ignore-revs`      |
| Existing devs resist new hooks                   | Make hooks **advisory** first (`warn` not `die`); flip to enforcing after 2-week grace      |
| `clang-tidy` is slow on full build               | Pre-commit runs only on _changed_ files; full run stays in pre-push / CI                    |
| crypto-gate too noisy                            | Gate only applies to AI-assisted edits; human commits bypass via `--no-verify` (documented) |
| LLM hooks not supported by all IDEs              | Provide manual `AGENTS.md` copy-paste instructions; hooks are progressive enhancement       |

---

## 12. Open Questions for You

1. **Indent style**: ~~Confirm?~~ **Confirmed: 2-space** (verified in second-pass investigation)
2. **Column limit**: 120 is common for C++; keep or prefer 100/80?
3. **Task vs Make**: ~~Add `Taskfile.yml`?~~ **Decided: extend `Makefile`** (lower friction for existing contributors)
4. **Coverage target**: 60% is realistic for legacy C++; target for crypto/ and ringct/?
5. **Red-zone enforcement**: Should AI literally refuse to edit `crypto/` / `ringct/` unless explicitly told, or just warn loudly?
6. **Platform priority**: Which LLM IDEs does your team use? (Windsurf, Cursor, Copilot, Claude Code, Continue...)

Once you confirm these, I can begin implementing Phase 1.
