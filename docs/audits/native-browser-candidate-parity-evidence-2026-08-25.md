# Native versus browser semantic candidate parity evidence

- Date: 2026-08-25
- Status: Measured across the current 18-fixture corpus; candidate divergence remains an active implementation finding
- Native adapter: `PDFContractHarness` using PDFKit and the native static-region detector
- Browser adapter: PDF.js browser contract fixture and browser geometry detector
- Corpus: [`docs/fixtures/manifest.md`](../fixtures/manifest.md)
- Report: [`benchmark/results/semantic-parity/2026-08-25/candidate-parity-report.json`](../../benchmark/results/semantic-parity/2026-08-25/candidate-parity-report.json)
- Projection: [`web/candidate-parity.mjs`](../../web/candidate-parity.mjs)
- Runner: [`Tests/native_browser_candidate_parity_report_test.mjs`](../../Tests/native_browser_candidate_parity_report_test.mjs)
- Mutation checks: [`Tests/candidate_parity_mutation_test.mjs`](../../Tests/candidate_parity_mutation_test.mjs)

## Purpose

The whole-document parity report already identified candidate-set differences,
but a raw set comparison could not distinguish grouping, classification,
rotation, or provider-only suggestions. This report adds a candidate-specific
projection over the same native and browser bundles.

It measures one-to-one geometry correspondence, directional provider coverage,
symmetric agreement F1, fully equivalent pairs, matched pairs with semantic
differences, native-only candidates, browser-only candidates, and candidate
kind, field type, entry mode, review state, grouping, coordinate, geometry,
and evidence-family differences.

Neither provider is treated as ground truth. A matched candidate can still be
semantically different, and an unmatched candidate remains provider evidence
for future reviewed adjudication.

## Normalization and privacy boundary

The candidate parity contract is version `1.0` in
[`web/candidate-parity.mjs`](../../web/candidate-parity.mjs).

Candidate correspondence requires the same page index and page-space rectangle
IoU of at least `0.80`, followed by one-to-one greedy assignment ordered by
geometry and semantic compatibility. Bounds are considered equal within `0.5`
points after pairing.

The report compares candidate kind, suggested field type, entry mode, evidence
kinds and origins, label presence, review state, fusion state, grouped-member
count, and coordinate unit, origin, page box, and rotation.

It does not retain provider candidate IDs, label text, evidence text, evidence
summaries, score values, provider timestamps, or output digests. It retains
only structural geometry, evidence families, presence flags, and state.

## Fresh corpus result

The underlying whole-corpus runner was refreshed through an isolated local
server on port 4174 because port 4173 belonged to the unrelated
`rigs-unbound` project. The native and browser adapters consumed the same
18-fixture manifest and source digests.

| Measure | Result |
|---|---:|
| Manifest fixtures | 18 |
| Expected malformed failures | 2 |
| Native candidate count | 206 |
| Browser candidate count | 140 |
| Geometry pairs | 118 |
| Native-only candidates | 88 |
| Browser-only candidates | 22 |
| Native candidate set covered by browser pairs | 57.28% |
| Browser candidate set covered by native pairs | 84.29% |
| Symmetric agreement F1 | 68.21% |
| Fully equivalent pairs | 49/118, 41.53% |
| Matched pairs with semantic differences | 69 |

Aggregate mismatch clusters:

| Cluster | Count |
|---|---:|
| Coordinate-space mismatch | 59 |
| Field-type mismatch | 18 |
| Entry-mode mismatch | 14 |
| Review-state mismatch | 2 |
| Geometry-precision mismatch | 2 |
| Grouping mismatch | 2 |

These are provider-divergence observations, not product accuracy scores.

## Candidate-bearing fixtures

Only the two Form 6-derived fixtures currently emit static candidates in both
adapters. The other 16 fixtures remain important because they prove empty
candidate sets and explicit malformed failure behavior, but they do not yet
exercise candidate correspondence.

| Fixture | Native | Browser | Matched | Native-only | Browser-only | Agreement F1 | Equivalent pairs |
|---|---:|---:|---:|---:|---:|---:|---:|
| `docs/benchmarks/pdfkit-form6-run-2026-08-23/noop.pdf` | 103 | 70 | 59 | 44 | 11 | 68.2% | 49/59 |
| `benchmark/results/rotation-corpus/rotated-form6-mixed.pdf` | 103 | 70 | 59 | 44 | 11 | 68.2% | 0/59 |

The normal Form 6 fixture has semantic differences in field type, entry mode,
review state, geometry precision, and grouping. The rotated derivative has the
same additional differences plus coordinate-space divergence for all 59
paired candidates, which prevents any pair from being fully equivalent.

## Interpretation

The report establishes that source identity and candidate correspondence are
different layers:

1. Source binding is intact across the readable corpus.
2. Candidate geometry overlaps enough to form 118 explicit pairs.
3. Candidate semantics still diverge substantially between native and browser.
4. Rotation coordinate normalization is a distinct high-volume mismatch.
5. Provider-only candidates remain visible rather than being discarded.

The report does not authorize treating either detector as correct. It also
does not replace the reviewed hard-negative calibration report, because this
corpus projection has no independent reviewed target labels for the 206 and
140 provider candidates.

## Mutation and privacy verification

```text
node Tests/candidate_parity_mutation_test.mjs
candidate parity mutation checks: 5 passed

node Tests/native_browser_candidate_parity_report_test.mjs
18 fixtures; source binding, candidate coverage, mismatch classification, and
value-minimized artifact checks passed
```

The mutation checks prove that provider IDs and label/evidence prose changes
do not alter semantic equality, while candidate-kind changes, evidence-kind
changes, and large coordinate drift are reported.

The whole-corpus native/browser parity run also completed with its existing
six declared document-level mismatches and zero unexpected mismatches. Output
digests, provider IDs, timestamps, and diagnostic prose remain outside
semantic equality.

## Remaining implementation work

- Add reviewed candidate ground truth for the existing Form 6 and rotated
  fixtures so provider coverage can be compared with actual precision/recall,
  not only symmetric agreement.
- Reconcile native/browser grouping and field-type taxonomies for repeated
  cells, checkboxes, date regions, radio groups, and signature regions.
- Normalize rotation in the shared coordinate contract without hiding genuine
  provider geometry errors.
- Add candidate-bearing scanned, hybrid, multilingual, OCR-assisted, clipped,
  table, malformed-recovery, and real-world form fixtures.
- Extend pairing to explicit split/merge diagnostics when one provider emits
  one region and the other emits multiple overlapping regions.

This is Tier 2/S1 native plus Tier 3/S1 browser corpus evidence. It is a
semantic comparison and detector-remediation baseline, not universal PDF
fidelity, OCR accuracy, autofill safety, or independent-viewer proof.
