# PDF Feature Frontier

**Status:** Discovery artifact; no new feature implementation authorized by this document
**Date:** 2026-08-24
**Project:** `/Users/pranay/Projects/pdf_editor`
**Purpose:** Explore the useful PDF feature space for one native application and one local-first web application before choosing the next implementation slice.

## Executive recommendation

Build the product around a privacy-first, reversible completion workflow:

1. Open and render any PDF that the selected provider can safely parse.
2. Inspect native interactive fields first.
3. Detect likely static entry regions as evidence-backed suggestions.
4. Let the user review, correct, and fill those suggestions.
5. Represent every change as an operation over immutable source bytes.
6. Export a new copy and validate it by reopening, extracting, rendering, and comparing the result.

The first shared product boundary should be **reader + form completion + reviewed overlays + page operations + annotations + export validation**. It should not initially promise arbitrary text reflow or perfect semantic editing of every existing PDF object. Those are materially different capabilities and need a separate corpus and fidelity program.

The recommended platform composition is:

| Surface | Initial direction | Why |
|---|---|---|
| Native macOS | Existing PDFKit adapter behind provider-neutral contracts | Best integration with the current macOS shell, file picker, security-scoped URLs, and native rendering. Apple documents PDFKit for displaying and manipulating PDF documents, including pages, selection, annotations, and widgets. [Apple PDFKit](https://developer.apple.com/documentation/pdfkit) |
| Web, local-first | PDF.js for parsing/rendering/inspection plus pdf-lib for bounded writing and overlays | PDF.js provides browser rendering, text content, annotations, and annotation storage; pdf-lib provides page drawing, form operations, page insertion/copying, images, fonts, and saving. They complement each other instead of pretending one library is both a viewer and a complete editor. [PDF.js API](https://mozilla.github.io/pdf.js/api/), [pdf-lib PDFDocument](https://pdf-lib.js.org/docs/api/classes/pdfdocument) |
| Optional high-fidelity lane | MuPDF.js or a local/server PDFBox lane, only after license and corpus gates | MuPDF exposes a broad read/render/manipulate surface but its JavaScript distribution is AGPL or commercial. PDFBox is Apache-2.0 and covers extraction, forms, rendering, preflight, creation, and signing, but requires a JVM boundary. [MuPDF.js](https://github.com/ArtifexSoftware/mupdf.js/), [Apache PDFBox](https://pdfbox.apache.org/) |
| OCR | Native Vision or a local OCR worker; OCRmyPDF/Tesseract are batch and searchable-layer candidates | OCR is a recognition aid, not proof that a visual blank region is safe to fill. OCRmyPDF adds searchable text layers, sidecar text, and PDF/A options, but its dependency and security boundaries must be isolated. [OCRmyPDF introduction](https://ocrmypdf.readthedocs.io/en/latest/introduction.html) |

## Feature taxonomy

The same feature can have different implementation status on native and web. The feature list below is deliberately broader than the first release so that product scope is chosen consciously rather than by accidental library availability.

### 1. Reading and navigation

| Feature | Native | Web | Shared contract | Notes and proof needed |
|---|---|---|---|---|
| Open/import PDF | Yes | Yes | `DocumentSource` | MIME/extension checks, malformed input, password prompt, size limits, cancellation |
| Continuous, single-page, two-page, fit-width, fit-page views | Yes | Yes | `ViewState` | Render parity is visual evidence, not a unit-test claim |
| Zoom, rotate, pan, page jump | Yes | Yes | `PageViewport` | All selection and overlay coordinates must round-trip through rotation and crop boxes |
| Thumbnail strip and page labels | Yes | Yes | `PageIndex` | Generate thumbnails lazily for large documents |
| Text selection and copy | Yes | Yes | `TextSpan` with page-space bounds | Scanned PDFs require OCR; copied text must be marked as extracted or recognized |
| Search, next/previous, match highlighting | Yes | Yes | `SearchMatch` | Search native text and OCR text separately in the result explanation |
| Links, named destinations, outlines/bookmarks | Yes | Yes | `NavigationTarget` | External links need a safe-open policy; embedded JavaScript should not execute by default |
| Attachments, metadata, page boxes, permissions | Yes | Conditional | `DocumentFacts` | Web access depends on provider support; show unknown rather than inventing values |
| Password-protected and encrypted PDFs | Conditional | Conditional | `UnlockSession` | Never bypass a password; distinguish open password from edit permission |
| Accessibility tree, reading order, tags | Conditional | Conditional | `AccessibilityFacts` | Preserve tags where the provider permits; do not claim PDF/UA compliance without a validator |

### 2. Native interactive forms

| Feature | Native | Web | Shared contract | Safety boundary |
|---|---|---|---|---|
| Inventory AcroForm fields | Yes in current PDFKit lane | Yes with PDF.js inspection or pdf-lib form APIs | `NativeField` | Native fields are higher-confidence than visual candidates |
| Text fields | Yes | Yes | `FieldValueOperation` | Font embedding, Unicode, appearance streams, multiline and comb settings need corpus tests |
| Checkboxes | Yes | Yes | `FieldValueOperation` | Preserve export value and appearance state |
| Radio groups | Conditional | Conditional | `ChoiceValueOperation` | Existing PDFKit public-form benchmark lost radio-choice metadata on no-op save; keep this provider gate visible |
| Combo boxes and list boxes | Conditional | Conditional | `ChoiceValueOperation` | Preserve option labels, export values, selected index, and appearance |
| Signature widgets | Inventory only initially | Inventory only initially | `SignatureField` | A visible signature is not a cryptographic signature |
| Required-field and format validation | Yes | Yes | `FieldValidationResult` | Use provider metadata plus product-level rules; never infer legal validity |
| Keyboard field navigation | Yes | Yes | `FieldOrder` | Required for fast completion of long forms |
| Fill from a saved profile/template | Yes | Yes | `FieldMapping` | Store user-approved mappings, not silent semantic guesses |
| Flatten completed form | Yes | Yes | `FlattenOperation` | Destructive to interactivity; always export a separate copy and state that fields are no longer editable |
| Create new fillable fields | Later | Later | `FieldDefinitionOperation` | Requires accurate widget appearance, tab order, naming, and viewer compatibility |
| XFA forms | Warn/limited | Warn/limited | `UnsupportedFeature` | Treat dynamic XFA as a separate compatibility lane; do not silently convert it |

### 3. Static blank-field and box assistance

This is the product differentiator. It is not the same as reading AcroForm widgets.

| Capability | Native | Web | Shared contract | Confidence rule |
|---|---|---|---|---|
| Detect vector rectangles and lines | Yes | Yes, if provider exposes geometry | `GeometryEvidence` | Candidate only; a table cell is not necessarily an input |
| Detect underline-like blanks | Yes | Yes | `TextAndGeometryEvidence` | Use text, line length, surrounding whitespace, and alignment |
| Detect checkbox/radio-like empty shapes | Yes | Yes | `ShapeCandidate` | Avoid classifying decorative bullets or table cells automatically |
| Detect empty image/scanned boxes | Yes with OCR/raster pipeline | Yes with worker or local companion | `RasterEvidence` | Region proposal must carry crop/rotation and image confidence |
| Associate label with candidate | Yes | Yes | `LabelAssociation` | Record label text, distance, reading order, and ambiguity |
| Infer field type | Yes | Yes | `CandidateKind` | Return text/date/number/checkbox/signature suggestion with evidence; user confirms |
| Suggest tab order | Yes | Yes | `FieldOrderSuggestion` | Never silently make a guessed order authoritative |
| Guided “next blank” entry | Yes | Yes | `CompletionSession` | Entering text should be easy; applying it should remain reversible |
| Create a real native form field from a static region | Later | Later | `CreateFieldOperation` | Separate from overlay fill; needs external-viewer round-trip proof |
| Learn a reusable template | Designed next | Designed next | `TemplateDefinition` | Privacy-minimized keyed layout fingerprints, explicit reviewed mappings, local value references, and immutable revisions; no silent autofill |

### 4. Bounded editing and markup

| Feature | Native | Web | Shared contract | Initial stance |
|---|---|---|---|---|
| Add text overlay | Yes | Yes | `OverlayTextOperation` | Primary safe edit for static blanks and notes |
| Add image, stamp, logo | Yes | Yes | `OverlayImageOperation` | Embed image and record source/provenance |
| Draw, highlight, underline, strikeout, note, freehand | Yes | Yes | `AnnotationOperation` | Keep annotations distinct from content replacement |
| Add checkmark, cross, date, initials | Yes | Yes | `StampOperation` | Useful for static forms; coordinate and visual proof required |
| Move, resize, recolor overlays | Yes | Yes | Operation replay | Keep original PDF content untouched until export |
| Edit existing text object in place | Conditional | Conditional | `ObjectEditOperation` | Only when provider identifies an editable object and preserves layout |
| Edit existing image object | Conditional | Conditional | `ObjectEditOperation` | Need image identity, clipping, masks, and resource preservation |
| Erase/whiteout content | Conditional | Conditional | `CoverOperation` | Must not be called redaction; content may remain underneath |
| Arbitrary paragraph reflow | No initial promise | No initial promise | Separate future capability | Requires layout reconstruction and is not a safe extension of overlay editing |
| Watermark/header/footer/page numbers | Yes | Yes | `BatchOverlayOperation` | Good batch feature with deterministic geometry |
| Background/foreground replacement | Later | Later | `PageLayerOperation` | Can destroy or obscure existing content; explicit confirmation required |

### 5. Annotations, redaction, and security-sensitive operations

| Feature | Native | Web | Shared contract | Risk |
|---|---|---|---|---|
| Highlight and review comments | Yes | Yes | `AnnotationOperation` | Annotation visibility and flattening vary by viewer |
| Redaction marking | Later | Later | `RedactionMark` | Marking is not removal |
| Apply permanent redaction | Gated | Gated | `ApplyRedactionOperation` | Verify text, vector, raster, metadata, hidden layers, and copy/paste removal |
| Remove metadata and hidden content | Later | Later | `SanitizeOperation` | Must specify what is removed and preserve a before/after report |
| Remove JavaScript/actions | Later | Later | `SanitizeOperation` | Prefer safe non-execution by default; sanitation needs structural checks |
| Permissions/password/encryption | Later | Later | `SecurityOperation` | Requires key handling, failure recovery, and export/reopen tests |
| Visual handwritten signature | Yes | Yes | `SignatureAppearanceOperation` | Image/drawn/type signature only; not proof of identity or signing authority |
| Cryptographic digital signature | Gated | Gated | `DigitalSignatureOperation` | Certificate, trust chain, byte-range preservation, timestamp, and independent verifier required |
| Signature validation | Gated | Gated | `SignatureValidationReport` | Report signer, integrity, trust, and unknown states separately |

### 6. Page and document operations

| Feature | Native | Web | Shared contract |
|---|---|---|---|
| Reorder pages | Yes | Yes | `PageMoveOperation` |
| Insert/delete/extract pages | Yes | Yes | `PageSetOperation` |
| Split/merge PDFs | Yes | Yes | `DocumentCompositionOperation` |
| Rotate pages and normalize orientation | Yes | Yes | `PageTransformOperation` |
| Crop/media/trim/bleed box editing | Conditional | Conditional | `PageBoxOperation` |
| Blank-page detection/removal | Yes | Yes | `PageClassification` |
| N-up/booklet/imposition | Later | Later | `LayoutOperation` |
| PDF to image/text | Yes | Yes | `ExportArtifact` |
| Image/text/office to PDF | Conditional | Conditional | `ImportConversionOperation` |
| Compare two revisions | Yes | Yes | `ComparisonReport` |
| Batch processing and pipelines | Later | Yes via worker/server | `JobPlan` |

### 7. OCR, layout, and extraction

| Feature | Native | Web | Shared contract | Boundary |
|---|---|---|---|---|
| Detect scanned/no-text pages | Yes | Yes | `PageFacts` | Heuristic only until OCR probe completes |
| OCR text layer | Local worker/native | Browser worker or companion | `RecognitionLayer` | Preserve source image; do not replace content by default |
| OCR bounding boxes | Yes | Yes | `TextSpan` | Needed for label association and search highlighting |
| Deskew/denoise/rotate | Yes | Conditional | `ImagePreprocessOperation` | Keep preprocessing separate from PDF mutation |
| Tables and reading order | Conditional | Conditional | `LayoutStructure` | Extraction may be useful without promising faithful editing |
| Key-value extraction | Conditional | Conditional | `ExtractionResult` | Always show source page/bounds and confidence |
| Sidecar JSON/CSV/text export | Yes | Yes | `ExtractionArtifact` | Useful for downstream workflows and debugging detection |
| Template matching | Later | Later | `TemplateMatch` | Requires corpus, versioning, and false-positive controls |

## Cross-platform parity rules

The product should promise parity at the intent and safety level, not identical pixels from different engines.

1. **Canonical coordinates:** store page-space points with page index, crop box, rotation, and coordinate-system version. Convert to native view or browser viewport coordinates only at the edge.
2. **Immutable source:** source bytes are never overwritten during a session. Native uses a new export path; web uses a new download or explicitly approved file-handle write.
3. **Operation log:** edits are typed operations with stable IDs, target evidence, previous value where reversible, and an explicit destructive flag.
4. **Confidence is not truth:** every static candidate records evidence and confidence. Only native fields may bypass candidate confirmation, and even native fields require provider-preservation tests.
5. **Capability reports:** unsupported features are surfaced as known limitations with a fallback, not silently dropped.
6. **Export validation:** reopen output, compare page count and geometry, verify applied operations, extract text, inspect fields, render representative pages, and run independent structural checks.
7. **Provider evidence is scoped:** a PDFKit pass does not clear the web writer; a PDF.js rendering pass does not clear PDF writing; a synthetic widget test does not clear external AcroForm preservation.

## Suggested product surfaces

### Native application

- Finder/open-with and recent documents.
- Large-document reader with thumbnails, search, outline, and page navigator.
- “Complete form” mode that moves through native fields and reviewed static candidates.
- Inspector showing field/candidate evidence, source bounds, confidence, and edit history.
- Overlay toolbar for text, checkmark, initials, date, image, stamp, and visual signature.
- Page organizer for reorder, rotate, extract, delete, and merge.
- Review mode for annotations, comparison, and export warnings.
- Offline OCR and optional local companion for heavier work.
- Export report that can be saved alongside the result.

### Web application

- Drag/drop and file picker import.
- Local-first document workspace with no upload required for the core lane.
- PDF.js reader surface with a separate editable overlay layer.
- Browser-supported save-to-file handle where available, download fallback everywhere else.
- IndexedDB/OPFS-backed draft and thumbnail cache; browser storage must be treated as cache, not the only authoritative copy.
- Responsive completion flow for keyboard, touch, and assistive technology.
- Shareable, explicit export artifact; collaboration should be a later mode with a server authority.
- Optional local companion/server lane for OCR, large files, conversion, and high-fidelity operations.

## Deliberate non-goals for the first build

- Perfect editing of arbitrary existing text with automatic line reflow.
- Silent conversion of static boxes into AcroForm fields.
- Silent flattening or destructive whiteout.
- Claims that visual signatures are legally binding or identity-verified.
- Public upload of sensitive documents by default.
- Treating OCR output as authoritative without user review.
- Claiming PDF/A, PDF/UA, or digital-signature compliance without an independent validator.

## Discovery exit criteria

Before the next implementation slice is selected, the project should have:

- a fixed representative corpus: native AcroForms, static text forms, grids/tables, scans, rotated pages, mixed text/image PDFs, malformed/encrypted files, annotations, and signed files;
- a provider capability manifest for native and web;
- a license inventory and dependency boundary;
- an operation schema and coordinate transform test;
- a static-region benchmark with reviewed ground truth and abstention metrics;
- no-op and bounded-edit preservation tests against at least two independent viewers or renderers;
- a web storage and privacy threat model;
- an explicit choice between browser-only, native-only, and companion-backed lanes for OCR and high-fidelity editing.

## Sources consulted on 2026-08-24

- [Apple PDFKit](https://developer.apple.com/documentation/pdfkit)
- [PDF.js API](https://mozilla.github.io/pdf.js/api/)
- [PDF.js getting started and layers](https://mozilla.github.io/pdf.js/getting_started/)
- [pdf-lib PDFDocument API](https://pdf-lib.js.org/docs/api/classes/pdfdocument)
- [pdf-lib PDFPage API](https://pdf-lib.js.org/docs/api/classes/pdfpage)
- [Apache PDFBox](https://pdfbox.apache.org/)
- [MuPDF.js repository and license boundary](https://github.com/ArtifexSoftware/mupdf.js/)
- [Stirling PDF functionality reference](https://docs.stirlingpdf.com/functionality/)
- [Stirling PDF developer architecture reference](https://github.com/Stirling-Tools/Stirling-PDF/blob/main/DeveloperGuide.md)
- [OCRmyPDF introduction](https://ocrmypdf.readthedocs.io/en/latest/introduction.html)
- [OCRmyPDF advanced output and PDF/A behavior](https://ocrmypdf.readthedocs.io/en/stable/advanced.html)
- [MDN File System API](https://developer.mozilla.org/en-US/docs/Web/API/File_System_API)
- [MDN IndexedDB API](https://developer.mozilla.org/en-US/docs/Web/API/IndexedDB_API)
