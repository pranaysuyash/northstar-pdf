# Independent Preservation, Rotated Fixtures, and Viewer Reopen Evidence

**Date:** 2026-08-24  
**Evidence status:** Bounded preservation gate implemented and exercised  
**Primary runner:** [`Tests/pdf_independent_preservation_test.mjs`](../../Tests/pdf_independent_preservation_test.mjs)  
**Corpus runner:** [`Tests/pdf_contract_parity_test.mjs`](../../Tests/pdf_contract_parity_test.mjs)  
**Independent adapter:** [`benchmark/independent-preservation-validator.mjs`](../../benchmark/independent-preservation-validator.mjs)

## Claim boundary

The PDF.js browser impact validator remains useful for fast in-browser feedback,
but it cannot independently establish raster preservation because it renders
both source and output through PDF.js. This gate adds a separate Poppler path:

- `pdfinfo` reopens page count, page boxes, and page rotation;
- `pdftotext` reopens and hashes word-bounded text outside authorized regions;
- `pdftoppm` renders source and output and compares RGB pixels outside those
  regions;
- `qpdf --check` records structural acceptance or warning separately from the
  Poppler viewer result.

The validator never writes extracted text to the evidence report. It records
word counts, SHA-256 text hashes, page facts, pixel counts, ratios, maximum
channel deltas, tool versions, and bounded diagnostics. It does not prove
byte identity, semantic object preservation, PDF/UA, signature validity, or
human visual approval.

## Rotated corpus additions

[`benchmark/generate_rotation_fixtures.sh`](../../benchmark/generate_rotation_fixtures.sh)
creates stable derived fixtures using qpdf deterministic IDs. The source PDFs
remain unchanged.

| Fixture | Rotation | SHA-256 | Independent result |
|---|---:|---|---|
| `benchmark/results/rotation-corpus/rotated-widget-90.pdf` | 90 degrees | `bc7c40a80dc662258b99680c3d73dea05a1b9f297576410e21a0690b2e2711b2` | Poppler reopen passed; source-to-source text/raster checks passed |
| `benchmark/results/rotation-corpus/rotated-form6-mixed.pdf` | Page 1: 90 degrees; page 2: 180 degrees | `3e01dac92555798ca8d4369ed0ea4021c35a264e0969b5d08cd026e30364b177` | Poppler reopen passed; source-to-source text/raster checks passed |

The rotation transform is explicit in the independent adapter. It converts
lower-left PDF crop-box rectangles into Poppler's top-left rendered frame for
0, 90, 180, and 270 degree page rotations. The no-op rotated checks exercise
the page dimensions and rendering path; the mutation gate exercises the
outside-region authorization path on a non-rotated public form. A rotated
operation replay gate remains a follow-up because it needs a reviewed rotated
region fixture rather than only page-level rotation metadata.

## Corpus result

The parity harness now runs against 10 manifest entries: 9 valid source PDFs
and one intentionally truncated failure.

| Evidence | Result | Interpretation |
|---|---:|---|
| Valid source Poppler reopen | 9/9 passed | Independent parser/viewer path reopened every valid source, including encrypted input with its password |
| Truncated source Poppler reopen | Expected failure | Malformed input remains visibly rejected |
| Native no-op outputs | 9/9 Poppler reopen and text/raster pass | Native validated exports are independently reopenable and unchanged outside an empty operation set |
| Browser no-op outputs | 9/9 valid produced outputs Poppler reopen and text/raster pass | Browser lane passes the independent preservation check on all valid outputs, including the byte-preserved encrypted no-op export |
| Encrypted browser output | Not produced | PDF.js can inspect the source, but the current pdf-lib writer lane refuses the encrypted export; no silent decryption claim is made |
| Rotated source fixtures | 2/2 passed with exact rotation facts | Page rotations 90 and 90/180 were preserved for independent reopen and raster rendering |
| qpdf structural check | Mixed and preserved | Existing public AcroForm/Form 6 warnings remain visible; Poppler reopen is not promoted to structural conformance |

Machine-readable corpus evidence is retained in:

- [`benchmark/results/contract-parity-2026-08-24/independent-preservation-report.json`](../../benchmark/results/contract-parity-2026-08-24/independent-preservation-report.json)
- [`benchmark/results/contract-parity-2026-08-24/native/exports/`](../../benchmark/results/contract-parity-2026-08-24/native/exports/)
- [`benchmark/results/contract-parity-2026-08-24/web-exports/`](../../benchmark/results/contract-parity-2026-08-24/web-exports/)

## Mutation-sensitive evidence

`Tests/pdf_independent_preservation_test.mjs` opens the public AcroForm in
isolated Chrome, applies one reviewed native-field operation, exports the PDF,
and then runs the independent validator twice:

| Authorization input | Poppler outside text | Poppler outside raster | Poppler output reopen |
|---|---|---|---|
| No operation region | Failed | Failed | Not a preservation pass |
| Recorded operation region | Passed | Passed | Passed |

This is S3 sensitivity evidence for the independent gate. The validator fails
when the authorization boundary is removed, and passes only when the same
source-bound operation region is supplied. The existing browser impact test
continues to provide the analogous text/raster mutation checks inside PDF.js.

## Reproduction

```bash
bash benchmark/generate_rotation_fixtures.sh
swift build --product PDFContractHarness
swift test
node Tests/pdf_independent_preservation_test.mjs
node Tests/pdf_contract_parity_test.mjs
```

The parity runner retains native and browser no-op export bytes and updates the
independent report. The browser test uses isolated Chrome and the existing
local server route; it does not use the shared browser daemon as release proof.

## Remaining limits and next gate

- Poppler is an independent parser and renderer, not a second human-operated
  GUI viewer. A future control-viewer observation can add Preview or another
  independent application, but must be recorded separately from this machine
  gate.
- A passing Poppler reopen does not clear qpdf warnings, broken form reachability,
  semantic AcroForm parity, or arbitrary text-edit fidelity.
- The current retained parity outputs are no-op outputs. Reviewed overlay and
  native-field output artifacts need their own independent report entries if
  they are used for release claims.
- Rotated page-level evidence is present. Rotated reviewed-operation replay,
  crop-box offsets, non-90 degree display transforms, and mixed image/text
  rotations remain open.
- The output gate must remain fail-closed on invalid or missing operation
  coordinates. An `unknown` result is not a preservation pass.

## Decision impact

The product can now claim a bounded, independently reopened preservation check
for the supported no-op and reviewed public-form paths. It cannot claim general
PDF preservation, arbitrary semantic editing, or structural conformance. The
next hardening unit is rotated reviewed-operation replay plus an accepted
variance registry for qpdf warnings and provider-specific output behavior.
