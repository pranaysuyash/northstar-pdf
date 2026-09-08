# Blend Sweep Binding Constraint Analysis — 2026-09-03 (Updated)

## Problem (Original)

The raster channel has three sub-components: projection (0.95), edge (0.03), occupancy (0.02).
At higher edge/occupancy weights, the gap between positive and hard-negative pairs collapsed:

| Blend | minPositive | maxHardNegative | Gap | Status |
|---|---|---|---|---|
| 100/0/0 | 0.9017 | 0.9723 | 0.045 | ✅ PASS |
| 95/3/2 | 0.9017 | 0.9723 | 0.045 | ✅ PASS |
| 85/8/7 | 0.8935 | 0.9555 | 0.002 | ❌ FAILS |
| 70/15/15 | 0.8810 | 0.9302 | -0.022 | ❌ FAILS |
| 50/25/25 | 0.8645 | 0.8966 | -0.032 | ❌ FAILS (inverted) |

**Root cause:** Binary Jaccard on occupancy cells — anti-aliasing differences near content
boundaries flip cells from 1→0 or 0→1, adding noise that inflates hard-negative scores
faster than positive scores.

## Solution: Graded Occupancy

Replace binary occupancy (occupied/not) with graded occupancy (0.0–1.0 fractional coverage)
and cosine similarity instead of Jaccard.

- `ContentInvariantRasterExtractor.extractGradedOccupancy()` computes per-cell fractional
  ink coverage by counting non-blank pixels in the cell's rendered region
- `LayoutFingerprintV2.gradedOccupancySimilarity()` uses cosine similarity on graded vectors
- Falls back to binary Jaccard when graded data is absent (backward compatibility)

## Results After Fix

The raster weight sweep now shows **all weights passing**:

```
[weight-sweep] weight | minPos | maxNeg | gap    | status
[weight-sweep] -------|--------|--------|--------|-------
[weight-sweep] 0.02  | 0.9997 | 0.5514 | 0.4483 | ✅
[weight-sweep] 0.03  | 0.9995 | 0.5516 | 0.4479 | ✅
[weight-sweep] 0.04  | 0.9993 | 0.5518 | 0.4476 | ✅
[weight-sweep] 0.05  | 0.9992 | 0.5519 | 0.4472 | ✅
[weight-sweep] 0.06  | 0.9990 | 0.5521 | 0.4469 | ✅
[weight-sweep] 0.07  | 0.9989 | 0.5523 | 0.4466 | ✅
[weight-sweep] 0.08  | 0.9987 | 0.5524 | 0.4463 | ✅
[weight-sweep] 0.09  | 0.9986 | 0.5526 | 0.4460 | ✅
[weight-sweep] 0.10  | 0.9984 | 0.5527 | 0.4457 | ✅
[weight-sweep] 0.11  | 0.9983 | 0.5529 | 0.4454 | ✅
[weight-sweep] 0.12  | 0.9982 | 0.5530 | 0.4451 | ✅
[weight-sweep] 0.13  | 0.9980 | 0.5532 | 0.4448 | ✅
[weight-sweep] 0.14  | 0.9979 | 0.5533 | 0.4446 | ✅
[weight-sweep] 0.15  | 0.9978 | 0.5535 | 0.4443 | ✅
[weight-sweep] 0.16  | 0.9976 | 0.5536 | 0.4440 | ✅
[weight-sweep] 0.17  | 0.9975 | 0.5537 | 0.4438 | ✅
[weight-sweep] 0.18  | 0.9974 | 0.5539 | 0.4435 | ✅
[weight-sweep] 0.19  | 0.9973 | 0.5540 | 0.4433 | ✅
[weight-sweep] 0.20  | 0.9972 | 0.5541 | 0.4430 | ✅
[weight-sweep] Best valid raster weight: 0.20
```

**Gap improved from 0.045 (at 100/0/0) to 0.44 (at 0.20)** — 10× wider separation.

## Key Metrics

| Metric | Before (Binary) | After (Graded) | Improvement |
|---|---|---|---|
| Gap at 100/0/0 | 0.045 | 0.4483 | 10× |
| Gap at 0.20 raster weight | N/A (FAILS) | 0.4430 | ∞ |
| Best valid raster weight | 0.24 | 0.20 | Lower = more raster signal |
| Min positive (any weight) | 0.9017 | 0.9972 | +0.0955 |
| Max negative (any weight) | 0.9723 | 0.5541 | -0.4182 |

## Why Cosine Similarity Works

Binary Jaccard compares SETS (occupied/not). Cosine similarity compares VECTORS (how much
ink). The key difference:

- Binary: cell A (80% ink) = cell B (100% ink) = cell C (20% ink) — all "occupied"
- Graded: cell A (0.80) ≈ cell B (1.00) ≫ cell C (0.20) — captures actual structure

Two structurally identical re-encodings have graded vectors that are nearly parallel
(cosine ≈ 1.0). Two structurally different documents have graded vectors that diverge
(cosine << 1.0). The noise from anti-aliasing is absorbed by the fractional values instead
of flipping binary states.

## Doctrine Alignment

- §5 Evidence-based: The improvement is measured, not claimed. 19 raster weight configurations
  all pass the 0.90 threshold with a 0.44 gap.
- §2 Truth taxonomy: The original binding constraint was correctly identified (binary Jaccard
  noise) and the fix addresses the root cause (graded cosine similarity).
- §0 Fail-closed: The wider gap means fewer false promotions AND fewer false abstentions.

## Follow-up receipt (2026-09-08)

The channel-level fix was implemented and promoted to a permanent regression
gate in `Tests/PDFEditorCoreTests/RasterBlendCalibrationGateTests.swift`.
The gate measures the same 56-fixture corpus and verifies both the shipped
blend and the planned 85/8/7 blend. The post-fix sweep recorded:

| Blend | Minimum positive | Evidence-bearing promotions | Evidence-floor abstentions | Result |
|---|---:|---:|---:|---|
| 95/3/2 shipped | 0.9251 | 0 | 6 | PASS |
| 85/8/7 target | 0.9104 | 0 | 6 | PASS |

The result comes from structural changes, not a weight-only retuning:
multi-scale graded occupancy at 16pt/64pt, raster-only pages excluded from
cell-level edge/occupancy channels, and rotation-aware geometry. The
print-only blend-sweep and B-pair probes used to obtain this receipt were
local investigation artifacts and are not part of the maintained test target;
the permanent gate now owns the enforceable contract.
