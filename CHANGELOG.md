# Changelog

All notable changes to Rackz are documented here.

**Format** — based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
**Versioning** — [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Each entry is categorised as one of:

- `Added` — new features or files that do not exist in upstream Monero
- `Changed` — modifications to behaviour that already exists in upstream Monero
- `Removed` — code removed from the upstream Monero baseline
- `Fixed` — bug fixes (Rackz-specific)
- `Upstream Sync` — commits cherry-picked or merged from [monero-project/monero](https://github.com/monero-project/monero); includes the upstream commit reference

> **Fork baseline**: Rackz was forked from [monero-project/monero](https://github.com/monero-project/monero).
> Changes below this point diverge from that baseline unless noted as `Upstream Sync`.

---

## [Unreleased]

### Added

- **LLM guardrail infrastructure** — full AI-assisted development governance layer:
  - `AGENTS.md` — LLM constitution covering architecture, C++ style, security rules, and testing
  - `docs/rackz/STYLE_GUIDE.md` — codebase-derived C++ style guide; includes new-code best practices section (function length, brace consistency, comment philosophy, macro discipline, type aliases, naming, return value conventions)
  - `scripts/ci/` — CI pipeline scripts: format-check, clang-tidy, cppcheck, crypto guardrail, arch guardrail, complexity, build, test, coverage, sanitisers, secrets scan
  - `scripts/llm/` — LLM platform hooks and setup: Windsurf, Cursor, Claude config YAMLs; `llm-setup.sh` interactive installer
  - `.windsurf/hooks/` — Cascade hook scripts; `pre_write_code` hook hard-blocks writes to crypto/consensus layers (exit 2)
  - `.cursor/hooks/` — Cursor `preToolUse` hook hard-blocks writes to crypto/consensus layers (exit 2, `failClosed`)
  - `.githooks/` — Git hooks: pre-commit, pre-push, commit-msg, prepare-commit-msg, pre-rebase
  - `Makefile` targets: `format`, `format-check`, `lint`, `ci`, `install-hooks`, `llm-setup`, `check-deps`
  - `.clang-format` — 2-space Allman style, 120-col limit, Left pointer alignment
  - `.clang-tidy` — curated checks for `src/` only

- **Red-zone hard guardrails** — three independent enforcement layers block AI writes to:
  - `src/crypto/`, `src/ringct/`, `src/seraphis_crypto/`, `src/hardforks/`, `src/cryptonote_config.h`
  - Override: `export RACKZ_AI_CRYPTO_GATE=1` (IDE only; git guardrail always requires correct commit prefix)

- **Windsurf workspace configuration** — `.windsurf/` with agents, rules, skills, and workflow definitions

---

## Upstream Sync Log

> Record cherry-picks and merges from [monero-project/monero](https://github.com/monero-project/monero) here.
> Format: `- upstream/<hash> — <subject>` under the date of the sync.

_No upstream syncs recorded yet._

---

[Unreleased]: https://github.com/rackz-project/rackz/compare/HEAD...HEAD
