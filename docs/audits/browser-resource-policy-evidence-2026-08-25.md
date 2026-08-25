# Browser Resource Policy Evidence

**Date:** 2026-08-25  
**Status:** Implemented contract and controlled benchmark; physical-device and real-provider calibration remain open  
**Owner:** /Users/pranay/Projects/pdf_editor  
**Decision:** D-032  
**Release gate:** RG-098  
**Evidence sensitivity:** S1 for the passing checks, S2 for the cancellation checkpoint assertion, S3 remains required for physical-device and provider stress promotion

## Outcome

The browser and native adapters now share a value-free resource-governance
contract. It measures or records available runtime and document facts, selects
bounded budgets for rendering, high-DPI work, OCR, batching, cancellation, and
recovery, and emits explicit states and reason codes.

The policy does not perform PDF parsing, rendering, OCR, writing, or
sanitization. It is a control-plane contract consumed by those providers.
Keeping it separate prevents a renderer-specific heuristic from becoming a
hidden PDF semantic rule.

## Contract surface

The canonical browser implementation is:

- web/browser-resource-policy.mjs
- Sources/PDFEditorCore/BrowserResourcePolicyContracts.swift

The envelope is pdf-editor.browser-resource-policy, version 1.0. Its header
contains contract version, generation time, optional source digest, and
provider identity. Its payload contains:

- normalized environment facts: CPU logical cores, device memory when exposed,
  device pixel ratio, viewport, connection/save-data signals, memory and
  storage availability, and browser family;
- normalized document facts: byte count, page count, page area and dimensions,
  rotation, raster and selectable-text counts, native fields, candidates,
  image-pixel estimate, encryption, attachments, and malformed state;
- explicit request intent for render mode, OCR, batching, and high-DPI;
- render, OCR, batch, and recovery budgets;
- capability decisions with enabled, limited, deferred, unknown, or blocked
  states and reason codes;
- safety assertions for no content logging, no network action, no source-byte
  mutation, no partial-output promotion, and cancellation support.

The policy never receives or emits page text, OCR values, profile values,
passwords, image pixels, URLs, attachment names, filenames, or source bytes.
The source digest is an integrity binding, not content telemetry.

## Adaptive rules

Render and high-DPI budgets are based on maximum page area, raster density,
document size, page count, device pixel ratio, memory class, CPU count, and
save-data preference. Low-memory and unknown-memory devices use a smaller pixel
budget, one worker, one-page chunks, and lower concurrency. Large or
raster-heavy documents force chunking and bounded concurrency. High-DPI is
allowed only when the page fits the computed pixel budget.

OCR is deferred unless explicitly requested. A request still requires a
confirmation boundary in the caller. OCR receives per-page pixels, batch-page,
batch-pixel, worker, yield, and cancellation-timeout limits. Malformed input
blocks OCR in the policy.

Batching is deferred unless explicitly requested. An admitted batch has finite
document, byte, page, concurrency, and checkpoint intervals. Save-data,
unknown-memory, and low-memory states use stricter limits.

Long-running work requires a checkpoint. A checkpoint contains only the source
digest, operation ID, batch index, completed count, optional policy digest, and
the invariant that partial output was not promoted. Resume fails closed for a
stale source digest or a different operation ID.

## Controlled benchmark

The governed input is:

- Tests/fixtures/browser_resource_policy_benchmark.json

It covers five declared device profiles:

- low-memory mobile, 2 logical cores and 2 GB;
- save-data mobile, 4 logical cores and 4 GB;
- mid laptop, 4 logical cores and 8 GB;
- high desktop, 12 logical cores and 32 GB;
- unknown signals, with CPU and memory unavailable.

It covers six document classes:

- tiny selectable-text form;
- rotated hybrid;
- scanned noisy raster;
- 40-page hybrid;
- 120-page rotated scan;
- malformed input.

The benchmark is:

- benchmark/benchmark_browser_resource_policy.mjs

It emitted 30 device/document cases to:

- benchmark/results/browser-resource-policy/2026-08-25-device-adaptive.json

The result contains policy envelopes, bounded numeric budgets, state and
reason-code projections, timing, and safety flags. It does not contain source
content. Every row has a finite page concurrency, byte budget, page budget,
recovery policy, and false partial-output promotion flag.

## Verification

Observed and verified:

1. node Tests/browser_resource_policy_test.mjs passed 242 checks across all
   five device profiles and six document classes. It covers source-digest
   mismatch, unknown decision state, unsafe content logging, stale checkpoint,
   operation mismatch, explicit OCR and batch admission, cancellation, and
   matching-digest recovery.
2. node benchmark/benchmark_browser_resource_policy.mjs emitted 30 rows.
3. swift test --filter BrowserResourcePolicyContractTests passed 2 tests.
   Native Swift decoded every serialized policy envelope in the benchmark and
   validated the shared safety and budget invariants.
4. An isolated Chrome run passed
   Tests/web_browser_resource_policy_test.mjs. It opened the existing public
   form, observed live fixture emission and source binding, evaluated low-memory
   and unknown-signal policies, checked explicit OCR behavior, checked
   value-free event summaries, and found no console or page errors.
5. The browser runtime was served locally at port 4174 for the isolated check
   and stopped afterward. No network action was attempted by the policy.

The cancellation test exposed and then protected a recovery invariant. On a
low-memory profile, the policy checkpoints every document. Cancellation after
the first item therefore retains one valid checkpoint, but the result marks
partialOutputPromoted false and the run remains cancelled. The test asserts
that behavior rather than incorrectly expecting no checkpoint.

## What this proves

This is Tier 2 targeted contract evidence plus Tier 3 browser fixture evidence
and native serialized parity for a controlled benchmark. It proves that the
policy is finite, source-bound, explicit about unknown signals, review-gated
for OCR and batching, cancellation-aware, recovery-aware, and value-free in
the tested runtime.

It does not prove physical-device memory ceilings, browser-version stability,
actual PDF.js canvas allocation behavior at every device pixel ratio, OCR
worker model memory, long-run batch throughput, companion crash recovery,
thermal throttling, background-tab suspension, or production user behavior.
Those remain implementation and measurement work, not reasons to narrow the
long-term capability program.

## Active follow-up gates

- Run the same policy on physical low-memory mobile, laptop, and desktop
  browsers with memory and canvas telemetry.
- Attach the policy to actual PDF.js page scheduling and measure allocation,
  render latency, cancellation latency, and recovery replay.
- Add Web Worker OCR with model-loading, per-page pixel enforcement, worker
  termination, and source-bound checkpoints.
- Exercise companion timeout, crash, revocation during work, and restart from a
  checkpoint using the typed provider host.
- Add long-run batch tests with repeated cancellation, tab suspension,
  quota/eviction events, and malformed/encrypted mixed corpus inputs.
- Promote thresholds only after hard-negative, privacy, and recovery evidence
  remains green on newly governed document classes.
