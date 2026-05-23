#!/usr/bin/env bash
# pre-push/00-build.sh
# Full release build verification.
# Uses ccache if available for speed.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

BUILD_DIR="$ROOT/build/release"
mkdir -p "$BUILD_DIR"

JOBS=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
MEM_GB=$(free -g 2>/dev/null | awk "/^Mem:/{print $7}" || echo 4)
MAX_MEM_JOBS=$(( MEM_GB / 2 )); [ "$MAX_MEM_JOBS" -lt 1 ] && MAX_MEM_JOBS=1
[ "$JOBS" -gt "$MAX_MEM_JOBS" ] && JOBS="$MAX_MEM_JOBS"

cd "$BUILD_DIR"
cmake -G "Unix Makefiles" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
  ../.. 2>&1 | tail -5

make -j"$JOBS" 2>&1 | tail -20

echo "Build succeeded."
