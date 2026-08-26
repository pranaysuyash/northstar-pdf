#!/bin/bash
# Pre-push hook — mirrors CI gates (RG-081 local).
# Install: ln -sf ../../tools/pre-push-hook.sh .git/hooks/pre-push
set -euo pipefail

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
