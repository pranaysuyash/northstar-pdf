# Getting Started — PDF Editor

**What this is:** A local-first PDF reader/editor for macOS and browser. The core invariant: original PDF bytes are never mutated. Every edit targets a specific region, is reversible, and exports to a new copy.

## Build

```bash
# macOS (Swift 6.0+, macOS 15+)
swift build                    # debug build
swift build -c release         # release build
swift test                     # run all 252 tests

# Web companion (Node.js 24+)
node Tests/web_reader_contract_test.mjs      # 51 contract checks
node Tests/pdf_contract_parity_mutation_test.mjs  # 10 mutation checks
node Tests/web_editor_workflow_test.mjs       # browser E2E (self-booting server)
node Tests/run-web-e2e.mjs                    # full Playwright suite
```

## Project structure

```
Sources/
├── PDFEditorCore/          # 49 files — provider-neutral contracts, detection,
│                           #   incremental form writer, template system, security,
│                           #   validation, learning loop, capability lanes
├── PDFEditorApp/           # 11 files — SwiftUI views, toolbar, inspector
├── PDFEditorRecovery/      # 6 files — session persistence, autosave, AppModel
├── PDFEditorInlineEditor/  # 1 file — on-canvas text editor host
└── [harnesses]             # 6 harness files — benchmarks, contracts, templates

Tests/
├── PDFEditorCoreTests/     # 25 Swift test suites (252 tests)
└── *.mjs                   # 80+ Node test files (web contracts, mutations, E2E)

web/
├── app/                    # React companion (TypeScript)
├── *.mjs                   # Browser contract/mutation/detection modules
└── index.html              # Main web app entry

docs/
├── decisions.md            # All durable decisions (D-001 through D-055)
├── release-gates.md        # 127 gates with evidence
├── audits/                 # Persona audit reports
├── personas/               # Vendored persona definitions
└── runbooks/               # Operational guides

benchmark/
├── results/                # Generated test artifacts (don't commit stale ones)
└── *.mjs                   # Benchmark runners
```

## Key concepts

| Concept | What it means |
|---|---|
| **Source-byte immutability** | Original PDF bytes are never written to. Exports create new copies. |
| **EditOperation** | Typed edit: `.overlayText`, `.nativeFieldValue`, `.textRunReplacement`, etc. |
| **Candidate** | Detected fill region with evidence. States: suggested → confirmed/rejected. |
| **Learning loop** | User review decisions are recorded (value-free) and used to rank future suggestions. |
| **Provider adapter** | PDFKit (native) or PDF.js/pdf-lib (browser) behind shared contracts. |
| **Capability lane** | Named capability (OCR, redaction, signatures) with evidence-gated activation. |
| **Release gate** | acceptance oracle with PASS/PARTIAL/OPEN/BLOCKED/FAIL state and linked evidence. |

## How to add a feature

1. Check `docs/release-gates.md` for existing gates
2. Add operation type to `EditOperation` if new kind
3. Implement in both native (Swift) and browser (TypeScript) adapters
4. Write tests: S1 for basic pass, S2 for fix verification, S3 for mutation kills
5. Update gate evidence in `release-gates.md`
6. Append to `progress.md`

## How to run the full test suite

```bash
# Everything at once
swift test && \
node Tests/web_reader_contract_test.mjs && \
node Tests/pdf_contract_parity_mutation_test.mjs && \
node Tests/web_editor_workflow_test.mjs && \
node Tests/redaction_completeness_mutation_test.mjs && \
node Tests/pdf-signature-guard-mutation-test.mjs && \
node Tests/run-tool-dependent-tests.mjs
```

## Architecture in one sentence

SwiftUI App → AppModel → PDFKitProvider (native) or PDF.js/pdf-lib (browser) → shared contracts → EditOperation → incremental export → validation → new PDF copy.
