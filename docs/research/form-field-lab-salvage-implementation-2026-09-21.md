# Fieldroom salvage implementation record — 2026-09-21

Companion to `form-field-lab-salvage-assessment-2026-09-21.md` (what to port and why).
This record captures **what landed, how it was verified, and what remains**.

## Implemented (A-tier items)

| Item | Change | Files |
|---|---|---|
| A4 token-boundary type inference | `inferFieldType` rewritten: collision-prone short cues ("date", "sign", "tick", "tel", "check") match only as whole tokens / safe word prefixes; phrases stay substring. Fixes live defects: "Candidate name:" → Date, "Designation:" → Signature, "Ticket No:" → Checkbox. | `Sources/PDFEditorCore/StaticRegionDetector.swift` |
| A4 semantic-key token boundary | `inferSemanticKey`: "statement"→State, "capacity"→City, "automobile"→Mobile, "excellent"→Cell, "accountant"→Account, "hotel"→phone key all fixed via whole-token matching. | `Sources/PDFEditorCore/FieldLabelCanonicalizer.swift` |
| A5 per-page native-overlap suppression | New pure `StaticRegionDetector.suppressingNativeDuplicates(_:nativeFields:)` (intersection/min-area ≥ 0.60, same page only) wired into `AppModel.refreshCandidateCaches()`. Unrelated painted fields elsewhere on the page survive. | `Sources/PDFEditorCore/StaticRegionDetector.swift`, `Sources/PDFEditorRecovery/AppModel.swift` |
| A1 signature occupancy audit | New module: `SignatureObservation` (present/missing/uncertain) + `SignatureSlot`; role-word slot detection (multi-signer blocks only, lower page band, ≥2 roles); CoreGraphics raster ink classification with the reference lane's calibrated thresholds (dark ≥0.003 present, ≤0.0005 missing); UI card in the inspector under document scope, review-only. | `Sources/PDFEditorCore/SignatureOccupancyAudit.swift` (new), `Sources/PDFEditorApp/ContextualInspectorView.swift` |
| A2 abstention copy | Zero-suggestion state now explains abstention ("a region needs both a field-like label and nearby geometry") with the OCR recovery path. | `Sources/PDFEditorApp/ContextualInspectorView.swift` |

## Cross-lane fixes (shared target was broken by the parallel lane)

While verifying, the parallel lane's in-flight `PDFIncrementalFormWriter` changes could not
compile on this toolchain (`Data`/`NSData.compressed(using:)` does not exist here — confirmed
with a standalone probe). After the file went quiet, applied the minimal correct fix and one
test call-site alignment; flagged for the lane owner to review:

- `Sources/PDFEditorCore/PDFIncrementalFormWriter.swift` — nested `zlib(_:)` now emits a real
  RFC 1950 stream (zlib header `0x78 0x9C` + raw deflate via `compression_encode_buffer` +
  Adler-32). PDF `/FlateDecode` requires the wrapped stream; bare `COMPRESSION_ZLIB` output
  would be subtly wrong.
- `Tests/PDFEditorCoreTests/ReviewFixVerificationTests.swift:348` — `walkAcroForm(sampleForm)`
  → `walkAcroForm(try Data(contentsOf: sampleForm))` to match the lane's new `Data` signature.

## Verification

Code (Tier 2):
- `swift build` and `swift build --build-tests` clean.
- New suite `Tests/PDFEditorCoreTests/FormFieldLabSalvageTests.swift` — **11/11 pass**, including
  the S2 fixtures (pre-fix behavior provably wrong: "candidate" contains "date"; post-fix correct)
  and a real-PDF integration test (generated two-block signing page: Secretary PRESENT,
  Director MISSING, prose page contributes zero observations).
- Regression: `FieldSuggestionFidelityTests` 13/13, `ReviewFixVerificationTests` 11/11 (the
  latter also exercises the zlib fix end-to-end through the writer).
- Known unrelated reds: pdf-lib external-engine round-trips (pre-existing RG-135/parity family,
  node-engine environment), untouched by this work.

Feature (Tier 3): generated fixtures via the new reusable
`benchmark/datasets/generate_form_salvage_fixtures.py` (reportlab): zero-target prose+table
page and a signature-block page with ink in one slot. Detector abstains on the first; audit
classifies present/missing on the second (both in tests and in the live app).

Visual (Tier 4, live app screenshots):
- Zero-target fixture: Review tab shows "Detected Candidates 0 region(s)" / "Native Form Fields 0";
  document scope shows the abstention card with the new copy + OCR recovery action.
- Signature fixture: **Signature Audit card renders "MISSING John Doe — Director · 93%" and
  "PRESENT Jane Roe — Secretary · 72%"** under "Review-only document evidence — observations
  never become fields."

## Implementation notes worth keeping

- PDFKit `PDFPage.draw(with:to:)` produced non-uniform content offsets in this environment;
  rendering switched to CoreGraphics `CGContext.drawPDFPage` with explicit scale. CG bitmap
  memory is top-down while page space is bottom-origin — `darkRatio` remaps rows explicitly.
- PDFKit selection line bounds carry ~2.5pt padding per edge; the reference lane's 18pt
  printed-name gap widened to 22pt to survive selection-based geometry.
- The audit is page-limited (`pageLimit`, UI uses 12) per the reference lane's resource-budget
  lesson; slot detection requires a ≥2-role signing block (Medpiper hard-negative discipline),
  so prose/financial pages contribute zero observations by construction.

## Open items

1. Composite semantic groups + photo target kinds (A3) — not started; needs UI design pass.
2. Multilingual fill contract registration (B1) — contract doc only, additive schema later.
3. Label-governance patterns (B2) — fold verified-retention + family-disjoint holdout rules
   into `CandidateReviewLearningEvents` when the review flywheel gets real volume.
4. Signature audit: embedded-image occupancy lane (image XObjects) not ported yet — raster
   ink path only; false-negative risk for stamped images noted.
5. Manual-add recovery affordance for the abstention state (draw-a-region tool) — not built;
   card currently routes to OCR instead.
