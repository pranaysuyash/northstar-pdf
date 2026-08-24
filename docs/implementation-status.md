# Implementation Status

**Reviewed:** 2026-08-24
**Status:** Native macOS and local web vertical slices are implemented for reading,
reviewed completion, and reversible overlay editing. Final provider, validator,
accessibility, packaging, and release gates remain open.

## Implemented

- Swift Package targeting macOS 15 with no third-party runtime dependencies.
- Provider-neutral document, page, native-field, candidate, edit-operation, export,
  and validation contracts.
- Immutable source digest and bounded input/page safety limits.
- Pure Swift `PDFVectorStreamParser` extracting visual rectangles, bounding boxes,
  checkboxes, and underlines directly from PDF graphic state operators (`re`, `m`, `l`, `cm`, `q`, `Q`).
- Enhanced `StaticRegionDetector` incorporating vector path geometry and spatial proximity
  matching to associate text labels with candidate boxes and infer field types (`.date`, `.checkbox`, `.signature`, `.text`, `.number`).
- Local Apple Vision OCR adapter with full page-rendering recognition and lower-left-to-page-space
  coordinate transformation.
- In-memory source caching in `AppModel` for $O(1)$ instantaneous non-destructive undo without disk re-reading.
- Native SwiftUI/AppKit window with Guided Next Blank navigation (`◀ Prev blank` / `Next blank ▶`),
  candidate badges, OCR trigger, file importer, PDFView rendering, field review/editing,
  undo, export, and validation reporting.
- Actionable candidate workflow in both lanes: visible page highlights, selected-candidate
  evidence review, text entry, explicit confirmation, dismissal/restoration, manual
  page placement, overlay editing, and operation-specific undo.
- Group-first static geometry interpretation: repeated small cells are represented as one
  character-entry region with label, evidence, and member-count metadata; choice-like patterns
  remain review-only until their interaction and export paths exist.
- Direct-on-page text placement in both lanes: native double-click and web double-click use the
  same reversible page-space overlay workflow as explicit manual placement.
- Air-gapped Web Companion with strict Content Security Policy (`default-src 'self' 'unsafe-inline' blob: data:;`)
  and local vendor bundling.
- Native `PDFImpactValidator` and browser `pdf-impact-validator.mjs` now compare
  extracted text and rendered pixels outside operation-owned page-space regions.
  Missing coordinates produce explicit `unknown` impact checks instead of a
  clean preservation result.
- Browser `pdf-geometry-detector.mjs` now consumes PDF.js operator-list geometry
  alongside text evidence and emits vector rectangle, checkbox-shape, repeated
  cell, underline, whitespace, and label-association candidates. It remains a
  suggestion provider and never creates native fields silently.
- `TemplateContracts.swift` and `pdf-template-contract.mjs` now implement the
  T1 reusable-template contract slice: keyed layout fingerprints, approved
  native/static mapping records, separate versioned profile records, exact or
  variant match proposals, and fail-closed lifecycle/revision checks. Template
  matching never creates an edit operation or stores profile values in a
  template.
- `TemplateCaptureContracts.swift` and the browser capture helpers now create
  value-free local drafts and immutable active child revisions. Revision
  histories reject duplicate IDs, mismatched template IDs, and missing parent
  links. Activation requires an explicit confirmed or rejected decision for
  every captured mapping.
- `TemplateRuntimeContracts.swift` and the browser completion functions now
  implement the review-to-operation boundary: mapping review, value review,
  native target resolution, source-digest-bound materialization, pending
  learning events, and strict revision promotion gates.
- `TemplateStoreCodec.swift` and `pdf-template-store.mjs` now provide encrypted
  native record sealing and opt-in browser IndexedDB AES-GCM persistence, plus
  an explicit ephemeral store. The browser store has explicit store unlock and
  lock, separate profile unlock, record and whole-store deletion, eviction
  health detection, ciphertext-only backup restore, and an allowlisted
  zero-content logger. Native Keychain custody and production persistence UX
  remain adapter/product work.
- The browser reader now includes a capture-review surface for draft template
  mappings, immutable child-revision activation, session-only values, proposal
  preparation, and a fail-closed apply control. It is not yet backed by the
  encrypted store and the native app does not yet expose an equivalent review
  UI.

## Current user workflow contract

The editor has two intentionally different completion paths:

1. **Native field:** an inspected AcroForm/widget with a provider identity. The
   user edits its value and the operation targets that field.
2. **Suggested area:** evidence-backed geometry with a detector score. The user
   selects the highlighted area, reviews the evidence, enters text, and confirms
   a reversible text overlay. The suggestion is never silently converted into a
   native field.
3. **No useful suggestion:** the user chooses `Add text manually`, clicks the
   page, enters text, and receives the same reversible overlay and undo path.

Candidate state is explicit: `suggested` means actionable but unconfirmed,
`confirmed` means an overlay has been applied, and `rejected` means dismissed
from the active queue but restorable from session history. A confirmed candidate
is not proof that the detector was correct; it records the user's decision.

## Evidence

| Check | Result | Evidence |
|---|---|---|
| Core unit, round-trip, vector, OCR, resilience & security tests | Pass, Tier 2/S1 (44 tests) | `swift test` |
| Malicious link scheme neutralization | Pass, Tier 2/S1 | `PDFEditorCoreTests.securityDangerousLinkSchemesAreBlocked` |
| Overwrite collision defense | Pass, Tier 2/S1 | `PDFEditorCoreTests.resilienceExportRejectsOverwritingSourceFile` |
| Inverted/zero geometry boundary clamping | Pass, Tier 2/S1 | `PDFEditorCoreTests.resilienceStandardizesInvertedOrZeroGeometryBounds` |
| Truncated stream recovery | Pass, Tier 2/S1 | `PDFEditorCoreTests.resilienceRejectsTruncatedStreamWithoutCrash` |
| Vector stream extraction | Pass, Tier 2/S1 | `PDFEditorCoreTests.vectorStreamParserExtractsBoxesAndUnderlinesFromSyntheticPDF` |
| OCR coordinate transformation | Pass, Tier 2/S1 | `PDFEditorCoreTests.ocrCoordinateConversionMapsCorrectlyToPageSpace` |
| Real Form 6 inspection/export | Pass, Tier 2/S1 | `PDF_EDITOR_FORM6_INPUT=... swift test --filter PDFEditorCoreTests` |
| Public AcroForm regression | Expected export rejection preserved, Tier 2/S1 | `PDF_EDITOR_PUBLIC_ACROFORM_INPUT=... swift test --filter PDFEditorCoreTests` |
| Release compilation | Pass, Tier 2/S1 | `swift build -c release` |
| WCAG 2.1/2.2 Level AA & VoiceOver conformance | Pass, Tier 2/S1 | `node Tests/web_accessibility_gate_test.mjs` & native VoiceOver element tree |
| Feature A web contract test | Pass (42 checks) | `node Tests/web_reader_contract_test.mjs` |
| Feature A native reader behavior | Covered by source and provider tests | Search selection, page geometry, security, and inspection invariants |
| Browser interaction run | Pass, Tier 2/S1 | Isolated Playwright Chromium opened the public sample and Form 6 fixtures, rendered canvas/text, searched, changed view/fit/rotation, jumped page, focused skip link, and asserted zero page/console errors |
| Browser accessibility runtime gate | Pass, Tier 2/S1 | `node Tests/web_accessibility_gate_test.mjs` asserted landmarks, skip-link focus, keyboard text spans, password dialog labeling, and zero page/console errors |
| Browser editor workflow | Pass, Tier 3/S1 | `node Tests/web_editor_workflow_test.mjs` selected a highlighted candidate, applied text, edited the overlay, undid it, dismissed/restored a candidate, and placed manual text |
| Native character-grid materialization | Pass, Tier 2/S1 | `PDFEditorCoreTests.characterGridOverlayWritesOneGlyphPerCell` writes and reopens one glyph annotation per cell |
| Browser character-grid workflow | Pass, Tier 3/S1 | `node Tests/web_character_grid_workflow_test.mjs` grouped the static Form 6 cells, retained member bounds, and rendered one preview per entered character |
| Browser PDF.js + pdf-lib completion proof | Pass with explicit warning, Tier 2/S1 | `node Tests/web_pdf_proof_playwright_test.mjs` opened the public AcroForm and Form 6 static corpus, detected 6 native fields and 15 static candidates, filled/overlaid, exported, reopened, and validated source digest/page geometry |
| Browser outside-region text and raster impact proof | Pass, Tier 3/S1 | `web_pdf_impact_validator_test.mjs` proves no-op pass, unauthorized text/raster mutation failure, authorized-region pass, and missing/mismatched-coordinate unknown; the checks remain PDF.js-provider-local and are not independent-viewer or byte-identity proof |
| Native outside-region text and raster impact proof | Pass, Tier 2/S1 | `PDFImpactValidator` is exercised by native overlay export and a fail-closed missing-coordinate test |
| Native reusable template/profile contracts | Pass, Tier 2/S1 | `swift test` passed keyed fingerprint, no-raw-content, approved mapping, profile revision, exact/variant/no-match, and revoked revision tests |
| Browser reusable template/profile adapter | Pass, Tier 3/S1 | `web_template_contract_test.mjs` and `web_template_browser_test.mjs` passed fingerprint creation, JSON validation, exact proposal, profile separation, and negative checks |
| Native/web reviewed template capture and revision round-trip | Pass, Tier 2/S1 native plus Tier 3/S1 web | `swift test` (35 tests), `web_template_contract_test.mjs`, and `web_template_browser_test.mjs` passed source-bound draft capture, keyed fingerprint privacy, complete review gating, immutable child activation, parent linkage, and append-only history |
| Browser encrypted vault lifecycle | Pass, Tier 3/S1 plus deliberate eviction and wrong-secret failures | `node Tests/web_template_security_browser_test.mjs` passed explicit store unlock/lock, separate profile unlock, wrong store/profile secret rejection, record deletion, whole-store deletion, simulated IndexedDB eviction, ciphertext-only backup restore, health states, and zero-content logging |
| Reviewed template matching benchmark | Pass, Tier 2/S1 plus S3 threshold and ambiguity mutation; browser corpus smoke pass Tier 3/S1 | `web_template_match_benchmark_test.mjs` covers exact, knownVariant, familyMatch, ambiguous, stale, and noMatch with two false-positive gates; the browser companion uses PDF.js fingerprints from the public sample and Form 6 corpus and rejects a weakened policy |
| Browser geometry evidence adapter | Pass, Tier 3/S1 | The shared-contract fixture now proves vector-rectangle, explicit checkbox-shaped, whitespace, and paired label-association evidence across the existing corpus; false-positive reduction, recall measurement, and native/browser semantic parity remain open |
| Browser shared-contract fixture emission | Pass with preserved provider failures, Tier 3/S1 | `node Tests/web_pdf_contract_fixture_test.mjs` emitted document, page-coordinate, candidate, edit-session, and validation bundles for the current ten-entry manifest, including explicit encrypted/password, malformed-input, OCR, and rotation states |
| Native/web serialized contract parity harness | Pass baseline, Tier 2/S1 native plus Tier 3/S1 browser; current mismatch record preserved | `node Tests/pdf_contract_parity_test.mjs` emitted native and browser bundles for all 11 manifest entries, matched source digests and malformed-input failure behavior, and recorded 63 normalized semantic mismatches in `benchmark/results/contract-parity-2026-08-24/parity-report.json`; representative links, outlines, attachments, labels, boxes, and permissions now have zero semantic mismatches |
| Security and OCR fixture generation gates | Pass, Tier 2/S1 | Security scripts cover AES-256 password, truncated malformed input, and repeated 20-page resource input; `bash benchmark/generate_ocr_fixture.sh && bash benchmark/test_ocr_fixture.sh` covers a raster-only page with ground-truth anchors |
| Contract negative and mutation tests | Pass, Tier 2/S1 plus S3 source-binding mutation | `swift test --filter ContractMutationTests` passed 6 tests; a deliberate source-binding bypass failed the stale-digest test before restoration |
| Independent qpdf source gate | Pass, Tier 2/S1 | `bash benchmark/test_qpdf_structure.sh` |
| Independent qpdf generated-output gate | Fail, preserved, Tier 2/S1 | `bash benchmark/test_qpdf_outputs.sh` classified 6 recoverable Form 6 offset-warning artifacts separately and still failed 8 generated artifacts for unreachable AcroForm widgets; no unrestricted output claim is made |
| Independent viewer gate | Pass, Tier 2/S1 | `bash benchmark/test_independent_viewer.sh` independently reopened 38 eligible corpus PDFs through Poppler `pdfinfo`/`pdftotext` and MuPDF `mutool info`, including the navigation fixture and encrypted native/browser parity outputs; this does not clear structural or fidelity failures |
| Independent outside-region preservation gate | Pass, Tier 3/S3 | `node Tests/pdf_independent_preservation_test.mjs` used Poppler text/raster plus qpdf evidence, rejected an unauthorized reviewed export, accepted the same export with its source-bound region, and reopened 90-degree and mixed 90/180-degree fixtures |
| Native/web retained-output preservation report | Pass with preserved warnings, Tier 3/S1 | `node Tests/pdf_contract_parity_test.mjs` retained native and browser no-op exports and wrote `benchmark/results/contract-parity-2026-08-24/independent-preservation-report.json`; 9 valid sources reopened independently in both lanes, including byte-preserved encrypted browser output |

## Known Limits

- Static suggestions remain conservative and uncertain. Vector geometry is now
  grouped before semantic classification in the core detector, but the reviewed
  corpus is still too small to claim production-grade candidate recall or precision
  across forms. The next benchmark must measure grouped name grids, labeled
  choices, dates, signatures, photo boxes, and decorative geometry separately.
- Vision OCR is implemented as an adapter and now has one deterministic printed
  raster benchmark; multi-language, layout, confidence, skew/noise, handwritten,
  and packaged model/language policy evidence remain open.
- The product provider now copies unchanged sources byte-for-byte instead of
  reserializing them, preserving imported AcroForms for no-op export. PDFKit
  now rejects edits against a document-level AcroForm before mutation because
  it cannot safely preserve the external widget tree. A form-aware writer is
  still required for editable external forms.
- A qpdf rewrite can normalize some offset warnings in generated Form 6 output,
  but it does not restore unreachable AcroForm widgets; qpdf remains a validator
  and structural tool, not the semantic form writer.
- The malformed/encrypted/page-limit security tranche is now covered by a
  deterministic corpus and native tests; broader malformed object classes,
  unsupported encryption, signed/XFA, large-image, and independent-viewer
  sweeps remain open.
- Browser interaction evidence now includes the completion proof; VoiceOver and
  screen-reader evidence must still be captured on the local web companion and
  native app respectively. Source-level accessibility claims do not substitute
  for assistive-technology observation.
- The browser workflow test proves the local interaction state machine, not
  independent PDF fidelity. The PDF.js outside-region checks are bounded
  provider-local evidence; the Poppler gate adds independent reopen/text/raster
  evidence, but independent GUI-viewer parity, byte-for-byte object proof, and
  general semantic editing remain open.
- The browser fixture emits contract records and the native/web parity harness
  now compares both serialized sides. The current baseline retains 75 normalized
  semantic mismatches as evidence. Two manifest AcroForm outputs remain explicit
  browser provider failures because pdf-lib cannot resolve fields that PDF.js can
  inspect.
- Browser operator-list detection currently over-generates some decorative
  border and long-rule candidates on static fixtures. It emits the four
  requested evidence families and keeps them review-only, but it is not
  production-grade precision/recall until geometry filtering and reviewed
  ground truth are added.
- Browser OCR, text-run replacement, permanent redaction, sanitization,
  cryptographic signatures, XFA, PDF/UA, and general page-operation lanes remain
  explicitly unclaimed and are mapped in
  [`docs/full-capability-build-program.md`](full-capability-build-program.md).
- Browser no-op export now downloads every inspected source byte-for-byte and
  validates source identity without invoking a PDF writer; encrypted edits
  remain explicitly unsupported by the browser writer.
- The first web deployment boundary is now accepted: browser-only for the
  bounded reader/completion/export core; OCR and high-fidelity editing are
  companion-required capabilities behind an explicitly installed optional local
  companion. The companion is not packaged or required by the current web proof.
- Automatic profile resolution, native mapping/value review UI, variant diff UI,
  browser template-store UI integration, native Keychain integration, lost-
  passphrase recovery, backup download/import UX, quota education,
  learning-event journal UI, and template revision migration remain open. The
  runtime and local vault slices are guarded but are not a silent autofill or
  production account-recovery implementation.
- `qpdf 12.4.0` and Poppler 26.08.0 are installed and used for independent
  source/output gates; the current preservation adapter does not depend on
  MuPDF, while `pdftk` and `pdfcpu` remain unavailable in the current environment.
- No app-bundle signing, notarization, deployment, cloud service, or legally
  binding signature/redaction claim has been performed.

## Next Gates

1. Classify the retained native/browser semantic mismatches without normalizing
   away product-relevant differences.
2. Reduce browser geometry false positives while preserving labeled rectangles,
   checkbox shapes, repeated cells, underlines, whitespace, and label evidence.
3. Add a read-only privacy preflight contract and OCR alignment fixtures.
4. Run the same contract against PDFBox and one permitted native control lane.
5. Add rotated reviewed-operation replay, malformed/encrypted, signed, XFA, and
   resource exhaustion checks; keep the independent Poppler gate distinct from
   future GUI-viewer observation.
6. Profile the native app on representative hardware and complete exact dependency,
   packaging, accessibility, and security review.
7. If a declared workflow triggers the companion admission gate, implement the
   typed capability handshake and run separate OCR and high-fidelity provider
   bake-offs with license, bridge, recovery, and independent-viewer evidence.
