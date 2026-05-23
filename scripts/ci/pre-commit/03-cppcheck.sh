#!/usr/bin/env bash
# pre-commit/03-cppcheck.sh
# Fast cppcheck pass on staged C++ files.
# Focuses on definite bugs (null dereference, out-of-bounds, use-after-free).
# Suppressions for known false-positives in the Monero codebase.
#
# Requires: cppcheck >= 2.9

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

if ! command -v cppcheck >/dev/null 2>&1; then
  echo "warning: cppcheck not found — skipping"
  echo "  Install: apt-get install cppcheck  OR  brew install cppcheck"
  exit 0
fi

STAGED=$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null | \
         grep -E '\.(cpp|cxx|cc|c)$' || true)

if [ -z "$STAGED" ]; then
  exit 0
fi

SUPPRESS=(
  "--suppress=missingInclude"
  "--suppress=missingIncludeSystem"
  "--suppress=unmatchedSuppression"
  "--suppress=unusedFunction"
)

ERRORS=0
while IFS= read -r file; do
  [ -f "$file" ] || continue
  output=$(cppcheck \
    --std=c++17 \
    --enable=warning,performance,portability \
    --error-exitcode=1 \
    --quiet \
    "${SUPPRESS[@]}" \
    -I "$ROOT/src" \
    "$file" 2>&1) || {
      echo "error: cppcheck issues in: $file"
      echo "$output"
      ((ERRORS++)) || true
    }
done <<< "$STAGED"

if [ "$ERRORS" -gt 0 ]; then
  exit 1
fi
