# Reviewed Completion, Abstention, Hard-Negative, and Safe-Completion Metrics

**Date:** 2026-08-25  
**Status:** Passed controlled value-free benchmark  
**Metric contract:** [`web/reviewed-completion-metrics.mjs`](../../web/reviewed-completion-metrics.mjs)  
**Native mirror:** [`ReviewedCompletionMetricsContracts.swift`](../../Sources/PDFEditorCore/ReviewedCompletionMetricsContracts.swift)  
**Benchmark:** [`web/template-correction-benchmark.mjs`](../../web/template-correction-benchmark.mjs)  
**Mutation suite:** [`Tests/reviewed_completion_metrics_mutation_test.mjs`](../../Tests/reviewed_completion_metrics_mutation_test.mjs)

## Purpose

The existing correction benchmark measured reviewed-target coverage lift and
hard-negative replay. This extension adds a versioned metric contract for four
separate questions:

1. Did an explicitly reviewed correction improve recurring completion coverage?
2. Did ambiguous, stale, and no-match cases abstain instead of selecting?
3. Did hard negatives remain unselected after correction promotion and replay?
4. Did the workflow become ready for explicit completion review without allowing
   materialization or silent autofill?

The metrics are value-free. They do not store profile values, page text, source
bytes, raw labels, screenshots, or OCR output.

## Contract

The metric contract is:

```text
schema: pdf-editor.reviewed-completion-metrics
version: 1.0
primaryDenominator: reviewed-correction-cases
abstentionStates: ambiguous, stale, noMatch
hardNegativeState: noMatch
silentAutofillPolicy: forbidden
privacy: value-free-counters-and-states-only
```

The evaluator is independently computable from the matching report and the
reviewed correction report. It does not trust the report's final `passed` field
as its own input, which prevents a self-validating metric cycle.

## Metrics

### Reviewed correction

The benchmark measures:

- eligible correction cases;
- explicitly promoted correction count;
- baseline reviewed-target count;
- promoted reviewed-target count;
- reviewed-target coverage lift;
- improved-case count and rate;
- rollback restoration count and rate.

Current controlled result:

```text
eligible cases:                 5
promoted corrections:           5
baseline reviewed targets:      0
promoted reviewed targets:      5
coverage lift:                  5
improvement rate:               1.0
rollback restoration rate:      1.0
```

This means each controlled source variant surfaced one reviewed mapping after
an explicit correction promotion. It does not mean a user entered a value or
that a real-world document was completed faster.

### Abstention

Abstention is measured over cases whose reviewed expected state is `ambiguous`,
`stale`, or `noMatch`.

```text
abstention-eligible cases:      14
abstained cases:                14
abstention rate:                1.0
abstention failures:            0
```

The state breakdown is:

| Expected state | Cases |
| --- | ---: |
| `ambiguous` | 6 |
| `stale` | 1 |
| `noMatch` | 7 |

The metric treats abstention as a successful safety outcome when the reviewed
case says that selection is unsafe or unsupported.

### Hard negatives

Hard negatives are the seven reviewed `noMatch` cases. They are measured both
in the original matching corpus and as replays against every promoted child
revision:

```text
hard-negative fixtures:          7
selected before/after replay:   0
hard-negative abstention rate:  1.0
false-positive rate:             0.0
promotion replays:              35
replay selections:               0
replay abstention rate:          1.0
```

The metric fails if a single hard negative is selected. A higher coverage lift
cannot compensate for a hard-negative false positive.

### Safe completion

Safe completion is deliberately defined as readiness for explicit review, not
automatic application:

- source digest is bound to the correction event and validation result;
- source is unchanged;
- output is reopenable;
- a reviewed target is available;
- mapping review is still required;
- value review is still required;
- materialization without review is rejected;
- silent autofill count remains zero.

Current controlled result:

```text
source-bound validated cases:                 5 / 5
explicit-review guarded cases:                5 / 5
safe-completion-ready cases:                  5 / 5
materialization without review:               0
silent autofill:                              0
```

The completion proposal is intentionally blocked by the existing
`canMaterializeCompletion` guard until mapping and value review are explicitly
approved. The correction benchmark contains no profile values, so the metric
cannot claim actual field completion.

## Mutation evidence

[`Tests/reviewed_completion_metrics_mutation_test.mjs`](../../Tests/reviewed_completion_metrics_mutation_test.mjs)
passed five checks. The mutations are:

- selecting a reviewed hard negative;
- allowing materialization without review;
- marking silent autofill as detected;
- degrading the privacy evidence;
- selecting an ambiguous case instead of abstaining.

Each mutation makes the aggregate metric fail. This protects against a future
implementation that improves completion numbers by weakening abstention or
review gates.

## Native and browser evidence

The Node benchmark and isolated browser benchmark both passed:

```text
reviewed correction coverage lift:       5
abstention rate:                         1.0
hard-negative false-positive rate:       0.0
safe-completion-ready rate:              1.0
silent autofill count:                   0
browser console errors:                 0
browser page errors:                    0
```

The browser result is recorded in
[`benchmark/results/template-matching/2026-08-24-correction-benefit-browser.json`](../../benchmark/results/template-matching/2026-08-24-correction-benefit-browser.json).
The Node result is recorded in
[`benchmark/results/template-matching/2026-08-24-correction-benefit.json`](../../benchmark/results/template-matching/2026-08-24-correction-benefit.json).

The native Swift core decodes the nested `metrics` payload from the Node
benchmark artifact and validates the same schema, version, privacy, abstention,
hard-negative, and no-silent-autofill invariants. The focused native test is
[`Tests/PDFEditorCoreTests/ReviewedCompletionMetricsContractTests.swift`](../../Tests/PDFEditorCoreTests/ReviewedCompletionMetricsContractTests.swift):
two tests passed, including one intentionally unsafe hard-negative report that
was rejected before parity acceptance. This is serialized contract parity, not
yet native aggregation parity. The native matcher and browser evaluator still
need to be run over the same raw case records before their computed counters
can be claimed equivalent.

## Limits and next evidence

This is controlled value-free evidence. It does not measure:

- real user time to completion;
- user acceptance or correction effort;
- profile-value correctness;
- genuine handwriting recognition;
- held-out recurring-document recall;
- reviewer agreement beyond the current single-curator labels;
- output PDF fidelity for an actual materialized value;
- independent viewer parity for a corrected export.

The next metric expansion should add held-out recurring documents with
independent reviewer labels, explicit value-review simulations using synthetic
values, source/output outside-region validation, correction latency, and
cross-platform native/browser metric parity. The silent-autofill invariant must
remain mandatory in every expansion.
