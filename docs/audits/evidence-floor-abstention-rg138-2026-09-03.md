# RG-138 — Evidence-Floor Abstention for Raster-Only Family Claims

**Date:** 2026-09-03
**Status:** Implemented and ratified
**Doctrine refs:** §0 Fail-closed, §2 Truth taxonomy, §4.3 default fail-closed, §5 Evidence-based, §8 Capability routing

---

## 1. The problem

A family claim (match template → prefill) was being promoted on **geometry + coarse
occupancy alone**. Two unrelated graphics-heavy / scanned documents of the same page
size with similar ink density scored above the 0.90 family threshold:

| Pair | Total | Why |
|---|---|---|
| scanned-noisy ↔ ocr-low-contrast | 0.9886 | Same geometry, empty text/field/annotation channels, similar raster ink |
| diverse-graphics-heavy ↔ diverse-scanned-sim | 0.972 | Same geometry, empty structured channels |
| ocr-clean-english ↔ ocr-dense-paragraph | 0.902 | Same geometry, empty structured channels |

That is "same page size," not "same form." A false promotion pollutes the template
store and risks wrong prefill; a false abstention is recoverable (the user
re-specifies the form). The cost asymmetry is the doctrine's own fail-closed default
(§4.3).

## 2. The falsified hypothesis

The prior decision path (raster-weight-analysis §150) said: *"the binding constraint
is corpus composition — add more graphics-heavy fixtures."*

**That hypothesis was tested and falsified (Observed, 2026-09-03).**

- The corpus was expanded to 60 fixtures, including 11 graphics-heavy PDFs
  (scanned, multi-column, graphics-heavy, table grid).
- The graphics-heavy high scorers **persisted** (0.9886, 0.972, 0.902 above
  threshold).
- Measured finding: **the binding constraint is extraction resolution, not corpus
  composition.** Two documents with identical geometry and identical coarse raster
  ink distribution are indistinguishable at 32-bin projection resolution —
  no amount of additional fixtures separates them, because the pairs genuinely
  share every channel the fingerprint measures.

This redirects future work to the **OCR/vision channel** (real text from scans is
the missing evidence), not more fixtures or more threshold tuning.

## 3. The evidence floor (implemented)

### 3.1 `SimilarityCoverage`

`LayoutSimilarityV2` now carries a `coverage` field:

```swift
public struct SimilarityCoverage: Codable, Sendable, Equatable {
    public let text: Bool
    public let field: Bool
    public let annotation: Bool
    public let region: Bool
    public let raster: Bool
    public var hasStructuredContent: Bool { text || field || annotation || region }
}
```

- `hasStructuredContent` is true when either document carries **structured** content
  (text cells, field cells, annotation cells, or text regions) on any page.
- Raster ink alone does **not** count as structured content — it is the coarse,
  content-invariant channel that caused the false promotions.

### 3.2 `insufficientEvidence` tier

`RecurringFormCalibrator.MatchingTier` gains a fifth tier:

```swift
case insufficientEvidence
```

`isMatch` remains false for it; the description routes to the confirmation lane:
*"Insufficient evidence — no structured content; routes to confirmation lane."*

### 3.3 Classification gating

`classify(...)` now applies the floor at **both** promotion points:

1. **Known-variant branch** (canonical digest equality): if both documents are
   content-less, canonical equality is **vacuous** — "same page size, same
   emptiness." Two unrelated scans of the same page size collapse to one canonical
   key (Observed: scanned-noisy↔ocr-low-contrast). Claiming a known variant on
   vacuous equality is the same false family claim the floor exists to stop →
   returns `.insufficientEvidence` instead of `.knownVariant`.

2. **Family branch** (structured similarity above threshold): if the best-matching
   template pair has no structured content on either side → `.insufficientEvidence`
   instead of `.familyMatch`.

### 3.4 Confirm-lane routing (§8)

The abstention tier routes to lanes with real evidence:

- **OCR spot-check** — `OCRCompanionBenchmark` (Tesseract / Vision / PaddleOCR /
  Marker) extracts real text from the scanned candidate.
- **Human visual confirmation** — RG-135 workflow records reviewer observations
  against fixture SHA-256.

A chart-vs-scan pair fails the OCR check; a true re-encoding pair passes it. Family
members are **not** broken — the decision merely moves to a lane with real evidence.

### 3.5 Calibration semantics

`LayoutFingerprintThresholdCalibrationTests` (F-3) now asserts precision-first
semantics:

- A high-scoring pair **with** structured content that is not a true positive is an
  `evidencePromotion` → **fails the gate** (the precision failure the gate exists to
  catch).
- A high-scoring pair **without** structured content is an `abstention` → recorded
  as Observed evidence, printed, persisted in the artifact, **never promoted**.
- Every true positive pair must itself carry structured content (an evidence-free
  family member would correctly abstain and its corpus label would need review).

## 4. "What's needed to make the blend rows green?"

The blend sweep (projection/edge/occupancy) from the raster-weight analysis:

| Blend | minPositive | maxHardNegative | Status |
|---|---|---|---|
| 100/0/0 (projection only) | 0.9017 | 0.9723* | ✅ PASS* |
| 95/3/2 | 0.9012 | 0.7479 | ✅ PASS |
| 85/8/7 | 0.8935 | 0.9555 | ❌ FAILS |
| 70/15/15 | 0.8810 | 0.9302 | ❌ FAILS |
| 50/25/25 | 0.8645 | 0.8966 | ❌ FAILS (inverted) |

\* The 100/0/0 row's maxHardNegative (0.9723) is a **graphics-heavy abstention pair**,
not a promotion — under the RG-138 floor it no longer counts against the gate.

The answer: **these rows cannot be made green by tuning the blend.** The mechanism
is measured:

- Edge/occupancy channels are **cell-Jaccard**, and cell membership is
  threshold-fragile: re-encoding the *same* document at the *same* settings yields
  occupancy Jaccard ≈ 0.873 vs projection ≈ 0.987 (BlendProbe, 2026-09-03).
- Adding noise-weighted channels (edge/occupancy) drags **minPositive down faster
  than maxHardNegative** — the identical-pair score drops below 0.90 while hard
  negatives barely move.
- At 50/25/25 the separation inverts entirely: edge/occupancy noise dominates the
  signal.

**To make higher blends green you must fix the channel, not the weights:**

1. **Graded occupancy** — encode per-cell ink coverage fraction (0..1) instead of
   binary membership, so anti-aliasing shifts cost a little, not everything.
2. **Multi-scale with tolerance** — match cells with a distance-tolerance radius
   (e.g., ±1 cell) before Jaccard, absorbing sub-cell rendering shifts.
3. **Abandon the raster lane for the decision** — the RG-138 evidence floor is the
   production resolution: raster-only candidates abstain and route to the OCR/vision
   lane, where real text is the missing evidence.

Option 3 is what shipped. Options 1–2 remain open work if raster discrimination
itself must improve (see §6).

## 5. Evidence

- `SimilarityCoverage` + `insufficientEvidence` + classification gating —
  `Sources/PDFEditorCore/LayoutFingerprintV2.swift`,
  `Sources/PDFEditorCore/RecurringFormCalibrator.swift`
- `Tests/PDFEditorCoreTests/EvidenceFloorAbstentionTests.swift` — 15 tests,
  including the real-corpus pair:
  `scanned-noisy↔ocr-low-contrast total=0.9886 → insufficientEvidence (not promoted)`
- F-3 gate rework — `Tests/PDFEditorCoreTests/LayoutFingerprintThresholdCalibrationTests.swift`
- Calibration policy — `Tests/PDFEditorCoreTests/CalibrationPolicyTests.swift`
  (content-less canonical equality now abstains)
- Blend probe data (temporary probe, removed after use) — occupancy Jaccard on
  identical re-encoding ≈ 0.873 vs projection ≈ 0.987

## 6. Open work

- Graded occupancy cells (coverage fraction) for the raster channel
- Multi-scale tolerant matching (±1 cell radius)
- OCR/vision escalation wiring end-to-end (companion OCR spot-check invoked from
  the confirm lane)

## Cross-references

- [raster-weight-analysis-2026-08-30.md](./raster-weight-analysis-2026-08-30.md) —
  blend sweep table, superseded decision (§150 hypothesis falsified here)
- [content-invariant-raster-extraction-2026-08-31.md](./content-invariant-raster-extraction-2026-08-31.md)
- [first-principles-audit-2026-09-02.md](./first-principles-audit-2026-09-02.md) §4
- [rg-135 control viewer / human confirmation](./rg-131-dual-engine-verification-2026-09-01.md)