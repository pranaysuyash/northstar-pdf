# Package-visible performance benchmark harness

**Date:** 2026-08-25
**Status:** source and package target specified; runtime evidence intentionally open
**Owner:** package-visible native performance lane
**Write set:** `Sources/PDFPerformanceBenchmark/main.swift` and this report

## Outcome

The package now exposes an additive `PDFPerformanceBenchmark` macOS executable
target. It is a benchmark harness only. It does not change production app
behavior, provider contracts, fixture governance, export semantics, or the
existing macOS 15 package platform.

The harness accepts either repeated explicit fixture paths or a JSON manifest:

```text
PDFPerformanceBenchmark --fixture <path> [--fixture <path> ...] [--inspect]
PDFPerformanceBenchmark --manifest <path> [--inspect] [--export \
  --export-output-directory <path>]
PDFPerformanceBenchmark --manifest <path> --render-page <zero-based-index> [--memory]
```

Provider work is opt-in. Without `--inspect` or `--export`, the harness parses
inputs and emits `not_requested` fixture rows without opening a PDF. Inspection
is requested only by `--inspect`. A single page render is requested only by
`--render-page <zero-based-index>` and opens a private `PDFDocument`/`PDFPage`
owned by the harness. It draws into a bounded bitmap context through
`PDFPerformancePageRenderer.draw`; no raster bytes are retained or serialized.
Export is requested only by `--export`, uses the provider's existing
zero-operation export contract, and requires an explicit output directory.
Existing output files are blocked rather than silently replaced by the harness.
`--memory` is an opt-in modifier: it samples native process memory immediately
before and after the requested fixture work, and does nothing by itself.

The manifest shape is intentionally small and value-free:

```json
{
  "fixtures": [
    {
      "id": "reviewed-fixture-label",
      "path": "../benchmark/results/example.pdf",
      "passwordEnvironmentVariable": "PDF_BENCHMARK_PASSWORD"
    }
  ]
}
```

The password value is read only from the named process environment variable,
never serialized, and never placed in a report. Fixture IDs are caller-supplied
labels; explicit paths receive ordinal IDs. Reports do not include paths,
source digests, extracted text, field values, PDF metadata, error descriptions,
or export paths.

## API boundary and telemetry decision

The current core APIs provide `PDFKitProvider.inspect(url:password:)`,
`PDFKitProvider.export(url:operations:to:)`, `DocumentInspection` structural
collections, and `ExportResult.report`. `PerformanceTelemetry` is explicitly
constructed by the harness with a bounded capacity and enabled only when
inspection, rendering, or export was requested. The harness records only the
outer requested provider spans as `open_load` and `save`, plus the explicit
`page_render` span, then emits the core's value-free `PerformanceSummary`
records.

There is one exact limitation in the current APIs: `PDFKitProvider` internally
uses `PerformanceTelemetry.shared` and does not accept an injected telemetry
instance. The harness therefore cannot claim provider-internal span ownership;
its explicit instance measures the complete synchronous provider call. This is
safe for a package-visible baseline because it keeps the measurement boundary
honest and does not modify the provider or production call sites. A future
injection change would need a separate core ownership decision and focused
evidence before replacing this wrapper.

The export request is likewise deliberately bounded. The current package
exposes `EditOperation`, but no benchmark-manifest contract for reconstructing
reviewed non-empty operations. The harness uses `operations: []` only, so an
export baseline means the existing no-op provider export path, including its
staging, validation, and publication contract. It does not imply edit, undo,
redo, or fidelity coverage for a mutation.

The render request is separate from provider inspection and export. It does not
call `PDFKitProvider`, does not mutate the source document, and does not emit
PNG bytes, page images, PDF bytes, page content, or source paths. A render page
index is zero-based and must be supplied once. The bitmap context has a maximum
dimension of 2048 pixels on either axis; the page is scaled down to that bound
before `PDFPerformancePageRenderer.draw` is called.

Memory sampling is separate from timing telemetry. When `--memory` is absent,
the report contains no memory field. When it is present with requested work,
each fixture may contain only numeric `before` and `after` snapshots from
`NativeMemoryTelemetry`; sampling failure is represented by a nullable snapshot
without changing the requested work. `--memory` without `--inspect`,
`--render-page`, or `--export` leaves fixtures `not_requested` and does not
sample.

## Report contract

The JSON schema is `pdf-editor.performance-benchmark.v1`. It contains:

- requested operation names and per-fixture status codes;
- inspection counts for pages, fields, candidates, links, outlines,
  attachments, and warnings;
- export completion/validation status and the provider's reopenability result;
- render completion status for the explicitly requested page, without image
  or document content;
- bounded `PerformanceSummary` values only when the requested operation really
  ran; and
- optional native memory snapshots only when `--memory` was supplied with
  requested work; and
- nullable run metadata placeholders for timestamps, OS, architecture, Swift,
  package revision, warm/cold policy, and corpus manifest identity.

Nullable metadata is intentional. The harness does not infer compiler, SDK,
revision, cache state, fixture identity, or benchmark policy from the local
process and does not fabricate a baseline when no run has supplied those facts.
The harness source also does not run a benchmark during this change.

## Preserved boundaries

- Existing products and targets remain unchanged apart from the additive
  executable product and target.
- The package remains macOS 15.
- Provider inspection and export are never implicit.
- The harness does not use extracted PDF values as identifiers or output fields.
- Provider errors are reduced to stable classes such as `provider_error` and
  `operation_failed`; localized details are not serialized.
- No source fixture is generated, copied, overwritten, staged, or committed by
  the implementation itself.
- Telemetry is bounded, opt-in at the core primitive, and value-free; the
  harness's explicit instance is enabled only for the requested run.

## Evidence and open work

This is a Tier 1 static implementation result. Per task instruction, no tests,
builds, benchmarks, or verification commands were run. The following remain
unclaimed until an explicitly authorized verification flow records them:

- package compilation and executable launch on the target macOS environment;
- actual warm/cold policy, run timestamps, toolchain, architecture, and
  revision metadata;
- fixed fixture byte identity, provenance, and corpus completeness;
- provider-internal telemetry separation from the harness's outer spans;
- actual page-render and memory-sampling runs, plus non-empty edit export,
  undo/redo, detection, crash,
  cancellation, and recovery measurements; and
- independent source-integrity, reopen, geometry, form, text, raster, and
  viewer evidence for any mutation-capable export.

No performance threshold, production claim, release claim, or provider adoption
claim is made by this target or report.

## Rollback and revisit trigger

Rollback is additive: remove the `PDFPerformanceBenchmark` product/target and
the new source/report, leaving all existing targets and core APIs intact. Revisit
this report when the provider accepts injected telemetry, a reviewed operation
manifest contract exists, or the owning verification flow is authorized to
populate the currently nullable run metadata and evidence fields.
