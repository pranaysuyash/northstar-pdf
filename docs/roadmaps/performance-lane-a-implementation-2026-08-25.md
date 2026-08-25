# Performance Lane A implementation report

**Date:** 2026-08-25
**Status:** Provider-boundary wiring implemented; runtime evidence remains open
**Owner:** Performance Lane A
**Write set:** `Sources/PDFEditorCore/PerformanceTelemetry.swift`, `Sources/PDFEditorCore/PDFKitProvider.swift`, and this report only

## Outcome

The existing opt-in, value-free telemetry primitive is now wired at the two
safe synchronous PDFKit provider boundaries requested for this lane:

- `PDFKitProvider.inspect` records `open_load` from the beginning of source
  loading through PDFKit opening, password handling, inspection, and the
  returned inspection result. This is the combined inspect/open-load boundary.
- `PDFKitProvider.export` records `save` across the full export contract, from
  source loading through source inspection, no-op byte-copy or edited staging,
  reopen/fidelity validation, temporary-file cleanup on failure, publication,
  and the returned export result.

The only primitive correction is the malformed Swift key-path expression in
`PerformanceSummary`. No telemetry payload or public provider contract was
expanded.

## Boundary decision

For this implementation, save timing means the full export-contract duration,
not serialization alone. Reopen and fidelity validation are intentionally inside
the measured span because they are required parts of a successful export in the
current provider contract. A failed validation, rejected export, or publication
failure is therefore recorded as a failed `save` sample for the complete work
performed up to that failure.

This boundary preserves the distinction between a timing sample and the
validation result: the `ExportResult.report` remains the authority for source
integrity, reopenability, geometry, field, text, raster, and applied-operation
checks. Telemetry does not reinterpret or replace those checks.

## Preserved invariants

- Empty-operation exports still use the existing no-op byte-copy branch.
- The source remains protected from overwrite and output publication still uses
  the existing staged temporary URL and atomic replacement or move behavior.
- Source SHA-256 binding and operation source-digest validation are unchanged.
- Reopen and fidelity validation still run before publication.
- Existing temporary-file cleanup remains on validation and publication failure.
- The provider-neutral telemetry API still records only stage, monotonic
  duration, and success or failure outcome.
- Paths, filenames, source digests, PDF bytes, extracted text, field values,
  passwords, document objects, and error descriptions are not sent to
  telemetry or signposts.
- No actor hop, `Task.detached`, geometry change, AppModel change, cache, or
  provider-specific telemetry schema was introduced.

## Evidence and limitations

This is a Tier 1 static implementation result. Tests, builds, benchmarks, and
verification were intentionally not run for this task. There is consequently
no current runtime evidence that the package compiles with the provider wiring,
that opt-in samples are emitted on both success and failure paths, or that the
observed duration matches the intended boundary on a live export.

The following evidence remains open for the owning verification flow:

- compile and focused source-level tests for the corrected primitive and the
  throwing provider wrappers;
- an opt-in native run covering inspect success and failure, no-op export,
  edited export, validation rejection, and publication failure;
- runtime confirmation that telemetry remains empty when the opt-in environment
  variable is absent;
- benchmark runs with fixed fixture digests and separate cold and warm process
  policy; and
- independent fidelity and crash evidence for the existing export contract.

No performance target or release-readiness claim is made by this report.

## Alternatives considered

- Instrumenting `AppModel` or the open task was rejected because the requested
  ownership boundary is the synchronous provider and AppModel is outside the
  write set.
- Measuring only PDFKit serialization was rejected because it would omit
  staged validation, cleanup, and publication that are part of the current
  export contract.
- Adding document identifiers or provider-specific payload fields was rejected
  to preserve the existing privacy and provider-neutral API.

## Rollback and follow-up

Rollback is local and additive: remove the two provider wrapper calls and the
primitive key-path correction while preserving the existing export body. The
next review should run the explicitly listed compile, runtime, benchmark, and
fidelity evidence, then update this report with observed results rather than
promoting static wiring to end-to-end proof.
