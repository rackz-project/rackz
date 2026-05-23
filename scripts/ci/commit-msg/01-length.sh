#!/usr/bin/env bash
# commit-msg/01-length.sh
# Enforces subject line <= 72 chars and body line wrap <= 100 chars.

set -euo pipefail

MSG_FILE="$1"
ERRORS=0
LINE_NUM=0

while IFS= read -r line; do
  ((LINE_NUM++)) || true

  if [ "$LINE_NUM" -eq 1 ]; then
    len=${#line}
    if [ "$len" -gt 72 ]; then
      echo "error: subject line is ${len} chars (max 72)"
      echo "  $line"
      ((ERRORS++)) || true
    fi
  fi

  if [ "$LINE_NUM" -gt 2 ]; then
    len=${#line}
    if [ "$len" -gt 100 ]; then
      echo "warning: body line $LINE_NUM is ${len} chars (recommended max 100)"
      echo "  $line"
    fi
  fi
done < "$MSG_FILE"

if [ "$ERRORS" -gt 0 ]; then
  exit 1
fi
