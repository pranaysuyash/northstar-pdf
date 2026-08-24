#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${PDF_EDITOR_WIDGET_BENCHMARK_OUTPUT_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/pdfkit-widgets.XXXXXX")}"
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
BIN="$(mktemp "${TMPDIR:-/tmp}/pdfkit-widget-benchmark.XXXXXX")"
RESULT="$OUTPUT_DIR/result.json"
trap 'rm -f "$BIN"' EXIT

mkdir -p "$OUTPUT_DIR"

xcrun swiftc \
  -sdk "$SDK_PATH" \
  -target arm64-apple-macosx15.0 \
  -framework PDFKit \
  -framework AppKit \
  -framework CoreGraphics \
  -framework ImageIO \
  "$ROOT/benchmark/PDFKitWidgetBenchmark.swift" \
  -o "$BIN"

"$BIN" "$OUTPUT_DIR/artifacts" > "$RESULT"

jq -e '
  (.provider == "PDFKit") and
  (.widgetCount == 6) and
  (.fixtureReopen == true) and
  (.filledReopen == true) and
  (.textValueRoundTrip == true) and
  (.checkboxStateRoundTrip == true) and
  (.radioStateRoundTrip == true) and
  (.choiceValueRoundTrip == true) and
  (.signatureFieldRoundTrip == true) and
  (.fixtureUnchanged == true)
' "$RESULT" >/dev/null

printf 'PASS: PDFKit native widget benchmark checks passed.\n'
printf 'Artifacts: %s\n' "$OUTPUT_DIR"
