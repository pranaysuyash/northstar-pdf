#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT/benchmark/results/navigation-corpus"
RAW="$OUT_DIR/pdfkit-navigation-raw.pdf"
FINAL="$OUT_DIR/navigation-metadata.pdf"
mkdir -p "$OUT_DIR"
xcrun swiftc -O -framework Cocoa -framework PDFKit "$ROOT/benchmark/PDFKitNavigationFixture.swift" -o "$OUT_DIR/PDFKitNavigationFixture"
"$OUT_DIR/PDFKitNavigationFixture" "$RAW"
python3 "$ROOT/benchmark/add_navigation_metadata.py" "$RAW" "$FINAL"
rm -f "$RAW" "$OUT_DIR/PDFKitNavigationFixture"
SHA="$(shasum -a 256 "$FINAL" | awk '{print $1}')"
printf 'navigation-metadata.pdf sha256=%s\n' "$SHA"
