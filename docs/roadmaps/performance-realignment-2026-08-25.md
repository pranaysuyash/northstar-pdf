# Performance program realignment and corpus contract

**Date:** 2026-08-25
**Status:** Proposed program realignment; Tier 1 static inspection only
**Owner:** Program realignment and performance-corpus contract owner
**Owned write set:** This document and `benchmark/performance-corpus-manifest.json` only
**Verification boundary:** No tests, builds, benchmarks, runtime checks, or Git mutations were run

## Purpose

This document re-aligns the 2026-08-24 performance roadmap with the current
native source, the dated lane reports, and the existing fixture/result naming.
It is a coordination contract, not a performance result. It keeps observed
behavior, proposed targets, historical evidence, and unknowns separate so that
future work cannot turn a plan, a static change, or a prior parity run into a
latency, memory, crash, or production claim.

The companion manifest is the value-free input contract for future runs. It
names the current discovery inventory and the required metadata shape, but it
does not assert newly measured hashes, byte counts, page counts, rotations,
iterations, runtime metadata, or gate outcomes.

## Current evidence posture

The live checkout supports the following classification:

| Classification | Meaning in this realignment |
| --- | --- |
| Observed | Directly present in the live source or current dated project document during this static inspection. |
| Proposed target | A desired threshold or sequencing choice from the roadmap, not a measured result. |
| Unverified claim | A behavior or improvement that needs a named test, benchmark, or runtime observation. |
| Historical stale statement | A statement retained for provenance whose status is superseded, narrowed, or not revalidated for this program. |
| Unknown | A field or fact intentionally left open until discovery or runtime evidence supplies it. |

No item below is promoted to verified performance evidence. The 2026-08-23
through 2026-08-25 result directories and audit reports remain useful historical
fidelity/provenance evidence, but they are not a new performance baseline.

## Observed source behavior

### Lane A: telemetry and benchmark boundaries

- `Sources/PDFEditorCore/PerformanceTelemetry.swift` defines the value-free
  stages `open_load`, `page_render`, `detection`, `undo`, `redo`, and `save`.
- The recorder is opt-in, keeps a bounded in-memory ring, uses monotonic timing,
  and retains only stage, duration, and success/failure outcome. It does not
  retain paths, filenames, digests, text, field values, PDF bytes, PDF objects,
  or error descriptions.
- `PDFKitProvider.inspect` is wrapped at the combined source-load/inspection
  boundary and `PDFKitProvider.export` is wrapped around the full staged export
  contract, including reopen and fidelity validation before publication.
- `PDFPerformancePageRenderer.draw` is an available page-draw seam, but this
  inspection does not establish that every app or standalone benchmark render
  path uses it.
- Detection, undo, and redo call-site coverage is not established here. A redo
  transition is not part of the current native surface, so a `redo` sample
  cannot be claimed merely because the enum exists.

### Lane B: edit state and undo

- `AppModel` owns the live PDFKit document, the semantic `operations` history,
  cached source bytes, and native undo state.
- The current bounded improvement keeps at most eight in-memory PDFKit
  checkpoints, with a checkpoint eligible after every eight successful edits.
  Undo replays only the suffix after the newest usable checkpoint and falls back
  to cached-source replay when needed.
- The operation log remains canonical; checkpoints are disposable derived state.
  Failed reconstruction does not discard operation or candidate state, and
  export still uses a new destination plus source/output validation.
- Direct inverse mutation and redo remain proposed follow-on architecture. The
  current operation contract does not generally carry durable provider-owned
  annotation identities or exact inverse tokens.

### Lane C: geometry and detection

- `StaticRegionDetector` contains stable first-seen rectangle deduplication and
  a capped reserve hint for small-cell staging. The current field vocabulary,
  thresholds, candidate kinds, grouping policy, and abstention behavior are
  intended to remain unchanged by this slice.
- `PDFVectorStreamParser` filters and classifies raw geometry and uses bounded
  reserve hints. No corpus-level timing, allocation, candidate-count, or group-
  membership result is established by the source shape alone.
- Static geometry is review evidence, not authored field intent. Repeated or
  ambiguous grids must not become editable fields solely because they are cheap
  to detect.
- A provider-boundary risk remains: parser geometry is associated with a media
  box while the inspection/provider path carries crop-box and page-rotation
  information. Treating parser output as canonical crop-relative edit geometry
  without an agreed conversion point is unsafe. The risk is observed from
  static contracts, not proof that every document is wrong.

### Lane D: native runtime, I/O, and memory

- The native provider is synchronous. It loads and inspects the source, applies
  operations, stages output, reopens and validates the staged result, and only
  then publishes it. The no-op path preserves the original source bytes.
- Input limits, source-digest binding, no-overwrite behavior, temporary-file
  cleanup, and provider-neutral value results are existing correctness
  boundaries.
- PDFKit/AppKit executor safety, stale-result handling, cancellation inside
  synchronous calls, peak-memory ownership, and concurrent export policy are
  not established by static inspection. A detached task, page cache, or broad
  background move is therefore a proposed design, not an observed improvement.
- The safe order in the lane report is measurement first, then a bounded
  latest-wins coordinator, then memory/render policy only after profiling
  identifies the dominant cost.

## Proposed targets and operating contract

The original roadmap proposes these targets. They remain targets until a run
records the fixture identity, build/runtime metadata, warm/cold policy, samples,
and gates in a retained result:

| Target | Proposed threshold | Required evidence before promotion |
| --- | --- | --- |
| Warm first usable page | P50 below 2.0 seconds on the target Mac profile | Isolated warm run with explicit first-page boundary and runtime metadata. |
| Mixed 15-20 page open/load | P95 at or below 5.0 seconds | Fixed corpus entry with page/content metadata and separated cold/warm samples. |
| Small-to-moderate undo | P95 at or below 250 ms; redo only when a real redo path exists | Edit-history fixture, replay/fidelity oracle, and independent runtime sample. |
| Detection responsiveness | No UI-thread blocking attributable to detection | Runtime observation; timing JSON alone is insufficient. |
| Memory | No regression against an approved, file-size-normalized budget | Peak-memory accounting by source bytes, live document, validation document, rasters, and caches. |
| Crash and recovery | No new crash, hang, watchdog timeout, or unsafe publication path | Malformed/encrypted/oversized cases plus repeated-run process evidence. |
| Fidelity | Zero regression of source, reopen, geometry, form, text, raster, and applied-operation gates | Provider and independent-viewer evidence where the fixture class requires it. |

The thresholds are not values in the companion manifest. The manifest records
where the target run must place the gate status and measured values, leaving
those fields `null` until the responsible lane performs the run.

## Lane ownership and boundaries

| Lane or boundary | Owns | Does not own | Handoff/dependency |
| --- | --- | --- | --- |
| Program realignment and corpus contract | This realignment, the value-free manifest, corpus identity policy, and evidence vocabulary | Fixture regeneration, benchmark execution, source optimization, or Git state | Provides one stable input contract to every measurement lane. |
| A: telemetry and measurement | Opt-in spans, run schema, result serialization, baseline orchestration, and stage definitions | Fidelity policy, provider-specific semantic decisions, or inventing target measurements | Needs the manifest and provider-approved call-site ownership before baselines. |
| B: edit state | Checkpoints, operation history, undo/redo semantics, replay recovery, and related memory accounting | Direct PDFKit inverse behavior without provider tokens; native runtime executor policy | Needs fidelity/replay oracles and memory measurements before deeper history changes. |
| C: geometry | Parser/detector hot paths, candidate/group semantics, geometry metrics, and hard negatives | Silent crop/rotation normalization or provider contract migration | Coordinate migration requires PDFKit provider, shared contracts, and native/browser parity owners. |
| D: native runtime | Rendering, I/O, concurrency, cancellation, stale-result policy, and memory lifecycle | Speculative `Task.detached`, cache authority, or bypassing export validation | Needs A measurements and an accepted state/publication machine before async work. |
| Fidelity and independent validation | Source integrity, reopen, geometry/form/text/raster preservation, and independent viewer checks | Latency optimization or promoting a timing pass over a fidelity failure | Every mutation-capable performance run must consume these gates. |

The manifest itself is not a second governance authority. Existing provenance
and privacy rules in `Tests/fixtures/pdf_corpus_governance_manifest.json` remain
the source for fixture governance. This performance manifest is a measurement
input projection and must point back to those retained artifacts and generators.

## Dependency order

1. Preserve the current provider, operation, source-digest, export-publication,
   candidate, and privacy contracts. Reconcile any concurrent owner changes
   before editing shared source.
2. Admit the value-free corpus inventory and resolve each entry's exact bytes,
   SHA-256, byte count, page count, rotations, and provenance from the retained
   artifact or a declared stable locator. A filename or prior result name is not
   a substitute for a digest.
3. Confirm the measurement harness can compile the intended core seams and
   record build/runtime metadata without content-bearing logs. Keep cold and
   warm samples separate and keep the process/filesystem cache distinction
   explicit.
4. Capture an unchanged baseline for open/load, page render, detection, undo,
   and save. Capture redo only after a real redo transition and oracle exist.
5. Establish fidelity, memory, crash, malformed-input, encrypted-input, and
   cleanup gates on the same corpus before tuning a hot path.
6. Measure Lane B checkpoint memory/replay equivalence and Lane C candidate and
   group membership before accepting deeper optimization. Treat coordinate
   normalization as a separate semantic migration with provider/parity review.
7. Only after the above evidence, evaluate Lane D orchestration, cancellation,
   stale-result handling, and derived caches. Keep publication last and retain
   full export validation.
8. Re-run the relevant corpus slice after each optimization, compare semantic
   outputs before timing deltas, and preserve failed or classified results.

## Historical and stale statements that must not be reused as current proof

- The 2026-08-24 roadmap describes four synchronized lanes and asks for fixed
  benchmark outputs and dashboards. It is a program outline, not evidence that
  those deliverables or targets are complete.
- The 2026-08-24 Lane A report says call-site wiring remains open. The dated
  2026-08-25 Lane A implementation report narrows that statement: `inspect` and
  `export` wiring is now described, while page-render coverage and detection,
  undo, redo, and standalone-harness integration remain open.
- The roadmap's daily template says to run a benchmark slice. This task
  explicitly forbids running one, so no daily delta or baseline is asserted.
- Dated `benchmark/results/` JSON and PDF artifacts are derived evidence. Their
  names identify historical runs and operations; they do not establish a
  current warm/cold performance baseline.
- The 2026-08-25 corpus audits report governance, browser, parity, viewer, and
  preservation observations. They are valuable historical evidence with
  explicitly classified mismatches, not proof of memory, latency, crash-free
  operation, OCR accuracy, or universal PDF fidelity.
- Existing exact fixture hashes in governance and benchmark documents were not
  copied into the new performance manifest as newly verified facts. The new
  manifest intentionally uses `null` until its discovery pass binds each entry
  to exact retained bytes.

## Unverified claims and required falsifiers

| Claim still open | Falsifier or required evidence |
| --- | --- |
| The telemetry wrappers cover every performance-critical boundary | Static call-site inventory plus a run showing each required stage, including an explicit absence/unsupported state for redo. |
| Checkpoints reduce undo latency without semantic drift | Replay-equivalence and fidelity checks across short and long histories, then measured P95 and peak memory. |
| Geometry changes preserve detector semantics | Candidate membership, group membership, ordering policy, coordinate metadata, rotated/non-zero-crop fixtures, and hard-negative comparison. |
| A background coordinator is safe for PDFKit | Executor/thread-affinity evidence, stale-result mutation checks, cancellation cleanup, and publication-order checks. |
| A cache reduces cost | Measured hit/miss behavior, invalidation by source/revision/geometry key, bounded memory, and no authority transfer from source or operation history. |
| Existing result artifacts are reproducible baselines | Re-run from the manifest with exact bytes, generator chain, build/runtime metadata, and separate cold/warm policy. |

## Doctrine-alignment assumptions

These are operating assumptions for future work, not claims about measured
behavior:

- Native Swift/PDFKit remains the canonical shipping lane unless a separate
  provider decision changes that boundary.
- One source of truth remains authoritative for each semantic fact: the
  operation log for edit history, source bytes for recovery/no-op export, the
  provider for native mutation, the corpus manifest for fixture identity, and
  result artifacts for run evidence.
- Performance telemetry stays opt-in, bounded, monotonic, and value-free.
- Unknown, failed, malformed, encrypted, or unsupported states remain visible;
  a fast failure cannot improve a performance gate.
- Optimization may reduce repeated work but may not weaken source integrity,
  fail-closed publication, candidate abstention, coordinate meaning, or
  provider-neutral contracts.
- Synthetic and derived fixtures are useful for controlled falsification but do
  not establish real-user, production, OCR, handwriting, signature, or universal
  document-family claims.
- A benchmark result is promoted only with evidence tier and test sensitivity;
  a static source review remains Tier 1 and this document has no test
  sensitivity beyond documentation existence.

## Explicit exclusions

This realignment does not modify or adjudicate unrelated work, including
template-index files or template family catalogs, OCR/provider adoption,
SignKit or hosted/cloud processing, signing, redaction, XFA, PDF/UA,
collaboration, product-mode/UI redesign, source fixture regeneration,
benchmark execution, result cleanup/renaming, generated artifacts, native
runtime changes outside the named lane owners, or any Git operation.

## Intentionally unmeasured fields

The following remain intentionally unmeasured in this task and are represented
as `null` or `TODO` in `benchmark/performance-corpus-manifest.json`:

- exact retained fixture bytes and SHA-256 digests;
- byte counts, page counts, and per-page rotations;
- fixture discovery completeness and any missing stable locator;
- warm-up and measured iteration counts actually completed;
- cold filesystem-cache state and warm process state;
- compiler, SDK, OS, architecture, provider, harness, and build revision for a
  performance run;
- P50/P95 latency, first-page readiness, detection blocking, queue depth, and
  cancellation/stale-result counts;
- source/output fidelity, reopen, geometry, form, text, raster, and independent
  viewer gate outcomes;
- peak memory, normalized memory budget, cache growth, and cleanup behavior;
- crashes, hangs, watchdog timeouts, malformed/encrypted safe-failure outcomes,
  and repeated-run recovery outcomes;
- candidate/group membership deltas, coordinate parity, and checkpoint replay
  equivalence under optimization;
- any claim of production, real-user, device, hosted, or external-provider
  performance.

## Revisit and completion trigger

Revisit this document when the corpus discovery pass completes, a lane owner
accepts a measurement boundary, a shared source owner changes, or a semantic
coordinate/recovery contract is proposed. The program is not complete until
the manifest's null/TODO fields have current evidence or an explicit accepted
unknown, and every promoted result links its corpus identity, run metadata,
gate outcomes, evidence tier, sensitivity, and residual risk.
