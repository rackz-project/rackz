#!/usr/bin/env bash
# scripts/llm/hooks/post-write-test-suggestion.sh
# Post-write LLM hook: suggests unit tests when a new .cpp file is written
# that has no corresponding test file in tests/unit_tests/.

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
[[ "$file_path" == *.cpp ]] || [[ "$file_path" == *.cc ]] || exit 0

[[ "$file_path" == */tests/* ]] && exit 0

basename_noext=$(basename "${file_path%.*}")
module_dir=$(dirname "$file_path" | sed "s|$ROOT/||")

TEST_CANDIDATES=(
  "$ROOT/tests/unit_tests/${basename_noext}_test.cpp"
  "$ROOT/tests/unit_tests/${basename_noext}_tests.cpp"
  "$ROOT/tests/unit_tests/test_${basename_noext}.cpp"
  "$ROOT/tests/core_tests/${basename_noext}_test.cpp"
)

found=0
for candidate in "${TEST_CANDIDATES[@]}"; do
  if [ -f "$candidate" ]; then
    found=1
    break
  fi
done

if [ "$found" -eq 0 ]; then
  echo ""
  echo "=== Test Suggestion ==="
  echo "No test file found for: $file_path"
  echo ""
  echo "Consider creating: tests/unit_tests/${basename_noext}_test.cpp"
  echo ""

  PUBLIC_FUNCS=$(grep -Eo '^\w[\w:* ]+\s+\w+\s*\([^)]*\)\s*(const)?\s*(override)?\s*(noexcept)?\s*[{;]' \
    "$file_path" 2>/dev/null | grep -v '//' | head -5 || true)

  if [ -n "$PUBLIC_FUNCS" ]; then
    echo "Detected functions to test:"
    echo "$PUBLIC_FUNCS" | sed 's/^/  /'
    echo ""
  fi

  echo "Suggested test skeleton:"
  echo "  // tests/unit_tests/${basename_noext}_test.cpp"
  echo "  #include <gtest/gtest.h>"
  echo "  #include \"${module_dir}/${basename_noext}.h\""
  echo ""
  echo "  namespace {"
  echo ""
  echo "  TEST(${basename_noext^}Test, BasicSanity) {"
  echo "    // TODO: replace with meaningful assertions"
  echo "    EXPECT_TRUE(true);"
  echo "  }"
  echo ""
  echo "  } // namespace"
  echo "======================="
fi
