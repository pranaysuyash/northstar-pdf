#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QPDF="${QPDF_BIN:-$(command -v qpdf || true)}"
if [[ -z "$QPDF" ]]; then
  printf 'BLOCKED: qpdf is not installed.\n' >&2
  exit 2
fi

SOURCE="${PDF_EDITOR_SECURITY_SOURCE:-$ROOT/benchmark/results/2026-08-23-pdfkit-widgets/fixture.pdf}"
OUTPUT_DIR="${PDF_EDITOR_SECURITY_OUTPUT_DIR:-$ROOT/benchmark/results/security-corpus}"
[[ -f "$SOURCE" ]] || { printf 'ERROR: source fixture not found: %s\n' "$SOURCE" >&2; exit 2; }
mkdir -p "$OUTPUT_DIR"

# qpdf intentionally randomizes encrypted-file key material, so regenerating
# this artifact would change its bytes and invalidate the reviewed provenance
# digest. Retain the checked-in golden artifact; regenerate it manually only
# when the source or encryption policy changes and the manifest is reviewed.
if [[ ! -f "$OUTPUT_DIR/encrypted-reader.pdf" ]]; then
  "$QPDF" --encrypt reader-password owner-password 256 -- "$SOURCE" "$OUTPUT_DIR/encrypted-reader.pdf"
fi
head -c 128 "$SOURCE" > "$OUTPUT_DIR/truncated-128-bytes.pdf"

if [[ ! -f "$OUTPUT_DIR/repeated-20-pages.pdf" ]]; then
  page_args=()
  for _ in $(seq 1 20); do
    page_args+=("$SOURCE" 1)
  done
  "$QPDF" --empty --pages "${page_args[@]}" -- "$OUTPUT_DIR/repeated-20-pages.pdf"
fi

cat > "$OUTPUT_DIR/README.txt" <<EOF
Generated from: ${SOURCE#$ROOT/}
Generator: benchmark/generate_security_fixtures.sh
Encrypted password: reader-password
Owner password: owner-password
Truncated fixture is intentionally malformed and must fail safely.
Repeated fixture contains 20 copies of source page 1 for page/resource limits.
EOF

printf 'Generated security fixtures in %s\n' "${OUTPUT_DIR#$ROOT/}"
