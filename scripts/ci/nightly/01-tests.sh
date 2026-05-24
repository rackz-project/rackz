#!/usr/bin/env bash
# pre-push/01-tests.sh
# Runs the full ctest suite (unit + core tests).
# Excludes known slow integration tests unless RUN_ALL_TESTS=1.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

BUILD_DIR="$ROOT/build/release"
if [ ! -d "$BUILD_DIR" ]; then
  BUILD_DIR="$ROOT/build/debug"
fi

if [ ! -f "$BUILD_DIR/CTestTestfile.cmake" ]; then
  echo "warning: No CTest configuration found. Run a build with BUILD_TESTS=ON first."
  echo "  make debug-test  OR  make release-test"
  exit 0
fi

cd "$BUILD_DIR"

EXCLUDE_PATTERN="libwallet_api_tests|functional"
if [ "${RUN_ALL_TESTS:-0}" = "1" ]; then
  EXCLUDE_PATTERN=""
fi

if [ -n "$EXCLUDE_PATTERN" ]; then
  ctest --output-on-failure -E "$EXCLUDE_PATTERN"
else
  ctest --output-on-failure
fi
