#!/usr/bin/env bash
# tools/mupdf-validate.sh
# MuPDF CLI validator — validates a PDF using mutool info, clean, and show.
#
# Usage:
#   bash tools/mupdf-validate.sh <file.pdf> [--json]
#
# Exit codes:
#   0 = Valid
#   1 = Invalid or warnings
#   2 = Missing mutool

set -uo pipefail

if ! command -v mutool &>/dev/null; then
  echo "ERROR: mutool not found (install MuPDF)" >&2
  exit 2
fi

PDF="$1"
JSON_OUTPUT=false
[[ "${2:-}" == "--json" ]] && JSON_OUTPUT=true

if [[ ! -f "$PDF" ]]; then
  echo "ERROR: File not found: $PDF" >&2
  exit 2
fi

# 1. Structural validation (mutool clean — dry run)
CLEAN_OUTPUT=$(mutool clean "$PDF" /dev/null 2>&1) || CLEAN_EXIT=$?
CLEAN_EXIT=${CLEAN_EXIT:-0}

# 2. Info extraction
INFO_OUTPUT=$(mutool info "$PDF" 2>&1) || INFO_EXIT=$?
INFO_EXIT=${INFO_EXIT:-0}

# 3. Object show (first page)
SHOW_OUTPUT=$(mutool show "$PDF" 1 2>&1) || SHOW_EXIT=$?
SHOW_EXIT=${SHOW_EXIT:-0}

# Parse info output for key metrics
PAGES=$(echo "$INFO_OUTPUT" | grep -o 'Pages:\s*[0-9]*' | awk '{print $2}' || echo "unknown")
FILES=$(echo "$INFO_OUTPUT" | grep -o 'Files:\s*[0-9]*' | awk '{print $2}' || echo "unknown")
ENCRYPTED=$(echo "$INFO_OUTPUT" | grep -i "encrypted" | head -1 || echo "no")

if [[ "$JSON_OUTPUT" == "true" ]]; then
  cat <<EOF
{
  "file": "$(basename "$PDF")",
  "pages": "$PAGES",
  "files": "$FILES",
  "encrypted": "$ENCRYPTED",
  "clean_exit": $CLEAN_EXIT,
  "info_exit": $INFO_EXIT,
  "show_exit": $SHOW_EXIT,
  "valid": $([ $CLEAN_EXIT -eq 0 ] && echo "true" || echo "false")
}
EOF
else
  echo "MuPDF Validation: $(basename "$PDF")"
  echo "  Pages: $PAGES"
  echo "  Files: $FILES"
  echo "  Encrypted: $ENCRYPTED"
  echo "  Clean exit: $CLEAN_EXIT"
  echo "  Info exit: $INFO_EXIT"
  echo "  Show exit: $SHOW_EXIT"
  if [[ $CLEAN_EXIT -eq 0 ]]; then
    echo "  Status: VALID ✅"
  else
    echo "  Status: INVALID ❌"
    echo "  Errors: $CLEAN_OUTPUT"
  fi
fi

exit $CLEAN_EXIT
