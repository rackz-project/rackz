#!/usr/bin/env bash
# pre-push/05-arch-guardrail.sh
# Enforces src/ layer dependency rules by analysing #include directives.
#
# Layer rules (see AGENTS.md §Architecture Rules):
#   src/crypto/        must not include: wallet/, daemon/, rpc/, protocol/
#   src/ringct/        must not include: wallet/, daemon/, protocol/
#                      (device/ is allowed — hardware wallet signing abstraction)
#   src/seraphis_crypto/ must not include: wallet/, daemon/, rpc/, protocol/, cryptonote_core/
#   src/cryptonote_core/ must not include: wallet/
#   src/wallet/        must not include: daemon/ (non-rpc internals)
#   src/net/           must not include: cryptonote_core/, wallet/
#   src/p2p/           must not include: wallet/
#
# Known pre-existing exceptions NOT flagged by this script:
#   blockchain.h includes rpc/core_rpc_server_commands_defs.h (shared type defs, not the server)
#   ringct/rctSigs.cpp includes device/device.hpp (hardware wallet abstraction)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

ERRORS=0

check_layer() {
  local layer="$1"
  local forbidden_pattern="$2"
  local friendly_msg="$3"

  files=$(find "src/$layer" -name "*.cpp" -o -name "*.h" -o -name "*.hpp" 2>/dev/null || true)
  if [ -z "$files" ]; then
    return
  fi

  violations=$(grep -rn --include="*.cpp" --include="*.h" --include="*.hpp" \
    -E "#include.*(${forbidden_pattern})" "src/$layer/" 2>/dev/null || true)

  if [ -n "$violations" ]; then
    echo "error: Architecture violation in src/$layer/"
    echo "  Rule: $friendly_msg"
    echo "$violations" | head -10 | sed 's/^/  /'
    echo ""
    ((ERRORS++)) || true
  fi
}

check_layer "crypto" \
  "wallet/|daemon/|rpc/|cryptonote_protocol/" \
  "src/crypto/ must not depend on wallet, daemon, rpc, or protocol layers"

check_layer "ringct" \
  "wallet/|daemon/|cryptonote_protocol/" \
  "src/ringct/ must not depend on wallet, daemon, or protocol layers"

check_layer "seraphis_crypto" \
  "wallet/|daemon/|rpc/|cryptonote_protocol/|cryptonote_core/" \
  "src/seraphis_crypto/ (stub) must not depend on any application layer"

check_layer "cryptonote_core" \
  "\"wallet/" \
  "src/cryptonote_core/ must not depend on src/wallet/"

check_layer "net" \
  "cryptonote_core/|wallet/" \
  "src/net/ must not depend on consensus or wallet layers"

check_layer "p2p" \
  "\"wallet/" \
  "src/p2p/ must not depend on src/wallet/"

if [ "$ERRORS" -gt 0 ]; then
  echo "Architecture guardrail failed: $ERRORS violation(s) found."
  echo "See AGENTS.md §Architecture Rules for dependency rules."
  exit 1
fi

echo "Architecture guardrail: all layer boundaries respected."
