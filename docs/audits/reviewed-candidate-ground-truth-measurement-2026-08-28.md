# Reviewed Candidate Ground Truth & Detector Semantic Measurement

**Date:** 2026-08-28
**Status:** Implemented, tested (19 tests), full suite 1294/1294 pass
**Doctrine:** §2 Truth taxonomy, §5 Evidence-based, §12 Privacy

## 1. Outcome

Measure native vs browser detector precision, recall, abstention, and
label-association agreement against **reviewed** candidate ground truth across
the PDF corpus — not against provider candidates (which are never ground truth).

## 2. What was built

### `Sources/PDFEditorCore/ReviewedCandidateGroundTruth.swift` (297 lines)
- `ReviewedGroundTruthCase` — reviewed region expectation: class, expected
  state (detected/abstain), hard-negative flag, target rect, required evidence
  kinds, expected evidence families, expected label association, grouping
  state, false-positive severity, **provenance**.
- `ReviewedCandidateGroundTruth.canonical()` — 15 cases across 6 fixtures:
  - **10 human-reviewed** detector-calibration regions (mirrors
    `benchmark/results/detector-calibration/detector_calibration_labels.json`
    v1.0, source SHA-256 `5d50d759…b83d6f`, provenance `human-reviewed`).
  - **5 generator-derived** corpus-sweep structural expectations (provenance
    `generator-manifest`), all hard negatives asserting non-detection on
    plain-text / multi-column / navigation / signed / XFA fixtures.

### `Sources/PDFEditorCore/DetectorSemanticMeasurement.swift` (639 lines)
- `DetectorCandidate` normalization from native `RegionCandidate` and from
  browser JSON — **candidate IDs, text, scores, and digests are excluded**
  (privacy: report carries region identities, never document content).
- Full mirror of `web/detector-semantic-comparison.mjs` v1.0 contract:
  - matching: minimumIoU 0.25, nearIoU 0.05, geometryTolerancePoints 0.5
  - strategy: reviewed-region-first-score-with-one-selected-candidate
  - severity weights: low 1, medium 3, high 9, critical 27
- Per-case evaluation: detection state, evidence-family agreement (Jaccard
  F1), label-association agreement, grouping agreement, severity burden.
- Lane metrics: precision, recall, abstention, labelAssociationPrecision,
  evidenceFamilyAgreement, groupingAgreement, severityBurden, pass/fail.
- Native/browser parity report: per-region mismatch kinds.
- Markdown export (content-free by construction).

### `Tests/PDFEditorCoreTests/DetectorSemanticMeasurementTests.swift` (352 lines, 19 tests)
- Ground truth integrity: 15 cases / 6 fixtures, 5 positives, 10 hard
  negatives, provenance split, unique reviewed region IDs.
- Perfect-lane metrics: precision 1, recall 1, abstention 1, label 1, pass.
- S3 mutations: missing positive drops recall; promoted hard negative drops
  precision/abstention with severity burden 3; high-severity burden 9; wrong
  page index kills match; shifted bounds below minimum IoU kills match;
  evidence-removal degrades agreement.
- Parity: identical lanes → zero mismatches; divergence surfaces.
- Browser JSON decoding from the contract shape; markdown export content-free.

## 3. Bug found and fixed (Observed → Verified)

The Swift mirror of `requiredEvidenceFamilies` / `minimumEvidenceFamilies` /
browser candidate evidence mapping **dropped** evidence kinds not in
`EVIDENCE_FAMILY_BY_KIND` (`label`, `relationship`, …) instead of applying the
mjs identity fallback `EVIDENCE_FAMILY_BY_KIND[kind] || kind`.

- Symptom: `p0-whitespace` (expected `["whitespace","label","relationship"]`)
  reported agreement against `["whitespace"]` only → evidence-family agreement
  0.8 on a perfect lane.
- Root cause: Swift `family(forKind:)` returns `nil` for unknown kinds and the
  empty-check fallback silently discarded them.
- Fix: identity fallback `family(forKind:) ?? kind` in all three mapping sites.
- Verified: perfect lane now yields evidenceFamilyAgreement 1.0; all 19 tests
  pass; full suite 1294/1294.

## 4. Evidence

- 19 targeted tests pass (`DetectorSemanticMeasurementTests`).
- Full suite: **1294/1294** tests in 123 suites pass.
- Ground truth provenance: human-reviewed labels JSON (SHA-256
  `5d50d759273ea20f43beecbc97737cf7053e0cf61ce643bb802e3b9b29b83d6f`) +
  generator-manifest structural expectations.

## 5. Alternatives not taken

- **Provider candidates as ground truth** — rejected: violates the first
  principle that providers are never truth (documented in both files).
- **Content-bearing report** — rejected: privacy doctrine; report carries
  region identities and metrics only.
- **Single-fixture scope** — rejected: the mjs comparison already covered one
  fixture; this extends corpus-wide with provenance labeling.

## 6. Open questions / next steps

- Wire `DetectorSemanticMeasurement` into the native candidate pipeline as a
  CI gate (report on every corpus run).
- Extend corpus-sweep ground truth with *positive* expectations on form
  fixtures (currently all hard negatives).
- Human review pass over generator-manifest cases to upgrade provenance.