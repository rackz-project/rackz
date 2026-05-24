#!/usr/bin/env bash
# pre-commit/00-file-quality.sh
# Checks trailing whitespace, merge conflict markers, large files, and missing EOF newline.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

ERRORS=0

STAGED=$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null || true)
if [ -z "$STAGED" ]; then
  exit 0
fi

CPP_STAGED=$(echo "$STAGED" | grep -E '\.(cpp|cxx|cc|c|h|hpp|hxx)$' || true)
ALL_STAGED=$(echo "$STAGED" | grep -E '\.(cpp|cxx|cc|c|h|hpp|hxx|cmake|md|yml|yaml|json|sh|txt)$' || true)

if [ -z "$ALL_STAGED" ]; then
  exit 0
fi

while IFS= read -r file; do
  [ -f "$file" ] || continue

  if git show ":$file" 2>/dev/null | grep -Pq '\s+$'; then
    echo "error: trailing whitespace in: $file"
    echo "  fix: sed -i 's/[[:space:]]*$//' $file"
    ((ERRORS++)) || true
  fi

  if git show ":$file" 2>/dev/null | grep -qE '^(<<<<<<<|=======|>>>>>>>)'; then
    echo "error: merge conflict markers in: $file"
    ((ERRORS++)) || true
  fi

  size=$(git cat-file -s ":$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)
  if [ "$size" -gt 1048576 ]; then
    echo "error: file exceeds 1 MB: $file (${size} bytes)"
    echo "  Consider splitting or using Git LFS."
    ((ERRORS++)) || true
  fi

  last_char=$(git show ":$file" 2>/dev/null | tail -c1 | xxd -p 2>/dev/null || true)
  if [ "$last_char" != "0a" ] && [ -n "$last_char" ]; then
    echo "warning: no newline at end of file: $file"
  fi
done <<< "$ALL_STAGED"

if [ "$ERRORS" -gt 0 ]; then
  exit 1
fi
