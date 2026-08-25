# Multi-signal evidence fusion evidence

**Date:** 2026-08-25  
**Status:** Implemented deterministic fusion core; corpus calibration and provider-wide promotion remain active gates  
**Asset:** MA-003, multi-signal evidence graph  
**Privacy class:** derived geometry, confidence, provider identity, and reason codes only

## What changed

The native and browser detectors now emit an optional `fusion` result on each
static `RegionCandidate`. The result is derived from the existing typed
`CandidateEvidence` items. It does not add a second candidate model, copy raw
page text, or create an edit operation.

Native implementation:

- [`Sources/PDFEditorCore/EvidenceFusion.swift`](../../Sources/PDFEditorCore/EvidenceFusion.swift)
- [`Sources/PDFEditorCore/DocumentModel.swift`](../../Sources/PDFEditorCore/DocumentModel.swift)

Browser implementation:

- [`web/pdf-evidence-fusion.mjs`](../../web/pdf-evidence-fusion.mjs)
- [`web/pdf-geometry-detector.mjs`](../../web/pdf-geometry-detector.mjs)

The same policy is used on both sides. Semantic evidence has the strongest
weight, geometry and language evidence have intermediate weights, and
relationship or whitespace evidence is weaker until independently confirmed.
The final score combines weighted support, independent evidence-family
coverage, and pairwise region agreement.

Two high-confidence signals with non-overlapping regions produce an abstention,
even when their individual scores are high. A single OCR or whitespace signal
remains review-only at the declared thresholds. No score is a silent approval.

## Contract output

The optional result contains only:

- `state`: `supported`, `review`, or `abstain`;
- aggregate scores rounded to six decimal places;
- sorted evidence IDs;
- independent evidence groups;
- conflict boolean;
- sorted reason codes.

The current reason codes include `noEvidence`, `singleEvidenceFamily`,
`independentEvidenceAgreement`, `lowGeometricAgreement`,
`conflictingHighConfidenceEvidence`, and `lowSupport`.

## Fixture and tests

The versioned, metadata-only cases are in
[`Tests/fixtures/evidence_fusion_cases.json`](../../Tests/fixtures/evidence_fusion_cases.json):

1. aligned native, vector, and label evidence is supported;
2. OCR-only evidence requires review;
3. low-confidence whitespace abstains;
4. conflicting high-confidence regions abstain;
5. empty evidence abstains.

The browser test is [`Tests/evidence_fusion_test.mjs`](../../Tests/evidence_fusion_test.mjs).
The native tests are [`Tests/PDFEditorCoreTests/EvidenceFusionTests.swift`](../../Tests/PDFEditorCoreTests/EvidenceFusionTests.swift).

Evidence recorded in this pass:

- browser: 5/5 deterministic cases passed;
- native: 4/4 focused XCTest cases passed;
- moat registry: 14/14 assets resolved and zero-content checks passed;
- browser contract fixture: 18/18 governed corpus records emitted;
- reviewed static-region browser benchmark: 33 target regions, 100 labeled
  candidates, label recall `0.1818`, precision proxy `0.11`, with the metric
  explicitly documented as not geometric IoU.

## What this proves and does not prove

This proves that native and browser candidate objects can carry the same
deterministic evidence-decision shape and that conflict abstention is executable
on both adapters. It does not prove that the detector is accurate on every PDF
class, that OCR text is correct, or that a supported fusion state should be
auto-applied. Those claims require reviewed labels, hard negatives, held-out
versions, language coverage, and independent provider measurements.

The asset remains `partial` until:

- the same real-PDF candidate set is extracted through native and browser
  providers and compared at evidence-ID and geometry level;
- thresholds are calibrated per governed document class with held-out cases;
- OCR and companion evidence are admitted only through the capability registry;
- correction, rollback, provider crash, and recovery metrics include fusion
  states; and
- content-bearing evidence retention is explicitly selected per corpus item.

The original mismatch and abstention records remain append-only. This layer
does not authorize silent autofill, profile-value storage, source mutation, or
deletion of hard negatives.
