#!/usr/bin/env bash
# scripts/llm/hooks/pre-write-arch-compliance.sh
# Pre-write LLM hook: validates #include patterns before a C++ file is written.
# Called by the IDE platform hook (e.g. .windsurf/hooks/pre-write.sh).
#
# Input: file path as $1 (or JSON on stdin with .tool_info.file_path)
# Output: warnings/errors to stdout; exit 1 to block write

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

file_path=""
if [ -n "${1:-}" ]; then
  file_path="$1"
else
  input=$(cat 2>/dev/null || true)
  file_path=$(echo "$input" | jq -r '.tool_info.file_path // .file_path // empty' 2>/dev/null || true)
fi

[ -n "$file_path" ] || exit 0
[[ "$file_path" == *.cpp ]] || [[ "$file_path" == *.h ]] || \
[[ "$file_path" == *.hpp ]] || [[ "$file_path" == *.cc ]] || exit 0

identify_layer() {
  local fp="$1"
  if [[ "$fp" == */src/crypto/* ]];            then echo "crypto"; return; fi
  if [[ "$fp" == */src/ringct/* ]];            then echo "ringct"; return; fi
  if [[ "$fp" == */src/seraphis_crypto/* ]];   then echo "seraphis_crypto"; return; fi
  if [[ "$fp" == */src/cryptonote_core/* ]];   then echo "cryptonote_core"; return; fi
  if [[ "$fp" == */src/wallet/* ]];            then echo "wallet"; return; fi
  if [[ "$fp" == */src/net/* ]];               then echo "net"; return; fi
  if [[ "$fp" == */src/p2p/* ]];               then echo "p2p"; return; fi
  if [[ "$fp" == */src/rpc/* ]];               then echo "rpc"; return; fi
  echo "other"
}

layer=$(identify_layer "$file_path")

case "$layer" in
  crypto)
    echo "Layer: crypto — pure cryptographic primitives."
    echo "Forbidden imports: wallet/, daemon/, rpc/, cryptonote_protocol/"
    ;;
  ringct)
    echo "Layer: ringct — ring signature and Bulletproof math."
    echo "Allowed imports: src/crypto/ and device/ (hardware wallet abstraction)."
    echo "Forbidden imports: wallet/, daemon/, cryptonote_protocol/"
    ;;
  seraphis_crypto)
    echo "Layer: seraphis_crypto — STUB MODULE. READ-ONLY."
    echo "This module is in early development. Do not add new code without lead sign-off."
    echo "If you must edit, confirm with the user explicitly."
    exit 1
    ;;
  cryptonote_core)
    echo "Layer: cryptonote_core — consensus, blockchain, tx pool."
    echo "Forbidden imports: wallet/"
    ;;
  wallet)
    echo "Layer: wallet — libwallet. wallet2.cpp is 15k lines."
    echo "Forbidden imports: daemon/ internals (use rpc/ public interface only)"
    echo "Prefer adding to focused submodules rather than appending to wallet2.cpp."
    ;;
  net)
    echo "Layer: net — network abstractions."
    echo "Forbidden imports: cryptonote_core/, wallet/"
    ;;
  p2p)
    echo "Layer: p2p — peer discovery and connection management."
    echo "Forbidden imports: wallet/"
    ;;
esac

exit 0
