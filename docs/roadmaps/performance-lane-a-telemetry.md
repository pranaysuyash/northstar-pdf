# Performance Lane A: Telemetry and benchmark contract

**Status:** Six-stage instrumentation primitive with `inspect`/`export` provider-boundary wiring described in the 2026-08-25 follow-up; remaining stage seams and runtime baselines remain open
**Owner:** Performance Lane A
**Date:** 2026-08-24
**Write set:** `Sources/PDFEditorCore/PerformanceTelemetry.swift` and this report only

## Outcome

The native core now has one opt-in timing primitive for the six performance
stages that matter to the PDF editor: `open_load`, `page_render`, `detection`,
`undo`, `redo`, and `save`. It records monotonic durations, success/failure status,
P50/P95 summaries, and no document content. The recorder is disabled by default,
keeps a bounded in-memory ring when enabled, and emits value-free `os_signpost`
intervals for Instruments.

This is a Tier 1 static implementation claim. No tests, benchmarks, or runtime
verification were run for this lane, by instruction.

The dated [`performance-lane-a-implementation-2026-08-25.md`](performance-lane-a-implementation-2026-08-25.md)
report narrows the former "call-site wiring remains open" statement: it describes
`open_load` wiring at `PDFKitProvider.inspect` and `save` wiring around the full
`PDFKitProvider.export` contract. It does not establish page-render, detection,
undo, redo, standalone benchmark-harness, or runtime coverage.

## Current architecture and ownership boundary

The checkout contains a Swift Package with an auto-discovered `PDFEditorCore`
target, a SwiftUI app target, and standalone Swift sources under `benchmark/`.
The entire checkout is currently presented as untracked, so ownership of
existing shared files cannot be safely inferred. This lane therefore adds only a
new core source file and does not edit `Package.swift`, `PDFKitProvider.swift`,
`AppModel.swift`, `ContentView.swift`, or existing benchmark harnesses.

The new source is automatically part of the existing `PDFEditorCore` target.
No package target or dependency change is required. The public API is generic so
the owning lanes can wrap their existing operations without passing document
objects or identifiers to telemetry.

## Instrumentation contract

### Stages

| Stage | Span boundary | Required caller seam |
|---|---|---|
| `open_load` | Start immediately before the provider opens/loads a source; end after the load/inspection result is available | `PDFKitProvider.inspect` or the app open task |
| `page_render` | `PDFPage.draw(with:to:)` only; image encoding and view layout are separate | `PDFPerformancePageRenderer.draw` or an equivalent existing renderer |
| `detection` | Detector entry through candidate result, including parser input already prepared for that detector | `StaticRegionDetector.detect` call site |
| `undo` | User undo request through the restored visible state | `AppModel.undoLastEdit` or the owning history lane |
| `redo` | User redo request through the restored visible state | A redo operation must first exist in the app architecture |
| `save` | Provider serialization/copy and atomic output publication; reopen/fidelity validation should be recorded as a separate contract result | `PDFKitProvider.export` save boundary |

`PerformanceTelemetry.measure` is the canonical closure seam. The span handle
returned by `begin` is available for callbacks with early returns. Failed spans
are retained as failures with their duration, but no error text is captured.

### Privacy and production behavior

- Enablement is opt-in through `PDF_EDITOR_PERF_TELEMETRY=1` or an explicitly enabled benchmark instance.
- The default singleton is disabled, so an ordinary production run adds no ring-buffer writes.
- The ring capacity defaults to 512 and is bounded by construction.
- Samples contain only stage, duration, and outcome.
- Signposts contain only a static interval name; stage identity is in the in-memory sample, not a document-derived string.
- No path, filename, digest, extracted text, field value, page object, error description, or PDF bytes are retained or logged.
- `NSLock` is held only while appending or copying a tiny bounded sample buffer; the measured operation itself never runs under the lock.

## Reproducible corpus metadata contract

Corpus metadata is benchmark input and must remain separate from production
telemetry. Each case is identified by a stable value-free `corpusId`, not a
user filename. The manifest schema is:

```json
{
  "schemaVersion": 1,
  "corpusId": "static-form-001",
  "fixtureClass": "static-text-form",
  "sourceSha256": "<digest of the exact fixture bytes>",
  "byteCount": 123456,
  "pageCount": 2,
  "rotationDegrees": [0, 0],
  "textMode": "selectable",
  "formMode": "none",
  "provenance": "reviewed-local-fixture",
  "expectedGates": ["reopen", "page-geometry", "source-unchanged", "fidelity"]
}
```

Required corpus classes are static text forms, native AcroForms, mixed
text/image pages, raster-only scans, rotated pages, repeated multi-page input,
encrypted input, and malformed/truncated input. A metadata record must include
the exact byte digest, byte count, page count, rotations, text/form class, and
provenance. It must not include extracted text, field values, image pixels, or
user document paths.

Every timing result must also record run metadata outside the telemetry sample:

```json
{
  "runSchemaVersion": 1,
  "runId": "2026-08-24T00:00:00Z-static-form-001",
  "corpusId": "static-form-001",
  "platform": "macOS 15.x arm64",
  "swiftAndSdk": "<compiler and SDK versions>",
  "buildConfiguration": "release",
  "processIsolation": "new-process-per-cold-case",
  "warmupIterations": 3,
  "measuredIterations": 15,
  "telemetryCapacity": 512
}
```

The run record must preserve the harness version and environment details. Do
not call a result reproducible if the fixture digest, provider version, build
configuration, or process/cache policy is missing.

## Warm and cold rules

Cold means a new benchmark process for the case, with the first open counted and
without claiming that OS filesystem caches were purged. If cache purging is not
controlled, label the run `process-cold/filesystem-cache-unknown` rather than
simply `cold`.

Warm means one process and one loaded case reused for the measured sequence.
Run three warm-up iterations, discard them, then collect at least 15 measured
iterations. Do not mix cold and warm samples in one percentile series. Keep
provider and fixture order stable, and report failures rather than dropping
outliers.

P50 and P95 use nearest-rank selection over completed stage durations, with
rank `ceil(n * percentile)` clamped to the final sample. The implementation
reports failed samples in the same distribution and exposes failure count
separately; a fast failure cannot improve a gate.

## Performance gates

These are target gates from the existing performance roadmap, not verified
results:

| Gate | Target | Classification |
|---|---:|---|
| Warm first usable page | P50 < 2.0 s | Must be measured on the target Mac profile |
| Mixed 15-20 page open/load | P95 <= 5.0 s | Includes the open/load boundary; page render is reported separately |
| Small-to-moderate undo | P95 <= 250 ms | Undo and redo reported independently when redo exists |
| Detection responsiveness | No UI-thread blocking attributable to detection | Requires runtime observation, not a timing JSON alone |

Performance gains are rejected when they regress the fidelity or crash gates.

## Fidelity and crash gates

Every performance run that includes save or mutation must retain these gates:

- Source SHA-256 remains unchanged.
- Output is written to a new or atomically replaced destination and reopens in PDFKit.
- Page count, boxes, rotation, and expected text/form inventory are preserved unless the operation explicitly changes them.
- Existing independent preservation checks and visual comparison gates remain green; a timing pass never overrides a fidelity failure.
- Detector changes preserve the reviewed candidate contract, including abstention and known negative fixtures.
- Zero process crashes, hangs, watchdog timeouts, or unbounded memory growth across the corpus.
- A malformed, encrypted, or oversized input fails closed with a bounded error path and no telemetry content leak.

The existing AcroForm evidence already contains a preserved failure where a
no-op PDFKit save loses radio-choice metadata. That failure must remain visible
in performance runs; the instrumentation must not turn it into a success.

## Integration points still open

The current wiring posture is:

| Stage | Current status | Evidence boundary |
|---|---|---|
| `open_load` | Provider-boundary wiring described at `PDFKitProvider.inspect` | Tier 1 static implementation report; no runtime emission claim |
| `save` | Provider-boundary wiring described around the full `PDFKitProvider.export` contract, including reopen/fidelity validation before publication | Tier 1 static implementation report; export validation remains authoritative |
| `page_render` | Renderer seam exists, but coverage of every app or standalone benchmark render path is not established | Open integration seam |
| `detection` | Detector call-site coverage is not established | Open integration seam |
| `undo` | Not wired; Lane B currently uses bounded checkpoints plus cached-source fallback | Open integration seam; no timing result |
| `redo` | Not wired because a real redo transition is not part of the current native surface | Proposed only after redo semantics exist |

Standalone benchmark-harness integration also remains open. The additive
primitive and the two provider wrappers therefore prove the measurement
contract and safe storage behavior only. They do not prove app-level latency,
UI non-blocking behavior, crash freedom, or production performance.

The [`performance-realignment-2026-08-25.md`](performance-realignment-2026-08-25.md)
record is the current evidence vocabulary and cross-lane dependency contract.
Its companion [`../../benchmark/performance-corpus-manifest.json`](../../benchmark/performance-corpus-manifest.json)
is a proposed value-free input contract with null/TODO measurement fields, not
a completed baseline. Existing governance remains owned by
`Tests/fixtures/pdf_corpus_governance_manifest.json`.

## Rollback and revisit trigger

Rollback is additive and local: remove the new source and report if the package
needs to return to the pre-instrumentation surface. Revisit when the app owner
confirms call-site ownership, a redo path exists, and the benchmark harness can
compile the core instrumentation. The next evidence target is Tier 2/S1 for
contract shape plus Tier 2/S1 warm/cold benchmark output, followed by Tier 3
runtime evidence for non-blocking UI and crash/fidelity gates.
