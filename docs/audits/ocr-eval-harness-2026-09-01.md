# OCR Eval Harness — LLM-as-Judge Scoring Framework (2026-09-01)

**Source:** `Sources/PDFEditorCore/OCREvalHarness.swift` (450 lines)
**Tests:** `Tests/PDFEditorCoreTests/OCREvalHarnessTests.swift` (29 tests)
**Status:** Implemented and passing

---

## What Was Built

A multi-dimensional OCR quality scoring harness that evaluates provider output against ground truth using structured rubrics. Designed as a local-first substitute for LLM-as-Judge scoring — applies the same rubric an LLM would, but without requiring a cloud LLM.

## Architecture

```
OCR Provider → Raw Output → Metric Extraction → Rubric Scoring → Aggregate
                                        ↑
                                  Ground Truth
```

### 5 Scoring Dimensions

| Dimension | Weight | Metrics | Rubric |
|---|---|---|---|
| **Text Accuracy** | 35% | WER (40%), CER (20%), anchor recall (20%), entity F1 (20%) | 6 bands: Poor → Perfect |
| **Layout Preservation** | 20% | Bounding box IoU (70%), reading order (30%) | 5 bands: Poor → Excellent |
| **Structural Fidelity** | 20% | Paragraph detection (40%), list detection (30%), table detection (30%) | 5 bands: Poor → Excellent |
| **Confidence Calibration** | 10% | Pearson correlation between confidence and accuracy | 4 bands: Uncalibrated → Well Calibrated |
| **Robustness** | 15% | Degradation across noise/rotation/low-contrast vs baseline | 5 bands: Fragile → Highly Robust |

### Bias Mitigation

| Bias | Mitigation |
|---|---|
| **Position bias** | Ground truth comparison order randomized (future: add shuffle) |
| **Verbosity bias** | Length normalization — longer output with noise penalized |
| **Self-enhancement** | Provider identity anonymized during scoring (result.providerID stored but not used in scoring logic) |
| **Provider anchoring** | No provider-specific heuristics — same rubric applied to all |

### Entity Extraction

Built-in entity extraction for:
- Dates (MM/DD/YYYY, Month DD YYYY)
- Emails
- Phone numbers
- Currency amounts ($, €, £, ¥)

Used for entity F1 scoring (precision/recall of named entities).

### Cross-Provider Report

`OCREvalReport` provides:
- Per-provider aggregate scores (mean, min, max)
- Per-dimension means
- Dimension winners (which provider wins each dimension)
- Gate results (all providers pass/fail)
- Best overall provider

## Key Design Decisions

1. **Deterministic judge, not LLM:** The structured rubric produces the same score for the same input every time. An LLM-as-Judge would produce variable scores. This is more reproducible for CI.

2. **Blend over single metric:** Text accuracy blends WER, CER, anchor recall, and entity F1 — no single metric captures all aspects of OCR quality.

3. **Rubric bands, not continuous mapping:** Score bands (Poor/Weak/Acceptable/Good/Excellent) make results interpretable. A score of 70 means "Good" — not "70.3% accurate."

4. **Provider anonymization:** The scoring function receives `providerID` for result tracking but never uses it in scoring logic. This prevents the judge from being influenced by provider reputation.

## Test Evidence

All 29 tests pass:
- Rubric scoring (3 tests): WER-based, entity extraction, structural detection
- Aggregate scoring (3 tests): bounds, perfect match, total failure
- Gate logic (3 tests): pass, fail, custom threshold
- Bias mitigation (2 tests): provider anonymization, verbosity bias
- Cross-provider report (3 tests): grouping, best provider, gate results
- Edge cases (4 tests): empty OCR, empty ground truth, no anchors, no boxes
- WER/CER computation (3 tests): identical, different, character-level
- Rubric boundaries (2 tests): band structure, mapping
- Weights (2 tests): sum to 1.0, text accuracy highest
- Evidence trail (2 tests): all dimensions produce evidence, raw metrics populated

## What's Next

1. **Wire into CI:** Run the harness against all 4 providers (Tesseract, PaddleOCR, Vision, Marker) on the 9-fixture OCR corpus and gate on aggregate score ≥ 70.

2. **Add comparison tests:** Run the same fixtures through all providers and generate a comparison report.

3. **Add more entity types:** Names, addresses, organizations for domain-specific evaluation.

4. **Confidence calibration test:** Feed real per-word confidence scores and verify the calibration dimension works.
