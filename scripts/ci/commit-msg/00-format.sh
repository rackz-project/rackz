#!/usr/bin/env bash
# commit-msg/00-format.sh
# Validates commit message format: "subdir: short description"
# Follows the Monero project convention from docs/CONTRIBUTING.md.
#
# Valid:   "crypto: fix scalar reduction edge case"
# Valid:   "wallet: add subaddress scan optimisation"
# Valid:   "cmake: update minimum version to 3.16"
# Invalid: "Fixed stuff"
# Invalid: "WIP"

set -euo pipefail

MSG_FILE="$1"
MSG=$(cat "$MSG_FILE")
SUBJECT=$(echo "$MSG" | head -1)

if echo "$SUBJECT" | grep -qE '^(Merge|Revert|fixup!|squash!)'; then
  exit 0
fi

if ! echo "$SUBJECT" | grep -qE '^[a-zA-Z0-9_/.-]+: .+'; then
  echo "error: commit subject does not follow 'subdir: description' format"
  echo "  got:      $SUBJECT"
  echo "  expected: 'subdir: short description'"
  echo ""
  echo "  Examples:"
  echo "    crypto: fix scalar reduction edge case"
  echo "    wallet: add subaddress scan optimisation"
  echo "    rpc: expose new get_transfers_by_height endpoint"
  exit 1
fi
