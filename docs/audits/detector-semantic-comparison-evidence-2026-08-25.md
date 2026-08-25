# Reviewed Detector Semantic Comparison Evidence

**Date:** 2026-08-25  
**Status:** Controlled reviewed-region comparison implemented and passing;
broader real-document reviewed expansion remains active long-term work  
**Scope:** reviewed region identity, candidate precision and recall,
abstention, evidence-family agreement, label association, grouping behavior,
and false-positive severity

## Why this phase exists

The existing 18-fixture native/browser semantic parity report records provider
divergence across page boxes, text counts, AcroForm metadata, candidates,
validation applicability, encrypted writer capability, accessibility, and
security summaries. Those 78 mismatches are useful diagnostic evidence, but a
provider-level mismatch is not automatically a detector failure.

This phase adds the missing reviewed-ground-truth join. It asks whether a
provider difference changes a reviewed region’s identity, detection state,
abstention decision, evidence-family set, label relationship, grouping, or
false-positive risk.

The implementation is separate from the whole-document parity comparator and
the provider-only candidate parity report. It does not treat either native
PDFKit or browser PDF.js as ground truth for the unreviewed 18-fixture
candidate population.

## Versioned reviewed fixture

The existing source-bound calibration fixture is extended with explicit
review metadata in
[`benchmark/results/detector-calibration/detector_calibration_labels.json`](../../benchmark/results/detector-calibration/detector_calibration_labels.json):

- `reviewedRegionID` is stable across provider runs and candidate IDs;
- `expectedEvidenceFamilies` records the complete expected semantic evidence;
- `expectedLabelAssociation` records whether a field-intent label is expected;
- `expectedGrouping` records single-region or grouped behavior;
- `falsePositiveSeverity` records the consequence of promoting each negative.

The fixture contains 10 reviewed regions:

| Class | Positive | Hard negative | Severity coverage |
| --- | ---: | ---: | --- |
| vector rectangle | 1 | 1 | medium |
| checkbox | 1 | 1 | high |
| underline | 1 | 1 | low |
| whitespace | 1 | 1 | medium |
| label association | 1 | 1 | high |

The source fixture remains the same two-page, privacy-safe PDF with SHA-256:

`5d50d759273ea20f43beecbc97737cf7053e0cf61ce643bb802e3b9b29b83d6f`

No personal labels, screenshots, profile values, or source PDF bytes are
copied into the semantic comparison report.

## Comparison contract

The normalized comparison is implemented in
[`web/detector-semantic-comparison.mjs`](../../web/detector-semantic-comparison.mjs)
under `pdf-editor.detector-semantic-comparison` version `1.0`.

### Reviewed region identity

Region identity is the reviewed sidecar identity, not a provider candidate ID.
Candidate selection requires the reviewed page, minimum IoU `0.25`, minimum
recognition evidence, optional candidate kind, and optional field type. The
full evidence-family set is then compared separately.

This distinguishes:

- no candidate near a reviewed region;
- a candidate with insufficient recognition evidence;
- a candidate recognized but missing expected evidence;
- a candidate with label or grouping divergence;
- a provider-only candidate with no reviewed identity.

### Candidate precision and recall

The metrics are region-level, not candidate-count-level:

- true positive: reviewed positive detected;
- false negative: reviewed positive missed or abstained;
- false positive: reviewed hard negative promoted;
- true negative: reviewed hard negative correctly abstained;
- precision and recall are computed from those reviewed outcomes.

This avoids rewarding a provider for producing many unreviewed candidates.

### Abstention behavior

The report exposes:

- `correctAbstentionRate` for reviewed hard negatives;
- `positiveAbstentionRate` for reviewed positives that were missed;
- explicit `detected` and `state` per reviewed region;
- failure clusters for reviewed-region misses and false-positive promotion.

Abstention remains a valid result. It is not converted into a negative
accuracy score when the reviewed case expects the detector to remain silent.

### Evidence-family agreement

Provider-specific evidence kinds are mapped to semantic families:

| Provider evidence kinds | Semantic family |
| --- | --- |
| `vectorRectangle`, `vectorLine`, native `underline`, `checkboxShape` | geometry |
| `whitespace` | whitespace |
| `textLabel` | label |
| `spatialRelationship` | relationship |
| `ocrText`, `ocrBounds` | OCR |
| `nativeField` | native-field |

The report retains expected, actual, missing, unexpected, intersection,
precision, recall, and exact agreement. It does not retain evidence IDs,
extracted text, summaries, or prose.

The distinction between minimum evidence and expected evidence is deliberate.
For example, geometry may be sufficient to recognize a candidate, while the
reviewed expectation still requires geometry plus label plus spatial
relationship evidence for a safe suggestion.

### Label association

Label association is compared as the semantic state `associated` or `none`.
Presence of label or relationship evidence counts as association in the
normalized projection. The report does not expose the label string.

### Grouping behavior

Grouping is compared using semantic state and member count:

- `single`, member count 1;
- `grouped`, member count greater than 1;
- `abstain`, no candidate accepted for the reviewed negative.

The current controlled fixture uses single reviewed regions. Grouped repeated
cell and radio-group labels are a required next corpus expansion, not inferred
from provider agreement.

### False-positive severity

Severity weights are versioned in the contract:

| Severity | Weight |
| --- | ---: |
| low | 1 |
| medium | 3 |
| high | 9 |
| critical | 27 |

The report retains severity counts and weighted burden. A zero false-positive
rate and zero severity burden are required for the controlled gate.

## Current result

Machine report:

[`benchmark/results/detector-calibration/detector-semantic-comparison-report.json`](../../benchmark/results/detector-calibration/detector-semantic-comparison-report.json)

| Measure | Native PDFKit | Browser PDF.js |
| --- | ---: | ---: |
| Reviewed regions | 10 | 10 |
| Precision | 1.00 | 1.00 |
| Recall | 1.00 | 1.00 |
| Correct hard-negative abstention | 1.00 | 1.00 |
| Positive abstention | 0.00 | 0.00 |
| Evidence-family exact agreement | 1.00 | 1.00 |
| Label-association agreement | 1.00 | 1.00 |
| Grouping agreement | 1.00 | 1.00 |
| False positives | 0 | 0 |
| Severity burden | 0 | 0 |
| Native/browser reviewed-region mismatches | 0 | 0 |

This is a controlled regression result, not a universal detector accuracy
claim. The broader 18-fixture candidate parity report remains diagnostic and
retains its provider divergences, including the previously recorded 78
semantic mismatches. The reviewed report establishes that those divergences do
not alter the current reviewed calibration fixture’s safe detector outcomes.

## Mutation evidence

Runner:

[`Tests/detector_semantic_comparison_test.mjs`](../../Tests/detector_semantic_comparison_test.mjs)

The test rebuilds the report from mutated candidate inputs, rather than editing
the output report after calculation:

| Mutation | Killed | Failure cluster |
| --- | --- | --- |
| Remove the reviewed positive region | Yes | `reviewedRegionMiss` |
| Promote a high-severity hard negative | Yes | `falsePositive` |
| Strip expected evidence families | Yes | `evidenceFamilyMismatch` |
| Break label association | Yes | `labelAssociationMismatch` |
| Split a single reviewed group | Yes | `groupingMismatch` |

This ensures each safety dimension has an independent bypass test. A failure
cannot disappear into an aggregate precision number.

## Privacy and source boundaries

The report contains reviewed IDs, semantic classes, page-space bounds, field
types, entry modes, grouping counts, evidence family names, states, metrics,
and the source digest used for binding. It excludes:

- provider candidate IDs;
- evidence IDs;
- label text;
- evidence summaries and prose;
- profile values;
- PDF bytes;
- timestamps and output digests.

The detector remains review-only. This comparison creates no EditOperation,
does not approve a candidate, does not fill a field, and does not mutate the
source PDF.

## Verification

Command:

```text
PDF_CALIBRATION_BASE_URL=http://127.0.0.1:4174/web/index.html \
  node Tests/detector_semantic_comparison_test.mjs
```

Result:

```text
10 reviewed regions
native precision/recall: 1.00/1.00
browser precision/recall: 1.00/1.00
five declared mutations killed by distinct clusters
native/browser reviewed-region parity: 0 mismatches
```

The native harness and browser fixture consumed the same source digest. The
temporary local server was stopped after verification.

## Remaining implementation work

- Add reviewed identities for the existing Form 6 and rotated Form 6
  candidates, including explicit split/merge adjudication.
- Add grouped repeated-cell, radio-group, signature-region, table, and
  multi-column reviewed labels.
- Add scanned, OCR-only, multilingual, handwriting, clipped-path, malformed,
  and mixed-content reviewed regions.
- Calibrate severity with reviewer agreement and workflow consequence data,
  not only engineering judgment.
- Join this report to the broader 18-fixture mismatch ledger so every
  provider mismatch receives a reviewed impact classification.

