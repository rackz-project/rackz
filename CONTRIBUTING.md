# Contributing to Rackz

Thanks for your interest in contributing to Rackz.

Rackz is a privacy-focused Monero fork. Contributions that add features, fix bugs, or improve tooling are welcome, provided they do not weaken consensus correctness, cryptographic safety, or user privacy.

## Before You Start

- Search existing issues and pull requests before opening a new one.
- For anything touching consensus, cryptographic code, or hardfork parameters — open an issue to discuss the proposal **before** writing code. These changes require human cryptographic review regardless of the implementation quality.
- Keep changes focused. Avoid mixing feature work with unrelated refactors.

## Development Setup

```bash
# Install required tools
make check-deps

# Install git hooks (format check, clang-tidy, crypto guardrail, secrets scan)
make install-hooks

# Build (debug)
make debug

# Run unit + core tests
make debug-test

# Full CI pipeline
make ci
```

See `docs/rackz/` for architecture documentation and the style guide.

## Branch and Commit Guidelines

- Branch from `master`; name branches `feat/<topic>`, `fix/<topic>`, or `chore/<topic>`
- Commit subject format: `<scope>: <description>` (72-character limit)
  - Scope must match the primary directory changed: `wallet`, `rpc`, `p2p`, `cryptonote_core`, `tests`, `scripts`, `docs`, etc.
  - **Red-zone scopes require explicit prefixes**: `crypto:`, `ringct:`, `hardforks:`, `consensus:`
- Write small, logical commits — one concern per commit
- Do not use `--no-verify` to bypass hooks; document why if truly necessary

## Code Style

- Follow `docs/rackz/STYLE_GUIDE.md` — derived directly from the existing codebase
- 2-space indentation, Allman braces, 120-column limit, `snake_case` for functions
- Run `make format-check` before pushing; auto-fix with `make format` when needed
- New logic requires a unit test in `tests/unit_tests/`

## Red-Zone Code (Cryptographic and Consensus Layers)

The following paths require **explicit human review** before any change merges:

| Path | Why |
|------|-----|
| `src/crypto/` | Cryptographic primitives |
| `src/ringct/` | RingCT / Bulletproof implementations |
| `src/seraphis_crypto/` | Next-gen protocol primitives (stub — treat as read-only) |
| `src/hardforks/` | Consensus upgrade heights |
| `src/cryptonote_config.h` | Chain-level constants |

Changes to these paths must:
1. Use the correct commit prefix (`crypto:`, `ringct:`, `hardforks:`, `consensus:`)
2. Include or update test vectors in `tests/`
3. Be reviewed by a maintainer with cryptographic background before merge

## Upstream Monero Changes

When cherry-picking a fix or improvement from [monero-project/monero](https://github.com/monero-project/monero):

1. Apply the upstream commit cleanly (or adapt it minimally)
2. Add an entry to `CHANGELOG.md` under `### Upstream Sync` with the upstream commit hash and subject
3. Use the commit subject format: `sync: <original-subject> (upstream/<short-hash>)`

## Pull Request Guidelines

- Use a clear title matching the commit scope convention
- Describe what changes and why — not how (the diff shows that)
- Link related issues
- Include or point to tests; explain if tests are not applicable
- Update `CHANGELOG.md` under `## [Unreleased]`
- Be responsive to review feedback

## Reporting Bugs

Include:
- What happened vs. what you expected
- Minimal steps to reproduce
- OS, build type (debug/release), and commit hash

For **security vulnerabilities** — see [SECURITY.md](SECURITY.md). Do not open a public issue.

## Questions

Open an issue or discussion before implementing anything non-trivial. Early alignment saves everyone time.
