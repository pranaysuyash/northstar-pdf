#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PDFINFO="${PDFINFO_BIN:-$(command -v pdfinfo || true)}"
PDFTOTEXT="${PDFTOTEXT_BIN:-$(command -v pdftotext || true)}"
MUTOOL="${MUTOOL_BIN:-$(command -v mutool || true)}"
if [[ -z "$PDFINFO" || -z "$PDFTOTEXT" || -z "$MUTOOL" ]]; then
  printf 'BLOCKED: Poppler pdfinfo/pdftotext and MuPDF mutool are required.\n' >&2
  exit 2
fi

files=()
while IFS= read -r -d '' file; do
  case "$file" in
    "$ROOT/benchmark/results/security-corpus/truncated-128-bytes.pdf"|*"/malformed-"*.pdf) continue ;;
    *) files+=("$file") ;;
  esac
done < <(find "$ROOT/benchmark/results" "$ROOT/docs/benchmarks" -type f -name '*.pdf' -print0 | sort -z)

failures=0
for file in "${files[@]}"; do
  printf '\n--- independent viewer reopen: %s ---\n' "${file#$ROOT/}"
  info_args=()
  text_args=()
  if [[ "$file" == *"encrypted-reader"*.pdf || "$file" == *"encrypted-"*.pdf ]]; then
    info_args+=("-upw" "reader-password")
    text_args+=("-upw" "reader-password")
  fi
  info=""
  if ((${#info_args[@]})); then
    if ! info="$($PDFINFO "${info_args[@]}" "$file" 2>/tmp/pdf-editor-pdfinfo.$$.err)"; then
      printf 'FAIL: Poppler could not reopen this PDF. %s\n' "$(tr '\n' ' ' </tmp/pdf-editor-pdfinfo.$$\.err)" >&2
      failures=$((failures + 1))
      rm -f /tmp/pdf-editor-pdfinfo.$$\.err
      continue
    fi
  else
    if ! info="$($PDFINFO "$file" 2>/tmp/pdf-editor-pdfinfo.$$\.err)"; then
      printf 'FAIL: Poppler could not reopen this PDF. %s\n' "$(tr '\n' ' ' </tmp/pdf-editor-pdfinfo.$$\.err)" >&2
      failures=$((failures + 1))
      rm -f /tmp/pdf-editor-pdfinfo.$$\.err
      continue
    fi
  fi
  rm -f /tmp/pdf-editor-pdfinfo.$$\.err
  if ! printf '%s\n' "$info" | rg -q '^Pages: *[1-9][0-9]*$'; then
    printf 'FAIL: independent viewer could not report a positive page count.\n' >&2
    failures=$((failures + 1))
    continue
  fi
  text_failed=0
  if ((${#text_args[@]})); then
    if ! "$PDFTOTEXT" "${text_args[@]}" "$file" - >/dev/null 2>&1; then text_failed=1; fi
  else
    if ! "$PDFTOTEXT" "$file" - >/dev/null 2>&1; then text_failed=1; fi
  fi
  if [[ "$text_failed" -ne 0 ]]; then
    printf 'FAIL: independent viewer could not extract/reopen text stream.\n' >&2
    failures=$((failures + 1))
  fi
  mutool_failed=0
  if [[ "$file" == *"encrypted-reader"*.pdf || "$file" == *"encrypted-"*.pdf ]]; then
    if ! "$MUTOOL" info -p reader-password "$file" >/tmp/pdf-editor-mutool-info.$$ 2>&1; then mutool_failed=1; fi
  else
    if ! "$MUTOOL" info "$file" >/tmp/pdf-editor-mutool-info.$$ 2>&1; then mutool_failed=1; fi
  fi
  if [[ "$mutool_failed" -ne 0 ]] || ! rg -q '^Pages: *[1-9][0-9]*$' /tmp/pdf-editor-mutool-info.$$; then
    printf 'FAIL: MuPDF could not independently reopen/report pages.\n' >&2
    failures=$((failures + 1))
  fi
  rm -f /tmp/pdf-editor-mutool-info.$$
done

if [[ "$failures" -ne 0 ]]; then
  printf '\nFAIL: %s corpus PDF(s) failed independent viewer reopen.\n' "$failures" >&2
  exit 1
fi

printf '\nPASS: Poppler independently reopened and inspected %s corpus PDF(s).\n' "${#files[@]}"
