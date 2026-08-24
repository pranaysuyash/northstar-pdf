# PDF Reader/Editor Release-Gate Evidence Snapshot

**Evidence date:** 2026-08-24

This is the current release snapshot. Earlier audit documents remain historical evidence; this document is the authoritative status for the latest expanded 11-fixture run.

## Passing evidence

| Lane | Command | Result |
|---|---|---|
| Native core and app | `swift test` | `62` tests passed across 4 Swift Testing suites; the app target also built |
| Native reader gate | `swift test --filter PDFReaderGateTests` | `9` reader/security/rotation/OCR tests passed |
| Browser reader contract | `node Tests/web_reader_contract_test.mjs` | `44` checks passed |
| Browser accessibility | `node Tests/web_accessibility_gate_test.mjs` | Landmarks, skip-link focus, keyboard text access, password dialog, and zero-runtime-error gate passed |
| Browser fixture corpus | `node Tests/web_pdf_contract_fixture_test.mjs` | `11` fixtures completed; no-op exports are byte-preserving, encrypted edits are rejected |
| Browser proof | `node Tests/web_pdf_proof_playwright_test.mjs` | Native-field and static-region browser export workflows validated |
| Native/web parity | `node Tests/pdf_contract_parity_test.mjs` | `11` fixtures inspected; source digests and expected malformed-input behavior agree; navigation metadata fixture has zero semantic metadata mismatches |
| Independent viewers | `bash benchmark/test_independent_viewer.sh` | Poppler/MuPDF reopened `38` eligible PDFs |
| Independent preservation | `node Tests/pdf_independent_preservation_test.mjs` | Unauthorized text/raster edits rejected; authorized region and rotated fixtures passed |
| Security | `bash benchmark/test_security_fixtures.sh` | AES-256, malformed, and repeated-page fixtures passed |
| Web mutation safety | `node Tests/web_pdf_contract_mutation_test.mjs` | Seven fail-closed mutation cases passed with zero writer calls |
| Source structure | `bash benchmark/test_qpdf_structure.sh` | Source fixtures passed qpdf structural checks |

## Restricted or open evidence

| Gate | Current state | Consequence |
|---|---|---|
| Generated qpdf output | Failed, preserved: `8` hard AcroForm widget-reachability artifacts; `6` classified cross-reference warnings | No unrestricted edited-PDF release claim; qpdf remains independent structural evidence, not replaced by reopenability |
| Native/web parity | `63` normalized mismatches remain across 11 fixtures, concentrated in form-state normalization, candidate detection, validation check shape/status, accessibility notes, and encrypted security semantics | Cross-lane parity is not complete; metadata/navigation parity is complete only for the representative fixture and surfaces documented in the companion audit |
| External AcroForms | Read-only/no-op preservation boundary remains active | Editing external AcroForms requires a form-aware provider with independent output validation |
| Encrypted edits | Browser rejects edits; native edited-encrypted fidelity remains conditional | Encrypted documents may be inspected and no-op exported, not advertised as generally editable |
| Accessibility | Keyboard/accessibility shell passes; tagged content, reading order, and PDF/UA conformance remain validator-backed conditional claims | No PDF/UA or universal reading-order claim |

## Release decision

**Scoped NO-GO for unrestricted release.**

The native and web reader lanes, representative navigation metadata, no-op preservation path, security boundaries, and browser accessibility shell have current passing evidence. The product must remain restricted to the documented provider capability boundaries until the generated-output qpdf failures and remaining semantic parity mismatches are either repaired with stronger evidence or explicitly excluded by a reviewed release policy.

## Reproduction artifacts

- Current parity report: `benchmark/results/contract-parity-2026-08-24/parity-report.json`
- Current independent preservation report: `benchmark/results/contract-parity-2026-08-24/independent-preservation-report.json`
- Fixture provenance: `docs/fixtures/manifest.md`
- Navigation metadata audit: `docs/audits/navigation-metadata-evidence-2026-08-24.md`
- Output validation policy: `docs/policies/pdf-output-validation.md`

