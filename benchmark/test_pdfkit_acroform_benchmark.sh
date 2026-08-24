#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INPUT="${PDF_EDITOR_ACROFORM_BENCHMARK_INPUT:-$ROOT/benchmark/results/public-sample-form.pdf}"
OUTPUT_DIR="${PDF_EDITOR_ACROFORM_BENCHMARK_OUTPUT_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/pdfkit-acroform.XXXXXX")}"
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
BIN="$(mktemp "${TMPDIR:-/tmp}/pdfkit-acroform.XXXXXX")"
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
  "$ROOT/benchmark/PDFKitAcroFormBenchmark.swift" \
  -o "$BIN"

"$BIN" --input "$INPUT" --output-dir "$OUTPUT_DIR" > "$RESULT"

jq -e '(.provider == "PDFKit") and (.fixture == "public-acroform") and (.pages == 1) and (.widgetCount > 0) and (.noOpReopen == true) and (.widgetStateEquivalent == true) and (.mutatedReopen == true) and ((.widgetTypes | index("/Tx")) != null) and ((.widgetTypes | index("/Btn")) != null) and ((.widgetTypes | index("/Ch")) != null)' "$RESULT" >/dev/null
test -f "$OUTPUT_DIR/noop.pdf"
test -f "$OUTPUT_DIR/mutated.pdf"
test -f "$OUTPUT_DIR/original-page-1.png"
test -f "$OUTPUT_DIR/noop-page-1.png"
cmp -s "$OUTPUT_DIR/original-page-1.png" "$OUTPUT_DIR/noop-page-1.png"

printf 'PASS: PDFKit AcroForm benchmark checks passed.\n'
printf 'Artifacts: %s\n' "$OUTPUT_DIR"
