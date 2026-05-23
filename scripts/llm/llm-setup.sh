#!/usr/bin/env bash
# scripts/llm/llm-setup.sh
# Sets up LLM tool configuration for a chosen IDE/platform.
# Reads a config.yaml per platform and materialises files into the
# platform's config folder (e.g. .windsurf/, .cursor/, .claude/).
#
# Usage:
#   ./scripts/llm/llm-setup.sh              # interactive
#   ./scripts/llm/llm-setup.sh windsurf     # non-interactive

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PLATFORMS_DIR="$SCRIPT_DIR/platforms"

echo "=== Rackz LLM Tool Setup ==="
echo ""

if ! command -v yq >/dev/null 2>&1; then
  echo "error: 'yq' is required but not installed."
  echo "  Install: pip install yq  OR  brew install yq  OR  snap install yq"
  echo "  (mikefarah/yq v4+: go install github.com/mikefarah/yq/v4@latest)"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "error: 'jq' is required but not installed."
  echo "  Install: apt-get install jq  OR  brew install jq"
  exit 1
fi

platforms=()
for dir in "$PLATFORMS_DIR"/*/; do
  [ -d "$dir" ] || continue
  platforms+=("$(basename "$dir")")
done

if [ "${#platforms[@]}" -eq 0 ]; then
  echo "error: No platforms found in $PLATFORMS_DIR"
  exit 1
fi

if [ -n "${1:-}" ]; then
  PLATFORM="$1"
else
  echo "Available platforms:"
  i=1
  for p in "${platforms[@]}"; do
    printf "  %d) %s\n" "$i" "$p"
    ((i++)) || true
  done
  echo ""
  read -rp "Select platform (number or name): " choice

  if [[ "$choice" =~ ^[0-9]+$ ]]; then
    if (( choice < 1 || choice > ${#platforms[@]} )); then
      echo "error: Invalid selection"
      exit 1
    fi
    PLATFORM="${platforms[$((choice-1))]}"
  else
    PLATFORM="$choice"
  fi
fi

CONFIG_FILE="$PLATFORMS_DIR/$PLATFORM/config.yaml"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "error: config.yaml not found for platform '$PLATFORM'"
  echo "  Available: ${platforms[*]}"
  exit 1
fi

FOLDER=$(yq -r '.folder' "$CONFIG_FILE")
TARGET_DIR="$PROJECT_ROOT/$FOLDER"
mkdir -p "$TARGET_DIR"

echo "Setting up: $PLATFORM → $FOLDER/"
echo ""

yq -o=json '.structure' "$CONFIG_FILE" | jq -c '.[]' | while IFS= read -r item; do
  path=$(echo "$item" | jq -r '.path')
  type=$(echo "$item" | jq -r '.type')
  content=$(echo "$item" | jq -r '.content // ""')
  source=$(echo "$item" | jq -r '.source // ""')
  fullpath="$TARGET_DIR/$path"

  if [ "$type" = "dir" ] || [ "$type" = "directory" ]; then
    mkdir -p "$fullpath"
    echo "  [dir]  $path"
  elif [ "$type" = "file" ]; then
    mkdir -p "$(dirname "$fullpath")"

    if [ -n "$source" ]; then
      src_path="$PROJECT_ROOT/$source"
      if [ -f "$src_path" ]; then
        cp "$src_path" "$fullpath"
        echo "  [copy] $path  ← $source"
      else
        echo "  [warn] source not found: $source — creating empty file"
        touch "$fullpath"
      fi
    elif [ -n "$content" ]; then
      printf '%s\n' "$content" > "$fullpath"
      echo "  [file] $path"
    else
      touch "$fullpath"
      echo "  [file] $path  (empty)"
    fi

    if [[ "$path" == *.sh ]]; then
      chmod +x "$fullpath"
    fi
  else
    echo "  [skip] unknown type '$type' for: $path"
  fi
done

echo ""
echo "Done. LLM configuration written to: $FOLDER/"
echo ""
echo "Next steps:"
case "$PLATFORM" in
  windsurf)
    echo "  Windsurf reads .windsurf/rules/*.md and .windsurf/AGENTS.md automatically."
    echo "  Restart Windsurf to pick up new rules."
    ;;
  cursor)
    echo "  Cursor reads .cursor/rules/*.mdc automatically."
    echo "  The hooks.json is for reference — Cursor hooks are configured in Settings."
    ;;
  claude)
    echo "  Copy CLAUDE.md to your project root or Claude project instructions."
    ;;
esac
