# OCR Benchmark Expansion (2026-08-31)

**Status:** Verified
**Doctrine ref:** §5 Evidence-based, §2 Truth taxonomy

## What was built

### 8 new ground-truth fixtures

| Fixture | Dimension | Description | Ground truth words |
|---|---|---|---|
| `clean-english` | scans | Clean printed English paragraph | 23 |
| `noisy-invoice` | noise | Gaussian noise (0.3 attenuation) | 12 |
| `rotated-certificate` | rotations | 90° rotated document | 10 |
| `low-contrast` | low_contrast | Gray text on light gray background | 17 |
| `dense-paragraph` | dense_text | 6-line Lorem Ipsum | 55 |
| `small-font` | small_font | 12pt stress test | 27 |
| `mixed-punctuation` | punctuation | Email, phone, fax, order, EUR | 18 |
| `multi-column` | multi_column | Two-column layout | 33 |

Each fixture is generated via ImageMagick as a raster image (PNG) and embedded into a PDF (raster-only, no text layer). Ground truth is stored in separate `.gt.txt` files.

### Two OCR providers implemented

| Provider | Type | Mechanism | Works on |
|---|---|---|---|
| **Tesseract** | Real OCR | Shell invocation of tesseract 5.5.0 | PNG images, raster PDFs |
| **PDFKit** | Text extraction | Native PDFKit `page.string` | PDFs with text layers only |

### WER/CER measurement

Both Word Error Rate and Character Error Rate are computed using Levenshtein distance on word/character sequences. The `computeWER` and `computeCER` methods are public and tested independently.

## Baseline results (Verified, Tesseract 5.5.0)

| Fixture | Tesseract WER | Notes |
|---|---|---|
| clean-english | 0.0% | Perfect recognition |
| noisy-invoice | 0.0% | Noise doesn't affect 28pt text |
| rotated-certificate | 0.0% | Tesseract handles rotation |
| low-contrast | 0.0% | Gray-on-gray works |
| dense-paragraph | 0.0% | 22pt Lorem Ipsum recognized |
| small-font | 9.4% | 12pt is the stress case |
| mixed-punctuation | 0.0% | Special chars preserved |
| multi-column | 0.0% | Column layout handled |
| **AVERAGE** | **1.2%** | Excellent baseline |

pdftotext (Poppler) returns 100% WER on all fixtures because these are raster-only PDFs with no text layer — exactly the use case where OCR is needed.

## Architecture decisions

1. **PNG preferred over PDF for OCR**: Tesseract works directly on PNG images. PDFs are converted to PNG via `pdftoppm` at 300 DPI when needed. This avoids PDF rendering differences between providers.

2. **Ground truth normalization**: Ground truth text is normalized (whitespace collapsed) before WER computation to avoid false positives from formatting differences.

3. **Provider protocol**: `BenchmarkOCRProvider` is separate from the core `OCRProvider` protocol (which uses `CGImage`). The benchmark protocol uses file paths because Tesseract operates on files, not in-memory images.

## Files

- Source: `Sources/PDFEditorCore/OCRCompanionBenchmark.swift` (rewritten)
- Tests: `Tests/PDFEditorCoreTests/OCRCompanionBenchmarkTests.swift` (14 tests)
- Fixtures: `benchmark/results/ocr-corpus/` (8 new PNGs + PDFs + ground truth)
- Generator: `benchmark/generate_ocr_benchmark_fixtures.sh`
