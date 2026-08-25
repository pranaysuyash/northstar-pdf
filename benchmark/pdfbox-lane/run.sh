#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INPUT="${PDF_EDITOR_PDFBOX_INPUT:-$ROOT/benchmark/results/public-sample-form.pdf}"
OUTPUT_DIR="${PDF_EDITOR_PDFBOX_OUTPUT_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/pdfbox-acroform.XXXXXX")}"
JAR="$ROOT/benchmark/pdfbox-lane/pdfbox-app-3.0.8.jar"
JAR_SHA512_FILE="$JAR.sha512"
CLASSES_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pdfbox-classes.XXXXXX")"
RESULT="$OUTPUT_DIR/result.json"
trap 'rm -rf "$CLASSES_DIR"' EXIT

mkdir -p "$OUTPUT_DIR"

if [ ! -f "$JAR" ]; then
  printf 'FAIL: missing PDFBox fat jar: %s\n' "$JAR" >&2
  exit 1
fi

# Verify the jar against the published SHA-512 before trusting results.
EXPECTED_SHA512="$(tr -cd '0-9a-fA-F' < "$JAR_SHA512_FILE" | tr 'A-F' 'a-f')"
ACTUAL_SHA512="$(openssl dgst -sha512 "$JAR" | awk '{print $NF}')"
if [ "$EXPECTED_SHA512" != "$ACTUAL_SHA512" ]; then
  printf 'FAIL: jar SHA-512 mismatch (expected %s, got %s)\n' \
    "$EXPECTED_SHA512" "$ACTUAL_SHA512" >&2
  exit 1
fi

javac -cp "$JAR" -d "$CLASSES_DIR" "$ROOT/benchmark/pdfbox-lane/RadioProbe.java"

java -Djava.awt.headless=true \
     -Dpdfbox.jar.sha512="$ACTUAL_SHA512" \
     -cp "$JAR:$CLASSES_DIR" \
     RadioProbe "$INPUT" "$OUTPUT_DIR" > "$RESULT"

# Gate on the four oracle booleans; exits nonzero when any is false
# (same widgetStateEquivalent gate semantics as the PDFKit lane).
jq -e '(.provider == "PDFBox")
       and (.noOpReopen == true)
       and (.widgetStateEquivalent == true)
       and (.mutatedReopen == true)
       and (.originalUnchanged == true)' "$RESULT" >/dev/null

test -f "$OUTPUT_DIR/noop.pdf"
test -f "$OUTPUT_DIR/mutated.pdf"

printf 'PASS: PDFBox AcroForm benchmark checks passed.\n'
printf 'Artifacts: %s\n' "$OUTPUT_DIR"
