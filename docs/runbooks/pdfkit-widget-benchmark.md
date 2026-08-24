# Runbook: PDFKit Widget and AcroForm Benchmark

**Purpose:** Exercise PDFKit widget creation and external AcroForm round-trip
behavior without touching the Form 6 source.
**Authorization boundary:** Reversible local benchmark artifacts only. Do not
process arbitrary personal PDFs, install dependencies, upload documents, or run
Git mutations.
**Last validated:** 2026-08-23; synthetic lane passed, public AcroForm lane failed
the radio-choice preservation gate.

## Prerequisites

- macOS with Xcode and the macOS SDK.
- `jq`, Poppler tools, and ImageMagick `compare` for independent checks.
- The public sample artifact at `benchmark/results/public-sample-form.pdf`, or an
  explicitly authorized replacement passed through `PDF_EDITOR_ACROFORM_BENCHMARK_INPUT`.

## Commands

Synthetic PDFKit widget annotations:

```bash
PDF_EDITOR_WIDGET_BENCHMARK_OUTPUT_DIR=benchmark/results/2026-08-23-pdfkit-widgets \
  bash benchmark/test_pdfkit_widget_benchmark.sh
```

Public/external AcroForm:

```bash
PDF_EDITOR_ACROFORM_BENCHMARK_OUTPUT_DIR=benchmark/results/2026-08-23-public-acroform \
  bash benchmark/test_pdfkit_acroform_benchmark.sh
```

The public command is expected to exit nonzero for the current sample because the
no-op widget-state gate detects lost radio choices. Preserve its JSON and PDFs;
do not weaken the assertion to force a pass.

## Required Evidence

- Record the exact input path, source SHA-256, provider/SDK target, command, JSON
  result, output PDFs, and independent Poppler checks.
- Compare original/no-op rendering locally with `cmp`; use pixel tolerance for
  cross-renderer comparisons.
- Compare source/no-op extracted text while accounting for expected mutation text
  in mutated outputs.
- Treat missing radio/choice values, field-name warnings, source changes, reopen
  failures, and unexpected widget-count changes as fidelity failures.

## Recovery

- Preserve failed artifacts and the machine result.
- Do not use unrelated Desktop or workspace PDFs as fixtures without exact target
  selection and authorization.
- Update [`../pdfkit-widget-benchmark.md`](../pdfkit-widget-benchmark.md),
  [`../../findings.md`](../../findings.md), and [`../../progress.md`](../../progress.md)
  after each new fixture lane.
