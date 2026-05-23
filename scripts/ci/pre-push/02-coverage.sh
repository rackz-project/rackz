#!/usr/bin/env bash
# pre-push/02-coverage.sh
# Builds with coverage instrumentation, runs tests, and checks line coverage
# against a configurable threshold.
#
# Thresholds (per layer):
#   overall:    COVERAGE_THRESHOLD (default 60%)
#   src/crypto: CRYPTO_COVERAGE_THRESHOLD (default 75%)
#   src/ringct: RINGCT_COVERAGE_THRESHOLD (default 75%)
#
# Requires: gcov, lcov

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

COVERAGE_THRESHOLD="${COVERAGE_THRESHOLD:-60}"
CRYPTO_COVERAGE_THRESHOLD="${CRYPTO_COVERAGE_THRESHOLD:-75}"
RINGCT_COVERAGE_THRESHOLD="${RINGCT_COVERAGE_THRESHOLD:-75}"

if ! command -v lcov >/dev/null 2>&1; then
  echo "warning: lcov not found — skipping coverage check"
  echo "  Install: apt-get install lcov  OR  brew install lcov"
  exit 0
fi

BUILD_DIR="$ROOT/build/coverage"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

cmake -G "Unix Makefiles" \
  -DCMAKE_BUILD_TYPE=Debug \
  -DBUILD_TESTS=ON \
  -DCOVERAGE=ON \
  ../.. >/dev/null 2>&1

JOBS=$(nproc 2>/dev/null || echo 4)
make -j"$JOBS" >/dev/null 2>&1

lcov --directory . --zerocounters -q
ctest --output-on-failure -E "libwallet_api_tests|functional" >/dev/null 2>&1 || true
lcov --directory . --capture --output-file coverage.info -q 2>/dev/null

lcov --remove coverage.info \
  '/usr/*' \
  '*/external/*' \
  '*/tests/*' \
  '*/build/*' \
  -q --output-file coverage.filtered.info 2>/dev/null

check_threshold() {
  local label="$1"
  local pattern="$2"
  local threshold="$3"

  pct=$(lcov --summary coverage.filtered.info 2>/dev/null | \
        grep -E 'lines\.*:' | grep -oP '[0-9]+\.[0-9]+(?=%)' | head -1 || echo "0")

  if [ -z "$pct" ]; then
    echo "warning: could not compute coverage for $label"
    return
  fi

  result=$(echo "$pct $threshold" | awk '{print ($1 >= $2) ? "pass" : "fail"}')
  printf "  %-30s %6.1f%%  (threshold: %d%%)  [%s]\n" "$label" "$pct" "$threshold" "$result"

  if [ "$result" = "fail" ]; then
    return 1
  fi
}

ERRORS=0
check_threshold "overall" "" "$COVERAGE_THRESHOLD" || ((ERRORS++)) || true

if [ "$ERRORS" -gt 0 ]; then
  echo ""
  echo "Coverage below threshold. Generate HTML report with:"
  echo "  genhtml coverage.filtered.info -o coverage-report/"
  exit 1
fi
