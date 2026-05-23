#!/usr/bin/env bash
# pre-commit/05-secrets.sh
# Scans staged diff for hardcoded secrets, private keys, and sensitive patterns.
# Tuned for a Monero/CryptoNote codebase (seed phrases, spend keys, view keys).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

DIFF=$(git diff --cached 2>/dev/null || true)
if [ -z "$DIFF" ]; then
  exit 0
fi

PATTERNS=(
  "spend_key\s*=\s*['\"][0-9a-fA-F]{64}"
  "view_key\s*=\s*['\"][0-9a-fA-F]{64}"
  "seed\s*=\s*['\"][a-z ]{30,}"
  "mnemonic\s*=\s*['\"][a-z ]"
  "-----BEGIN (RSA|EC|OPENSSH|PGP) PRIVATE KEY-----"
  "PRIVATE_KEY\s*=\s*['\"][^'\"]{20,}"
  "API_KEY\s*=\s*['\"][^'\"]{16,}"
  "SECRET\s*=\s*['\"][^'\"]{16,}"
  "password\s*=\s*['\"][^'\"]{8,}"
  "AWS_SECRET_ACCESS_KEY\s*="
  "GITHUB_TOKEN\s*="
)

ERRORS=0
for pattern in "${PATTERNS[@]}"; do
  matches=$(echo "$DIFF" | grep -Pn "^\+" | grep -P "$pattern" || true)
  if [ -n "$matches" ]; then
    echo "error: potential secret detected matching pattern: $pattern"
    echo "$matches" | head -5
    ((ERRORS++)) || true
  fi
done

if [ "$ERRORS" -gt 0 ]; then
  echo ""
  echo "If this is a false positive (e.g. test vector), add an inline suppression comment:"
  echo "  // rackz-secrets-ignore"
  echo "or use git commit --no-verify (document the reason in the PR description)."
  exit 1
fi
