#!/bin/zsh
# measure_app_launch.sh — time PDFEditor from spawn to visible window.
#
# Usage:
#   ./scripts/measure_app_launch.sh [runs] [--warm]
#   Default: 3 cold runs (app killed + caches kept; true cold = reboot, noted).
#   --warm: keep process out but measure relaunch with warm dyld/file caches.
#
# Method: spawn the built binary, poll CGWindowList via Python until a
# window owned by the PID appears, record elapsed ms. This measures
# "time to open" the way a user feels it: icon bounce -> visible window.
# Debug builds are slower than release; always record which config ran.

set -euo pipefail
cd "$(dirname "$0")/.."

RUNS="${1:-3}"
MODE="cold"
[[ "${2:-}" == "--warm" ]] && MODE="warm"

BINARY=".build/arm64-apple-macosx/debug/PDFEditor"
[[ -x "$BINARY" ]] || { echo "binary missing; run: swift build --product PDFEditor" >&2; exit 1; }

poll_for_window() {
  local pid="$1" deadline_ms="$2"
  # Precise poll: compiled Swift helper watches CGWindowList for an
  # on-screen window owned by $pid. Falls back to AppleScript if missing.
  if [[ -x /tmp/window_poll ]]; then
    /tmp/window_poll "$pid" "$deadline_ms"
    return $?
  fi
  local start_ms=$(python3 -c 'import time; print(int(time.monotonic()*1000))')
  while true; do
    local now_ms=$(python3 -c 'import time; print(int(time.monotonic()*1000))')
    (( now_ms - start_ms > deadline_ms )) && { echo "TIMEOUT"; return 1; }
    local n
    n=$(osascript -e 'tell application "System Events" to get count of windows of (first process whose unix id is '"$pid"')' 2>/dev/null || echo "0")
    if [[ "$n" =~ ^[1-9][0-9]*$ ]]; then
      echo $(( now_ms - start_ms ))
      return 0
    fi
    sleep 0.2
  done
}

echo "mode=$MODE runs=$RUNS binary=$BINARY"
for i in $(seq 1 "$RUNS"); do
  pkill -f "\.build.*PDFEditor" 2>/dev/null || true
  sleep 1
  if [[ "$MODE" == "cold" ]]; then
    # Cold-ish: drop file caches for the build dir is overkill; we kill the
    # process and let dyld/page cache stay warm. True cold (post-reboot)
    # is recorded manually in the perf plan when needed.
    :
  fi
  T0=$(python3 -c 'import time; print(int(time.monotonic()*1000))')
  nohup "$BINARY" > /tmp/pdfeditor_mac.log 2>&1 &
  PID=$!
  if MS=$(poll_for_window "$PID" 60000); then
    echo "run $i: ${MS}ms (pid $PID)"
  else
    echo "run $i: TIMEOUT waiting for window (pid $PID)"
  fi
done
echo "done. app left running; baseline goes to docs/perf-test-plan.md"
