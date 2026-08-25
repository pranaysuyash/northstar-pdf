# Performance Lane C: Geometry

Date: 2026-08-25
Owner: Lane C geometry performance and ownership
Status: bounded semantics-preserving implementation slice

## Scope and authorization

This lane owns geometry extraction and static-region detector performance in
the shared main checkout. The canonical current write set is exactly:

- `Sources/PDFEditorCore/PDFVectorStreamParser.swift`
- `Sources/PDFEditorCore/StaticRegionDetector.swift`
- `docs/roadmaps/performance-lane-c-geometry.md`

The user explicitly excluded Git mutations and requested no tests, builds,
benchmarks, or verification. No Git state was changed. The owned source files
were clean at the edit boundary; unrelated work was left untouched.

## Implemented slice

`StaticRegionDetector.swift` now performs three bounded, semantics-preserving
hot-path improvements:

1. It filters the same field-label vocabulary once per page geometry before
   nearest-label matching. The matching distance rules, label vocabulary,
   iteration order among eligible lines, and candidate semantics are unchanged.
2. It gives the small-cell staging array a capped reserve hint of 256 entries.
   The cap affects only allocation behavior; no input is discarded and the
   existing checkbox/input inclusion rule is unchanged.
3. It replaces `Array(Set(boxes))` with stable first-seen deduplication. The
   same `PDFRect` set reaches grouping, while preserving source order instead
   of exposing Swift hash iteration order. Row tolerances, width signatures,
   gap thresholds, minimum group size, and union behavior are unchanged.

`PDFVectorStreamParser.swift` remains source-untouched in this slice. Its
current append-and-classify path does not expose a clearly safe optimization
within this write set: speculative scanner reserves could allocate for empty
pages, and parser-side deduplication would change the raw geometry arrays or
the provider evidence population. The parser is therefore recorded as a
future profiling target, not changed on intuition.

## Static metrics and measurement status

These are static contract metrics, not runtime measurements:

| Area | Before | After | Expected effect |
|---|---|---|---|
| Label eligibility | Trim/token regular-expression work repeated for each vector box lookup | One filtered label array per page geometry | Removes repeated eligibility work; nearest-label scan remains bounded by the same eligible lines |
| Small-cell staging | Array grew from the checkbox input without a reserve hint | Reserve hint capped at 256, then the same append rule | Fewer small reallocations without an unbounded upfront allocation |
| Cell deduplication | `Set` deduplication with nondeterministic output order | One bounded reserve hint plus stable first-seen `Set` deduplication | Same unique cells and grouping policy, deterministic input order |
| Parser allocations | Existing lazy arrays and capped classification reserves | Unchanged | No unmeasured parser allocation claim is made |

Wall-clock timing, allocation counts, peak memory, raw rectangle counts,
candidate counts, and corpus-level grouping deltas are intentionally
unmeasured in this slice because the user prohibited benchmarks and
verification. The next metrics pass should capture, per page and per corpus,
raw rectangles, clean rectangles, small cells, unique cells, grouped cells,
eligible labels, nearest-label calls, candidates, elapsed time, and peak
allocation. It must compare candidate membership and group membership before
and after the optimization.

## Invariants

- Coordinates retain their existing meaning. This lane does not convert,
  rotate, translate, crop-normalize, or otherwise reinterpret rectangles.
- Page indices remain zero-based wherever the shared model carries them.
- The field vocabulary, candidate types, evidence origins, status policy,
  scores, label distance limits, grouping thresholds, and grouping minimums
  remain unchanged.
- Stable deduplication changes only the unspecified hash-order sequence of
  duplicate-free cells. It does not remove a distinct rectangle or merge
  rectangles that were not already equal under `PDFRect` equality.
- Browser parity and provider behavior are unchanged. No provider, browser,
  contract, fixture, or test file is part of this implementation slice.
- Raw vector geometry remains review evidence, not authored field intent.
  Unlabeled repeated grids continue to abstain from candidate promotion.

## Provider-boundary coordinate issue

The canonical shared contract is points, lower-left origin, crop-box-relative,
zero-rotation page space unless a `PDFPageRegion` names another space. The
vector parser currently reads `CGPDFPage` content using the media box and
returns transformed rectangles plus a `mediaBox`; it does not attach crop-box
offset or page-rotation metadata to those parsed rectangles. The PDFKit
inspection/provider boundary separately uses crop-box page bounds and carries
page rotation in page snapshots. This leaves a provider-boundary risk: raw
parser geometry can be treated as canonical crop-relative edit geometry even
when the source page has a non-zero crop origin or rotation.

This is an observed contract mismatch risk from static inspection, not a claim
that every document is currently wrong. It is deliberately not normalized in
Lane C. Fixing it would change coordinate meaning and requires the provider
boundary, persisted region construction, and native/browser parity evidence to
agree on one conversion point.

## Canonical future write set

The current performance write set remains the three files listed above. A
future semantic coordinate-normalization slice must be planned separately and
must include, at minimum:

- `Sources/PDFEditorCore/PDFVectorStreamParser.swift`, for an explicit raw
  geometry boundary or coordinate metadata;
- `Sources/PDFEditorCore/StaticRegionDetector.swift`, for consuming that
  explicit space without guessing;
- `Sources/PDFEditorCore/PDFKitProvider.swift`, for provider-boundary
  crop/rotation conversion and fail-closed validation;
- `docs/shared-contracts.md`, only if the canonical conversion or vocabulary
  changes, plus the corresponding parity fixtures and checks owned by that
  future slice.

`PDFKitProvider.swift` is intentionally not modified here. Semantic
normalization is deferred because performance ownership does not authorize a
coordinate contract migration, and silently applying a transform in this lane
could make native and browser geometry disagree while appearing faster.

## Evidence and next gate

Evidence level for this slice is Tier 1 static inspection. Test sensitivity is
S0 because no checks were run, as requested. The next gate is a separately
authorized measurement and contract-parity pass that proves unchanged
candidate/group membership on representative duplicated-cell, rotated-page,
and non-zero-crop fixtures before any coordinate normalization is accepted.
