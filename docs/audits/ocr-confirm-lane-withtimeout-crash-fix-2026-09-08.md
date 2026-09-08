# OCRConfirmLane.withTimeout crash fix — 2026-09-08

**Classification:** Observed crash (DiagnosticReports) → Verified fix (code inspection + suite runs)

## Symptom

`swiftpm-testing-helper` crashed with `EXC_BREAKPOINT` in
`OCRConfirmLane.withTimeout` during `reEncodingPromotes` (crash report
2026-09-08 08:06; also killed two full-suite runs silently mid-session).
Load-dependent: appeared only under heavy parallel test load.

## Root cause (Observed from the crash report + code)

The pre-fix implementation shared a captured `var result: T?` between the
calling thread and the `DispatchQueue.global().async` closure. When the
deadline fired, the caller could read the boxed local while the background
closure was still writing it — a dynamic exclusivity violation, which traps
via `_assertionFailure` (the EXC_BREAKPOINT frame). The pre-existing
`wait` timeout return value was also ignored, so a timed-out caller read a
half-written result instead of degrading to abstention.

## Fix (Verified in `Sources/PDFEditorCore/OCRConfirmLane.swift`)

- The `wait` result is checked: `guard waited == .success else { return nil }`
  — timeout degrades to `nil` (recorded `timedOut` → abstention), never a
  torn read.
- On `.success`, the semaphore guarantees the closure has finished writing
  before the caller reads — the memory-model hazard is closed without a lock.

Doctrine: §10 Failure (timeout is a degradation path, not a crash), §5
Evidence-based (crash report + two prior silent suite deaths as evidence).

## Disposition

Fix landed 2026-09-08. Full-suite verification pending machine-quiet window
(the same load conditions that exposed the crash also starve verification
runs); standalone suites touching OCRConfirmLane green.
