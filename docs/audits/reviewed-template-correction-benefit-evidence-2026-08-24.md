# Reviewed Template Correction Benefit Evidence

Date: 2026-08-24  
Status: Passed controlled value-free measurement; real-user completion benefit remains unmeasured  
Evidence tier: Tier 2/S1 Node benchmark plus Tier 3/S1 isolated Chrome execution; mutation-sensitive safety checks included

## Question

Do explicit reviewed correction events improve recurring PDF completion coverage
without leaking content, changing the source, losing rollback, or causing hard
negative templates to select?

The answer from this controlled benchmark is yes for the bounded metric tested:
five reviewed structured document variants moved from zero surfaced reviewed
targets to one surfaced reviewed target each after promotion. All seven reviewed
hard-negative cases remained abstained across all five promoted revisions.

This is not a claim about real-user speed, real profile values, production
precision, or arbitrary recurring PDFs.

## Metric definition

The primary metric is `reviewedTargetCoverage`:

> the count of reviewed template mappings surfaced in a completion proposal,
> without resolving or storing any profile value.

This metric measures whether a correction makes the right reviewed target
available to the completion workflow. It intentionally does not pretend that a
surfaced mapping equals a completed field.

Not measured by this benchmark:

- keystroke or task completion time;
- user acceptance rate;
- profile-value resolution or value correctness;
- export fidelity or outside-region PDF preservation;
- real-world recurring-family recall and precision;
- independent reviewer agreement.

## Experimental design

The benchmark starts from the existing reviewer-labeled corpus. It selects the
five structured `family-positive` cases:

- `publicAcroForm`;
- `staticPrintedForm`;
- `nativeWidget`;
- `rotatedStaticForm`;
- `rotatedNativeWidget`.

For each case, the benchmark creates a value-free recurring variant by changing
the keyed layout fingerprint and anchor tokens enough that the calibrated
baseline matcher abstains with `noMatch`. The variant is then represented by a
reviewed correction record containing:

- current source digest;
- keyed fingerprint evidence;
- document class;
- explicit `sameFamily` review decision;
- one confirmed static-region mapping;
- semantic key and candidate-evidence reference;
- no profile value, raw label, screenshot, or source bytes.

Promotion uses the existing strict `canPromoteTemplateRevision` gate. It
requires a validated and reopenable result, unchanged source, matching source
digest, and no failed or unknown validation checks. The correction creates an
immutable child revision with:

- a parent revision ID;
- the reviewed source digest in the local exact-source allowlist;
- the confirmed mapping;
- a pending learning event transitioned to `applied` in the measurement result.

The parent revision is retained. Rollback selects the unchanged parent revision
again while retaining the promoted child in history for auditability.

## Result

Machine report:

[`benchmark/results/template-matching/2026-08-24-correction-benefit.json`](../../benchmark/results/template-matching/2026-08-24-correction-benefit.json)

Isolated Chrome summary:

[`benchmark/results/template-matching/2026-08-24-correction-benefit-browser.json`](../../benchmark/results/template-matching/2026-08-24-correction-benefit-browser.json)

The Node benchmark passed:

```text
correction scenarios:                 5
baseline reviewed targets:             0
promoted reviewed targets:             5
reviewed-target coverage lift:         5
improved scenarios:                    5 / 5
improvement rate:                      100%
baseline targets after rollback:       0
rollback:                              passed
hard negatives evaluated:              7
hard-negative selections after learn:   0
hard-negative abstentions after learn:  35 / 35
privacy:                               passed
```

The five promoted cases all had this semantic transition:

```text
baseline:  noMatch -> 0 reviewed targets
promoted:  exact   -> 1 reviewed target
rollback:  noMatch -> 0 reviewed targets
```

The exact state transition is intentionally source-bound. The correction does
not enable a general family threshold bypass. It admits the explicitly reviewed
source digest and mapping into a child revision.

## Safety results

### Privacy

The correction records and report contain no profile values, raw labels, PDF
bytes, screenshots, or passphrases. The report records counters and semantic
states only. The test also injects a raw synthetic name into the privacy
sentinel and confirms that it is rejected, while keyed structural tokens such
as `hmac:anchor-applicant` are accepted as non-content identifiers.

### Rollback

Promotion creates a child revision and leaves the parent object unchanged. The
rollback check reselects the parent, returns to the baseline `noMatch` state,
returns reviewed-target coverage to zero, and confirms that the child revision
remains present in the append-only history.

This benchmark models rollback as a revision-selection view. Native and browser
persistence layers still need a production rollback command, user-visible
confirmation, encrypted-store recovery, and cross-device conflict handling.

### Hard-negative abstention

The seven existing no-match fixtures are replayed against every promoted child
revision. There are 35 promoted-revision checks and zero selections. A separate
negative test attempts to promote a correction marked `hardNegative` and the
promotion is rejected before a child revision is created.

### Strict validation

The correction uses the existing strict validation gate. Failed, unknown, stale,
or warning-only validation cannot promote future template behavior. The native
Swift contract test continues to cover the same strict promotion boundary in
`PDFTemplateRevisionGate`.

## Browser evidence

The browser adapter was run in isolated headless Chrome using a project-owned
static server on port 8183. The other local browser daemon was serving a
different project on port 4173, so it was not used as evidence for this run.

Browser result:

```text
fixtureCount:                 5
reviewedTargetCoverageLift:   5
selected hard negatives:      0
rollback:                     true
privacy:                      true
console errors:               0
page errors:                  0
```

The repeatable browser command is:

```bash
PDF_PROOF_BASE_URL=http://127.0.0.1:8183/web/index.html \
  node Tests/web_template_correction_benchmark_browser_test.mjs
```

The server is intentionally not part of the product claim. It is only the local
static route needed to load the browser fixture in an isolated test context.

## Mutation and failure evidence

The benchmark rejects:

- a correction whose review decision is not `sameFamily`;
- a correction whose event and current source digests differ;
- a correction with raw document or profile content;
- a correction with failed or unknown validation;
- a correction whose source-bound promotion would target a hard negative.

The first run also caught an over-broad privacy sentinel. It incorrectly treated
the keyed token `hmac:anchor-applicant` as raw content. The sentinel was narrowed
to quoted raw labels, and the corrected benchmark passed. This is recorded as
measurement harness S2 evidence, not hidden as a clean first attempt.

## Implementation artifacts

- [`web/template-correction-benchmark.mjs`](../../web/template-correction-benchmark.mjs)
  implements reviewed correction construction, strict promotion, coverage
  measurement, rollback view, privacy checks, and hard-negative replay.
- [`Tests/web_template_correction_benchmark_test.mjs`](../../Tests/web_template_correction_benchmark_test.mjs)
  runs the deterministic benchmark and writes the machine report.
- [`Tests/web_template_correction_benchmark_browser_test.mjs`](../../Tests/web_template_correction_benchmark_browser_test.mjs)
  runs the same browser API in isolated Chrome.
- [`web/index.html`](../../web/index.html) and [`web/app.js`](../../web/app.js)
  expose the benchmark through the existing browser contract fixture.
- [`Sources/PDFEditorCore/TemplateRuntimeContracts.swift`](../../Sources/PDFEditorCore/TemplateRuntimeContracts.swift)
  remains the native strict learning-event and validation gate.

## Interpretation and next gate

The measured lift is promising but intentionally narrow. It demonstrates that a
reviewed correction can turn a repeated, source-bound variant from no proposal
into one reviewed target while preserving the safety invariants. It does not
show that users finish faster or that the corrected mapping is semantically
right on a new unseen PDF.

The next measurement should add held-out recurring versions with independently
reviewed mappings and compare:

1. baseline proposal coverage;
2. correction-promoted proposal coverage;
3. reviewer acceptance and correction rate;
4. hard-negative selection rate;
5. rollback and stale-source recovery rate;
6. value-free diagnostics and encrypted-store leakage checks.

Promotion should remain review-only until those held-out measurements exist.
