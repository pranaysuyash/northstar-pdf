#!/bin/zsh
# package_mac_app.sh — wrap the SwiftPM binary in a proper Northstar.app bundle.
#
# Why: a raw executable has no bundle, so macOS shows the process name
# ("PDFEditor") in the menu bar and Dock. A bundle gives us the product
# name (Northstar), bundle id, version, and later: icon + file associations.
#
# Usage: ./scripts/package_mac_app.sh [--release]
# Output: ./dist/Northstar.app (built product copied, never moved).

set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG=debug
[[ "${1:-}" == "--release" ]] && CONFIG=release

echo "building ($CONFIG)..."
if [[ "$CONFIG" == "release" ]]; then
  swift build --product PDFEditor -c release 2>&1 | tail -1
else
  swift build --product PDFEditor 2>&1 | tail -1
fi

APP="dist/Northstar.app"
BINARY=".build/arm64-apple-macosx/$CONFIG/PDFEditor"
VERSION=$(date +%Y.%m.%d)

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/Northstar"

# Single canonical plist source (tools/native-preview-Info.plist) so document
# types, category, and metadata cannot drift between the preview bundle and the
# dist bundle. Packaging variables (executable name, date version) are stamped
# on the copy instead of forking a second plist here.
cp "tools/native-preview-Info.plist" "$APP/Contents/Info.plist"
plutil -replace CFBundleExecutable -string "Northstar" "$APP/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$VERSION" "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist" >/dev/null

echo "packaged: $APP"
echo "launch: open $APP --args /path/to/file.pdf"
