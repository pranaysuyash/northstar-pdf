# Calibration Corpus Verification + False-Positive Report

**Date:** 2026-08-28
**Status:** Observed + Verified
**Evidence tier:** Tier 3 (integration — real PDF corpus)
**Test sensitivity:** S1 (13 tests pass), S2 (fingerprint collision documented as finding)

## 1. Decision context

The RecurringFormCalibrator and PageBoxPolicy were verified against synthetic data only. The question: do calibrated thresholds hold against **real PDF corpus files**?

## 2. `CalibrationCorpusVerificationTests.swift` (13 tests)

Runs both components against `benchmark/results/corpus-sweep-2026-08-25/` real PDFs:
- plain-text.pdf, multi-column.pdf, geometry.pdf, navigation.pdf, metadata-complete.pdf

### Verified against real PDFs

| Check | Result |
|---|---|
| Page box extraction | ✅ 5/5 PDFs extract valid mediaBox/cropBox |
| Page size consistency | ✅ All Letter (612×792) or A4 (595×842) |
| Canonical box selection | ✅ cropBox or mediaBox wins |
| Negative coordinate normalization | ✅ |
| Fingerprint determinism | ✅ Stable across reads |
| Cross-system self-comparison | ✅ Zero deviation |
| Strict tolerance (±0.1pt) | ✅ Catches 0.2pt deviation |
| Relaxed tolerance (±1.0pt) | ✅ Accepts 0.8pt deviation (added `.relaxed` preset) |
| Exact-match classification | ✅ Each PDF matches itself, score 1.0 |
| Cross-PDF rejection | ✅ Never `.exact` for different PDFs |
| Full corpus calibration report | ✅ Valid accuracy + FPR + recommendations |
| Hard negative rejection | ✅ 0 false positives, passes 5% threshold |

## 3. `FalsePositiveReport.swift` (233 lines)

Generates structured false-positive reports from calibration runs:
- `FalsePositiveEntry` — entry ID, class, actual tier, score, matched template, fingerprint similarity, expected tier
- `FalsePositiveReport` — total hard negatives, FP count, FP rate, per-class breakdown, per-tier breakdown, recommendations, passes-threshold flag
- `FalsePositiveReportGenerator` — configurable max FP rate (default 5%), data-driven recommendations

## 4. Real findings (Observed, not defects)

| Finding | What happened | Root cause | Action |
|---|---|---|---|
| **Fingerprint collision** | 2 of 4 corpus PDFs share same fingerprint | Simple fingerprint (page size + rotation + count) too coarse | Need richer fingerprint (content hash, field count, text density) |
| **Family match on different PDFs** | Different PDF with same page size → `.familyMatch` | Same collision + Jaccard similarity threshold | Need content-aware fingerprint or higher family threshold |

These are **documented as known variances** — the tests assert the invariant that matters (never `.exact` for different PDFs), not the weaker property (never any match), because the current fingerprint is known-coarse.

## 5. Evidence

- 13 calibration corpus tests pass
- Full suite: 1275/1275 pass
- `.relaxed` tolerance preset added to `PageBoxPrecisionPolicy`

## 6. Doctrine alignment

- §5 Evidence-based: verified against real PDFs, not synthetic only
- §3 Proportional rigor: Tier 3 (integration) with real corpus
- §2 Truth taxonomy: findings labeled Observed; fingerprint limits stated

## 7. Open questions

- Should the layout fingerprint be upgraded to include content hashes?
- Should the corpus expand to browser-corpus PDFs (rotated, hybrid, scanned)?
- Should calibration results be persisted as benchmark evidence artifacts?
## 8. V1 → V2 migration addendum (2026-08-28)

### What changed

The calibration corpus tests no longer use the V1 `computeLayoutFingerprint`
(char-Jaccard over digest hex strings). They now exercise the **V2 structured
lane** end-to-end:

- `RecurringFormCalibrator` gained a V2-aware `classify`/`calibrate` path:
  `CorpusEntry` carries an optional `layoutV2: LayoutFingerprintV2?`
  (backward-compatible Codable), and classification uses the structured
  `similarity(to:)` on the F-3-calibrated scale (`familyThreshold = 0.90`).
  Entries without V2 fall back to the legacy string lane (hard-negative
  machinery preserved).
- `CalibrationCorpusVerificationTests` replaced every V1 fingerprint
  computation with `LayoutFingerprintV2Extractor` (14 call sites, 0 V1
  references remain). All 14 tests run on the V2 lane.

### What the V2 lane fixed (Observed, real corpus)

The persisted artifact diff documents the honest V1 → V2 delta:

| Entry | V1 (char-Jaccard) | V2 (structured) | Verdict |
|---|---|---|---|
| navigation (not a template) | 0.900 → `knownVariant` (false positive class) | 0.713 → `noMatch` (correct) | F-4 false-similarity eliminated |
| hard-neg-similar | 0.080 | 0.138 | correctly rejected |
| hard-neg-different | 0.087 | 0.148 | correctly rejected |
| 3 template entries | exact @ 1.0 | exact @ 1.0 | unchanged |

V1's digest-hex Jaccard pushed a distinct document to the family boundary.
V2's per-page aligned structural similarity measures the actual layout:
navigation shares the same page geometry but not the text/field cells, so it
scores 0.713 — below the calibrated 0.90 threshold. This is the same
false-similarity class F-4 fixed in `LayoutFingerprintV2.similarity`, now
observable in the calibrator.

### Test-expectation correction (honest labeling)

The pre-migration artifact expected `.exact` for **navigation** while the
template set only contained plain-text/multi-column/geometry (first 3
entries). `exact` is impossible for a non-template entry, so the expectation
was wrong, not the pipeline. Corrected to `.noMatch` — the tier F-3
(Verified 2026-08-28) measured for navigation against every template
(0.378–0.713, all < 0.90). Result: **6/6 passed, 0 false positives, 0 false
negatives, accuracy 1.0** on the persisted artifact.

### Evidence

- 14/14 calibration corpus tests pass on the V2 lane
- Full suite: 1322/1322 pass
- Persisted artifact regenerated: `benchmark/results/recurring-form-calibration/recurring-form-calibration-report-2026-08-28.json`
  (`familyThreshold: 0.9`, accuracy 1.0, zero false positives/negatives)
