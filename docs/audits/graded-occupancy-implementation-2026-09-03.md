# Graded Occupancy Implementation — 2026-09-03

## What Changed

Replaced binary occupancy cells (occupied/not) with **graded occupancy cells** (0.0–1.0
fractional ink coverage per cell). The similarity comparison now uses **cosine similarity**
on graded vectors instead of binary Jaccard.

## Files Modified

| File | Change |
|---|---|
| `Sources/PDFEditorCore/LayoutFingerprintV2.swift` | Added `GradedCell` struct, `gradedOccupancyCells` field in `PageLayout`, `gradedOccupancySimilarity()` method |
| `Sources/PDFEditorCore/ContentInvariantRasterExtractor.swift` | Added `extractGradedOccupancy()` method |
| `Tests/PDFEditorCoreTests/ExternalDatasetEvalTests.swift` | Fixed FUNSD entity-type case mismatch |

## Why Binary Failed

Binary Jaccard on occupancy cells has a fundamental limitation: anti-aliasing differences
near content boundaries flip cells from 1→0 or 0→1. Two structurally identical documents
with different re-encoding have nearly identical binary occupancy patterns, but so do
structurally different documents with similar ink density.

The binding constraint was that edge/occupancy Jaccard adds noise that inflates hard-negative
scores faster than positive scores at higher blend ratios:

| Blend | minPositive | maxHardNegative | Gap | Status |
|---|---|---|---|---|
| 100/0/0 (projection only) | 0.9017 | 0.9723 | 0.045 | ✅ PASS |
| 95/3/2 | 0.9017 | 0.9723 | 0.045 | ✅ PASS |
| 85/8/7 | 0.8935 | 0.9555 | 0.002 | ❌ FAILS |
| 70/15/15 | 0.8810 | 0.9302 | -0.022 | ❌ FAILS |
| 50/25/25 | 0.8645 | 0.8966 | -0.032 | ❌ FAILS (inverted) |

## How Graded Occupancy Fixes It

Graded occupancy captures HOW MUCH ink each cell has (0.0–1.0) instead of WHETHER it has
ink (0 or 1). Cosine similarity on graded vectors is inherently content-invariant:

- A cell with 80% coverage is structurally similar to one with 75% coverage
- Binary Jaccard treats both as identical to a cell with 100% coverage
- Cosine similarity reduces sensitivity to anti-aliasing differences near boundaries

## Results After Implementation

The raster weight sweep now shows **all weights from 0.02 to 0.20 passing**:

```
[weight-sweep] weight | minPos | maxNeg | gap    | status
[weight-sweep] -------|--------|--------|--------|-------
[weight-sweep] 0.02  | 0.9997 | 0.5514 | 0.4483 | ✅
[weight-sweep] 0.03  | 0.9995 | 0.5516 | 0.4479 | ✅
[weight-sweep] 0.04  | 0.9993 | 0.5518 | 0.4476 | ✅
...
[weight-sweep] 0.20  | 0.9972 | 0.5541 | 0.4430 | ✅
[weight-sweep] Best valid raster weight: 0.20
```

**Gap improved from 0.045 (at 100/0/0) to 0.44 (at 0.20)** — a 10× wider separation
between positives and hard negatives.

## Backward Compatibility

- `gradedOccupancyCells` decodes to empty array from old records (Codable default)
- Binary `occupancyCells` is preserved for backward compatibility
- Cosine similarity falls back to binary Jaccard when graded data is absent

## Test Results

All affected tests pass:
- LayoutFingerprintV2 tests: 13/13 pass
- ContentInvariantRaster tests: pass
- Calibration tests: pass
- EvidenceFloorAbstention tests: 15/15 pass
- Weight sweep: all 19 weights pass (0.02–0.20)

Two pre-existing failures unrelated to this change:
- ManifestFieldPresenceGateTests (xfa-hybrid widget count)
- RecoveryCrashInterruptionTests (payload interruption)

**Both resolved 2026-09-06** (plus RecentDocumentHistoryTests /private/var vs /var symlink mismatch — the third known pre-existing failure):
- ManifestFieldPresenceGate: the test compared the manifest's pikepdf field-tree count (`/Fields` = [hybridField], 1) against PDFKit's page-widget count (6 base-form annotations orphaned when `write_xfa` rebuilt the AcroForm) — a semantics conflation, not a fixture defect (fixture sha256 matches the manifest exactly). The test now counts field-tree entries with pikepdf semantics.
- RecoveryCrashInterruption: load-tolerant child-startup deadline (20s → 240s) with harness-failure diagnostics; after full-suite evidence showed five OCR provider jobs could still starve the child across SwiftPM test targets, the heavy lanes now share a process-level lock so the deadline remains a genuine hung-child bound rather than a contention workaround.
- RecentDocumentHistory: falsified test premise — bookmark resolution TRACKS same-volume renames (resolved URL = moved.pdf, file exists — better than the assumed stale-path behavior) and canonicalizes /var → /private/var (symlink traversal `standardizedFileURL` does not perform). Test now compares symlink-resolved URLs on both sides and measures current bookmark semantics.

## Addendum (2026-09-08): multi-scale rework — the 2026-09-03 version was degenerate

**Observed (blend-sweep calibration probe, 2026-09-08):** the original
`extractGradedOccupancy` rendered at 0.15 scale with 4pt cells — a 4pt cell
spans ~0.6 px at that scale, so each cell's "fractional coverage" was a
**single pixel sample**: coverage ∈ {0, 1}, i.e. binary in disguise. The
cosine similarity was operating on binary data with extra steps.

**Verified fix (2026-09-07/08, in `ContentInvariantRasterExtractor.swift`):**

- `gradedScales: [16.0, 64.0]` — coarse grids only; the degenerate 4pt scale
  is dropped from the graded channel.
- Render scale 0.15 → 0.5: a 16pt cell spans ~8 px/side (~64 samples), a
  64pt cell ~32 px/side (~1024 samples) — coverage is genuinely fractional.
- Measured on the corpus: 439 distinct coverage values (3dp), 3.7% exactly-0/1
  cells (vs 629/16.6% under an intermediate ungated version; the 2026-09-03
  original was ~100% degenerate).
- `gradedOccupancySimilarity` keys vectors by (scale, col, row) so the two
  grids cannot collide; `GradedCell` gained a `scale` field with explicit
  backward-compatible Codable (old records decode with scale 0 sentinel).

**Falsifier:** `RasterBlendCalibrationGateTests.gradedOccupancyIsFractional`
(≥20 distinct coverage values, <10% degenerate cells, scales == {16, 64}).
