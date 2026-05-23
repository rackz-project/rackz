#!/usr/bin/env bash
# scripts/ci/ci.sh
# Single entrypoint for all quality checks.
# Run locally or from GitHub Actions — same script, same results.
#
# Usage:
#   ./scripts/ci/ci.sh              # full pipeline
#   SKIP_SLOW=1 ./scripts/ci/ci.sh  # skip sanitiser and coverage passes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT"

PASS=0
FAIL=0
SKIP=0

run_step() {
  local label="$1"
  local script="$2"
  shift 2

  if [ ! -f "$script" ]; then
    echo "  [SKIP] $label (script not found: $script)"
    ((SKIP++)) || true
    return
  fi

  printf "  %-55s " "$label"
  if bash "$script" "$@" 2>&1 | tail -1 | grep -q ""; then
    if bash "$script" "$@" >/dev/null 2>&1; then
      echo "[ OK ]"
      ((PASS++)) || true
    else
      echo "[FAIL]"
      echo ""
      bash "$script" "$@" || true
      ((FAIL++)) || true
    fi
  fi
}

echo "=== Rackz CI Pipeline ==="
echo ""

echo "--- pre-commit checks ---"
run_step "file quality"          "$SCRIPT_DIR/pre-commit/00-file-quality.sh"
run_step "format check"          "$SCRIPT_DIR/pre-commit/01-format-check.sh"
run_step "clang-tidy (staged)"   "$SCRIPT_DIR/pre-commit/02-clang-tidy.sh"
run_step "cppcheck (staged)"     "$SCRIPT_DIR/pre-commit/03-cppcheck.sh"
run_step "crypto guardrail"      "$SCRIPT_DIR/pre-commit/04-crypto-guardrail.sh"
run_step "secrets scan"          "$SCRIPT_DIR/pre-commit/05-secrets.sh"
echo ""

echo "--- pre-push checks ---"
run_step "build"                 "$SCRIPT_DIR/pre-push/00-build.sh"
run_step "tests"                 "$SCRIPT_DIR/pre-push/01-tests.sh"
if [ "${SKIP_SLOW:-0}" != "1" ]; then
  run_step "coverage"            "$SCRIPT_DIR/pre-push/02-coverage.sh"
  run_step "sanitisers"          "$SCRIPT_DIR/pre-push/03-sanitisers.sh"
fi
run_step "submodule drift"       "$SCRIPT_DIR/pre-push/04-submodule-drift.sh"
run_step "architecture guardrail" "$SCRIPT_DIR/pre-push/05-arch-guardrail.sh"
run_step "complexity"            "$SCRIPT_DIR/pre-push/06-complexity.sh"
echo ""

echo "=== Results: $PASS passed, $FAIL failed, $SKIP skipped ==="
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
