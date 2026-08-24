# Grouped regions and direct editing exploration

Date: 2026-08-24

Status: active product decision and experiment record

## User problem

The old review surface presented repeated 17x13 point rectangles from a static
form as separate “Possible checkbox” suggestions. The attached screenshot shows
the failure clearly: the page contains a character-entry grid, while the
inspector advertises several high-confidence checkbox hypotheses that the user
cannot actually fill, check, or edit.

The product requirement is therefore not “detect every rectangle.” It is:

1. infer the likely logical region from geometry, repeated patterns, and nearby labels;
2. expose the evidence and uncertainty;
3. offer an interaction only when the current editor can safely complete it;
4. preserve a direct-on-page escape hatch for regions the detector cannot understand;
5. keep the decision and edit reversible, inspectable, and testable.

## Decision

The canonical detection unit is now a logical region, not an individual vector primitive.

The shared RegionCandidate contract carries:

- suggestedFieldType: the semantic data hypothesis, such as text, date, or checkbox;
- entryMode: the currently supported interaction shape, such as singleText, characterGrid, checkbox, or unknown;
- labelText: the nearby text used as semantic evidence;
- groupMemberCount: the number of repeated geometry members represented by the candidate;
- evidenceItems: structured evidence for later review and benchmark analysis.

The native detector groups adjacent small boxes before classifying them. A run
of three or more aligned cells becomes one characterGrid candidate. The
individual cells are claimed and cannot also become separate checkbox suggestions.

Choice-like patterns remain visible as review-only detections until there is a
real checkbox/radio interaction model and a corresponding export/reopen proof.
The UI must never offer “Add text here” for a candidate whose entryMode is
checkbox, radioGroup, or unknown.

## Current interaction contract

### Native macOS lane

- Select a grouped character-entry candidate to highlight the union of its cells.
- Review the matched label, group count, evidence, and confidence.
- Enter the full value once. The edit is one reversible logical operation that
  materializes one glyph per detected cell at export and in the live preview.
- Double-click anywhere on the PDF to open the same text-placement sheet directly at that page-space coordinate.
- Use the toolbar placement action when a precise manual click is preferred.
- Dismiss a hypothesis without changing the source PDF.
- Undo a confirmed overlay and restore its candidate to review state.

### Web lane

- Use the same candidate vocabulary and editability policy.
- Text-anchored regions are currently emitted from PDF.js text content and are singleText candidates.
- Double-clicking the rendered page opens direct text placement.
- PDF.js rendering and viewport transforms are used for display and coordinate conversion; browser-side vector geometry grouping is not yet implemented.
- This is a known parity gap, not an invisible claim of identical detection.

## Grouping algorithm v0.1

Input: small vector rectangles from the PDF content stream, currently those no
larger than 32 by 24 points.

1. Deduplicate rectangles from the parser's checkbox and input-box buckets.
2. Sort by row center, then horizontal position.
3. Join a rectangle to the current run when row centers are aligned within a size-aware tolerance and the horizontal gap is no more than 1.5 cell widths or 8 points.
4. Emit a group only when it contains at least three cells.
5. Compute the union rectangle in PDF page user space.
6. Find the nearest label to the union, preferring left or above relationships.
7. Infer a semantic type from the label.
8. Map semantic type plus grouping to an interaction mode:
   - text, date, number, and choice-like text in a repeated run: characterGrid;
   - checkbox cues: checkbox and review-only;
   - signature cues: signature;
   - larger isolated regions: singleText or the corresponding semantic mode.
9. Record the group and label evidence, then claim all member boxes.

This is a deterministic heuristic, not machine learning. It is intentionally
small enough to benchmark and replace without changing the edit ledger.

## Why the PDF libraries are not the whole solution

The current technology boundary is:

| Capability | Useful source | What it proves | What remains product-owned |
| --- | --- | --- | --- |
| Native macOS rendering and static PDF inspection | PDFKit | PDF pages, annotations, text, page coordinates | Logical grouping, label semantics, safe interaction policy |
| Browser rendering and viewport transforms | [PDF.js API](https://mozilla.github.io/pdf.js/api/) and [PDF.js examples](https://mozilla.github.io/pdf.js/examples/index.html) | Text content, rendering, page viewport conversion | Vector grouping, OCR fallback, semantic field inference |
| Create or fill standard forms and draw overlays | [pdf-lib](https://github.com/Hopding/pdf-lib) | AcroForm field types and PDF drawing/modification | Whether a static visual region should become a field; appearance and compatibility policy |
| Alternate extraction and form engineering lane | [Apache PDFBox](https://pdfbox.apache.org/) | Text, forms, images, PDF/A tooling, Java ecosystem | Product semantics and cross-lane parity |
| OCR and text bounds on macOS | [Apple Vision text rectangles](https://developer.apple.com/documentation/vision/detecttextrectanglesrequest) and [recognized text bounds](https://developer.apple.com/documentation/vision/vnrecognizedtext) | Image-space text observations and per-text bounds | Mapping, label matching, confidence calibration, privacy and latency |
| Image-space connected components and contours | [OpenCV structural analysis](https://docs.opencv.org/5.0/main_modules/imgproc_shape.html) | Candidate connected regions and statistics from raster input | Choosing thresholding, joining lines/cells, label semantics, false-positive policy |
| Coordinate reference | [MuPDF coordinate systems](https://mupdf.readthedocs.io/en/1.27.0/reference/common/coordinate-system.html) | Why PDF bottom-left, image top-left, crop boxes, and rotation must be explicit | One canonical project coordinate contract and round-trip tests |

The conclusion is to keep the current PDFKit/PDF.js lanes as providers and own
the semantic region graph in PDFEditorCore. A new provider is justified only
by a measured failure that the current provider cannot expose, not by the
presence of a convenient API.

## Exploration frontier

### Experiment A: vector-native grouped form

Fixture: synthetic six-cell name region with a nearby label.

Expected falsifiers:

- more than one candidate for the six cells;
- groupMemberCount not equal to six;
- missing label association;
- entryMode not equal to characterGrid;
- individual cell candidates reappearing.

Current result: the regression test
vectorDetectorGroupsCharacterCellsAndUsesNearbyLabel passes these invariants.

### Experiment B: real static form

Fixture: /Users/pranay/Desktop/RAr0Lq2Avu.pdf.

Current guard: the Form 6 smoke test requires fewer than 100 candidates. This
is a queue-volume guard, not a field-accuracy benchmark. The next benchmark
must add a reviewed truth table for grouped name grids, choices, dates,
signatures, photo boxes, and decorative geometry.

### Experiment C: direct placement coordinate fidelity

Native and web direct placement use page-space rectangles and the shared
PDFPageRegion convention. The required proof is:

1. click or double-click at a rendered location;
2. create an overlay operation;
3. export a new copy;
4. reopen it;
5. verify the text and bounds remain within the intended page region after scale, rotation, crop-box, and two-page layout changes.

The native `characterGridOverlayWritesOneGlyphPerCell` test and browser
character-grid workflow now cover the logical operation, per-cell materialization,
and bounded value path. A future visual test must add screenshot-level tolerance
at several rotations and zoom levels.

### Experiment D: raster/CV fallback

Candidate design:

1. render a page at a fixed DPI;
2. detect text and text bounds with Vision where available;
3. threshold and detect connected components/rectangles;
4. normalize image-space observations into PDF page space;
5. feed them into the same region graph as vector evidence;
6. lower confidence when geometry and text evidence disagree;
7. abstain when the candidate cannot be explained to the user.

This should begin as an offline benchmark lane. It must not silently add a
second production detector until latency, memory, OCR privacy, coordinate
fidelity, and false-positive results are measured on a corpus.

## Product policy for suggested regions

“Suggested” is an evidence state, not a promise that the region is editable.
The UI must use these labels:

- Text entry region: safe to review and place text.
- Character-entry region: one logical value spanning grouped cells.
- Checkbox pattern · review only: detected visual choice pattern; no text action until a choice interaction exists.
- Unclassified entry region: explain evidence and offer manual placement.

Every visible candidate must expose its next useful action. If no supported
action exists, the card must say why and provide either manual placement or dismissal.

## Risks and revisit triggers

- A row of checkboxes can look like a character grid. Revisit when the corpus includes labeled choice rows and add negative tests.
- A form may use gaps, broken strokes, or transformed paths that defeat the current adjacency tolerance. Revisit after corpus measurement.
- Label proximity can associate a region with the wrong line in dense forms. Revisit when a reviewed label benchmark exists.
- Overlay text is not a native field. Revisit native-field synthesis only after appearance, accessibility, field naming, export, reopen, and provider parity are proven.
- OCR and CV add compute and privacy cost. Revisit after an offline benchmark shows material recall improvement over vector plus text evidence.

## Files and verification

Implementation:

- Sources/PDFEditorCore/SharedContracts.swift
- Sources/PDFEditorCore/DocumentModel.swift
- Sources/PDFEditorCore/StaticRegionDetector.swift
- Sources/PDFEditorApp/AppModel.swift
- Sources/PDFEditorApp/ContentView.swift
- web/index.html

Tests:

- Tests/PDFEditorCoreTests/PDFEditorCoreTests.swift
- Tests/web_reader_contract_test.mjs
- Tests/web_editor_workflow_test.mjs

The durable rule is: detection, review, interaction, export, and reopen are
separate proof obligations. A passing detector test cannot be reported as
end-to-end form completion.
