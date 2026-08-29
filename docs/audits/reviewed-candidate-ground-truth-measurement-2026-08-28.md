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

## 7. Addendum — human review pass over corpus fixtures (2026-08-28)

### Finding (Observed, qpdf 12.4 structural inspection)

A human review pass over the five corpus-sweep fixtures **found the
generator-manifest ground truth cases were wrong**. Every fixture is the base
`public-sample-form.pdf` with pages added by
`Tests/fixtures/generate_corpus_sweep.py` — so page 0 of each retains the **6
AcroForm widgets** from the base form:

| Fixture | Pages | Page 0 | Other pages |
|---|---|---|---|
| plain-text.pdf | 3 | 6 widgets | p1, p2: no /Annots |
| multi-column.pdf | 2 | 6 widgets | p1: no /Annots |
| navigation.pdf | 3 | 6 widgets | p1: 3 link annots only; p2: none |
| signed-valid-structure.pdf | 1 | 6 widgets + signature | — |
| xfa-static.pdf | 1 | 6 widgets + XFA packet | — |

Widget rects (identical across fixtures, base form): name `[185.5 705.39
436.5 728.39]` (Tx), notes `[185.5 617.39 436.5 684.39]` (Tx), subscribe
`[185.5 567.39 204.5 586.39]` (Btn), contact ×2 `[185.5 523.39 204.5 542.39]`
/ `[255.5 523.39 274.5 542.39]` (Btn), country `[185.5 477.39 436.5 500.39]`
(Ch).

### Correction

- The 5 document-level "no editable candidates" abstain cases were **replaced**
  with 30 native-field positives (6 widgets × 5 fixtures, page 0,
  `nativeField` evidence family) + 5 page-level abstains for the genuinely
  widget-free added pages.
- All 35 corpus-sweep cases re-labeled `human-reviewed` with a
  `GroundTruthReviewRecord` (reviewer, method, tool, per-fixture findings).
- Corpus now: 45 cases (10 calibration + 35 sweep), 35 positives, 10 hard
  negatives.

### Why the original error happened

The generator-manifest provenance was a proxy for "the generator script says
so" — but the manifest's `expected` facts only record pages/rotations/sizes,
never field presence. The abstain claim was an *inference* from the fixture
name ("plain-text") that the review pass falsified. This is the exact failure
mode §2 Truth taxonomy exists to prevent: expectations must be tied to
observed structure, not names.

### Evidence

- 20 targeted tests pass (perfect lane: precision/recall/abstention/label
  1.0 over 45 cases; S3 mutations still bite).
- Full suite: **1303/1303**.

### Remaining open questions

- Signed-valid-structure and xfa-static are single-page forms — their
  signature/XFA guards are exercised by separate suites; the detector ground
  truth records the 6 fields as detected (the guard lanes own the
  protection semantics).
- The 6 field candidates satisfy all 15 fixtures' identical rects in one lane
  run; a per-fixture runner would duplicate candidates — acceptable for
  measurement, noted for the CI gate design.

## 8. Addendum — positive expectations extended to all 15 form-bearing fixtures (2026-08-28)

### Finding (Observed, qpdf 12.4)

Every corpus-sweep fixture derives from `public-sample-form.pdf`, so **all 15
fixtures** carry the 6 base-form widgets on page 0 — not just the 5 covered
by the first review pass. Verified per fixture: page /Annots arrays and widget
objects (including `xfa-dynamic.pdf`, whose AcroForm tree is empty — dynamic
XFA — but whose 6 widget annotations are present on the page).

### Extension

- Corpus-sweep positives: 30 → **90** (6 widgets × 15 fixtures).
- Abstains: 5 → **8** (added geometry p1 200×2000, p2 612×792 r90, p3 crop
  [36 36 400 700], all verified annot-free).
- Corpus total: 45 → **108** cases (10 calibration + 98 sweep), 95 positives,
  13 hard negatives.
- `reviewRecord.fixtureFindings` extended to all 15 fixtures.

### Evidence

- 21 targeted tests pass (new `formFixturesPositive` asserts 6 native-field
  positives per fixture across all 15).
- Full suite: **1304/1304**.

### Note

The 6 field candidates in the perfect lane satisfy all 90 positives in the
pooled measurement — correct for a lane-level metric, but a per-fixture
runner (CI gate) should scope candidates by fixture to avoid over-counting.

## 9. Addendum — live native-vs-browser corpus report (2026-08-28)

### What was done

Ran **both detector lanes against the real 15-fixture corpus-sweep set** and
produced a live measurement report from actual candidates:

- **Native lane**: `PDFContractHarness` run per fixture via
  `docs/fixtures/corpus-sweep-detector-manifest.md` (15 bundles under
  `benchmark/results/native-browser-corpus/native`).
- **Browser lane**: new Playwright runner `Tests/browser_detector_corpus_report.mjs`
  loads each fixture in the real app, captures the contract snapshot, and feeds
  both lanes through the same mjs v1.0 evaluator the Swift suite mirrors.
- **Artifact** (deterministic, fixed timestamp):
  `benchmark/results/detector-calibration/corpus-native-browser-semantic-parity-2026-08-28.json`
  (schema `pdf-editor.detector-semantic-comparison-corpus`).

### Key finding (Observed): detectors abstain on confirmed fields

Both lanes report **0 candidates on all 15 fixtures** — the detectors do not
re-suggest native AcroForm widgets because they are already resolved fields.
The fields channel (`document.payload.fields`) carries the 6 widgets with exact
rects. The measurement therefore maps the **fields channel to `nativeField`
candidates** (documented in the report `policy` block) — this is the honest
contract: confirmed fields are surfaced as fields, not re-detected.

### Results (Observed, artifact pinned)

- Corpus: **98 cases** (90 positives / 8 abstains), 15/15 fixtures passed,
  per-fixture scoping enabled.
- Native: precision 1.0, recall 1.0, abstention 1.0, e.g. plain-text.pdf
  = 6 TP / 2 correct abstains; zero FPs.
- Browser: identical 1.0/1.0/1.0.
- Parity: zero mismatches; every fixture `sourceDigest` bound to reviewed bytes.
- Determinism: three consecutive runs byte-identical (diff clean).

### Fixes made during the run

1. **mjs gate bug (Observed → Verified):** `buildDetectorSemanticComparisonReport`
   in `web/detector-semantic-comparison.mjs` gated `falsePositiveRate === 0`;
   fixtures with no hard negatives report `null`, and `null === 0` is false,
   so valid fixtures failed the gate. Fixed to treat null (no negatives to
   test) as pass.
2. **Label association (Observed):** field names ARE the label association;
   the runner now maps `field.name` → `labelText` (not a synthetic textLabel
   evidence item, which broke evidence-family exact-match against the
   `["nativeField"]` expectation).

### Pre-existing failures found during verification (not caused by this work)

1. **`browser_network_egression_assertion_test.mjs` — FIXED.** The test filled
   "Egress test value" (17 chars) into a 12-cell character-grid candidate; the
   app correctly rejected it (`value is longer than the detected character
   grid (12 cells)`), so no overlay preview ever appeared and the test timed
   out. The test now prefers a singleText candidate and falls back to a short
   value. Verified: zero external requests during the full workflow.
2. **`pdf_contract_parity_test.mjs` — pre-existing, unchanged numbers.** The
   committed parity report already records 10 unexpected mismatches (native
   fields choice representation, candidate counts 72 vs 56, check-kinds,
   accessibility) — identical before and after this work. Fixed only the
   assert message, which referenced a nonexistent `report.unexpectedMismatches`
   and crashed with a TypeError instead of printing the mismatches.
3. **Port 4173 hijack (Observed):** an unrelated dev server ("Rigs Unbound")
   listens on 4173, the hard-coded fallback base URL of several tests, making
   them fail standalone. The e2e runner avoids this by serving on a free port
   and exporting `PDF_EDITOR_BASE_URL`; tests run green under it
   (`web_character_grid_workflow_test`, `static_region_reviewed_benchmark_browser_test`
   verified). Consider removing the 4173 fallback default.

### Evidence

- 21 Swift measurement tests + new `GroundTruthExportTests` (mjs-compatible
  ground-truth export) all pass; full suite **1305/1305**.
- `node Tests/browser_detector_corpus_report.mjs` — 15/15 fixtures pass, both
  lanes 1.0, deterministic across runs.
- `detector_semantic_comparison_test.mjs`, `native_browser_semantic_parity_report_test.mjs`,
  `native_browser_fingerprint_parity_test.mjs` — pass.
- `run-web-e2e.mjs` — all browser suites pass except `pdf_contract_parity_test`
  (pre-existing, see above).

### Open questions

- Per-fixture candidate scoping for the CI gate (the pooled lane metric
  over-counts when one candidate satisfies many identical fixtures).
- Whether the fields-channel mapping should become a first-class contract
  envelope (fields as evidence-free candidates) vs. the runner-side mapping
  used here.
## §10 Addendum — The automated detector gate (2026-08-28)

`NativeDetectorGate` (Sources/PDFEditorCore/DetectorGate.swift) wires
`DetectorSemanticMeasurement` into the native candidate pipeline as an
automated gate: it runs the live `PDFProvider.inspect` output (candidates +
fields channel) over the real corpus fixtures, measures each fixture against
its own reviewed ground truth, and fails the pipeline on any regression.

### Design (first principles)

- **Live truth, not synthetic lanes.** The gate measures what the pipeline
  actually produces. The mutation tests are the only synthetic lanes, and
  their purpose is to prove the gate *can* fail (S3 discipline).
- **Per-fixture scoping** — resolves the open question from §9: each fixture
  is measured against its own reviewed cases, so a regression is attributed
  to the fixture that caused it, and the pooled over-count artifact
  (one candidate satisfying many identical fixtures) is avoided by
  construction.
- **Fail closed.** A fixture with no reviewed ground truth cannot pass the
  gate. Adding a new corpus fixture requires a human review pass before it
  can go green — the gate cannot be silently widened.
- **Inspection failure = gate failure**, recorded per fixture with the
  full report persisted before the non-zero exit.
- **Privacy (§12).** The report carries region identities, digests, and
  metrics only; verified by test that no `labelText` or field value enters
  the serialized artifact.

### Wiring

1. **Harness flag** — `PDFContractHarness --detector-gate` (with the
   sweep manifest) runs the gate after the parity bundles, persists
   `detector-gate-report.json` (schema `pdf-editor.detector-gate` v1.0) next
   to `summary.json`, and exits **1** with a per-fixture failure summary on
   regression (explicit `exit(1)`, not a thrown-error trap).
   ```
   swift run PDFContractHarness --manifest docs/fixtures/corpus-sweep-detector-manifest.md \
     --output-dir benchmark/results/detector-calibration/native-corpus --detector-gate
   ```
2. **CI Gate 1 (swift test)** — `NativeDetectorGateTests.liveCorpusGatePasses`
   re-runs the live measurement on every push: corpus rewrites that regress
   detection fail CI.

### Evidence

- **1312/1312 Swift tests pass**, including 7 new gate tests:
  live corpus 15/15 (98 reviewed cases, all metrics 1.0, severity burden 0);
  dropped-field regression fails the gate attributed to its fixture
  (recall 5/6, other 14 fixtures stay green); unreviewed fixture fails
  closed; inspection failure recorded; fields-channel mapping mirrors the
  mjs contract; report round-trips and is content-free.
- Live harness runs: pass path `15/15 fixtures passed` exit 0; negative
  path (unreviewed base form) `0/1` exit 1 with persisted report.
- First live report artifact: `benchmark/results/detector-calibration/native-corpus/detector-gate-report.json`.
