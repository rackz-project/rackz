#!/usr/bin/env bash
# pre-commit/01-format-check.sh
# Runs clang-format --dry-run on staged C/C++ files.
# Fails if any file would be reformatted (formatting drift).
#
# Requires: clang-format (any version >= 14)
# Config:   .clang-format in repo root

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

if ! command -v clang-format >/dev/null 2>&1; then
  echo "warning: clang-format not found — skipping format check"
  echo "  Install: apt-get install clang-format  OR  brew install clang-format"
  exit 0
fi

if [ ! -f ".clang-format" ]; then
  echo "warning: .clang-format not found in repo root — skipping"
  exit 0
fi

STAGED=$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null | \
         grep -E '\.(cpp|cxx|cc|c|h|hpp|hxx)$' || true)

if [ -z "$STAGED" ]; then
  exit 0
fi

ERRORS=0
while IFS= read -r file; do
  [ -f "$file" ] || continue
  if ! clang-format --dry-run --Werror "$file" 2>/dev/null; then
    echo "error: $file would be reformatted"
    echo "  fix: clang-format -i $file"
    ((ERRORS++)) || true
  fi
done <<< "$STAGED"

if [ "$ERRORS" -gt 0 ]; then
  echo ""
  echo "Run 'make format' to auto-fix all formatting issues."
  exit 1
fi
