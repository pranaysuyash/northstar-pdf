#!/usr/bin/env bash
# PERF-S14 snappiness capture — identical protocol for before/after runs.
#
# Measures the two critical findings' validation oracles headlessly:
#   1. Extraction-in-body cost (audit finding 1 / PERF-S01): open-phase
#      call-tree sample (toolbar build) + cputime deltas. NOTE verified
#      2026-09-21: the pipeline extractor is ImprovedTextExtractor
#      (in-process PDFKit full re-parse) — pdf_oxide is NOT on this path;
#      the PATH-shim pdf_oxide counter stays in the protocol to prove the
#      no-child-process property.
#   2. Scroll-path work storm (audit finding 2 / PERF-S02): interaction-phase
#      sample while scripted page-down keystrokes run, with the persisted
#      readingPositions marker as proof the pages actually changed.
#
# Usage: tools/perf-s14-capture/capture.sh before|after
# Output: benchmark/results/2026-09-21-perf-s01s02/<phase>/
set -euo pipefail

PHASE="${1:?usage: capture.sh before|after}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

EVDIR="benchmark/results/2026-09-21-perf-s01s02"
OUT="$EVDIR/$PHASE"
FIXTURE="$EVDIR/perf-fixture-120p.pdf"
APP=".build/debug/PDFEditor"

mkdir -p "$OUT/shim"
cat > "$OUT/shim/pdf_oxide" <<EOF
#!/bin/bash
COUNT_FILE="\${PDF_OXIDE_COUNT_FILE:?}"
n=\$(cat "\$COUNT_FILE" 2>/dev/null || echo 0)
echo \$((n + 1)) > "\$COUNT_FILE"
exit 3
EOF
chmod +x "$OUT/shim/pdf_oxide"
echo 0 > "$OUT/spawn-count.txt"

export PATH="$OUT/shim:$PATH"
export PDF_OXIDE_COUNT_FILE="$OUT/spawn-count.txt"

log() { echo "[$PHASE] $*" | tee -a "$OUT/timeline.log"; }

pos_snapshot() {
  : > "$1"
  for d in PDFEditor pdf-editor pdfeditor com.pdfeditor.PDFEditor .GlobalPreferences; do
    if defaults read "$d" readingPositions >> "$1" 2>/dev/null; then
      echo "domain=$d" >> "$1"
      return 0
    fi
  done
  echo "readingPositions not found in probed domains" >> "$1"
}

log "launching app with 120-page fixture"
# Bare SwiftPM binaries suppress their window when argv carries a document
# (PL-I30) — the supported dev-open path is the PDF_EDITOR_OPEN_SOURCE env hook.
PDF_EDITOR_OPEN_SOURCE="$PWD/$FIXTURE" "$APP" > "$OUT/app-stdout.log" 2>&1 &
APP_PID=$!

log "open-phase call-tree sample (first 6s — toolbar build + canvas mount)"
sample "$APP_PID" 6 -mayDie -file "$OUT/sample-open.txt" > /dev/null 2>&1 || true
CPU_POSTOPEN=$(ps -o cputime= -p "$APP_PID")
log "post-open cputime: $CPU_POSTOPEN"
echo "$CPU_POSTOPEN" > "$OUT/cpu-postopen.txt"

log "window-count check"
osascript -e "tell application \"System Events\" to set frontmost of (first process whose unix id is $APP_PID) to true" 2>"$OUT/ax-error.log" || true
osascript -e "tell application \"System Events\" to get count of windows of (first process whose unix id is $APP_PID)" > "$OUT/window-count.txt" 2>>"$OUT/ax-error.log" || true
log "windows: $(cat "$OUT/window-count.txt" 2>/dev/null || echo probe-failed)"

log "20s idle window (catches per-eval churn without interaction)"
sleep 20
CPU_POSTIDLE=$(ps -o cputime= -p "$APP_PID")
log "post-idle cputime: $CPU_POSTIDLE"
echo "$CPU_POSTIDLE" > "$OUT/cpu-postidle.txt"

pos_snapshot "$OUT/pos-before.txt"
log "reading-position marker before: $(grep -m1 -oE 'pageIndex [0-9]+|pageIndex = [0-9]+' "$OUT/pos-before.txt" || echo none)"

log "scripted page-down keystrokes (12x, 0.4s apart)"
for i in $(seq 1 12); do
  osascript -e 'tell application "System Events" to key code 121' 2>>"$OUT/ax-error.log" || true
  sleep 0.4
done &
KEYSTROKE_PID=$!

log "sampling call tree for 10s during interaction"
sample "$APP_PID" 10 -mayDie -file "$OUT/sample-interaction.txt" > /dev/null 2>&1 || true

# Bounded settle instead of bare `wait`: bare wait includes the app process
# (never exits) and one stuck osascript child would hang the capture
# (observed 2026-09-21).
for i in $(seq 1 20); do
  kill -0 "$KEYSTROKE_PID" 2>/dev/null || break
  sleep 1
done
kill -9 "$KEYSTROKE_PID" 2>/dev/null || true

pos_snapshot "$OUT/pos-after.txt"
log "reading-position marker after: $(grep -m1 -oE 'pageIndex [0-9]+|pageIndex = [0-9]+' "$OUT/pos-after.txt" || echo none)"
CPU_POSTINTERACTION=$(ps -o cputime= -p "$APP_PID")
log "post-interaction cputime: $CPU_POSTINTERACTION"
echo "$CPU_POSTINTERACTION" > "$OUT/cpu-postinteraction.txt"

SPAWNS=$(cat "$OUT/spawn-count.txt")
log "pdf_oxide spawn attempts: $SPAWNS"
# SIGKILL, not SIGTERM: applicationShouldTerminate may .terminateCancel and
# leave the process alive, which would hang the final wait.
kill -9 "$APP_PID" 2>/dev/null || true
sleep 1

{
  echo "phase=$PHASE"
  echo "pdf_oxide_spawn_attempts=$SPAWNS"
  echo "windows=$(cat "$OUT/window-count.txt" 2>/dev/null || echo probe-failed)"
  echo "cpu_postopen=$CPU_POSTOPEN"
  echo "cpu_postidle=$CPU_POSTIDLE"
  echo "cpu_postinteraction=$CPU_POSTINTERACTION"
  echo "ax_error=$(test -s "$OUT/ax-error.log" && echo yes || echo no)"
} > "$OUT/summary.txt"
cat "$OUT/summary.txt"
