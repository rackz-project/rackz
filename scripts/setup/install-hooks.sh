#!/usr/bin/env bash
# scripts/setup/install-hooks.sh
# Installs the rackz git hooks by pointing core.hooksPath at .githooks/.
# Run once after cloning.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

if [ ! -d ".git" ]; then
  echo "error: Not a git repository. Run from the repo root."
  exit 1
fi

if [ ! -d ".githooks" ]; then
  echo "error: .githooks/ directory not found."
  echo "  Ensure you have the full rackz repository checked out."
  exit 1
fi

chmod +x .githooks/*

git config core.hooksPath .githooks

echo "Git hooks installed: core.hooksPath = .githooks"
echo ""
echo "Active hooks:"
for h in .githooks/*; do
  printf "  %s\n" "$(basename "$h")"
done
echo ""
echo "To uninstall: git config --unset core.hooksPath"
echo "To bypass once: git commit --no-verify (document reason in PR)"
