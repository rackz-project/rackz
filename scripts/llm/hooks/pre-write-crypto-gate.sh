#!/usr/bin/env bash
# scripts/llm/hooks/pre-write-crypto-gate.sh
# Extra friction gate for red-zone cryptographic files.
# Blocks AI writes to src/crypto/, src/ringct/, src/seraphis_crypto/,
# src/hardforks/, and src/cryptonote_config.h unless explicitly unlocked.
#
# Unlock: set RACKZ_AI_CRYPTO_GATE=1 in the environment (must be explicit).
# Human commits may use --no-verify; AI must not.

set -euo pipefail

file_path=""
if [ -n "${1:-}" ]; then
  file_path="$1"
else
  input=$(cat 2>/dev/null || true)
  file_path=$(echo "$input" | jq -r '.tool_info.file_path // .file_path // empty' 2>/dev/null || true)
fi

[ -n "$file_path" ] || exit 0

RED_ZONE=0
RED_ZONE_REASON=""

if [[ "$file_path" == */src/crypto/* ]]; then
  RED_ZONE=1
  RED_ZONE_REASON="src/crypto/ contains cryptographic primitives — changes require human cryptographic review"
fi
if [[ "$file_path" == */src/ringct/* ]]; then
  RED_ZONE=1
  RED_ZONE_REASON="src/ringct/ contains RingCT and Bulletproof implementations — changes require human cryptographic review"
fi
if [[ "$file_path" == */src/seraphis_crypto/* ]]; then
  RED_ZONE=1
  RED_ZONE_REASON="src/seraphis_crypto/ is an in-progress stub — do not modify without explicit lead approval"
fi
if [[ "$file_path" == */src/hardforks/* ]]; then
  RED_ZONE=1
  RED_ZONE_REASON="src/hardforks/ contains consensus upgrade heights — changes require a proposal document and network consensus"
fi
if [[ "$file_path" == */src/cryptonote_config.h ]]; then
  RED_ZONE=1
  RED_ZONE_REASON="cryptonote_config.h contains chain-level constants — changes affect every node and require explicit approval"
fi

if [ "$RED_ZONE" -eq 0 ]; then
  exit 0
fi

if [ "${RACKZ_AI_CRYPTO_GATE:-0}" = "1" ]; then
  echo "warning: RACKZ_AI_CRYPTO_GATE=1 — crypto gate bypassed by explicit override"
  echo "  File: $file_path"
  exit 0
fi

echo "error: Red-zone file — AI write blocked"
echo "  File:   $file_path"
echo "  Reason: $RED_ZONE_REASON"
echo ""
echo "To proceed:"
echo "  1. Confirm with the user that this edit is intentional and reviewed"
echo "  2. The user should set RACKZ_AI_CRYPTO_GATE=1 to unlock"
echo "  3. All changes to cryptographic code require human review before merge"
exit 2
