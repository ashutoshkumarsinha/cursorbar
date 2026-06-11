#!/usr/bin/env bash
# Build CursorBar via xcodebuild and copy CursorBar.app to the project root.
# Usage: scripts/package-app.sh [debug|release]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIG="${1:-debug}"
APP_NAME="CursorBar.app"
DERIVED_DATA="$ROOT/.derivedData"
CONFIG_CAP="$(echo "$CONFIG" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
BUILT_APP="$DERIVED_DATA/Build/Products/${CONFIG_CAP}/$APP_NAME"
DEST_APP="$ROOT/$APP_NAME"

if [[ "$CONFIG" != "debug" && "$CONFIG" != "release" ]]; then
  echo "Usage: $0 [debug|release]" >&2
  exit 1
fi

if [[ ! -d "$BUILT_APP" ]]; then
  echo "Building CursorBar ($CONFIG)..."
  make "build-${CONFIG}"
fi

rm -rf "$DEST_APP"
cp -R "$BUILT_APP" "$DEST_APP"

# Ship user-facing docs inside the bundle for reference.
DOCS_DEST="$DEST_APP/Contents/Resources"
mkdir -p "$DOCS_DEST"
cp "$ROOT/docs/USER_GUIDE.md" "$DOCS_DEST/USER_GUIDE.md"
cp "$ROOT/docs/SPEC.md" "$DOCS_DEST/SPEC.md"

echo "Created $DEST_APP ($CONFIG)"
