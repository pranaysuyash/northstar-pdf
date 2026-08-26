#!/usr/bin/env bash
# PDFBox corpus lane: runs the generalized RadioProbe against the broader
# fixture set, preserves one result.json per fixture under
# benchmark/results/2026-08-25-pdfbox-corpus/<fixture-name>/, jq-gates each,
# and prints a summary table. Exits nonzero on any unexpected failure.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LANE_DIR="$ROOT/benchmark/pdfbox-lane"
JAR="$LANE_DIR/pdfbox-app-3.0.8.jar"
JAR_SHA512_FILE="$JAR.sha512"
CORPUS_DIR="$ROOT/benchmark/results/2026-08-25-pdfbox-corpus"
CLASSES_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pdfbox-corpus-classes.XXXXXX")"
trap 'rm -rf "$CLASSES_DIR"' EXIT

die() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

mkdir -p "$CORPUS_DIR"

# Java 17+, headless.
JAVA_MAJOR="$(java -version 2>&1 | awk -F '"' '/version/ {split($2, v, "."); print v[1]; exit}')"
case "$JAVA_MAJOR" in
  ''|*[!0-9]*) die "cannot parse java major version" ;;
esac
if [ "$JAVA_MAJOR" -lt 17 ]; then
  die "need Java >= 17, found major '$JAVA_MAJOR'"
fi

if [ ! -f "$JAR" ]; then die "missing PDFBox fat jar: $JAR"; fi

# Verify the jar against the published SHA-512 before trusting results.
EXPECTED_SHA512="$(tr -cd '0-9a-fA-F' < "$JAR_SHA512_FILE" | tr 'A-F' 'a-f')"
ACTUAL_SHA512="$(openssl dgst -sha512 "$JAR" | awk '{print $NF}')"
if [ "$EXPECTED_SHA512" != "$ACTUAL_SHA512" ]; then
  die "jar SHA-512 mismatch (expected $EXPECTED_SHA512, got $ACTUAL_SHA512)"
fi

javac -cp "$JAR" -d "$CLASSES_DIR" "$LANE_DIR/RadioProbe.java"

# Fixture registry: name | input path | extra flags
FIXTURES=(
  "public-sample-form|$ROOT/benchmark/results/public-sample-form.pdf|--raster"
  "rotated-widget-90|$ROOT/benchmark/results/rotation-corpus/rotated-widget-90.pdf|--raster"
  "rotated-form6-mixed|$ROOT/benchmark/results/rotation-corpus/rotated-form6-mixed.pdf|--raster"
  "encrypted-reader|$ROOT/benchmark/results/security-corpus/encrypted-reader.pdf|--no-mutate"
  "native-widgets|$ROOT/benchmark/results/2026-08-23-pdfkit-widgets/native-widgets.pdf|--no-mutate"
)

ANY_FAIL=0
declare -a TABLE_ROWS=()

row_value() { # row_value <result.json> <jq filter> <fallback>
  local v
  v="$(jq -r "$2 // \"$3\"" "$1" 2>/dev/null)" || v="$3"
  printf '%s' "$v"
}

run_fixture() {
  local spec="$1"
  local name input flags out result verdict
  IFS='|' read -r name input flags <<<"$spec"
  out="$CORPUS_DIR/$name"
  result="$out/result.json"
  mkdir -p "$out"

  printf '== %s ==\n' "$name"
  if ! java -Djava.awt.headless=true \
       -Dpdfbox.jar.sha512="$ACTUAL_SHA512" \
       -cp "$JAR:$CLASSES_DIR" \
       RadioProbe "$input" "$out" $flags \
       > "$out/result.json.tmp" 2> "$out/probe.stderr.log"; then
    mv "$out/result.json.tmp" "$result" 2>/dev/null || true
    printf '   CRASH: probe exited nonzero (see %s)\n' \
      "$out/probe.stderr.log" >&2
    TABLE_ROWS+=("$(printf '%s|%s|%s|%s|%s|%s|%s|CRASH' \
      "$name" '-' '-' '-' '-' '-' '-')")
    ANY_FAIL=1
    return
  fi
  mv "$out/result.json.tmp" "$result"

  case "$name" in
    encrypted-reader)
      # Documented failure mode, not a crash: PDFBox cannot open the file
      # without a password; the lane must record encryptedUnsupported.
      if jq -e '.encryptedUnsupported == true
                and .failureMode == "encrypted-no-password"
                and .originalUnchanged == true' "$result" >/dev/null; then
        verdict=PASS
      else
        verdict=FAIL
      fi
      ;;
    public-sample-form)
      # Fields exist here: full oracle incl. mutation + exact raster parity.
      if jq -e '.encryptedUnsupported == false
                and .noOpReopen == true
                and .widgetStateEquivalent == true
                and .mutatedReopen == true
                and .originalUnchanged == true
                and .rasterAE == 0' "$result" >/dev/null; then
        verdict=PASS
      else
        verdict=FAIL
      fi
      ;;
    native-widgets)
      # Negative control: PDFKit-native widgets, zero AcroForm fields,
      # mutation not applicable, no raster phase requested.
      if jq -e '.encryptedUnsupported == false
                and .fieldCount == 0
                and .mutateSkipped == true
                and .originalUnchanged == true' "$result" >/dev/null; then
        verdict=PASS
      else
        verdict=FAIL
      fi
      ;;
    *)
      # Rotation fixtures: widget-state gates apply only where fields exist;
      # both are currently field-less qpdf --rotate derivatives, so parity
      # rests on originalUnchanged + exact raster equality of page 1.
      if jq -e '.encryptedUnsupported == false
                and (.pages != null)
                and (.originalUnchanged == true)
                and (.rasterAE == 0)
                and ((.fieldCount == 0)
                     or (.noOpReopen == true
                         and .widgetStateEquivalent == true))' \
           "$result" >/dev/null; then
        verdict=PASS
      else
        verdict=FAIL
      fi
      ;;
  esac

  [ "$verdict" = PASS ] || ANY_FAIL=1

  TABLE_ROWS+=("$(printf '%s|%s|%s|%s|%s|%s|%s|%s' \
    "$name" \
    "$(row_value "$result" '.pages' '-')" \
    "$(row_value "$result" '.fieldCount' '-')" \
    "$(row_value "$result" '.noOpReopen' '-')" \
    "$(row_value "$result" '.widgetStateEquivalent' '-')" \
    "$(row_value "$result" '.mutatedReopen' '-')" \
    "$(row_value "$result" '.rasterAE' '-')" \
    "$verdict")")
}

for spec in "${FIXTURES[@]}"; do
  run_fixture "$spec"
done

echo
echo "PDFBox corpus summary (${CORPUS_DIR#$ROOT/}):"
printf '%-20s %5s %6s %-5s %-5s %-7s %-8s %s\n' \
  fixture pages fields noOp state mutatd rasterAE verdict
for row in "${TABLE_ROWS[@]}"; do
  IFS='|' read -r n p f o s m r v <<<"$row"
  printf '%-20s %5s %6s %-5s %-5s %-7s %-8s %s\n' \
    "$n" "$p" "$f" "$o" "$s" "$m" "$r" "$v"
done
echo

if [ "$ANY_FAIL" -ne 0 ]; then
  die "corpus lane failed; results preserved under $CORPUS_DIR"
fi

printf 'PASS: all PDFBox corpus fixtures passed.\n'
printf 'Artifacts: %s\n' "$CORPUS_DIR"
