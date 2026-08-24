#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QPDF="${QPDF_BIN:-$(command -v qpdf || true)}"
TESSERACT="${TESSERACT_BIN:-$(command -v tesseract || true)}"
DIR="${PDF_EDITOR_OCR_OUTPUT_DIR:-$ROOT/benchmark/results/ocr-corpus}"
PDF="$DIR/printed-scan.pdf"
PNG="$DIR/printed-scan.png"
TRUTH="$DIR/ground-truth.txt"

for file in "$PDF" "$PNG" "$TRUTH"; do
  [[ -f "$file" ]] || { printf 'BLOCKED: missing OCR fixture: %s\n' "$file" >&2; exit 2; }
done
[[ -n "$QPDF" ]] || { printf 'BLOCKED: qpdf is not installed.\n' >&2; exit 2; }
[[ -n "$TESSERACT" ]] || { printf 'BLOCKED: tesseract is not installed.\n' >&2; exit 2; }

"$QPDF" --check "$PDF" >/dev/null
ocr_output="$($TESSERACT "$PNG" stdout --psm 6 2>/dev/null | tr -s '[:space:]' ' ' | sed 's/[[:space:]]*$//')"
expected="$(tr -s '[:space:]' ' ' < "$TRUTH" | sed 's/[[:space:]]*$//')"
printf 'OCR observed: %s\n' "$ocr_output"
printf 'OCR expected: %s\n' "$expected"
[[ "$ocr_output" == *"OCR SAMPLE 2026"* ]] || { printf 'FAIL: OCR missed the fixture title.\n' >&2; exit 1; }
[[ "$ocr_output" == *"Ada Lovelace"* ]] || { printf 'FAIL: OCR missed the applicant name.\n' >&2; exit 1; }
[[ "$ocr_output" == *"OCR-042"* ]] || { printf 'FAIL: OCR missed the reference identifier.\n' >&2; exit 1; }

printf 'PASS: image-only OCR fixture is structurally valid and meets the benchmark anchors.\n'
