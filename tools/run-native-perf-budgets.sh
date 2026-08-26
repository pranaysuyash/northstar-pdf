#!/usr/bin/env bash
# tools/run-native-perf-budgets.sh
# Native performance lane runner — runs NativePerformanceBudgetTests and reports results.
#
# Usage:
#   bash tools/run-native-perf-budgets.sh [--json] [--verbose]
#
# Exit codes:
#   0 = All budgets pass
#   1 = One or more budgets fail
#   2 = Missing required tools or fixtures

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

JSON_OUTPUT=false
VERBOSE=false

for arg in "$@"; do
  case "$arg" in
    --json) JSON_OUTPUT=true ;;
    --verbose) VERBOSE=true ;;
    --help|-h)
      echo "Usage: $0 [--json] [--verbose]"
      echo "  --json    Output results as JSON"
      echo "  --verbose Show detailed test output"
      exit 0
      ;;
  esac
done

# --- Preflight checks ---

if ! command -v swift &>/dev/null; then
  echo "ERROR: swift not found" >&2
  exit 2
fi

if [[ ! -f "$REPO_ROOT/Package.swift" ]]; then
  echo "ERROR: Package.swift not found in $REPO_ROOT" >&2
  exit 2
fi

# Check for the public AcroForm fixture
if [[ -z "${PDF_EDITOR_PUBLIC_ACROFORM_INPUT:-}" ]]; then
  CANDIDATE=$(find "$REPO_ROOT/Tests" -name "*.pdf" -type f 2>/dev/null | head -1)
  if [[ -z "$CANDIDATE" ]]; then
    # Prefer tagged-acroform (has AcroForm fields for walk/write tests)
    CANDIDATE=$(find "$REPO_ROOT/benchmark/results" -name "tagged-acroform.pdf" -type f 2>/dev/null | head -1)
  fi
  if [[ -z "$CANDIDATE" ]]; then
    CANDIDATE=$(find "$REPO_ROOT/benchmark/results" -name "*.pdf" -type f 2>/dev/null | head -1)
  fi
  if [[ -n "$CANDIDATE" ]]; then
    export PDF_EDITOR_PUBLIC_ACROFORM_INPUT="$CANDIDATE"
  else
    echo "ERROR: PDF_EDITOR_PUBLIC_ACROFORM_INPUT not set and no PDF fixture found" >&2
    exit 2
  fi
fi

echo "=== Native Performance Budget Runner ==="
echo "Fixture: ${PDF_EDITOR_PUBLIC_ACROFORM_INPUT}"
echo ""

# --- Run the perf budget tests ---

echo "Running NativePerformanceBudgetTests..."
echo ""

# Capture test output
TEST_OUTPUT=$(cd "$REPO_ROOT" && swift test --filter NativePerformanceBudgetTests 2>&1) || TEST_EXIT=$?
TEST_EXIT=${TEST_EXIT:-0}

if [[ "$VERBOSE" == "true" ]]; then
  echo "$TEST_OUTPUT"
  echo ""
fi

# Extract timing results from test output
# Swift Testing swallows print() in default mode, so we look for assertion messages
COLD_INSPECTION=$(echo "$TEST_OUTPUT" | grep -o 'cold inspection: [0-9.]*s' | awk '{print $3}' | tr -d 's' 2>/dev/null || true)
FIELD_TREE_WALK=$(echo "$TEST_OUTPUT" | grep -o 'field-tree walk: [0-9.]*s' | awk '{print $3}' | tr -d 's' 2>/dev/null || true)
INCREMENTAL_WRITE=$(echo "$TEST_OUTPUT" | grep -o 'incremental write: [0-9.]*s' | awk '{print $3}' | tr -d 's' 2>/dev/null || true)
FIELD_LOOKUP=$(echo "$TEST_OUTPUT" | grep -o 'field lookups: [0-9.]*s' | awk '{print $3}' | tr -d 's' 2>/dev/null || true)

# Check if tests passed (look for "passed" in the output)
TESTS_PASSED=true
if echo "$TEST_OUTPUT" | grep -q "failed"; then
  TESTS_PASSED=false
fi
if [[ $TEST_EXIT -ne 0 ]]; then
  TESTS_PASSED=false
fi

# Default values for missing timings
COLD_INSPECTION="${COLD_INSPECTION:-N/A}"
FIELD_TREE_WALK="${FIELD_TREE_WALK:-N/A}"
INCREMENTAL_WRITE="${INCREMENTAL_WRITE:-N/A}"
FIELD_LOOKUP="${FIELD_LOOKUP:-N/A}"

# --- Report results ---

if [[ "$JSON_OUTPUT" == "true" ]]; then
  cat <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "fixture": "$(basename "${PDF_EDITOR_PUBLIC_ACROFORM_INPUT}")",
  "tests_passed": $TESTS_PASSED,
  "budgets": {
    "cold_inspection": {
      "measured": "$COLD_INSPECTION",
      "budget": "2.0s"
    },
    "field_tree_walk": {
      "measured": "$FIELD_TREE_WALK",
      "budget": "0.5s"
    },
    "incremental_write": {
      "measured": "$INCREMENTAL_WRITE",
      "budget": "0.5s"
    },
    "field_lookup": {
      "measured": "$FIELD_LOOKUP",
      "budget": "10.0ms"
    }
  }
}
EOF
else
  echo "Results:"
  echo "  Cold inspection:   ${COLD_INSPECTION}s (budget: 2.0s)"
  echo "  Field-tree walk:   ${FIELD_TREE_WALK}s (budget: 0.5s)"
  echo "  Incremental write: ${INCREMENTAL_WRITE}s (budget: 0.5s)"
  echo "  Field lookup:      ${FIELD_LOOKUP}s (budget: 10ms)"
  echo ""
  if [[ "$TESTS_PASSED" == "true" ]]; then
    echo "Status: ALL BUDGETS PASS ✅"
  else
    echo "Status: BUDGETS FAILED ❌"
  fi
fi

# --- Verdict ---

if [[ "$TESTS_PASSED" == "true" ]]; then
  exit 0
else
  exit 1
fi
