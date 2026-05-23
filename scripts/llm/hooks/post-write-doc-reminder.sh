#!/usr/bin/env bash
# scripts/llm/hooks/post-write-doc-reminder.sh
# Post-write LLM hook: reminds to add/update Doxygen documentation
# when a public header is modified and the changed functions lack doc comments.

set -euo pipefail

file_path=""
if [ -n "${1:-}" ]; then
  file_path="$1"
else
  input=$(cat 2>/dev/null || true)
  file_path=$(echo "$input" | jq -r '.tool_info.file_path // .file_path // empty' 2>/dev/null || true)
fi

[ -n "$file_path" ] || exit 0
[[ "$file_path" == *.h ]] || [[ "$file_path" == *.hpp ]] || [[ "$file_path" == *.hxx ]] || exit 0

[[ "$file_path" == */tests/* ]] && exit 0
[[ "$file_path" == */external/* ]] && exit 0

UNDOCUMENTED=$(grep -Eo '^\s*(virtual\s+|static\s+|explicit\s+)?[a-zA-Z_][a-zA-Z0-9_:<>* ]+\s+[a-zA-Z_][a-zA-Z0-9_]+\s*\(' \
  "$file_path" 2>/dev/null | grep -v '//' | grep -v 'operator' | head -10 || true)

if [ -z "$UNDOCUMENTED" ]; then
  exit 0
fi

HAS_DOXYGEN=$(grep -c '/\*\*\|///' "$file_path" 2>/dev/null || echo 0)
FUNC_COUNT=$(echo "$UNDOCUMENTED" | wc -l)

if [ "$HAS_DOXYGEN" -lt "$FUNC_COUNT" ]; then
  echo ""
  echo "=== Documentation Reminder ==="
  echo "Header modified: $file_path"
  echo "Some public functions may be missing Doxygen comments."
  echo ""
  echo "Example:"
  echo "  /**"
  echo "   * @brief Brief one-line description."
  echo "   * @param param_name Description of parameter."
  echo "   * @return Description of return value."
  echo "   */"
  echo ""
  echo "This project uses Doxygen. Public API headers should have:"
  echo "  /** @brief ... */ before each public method"
  echo "==============================="
fi
