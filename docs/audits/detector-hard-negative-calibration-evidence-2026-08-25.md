# Detector Hard-Negative Calibration Evidence

**Date:** 2026-08-25  
**Status:** Implemented synthetic calibration, native/browser semantic parity, overall metrics, failure clusters, and mutation gates; real-document expansion remains active long-term work
**Scope:** Vector rectangles, checkbox-shaped geometry, underlines, whitespace regions, and label association

## Purpose

The static detector must make difficult PDF completion easier without turning
ordinary layout geometry into an edit. This evidence pass creates a small,
privacy-safe, source-bound calibration PDF with reviewed positive labels and
explicit hard negatives. Both the macOS PDFKit adapter and browser PDF.js
adapter consume the same bytes and are evaluated against the same labels.

The fixture is not a production accuracy claim. It is a regression oracle for
the semantic gates that decide when geometry becomes a reviewable candidate.

## Fixture and labels

- PDF generator: [`benchmark/generate_detector_calibration_fixture.py`](../../benchmark/generate_detector_calibration_fixture.py)
- PDF: [`benchmark/results/detector-calibration/detector-calibration.pdf`](../../benchmark/results/detector-calibration/detector-calibration.pdf)
- Labels: [`benchmark/results/detector-calibration/detector_calibration_labels.json`](../../benchmark/results/detector-calibration/detector_calibration_labels.json)
- Manifest: [`docs/fixtures/detector-calibration-manifest.md`](../fixtures/detector-calibration-manifest.md)
- Rendered visual check: two pages rendered with `pdftoppm` and inspected during this pass

The source SHA-256 is:

`5d50d759273ea20f43beecbc97737cf7053e0cf61ce643bb802e3b9b29b83d6f`

The calibration report envelope is version `1.1`. This revision adds overall
metrics, the `metrics.byClass` namespace, near-target diagnostics, and
failure-cluster records while retaining the same fixture, label policy, and
source digest.

Page 1 contains five positive cases: a labeled vector rectangle, a labeled
small checkbox, a labeled underline, a text-only whitespace region, and
explainable label-association evidence. Page 2 contains five hard negatives: a
generic Section rectangle, an isolated square, a bare rule, a Note rectangle,
and generic Section whitespace.

The label sidecar retains target page-space rectangles, expected state,
required evidence kinds, rationale, and hard-negative status. It contains no
personal content, profile values, signatures, screenshots, or network
identifiers.

The acceptance IoU is `0.25`. The report also calculates a diagnostic
near-target neighborhood at IoU `0.05`. That lower neighborhood is not an
acceptance threshold. It exists to classify a miss as absent, evidence-wrong,
kind-wrong, field-type-wrong, or geometry-wrong.

## Detector policy implemented

Both adapters now use the same semantic label vocabulary for association. A
nearby string is not enough. It must contain a field-intent token such as
name, address, date, agreement, signature, account, or identifier. Generic
layout words such as Section and Note remain text evidence but do not promote
geometry to a candidate.

The shared rules are:

- unlabeled isolated squares abstain;
- labeled small squares can be reviewed as checkboxes;
- unlabeled large rectangles abstain;
- unlabeled horizontal rules abstain;
- grouped character cells require a semantically plausible label;
- whitespace suggestions require a semantically plausible label;
- label association emits both `textLabel` and `spatialRelationship` evidence;
- browser vector lines normalize to the shared `underline` evidence kind;
- native PDFKit text extraction uses `selection(...).selectionsByLine()` bounds,
  avoiding the previous evenly spaced approximation that could associate a
  label with the wrong shape;
- text-anchored whitespace scores are aligned between adapters as evidence
  strength, not as calibrated probability.

Every suggestion remains review-gated. The detector does not create a native
AcroForm field, apply a value, or silently modify the source.

## Native/browser result

Machine report:

[`benchmark/results/detector-calibration/detector-calibration-report.json`](../../benchmark/results/detector-calibration/detector-calibration-report.json)

The live command was `node Tests/detector_calibration_parity_test.mjs`. The
browser run used an isolated local server on port 4174 because port 4173 was
owned by another local project. The harness verified the PDF.js, pdf-lib, and
fixture globals before collecting browser evidence.

| Adapter | Precision | Recall | Hard-negative false-positive rate | Hard-negative abstention | Semantic parity |
|---|---:|---:|---:|---:|---|
| Native PDFKit | 5/5 (1.00) | 5/5 (1.00) | 0/5 (0.00) | 5/5 (1.00) | Pass |
| Browser PDF.js | 5/5 (1.00) | 5/5 (1.00) | 0/5 (0.00) | 5/5 (1.00) | Pass |

The browser result is therefore precision `1.00`, recall `1.00`, hard-negative
false-positive rate `0.00`, and hard-negative abstention `1.00` on this
controlled set. The same values hold for native PDFKit. The machine report
also retains per-class values and observed positive score floors: checkbox
`0.85`, vector rectangle `0.80`, underline `0.75`, whitespace `0.58`, and
label association `0.80`. These scores are evidence-strength observations,
not probabilities or automatic-acceptance thresholds.

### Failure clusters

The real browser and native runs contain zero failures:

| Adapter | Failure count | Failure clusters |
|---|---:|---|
| Native PDFKit | 0 | None observed |
| Browser PDF.js | 0 | None observed |

The calibration runner proves that the cluster taxonomy is live by applying
three in-memory mutations to the browser candidate set:

| Mutation | Expected cluster | Killed by gate |
|---|---|---|
| Remove the complete near-target neighborhood for a reviewed positive | `noCandidateNearTarget` | Yes |
| Copy a valid positive candidate onto a reviewed hard negative | `hardNegativePromotion` | Yes |
| Remove required evidence from the complete near-target neighborhood | `evidenceMismatch` | Yes |

Additional clusters are implemented for `candidateKindMismatch`,
`fieldTypeMismatch`, and `geometryMismatch`. They are currently zero-count,
not untested concepts: the classifier records nearby candidate counts and the
failed semantic gate without retaining document text or field values.

Class-specific minimum observed suggestion scores are:

| Class | Native | Browser |
|---|---:|---:|
| Checkbox | 0.85 | 0.85 |
| Vector rectangle | 0.80 | 0.80 |
| Underline | 0.75 | 0.75 |
| Whitespace | 0.58 | 0.58 |
| Label association | 0.80 | 0.80 |

These are lower bounds observed on this reviewed fixture. They are not
probabilities and are not permission to auto-accept candidates. The report
uses a zero hard-negative false-positive gate and full positive recall because
this fixture is a controlled contract regression set.

## Verification and limitations

- Python fixture generation and exact source digest binding passed.
- Native `PDFContractHarness` inspected the fixture successfully.
- Browser PDF.js opened the same source digest successfully.
- JavaScript syntax checks passed for the detector, calibration module, and
  parity runner.
- Native and browser calibration passed with no semantic mismatches.
- Overall precision and recall passed at `1.00` for both adapters; hard-negative
  false-positive rate was `0.00` and abstention was `1.00`.
- Mutation checks killed positive removal, hard-negative promotion, and
  required-evidence stripping, with the expected failure clusters.
- Both pages were rendered with `pdftoppm` and visually inspected.

This does not prove generalization to arbitrary PDFs. Rotated transforms,
clipped paths, filled versus stroked rectangles, dashed rules, table borders,
nested forms, right-to-left or multilingual labels, handwriting, OCR-only
labels, transparency, annotation widgets, malformed streams, and multi-column
reading order remain active corpus expansion work on the same evidence ledger.
The separate 33-target Form 6 benchmark remains a semantic-recall and
candidate-precision proxy, not a geometry metric, and is not merged into this
10-case exact-label score.
