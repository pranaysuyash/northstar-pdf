# Benchmark Results

This directory contains derived benchmark evidence, not an editable source of
truth. The protocol and interpretation live in [`../../docs/pdfkit-benchmark.md`](../../docs/pdfkit-benchmark.md);
decisions live in [`../../docs/decisions.md`](../../docs/decisions.md).

## `2026-08-23-pdfkit-form6`

- **Input:** `/Users/pranay/Desktop/RAr0Lq2Avu.pdf`
- **Input SHA-256:** `2cf1421343c22676f15eff0ec6f31a4df6e7f7975dc0f3d88d2b29a1dcc79d34`
- **Harness:** [`../PDFKitBenchmark.swift`](../PDFKitBenchmark.swift)
- **Test:** [`../test_pdfkit_benchmark.sh`](../test_pdfkit_benchmark.sh)
- **Machine result:** `result.json`
- **Derived artifacts:** `artifacts/noop.pdf`, `artifacts/overlay.pdf`, and the
  original/no-op PDFKit render PNGs.
- **Status:** Tier 2/S1 pass for the defined PDFKit-local Form 6 claims; not a final
  provider or production-fidelity result.

## `2026-08-23-pdfkit-widgets`

- **Input:** Generated locally by `PDFKitWidgetBenchmark.swift`.
- **Machine result:** `result.json`
- **Derived artifacts:** `native-widgets.pdf` and `native-widgets-filled.pdf`.
- **Status:** Tier 2/S1 pass for PDFKit-created text, checkbox, two radio, choice,
  and signature widget round-trips. Poppler reports `Form: none` for the generated
  input; this is not external AcroForm evidence.

## `public-sample-form.pdf`

- **Source:** <https://pdftoolskit.org/samples/sample-form.pdf>
- **SHA-256:** `5a681d44622f2ee577808e77f034525314d48a628b9cad26f7788564c9e922e8`
- **Status:** Public benchmark input. The source metadata claims `cc0`; this has not
  been independently legally verified.

## `2026-08-23-public-acroform`

- **Input:** `../public-sample-form.pdf`
- **Machine result:** `result.json`
- **Status:** Tier 2/S1 failure of the external AcroForm preservation gate. PDFKit
  dropped radio-choice metadata on no-op save while preserving other recorded checks.
- **Artifacts:** `noop.pdf`, `mutated.pdf`, and PDFKit original/no-op render PNGs.
