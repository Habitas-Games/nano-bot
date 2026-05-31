#!/usr/bin/env bash
# Open the nano-bot project in the Godot editor
GODOT="$HOME/.local/bin/godot4"
PROJECT="$(dirname "$(realpath "$0")")"
exec "$GODOT" --editor --path "$PROJECT" "$@"
