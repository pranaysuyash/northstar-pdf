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

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Northstar</string>
  <key>CFBundleDisplayName</key><string>Northstar</string>
  <key>CFBundleIdentifier</key><string>com.northstar.pdf</string>
  <key>CFBundleExecutable</key><string>Northstar</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <!-- No icon yet (F-006 asset pass); no file associations yet. -->
</dict>
</plist>
EOF

echo "packaged: $APP"
echo "launch: open $APP --args /path/to/file.pdf"
