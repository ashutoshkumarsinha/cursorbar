#!/usr/bin/env bash
# Regenerate AppIcon and MenuBarLogo assets from the 1024px source image.
# Usage: scripts/generate-icons.sh [path/to/source-1024.png]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:-$ROOT/Resources/cursorbar-icon-source.png}"
APPICON="$ROOT/CursorBar/Resources/Assets.xcassets/AppIcon.appiconset"
MENUBAR="$ROOT/CursorBar/Resources/Assets.xcassets/MenuBarLogo.imageset"

if [[ ! -f "$SRC" ]]; then
  echo "Source icon not found: $SRC" >&2
  exit 1
fi

mkdir -p "$APPICON" "$MENUBAR"

generate() {
  sips -z "$2" "$2" "$SRC" --out "$APPICON/icon_${1}.png" >/dev/null
}

generate "16x16" 16
generate "16x16@2x" 32
generate "32x32" 32
generate "32x32@2x" 64
generate "128x128" 128
generate "128x128@2x" 256
generate "256x256" 256
generate "256x256@2x" 512
generate "512x512" 512
cp "$SRC" "$APPICON/icon_512x512@2x.png"

sips -z 18 18 "$SRC" --out "$MENUBAR/menubar-18.png" >/dev/null
sips -z 36 36 "$SRC" --out "$MENUBAR/menubar-36.png" >/dev/null

echo "Regenerated icons in Assets.xcassets"
