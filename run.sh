#!/usr/bin/env bash
# Run the nano-bot game directly (no editor)
GODOT="$HOME/.local/bin/godot4"
PROJECT="$(dirname "$(realpath "$0")")"
exec "$GODOT" --path "$PROJECT" "$@"
