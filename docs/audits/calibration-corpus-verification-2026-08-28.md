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

---

## §9 Addendum (2026-08-29): Persisted artifact was not deterministic

### Finding (Observed → root cause Verified)

The committed artifact `recurring-form-calibration-report-2026-08-28.json`
showed a spurious diff after an unrelated `swift test` run:

```diff
     "tierBreakdown" : [
-      "noMatch",
-      3,
-      "exact",
-      3,
+      "exact",
+      3,
+      "noMatch",
+      3
     ],
```

Two defects, one root cause:

1. **Non-determinism.** `CalibrationReport.tierBreakdown` and
   `FalsePositiveReport.tierBreakdown` are `[MatchingTier: Int]`. Swift's
   `JSONEncoder` only produces a keyed container for `String`/`Int` keys or
   keys conforming to `CodingKeyRepresentable`. `MatchingTier` is a
   `String`-raw-value enum without that conformance, so the dictionary encoded
   as an **unkeyed array of alternating key/value pairs in dictionary hash
   order** — which is seeded per process and therefore differs run to run.
   `OutputFormatting.sortedKeys` could not help: there was no keyed container
   to sort. Every test run rewrote the committed artifact with a coin-flip key
   order.
2. **Wrong persisted shape.** An alternating array is not a usable schema for a
   report artifact; any reader has to reconstruct pairs by position.

Direct evidence (standalone `swiftc` probe, `tmp/keyrepr_check.swift`):

```
plain (no CodingKeyRepresentable): ["exact",3,"familyMatch",2,"noMatch",3]
keyed (CodingKeyRepresentable):    {"exact":3,"familyMatch":2,"noMatch":3}
```

### Fix

`MatchingTier` now conforms to `CodingKeyRepresentable` via
`MatchingTierCodingKey` (`Sources/PDFEditorCore/RecurringFormCalibrator.swift`).
The tier breakdown is now a real JSON object whose keys `.sortedKeys` orders
deterministically. No consumer changed: CI's artifact gate reads
`schema`, `thresholds.familyThreshold`, `calibration.falsePositives`, and
`calibration.accuracy`, never `tierBreakdown`; the only other readers are
in-memory tests.

### Falsifier

`tierBreakdownEncodesAsSortedObject()`
(`Tests/PDFEditorCoreTests/CalibrationCorpusVerificationTests.swift`) asserts
the root cause rather than the symptom. A within-process double encode cannot
detect hash-order drift — the seed is stable for the life of a process — so the
test asserts the breakdown encodes as a `{`-prefixed object with exactly the
sorted key order, and that it round-trips. Losing the conformance fails both
assertions.

### Evidence

- Artifact SHA-256 `5a209f27…` byte-identical across two consecutive full-suite
  runs (cross-process determinism, Verified 2026-08-29)
- Persisted artifact regenerated with `"tierBreakdown": {"exact": 3, "noMatch": 3}`
- Full suite: **1329/1329 pass** on 2026-08-29T18:40Z. The count is 1322 (pre-fix
  baseline) + 1 determinism test + 6 tests from the concurrently landing
  dual-lane detector gate (`DualLaneDetectorGateTests`), not from this change.

## §9 Expanded Corpus (2026-08-30, Observed → Verified)

### What changed
The calibration corpus expanded from 30 to 36 fixtures by adding browser-corpus
and rotation-corpus PDFs. This also triggered the F-5 fix (weight renormalization
for empty channels).

### New fixtures

| Fixture | Family | Layout | Source |
|---|---|---|---|
| pdfbox-pub-acroform.pdf | A | 595×842, 6 widgets, 163 chars | PDFBox re-encoding of base form |
| scanned-noisy.pdf | C | 1600×700 raster, 0 content | raster-only layout |
| printed-scan.pdf | C | 1600×700 raster, 0 content | OCR corpus raster |
| rotated-widget-90.pdf | D | 612×792 rot90, 4 widgets | rotated widget layout |
| handwritten-simulated-entries.pdf | N | 1800×1100, 0 content | hard negative |
| encrypted-reader.pdf | N | 612×792, 0 content | hard negative |
| repeated-20-pages.pdf | N | 20-page form | hard negative |

### F-5 fix: weight renormalization (Observed → Verified)

**Problem**: Zero-content documents (raster-only, encrypted, handwritten) had
all cell channels empty. The "agreement on absence" (score 1.0 per empty channel)
combined with fixed weights inflated the total. `scanned-noisy` ↔ `printed-scan`
scored 1.0 (both 1600×700 empty pages — genuinely identical). But
`scanned-noisy` ↔ `handwritten-simulated-entries` scored 0.9446 — too close to
the 0.90 threshold, and would promote hard negatives.

**Fix**: When a channel has zero content in both documents, its weight is
redistributed to channels that have data. This keeps the comparison grounded in
observable structure rather than absence.

**Measured effect**:

| Pair | Before F-5 | After F-5 | Change |
|---|---|---|---|
| scanned-noisy ↔ printed-scan | 1.0000 | 1.0000 | unchanged (genuinely identical) |
| scanned-noisy ↔ handwritten-sim | 0.9446 | 0.8418 | −0.103 (correctly discriminated) |
| printed-scan ↔ encrypted-reader | 0.9144 | 0.7554 | −0.159 (correctly discriminated) |
| hybrid-text-raster ↔ multi-column | 0.8132 | 0.7925 | −0.021 (content-bearing, minor) |

### Verified separation gap (36 fixtures)

- Positive pairs: 233 (22 A + 2 B + 2 C + 1 D within-family)
- Hard-negative pairs: 397
- Min positive: 0.9676
- Max hard negative: 0.8418
- Separation gap: 0.8418..0.9676 (midpoint 0.9047)
- **Threshold 0.90 sits strictly inside the gap**
- **Zero hard-negative promotions**
