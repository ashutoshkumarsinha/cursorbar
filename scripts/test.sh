#!/usr/bin/env bash
# Build CursorBar, run unit tests, and perform launch smoke checks.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DERIVED_DATA="$ROOT/.derivedData"

echo "==> Running unit tests..."
xcodebuild test \
  -project CursorBar.xcodeproj \
  -scheme CursorBar \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA" \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=NO

APP="$DERIVED_DATA/Build/Products/Debug/CursorBar.app"
BINARY="$APP/Contents/MacOS/CursorBar"

echo "==> Verifying app bundle..."
test -d "$APP" || { echo "Missing $APP" >&2; exit 1; }
test -x "$BINARY" || { echo "Missing executable $BINARY" >&2; exit 1; }

echo "==> Checking Info.plist..."
/usr/libexec/PlistBuddy -c "Print LSUIElement" "$APP/Contents/Info.plist" | grep -q true

echo "==> Checking bundle identifier..."
/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APP/Contents/Info.plist" | grep -q com.cursorbar.app

echo "==> Config files..."
test -f "$ROOT/docs/USER_GUIDE.md"
test -f "$ROOT/docs/SPEC.md"
test -f "$ROOT/config.toml"
test -f "$ROOT/config.toml.example"

echo "==> Launch smoke test..."
"$BINARY" &
PID=$!
sleep 2
if ! kill -0 "$PID" 2>/dev/null; then
  echo "CursorBar exited immediately (pid $PID)" >&2
  exit 1
fi
kill "$PID" 2>/dev/null || true
wait "$PID" 2>/dev/null || true

echo "All tests passed."
