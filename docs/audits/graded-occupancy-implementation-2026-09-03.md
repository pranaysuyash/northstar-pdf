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
- RecoveryCrashInterruption: load-tolerant child-startup deadline (20s → 60s) with harness-failure diagnostics — the child pays spawn + model init + full inspection before emitting its phase, which exceeded 20s under heavy machine load.
- RecentDocumentHistory: falsified test premise — bookmark resolution TRACKS same-volume renames (resolved URL = moved.pdf, file exists — better than the assumed stale-path behavior) and canonicalizes /var → /private/var (symlink traversal `standardizedFileURL` does not perform). Test now compares symlink-resolved URLs on both sides and measures current bookmark semantics.
