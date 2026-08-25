# Text-run replacement and OCR-layer alignment evidence

Date: 2026-08-25  
Contract: `pdf-editor.text-run-ocr-alignment` version 1.0  
Corpus authority: `Tests/fixtures/pdf_corpus_governance_manifest.json` and the
existing `docs/fixtures/manifest.md` execution list

## Purpose

This benchmark measures two related but separate capabilities across the native
PDFKit/Vision adapter and the browser PDF.js adapter:

1. whether text runs can be identified with stable semantic fingerprints and
   page-space geometry suitable for a future reviewed replacement operation;
2. whether OCR observations can be aligned with a selectable text layer without
   changing the source or silently creating fields.

The benchmark does not claim that either adapter can safely replace arbitrary
existing PDF text. Current replacement operations are therefore recorded as
review-required and abstained-unsupported until a provider passes the semantic,
geometry, outside-region, reopen, and independent-viewer gates.

## Implementation

The shared value-free projection is implemented in
[`web/text-run-ocr-alignment-benchmark.mjs`](../../web/text-run-ocr-alignment-benchmark.mjs).
It normalizes PDF.js text items, native PDFKit selection lines, and Vision OCR
observations into:

- source digest and provider identity;
- page index, crop-box page bounds, rotation, and lower-left point coordinates;
- a SHA-256 fingerprint of normalized text, character count, and run identity;
- geometry status, origin, confidence where applicable, and explicit abstention;
- no raw text, replacement value, OCR value, image, password, or source bytes.

The browser fixture adds `textRuns` to its existing snapshot and exposes the
projection and comparison functions through
`window.__pdfEditorContractFixture`. The native executable
[`Sources/PDFTextRunOCRBenchmark/main.swift`](../../Sources/PDFTextRunOCRBenchmark/main.swift)
uses PDFKit `selectionByLine` geometry and the existing Vision OCR provider.
The browser/native runner is
[`Tests/text_run_ocr_alignment_browser_test.mjs`](../../Tests/text_run_ocr_alignment_browser_test.mjs).

## Run commands

```sh
swift build --product PDFTextRunOCRBenchmark
swift run PDFTextRunOCRBenchmark \
  --manifest docs/fixtures/manifest.md \
  --output benchmark/results/text-run-ocr-alignment/native.json

python3 -m http.server 8765
PDF_PROOF_BASE_URL=http://127.0.0.1:8765/web/index.html \
  node Tests/text_run_ocr_alignment_browser_test.mjs

node Tests/text_run_ocr_alignment_contract_test.mjs
```

The browser test writes the combined report to
[`benchmark/results/text-run-ocr-alignment/browser-and-native.json`](../../benchmark/results/text-run-ocr-alignment/browser-and-native.json)
and the native-only evidence to
[`benchmark/results/text-run-ocr-alignment/native.json`](../../benchmark/results/text-run-ocr-alignment/native.json).

## Current measured result

The run covered all 18 entries in the existing execution manifest:

| Measure | Result | Interpretation |
|---|---:|---|
| Fixture entries | 18 | Same source list as the existing parity lane |
| Successfully inspected | 16 | Two declared malformed fixtures failed safely |
| Pages compared | 81 | Includes the 20-page and 40-page stress documents |
| Pages with measurable text projections | 29 | Both adapters exposed at least one comparable text run |
| Mean text-hash agreement | 0.6593 | Semantic run segmentation/content differs by provider and fixture |
| Pages with measured OCR/reference comparison | 10 | OCR evidence and browser selectable text both existed |
| OCR page abstentions | 71 | Expected for scanned pages or pages without a browser OCR provider |
| Text geometry agreement at 2 points | 0% mean | Current provider rectangles are not interchangeable |
| OCR geometry agreement at 3 points | 0% mean | Vision and PDF.js/PDFKit reference boxes need calibration |
| Silent text replacement | 0 | All replacement probes were abstained |

The machine-readable gates are in the report. Source-digest binding, zero
content logging, no silent replacement, and safe browser OCR abstention passed.
Text geometry and OCR geometry gates failed, intentionally. The report retains
the first mismatches using page index, text hash, counts, bounds, and provider
identity only.

## First mismatches

The public sample form is representative. Six of seven native PDFKit line
fingerprints matched a browser PDF.js fingerprint, but the browser projection
reported zero geometry matches within two points. The same semantic lines had
different lower-left rectangles, including a consistent vertical offset caused
by provider-specific text transform and selection-box conventions.

The native and browser character totals also differ on several fixtures because
the providers normalize empty text items, whitespace, line segmentation,
ligatures, and form-related text differently. The benchmark keeps those as
provider divergence instead of inventing a universal character-count oracle.

Hybrid and rotated fixtures add the expected page-class split: selectable pages
have measurable text evidence, while raster pages have no browser OCR evidence
and therefore produce `abstainedNoReference` or `abstainedNoOCR` states. The
absence is a safe result. It is not permission to infer a field, add a text
layer, or replace content.

## Replacement status

Both native and browser providers currently report
`textRunReplacement` as `abstained-unsupported` when a run exists. This is
correct for the current writer surface: PDFKit does not yet provide a safe
semantic replacement path, and the browser mutation gate intentionally accepts
bounded overlays/forms rather than arbitrary existing-page text replacement.
The live browser benchmark also sent a source-bound replacement probe through
the actual pre-export guard; every available target was rejected with the typed
`unsupportedOperation` code before pdf-lib was reached.

The benchmark therefore proves the admission boundary and the evidence needed
to implement the capability later. It does not pretend that an overlay is a
text replacement. A future supported result must include the replacement
operation, source digest, target run identity, reviewed decision, outside-region
text proof, raster diff, reopen result, and independent-viewer result.

## Bounded simple-run provider experiment

The first actual writer slice is now implemented in
[`web/simple-text-run-provider.mjs`](../../web/simple-text-run-provider.mjs).
It supports only a deliberately narrow PDF class: classic uncompressed content
streams, one unique printable ASCII literal string, and a same-byte-length
replacement. The provider changes the literal in place, so the existing font
operator, content-stream offsets, xref offsets, and all outside content remain
byte-layout stable. It does not draw an annotation or overlay.

The provider requires a source digest, target run ID, original-text hash,
page-space coordinate, and reversible operation state. It rejects stale source
digests, non-ASCII or escaped literals, ambiguous repeated targets, and
different-length replacements. The output remains a candidate until validation
passes.

[`Tests/text_run_simple_provider_test.mjs`](../../Tests/text_run_simple_provider_test.mjs)
passes 16 checks for same-width `Hello` to `Earth` replacement, source text
change, outside text retention, qpdf structural validation, Poppler extraction,
source/output reopen, outside-region text preservation, outside-region raster
preservation, stale-digest rejection, and unequal-width rejection. This is a
controlled provider result, not arbitrary PDF text-editing proof.

## Long-term implementation implications

1. Add a provider-independent text extraction control, such as Poppler `pdftotext
   -bbox` or PDFBox, and compare it with both PDFKit and PDF.js before selecting
   a canonical replacement rectangle.
2. Calibrate text-box policies by document class: normal text, embedded-font,
   ligature, rotated, multi-column, RTL, clipped, and hybrid pages.
3. Implement browser OCR as an explicit provider capability, then compare its
   OCR bounds to native Vision and the independent control. No OCR layer should
   become editable content without review and provenance.
4. Extend the bounded simple-run writer behind the provider capability
   handshake, then add hard abstention and separate fixtures for unsupported
   fonts, encodings, compressed streams, clipping, overlap, signatures, XFA,
   incremental updates, ligatures, embedded fonts, RTL, and Unicode.
5. Re-run the independent outside-region text and raster validators on every
   supported replacement, including rotated fixtures and independent-viewer
   reopen evidence.

## Evidence classification

This is runtime benchmark evidence for the current local corpus and current
provider versions. It is not a universal PDF fidelity claim, not handwriting
accuracy evidence, not OCR language coverage evidence, and not permission to
change the source PDF. Native and browser contracts remain semantically
comparable through source identity, page-space coordinates, evidence lineage,
review state, typed operation intent, and validation state even when their
provider-specific text rectangles and byte outputs diverge.
