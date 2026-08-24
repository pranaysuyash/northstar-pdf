# PDFKit Widget and AcroForm Benchmark

**Status:** Active provider-evaluation record
**Canonical owner:** `/Users/pranay/Projects/pdf_editor/docs/pdfkit-widget-benchmark.md`
**Provider:** PDFKit on macOS
**Evidence:** Tier 2 targeted runtime checks; S1 for each lane

## Purpose

This record separates two claims that must not be conflated:

1. PDFKit can create and reopen its own widget annotations.
2. PDFKit can preserve widget state from an external AcroForm document.

The first claim is a synthetic capability smoke test. The second uses a public
sample AcroForm and is the materially relevant provider gate.

## Synthetic Widget Lane

- **Command:** `PDF_EDITOR_WIDGET_BENCHMARK_OUTPUT_DIR=benchmark/results/2026-08-23-pdfkit-widgets bash benchmark/test_pdfkit_widget_benchmark.sh`
- **Input:** Generated locally by `PDFKitWidgetBenchmark.swift`.
- **Result:** Pass. Six widget annotations were created and reopened: text,
  checkbox, two radio buttons sharing a field name, choice, and signature. The
  filled copy reopened with the text, checkbox, radio, and choice mutations intact.
- **Machine result:** [`../benchmark/results/2026-08-23-pdfkit-widgets/result.json`](../benchmark/results/2026-08-23-pdfkit-widgets/result.json)
- **Fixture SHA-256:** `07f9e8c7ee952701a7721a32fdeea935923fdbcaec60dacf36e62afb1844e0c4`
- **Independent checks:** Poppler reports `Form: none` for the generated input and
  `Form: AcroForm` for the filled output. Both are one-page, unencrypted, and
  JavaScript-free. The generated input is therefore a PDFKit object-model smoke
  fixture, not external AcroForm evidence.
- **Limit:** This does not prove compatibility with externally-authored AcroForms;
  the public lane below is the relevant preservation gate.

## Public AcroForm Lane

- **Source:** [`https://pdftoolskit.org/samples/sample-form.pdf`](https://pdftoolskit.org/samples/sample-form.pdf)
- **Source page:** [`https://pdftoolskit.org/sample-pdfs`](https://pdftoolskit.org/sample-pdfs)
- **Local artifact:** [`../benchmark/results/public-sample-form.pdf`](../benchmark/results/public-sample-form.pdf)
- **Source SHA-256:** `5a681d44622f2ee577808e77f034525314d48a628b9cad26f7788564c9e922e8`
- **Source metadata:** One-page A4 PDF, `Form: AcroForm`, no JavaScript, and
  metadata keywords claim `cc0`. The license claim is provenance evidence, not
  independent legal clearance.
- **Command:** `PDF_EDITOR_ACROFORM_BENCHMARK_OUTPUT_DIR=benchmark/results/2026-08-23-public-acroform bash benchmark/test_pdfkit_acroform_benchmark.sh`
- **Result:** Failed the no-op widget-state gate. PDFKit reopened six widgets and
  preserved page/widget count, text mutation, source digest, and text extraction,
  but it dropped the `choices` array from the two `applicant.contact` radio widgets.
  The original/no-op PDFKit raster comparison differed by ImageMagick AE `166`
  (`8.27664e-05` normalized), so visual equality is also not a byte-identical pass.
  PDFKit also logged:
  `PDFFormField with no corresponding Widget sharing the field name.`
- **Machine result:** [`../benchmark/results/2026-08-23-public-acroform/result.json`](../benchmark/results/2026-08-23-public-acroform/result.json)
- **Result fields:** `noOpReopen: true`, `widgetStateEquivalent: false`,
  `mutatedReopen: true`, `originalUnchanged: true`, widget types `/Btn`, `/Ch`,
  and `/Tx`.
- **Independent checks:** Poppler reported `Form: AcroForm`; source/no-op text
  matched; the mutated extraction contained `PDFKit benchmark`; and the source vs
  no-op raster comparison recorded AE `166` (`8.27664e-05` normalized).

## Interpretation

- PDFKit's basic widget object model and text mutation path are viable for further
  investigation.
- PDFKit does not yet clear the external AcroForm preservation gate because radio
  choice metadata was lost on a no-op save.
- The public sample is a temporary benchmark artifact. Do not ship or make license
  claims from its source metadata without legal/provenance review.
- This lane does not test signatures, XFA, malformed/encrypted PDFs, rotated pages,
  independent viewer equivalence, or production readiness.
