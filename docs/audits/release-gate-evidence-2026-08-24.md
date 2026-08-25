# PDF Reader/Editor Release-Gate Evidence Snapshot

**Evidence date:** 2026-08-24

This is the current release snapshot. Earlier audit documents remain historical evidence; this document is the authoritative status for the latest expanded 11-fixture run.

## Passing evidence

| Lane | Command | Result |
|---|---|---|
| Native core and app | isolated current-source snapshot `swift test` | `67` tests passed across 4 Swift Testing suites; shared-checkout verification remains separately open because `AppModel.swift` is being modified externally during direct builds |
| Native reader gate | included in isolated snapshot `swift test` | `PDFReaderGateTests` passed within the 67-test snapshot; a fresh direct shared-checkout run remains required |
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
| Native Swift verification | Environment-blocked: current `swift test` and targeted `swift test --filter PDFReaderGateTests` both observed source mutation during compilation | Historical native passes are not treated as current proof; no unrestricted release claim until a stable checkout produces fresh native results; see [`native-build-stability-evidence-2026-08-24.md`](native-build-stability-evidence-2026-08-24.md) |
| Generated qpdf output | Pass: `39` generated PDFs checked; `6` classified cross-reference warnings; `0` hard failures | qpdf structural evidence is green under the active policy; warning-bearing Form 6 artifacts still require independent viewer evidence and are not structurally clean |
| Native/web parity | `4` normalized mismatches remain across 11 fixtures, all in provider candidate-set/count differences on the normal and rotated Form 6 fixtures | The shared document/edit/security/metadata semantics now agree; candidate detector parity remains open and review suggestions must remain untrusted until confirmed |
| External AcroForms | Read-only/no-op preservation boundary remains active | Editing external AcroForms requires a form-aware provider with independent output validation |
| Encrypted edits | Browser rejects edits; native edited-encrypted fidelity remains conditional | Encrypted documents may be inspected and no-op exported, not advertised as generally editable |
| Accessibility | Keyboard/accessibility shell passes; tagged content, reading order, and PDF/UA conformance remain validator-backed conditional claims | No PDF/UA or universal reading-order claim |

### Candidate detector boundary

The remaining 4 parity mismatches are not silently discarded. The web geometry
detector still emits more reviewable suggestions than the native detector on
public-form, widget, and Form 6 fixtures. A scoped false-positive reduction now
abstains on unlabeled horizontal rules, while label-associated geometry and
grouped cells remain available for review. This is still a provider capability
difference in suggestion generation, not permission to auto-apply edits: both
lanes keep candidates review-gated, and the native/web parity gate remains open
until the detectors share equivalent evidence rules or the native lane adopts
an independently validated geometry adapter.

## Release decision

**Scoped NO-GO for unrestricted release.**

The native and web reader lanes, representative navigation metadata, no-op preservation path, security boundaries, browser accessibility shell, and generated-output qpdf gate have current passing evidence. The product must remain restricted to the documented provider capability boundaries until the remaining semantic parity mismatches and open accessibility, OCR, signed-document, XFA, and form-editing gates are either repaired with stronger evidence or explicitly excluded by a reviewed release policy.

## Reproduction artifacts

- Current parity report: `benchmark/results/contract-parity-2026-08-24/parity-report.json`
- Current independent preservation report: `benchmark/results/contract-parity-2026-08-24/independent-preservation-report.json`
- Fixture provenance: `docs/fixtures/manifest.md`
- Navigation metadata audit: `docs/audits/navigation-metadata-evidence-2026-08-24.md`
- Output validation policy: `docs/policies/pdf-output-validation.md`
