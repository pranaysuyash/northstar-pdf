#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${PDF_EDITOR_BUILD_CONFIGURATION:-debug}"
OUTPUT_DIR="${PDF_EDITOR_APP_OUTPUT_DIR:-$ROOT_DIR/.build/native-preview}"
APP_PATH="$OUTPUT_DIR/PDFEditor.app"

BIN_PATH="$(swift build \
  --configuration "$CONFIGURATION" \
  --product PDFEditor \
  --show-bin-path)"
BIN_PATH="$BIN_PATH/PDFEditor"

if [[ ! -x "$BIN_PATH" ]]; then
  print -u2 "PDFEditor executable was not produced at $BIN_PATH"
  exit 1
fi

if [[ -e "$APP_PATH" ]]; then
  rm -rf -- "$APP_PATH"
fi

mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
cp "$BIN_PATH" "$APP_PATH/Contents/MacOS/PDFEditor"
cp "$ROOT_DIR/tools/native-preview-Info.plist" "$APP_PATH/Contents/Info.plist"
chmod 755 "$APP_PATH/Contents/MacOS/PDFEditor"

plutil -lint "$APP_PATH/Contents/Info.plist" >/dev/null

if [[ -n "${PDF_EDITOR_CODESIGN_IDENTITY:-}" ]]; then
  # Optional sandbox staging: set PDF_EDITOR_ENABLE_SANDBOX=1 to sign with
  # tools/native-preview.entitlements (see docs/research/sandbox-entitlements-plan-2026-09-17.md).
  # Default remains unsandboxed until the file-access audit passes end to end.
  SIGN_ARGS=(--force --deep --sign "$PDF_EDITOR_CODESIGN_IDENTITY")
  if [[ "${PDF_EDITOR_ENABLE_SANDBOX:-0}" == "1" ]]; then
    SIGN_ARGS+=(--entitlements "$ROOT_DIR/tools/native-preview.entitlements")
  fi
  codesign "${SIGN_ARGS[@]}" "$APP_PATH"
fi

print "$APP_PATH"
