#!/bin/sh
# verify-all.sh — single local entry point proving both planes healthy.
# Air-gap compatible: no external services. Derived from
# docs/roadmaps/implementation-plan-2026-08-26.md Phase P1.
#
# Usage:
#   tools/verify-all.sh              # build + swift test + contract suite
#   tools/verify-all.sh --quick      # skip swift test (build + contracts only)
#   tools/verify-all.sh --contracts  # contract suite only
#
# Exit code 0 = all green. Any failure prints the failing stage last.

set -u

MODE="${1:-all}"
FAILURES=""

run_stage() {
  name="$1"; shift
  printf '\n=== [%s] %s ===\n' "$(date '+%H:%M:%S')" "$name"
  if "$@"; then
    printf '=== PASS: %s ===\n' "$name"
  else
    status=$?
    printf '=== FAIL(%s): %s ===\n' "$status" "$name"
    FAILURES="$FAILURES $name($status)"
  fi
}

case "$MODE" in
  --contracts)
    run_stage "contract-suite" node tools/run-contract-tests.mjs
    ;;
  --quick)
    run_stage "swift-build" swift build
    run_stage "contract-suite" node tools/run-contract-tests.mjs
    ;;
  all)
    run_stage "swift-build" swift build
    run_stage "swift-test" swift test
    run_stage "contract-suite" node tools/run-contract-tests.mjs
    ;;
  *)
    echo "unknown mode: $MODE (use: none | --quick | --contracts)" >&2
    exit 64
    ;;
esac

printf '\n================ SUMMARY ================\n'
if [ -z "$FAILURES" ]; then
  printf 'ALL GREEN\n'
  exit 0
fi
printf 'FAILED STAGES:%s\n' "$FAILURES"
exit 1
