# Runbook: Run the Full Test Suite

**When:** Before any commit, before any push, after any significant change.
**Time:** ~2 minutes for core gates; ~5 minutes for full suite.

## Core gates (required before push)

```bash
# Gate 1: Swift tests (252 tests, 36 suites)
swift test

# Gate 2: Core Node contract tests (no external tools needed)
node Tests/web_reader_contract_test.mjs          # 51 checks
node Tests/pdf_contract_parity_mutation_test.mjs  # 10 checks
node Tests/pdf_capability_lanes_test.mjs          # capability lanes

# Gate 3: Self-booting browser workflow test
node Tests/web_editor_workflow_test.mjs           # full editor workflow
```

## Extended gates (run periodically)

```bash
# S3 mutation tests (prove guards kill tampering)
node Tests/redaction_completeness_mutation_test.mjs  # 7 mutations
node Tests/pdf-signature-guard-mutation-test.mjs     # 12 mutations

# Network-egression assertion (RG-028)
node Tests/browser_network_egression_assertion_test.mjs

# Tool-dependent tests (graceful skip when tools missing)
node Tests/run-tool-dependent-tests.mjs
```

## Full Playwright E2E suite

```bash
# Installs Chromium, starts server, runs all Playwright tests
node Tests/run-web-e2e.mjs

# Or run specific test
node Tests/run-web-e2e.mjs editor_workflow
```

## CI (GitHub Actions)

The CI workflow (`.github/workflows/ci.yml`) runs 4 gates on every push:
1. **swift-gate**: `swift test` + `swift build -c release`
2. **node-contract**: 31 pure-Node tests
3. **web-e2e**: Playwright browser suite
4. **tool-dependent**: qpdf/popler/pikepdf tests (graceful skip)

The evidence-summary job gates the workflow on gates 1+2; web-e2e and tool-dependent are advisory.

## Pre-push hook

The pre-push hook (`.git/hooks/pre-push` → `tools/pre-push-hook.sh`) runs automatically on every `git push`:
- `swift test` (252 tests)
- 3 core Node contract tests

If any test fails, the push is blocked.

## Troubleshooting

**`swift test` fails with "target not found":**
```bash
swift package clean
swift build
swift test
```

**Browser workflow test times out:**
Run the canonical runner, which self-boots a static server on a free port
(never 4173) and shuts it down afterwards:
```bash
node Tests/run-web-e2e.mjs web_editor
```
If a run still hangs, check for a squatter on the port it selected:
```bash
lsof -i :8090
# Kill any process using it
```

**Node tests fail with "module not found":**
```bash
npm install  # if web/app has dependencies
```

**Tool-dependent tests skip everything:**
Install the tools:
```bash
brew install qpdf poppler
pip3 install pikepdf
```
