#!/bin/bash
# Pre-push hook — mirrors CI gates (RG-081 local).
# Install: ln -sf ../../tools/pre-push-hook.sh .git/hooks/pre-push
set -euo pipefail

# Fixture integrity check — prevent pushing with missing test fixtures
# (Remediation for 2026-08-26 doctrine deviation: --no-verify bypass)
FIXTURE_COUNT=$(find benchmark/results -name '*.pdf' 2>/dev/null | wc -l | tr -d ' ')
if [ "$FIXTURE_COUNT" -lt 10 ]; then
  echo "PRE-PUSH BLOCKED: Only $FIXTURE_COUNT fixture PDFs found (expected 100+)"
  echo "Run: git checkout HEAD -- benchmark/results/"
  echo "Then retry the push."
  exit 1
fi
echo "Fixture check: $FIXTURE_COUNT PDFs present ✓"

echo "=== Pre-push: Swift test ==="
swift test 2>&1 | tail -5

echo ""
echo "=== Pre-push: Core node contracts ==="
CORE_TESTS=(
  Tests/web_reader_contract_test.mjs
  Tests/pdf_contract_parity_mutation_test.mjs
  Tests/pdf_capability_lanes_test.mjs
)
for test in "${CORE_TESTS[@]}"; do
  [ -f "$test" ] && node "$test"
done

echo ""
echo "=== Pre-push: all gates passed ==="
