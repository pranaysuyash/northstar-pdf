# Runbook: PDFKit Benchmark

**Purpose:** Re-run the native PDFKit evaluation without modifying the source PDF.
**Authorization boundary:** Reversible workspace/test artifacts only. Do not run
  Git mutations, install dependencies, upload documents, or overwrite the source.
**Last validated:** 2026-08-23; Tier 2/S1 Form 6 pass with documented Poppler variance.
**Owner:** Project owner.

## Prerequisites

- macOS with Xcode and the macOS SDK.
- Swift compiler available through `xcrun swiftc`.
- `/Users/pranay/Desktop/RAr0Lq2Avu.pdf` present with the recorded SHA-256.
- `pdfinfo`, `pdftotext`, and `pdftoppm` are useful independent checks but are not
  required by the Swift harness itself.

## Command

From `/Users/pranay/Projects/pdf_editor`:

```bash
bash benchmark/test_pdfkit_benchmark.sh
```

To preserve artifacts at a known path:

```bash
PDF_EDITOR_BENCHMARK_OUTPUT_DIR=/tmp/pdfkit-form6-run \
  bash benchmark/test_pdfkit_benchmark.sh
```

The test compiles `benchmark/PDFKitBenchmark.swift` with system frameworks only,
runs it against Form 6, and checks the JSON result plus original/no-op render
artifacts.

For an optional independent Poppler cross-check, render the original and no-op
outputs with `pdftoppm` and inspect pixel differences with a documented tolerance.
Do not require PNG byte equality across different renderers; the PDFKit harness's
original/no-op PNG comparison is the deterministic provider-local oracle.

## Expected Signals

- Exit status `0`.
- JSON reports `provider = PDFKit`, `pages = 2`, `nativeWidgetCount = 0`,
  `noOpReopen = true`, `overlayReopen = true`, and `originalUnchanged = true`.
- Original and no-op PNG artifacts compare byte-for-byte.
- The source SHA-256 remains `2cf1421343c22676f15eff0ec6f31a4df6e7f7975dc0f3d88d2b29a1dcc79d34`.
- PDFKit's extracted page text remains unchanged after the bounded annotation;
  another extractor may include the expected annotation contents in its output.

## Native Widget Corpus Lane

The separate native-widget harness exercises PDFKit-created text, checkbox, radio,
choice, and signature widgets without using product code:

```bash
PDF_EDITOR_WIDGET_BENCHMARK_OUTPUT_DIR=/tmp/pdfkit-widgets-run \
  bash benchmark/test_pdfkit_widget_benchmark.sh
```

It must report six widgets, reopen the generated fixture, round-trip bounded value
and state mutations, and preserve the generated fixture's source digest. This lane
does not establish compatibility with arbitrary third-party AcroForms; those still
require external fixtures.

## Failure Branches

- **Compiler unavailable:** Record the exact `xcrun`/SDK error; do not substitute a
  different provider without a decision amendment.
- **Input missing or digest mismatch:** Stop before opening or writing; investigate
  the fixture provenance.
- **Open/reopen failure:** Preserve all artifacts and classify the provider lane as
  failed; do not weaken the assertion.
- **Render mismatch:** Preserve both PNGs and the JSON output; treat it as a
  fidelity failure, not a flaky cosmetic check.
- **Overlay verification failure:** Preserve the output and JSON; do not present it
  as a valid export.

## Recovery and Cleanup

- The harness writes only to the selected output directory.
- The original PDF is never an output target.
- Keep failed artifacts until the result is documented; remove only explicitly
  identified temporary outputs after preservation checks.
- Update [`../pdfkit-benchmark.md`](../pdfkit-benchmark.md), [`../../findings.md`](../../findings.md),
  and [`../../progress.md`](../../progress.md) with the command, evidence, and residual risk.
