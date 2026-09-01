# Rotated Reviewed-Operation Replay Evidence

**Date:** 2026-08-31  
**Evidence status:** Three-case browser replay and independent Poppler gate pass  
**Primary test:** [`Tests/rotated_operation_replay_test.mjs`](../../Tests/rotated_operation_replay_test.mjs)  
**Independent validator:** [`benchmark/independent-preservation-validator.mjs`](../../benchmark/independent-preservation-validator.mjs)  
**Release gate:** RG-113 in [`docs/release-gates.md`](../release-gates.md)

## Objective

Prove that a reviewed operation authored in the browser remains in the shared
page-space coordinate system while it passes through preview, pdf-lib export,
reopen, and outside-region preservation validation. The test is deliberately
about a reviewed visual overlay. It does not treat a static region as a native
AcroForm widget and does not claim that an external widget graph is preserved.

The authoritative operation remains:

```text
page index = 0
unit = points
origin = lowerLeft
page box = crop
rotation = source page rotation
```

The writer receives the same typed operation and performs the provider-specific
page transform only at materialization. The source PDF is never mutated.

## Matrix

| Case | MediaBox | CropBox | Rotation | Browser | Poppler independent |
|---|---|---|---:|---|---|
| `rotated-90-crop-offset` | 720 × 900 | (12, 18) to (624, 810) | 90° | reopen, privacy, text impact, raster impact passed | text, raster, reopen passed |
| `rotated-180-crop-offset` | 720 × 900 | (24, 30) to (636, 822) | 180° | reopen, privacy, text impact, raster impact passed | text, raster, reopen passed |
| `rotated-270-zero-offset` | 612 × 792 | (0, 0) to (612, 792) | 270° | reopen, privacy, text impact, raster impact passed | text, raster, reopen passed |

The scenarios are derived into a temporary test directory with pikepdf so the
source corpus fixture remains immutable. The browser places a reviewed text
overlay through the actual manual-placement interaction, rather than injecting
an operation into the session. It then asserts that the recorded operation is
crop-relative, positive, in bounds, and tagged with the source rotation.

## Evidence chain

For every matrix row, the test proves:

1. PDF.js reads the expected rotation and CropBox.
2. The user-facing browser placement produces a source-bound `overlayText`
   operation in points, lower-left, crop-relative page space.
3. pdf-lib materializes the operation after restoring source page boxes and
   rotation.
4. The exported PDF reopens in PDF.js.
5. The browser privacy transition, outside-region text, and visual diff checks
   pass before the download is accepted.
6. Poppler independently reopens the source and output, hashes text outside
   the operation region, compares raster pixels outside the projected region,
   and records successful structural/text reopen evidence.

The test does not compare output bytes. Provider serialization is allowed to
change, while the source digest, page-space operation, review lineage, and
outside-region evidence remain the shared semantics.

## Renderer-origin correction

The first run exposed two non-equivalent failures that are preserved as
implementation history:

- pdf-lib introduced a `Creator` metadata presence change on the normalized
  rotated fixture. The browser writer now reapplies inspected metadata presence
  before saving, so a coordinate-only operation does not silently authorize a
  protected metadata transition.
- The 180° Poppler text bbox and crop raster use different origins. Text bbox
  coordinates are compared in media-space for that case, while the raster is
  clipped to CropBox dimensions before pixel comparison. The independent
  validator now receives the bbox dimensions for text and uses an explicit
  raster projection with media width plus crop-relative origin for 180° pages.

The correction keeps the authorized operation rectangle fixed. It does not
increase the pixel tolerance or mask the whole page. The previously failing
outside-raster pixels are therefore a useful negative signal showing that the
gate can detect a wrong projection.

## Verification command

```text
node --check benchmark/independent-preservation-validator.mjs
node --check Tests/rotated_operation_replay_test.mjs
node Tests/run-web-e2e.mjs rotated_operation_replay
```

Result: all three scenarios passed. The pikepdf derivation prints a warning
that four form widgets in the source are not reachable from `/AcroForm`. This
test does not use those widgets; the warning is retained as fixture provenance
and is not converted into a widget-preservation claim.

## Limits and next gates

This is local Tier 3 browser plus independent-renderer evidence over synthetic
or derived fixtures, with S1 document sensitivity. It does not prove:

- native PDFKit replay or native/web widget parity;
- multi-page mixed-rotation replay;
- non-zero crop offsets for every rotation and operation kind;
- native-field, annotation, image, signature, redaction, or text-run replay;
- byte-for-byte or object-by-object preservation;
- independent GUI viewer agreement;
- XFA, PDF/UA, cryptographic signature validity, or arbitrary-PDF production
  preservation.

Those remain explicit lanes under RG-113 and RG-121. The next useful extension
is a multi-page mixed-rotation fixture with a reviewed operation on every page,
followed by the equivalent native PDFKit replay and the MuPDF edited-operation
independent oracle.
