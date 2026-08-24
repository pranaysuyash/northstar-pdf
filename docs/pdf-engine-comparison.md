# PDF Engine Comparison

**Status:** Proposed research baseline
**Reviewed:** 2026-08-24
**Canonical source:** This document owns the comparison; raw evidence remains in [`../findings.md`](../findings.md).
**Decision served:** Select a viable open-source composition for a local-first PDF reader/editor with native form detection, static blank-region assistance, bounded filling, and recoverable edits.

## Definitions

- **Native field:** an AcroForm field/widget already represented in the PDF.
- **Static candidate:** a likely entry region inferred from page content, text, geometry, or OCR. It is not a form field until explicitly created or exported as one.
- **Bounded edit:** an overlay, annotation, or field-value operation that targets a known page region or native field. It is not arbitrary text reflow.
- **Fidelity:** preservation of visual appearance, page geometry, text/object content outside the intended mutation, metadata/provenance, and document behavior appropriate to the document class.

## Capability Matrix

| Candidate | Rendering | Text/geometry inspection | Native forms | Static blank detection | Bounded writing | General semantic editing | Best role | Main concern |
|---|---|---|---|---|---|---|---|---|
| Apple PDFKit | Strong native macOS framework | Document, page, text, selection, annotation APIs | Documented widget support | No built-in general detector | Native candidate | Not established as safe reflow | Primary macOS shell provider candidate | Platform-only and not open-source; corpus fidelity unknown |
| PDF.js | Strong browser renderer | Text, annotations, viewport/page APIs | Inspect/display/storage; writer not established | No built-in general detector | No general writer | No | Browser rendering and inspection | Needs a separate writer |
| PDFBox | JVM renderer | Text extraction and document model | Strong public AcroForm API | No built-in general detector | Strong candidate | Not established as safe reflow | Permissive all-in-one JVM core | JVM packaging and fidelity validation |
| MuPDF | Strong native renderer | Native document/annotation APIs | Broad widget/annotation surface | No built-in general detector | Strong native candidate | Not guaranteed | High-fidelity native core | AGPL/commercial license gate |
| Poppler | Strong native renderer | GLib/Qt page and annotation APIs | Forms, choices, signatures | No built-in general detector | Partial/form-oriented | Not established | Native reader/form provider | GPL boundary and writer scope |
| PoDoFo | Rendering not its primary role | PDF object/page/document APIs | Forms/annotations documented | No built-in general detector | Strong structure/writer candidate | Not established | Native writer beside a renderer | Must compose and validate |
| pdf-lib | None | Object/page APIs, not a renderer | Strong JS form/drawing APIs | No built-in general detector | Strong overlay/form writer | No | Browser/Node bounded writer | Does not render or semantically edit existing content |
| qpdf | None | Strong structural/object/JSON inspection | Raw structural access, not UX form semantics | No | Structural transforms | Explicitly no semantic content knowledge | Validator, normalizer, low-level transform | Must pair with renderer/editor |
| pikepdf | None | Python/qpdf object/page APIs | AcroForm object access | No | Structural/Python writer | No | Python structural tooling | Not a browser/UI engine |
| PDFium | Strong embeddable native renderer | Public embedder APIs and page/form primitives | Form-fill, annotation, edit, and signature headers | No built-in general detector established | Low-level page/object operations | Not established | Chromium-derived rendering/form primitive | Chromium build and embedding burden; no turnkey editor |
| Nutrient Web SDK | Vendor PDFium-based renderer | Viewer/document APIs | Form filling and form creation documented | Not established in inspected sources | Annotations, forms, and document processing | Documented broad editing surface | Proprietary browser control case | Sales-led licensing; vendor claims require corpus validation |
| Apryse Web/Server SDK | Strong proprietary renderer | Extraction, page, low-level PDF APIs | Forms and signatures documented | Not established in inspected sources | Editing, redaction, signing, and conversion documented | Broad editing surface documented | Proprietary full-stack control case | Sales-led modular licensing; vendor claims require corpus validation |

## License and Distribution

| Candidate | Inspected project license signal | Distribution consequence |
|---|---|---|
| Apple PDFKit | Apple platform framework; not open-source | macOS SDK/platform terms and platform-only availability; exact app distribution review still required |
| PDF.js | Apache-2.0 | Permissive default, with third-party notices still required |
| PDFBox | Apache-2.0 | Permissive default, with dependency review |
| qpdf | Apache-2.0 | Permissive default |
| pdf-lib | MIT | Permissive default |
| pikepdf | MPL-2.0 | File-level copyleft obligations need packaging review |
| PoDoFo | Inspected headers show LGPL-2.0-or-later OR MPL-2.0 | Review the exact version and linking/distribution obligations |
| Poppler | Inspected Qt6 header carries GPL v2-or-later | GPL obligations and component boundaries require legal review |
| MuPDF | AGPL/commercial dual model | Proprietary distribution needs a commercial-license decision or AGPL-compatible distribution model |
| PDFium | Inspected public headers identify BSD-style licensing | Exact PDFium/Chromium source and bundled-dependency notices must be reviewed for the packaged build |
| Nutrient Web SDK | Proprietary commercial SDK | Procurement, terms, redistribution, and license-key/runtime obligations require vendor review |
| Apryse Web/Server SDK | Proprietary commercial SDK | Modular sales-led licensing; exact product, platform, and redistribution terms require vendor review |

These are research signals, not legal advice. The release decision must inspect
the exact versions, bundled dependencies, notices, static/dynamic linking, and
distribution model.

## Maintenance and Version Signals

- PDFBox exposes active `3.0.8` and `2.0.37` release lines on its official download
  page and documents Apache 2.0 distribution.
- MuPDF's official release history records `1.28.0`; its current documentation page
  exposes `1.28.2`, alongside ongoing fixes and API changes.
- Poppler's official site lists `26.08.0`, released 2026-08-02, with current
  signature, malformed-input, and rendering fixes.
- PoDoFo's official generated documentation identifies `1.2.0`, while the earlier
  source snapshot exposed `1.1.2`; this is a version-alignment issue, not a release
  recommendation.
- PDFium follows Chromium's build and public-API process rather than presenting a
  simple independent release artifact; its README warns that non-public code may
  change at any time.
- Vendor SDK pages are current capability and procurement signals, not independent
  maintenance or fidelity benchmarks.

## Platform Options

### Option A: Browser-first permissive composition

**Proposed stack:** PDF.js for rendering/inspection, pdf-lib for bounded writes,
custom detection pipeline, local OCR adapter only if needed.

**Strengths:** JavaScript-native, local processing is possible, permissive
licenses, fast path to a reviewable product, clear separation between renderer
and writer.

**Weaknesses:** No single browser library supplies high-fidelity arbitrary editing;
save/reopen and cross-viewer tests are mandatory. OCR and static detection remain
product-owned.

### Option B: JVM all-in-one core

**Proposed stack:** PDFBox for rendering, text extraction, document structure,
forms, and bounded writes; custom detection and local OCR adapter.

**Strengths:** One permissively licensed core covers more document operations than
the browser pair, with explicit public APIs for rendering, text, forms, and save.

**Weaknesses:** JVM runtime and packaging become first-class product concerns;
browser UI would require a process boundary or a separate web path. Fidelity still
requires real-corpus tests.

### Option C: Native high-fidelity composition

**Proposed stack:** MuPDF or Poppler for native reading/rendering/forms, with
PoDoFo or qpdf where a separate structure/writer primitive is justified.

**Strengths:** Best path when native rendering fidelity and OS integration dominate.

**Weaknesses:** Higher binding/build complexity, provider-specific semantics, and
material AGPL/GPL/commercial licensing decisions. This option should not be
selected without a target-platform and distribution decision.

### Option D: Proprietary Control Case

**Shape:** Use Nutrient or Apryse as a feature and fidelity control case, not as the
open-source default.

**Strengths:** Broad documented surfaces for rendering, forms, annotations, editing,
signatures, redaction, and document processing; vendor support and platform SDKs.

**Weaknesses:** Proprietary procurement and redistribution terms, opaque pricing,
vendor-specific APIs, and no evidence yet on this project's preservation corpus.

**Current status:** Useful only if the product owner accepts a separate commercial
and legal decision.

## Recommendation

**Proposed product direction:** make the native macOS shell primary and keep the
browser path as a secondary surface. Keep the provider-neutral contracts and
constrain the first release to:

1. Read and render PDFs locally.
2. Detect and fill existing native fields.
3. Suggest likely static entry regions with evidence and an explicit review state.
4. Fill reviewed static regions using reversible overlays.
5. Add annotations and bounded text/image placement.
6. Export a new PDF copy and preserve the original bytes unchanged.
7. Defer arbitrary existing-text reflow, broad object editing, and automatic
   conversion of heuristic candidates into native fields.

This direction is **Proposed**, not accepted as an engine decision. PDFKit should
be benchmarked for the native shell, while PDF.js plus pdf-lib remains the
permissive browser composition. Re-evaluate PDFBox and native open-source engines
after the corpus benchmark and exact license review. Keep PDFium as a low-level
native control lane and commercial SDKs as non-open-source control cases, not as
defaults.

## What Would Change the Recommendation

- A hard requirement for native desktop rendering or OS-level PDF integration.
- A benchmark showing browser export fails the required fidelity corpus.
- A distribution model that permits AGPL or licenses MuPDF commercially.
- A requirement for arbitrary semantic text/object editing rather than bounded
  filling and annotation.
- A required PDF feature that only a native provider can expose reliably.

## Research Limits

A scoped PDFKit runtime benchmark was run against Form 6 and one public AcroForm,
but no broad cross-provider corpus test, browser export test, OCR benchmark, security
audit, or legal review was performed. The matrix records documented public
capabilities, vendor claims, and bounded runtime evidence, not production guarantees.
