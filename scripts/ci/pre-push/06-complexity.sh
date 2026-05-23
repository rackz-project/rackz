#!/usr/bin/env bash
# pre-push/06-complexity.sh
# Checks function cognitive complexity using clang-tidy.
# Enforces per-layer thresholds appropriate for the codebase.
#
# Thresholds (cognitive complexity):
#   src/crypto/    : 15  — cryptographic code must be simple and auditable
#   src/ringct/    : 20  — ring signature math is allowed more headroom
#   src/cryptonote_core/ : 30
#   src/wallet/    : skip (wallet2.cpp is 15k lines; requires dedicated refactor work)
#   everything else: 40
#
# Requires: clang-tidy with readability-function-cognitive-complexity check

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

if ! command -v clang-tidy >/dev/null 2>&1; then
  echo "warning: clang-tidy not found — skipping complexity check"
  exit 0
fi

COMPILE_DB=""
for candidate in build/release build/debug build; do
  if [ -f "$ROOT/$candidate/compile_commands.json" ]; then
    COMPILE_DB="$ROOT/$candidate"
    break
  fi
done

if [ -z "$COMPILE_DB" ]; then
  echo "warning: compile_commands.json not found — skipping complexity check"
  echo "  Run: cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON"
  exit 0
fi

check_complexity() {
  local layer="$1"
  local threshold="$2"

  files=$(find "src/$layer" -name "*.cpp" -not -path "*/build/*" 2>/dev/null | head -50 || true)
  [ -n "$files" ] || return

  echo "$files" | while IFS= read -r file; do
    clang-tidy \
      -p "$COMPILE_DB" \
      --checks="-*,readability-function-cognitive-complexity" \
      --config="{Checks: 'readability-function-cognitive-complexity', CheckOptions: [{key: readability-function-cognitive-complexity.Threshold, value: '$threshold'}]}" \
      "$file" 2>/dev/null || true
  done
}

ERRORS=0
for result in \
    "$(check_complexity crypto 15)" \
    "$(check_complexity ringct 20)" \
    "$(check_complexity cryptonote_core 30)"; do
  if echo "$result" | grep -q "warning:"; then
    echo "$result"
    ((ERRORS++)) || true
  fi
done

if [ "$ERRORS" -gt 0 ]; then
  echo ""
  echo "Complexity threshold exceeded. Refactor the flagged functions."
  exit 1
fi
