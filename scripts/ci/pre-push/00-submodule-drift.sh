#!/usr/bin/env bash
# pre-push/04-submodule-drift.sh
# Detects uncommitted submodule pointer changes and uninitialized submodules.
# Submodules: external/randomx, external/supercop, external/gtest

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

ERRORS=0

dirty=$(git diff HEAD --name-only -- '.gitmodules' 2>/dev/null || true)
if [ -n "$dirty" ]; then
  echo "error: .gitmodules has uncommitted changes"
  ((ERRORS++)) || true
fi

while IFS= read -r submodule; do
  submodule="${submodule#./}"
  [ -n "$submodule" ] || continue

  if [ ! -f "$submodule/.git" ] && [ ! -d "$submodule/.git" ]; then
    echo "warning: submodule not initialized: $submodule"
    echo "  fix: git submodule update --init --recursive"
    continue
  fi

  drift=$(git diff HEAD -- "$submodule" 2>/dev/null || true)
  if [ -n "$drift" ]; then
    echo "warning: submodule pointer changed (not committed): $submodule"
    echo "  Run 'git add $submodule && git commit' to record the update,"
    echo "  or 'git checkout HEAD -- $submodule' to revert."
  fi
done < <(git submodule foreach --quiet 'echo $displaypath' 2>/dev/null || true)

if [ "$ERRORS" -gt 0 ]; then
  exit 1
fi
