#!/usr/bin/env bash
# pre-commit/02-clang-tidy.sh
# Runs clang-tidy on staged C++ files only.
# Uses compile_commands.json if present; otherwise falls back to a minimal
# include path guess (still catches many issues).
#
# Requires: clang-tidy (>= 14), cmake with -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
# Config:   .clang-tidy in repo root

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

if ! command -v clang-tidy >/dev/null 2>&1; then
  echo "warning: clang-tidy not found — skipping"
  echo "  Install: apt-get install clang-tidy  OR  brew install llvm"
  exit 0
fi

if [ ! -f ".clang-tidy" ]; then
  echo "warning: .clang-tidy not found — skipping"
  exit 0
fi

STAGED=$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null | \
         grep -E '\.(cpp|cxx|cc)$' || true)

if [ -z "$STAGED" ]; then
  exit 0
fi

COMPILE_DB=""
for candidate in build/debug build/release build; do
  if [ -f "$ROOT/$candidate/compile_commands.json" ]; then
    COMPILE_DB="$ROOT/$candidate/compile_commands.json"
    break
  fi
done

ERRORS=0
while IFS= read -r file; do
  [ -f "$file" ] || continue

  if [ -n "$COMPILE_DB" ]; then
    clang-tidy -p "$(dirname "$COMPILE_DB")" "$file" 2>/dev/null || {
      echo "error: clang-tidy found issues in: $file"
      ((ERRORS++)) || true
    }
  else
    clang-tidy "$file" -- -std=c++17 -I"$ROOT/src" 2>/dev/null || {
      echo "warning: clang-tidy (no compile_commands.json): $file"
    }
  fi
done <<< "$STAGED"

if [ "$ERRORS" -gt 0 ]; then
  echo ""
  echo "Run 'make lint' for a full clang-tidy pass with all diagnostics."
  exit 1
fi
