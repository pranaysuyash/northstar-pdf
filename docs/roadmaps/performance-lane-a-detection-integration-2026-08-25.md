# Performance Lane A: Detection Integration

Date: 2026-08-25
Status: implemented, static inspection only
Owner: provider detection timing on the shared main checkout

## Outcome

`PDFKitProvider.inspection` now records an opt-in `detection` measurement around
the existing `StaticRegionDetector.detect(lines:vectorGeometries:)` call. The
wrapper is synchronous and returns the detector result directly. No detector
inputs, outputs, ordering, coordinate values, or error paths were changed.

The measurement boundary deliberately excludes the preceding
`PDFVectorStreamParser.parse(data:)` call and all surrounding inspection work.
It therefore measures the actual vector/text candidate detection call only.

## Timing boundaries

The timing surfaces are nested when inspection is reached through the normal
provider flows:

| Span | Boundary | Meaning |
| --- | --- | --- |
| `open_load` | Existing `PDFKitProvider.inspect` closure | Combined open timing: source load, PDFKit document creation and unlock, page and annotation inspection, text-selection geometry, vector parsing, static-region detection, and result assembly. |
| `detection` | New closure around `StaticRegionDetector.detect(...)` | Nested detector timing: vector/text candidate generation only. It does not include source loading, PDFKit parsing, text-selection extraction, vector-stream parsing, or result assembly. |
| `save` | Existing `PDFKitProvider.export` closure | Combined export timing: source load and inspection, including any nested detection measurement, operation application, writing, validation, cleanup, and publication. |

`open_load` remains the combined open measurement; it is not replaced by the
narrower detector measurement. When detection is enabled, the nested span can
be compared with the surrounding open or save span, but it should not be
treated as an independent end-to-end open or export duration.

## Default-off and privacy behavior

Timing is disabled by default. `PerformanceTelemetry.shared` records timings
only when `PDF_EDITOR_PERF_TELEMETRY=1` is present, while benchmark callers may
explicitly construct an enabled recorder. With telemetry disabled,
`measureDetection` executes and returns the detector closure result without
recording an event.

The integration adds no document identifiers, paths, text, field values,
coordinates, PDF bytes, or error descriptions to telemetry. The existing
bounded recorder and value-free signpost behavior remain authoritative.

## Preserved contracts

- The existing `open_load` span remains in place and still covers the complete `inspect` operation.
- The existing provider `save` span remains in place and still covers the complete `export` contract.
- Vector parser output is produced at the same point and passed unchanged to the detector.
- Detector candidate ordering and abstention behavior are unchanged.
- Existing coordinate semantics are unchanged; no coordinate transform was added.
- Existing provider errors and thrown-error propagation are unchanged.
- No asynchronous work, caching, field heuristics, or detector algorithm changes were added.

## Evidence and limitations

This change has Tier 1 static evidence only. The source boundary and telemetry
contract were inspected, but tests, builds, benchmarks, runtime checks, and
verification commands were intentionally not run for this handoff.

The next measurement step, owned by the benchmark or app operator, is to run a
controlled opt-in corpus capture and report `open_load` or `save` as the outer
combined stage while reporting `detection` as its nested stage. Any performance
claim still requires that separate measurement evidence and the existing
fidelity and abstention gates.

## Rollback and revisit trigger

Rollback is local and additive: remove the `measureDetection` wrapper and this
report, leaving the existing `open_load` and `save` spans untouched. Revisit
when benchmark collection is authorized and can distinguish nested detection
cost from the surrounding provider operation without changing the provider's
semantic contracts.
