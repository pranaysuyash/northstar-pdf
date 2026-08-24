#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INPUT="${PDF_EDITOR_BENCHMARK_INPUT:-/Users/pranay/Desktop/RAr0Lq2Avu.pdf}"
OUTPUT_DIR="${PDF_EDITOR_BENCHMARK_OUTPUT_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/pdfkit-benchmark.XXXXXX")}"
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
BIN="$(mktemp "${TMPDIR:-/tmp}/pdfkit-benchmark.XXXXXX")"
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
  "$ROOT/benchmark/PDFKitBenchmark.swift" \
  -o "$BIN"

"$BIN" --input "$INPUT" --output-dir "$OUTPUT_DIR/artifacts" > "$RESULT"

rg -q '"provider" : "PDFKit"' "$RESULT"
rg -q '"pages" : 2' "$RESULT"
rg -q '"nativeWidgetCount" : 0' "$RESULT"
rg -q '"noOpReopen" : true' "$RESULT"
rg -q '"overlayReopen" : true' "$RESULT"
rg -q '"originalUnchanged" : true' "$RESULT"
rg -q '"renderedPageCount" : 2' "$RESULT"
rg -q '"overlayAnnotationCount" : 1' "$RESULT"

test -f "$OUTPUT_DIR/artifacts/original-page-1.png"
test -f "$OUTPUT_DIR/artifacts/original-page-2.png"
test -f "$OUTPUT_DIR/artifacts/noop-page-1.png"
test -f "$OUTPUT_DIR/artifacts/noop-page-2.png"
cmp -s "$OUTPUT_DIR/artifacts/original-page-1.png" "$OUTPUT_DIR/artifacts/noop-page-1.png"
cmp -s "$OUTPUT_DIR/artifacts/original-page-2.png" "$OUTPUT_DIR/artifacts/noop-page-2.png"

printf 'PASS: PDFKit benchmark checks passed.\n'
printf 'Artifacts: %s\n' "$OUTPUT_DIR"
