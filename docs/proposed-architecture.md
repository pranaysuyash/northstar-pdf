# Proposed PDF Editor Architecture

> **ARCHIVED — not current authority.** This document is superseded by `docs/decisions.md` (canonical decisions, D-001…D-057) and the single-status-authority rule (D-055). It is retained for historical trace only; it must not be cited as the current architecture, and it contains no primary gate/claim truth. See `docs/INDEX.md`.

**Status:** Accepted working architecture for implementation; final provider remains open
**Reviewed:** 2026-08-23
**Inputs:** [`../findings.md`](../findings.md), [`pdf-engine-comparison.md`](pdf-engine-comparison.md), and [`../task_plan.md`](../task_plan.md).

## Long-Term Product Architecture and Safety Boundary

The long-term product is a local-first native and web PDF reader/editor with
reader, forms, static-layout assistance, OCR, editing, templates, validation,
security, accessibility, and provider-backed capability planes. The initial
vertical slice is a local-first reader and bounded filler, not a permanent
product ceiling.

The safety boundary remains important: every operation must be typed,
source-bound, reviewable, replayable, and validated. “Bounded” describes this
mutation contract, not the long-term set of capabilities the platform may add.

### In scope for the first slice

- Local PDF open, page navigation, zoom, search, and rendering.
- Native AcroForm/widget inspection and filling.
- Static entry-region suggestions from page evidence.
- User review, correction, rejection, and manual region creation.
- Overlay text/image placement and annotations.
- Export to a new PDF copy.
- Undo, recovery, provenance, and save/reopen validation.

### Explicitly out of scope initially

- Arbitrary existing-text reflow.
- Automatic claims that a static box is a real form field.
- Silent mutation of the source file.
- Cloud OCR or document transfer by default.
- Signature invalidation or redaction claims without a dedicated design and test
  plan.

## Invariants

1. The original input bytes are immutable and recoverable.
2. Native fields and static suggestions are different domain types.
3. A heuristic suggestion cannot become an applied edit without user review.
4. `unknown` and `suggested` remain representable; neither becomes `true` or
   `verified` by default.
5. Every edit has a page coordinate, target, source, operation type, and provenance.
6. Filling a region cannot request deletion or rewriting of unrelated page content.
7. Export failure leaves the source and edit log intact.
8. A saved output must be reopenable before it is presented as successfully
   exported.
9. Local processing is the default; any external processing must be explicit and
   separately documented.

## Ownership and State

| Concern | Owner | State type |
|---|---|---|
| Original PDF bytes and digest | Document store | Persistent source |
| Rendered page images/tiles | Rendering provider adapter | Derived/cacheable |
| Native field inventory | Analysis pipeline | Derived, versioned |
| Static candidate inventory | Detection pipeline | Derived, uncertain |
| User review decisions | Edit session | Persistent user state |
| Applied edits | Edit log | Persistent historical state |
| Exported PDF | Export pipeline | Derived artifact |
| Export validation result | Validation pipeline | Derived evidence |

The original PDF remains the canonical document source. Rendered pages,
detections, and exports must carry the source digest and provider/version metadata
that produced them.

## Core Model

```text
DocumentSource
  -> PageSnapshot[]
       -> NativeField[]
       -> RegionCandidate[]
       -> ReviewDecision[]
       -> EditOperation[]
       -> ExportArtifact
            -> ValidationResult
```

### `RegionCandidate`

At minimum:

- `pageIndex`
- `rect` in PDF user-space coordinates
- `kind`: `native_field`, `vector_region`, `text_anchored`, `ocr_region`, or
  `manual`
- `status`: `suggested`, `confirmed`, `rejected`, or `unknown`
- `score` or confidence signal, explicitly labeled as a detection score rather
  than proof
- evidence references such as nearby label text, line/rectangle geometry, OCR
  text, and provider/version
- optional native field identifier when the candidate is native
- `entryMode`: the interaction shape currently supported by the editor, such as
  `singleText`, `characterGrid`, `checkbox`, `radioGroup`, `signature`, or
  `unknown`
- optional `labelText` and `groupMemberCount` so grouping and semantic evidence
  remain inspectable

### `EditOperation`

An append-only operation should identify:

- operation ID and parent edit-session version
- target page/field/region
- operation type: native field value, overlay text, image, annotation, or manual
  geometry
- input value and formatting parameters
- source candidate/review decision
- timestamp and application status
- undo inverse or recoverable prior state

## Detection Pipeline

1. **Native inspection:** enumerate AcroForm fields/widgets and their page
   rectangles using the selected provider.
2. **Page evidence extraction:** collect text spans, line/rectangle geometry,
   page boxes, rotation, and provider coordinates.
3. **Static candidate generation:** identify bounded whitespace, underlines,
   rectangles, table cells, label/value relationships, and repeated form motifs.
4. **OCR branch:** for scanned or text-poor pages, run a local OCR adapter and
   retain OCR provenance and uncertainty.
5. **Candidate ranking:** rank suggestions, but do not represent ranking as a
   binary truth claim.
6. **Review:** show evidence and allow move, resize, reject, or manual creation.
7. **Mutation:** only confirmed candidates can enter the edit log.

### Implemented review loop

The first vertical slice makes the review boundary observable rather than
implicit:

```text
candidate suggested
  -> highlight on page + evidence card
  -> user selects and enters text
  -> confirm -> reversible overlay operation + candidate confirmed
  -> undo -> overlay removed + candidate suggested again
  -> dismiss -> candidate rejected
  -> restore -> candidate suggested again

manual placement
  -> click page in PDF space
  -> enter text
  -> reversible overlay operation
```

The web lane renders this state machine in `web/index.html`; the native lane
owns the equivalent state in `AppModel.swift` and `ContentView.swift`. The
shared contract remains the source of meaning: the visual highlight is derived
UI, while the candidate coordinate and edit operation are page-space records.
This deliberately leaves “suggestion accepted” distinct from “detector proved
field semantics.”

Static geometry is interpreted group-first. Repeated small cells are claimed by
one logical candidate before isolated checkbox or input classification runs.
Character grids are directly editable as one logical operation whose value is
materialized one glyph per cell in the live preview and exported artifact.
Checkbox and radio patterns now have bounded choice interaction plus
export/reopen proof. Static checkbox/radio candidates remain review-first until
the user confirms the detected choice, while authored native controls can be
edited directly. Native double-click and web double-click both
enter the same page-space manual placement path, so detection improvements do
not change the coordinate or undo contract. The full exploration record is in
[`docs/audits/grouped-regions-and-direct-editing-exploration-2026-08-24.md`](audits/grouped-regions-and-direct-editing-exploration-2026-08-24.md).

The current interaction contract is intentionally bounded. Candidate move and
resize controls, rich text formatting, images, and native-field creation remain
separate expansions because each adds persistence, coordinate, and export gates.

The detector is a product-owned subsystem because no inspected PDF candidate
provides a general static blank-region detector. Detection output is a review
queue, not an editable field inventory. A user can reject a weak suggestion or
create a manual overlay without changing the detector's source evidence.

### OCR Policy

OCR is a fallback evidence adapter for scanned or text-poor pages, not a required
step for text-extractable documents such as Form 6. Its output may contribute
language, label, and approximate geometry evidence, but it cannot directly create
or verify a fill region.

- Native macOS candidate: Apple Vision `VNRecognizeTextRequest`.
- Permissive baseline candidate: Tesseract 5.x.
- Layout-aware candidates for a later scanned-document lane: PaddleOCR or Docling.

The first runtime benchmark should omit OCR for Form 6 and add a separate scanned
lane before selecting an OCR provider. Model files, transitive dependencies,
memory use, language coverage, and exact licenses require their own review.

## Platform Shell (Accepted Working Direction)

The user-approved working direction is native macOS first, with a browser/local
companion later. The native shell follows the document-based macOS model and uses
SwiftUI/AppKit with PDFKit behind an adapter.

The browser alternatives remain comparison lanes, not parallel editable sources of
truth:

- The browser shell should evaluate PDF.js for rendering/inspection and pdf-lib
  for bounded writes.
- A shared-core approach could keep provider-neutral detection/edit contracts in
  one implementation while exposing native and browser shells.

Any selected shell must map into the same provider-neutral document, candidate,
review, edit, and validation contracts. A browser export must not be assumed
equivalent to a native export.

PDFKit is a system framework rather than open-source, and its required save/reopen
and unrelated-content fidelity are unverified. It must not bypass the benchmark
or the license/distribution review.

## Rendering and Writing Boundary

The initial provider boundary is intentionally split while the benchmark remains
open:

- **Native macOS read/render/form candidate:** PDFKit.
- **Browser read/render adapter candidate:** PDF.js.
- **Browser bounded write adapter candidate:** pdf-lib.
- **Optional structural validator:** qpdf where packaging and runtime support make
  it appropriate; it is not the renderer or semantic editor.

The internal document and edit contracts must not expose provider-specific object
models. A future PDFBox or native adapter should translate into the same page
coordinates, field identity, candidate status, operation, warning, and validation
semantics.

## Export and Recovery

1. Keep the original bytes untouched.
2. Materialize the edit log against a new output copy.
3. Reopen the output with the read provider.
4. Check page count, page boxes, rotation, native-field inventory, and expected
   operation results.
5. Compare content outside edited regions using provider extraction and a reviewed
   raster-diff tolerance.
6. Mark the artifact `validated`, `validated_with_warnings`, or `failed`.
7. Never discard the edit log or original when export fails.

This is a validation strategy, not a current guarantee. It must be implemented
and tested before the product makes preservation claims.

## Security and Privacy Constraints

- Treat every PDF as untrusted input; parser crashes, malformed objects,
  decompression/resource exhaustion, embedded actions, and oversized files are
  threat surfaces.
- Disable or constrain document JavaScript and external actions by default unless
  a separate trust model is approved.
- Enforce file-size, page-count, memory, and timeout limits appropriate to the
  target platform.
- Keep OCR and analysis local by default and disclose any provider transfer.
- Do not log raw PDF contents, form values, or OCR text unless explicitly needed
  for a user-owned local diagnostic artifact.
- Preserve signatures and redaction semantics as unknown until separately tested;
  never imply that an export preserves signature validity automatically.

## Validation Corpus and Gates

The first benchmark corpus should contain:

- native text, checkbox, radio, choice, and signature fields
- static vector forms with boxes, lines, tables, and repeated labels
- scanned forms with OCR noise and skew
- hybrid scanned/vector documents
- rotated pages, crop/media-box differences, and unusual coordinate systems
- encrypted, linearized, malformed, and object-stream-heavy PDFs
- existing annotations, embedded files, signatures, and metadata
- Unicode, long text, small fields, and overflow cases
- large multi-page documents

Required evidence before selecting a final provider:

- native-field inventory precision/recall on reviewed fixtures
- static-candidate precision/recall and false-positive review rate
- save/reopen success across the corpus
- no unintended text/object changes outside edited regions, with a defined oracle
- visual review of representative pages and an independent-viewer check
- performance and memory measurements on target hardware
- negative tests for malformed/untrusted PDFs and resource limits
- license and dependency review for the exact packaged build

These are future Tier 2-5 checks, not results from this research phase.

## Options and Revisit Triggers

| Trigger | Revisit |
|---|---|
| Browser export fails visual or structural gates | Compare PDFBox and native options |
| Native desktop is mandatory | Evaluate PDFBox versus MuPDF/Poppler with licensing owner |
| Arbitrary semantic editing becomes core | Expand research; bounded overlay architecture is insufficient |
| Cloud OCR becomes required | Perform provider privacy, retention, cost, and failure review |
| Digital-signature preservation becomes core | Create a separate signature architecture and validation gate |

## Completeness

### Established Current State

The workspace contains research framing, runtime benchmark harnesses, and the
accepted implementation boundary. Product application code is now being added in
small vertical slices; no final provider clearance is implied.

### Accepted Working State

The provider-neutral contract, custom detection pipeline, immutable-source/edit-log
model, and native-first shell are the implementation path. Browser-first and
commercial/native alternatives remain comparison lanes. No provider has passed the
required full runtime corpus tests.

### Migration Confidence

The internal provider-neutral contracts should make a later PDFBox or native
adapter possible, but no migration implementation or compatibility test exists.

### Unresolved Decisions

- Exact native provider and browser-companion boundary.
- Acceptable license/distribution model.
- Initial corpus and fidelity threshold.
- OCR engine and whether OCR is required in the first slice.
- Whether native fields may be flattened or converted on export.

### Known Blind Spots

No static-region detection benchmark, mixed real-document corpus, OCR evaluation,
security audit, or legal review has been performed. The scoped PDFKit Form 6 and
public AcroForm lanes are runtime evidence, but they do not clear the broader
provider or fidelity gates.
