#!/usr/bin/env bash
# Seed ~/.cursorbar/config.toml from the repo template when missing.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_DIR="${CURSORBAR_CONFIG_DIR:-$HOME/.cursorbar}"
CONFIG_FILE="$CONFIG_DIR/config.toml"

mkdir -p "$CONFIG_DIR"

if [[ -f "$CONFIG_FILE" ]]; then
  echo "Config already exists: $CONFIG_FILE"
  exit 0
fi

cp "$ROOT/config.toml.example" "$CONFIG_FILE"
echo "Created $CONFIG_FILE"
