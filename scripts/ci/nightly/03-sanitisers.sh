#!/usr/bin/env bash
# pre-push/03-sanitisers.sh
# Builds with AddressSanitiser + UndefinedBehaviourSanitiser and runs unit tests.
# Catches memory errors, use-after-free, buffer overflows, and UB at runtime.
#
# Skip with: SKIP_SANITISERS=1
# Requires: clang or gcc with sanitiser support

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

if [ "${SKIP_SANITISERS:-0}" = "1" ]; then
  echo "Sanitiser check skipped (SKIP_SANITISERS=1)."
  exit 0
fi

if ! cmake --version >/dev/null 2>&1; then
  echo "warning: cmake not found — skipping sanitiser build"
  exit 0
fi

BUILD_DIR="$ROOT/build/sanitise"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

cmake -G "Unix Makefiles" \
  -DCMAKE_BUILD_TYPE=Debug \
  -DBUILD_TESTS=ON \
  -DSANITIZE=ON \
  ../.. >/dev/null 2>&1

JOBS=$(nproc 2>/dev/null || echo 4)
MEM_GB=$(free -g 2>/dev/null | awk "/^Mem:/{print $7}" || echo 4)
MAX_MEM_JOBS=$(( MEM_GB / 2 )); [ "$MAX_MEM_JOBS" -lt 1 ] && MAX_MEM_JOBS=1
[ "$JOBS" -gt "$MAX_MEM_JOBS" ] && JOBS="$MAX_MEM_JOBS"
make -j"$JOBS" >/dev/null 2>&1

ASAN_OPTIONS="detect_leaks=0:abort_on_error=1" \
UBSAN_OPTIONS="print_stacktrace=1:halt_on_error=1" \
  ctest --output-on-failure -E "libwallet_api_tests|functional" 2>&1

echo "Sanitiser pass complete."
