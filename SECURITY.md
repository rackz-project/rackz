# Security Policy

## Scope

Rackz is a privacy-focused Monero fork. Security vulnerabilities in Rackz may affect:

- **User funds** — wallet key material, spend keys, view keys, transaction amounts
- **Network consensus** — chain splitting, double-spend attacks, block validation bypasses
- **Privacy guarantees** — ring signature linkability, stealth address leakage, RingCT amount exposure
- **Node operation** — remote crash, memory exhaustion, RPC abuse

## Reporting a Vulnerability

**Do not open a public GitHub issue for security vulnerabilities.**

Report privately via email. Include:

- A clear description of the vulnerability
- The affected component (`src/crypto/`, `src/ringct/`, wallet, RPC, P2P, etc.)
- Steps to reproduce or a proof-of-concept
- Affected versions or commit range
- Estimated impact (funds at risk, privacy degradation, network disruption)

We will:

- Acknowledge receipt within **48 hours**
- Provide an initial assessment within **7 days**
- Coordinate a fix and disclosure timeline with the reporter
- Credit the reporter in the changelog unless anonymity is requested

## Security-Critical Code

The following areas require elevated scrutiny. **No AI-assisted change reaches these files without human cryptographic review:**

| Path                      | Sensitivity                                         |
| ------------------------- | --------------------------------------------------- |
| `src/crypto/`             | Cryptographic primitives — Keccak, ed25519, RandomX |
| `src/ringct/`             | RingCT, Bulletproofs, MLSAG/CLSAG signatures        |
| `src/seraphis_crypto/`    | Next-generation protocol primitives (in-progress)   |
| `src/hardforks/`          | Consensus upgrade heights                           |
| `src/cryptonote_config.h` | Chain-level constants                               |

Changes to any of the above must:

1. Begin with the appropriate commit prefix (`crypto:`, `ringct:`, `hardforks:`, `consensus:`)
2. Include a written description of what changes and why
3. Be accompanied by updated test vectors or regression tests in `tests/`
4. Receive explicit human review before merge

## Security Practices

- Sensitive key material is wiped with `memwipe()` — never `memset()` alone
- Constant-time comparison is used for all secret-value comparisons
- All RPC and P2P inputs are length-checked and bounded before processing
- Cryptographic nonces are random — never reused, never sequential
- Secrets are never logged (private view keys, spend keys, decrypted amounts)
- The CI pipeline runs a secrets scan on every commit (`scripts/ci/pre-commit/05-secrets.sh`)

## Upstream Monero Vulnerabilities

If a vulnerability is discovered in upstream [monero-project/monero](https://github.com/monero-project/monero) that also affects Rackz, report it to the Monero team first at their [responsible disclosure process](https://github.com/monero-project/monero/blob/master/SECURITY.md), then notify the Rackz maintainers so a coordinated patch can be applied.
