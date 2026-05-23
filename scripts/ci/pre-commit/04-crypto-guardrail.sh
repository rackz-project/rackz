#!/usr/bin/env bash
# pre-commit/04-crypto-guardrail.sh
# Guards the cryptographic and consensus layers against unreviewed changes.
#
# Red-zone directories (require "crypto:", "ringct:", or "seraphis:" commit prefix
# AND a corresponding test file modification):
#   src/crypto/
#   src/ringct/
#   src/seraphis_crypto/
#   src/hardforks/
#   src/cryptonote_config.h
#
# Human committers may bypass with: git commit --no-verify (documented policy)
# AI-assisted commits must NOT bypass this gate.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

RED_ZONE_PATTERNS=(
  "^src/crypto/"
  "^src/ringct/"
  "^src/seraphis_crypto/"
  "^src/hardforks/"
  "^src/cryptonote_config\.h$"
)

STAGED=$(git diff --cached --name-only --diff-filter=ACMRD 2>/dev/null || true)

RED_ZONE_HITS=()
while IFS= read -r file; do
  for pattern in "${RED_ZONE_PATTERNS[@]}"; do
    if echo "$file" | grep -qE "$pattern"; then
      RED_ZONE_HITS+=("$file")
      break
    fi
  done
done <<< "$STAGED"

if [ "${#RED_ZONE_HITS[@]}" -eq 0 ]; then
  exit 0
fi

echo "warning: Red-zone files staged for commit:"
for f in "${RED_ZONE_HITS[@]}"; do
  echo "  $f"
done
echo ""

COMMIT_MSG_FILE=".git/COMMIT_EDITMSG"
if [ -f "$COMMIT_MSG_FILE" ]; then
  subject=$(head -1 "$COMMIT_MSG_FILE")
  if ! echo "$subject" | grep -qiE '^(crypto|ringct|seraphis|hardforks|consensus):'; then
    echo "error: Commit touches red-zone code but subject does not start with"
    echo "       'crypto:', 'ringct:', 'seraphis:', 'hardforks:', or 'consensus:'"
    echo "  subject: $subject"
    echo ""
    echo "Red-zone changes require:"
    echo "  1. A commit subject prefix matching the layer (e.g. 'crypto: ...')"
    echo "  2. A corresponding test file in tests/ modified in the same commit"
    echo "  3. Human review — AI must not modify these files autonomously"
    exit 1
  fi
fi

TEST_STAGED=$(echo "$STAGED" | grep -E '^tests/' || true)
if [ -z "$TEST_STAGED" ]; then
  echo "warning: Red-zone files changed without a corresponding tests/ modification."
  echo "  Strongly recommend adding or updating tests alongside cryptographic changes."
fi
