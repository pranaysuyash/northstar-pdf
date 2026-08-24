# Autoresearch Adaptation

**Status:** Proposed evaluation protocol
**Reviewed:** 2026-08-23
**Reference:** <https://github.com/karpathy/autoresearch>

## Transferable Idea

Karpathy's autoresearch separates a fixed preparation/evaluation surface from a
small mutable candidate surface. Each bounded run changes the candidate, executes
against the same evaluation conditions, records a metric, and keeps or discards
the change. The local MLX port preserves this shape with `prepare.py`, a mutable
training file, `program.md`, and `results.tsv`.

For PDF editing, the fixed surface must be stronger because a higher detection
score is not enough if the output damages unrelated content.

## Fixed Surface

The following must be immutable for a comparable experiment batch:

- source PDF bytes and SHA-256 digests;
- reviewed field-group manifests and non-target masks;
- page coordinate normalization and rendering settings;
- native-form inventory evaluator;
- static-candidate matching and label-association evaluator;
- export/reopen and content-preservation checks;
- timeout, file-size, memory, and external-processing policy;
- scoring and hard-gate definitions.

The Form 6 fixture is the first reviewed manifest candidate. It is not sufficient
as the complete corpus; later batches need native forms, scans, hybrid documents,
rotations, encryption, signatures, annotations, and malformed inputs.

## Mutable Surface

An experiment may change one explicitly named candidate surface at a time:

- geometric heuristics and thresholds;
- candidate grouping rules;
- label-to-region association;
- OCR/layout adapter configuration;
- ranking or abstention policy;
- text fitting and placement policy;
- provider adapter implementation, only in a provider-specific benchmark lane.

The mutable candidate must not change the ground truth, the evaluator, the source
PDF, the hard safety gates, or the user-review requirement.

## Acceptance Order

Use lexicographic acceptance rather than a single unconstrained score:

1. **Hard gates:** source digest unchanged, output reopens, no unsafe auto-apply,
   no parser/resource-limit violation, and no export failure presented as success.
2. **Safety:** lower false-positive rate, lower unintended-change rate, and higher
   abstention quality on ambiguous regions.
3. **Correctness:** higher field-group precision/recall, label association, and
   value-fit success.
4. **Product cost:** lower latency and memory use at equivalent safety/correctness.

If a candidate improves recall while violating a hard gate or increasing harmful
false positives, it is discarded regardless of its aggregate score.

## Required Run Record

Each run should have a stable ID and record:

- source and corpus manifest digests;
- candidate version and configuration hash;
- provider and model versions, if any;
- hard-gate results;
- precision, recall, F1, false-positive, abstention, and preservation metrics;
- latency, memory, warnings, and failure details;
- keep/discard decision and a short explanation;
- representative failure artifacts stored locally without uploading document data.

## Human Review Role

Human review is part of the product contract, not a temporary workaround. The
loop may optimize suggestion quality and reduce review burden, but it may not
turn an uncertain static region into a verified field without an explicit review
decision. Changes to this rule require a separate safety and product decision.

## Falsifiers

The approach is not ready if any of the following occur:

- small metric improvements repeatedly create visible unrelated-content changes;
- the evaluator rewards false positives or misses conditional relationships;
- results vary materially with renderer, page scale, or output viewer;
- the loop cannot reproduce a prior keep/discard decision from recorded inputs;
- a candidate depends on cloud processing despite the local-only policy;
- benchmark gains do not transfer beyond Form 6.

This is a proposed protocol only. No automated experiment loop or application
code has been implemented.
