# Native process-memory observation report

**Date:** 2026-08-25
**Status:** Additive observation primitive implemented; no measurements collected
**Owner:** Bounded native memory observation
**Write set:** `Sources/PDFEditorCore/NativeMemoryTelemetry.swift` and this report only

## Outcome

The native core now has a small, opt-in utility for taking one value-only
snapshot of the current macOS process. `NativeMemoryTelemetry.snapshot()` is
disabled by default and returns `nil` unless the caller explicitly passes
`enabled: true`.

The snapshot contains only these numeric counters:

- `residentBytes`: resident process memory reported by `proc_pidinfo` with
  `PROC_PIDTASKINFO`.
- `virtualBytes`: virtual address-space size reported by the same task
  information record.
- `physicalFootprintBytes`: the macOS physical footprint from
  `proc_pid_rusage` with `RUSAGE_INFO_V4`, when that secondary call succeeds.

The value is `Codable`, `Equatable`, and `Sendable` so a benchmark harness can
place it beside its own fixture and timing metadata without adding a telemetry
store here.

## Privacy and ownership boundary

- The sampler observes only the current process.
- It does not receive, inspect, retain, or serialize paths, PDF bytes, PDF
  content, passwords, document objects, object graphs, filenames, digests, or
  other sensitive metadata.
- It does not log, publish, persist, aggregate, smooth, or cache samples.
- It does not alter `PerformanceTelemetry` or any existing telemetry behavior.
- It is not authoritative for document memory cost, allocator ownership,
  system pressure, or release readiness.
- It is not integrated into `AppModel`, `PDFKitProvider`, or any application
  lifecycle path in this change.

## Units and sampling limitations

All counters are unsigned integer byte counts. The utility intentionally does
not convert bytes to decimal or binary megabytes, because benchmark reports
should choose and state their own presentation unit consistently.

Each call is a best-effort point-in-time observation of process state. It is
not a high-frequency sampler, allocation trace, heap census, leak detector, or
causal attribution mechanism. Resident memory and physical footprint can move
between calls because of paging, compression, shared memory, mapped files,
framework behavior, and operating-system reclamation. Virtual size describes
address-space reservation and should not be treated as physical usage.

The task-information call is required for a snapshot. If it fails, the utility
returns `nil`. The physical-footprint call is independent and may leave
`physicalFootprintBytes` as `nil`; callers must preserve that unknown state.
No value is substituted for an unavailable native counter.

## Platform assumptions

This implementation is intended for the package's macOS 15 platform target and
uses native Darwin `libproc` APIs already available on that platform. The
reported process is the process in which the package code executes. Other
platforms receive no observation through the guarded implementation.

Benchmark owners should record the macOS version, hardware or virtualized
environment, process lifecycle policy, sampling point, fixture identity in
their separate benchmark manifest, and the unit used in any derived report.
Those contextual fields are deliberately outside this value-only primitive.

## Evidence and current state

No measurements have been collected. No benchmark, runtime observation,
baseline, threshold, comparison, or memory improvement claim is made by this
report.

Per the bounded task request, tests, builds, benchmarks, and verification were
not run. The current result is an implementation and documentation change only;
compile compatibility and live counter behavior remain open for the owning
verification flow.

## Follow-up and rollback

The next owner may add a focused compile/test or benchmark harness integration
only after preserving the explicit opt-in and value-only boundary. Any future
report should distinguish raw native observations from benchmark-derived
statistics and should record unavailable counters as unknown.

Rollback is additive and local: remove
`Sources/PDFEditorCore/NativeMemoryTelemetry.swift` and this report. No
existing source, telemetry behavior, application state, cache, or persisted
artifact requires migration.
