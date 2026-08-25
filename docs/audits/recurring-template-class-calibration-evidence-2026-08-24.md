# Recurring PDF Template Corpus and Class Calibration

Date: 2026-08-24  
Evidence level: Tier 2/S1 value-free structural benchmark, with Tier 3/S1 browser fingerprint smoke coverage  
Status: calibration artifact complete; production automatic family acceptance remains disabled

## Result

The project now has a reviewer-labeled, value-free recurring-template benchmark
covering six document classes and 24 explicit decisions:

| Expected decision | Cases | Selection rule |
|---|---:|---|
| `exact` | 2 | Select only after an exact source digest match |
| `knownVariant` | 2 | Select a reviewed keyed-layout variant, while retaining value review |
| `familyMatch` | 6 | Select only as a reviewed proposal after the class threshold is met |
| `ambiguous` | 6 | Never select when the top candidates are within the class ambiguity margin |
| `stale` | 1 | Refuse replay before ranking when the expected source digest differs |
| `noMatch` | 7 | Never select; this is the false-positive gate |

The benchmark passes with the global fallback policy and with the calibrated
class-policy map. A weakened-policy mutation that sets family thresholds to zero
and removes the ambiguity margin fails on hard negatives and unsafe ambiguous
selections. This proves that the benchmark can detect the safety regression it is
intended to catch.

This is not a claim of production recall or precision. Most family-positive and
ambiguous examples are controlled, value-free structural perturbations of known
local fixtures. The source paths are real corpus artifacts, but recurring-version
provenance and independent reviewer agreement are not yet established for every
case. The next calibration release must add genuinely recurring source versions
and a second reviewer or an explicitly recorded single-reviewer exception.

## Corpus inventory

The fixture ledger is
[`Tests/fixtures/template_matching_reviewed_fixtures.mjs`](../../Tests/fixtures/template_matching_reviewed_fixtures.mjs).
The checked-in machine-readable snapshot is
[`benchmark/results/template-matching/2026-08-24-class-calibration.json`](../../benchmark/results/template-matching/2026-08-24-class-calibration.json).
Every case contains:

- `documentClass`, so thresholds are not silently shared across unlike inputs.
- `source`, identifying the local fixture or corpus family used for review.
- `review`, a concise human-readable decision record.
- `reviewLabel`, containing the decision, curator identity, date, evidence basis,
  and the explicit fact that independent agreement has not been measured.
- value-free keyed tokens, page geometry, rotation, native field kind sequences,
  anchor tokens, and region signatures.
- expected state, selected template identity when selection is allowed, and
  forbidden states or mandatory abstention where appropriate.

The currently represented classes are:

| Document class | Local corpus representatives | Cases | Family evidence | Policy result |
|---|---|---:|---|---|
| `publicAcroForm` | public sample AcroForm and its no-op variant | 6 | 1 positive, 1 hard negative, 1 ambiguous | calibrated, review-only |
| `staticPrintedForm` | Form 6 static output and controlled printed-form variants | 6 | 2 positives, 2 hard negatives, 2 ambiguous | calibrated, review-only |
| `nativeWidget` | local synthetic widget fixture | 3 | 1 positive, 1 hard negative, 1 ambiguous | calibrated, review-only |
| `rotatedStaticForm` | mixed-rotation Form 6 fixture | 3 | 1 positive, 1 hard negative, 1 ambiguous | calibrated, review-only |
| `rotatedNativeWidget` | 90-degree rotated widget fixture | 3 | 1 positive, 1 hard negative, 1 ambiguous | calibrated, review-only |
| `scannedDocument` | OCR printed scan and an unrelated security-corpus shape | 3 | no family positive, 1 hard negative; exact and known variant covered | family matching disabled |

The source paths are also recorded in
`REVIEWED_TEMPLATE_BENCHMARK_METADATA.corpus`. The fixture manifest remains the
authority for file hashes and acquisition caveats. No PDF bytes are copied into
the template records.

## Review labels and privacy boundary

The benchmark uses one named role, `corpus-curator`, rather than claiming a
multi-reviewer agreement that was not measured. The label is deliberately
explicit about this:

```json
{
  "decision": "hard-negative",
  "reviewer": "corpus-curator",
  "reviewedAt": "2026-08-24",
  "evidence": "incompatible field, anchor, region, or page evidence",
  "independentAgreement": "not-measured"
}
```

The record contains no raw field labels, profile values, signatures, screenshots,
source bytes, or globally linkable raw identifiers. The `hmac:` values are
benchmark placeholders for workspace-scoped keyed features. Production template
capture must continue to use the workspace-scoped HMAC boundary from the template
system design.

## Calibration method

Exact, known-variant, and stale states are deterministic precedence rules. They
are not learned from a score threshold:

1. A stale expected source digest refuses replay before candidate ranking.
2. An exact source digest selects the reviewed template.
3. An exact keyed layout selects a known variant, but does not suppress value
   review.
4. Only then does structural scoring consider family and ambiguity.

For each document class, the calibration routine computes the score of every
reviewed family-positive and hard-negative case using the shared component
weights. It records:

- the weakest positive score,
- the strongest negative score,
- the midpoint threshold between those scores, rounded upward to four decimals,
- the ambiguity margin required by reviewed equal-evidence cases,
- counts of positive, negative, and ambiguous evidence, and
- the false-positive gate result.

If positive and negative scores are not separable, family acceptance is disabled
for that class. A class with only negative evidence cannot earn a family threshold.
This is why `scannedDocument` remains disabled even though exact and known-variant
identity behavior is covered.

The class-aware policy is resolved at match time. An explicit policy supplied by a
future profile can override the benchmark map only if the caller records that
override. The matcher does not infer a class from sensitive content or silently
fall back from a disabled class to the global family threshold.

## Calibrated evidence

The current output from
`calibrateDocumentClassPolicies(REVIEWED_TEMPLATE_FIXTURES)` is:

| Document class | Cases | Weakest positive | Strongest negative | Family threshold | Ambiguity margin | Family acceptance | Gate |
|---|---:|---:|---:|---:|---:|---|---|
| `publicAcroForm` | 6 | 0.9619 | 0.7083 | 0.8352 | 0.05 | review | pass |
| `staticPrintedForm` | 6 | 0.9991 | 0.6600 | 0.8296 | 0.05 | review | pass |
| `nativeWidget` | 3 | 0.9748 | 0.7500 | 0.8624 | 0.05 | review | pass |
| `rotatedStaticForm` | 3 | 0.9994 | 0.5548 | 0.7772 | 0.05 | review | pass |
| `rotatedNativeWidget` | 3 | 0.9742 | 0.7500 | 0.8621 | 0.05 | review | pass |
| `scannedDocument` | 3 | none | 0.3048 | disabled | 0.05 | disabled | insufficient positive evidence |

The threshold is a reviewed separation point, not a probability. A score of
`0.8624` does not mean an 86.24 percent match probability. It means that, in this
corpus and under these component weights, the threshold lies above the strongest
negative and below the weakest positive for that class.

## Negative and mutation gates

The hard-negative cases remain unselected under the calibrated policy:

| Hard negative | Class | Score | Selected |
|---|---|---:|---|
| `near-family-negative` | `staticPrintedForm` | 0.4100 | no |
| `unrelated-corpus-negative` | `scannedDocument` | 0.3048 | no |
| `public-acro-form-hard-negative` | `publicAcroForm` | 0.7083 | no |
| `static-printed-form-hard-negative` | `staticPrintedForm` | 0.6600 | no |
| `native-widget-hard-negative` | `nativeWidget` | 0.7500 | no |
| `rotated-static-form-hard-negative` | `rotatedStaticForm` | 0.5548 | no |
| `rotated-native-widget-hard-negative` | `rotatedNativeWidget` | 0.7500 | no |

The mutation gate changes every class policy to `familyThreshold: 0` and
`ambiguityMargin: 0`, while forcing family acceptance to review mode. The
benchmark then fails on the hard negatives and ambiguous cases. This is the
required red-team property: if a future change widens acceptance or removes
abstention, the reviewed corpus must turn red.

## Verification commands

The following checks passed after the corpus and calibration changes:

```text
node --check web/template-match-benchmark.mjs
node --check Tests/fixtures/template_matching_reviewed_fixtures.mjs
node Tests/web_template_match_benchmark_test.mjs
```

The test output records 24 fixtures, all expected states, per-class thresholds,
the seven false-positive cases, and both global and class-policy mutations. The
browser fixture exposes `calibrateDocumentClassPolicies` alongside the existing
classifier so a future live browser corpus run can use the same serialized
policy artifact. The static test also checks that the checked-in JSON snapshot
matches the executable calibration to its documented precision.

## What remains open

This calibration must not yet enable batch completion or automatic profile value
resolution. The next corpus gate is:

1. Acquire at least two genuinely recurring source versions per class, with
   provenance and SHA-256 records.
2. Have the curator label page-level mappings and hard negatives, then record a
   second independent review or a documented exception.
3. Extract fingerprints independently through PDF.js and PDFKit from the same
   bytes, classify semantic mismatches, and preserve provider-specific evidence.
4. Add cross-class negatives that are visually close but semantically distinct.
5. Hold out one source version per family for calibration evaluation. Do not tune
   and report against the same version.
6. Re-run the threshold mutation campaign, including missing anchors, reordered
   fields, rotation changes, page insertion, OCR-only pages, and near-duplicate
   signatures.

Until those gates pass, the product may use the policies to rank reviewed
proposals and explain abstentions, but it must not silently apply a template,
profile value, or operation to a new source PDF.
