# Implementation Status

**Reviewed:** 2026-08-25
**Status:** Native macOS and local web vertical slices are implemented for reading,
reviewed completion, native checkbox/radio editing, static choice marks, native
field synthesis, reversible overlays, and reopen validation. Claim readiness
for provider breadth, independent fidelity, accessibility, packaging, and
release remains evidence-gated. The implementation program itself is not
bounded: every capability in the full-capability build program remains an
active native, browser, companion, hosted, validator, or recovery lane until
implemented, measured, replaced, or explicitly revoked.

**Status interpretation:** “Built” describes current implementation evidence;
“Partial,” “Gated,” “Blocked,” “Unknown,” “Quarantined,” “Abstained,” and
“Deferred” describe current execution or claim readiness. None of these states
removes a capability from the long-term build target. In particular,
permanent redaction, cryptographic signature validation, XFA, PDF/UA,
arbitrary text editing, multilingual/web OCR, conversion, repair, companion
lifecycle, collaboration, and sync remain build obligations even when their
current product claim is blocked.

## Implemented

- Swift Package targeting macOS 15 with no third-party runtime dependencies.
- Provider-neutral document, page, native-field, candidate, edit-operation, export,
  and validation contracts.
- Separate capability-negotiated provider admission contract with native and
  browser registry projections, exact artifact-to-measurement binding,
  deterministic source-limit routing, license-state rejection, abstention, and
  revocation/quarantine representation. This does not modify the shared PDF
  contract payloads.
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
  character-entry region with label, evidence, and member-count metadata. Checkbox and
  radio-like patterns expose detected member cells for reviewed static marking. Text-like
  regions can be explicitly synthesized into native text widgets; no static region is
  silently converted.
- Native choice workflow in both lanes: existing checkbox widgets expose a boolean control,
  existing radio groups expose their semantic options, and export validation reopens the
  selected state. Browser radio validation records the mapping between user-facing option
  labels and provider export indexes.
- Reviewed static choice workflow in both lanes: a user selects a detected member cell,
  places a reversible mark, and exports with outside-region text and raster validation.
- Reviewed native-field synthesis in both lanes: a text-like static region can be promoted
  to an invisible, editable native text widget at the reviewed page-space bounds. The
  synthesized widget must reopen after export and its provider-rendering envelope is
  included in visual impact proof.
- Direct-on-page text placement in both lanes: native double-click and web double-click use the
  same reversible page-space overlay workflow as explicit manual placement.
- Air-gapped Web Companion with strict Content Security Policy (`default-src 'self' 'unsafe-inline' blob: data:;`)
  and local vendor bundling.
- Native `PDFImpactValidator` and browser `pdf-impact-validator.mjs` now compare
  extracted text and rendered pixels outside operation-owned page-space regions.
  Missing coordinates produce explicit `unknown` impact checks instead of a
  clean preservation result.
- `benchmark/browser-export-independent-viewer-validator.mjs` now joins the
  PDF.js `outsideRegionText` and `visualDiff` checks with a separately rendered
  Poppler text/raster/reopen result. The current 18-entry report has 16
  readable passes, 2 malformed expected failures, 16/16 readable text and
  raster agreements, and zero unexpected divergences. This does not claim
  arbitrary edited-PDF fidelity or GUI-viewer parity.
- The browser review/export panel now exposes value-minimized preservation
  metrics for those two PDF.js checks: compared and changed pages, changed and
  compared pixels, outside-pixel ratio, maximum channel delta, render scale,
  channel tolerance, operation count, and evidence basis. It renders metrics
  for failed exports as well as successful exports and never displays the raw
  outside-region text strings.
- Browser `pdf-geometry-detector.mjs` now consumes PDF.js operator-list geometry
  alongside text evidence and emits vector rectangle, checkbox-shape, repeated
  cell, underline, whitespace, and label-association candidates. It remains a
  suggestion provider and never creates native fields silently. Unlabeled
  horizontal rules now abstain rather than becoming editable suggestions;
  label-associated underlines remain review-gated.
- `web/detector-calibration.mjs` now emits overall and per-class precision,
  recall, hard-negative false-positive rate, abstention, and explainable
  failure clusters. The controlled browser calibration is 5/5 precision and
  5/5 recall across five positives and five hard negatives, with zero observed
  failures. The parity runner kills positive-removal, hard-negative-promotion,
  and required-evidence-stripping mutations. This is exact-label regression
  evidence, not a universal geometry claim.
- Native and browser candidates now carry an optional deterministic `fusion`
  result derived from typed evidence items. The fusion layer combines support,
  independent evidence-family coverage, and geometric agreement, and abstains
  on conflicting high-confidence regions. It is executable and parity-tested,
  but class-level calibration and provider-wide OCR/companion admission remain
  open evidence gates.
- The shared operation model now includes a distinct `textRunReplacement`
  operation with source-run identity, original-text hash, optional font
  fingerprint, page-space bounds, and recovery-safe payload classification.
  Native PDFKit and browser pdf-lib reject the operation explicitly until a
  provider proves semantic text-object rewriting, font/glyph preservation,
  outside-region fidelity, and independent reopen evidence. It is never routed
  through the visual overlay writer.
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
   user edits its value and the operation targets that field. Checkbox and radio
   widgets use controls derived from the inspected field metadata.
2. **Static choice region:** evidence-backed checkbox/radio geometry. The user
   selects a detected member cell and explicitly places a reversible static mark.
3. **Static text-like region:** evidence-backed geometry with a detector score. The
   user may enter a reversible overlay or explicitly create a native text field at
   the reviewed bounds. Synthesis is a confirmed operation, never an automatic guess.
4. **No useful suggestion:** the user chooses `Add text manually`, clicks the
   page, enters text, and receives the same reversible overlay and undo path.

Candidate state is explicit: `suggested` means actionable but unconfirmed,
`confirmed` means an overlay has been applied, and `rejected` means dismissed
from the active queue but restorable from session history. A confirmed candidate
is not proof that the detector was correct; it records the user's decision.

## Evidence

| Check | Result | Evidence |
|---|---|---|
| Core unit, round-trip, vector, OCR, resilience & security tests | Pass, Tier 2/S1 (67 tests) | `swift test` |
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
| Feature A web contract test | Pass (44 checks) | `node Tests/web_reader_contract_test.mjs` |
| Feature A native reader behavior | Covered by source and provider tests | Search selection, page geometry, security, and inspection invariants |
| Browser interaction run | Pass, Tier 2/S1 | Isolated Playwright Chromium opened the public sample and Form 6 fixtures, rendered canvas/text, searched, changed view/fit/rotation, jumped page, focused skip link, and asserted zero page/console errors |
| Browser accessibility runtime gate | Pass, Tier 2/S1 | `node Tests/web_accessibility_gate_test.mjs` asserted landmarks, skip-link focus, keyboard text spans, password dialog labeling, and zero page/console errors |
| Browser editor workflow | Pass, Tier 3/S1 | `node Tests/web_editor_workflow_test.mjs` selected a highlighted candidate, applied text, edited the overlay, undid it, dismissed/restored a candidate, and placed manual text |
| Native character-grid materialization | Pass, Tier 2/S1 | `PDFEditorCoreTests.characterGridOverlayWritesOneGlyphPerCell` writes and reopens one glyph annotation per cell |
| Browser character-grid workflow | Pass, Tier 3/S1 | `node Tests/web_character_grid_workflow_test.mjs` grouped the static Form 6 cells, retained member bounds, and rendered one preview per entered character |
| Native checkbox/radio workflow | Pass, Tier 2/S1 | `PDFEditorCoreTests.nativeCheckboxAndRadioGroupRoundTripTheirState` exercises checkbox truthiness, radio selection, export, and reopen validation |
| Native static choice and synthesis workflow | Pass, Tier 2/S1 | `PDFEditorCoreTests.staticChoiceMarkAndNativeSynthesisRoundTrip` places a reviewed mark, synthesizes a text widget, and validates both after reopen |
| Browser native checkbox/radio workflow | Pass, Tier 3/S1 | `node Tests/web_native_choice_workflow_test.mjs` exposes checkbox and radio controls, exports, reopens, and validates provider option mapping |
| Browser static choice and native synthesis workflow | Pass, Tier 3/S1 | `node Tests/web_static_choice_and_synthesis_workflow_test.mjs` marks a reviewed static cell, synthesizes a native field, exports, and validates visual impact |
| Browser PDF.js + pdf-lib completion proof | Pass with explicit warning, Tier 2/S1 | `node Tests/web_pdf_proof_playwright_test.mjs` opened the public AcroForm and Form 6 static corpus, detected 6 native fields and 83 review candidates on Form 6 after geometry abstention, filled/overlaid, exported, reopened, and validated source digest/page geometry |
| Browser outside-region text and raster impact proof | Pass, Tier 3/S1 | `web_pdf_impact_validator_test.mjs` proves no-op pass, unauthorized text/raster mutation failure, authorized-region pass, and missing/mismatched-coordinate unknown; the checks remain PDF.js-provider-local and are not independent-viewer or byte-identity proof |
| Browser coordinate fidelity matrix | Pass, Tier 3/S1 | `node Tests/web_coordinate_fidelity_browser_test.mjs` covers 12 view states across rotations 0/90/180/270, zoom, and two-page page-bound containment |
| Native outside-region text and raster impact proof | Pass, Tier 2/S1 | `PDFImpactValidator` is exercised by native overlay export and a fail-closed missing-coordinate test |
| Native reusable template/profile contracts | Pass, Tier 2/S1 | `swift test` passed keyed fingerprint, no-raw-content, approved mapping, profile revision, exact/variant/no-match, and revoked revision tests |
| Browser reusable template/profile adapter | Pass, Tier 3/S1 | `web_template_contract_test.mjs` and `web_template_browser_test.mjs` passed fingerprint creation, JSON validation, exact proposal, profile separation, and negative checks |
| Native/web reviewed template capture and revision round-trip | Pass, Tier 2/S1 native plus Tier 3/S1 web | `swift test` (35 tests), `web_template_contract_test.mjs`, and `web_template_browser_test.mjs` passed source-bound draft capture, keyed fingerprint privacy, complete review gating, immutable child activation, parent linkage, and append-only history |
| Browser encrypted vault lifecycle | Pass, Tier 3/S1 plus deliberate eviction and wrong-secret failures | `node Tests/web_template_security_browser_test.mjs` passed explicit store unlock/lock, separate profile unlock, wrong store/profile secret rejection, record deletion, whole-store deletion, simulated IndexedDB eviction, ciphertext-only backup restore, health states, and zero-content logging |
| Reviewed template matching benchmark | Pass, Tier 2/S1 plus S3 threshold and ambiguity mutation; browser corpus smoke pass Tier 3/S1 | `web_template_match_benchmark_test.mjs` covers exact, knownVariant, familyMatch, ambiguous, stale, and noMatch with two false-positive gates; the browser companion uses PDF.js fingerprints from the public sample and Form 6 corpus and rejects a weakened policy |
| Native Swift/browser reviewed-template semantic parity | Pass, Tier 2/S1 native plus Tier 3/S1 isolated Chrome | `node Tests/template_match_native_browser_parity_test.mjs` runs all 24 reviewed cases through `PDFTemplateParityHarness` and the browser adapter; state distributions, 14 abstentions, candidate evidence, scores, and class policies agree with 0 semantic mismatches |
| Reviewed correction-event benefit measurement | Pass, Tier 2/S1 Node plus Tier 3/S1 isolated Chrome with mutation-sensitive safety gates | `node Tests/web_template_correction_benchmark_test.mjs` measures 5 reviewed variants, lifts reviewed-target coverage from 0 to 5, preserves 35/35 hard-negative abstentions, restores baseline after rollback, and passes value-free privacy checks; this is not real-user speed or production recall evidence |
| ihatepdf-inspired experiment ledger and semantic parity | Pass, Tier 2/S1 native and Node plus Tier 3/S1 isolated Chrome; S3 ledger mutations | `Tests/fixtures/ihatepdf_experiment_ledger.json` defines six versioned entries and six linked cases; `node Tests/ihatepdf_experiment_parity_test.mjs` reports 0 native/browser semantic mismatches and kills 4/4 ledger mutations; capability execution remains planned per case |
| Cross-project evidence ledger and PDF corpus semantic parity | Pass with six classified mismatches, Tier 1/S1 source inventory plus Tier 2/S1 native and Tier 3/S1 isolated Chrome | `Tests/fixtures/cross_project_evidence_ledger.json`, `Tests/fixtures/pdf_corpus_semantic_parity_fixture.json`, and `node Tests/cross_project_evidence_ledger_parity_test.mjs` validate 6 ledger entries, 18 source references, 17 corpus cases, 0 unexpected mismatches, expected malformed-input failures, and 1 preserved source-identity drift |
| Browser geometry evidence adapter | Pass with candidate parity partial, Tier 3/S1 | The shared-contract fixture proves vector-rectangle, explicit checkbox-shaped, whitespace, and paired label-association evidence; the fresh candidate parity report now measures native/browser geometry pairing and semantic divergence across the current corpus, while reviewed target precision/recall, split/merge adjudication, and broader candidate-bearing corpus classes remain open |
| Reviewed static-region benchmark baseline | Measured baseline, not a production claim | `node Tests/static_region_reviewed_benchmark_browser_test.mjs` matched 7 of 33 semantic targets: label-associated recall proxy 21.21%, labeled-candidate precision proxy 11.96%, 3 abstentions, 97 candidates; geometric IoU is not yet measured |
| Vision OCR and CV fallback evidence | Pass, Tier 2/S1 plus measured partial corpus comparison | `PDFReaderGateTests.visionOCRFallbackRecognizesTheReviewedRasterFixture` and `PDFReaderGateTests.visionCVFallbackReturnsReviewedRasterGeometryEvidence` cover the adapters; `node benchmark/compare_ocr_providers.mjs` measures Vision across clean, noisy, simulated-handwriting-like, rotated, encrypted, and large representative inputs, with broader language, handwritten, searchable-layer, memory, and recovery gates still open |
| Browser shared-contract fixture emission | Pass with preserved provider warnings and failures, Tier 3/S1 | `node Tests/web_pdf_contract_fixture_test.mjs` emitted document, page-coordinate, candidate, edit-session, and validation bundles for all 18 manifest entries, including encrypted hybrid password and edit rejection, two malformed-input failures, noisy OCR input, synthetic handwriting-like raster input, rotations, hybrid pages, and 40-page stress input; isolated Chrome recorded 0 console and page errors |
| Native/web serialized contract parity harness | Pass baseline with six classified mismatches, Tier 2/S1 native plus Tier 3/S1 isolated Chrome | `node Tests/pdf_contract_parity_test.mjs` emitted native and browser bundles for all 18 manifest entries and recorded 6 normalized mismatches in `benchmark/results/contract-parity-2026-08-24/parity-report.json`: 4 existing Form 6 candidate differences and 2 encrypted-hybrid geometry/coordinate differences; zero unexpected mismatches remain |
| Native/browser semantic candidate parity | Partial evidence, Tier 2/S1 native plus Tier 3/S1 isolated Chrome | `node Tests/native_browser_candidate_parity_report_test.mjs` compares the fresh 18-fixture bundles with a value-minimized geometry pairing projection: 206 native candidates, 140 browser candidates, 118 pairs, 49 equivalent pairs, 88 native-only candidates, 22 browser-only candidates, and 6 mismatch clusters; `node Tests/candidate_parity_mutation_test.mjs` passes 5/5 representation and semantic mutation checks |
| Native/browser structural fingerprint parity | Partial, Tier 2/S1 over retained native/browser bundles with S3 mutations | `node benchmark/generate_fingerprint_parity.mjs` and `node Tests/native_browser_fingerprint_parity_test.mjs` emit and verify an 18-case value-minimized fixture: 2 equal malformed failure states, 8 semantic-divergence-only cases, 8 mixed cases, permission divergence on 16, character-count differences on 8, encrypted page-box divergence on 1, and candidate-family divergence on 2; permission observed-versus-unknown normalization, rotation precision, and candidate remediation remain open |
| Security and OCR fixture generation gates | Pass, Tier 2/S1 | Security scripts cover AES-256 password, truncated malformed input, and repeated 20-page resource input; `bash benchmark/generate_ocr_fixture.sh && bash benchmark/test_ocr_fixture.sh` covers a raster-only page with ground-truth anchors, while the shared-provider comparison adds noisy, rotated, encrypted, simulated-handwriting-like, and large representative OCR inputs |
| Contract negative and mutation tests | Pass, Tier 2/S1 plus S3 source-binding mutation | `swift test --filter ContractMutationTests` passed 6 tests; a deliberate source-binding bypass failed the stale-digest test before restoration |
| Independent qpdf source gate | Pass, Tier 2/S1 | `bash benchmark/test_qpdf_structure.sh` |
| Independent qpdf generated-output gate | Pass with preserved warnings, Tier 2/S1 | `bash benchmark/test_qpdf_outputs.sh` checked 55 generated PDFs, accepted only the documented Form 6 offset-warning signature for 6 artifacts, and found 0 hard failures |
| Independent viewer gate | Pass, Tier 2/S1 | `bash benchmark/test_independent_viewer.sh` independently reopened 53 eligible corpus PDFs through Poppler `pdfinfo`/`pdftotext` and MuPDF `mutool info`, including all five valid new browser-corpus sources and their native/browser no-op outputs; malformed inputs remain expected safe failures |
| Independent outside-region preservation gate | Pass, Tier 3/S3 | `node Tests/pdf_independent_preservation_test.mjs` used Poppler text/raster plus qpdf evidence, rejected an unauthorized reviewed export, accepted the same export with its source-bound region, and reopened 90-degree and mixed 90/180-degree fixtures |
| Native/web retained-output preservation report | Pass with preserved warnings, Tier 3/S1 | `node Tests/pdf_contract_parity_test.mjs` retained native and browser no-op exports and wrote `benchmark/results/contract-parity-2026-08-24/independent-preservation-report.json`; 15 valid source fixtures reopened independently in both lanes, including the five valid new browser-corpus entries and byte-preserved encrypted outputs |
| Capability-negotiated local provider registry | Pass contract slice plus typed reference-host slice, Tier 2/S1 native and browser | `node Tests/provider_capability_contract_test.mjs` passed 12 browser checks; `swift test --filter ProviderCapabilityContractTests` passed 7 native tests; `node Tests/provider_companion_host_test.mjs` passed handshake, source binding, output-limit, cancellation, abstention, and zero-content checks; installer, cryptographic transport authentication, sandboxing, live provider bake-off, and runtime revocation remain open |

## Known Limits

- Static suggestions remain conservative and uncertain. The current reviewed
  baseline is 21.21% label-associated recall proxy and 11.96% labeled-candidate
  precision proxy on 33 semantic targets. These are not geometric IoU metrics and
  are not production accuracy claims. The next benchmark must measure grouped name
  grids, labeled choices, dates, signatures, photo boxes, and decorative geometry
  separately, with reviewer adjudication and geometric overlap.
- Vision OCR is implemented as an adapter and now has a six-input governed
  comparison with confidence and latency counters. It passes the controlled
  class gate, but multi-language, real handwriting, searchable-layer writing,
  output fidelity, memory, cancellation, and packaged model/language policy
  evidence remain open. Tesseract is measured as a control lane and fails the
  noisy-scan gate; OCRmyPDF, PDFBox, and MuPDF companion runtimes remain
  unmeasured or quarantined.
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
  now compares both serialized sides. The current baseline retains 6 classified
  semantic mismatches as evidence. Two manifest AcroForm outputs remain explicit
  browser provider failures because pdf-lib cannot resolve fields that PDF.js can
  inspect.
- Browser operator-list detection still over-generates some geometry candidates
  on static fixtures. Unlabeled horizontal rules now abstain, while the current
  browser choice and synthesis actions remain review-gated; the detector is not production-grade
  precision/recall until geometry filtering, grouped-label adjudication, and
  geometric ground truth are added.
- The bounded simple text-run provider now rewrites a unique same-width ASCII
  literal in a classic uncompressed stream and passes independent qpdf/Poppler
  outside-region text and raster checks. This is a provider-class experiment;
  general semantic text editing remains gated for compressed, escaped,
  Unicode, embedded-font, ligature, RTL, clipping, transparency, overlap,
  signed, XFA, and incremental-update documents.
- Browser OCR, text-run replacement, permanent redaction, sanitization,
  cryptographic signatures, XFA, PDF/UA, and general page-operation lanes remain
  active implementation targets with current evidence and activation states
  mapped in
  [`docs/full-capability-build-program.md`](full-capability-build-program.md).
- Native PDFKit and browser PDF.js now emit a value-minimized privacy preflight
  report for metadata presence, embedded-data indicators, network boundaries,
  possible active content, encryption, source binding, and sanitization limits.
  The report never includes raw values or claims that a PDF is clean. Metadata
  removal, action neutralization, hidden-revision analysis, signature effects,
  XFA/rich-media policy, and independent post-sanitize validation remain active
  sanitizer implementation lanes.
- Browser and native now emit the versioned device-adaptive resource policy for
  render, high-DPI, OCR, batching, cancellation, and source-digest recovery.
  Controlled five-profile/six-class evidence passes, but physical-device
  calibration, actual PDF.js allocation behavior, Web Worker OCR memory,
  companion crash recovery, and long-run batch throughput remain open.
- Browser no-op export now downloads every inspected source byte-for-byte and
  validates source identity without invoking a PDF writer; encrypted edits
  remain explicitly unsupported by the browser writer.
- The long-term deployment architecture is accepted: browser-first local core
  plus explicitly installed local companion. The companion is not packaged or
  required by the current web proof, but OCR, high-fidelity editing, batch,
  large-document, and other provider lanes remain active implementation targets.
  “Companion-required” describes runtime placement for a capability, not a
  permanent product exclusion. Activation and release claims remain gated by
  measurement, privacy, security, licensing, and fidelity evidence.
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

1. Remediate the 6 retained native/browser semantic mismatches without
   normalizing away product-relevant differences.
2. Reconcile native/browser candidate grouping, field-type taxonomy, and
   rotation coordinate normalization using RG-104 and its value-minimized
   candidate report.
3. Reduce browser geometry false positives while preserving labeled rectangles,
   checkbox shapes, repeated cells, underlines, whitespace, and label evidence.
4. Expand the privacy preflight into a source-bound sanitizer operation with
   removed/preserved/unknown inventory, hidden-revision and signature policy,
   independent post-sanitize reopening, and OCR alignment fixtures.
5. Run the same contract against PDFBox and one permitted native control lane.
6. Add rotated reviewed-operation replay, malformed/encrypted, signed, XFA, and
   resource exhaustion checks; keep the independent Poppler gate distinct from
   future GUI-viewer observation.

## Session privacy and provenance

**Status:** Implemented for native recovery envelopes, browser snapshots, and
the 18-fixture corpus; OCR/companion/provider-specific execution states remain
to be populated by their real adapters.

- `pdf-editor.session-provenance` 1.0 records processing locality, data egress,
  OCR use, source retention/deletion state, export identity, validation state,
  reopen result, and bounded operation/provider facts.
- The record is value-minimized and rejects source bytes, document text, OCR
  text, field values, filenames, URLs, and contradictory privacy or export
  states.
- Native `DocumentSession` recovery envelopes carry the record; the browser
  PDF.js fixture emits it from the real loaded source and refreshes it after
  export.
- Sixteen readable native and browser corpus fixtures emitted valid provenance
  records. Two declared malformed fixtures correctly emitted no session record.
- Evidence and remaining provider-specific retention/egress work are recorded
  in [`audits/session-privacy-provenance-evidence-2026-08-25.md`](audits/session-privacy-provenance-evidence-2026-08-25.md).
6. Profile the native app on representative hardware and complete exact dependency,
   packaging, accessibility, and security review.
7. If a declared workflow triggers the companion admission gate, implement the
   typed capability handshake and run separate OCR and high-fidelity provider
   bake-offs with license, bridge, recovery, and independent-viewer evidence.
