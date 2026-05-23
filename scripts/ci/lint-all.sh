#!/usr/bin/env bash
# scripts/ci/lint-all.sh
# Runs clang-tidy on all C++ source files in src/.
# Used by 'make lint'. Requires compile_commands.json for accurate results.
#
# Usage: bash scripts/ci/lint-all.sh [path/to/file.cpp ...]
#   With no arguments: scans all *.cpp / *.cc files under src/
#   With arguments:    scans only the specified files

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

if ! command -v clang-tidy >/dev/null 2>&1; then
  echo "warning: clang-tidy not found — skipping"
  echo "  Install: apt-get install clang-tidy  |  brew install llvm"
  exit 0
fi

if [ ! -f ".clang-tidy" ]; then
  echo "error: .clang-tidy not found in repo root"
  exit 1
fi

COMPILE_DB=""
for candidate in build/debug build/release build; do
  if [ -f "$ROOT/$candidate/compile_commands.json" ]; then
    COMPILE_DB="$ROOT/$candidate"
    break
  fi
done

if [ -z "$COMPILE_DB" ]; then
  echo "warning: No compile_commands.json found."
  echo "  Run: cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON ... to generate one."
  echo "  Falling back to best-effort mode (some diagnostics may be inaccurate)."
fi

if [ $# -gt 0 ]; then
  FILES=("$@")
else
  mapfile -t FILES < <(find src -name '*.cpp' -o -name '*.cc' | sort)
fi

if [ ${#FILES[@]} -eq 0 ]; then
  echo "No files to lint."
  exit 0
fi

echo "clang-tidy: scanning ${#FILES[@]} file(s)..."

ERRORS=0
for f in "${FILES[@]}"; do
  [ -f "$f" ] || continue
  if [ -n "$COMPILE_DB" ]; then
    clang-tidy -p "$COMPILE_DB" "$f" 2>/dev/null || ((ERRORS++)) || true
  else
    clang-tidy "$f" -- -std=c++17 -I"$ROOT/src" 2>/dev/null || true
  fi
done

if [ "$ERRORS" -gt 0 ]; then
  echo ""
  echo "clang-tidy: $ERRORS file(s) had warnings/errors."
  exit 1
fi

echo "clang-tidy: clean."
