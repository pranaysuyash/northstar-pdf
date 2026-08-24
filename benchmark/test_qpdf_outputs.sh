#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QPDF="${QPDF_BIN:-$(command -v qpdf || true)}"
if [[ -z "$QPDF" ]]; then
  printf 'BLOCKED: qpdf is not installed.\n' >&2
  exit 2
fi

files=()
while IFS= read -r -d '' file; do
  files+=("$file")
done < <(find "$ROOT/benchmark/results" "$ROOT/docs/benchmarks" -type f -name '*.pdf' -print0 | sort -z)

if [[ "${#files[@]}" -eq 0 ]]; then
  printf 'BLOCKED: no generated PDF outputs were found in the evidence corpus.\n' >&2
  exit 2
fi

failures=0
warnings=0
for file in "${files[@]}"; do
  case "$file" in
    "$ROOT/benchmark/results/security-corpus/"*|"$ROOT/benchmark/results/ocr-corpus/"*)
      continue
      ;;
  esac
  printf '\n--- qpdf output check: %s ---\n' "${file#$ROOT/}"
  qpdf_args=(--check)
  if [[ "$file" == *"encrypted-reader.pdf" ]]; then
    qpdf_args+=(--password=reader-password)
  fi
  output=""
  status=0
  output=$("$QPDF" "${qpdf_args[@]}" "$file" 2>&1) || status=$?
  printf '%s\n' "$output"
  if [[ "$status" -ne 0 ]]; then
    hardWarnings=$(printf '%s\n' "$output" | rg '^WARNING:' | rg -v 'object has offset 0 - a common error handled correctly by qpdf and most other applications' || true)
    hardDiagnostics=$(printf '%s\n' "$output" | rg '^qpdf:' | rg -v 'operation succeeded with warnings' || true)
    if [[ -z "$hardWarnings" && -z "$hardDiagnostics" && "$output" == *"operation succeeded with warnings"* ]]; then
      warnings=$((warnings + 1))
      printf 'WARN: accepted recoverable cross-reference offset warnings for this artifact; see docs/policies/pdf-output-validation.md.\n'
    else
      failures=$((failures + 1))
    fi
  fi
done

if [[ "$failures" -ne 0 ]]; then
  printf '\nFAIL: %s generated PDF output(s) failed independent qpdf validation; %s artifact(s) had classified recoverable warnings.\n' "$failures" "$warnings" >&2
  exit 1
fi

printf '\nPASS: independent qpdf output checks passed for %s generated PDF(s); %s artifact(s) had classified recoverable warnings.\n' "${#files[@]}" "$warnings"
