#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QPDF="${QPDF_BIN:-$(command -v qpdf || true)}"
if [[ -z "$QPDF" ]]; then
  printf 'BLOCKED: qpdf is not installed.\n' >&2
  exit 2
fi

fixtures=(
  "$ROOT/benchmark/results/public-sample-form.pdf"
  "$ROOT/benchmark/results/2026-08-23-pdfkit-widgets/fixture.pdf"
)

for fixture in "${fixtures[@]}"; do
  "$QPDF" --check "$fixture"
done

printf 'PASS: independent qpdf source-structure checks passed for %s fixture(s).\n' "${#fixtures[@]}"
