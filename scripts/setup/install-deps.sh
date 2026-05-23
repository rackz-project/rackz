#!/usr/bin/env bash
# scripts/setup/install-deps.sh
# Checks that all development tools required by the scripts/ pipeline are present.
# Reports what is missing and how to install it.

set -euo pipefail

MISSING=0
MISSING_OPT=0

check() {
  local tool="$1"
  local install_hint="$2"
  if command -v "$tool" >/dev/null 2>&1; then
    printf "  %-20s %s\n" "$tool" "[ OK ]  $(command -v "$tool")"
  else
    printf "  %-20s %s\n" "$tool" "[MISS]  $install_hint"
    ((MISSING++)) || true
  fi
}

check_opt() {
  local tool="$1"
  local install_hint="$2"
  if command -v "$tool" >/dev/null 2>&1; then
    printf "  %-20s %s\n" "$tool" "[ OK ]  $(command -v "$tool")"
  else
    printf "  %-20s %s\n" "$tool" "[ -- ]  optional: $install_hint"
    ((MISSING_OPT++)) || true
  fi
}

echo "=== Rackz Dev Tool Check ==="
echo ""
echo "Build:"
check cmake       "apt-get install cmake  |  brew install cmake"
check make        "apt-get install make   |  brew install make"
check_opt ccache  "apt-get install ccache |  brew install ccache"
echo ""
echo "Formatting & Linting:"
check clang-format "apt-get install clang-format  |  brew install clang-format"
check clang-tidy   "apt-get install clang-tidy    |  brew install llvm"
check_opt cppcheck "apt-get install cppcheck      |  brew install cppcheck"
echo ""
echo "Coverage:"
check_opt lcov     "apt-get install lcov  |  brew install lcov"
check gcov         "Included with gcc/g++"
echo ""
echo "LLM Setup:"
check yq           "pip install yq  |  brew install yq  |  snap install yq"
check jq           "apt-get install jq  |  brew install jq"
echo ""
echo "Git:"
check git          "apt-get install git  |  brew install git"
echo ""

if [ "$MISSING" -gt 0 ]; then
  echo "$MISSING required tool(s) missing. Install them before running 'make ci'."
  exit 1
fi
if [ "$MISSING_OPT" -gt 0 ]; then
  echo "$MISSING_OPT optional tool(s) not installed (coverage/static-analysis features will be skipped)."
fi
echo "All required tools present."
