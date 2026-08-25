# Character-Grid Merge and Highlight Evidence

Date: 2026-08-25  
Status: Implemented and verified in the browser fixture; native test-suite execution is environment-blocked  
Evidence tier: Tier 2 / S1 focused Chrome workflow plus direct detector assertions; native/browser parity implementation inspected

## User-visible outcome

The static-form review surface now treats repeated character cells as editable geometry rather than one painted rectangle:

- Search matches use a low-opacity amber cue with an inset underline, so the extracted PDF text remains readable.
- Character-grid suggestions render a transparent dashed union boundary and individual, low-opacity cell tints. The gaps between cells are not painted as editable space.
- Pending character-grid values use restrained blue cell overlays with dark glyphs instead of dense green fills.
- Same-row sibling fields are not merged merely because their boxes are close. The detector uses row geometry, cell-width signatures, and local gap patterns to identify field boundaries.

## Root cause (observed and inferred)

The previous browser and native grouping functions clustered cells using only a broad same-row test and a gap threshold:

```text
gap <= max(8pt, cellWidth * 1.5)
```

On Form 6, that rule crossed a real field boundary. The left and right sibling fields share a baseline, but their cell-width signatures differ and the gap between them is materially larger than the within-field gap. A photo-box cell on the same row was also close enough to be absorbed by the old rule. The candidate bounds were then calculated as the union of every member cell, so one mistaken group became an oversized editable region.

The user's missing-line intuition is directionally correct, but the fixture does not provide a reliable continuous horizontal rule for every field. The durable discriminator is the geometry signature: consistent top/bottom/height and width within a field, followed by a discontinuity in width or gap at a field boundary.

## Implementation

### Browser detector

`web/pdf-geometry-detector.mjs` now performs three grouping stages:

1. Bucket cells into narrow row bands using top, bottom, and height tolerances.
2. Split each band when cell width changes beyond the width-signature tolerance or when a gap is too large for the current cell signature.
3. Within each signature run, split on a gap that diverges from the observed within-run median gap.

The logic is intentionally conservative: only runs of at least three cells become character-grid candidates. This prevents isolated decorative squares and photo-box geometry from becoming text-entry regions.

### Native parity

`Sources/PDFEditorCore/StaticRegionDetector.swift` mirrors the browser grouping algorithm, including row bands, width signatures, median-gap splitting, and the three-cell minimum. This keeps the two product surfaces aligned on the same geometry contract.

### Browser and native rendering

The served module in `web/index.html` and the parallel `web/app.js` renderer now share the same behavior:

- `.candidate-preview.character-grid` is transparent and dashed.
- `.candidate-cell-tint` paints each detected cell individually.
- Character-grid candidates contain no label text inside the union box.
- Search marks use `rgba(255, 210, 77, 0.16)` plus an inset amber underline.
- Pending edits use a light blue background (`rgba(219, 234, 254, 0.30)`) and dark text.

The native `Sources/PDFEditorApp/ContentView.swift` presentation overlay now follows the same visual contract. Character grids use a dashed union boundary plus independent low-opacity cell strokes/fills; normal candidate and field fills were reduced; and search uses a light cue plus underline. Search now avoids invoking PDFKit's opaque `currentSelection` painter altogether, clears any stale selection after capturing exact bounds, and renders the controlled overlay instead.

The inline served renderer was reconciled with the external source copy rather than leaving two divergent implementations of this fix. The broader inline-module extraction remains a separate CSP/RT-004 architecture item because the served page currently contains product-surface code not present in `web/app.js`.

## Regression evidence

Fixture: `docs/benchmarks/pdfkit-form6-run-2026-08-23/noop.pdf`

The focused browser regression is `Tests/web_character_grid_workflow_test.mjs`. It now verifies:

- The first-name baseline at approximately `y=604.49` is split into two candidates with 11 and 12 cells instead of one 27-cell union.
- The adjacent name baseline at approximately `y=618.41` contains one 12-cell field and excludes the photo-box cell.
- Candidate left and right edges equal the union of their member cells.
- Character-grid previews have a transparent background, dashed boundary, no overlaid label text, and per-cell tints.
- Search marks use the reduced opacity.
- Entered values still render one glyph per detected cell.

Observed focused result:

```text
web character-grid workflow: grouped cell detection, per-cell preview, and bounded value entry passed
```

A direct Chrome inspection also observed:

```text
character-grid union background: rgba(0, 0, 0, 0)
character-grid union border: dashed
search mark background: rgba(255, 210, 77, 0.16)
```

The native `swift test` command could not run in this environment because Swift Package Manager's manifest compilation is rejected by the host sandbox (`sandbox_apply: Operation not permitted`). This is an execution-environment limitation, not a detected Swift source failure. The native implementation was updated and should be rerun in a normal Xcode/SwiftPM environment.

## Residual risks and next checks

- The focused web regression provides fixture-level evidence, not proof across arbitrary PDFs. The next corpus promotion should include rows with intentional mixed widths, irregular gaps, rotated pages, and decorative squares.
- The current CSS keeps the union boundary as the accessible/clickable hit target while cell tints use `pointer-events: none`; this preserves one review action per candidate and avoids making each tint a separate candidate.
- Native/browser parity is implemented, but native runtime execution remains unverified until the SwiftPM sandbox issue is cleared.
- The existing inline-module architecture is still duplicated at the application level. This fix synchronizes the relevant renderer but does not claim that RT-004 extraction is complete.

## Changed files

- `web/pdf-geometry-detector.mjs`
- `Sources/PDFEditorCore/StaticRegionDetector.swift`
- `Sources/PDFEditorApp/ContentView.swift`
- `web/app.js`
- `web/index.html`
- `Tests/web_character_grid_workflow_test.mjs`
