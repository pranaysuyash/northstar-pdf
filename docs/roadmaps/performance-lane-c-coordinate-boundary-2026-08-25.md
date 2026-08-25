# Performance Lane C: Coordinate Boundary

Date: 2026-08-25
Owner: Lane C first-principles geometry coordinate boundary
Status: design-only; source change intentionally deferred

## Scope and decision

This slice owns the coordinate boundary between PDF content-stream geometry,
PDFKit page metadata, and static-region candidates. The requested write set was
limited to:

- `Sources/PDFEditorCore/PDFVectorStreamParser.swift`
- `Sources/PDFEditorCore/StaticRegionDetector.swift`
- `Sources/PDFEditorCore/PDFKitProvider.swift`
- this roadmap

The three source files are intentionally unchanged. A safe normalization cannot
be completed inside that write set without either a focused non-zero-crop and
rotated-page fixture or an explicit caller/shared-contract change that defines
how raw geometry, missing metadata, and normalized candidate coordinates are
represented. No field vocabulary or grouping heuristic is changed here.

This is not a claim that existing geometry is wrong on every document. It is a
fail-closed boundary decision: the current path must not silently reinterpret
raw media-box geometry as crop-box-relative, zero-rotation edit geometry.

## Current contract, from source inspection

### Parser seam

`PDFVectorStreamParser.ParsedPageGeometry` carries `pageIndex`, `mediaBox`,
rectangle arrays, horizontal-line arrays, and the three potential-field arrays
(`PDFVectorStreamParser.swift:24-51`). The parser obtains the media box from
`CGPDFPage`, applies content-stream CTMs to path points and rectangles, and
returns the processed arrays (`PDFVectorStreamParser.swift:80-94,
112-177,​ 189-247`). The output therefore remains useful raw geometry evidence,
but it does not carry crop-box origin, crop-box dimensions, or page rotation.

The parser's `mediaBox` is not a sufficient normalization contract. It identifies
the page box used for raw extraction, but it cannot establish the PDFKit
inspection page's crop-relative origin or its display rotation.

### Detector seam

`StaticRegionDetector.detect(lines:vectorGeometries:)` receives text evidence
and parsed vector geometry only (`StaticRegionDetector.swift:17-29`). It uses
the existing label vocabulary, distance limits, grouping rules, and candidate
classification. Vector candidates construct `PDFPageRegion` directly from raw
rectangle values at the grouped-cell, checkbox, input-box, and underline seams
(`StaticRegionDetector.swift:73-104, 140-171, 202-230, 346-374`).

The no-argument `PDFPageRegion` coordinate-space default is the shared
page-user-space value: points, lower-left origin, crop box, rotation zero
(`Sources/PDFEditorCore/SharedContracts.swift:101-135`). Applying that default
to parser rectangles would claim semantics that the detector does not receive.
Changing the candidate's field vocabulary, grouping, or score is out of scope
and would not solve the missing metadata.

### Provider seam

`PDFKitProvider.inspection(...)` obtains crop, bleed, trim, and art boxes and
page rotation while constructing `PageSnapshot` values
(`PDFKitProvider.swift:356-378`). The same method then independently parses
the source data and invokes the detector:

```swift
let vectorGeometries = data.map { PDFVectorStreamParser.parse(data: $0) } ?? []
let candidates = StaticRegionDetector.detect(lines: lines, vectorGeometries: vectorGeometries)
```

(`PDFKitProvider.swift:464-465`). No page metadata is joined to a parsed
geometry before candidate construction. This is the exact missing caller
contract. It is also why a parser-only transform cannot be accepted: the parser
does not know the PDFKit page rotation, and a provider-only change would need a
new explicit handoff consumed by the detector.

## Boundary that is safe to implement later

The next source change should introduce an explicit two-layer geometry value,
without renaming field kinds or changing grouping behavior:

1. Preserve the parser's arrays and rectangles as raw content-stream geometry.
   Give that layer an explicit provenance such as `rawMediaBoxUserSpace` and
   retain the media box that was actually used. Raw arrays must not be replaced
   by normalized arrays.
2. Join the raw geometry to the matching PDFKit page metadata in the provider:
   page index, media box, crop box, and page rotation. The join must be
   page-indexed and must not infer crop or rotation from rectangle extents.
3. Normalize only in one named boundary after that join. The normalized result
   may claim the shared candidate contract only when it is points, lower-left,
   crop-box-relative, and zero-rotation page space.
4. Keep raw geometry available as evidence alongside any normalized geometry.
   Normalization is a derived view, not destructive parser output.
5. If crop metadata, rotation metadata, or the transform domain is missing or
   unsupported, retain raw evidence and abstain from attaching an editable
   `PDFPageRegion`. A missing value must not be represented as rotation zero.

The current `PDFCoordinateSpace` cannot express an unknown rotation. That is a
caller/shared-contract issue, not a reason to overload `rotationDegrees: 0`.
Either the boundary must complete the transform before constructing a
`PDFPageRegion`, or the shared contract must gain an explicit unresolved/raw
state. That contract choice requires its own owner and focused fixtures.

## Explicit non-goals

- No changes to field vocabulary, inferred field types, candidate statuses,
  evidence origins, scores, or label text.
- No changes to adjacent-cell grouping, deduplication, distance thresholds,
  line handling, or abstention heuristics.
- No parser-side crop or rotation transform based on guessed page geometry.
- No conversion of raw arrays in place.
- No use of media-box dimensions as a proxy for crop-box dimensions.
- No assumption that a missing rotation is zero.
- No browser parity claim and no export-integrity claim from this design note.

## Acceptance cases for the next implementation

The source change is not accepted until a focused fixture or equivalent caller
contract covers all of these cases without changing candidate vocabulary or
group membership:

1. **Identity case:** media and crop boxes have the same origin and size, page
   rotation is zero, and normalized candidate rectangles equal the existing
   numeric rectangles. Raw rectangles remain separately observable.
2. **Non-zero crop origin:** media and crop boxes differ by an x and/or y
   offset. The normalized rectangle is explicitly crop-relative; it is not
   silently left in media coordinates and is not clamped merely because the
   media box is larger.
3. **Crop size differs from media size:** page bounds used for normalization are
   the actual crop box while media-box metadata remains preserved for raw
   provenance and diagnostics.
4. **Quarter-turn rotations:** rotations of 0, 90, 180, and 270 degrees map
   through one documented transform convention, produce the expected
   crop-relative lower-left rectangles, and round-trip to the original raw
   rectangle within the declared tolerance.
5. **Rotation normalization:** equivalent signed or out-of-range right-angle
   values normalize deterministically; malformed or unsupported values abstain
   instead of being treated as zero.
6. **Missing metadata:** missing crop or rotation metadata leaves raw geometry
   available but produces no candidate coordinate that claims crop-box or
   zero-rotation semantics.
7. **Same-space label matching:** vector geometry and text-line evidence are in
   one declared space before proximity matching. The existing label vocabulary,
   maximum distances, grouping membership, and abstention behavior are
   unchanged.
8. **Raw preservation:** normalization does not mutate, filter, deduplicate, or
   reorder the parser's raw rectangle, line, or potential-field arrays.
9. **Candidate contract:** every non-nil candidate coordinate serializes as
   points, lower-left, crop box, rotation zero; every unresolved candidate
   remains review evidence without an editable coordinate.
10. **Provider join:** page metadata is matched by page index from the same
    source document, with a fail-closed result for a missing or mismatched
    page.

## Evidence and re-entry gate

Evidence for this slice is Tier 1 static inspection only. No tests, builds,
benchmarks, or verification were run, as requested. The source remains
unchanged, so there is no source-behavior claim beyond preservation of the
current extraction and abstention path.

Re-enter implementation only when the owner of the shared coordinate contract
accepts the raw-versus-normalized representation and the focused fixture set
is available. At that point, update the parser, detector, and provider together
in one boundary change, preserve the raw evidence path, and compare candidate
and group membership before claiming normalization is safe.
