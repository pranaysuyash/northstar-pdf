# AcroForm Radio Parity — N/A Root Cause and Fix (2026-09-03)

**Status:** Resolved — radio measured `production-ready` (7/7 round-trip) after a
classification and verification fix. The prior `N/A` was a measurement defect,
not a corpus absence.

## 1. The reported state (before)

```
Radio  ⚠️ Functional — Read+write works, selection state not preserved  N/A
```

Gate report: `radio` → `canDetect: false, canRead: false, canRoundTrip: false,
verifiedFixtures: 0, confidence: 0, decision: unsupported` for all providers.
Documented as: "no radio fields exist in the corpus."

## 2. Why N/A — three root causes (Observed)

1. **False corpus-absence claim.** `public-acroform/noop.pdf` (in the parity
   corpus) carries a real radio group: `applicant.contact` with 2 kids whose
   export values are `"0"`/`"1"` (Verified 2026-09-03 via pikepdf tree walk and
   a PDFKit probe). The experiment could not see it because `classifyField`
   returned `.checkbox` for **every** `/Btn` annotation; the doc comment
   promised "radio detection is done at document level" but that logic was
   never wired into `detectFields`. Radio measured zero fixtures by
   construction, on a corpus that contained radios.

2. **Wrong write API.** The round-trip wrote radio values via
   `setValue(_:forAnnotationKey: .widgetValue)`. Probe result: **no selection
   survives** for any candidate value (`email`, `phone`, `Yes`, `Off`, `1`,
   `0`). The `buttonWidgetStateString` setter is also a no-op. The working API
   is the settable `buttonWidgetState` — Verified: setting `.on` on the target
   kid survives save/reopen.

3. **Order sensitivity.** PDFKit's `.off` setter on one kid clears the whole
   group's state (last write wins). Probe: target `.on` then sibling `.off` →
   selection lost; sibling `.off` first then target `.on` → selection
   survives. The fix writes siblings off first, then the target on — mirroring
   the verified incremental-writer semantics (`/AS` on selected kid, `/Off` on
   siblings, group `/V` = export value).

4. **Weak read-back verification.** The old radio check only asserted "at least
   one field in the group has a readable value" (`hasAnyValue`) — which is why
   "selection state not preserved" could never be caught. The fix asserts:
   exactly one kid selected, its `buttonWidgetStateString` equals the written
   export value, every sibling off.

## 3. The fix

`Sources/PDFEditorCore/AcroFormParityExperiment.swift`:

- `detectFields(doc:type:)` now performs document-level radio detection:
  `/Btn` annotations sharing a `fieldName` (count > 1) are a radio group;
  `.radio` returns group members, `.checkbox` returns only single-member
  `/Btn` fields.
- `readFieldValues` reads radio groups at group level (the selected kid's
  export value) instead of a misleading per-kid `"Off"`.
- `roundTripTest` writes radio selections via `buttonWidgetState` in
  off-then-on order and verifies the **specific** selection survives.

Tests (`Tests/PDFEditorCoreTests/AcroFormParityExperimentTests.swift`):

- `radioSelectionRoundTrips` — asserts `applicant.contact` is a 2-kid group
  with export values `"0"`/`"1"`, writes a selection, reopens, and asserts the
  exact option survives.
- `experimentRuns` now hard-fails if radio is not detected or does not
  round-trip (regression guard against returning to N/A).

## 4. Measured result (Verified 2026-09-03)

| Field type | Before | After |
|---|---|---|
| radio | unsupported / N/A (0 fixtures) | **production-ready, 7/7 fixtures round-trip, confidence 1.0, ghost 0** |
| checkbox | limited (5/9) | limited (5/9) — unchanged |
| choice | experimental (8/9) | experimental (8/9) — unchanged |
| text | production-ready (9/9) | production-ready (9/9) — unchanged |

Radio groups detected in 7 of 9 corpus fixtures via shared-name `/Btn` grouping
(page-level annotation scan; a pikepdf `/AcroForm`-tree walk alone undercounts
because several fixtures carry widgets without a form root).

## 5. Honest caveats

- **"Cross-provider" is simulated for PDF.js and qpdf**: `testProvider` runs
  the same PDFKit code path for all three provider labels. The experiment
  measures PDFKit's handling; the parity claim is inferred from identical
  behavior, not independent implementations. This predates the fix and is
  documented here for the first time. A genuinely independent provider lane
  (pdf-lib / pdfcpu / Poppler) remains open work.
- Radio evidence is **1 distinct radio group** (`applicant.contact`) across
  fixture variants; the 7 "fixtures" share that group via producer re-encodes
  and the shared-name widget fixtures. Expanding to more distinct radio groups
  (different export vocabularies, /Opt arrays, hierarchical names) is the
  follow-up that would harden the production-ready claim.
- PDFKit's `buttonWidgetState` setter may be a no-op on some third-party widget
  encodings (the same failure class as the checkbox 67% limitation). The gate
  would catch it honestly as a `failedFixture`.

## 6. Doctrine alignment

- §2 Truth taxonomy — the "no radio fields in the corpus" label was falsified
  by measurement; the corrected label is Verified evidence (probe + round-trip).
- §5 Evidence-based — the write API and ordering are backed by standalone probe
  results, not assumptions.
- §10 Failure — the weak `hasAnyValue` check was a latent false-pass; the fix
  makes the failure mode (selection loss) detectable.

## 7. Artifacts

- `benchmark/results/acroform-parity/acroform-parity-gate-report.json`
  (regenerated; radio = production_ready, 7/7)
- `Sources/PDFEditorCore/AcroFormParityExperiment.swift`
- `Tests/PDFEditorCoreTests/AcroFormParityExperimentTests.swift` (4 tests)

## 8. Follow-up hardening (2026-09-06) — CLOSED

The radio production-ready claim was hardened beyond the base corpus's single
`applicant.contact` group: 8 generated fixtures (varied export vocabularies,
hierarchical dotted names, numeric, degenerate fail-closed cases) now have a
dedicated suite (`GeneratedRadioFixtureTests`, 6 tests), and the `/Opt`-array
half of the request was measured and covered as **choice** fields
(`/FT /Ch`) — the field type `/Opt` actually belongs to — with 7 fixtures and
`GeneratedChoiceFixtureTests` (7 tests). Full details and the two writer
defects the work uncovered: `docs/audits/radio-choice-fixture-hardening-2026-09-06.md`.