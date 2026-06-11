#!/usr/bin/env bash
# Build, package, and launch CursorBar.app.
# Usage: scripts/run-app.sh [debug|release]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIG="${1:-debug}"
APP_NAME="CursorBar.app"

if [[ "$CONFIG" != "debug" && "$CONFIG" != "release" ]]; then
  echo "Usage: $0 [debug|release]" >&2
  exit 1
fi

bash "$ROOT/scripts/package-app.sh" "$CONFIG"
open "$ROOT/$APP_NAME"
