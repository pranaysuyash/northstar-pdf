#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QPDF="${QPDF_BIN:-$(command -v qpdf || true)}"
if [[ -z "$QPDF" ]]; then
  printf 'BLOCKED: qpdf is not installed.\n' >&2
  exit 2
fi

DIR="${PDF_EDITOR_SECURITY_OUTPUT_DIR:-$ROOT/benchmark/results/security-corpus}"
encrypted="$DIR/encrypted-reader.pdf"
truncated="$DIR/truncated-128-bytes.pdf"
repeated="$DIR/repeated-20-pages.pdf"
for file in "$encrypted" "$truncated" "$repeated"; do
  [[ -f "$file" ]] || { printf 'BLOCKED: missing generated fixture: %s\n' "$file" >&2; exit 2; }
done

"$QPDF" --check --password=reader-password "$encrypted"
"$QPDF" --check "$repeated"

if "$QPDF" --check "$truncated" >/tmp/pdf-editor-truncated-qpdf.$$ 2>&1; then
  cat /tmp/pdf-editor-truncated-qpdf.$$ >&2
  rm -f /tmp/pdf-editor-truncated-qpdf.$$
  printf 'FAIL: truncated fixture unexpectedly passed qpdf validation.\n' >&2
  exit 1
fi
rm -f /tmp/pdf-editor-truncated-qpdf.$$

printf 'PASS: encrypted, malformed, and repeated-page security fixtures behaved as expected.\n'
