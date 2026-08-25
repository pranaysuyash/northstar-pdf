# Performance Lane D: Native PDF Runtime

**Date:** 2026-08-24  
**Owner:** Performance Lane D  
**Scope:** native PDF rendering, file I/O, concurrency, and memory behavior  
**Status:** design-only follow-up; Lane A now describes `inspect`/`export` telemetry wiring, but no native runtime change or runtime performance result is established

## Outcome

This lane preserves the native macOS PDFKit path while making the next performance changes safe to implement. The current checkout already has important correctness boundaries: bounded input and page limits, source-digest binding, a no-overwrite rule, temporary export staging, reopen/validation before publication, and an in-memory source snapshot for undo.

The current implementation does not yet establish a safe thread-isolation contract for moving PDFKit work away from the main actor. It also has no cooperative cancellation points inside the synchronous provider pipeline. Adding an asynchronous wrapper or a page cache without resolving those boundaries could create stale-document publication, PDFKit object races, excessive memory retention, or cancellation that reports success while an export is still writing.

For this pass, the correct implementation result is therefore documentation only. The design below is the required path for a later, measured implementation.

The current telemetry contract is the six-stage, value-free contract defined in
[`performance-lane-a-telemetry.md`](performance-lane-a-telemetry.md):
`open_load`, `page_render`, `detection`, `undo`, `redo`, and `save`. The dated
Lane A implementation report describes `open_load` at `PDFKitProvider.inspect`
and `save` around the full staged `PDFKitProvider.export` contract. Page-render,
detection, undo, redo, standalone harness, and runtime coverage remain open.
This provider-boundary wiring does not change the native-only or
provider-neutral contract and does not constitute runtime verification.

## Source-grounded current state

The following observations are from static inspection of the live checkout. They are Tier 1 evidence, not runtime or benchmark proof.

| Surface | Current behavior | Performance and safety consequence |
|---|---|---|
| `Sources/PDFEditorCore/PDFKitProvider.swift:23-37` | `inspect` synchronously loads bytes, constructs `PDFDocument`, unlocks when needed, and walks the document to produce provider-neutral `DocumentInspection`. | Open-time CPU and memory work is synchronous. The provider owns PDFKit objects during the operation, but no executor or cancellation contract is declared. |
| `Sources/PDFEditorCore/PDFKitProvider.swift:40-124` | `export` synchronously loads and inspects the source, applies operations in order, stages an output file, validates it by reopening, then moves or replaces the destination. No-op export copies the original source instead of reserializing it. | The current sequence protects source bytes and atomic publication. Any background or cancellation change must retain the stage, validate, and publish ordering. |
| `Sources/PDFEditorCore/PDFKitProvider.swift:279-287` | File reads use `Data(contentsOf:options: [.mappedIfSafe])` and enforce `maximumInputBytes` before processing. | Memory mapping is a useful input strategy, but the app also reads the source again and constructs a live `PDFDocument`, so peak resident memory is not established by the limit alone. |
| `Sources/PDFEditorCore/PDFKitProvider.swift:295-398` | Inspection walks every page, annotations, text lines, outlines, metadata, permissions, accessibility, vector streams, and static candidates. | This is a full-document pass. It is not a visible-page-only renderer and cannot be treated as cheap background work without measuring page count, object count, and peak memory. |
| `Sources/PDFEditorCore/PDFKitProvider.swift:445-762` | Export validation reopens source and output, compares page geometry and fields, checks applied operations, and performs text and raster impact checks. | Validation is correctness-critical and can be more expensive than mutation. It must remain in the same exclusive export job and must not be skipped when work is moved off-main. |
| `Sources/PDFEditorCore/DocumentModel.swift:532-583` | `DocumentInspection` and `ExportResult` are provider-neutral and `Sendable`; `PDFEditorError` is also `Sendable`. | Value results can cross an orchestration boundary. `PDFDocument`, `PDFPage`, and `PDFAnnotation` must not be added to those cross-boundary results. |
| `Sources/PDFEditorCore/DocumentModel.swift:617-625` | `PDFProvider` exposes synchronous `inspect` and `export` methods only. | Adding async behavior directly to this protocol would be an architectural change affecting every provider and caller. The first async layer should be orchestration, not a silent protocol rewrite. |
| `Sources/PDFEditorApp/AppModel.swift:20-55` | `AppModel` is `@Observable` and `@MainActor`; it owns inspection, the live `PDFDocument`, source URL, operations, and a private source-data cache. | UI state and the PDFKit presentation object have one clear owner today. That ownership should remain on the main actor until native isolation is proven. |
| `Sources/PDFEditorApp/AppModel.swift:86-138` | `open` calls provider inspection, reads the URL again, constructs the live `PDFDocument`, and publishes all new state synchronously. Security-scoped access is held around the whole synchronous operation. | Opening can block the main actor. A future async open must keep the security scope alive for the entire read/parse job and publish only the latest request. |
| `Sources/PDFEditorApp/AppModel.swift:434-461` | Undo rebuilds a fresh `PDFDocument` from `cachedSourceData` and reapplies the remaining operations in order. | The cache is currently an undo correctness dependency, not an optional performance cache. Evicting it without a recovery policy changes behavior. |
| `Sources/PDFEditorApp/AppModel.swift:729-749` | Export snapshots neither operations nor a session token; it calls synchronous provider export from the main actor after `NSSavePanel`. | Export can block the UI and can race with future asynchronous edits unless a versioned request snapshot is introduced before work leaves the main actor. |
| `Sources/PDFEditorApp/ContentView.swift:199-230` | `PDFKitView` receives `model.liveDocument` and reader state directly. | The view is a main-actor presentation projection over the live PDFKit object. A background job must never mutate or replace this object concurrently with `PDFView` updates. |

The existing native performance plan already identifies the relevant future work: instrumentation before tuning, page-scoped invalidation, bounded caches, visible-window rendering, cancellation, background parse/detect work, and memory pressure handling in `docs/roadmaps/performance-roadmap-2026-08-24.md:45-118`. The 2026-08-25 Lane A implementation report and [`performance-realignment-2026-08-25.md`](performance-realignment-2026-08-25.md) now refine that plan with the six-stage measurement contract, current provider wiring, checkpoint/redo boundary, and value-free corpus input contract. This document narrows the broad plan to the PDFKit and AppModel ownership constraints that must be resolved first.

## Invariants that must not move

1. The inspected source is identified by the source SHA-256. An operation with a stale source digest must still fail closed.
2. The live source file is never overwritten by an export. The source remains unchanged if staging, validation, or publication fails.
3. Edited output is written to a temporary location, reopened and validated, and only then moved or atomically replaced at the requested destination.
4. No-op export continues to copy source bytes rather than needlessly reserializing an imported PDF.
5. Operations are applied in their existing deterministic order. A faster replay or cache must not change the visible operation history or provider-neutral result.
6. `PDFView` never observes a `PDFDocument` that is being mutated by another executor.
7. A canceled or stale open cannot publish inspection, source data, or a live document over a newer open request.
8. Cancellation before export publication removes the staged temporary artifact. Cancellation after publication begins cannot claim rollback unless an explicit recoverable publication protocol exists.
9. Passwords, source text, raw PDF bytes, and sensitive metadata do not enter performance logs, task labels, cache keys visible to users, or telemetry.
10. Derived render or parse caches are disposable and invalidatable. They are never the authoritative source for undo, export, or recovery.
11. Provider-neutral contracts remain independent of PDFKit classes. Future providers must be able to implement the same value-level orchestration boundary.

## Decision for this lane

No changes are made to `PDFKitProvider.swift`, `AppModel.swift`, `ContentView.swift`, `DocumentModel.swift`, or `Package.swift` in this pass.

The tempting changes are not yet safe from source inspection alone:

- `Task.detached` around `PDFKitProvider.inspect` or `export` would assume that every PDFKit and AppKit object used by the provider is safe on that executor. The current code and protocol do not declare or enforce that assumption.
- A concurrent render or export queue could overlap reads, live-document mutations, validation, and `PDFView` updates. A serial queue alone would not fix stale-result publication or lifecycle ownership.
- Adding `Task.checkCancellation()` at the call boundary would only cancel before or after a synchronous PDFKit call. It would not stop a full inspection, raster comparison, serialization, or file copy already in progress.
- Evicting `cachedSourceData` would remove the current fast undo source. A memory cap cannot be selected responsibly until peak memory is measured against file size, page count, and the live document.
- Adding a custom page-image cache is premature while `PDFView` remains the native renderer and its own internal caching policy is not measured. A second cache could increase memory without reducing work.
- Changing temporary-file naming or publication would risk the existing atomic-save and collision behavior without a failure-injection result.

## Proposed native runtime design

### 1. Introduce a bounded work coordinator at the app boundary

Use a single bounded native PDF work lane for operations that create or mutate PDFKit documents. The initial capacity should be one in-flight PDFKit job, with no unbounded task group and no concurrent mutation of the same source session.

The coordinator should accept value-only request snapshots:

- source URL and an opaque session/request identifier;
- source digest when one is already known;
- operation values copied before leaving `AppModel`;
- destination URL for export;
- a private cancellation handle and a monotonic request generation.

The coordinator should return only `DocumentInspection`, `ExportResult`, errors, and small progress values. It should not return `PDFDocument`, `PDFPage`, `PDFAnnotation`, `NSImage`, or a source `Data` blob through a provider-neutral `Sendable` contract.

Open requests should be latest-wins. Starting a newer open cancels the prior request and makes its generation stale immediately. The completion handler must check both cancellation and generation on the main actor before assigning `inspection`, `liveDocument`, `sourceURL`, or `cachedSourceData`.

Export requests should be snapshot-based. The export worker must use the exact source URL, operation list, and source digest captured when the user confirmed the save panel. Later UI edits must not mutate that worker's input. A later export may supersede an earlier queued export, but an export that has begun destination publication must finish its existing atomic protocol or report a precise failure.

This coordinator is an app orchestration layer. It should not make `PDFKitProvider` silently actor-isolated or change `PDFProvider` for all providers until the provider-neutral async contract is designed and adopted deliberately.

### 2. Add cooperative cancellation only at explicit stage boundaries

Cancellation should be checked at these boundaries:

1. Before acquiring a security-scoped URL and before reading source bytes.
2. After input-size validation and before PDFKit construction.
3. Between page-level inspection units where the provider can safely release local references.
4. Before vector parsing and candidate detection, and between independent page batches if batching is introduced.
5. Before creating a staged export file.
6. Between operation applications only if the operation ledger can safely abandon the in-memory document.
7. Before validation, before reopening, and immediately before publication.
8. After cleanup, before publishing a canceled result to the main actor.

Cancellation is advisory inside individual PDFKit and `FileManager` calls. The user-visible state must say that the request was superseded or canceled, not imply that the underlying call was preempted. A temporary output must be removed on every pre-publication cancellation or failure path.

The security-scoped resource must remain active across the entire worker lifetime, including all staged reads and validation reads. It must be stopped exactly once after the worker has finished or failed.

### 3. Keep the main actor as the PDFView ownership boundary

The main actor should continue to own:

- `liveDocument` as the presentation projection;
- SwiftUI reader controls and selection state;
- operation-ledger mutations initiated by user interaction;
- installation of a completed inspection or freshly rebuilt preview.

The worker may construct a private `PDFDocument` for inspection or export, but it must never mutate `liveDocument`. If a future background edit path is needed, it should build a replacement document from an immutable source snapshot and operation snapshot, then publish the replacement only after the main-actor generation check succeeds.

The current direct edit and undo paths should remain synchronous until the replacement-document protocol exists. This keeps `PDFView` from observing partial annotation mutations.

### 4. Formalize source and derived cache policy

The current source cache should be modeled as a session-owned undo snapshot, not as a general LRU. Its initial policy should be:

- one source snapshot for the active document session;
- keyed by the inspected source digest and byte count;
- retained while undo or export recovery depends on it;
- cleared when the session is replaced or explicitly closed;
- never logged or serialized as performance telemetry.

Do not evict the active undo snapshot merely because a derived render cache is full. If memory pressure requires eviction, the app needs an explicit recovery path that rereads the source URL while preserving the source digest and security-scoped access rules.

Any future derived page cache should be separate and cost-bounded. Its key should include at least source digest, page index, crop/rotation state, scale or pixel dimensions, and render intent. An edit or rotation that changes pixels must invalidate affected entries. The cache should use `NSCache` or an equivalent cost-aware store only after the cost unit is defined and measured; count-based limits alone are not a memory budget.

The first optimization target should be duplicate source reads during `AppModel.open`. A future read session can stage source bytes once, derive the digest and size from that snapshot, and feed provider internals without exposing PDFKit objects across the boundary. This must be designed so that no-op export still copies the original bytes and password handling remains private.

### 5. Treat PDFView as the initial renderer

The current app uses `PDFView` through `PDFKitView` and passes the live document directly from `AppModel`. Do not introduce a parallel page-raster renderer or prefetch cache until a profile proves that `PDFView` is the bottleneck.

If a later profile identifies a native raster bottleneck, use a visible-page plus small prefetch window, with a hard pixel-cost budget and cancellation of stale page requests. The cache must be invalidated by source digest, page index, rotation, scale, crop box, and operation revision. A low-quality preview may be used only as an explicitly labeled intermediate state and must not become export or inspection truth.

### 6. Preserve I/O staging and deterministic publication

The current export sequence is the canonical write path:

1. Read and digest the source.
2. Reject source/destination identity and unsupported edit classes.
3. Apply operations to a private document or copy unchanged source bytes for no-op export.
4. Write to a temporary file.
5. Reopen and validate source preservation, geometry, fields, operations, text impact, and raster impact.
6. Move or replace the destination only after validation passes.
7. Remove the temporary artifact on every failure before publication.

Background execution must wrap this sequence, not reorder it. Temporary files should remain in the destination directory so that the final move or replacement retains the current same-volume atomicity assumptions. Do not claim byte-identical edited output; preserve deterministic operation semantics and validation outcomes. Exact byte identity remains appropriate for the existing no-op copy path.

## Implementation sequence for a later pass

### Phase A: measurement and contract preparation

- Use the existing six-stage, privacy-safe telemetry contract for measurement; `open_load` and the full `save` export boundary are described as provider-wired, while page-render, detection, undo, redo, and standalone benchmark seams still need ownership-confirmed integration.
- Add peak-memory measurements around open, inspection, undo rebuild, export mutation, validation, and publication.
- Use a fixed corpus described by input byte count, page count, text density, annotation count, vector complexity, encryption state, and image presence. Do not log source names or content.
- Record queue depth, canceled request count, stale-result drops, temporary-file cleanup outcomes, and first-page readiness.
- Define the cancellation, generation, and publication state machine before moving work off-main.

### Phase B: latest-wins open orchestration

- Add an `AppModel` request generation and one cancelable open task.
- Snapshot the URL and password handling state without retaining the password in diagnostics.
- Move only value-level inspection work behind the coordinator after PDFKit executor behavior is accepted.
- Construct or install `liveDocument` on the main actor, or define a reviewed replacement-document handoff if construction is proven safe off-main.
- Add stale-result and canceled-open coverage before enabling the UI path.

### Phase C: snapshot export orchestration

- Snapshot source URL, source digest, operations, and destination on the main actor.
- Run staged write and full validation in the bounded native lane.
- Keep publication as the last irreversible step and make the post-publication state explicit.
- Ensure a second export cannot mutate or reuse the first export's private PDFKit document.

### Phase D: memory and render policy

- Measure whether duplicate source data, live PDFKit documents, validation documents, vector arrays, candidate arrays, and raster comparison images dominate peak memory.
- Optimize duplicate reads and temporary object lifetime before adding caches.
- Add only a cost-bounded derived cache with source/revision invalidation and memory-pressure eviction.
- Profile `PDFView` before adding custom page rendering.

## Acceptance gates

The implementation is not ready to claim performance improvement until all of the following are established:

1. Open, undo, direct edit, search, rotate, and export remain behaviorally equivalent on the existing native corpus.
2. A stale open or export completion cannot overwrite a newer `AppModel` state.
3. Cancellation removes pre-publication temporary output and leaves the source and prior destination unchanged.
4. Export validation remains enabled and continues to reopen the staged output before publication.
5. Source-digest binding and no-overwrite behavior remain fail-closed.
6. Peak memory is reported separately for source bytes, live document, validation document, raster comparisons, and derived caches where possible.
7. No sensitive PDF content, password, source path, or raw bytes appear in diagnostics.
8. The provider-neutral contracts remain free of PDFKit/AppKit object types.
9. The fixed corpus shows a measured latency or memory improvement with no fidelity regression.
10. The result is described as static, targeted, integration, or runtime evidence accurately; a benchmark does not become a production claim.

## Unresolved risks

- PDFKit thread affinity and internal object safety are not established by this source inspection. This is the primary blocker for `Task.detached` or multi-threaded PDFKit work.
- `PDFView` may retain or access the live document during SwiftUI/AppKit updates. Replacing the document from a completion callback needs an observed lifecycle proof, not only a type-check.
- A synchronous PDFKit call may not honor cancellation until it returns. The UI needs a stale-result policy in addition to cooperative cancellation.
- The current source cache is required for fast undo. Memory pressure behavior must not silently turn undo into an unbounded or unreliable disk reread.
- Export validation intentionally constructs additional source and output documents and raster comparison state. Moving mutation off-main without accounting for validation can increase peak memory.
- Security-scoped URLs, sandbox permissions, and save-panel destination access must cover all worker I/O, not only the initial open callback.
- Concurrent exports to the same destination need an explicit last-writer or rejection policy. The current synchronous path does not define that future race.
- Native PDF output can contain provider-specific serialization details. The required determinism is stable operation semantics and validated logical output, not an unsupported byte-for-byte claim for edited PDFs.
- Existing roadmap targets such as visible-window rendering, page caches, and memory-pressure hooks remain proposals until instrumentation identifies their actual cost and invalidation behavior.

## Files intentionally changed

- `docs/roadmaps/performance-lane-d-native-runtime.md`: records the current native runtime facts, the documentation-only decision, invariants, proposed bounded executor and cache design, acceptance gates, and unresolved risks.

No Swift source, package configuration, tests, benchmarks, generated artifacts, or runtime state were changed in this lane.

The companion [`../../benchmark/performance-corpus-manifest.json`](../../benchmark/performance-corpus-manifest.json)
is a proposed value-free input contract, not a runtime corpus result. The
2026-08-25 realignment records which fields remain null/TODO until an authorized
measurement flow populates them. Historical parity and preservation outputs are
not substituted for native runtime evidence.

## Next decision

The next implementation pass should begin with Phase A measurement and a reviewed cancellation/generation state machine. It should not begin by wrapping the existing synchronous provider in `Task.detached`. Once PDFKit executor behavior, memory ownership, and stale-result handling are established, the coordinator can be implemented while keeping `PDFProvider` provider-neutral and the current atomic export path intact.
