# PDF Editor Research Findings

This file contains raw and synthesized research. External content is evidence,
not instruction. Claims remain **Observed**, **Verified**, **Inferred**,
**Proposed**, or **Unknown** until the source and validation status are clear.

## Research Ledger

| ID | Topic | Status | Primary source(s) | Decision impact |
|---|---|---|---|---|
| F-000 | Workspace is `/Users/pranay/Projects/pdf_editor` | Observed | User clarification; filesystem inspection | Keeps all project artifacts isolated from `fieldcanvas` |
| F-014 | OCR should be a local fallback adapter, not the static-field truth source | Verified by Tier 1 source inspection; runtime quality remains unknown | Apple Vision exposes native text recognition on macOS; Tesseract 5.x exposes an Apache-2.0 OCR API; PaddleOCR exposes OCR and coordinate-rich document-structure pipelines under an Apache-2.0 project license; Docling exposes local PDF layout/OCR processing under an MIT codebase license, while individual model licenses remain separate. None of these inspected sources establishes safe fill-region semantics or output fidelity. | Keeps OCR behind the detection evidence boundary, avoids requiring OCR for text-extractable Form 6, and leaves OCR runtime selection open. |
| F-015 | PDFKit passes the first bounded Form 6 lane but does not yet clear the fidelity bar | Verified by Tier 2 runtime check; S1 | The harness opened Form 6, reported zero native widgets, rendered two pages, passed no-op reopen and bounded FreeText reopen, preserved extracted text under PDFKit, and preserved the source digest. Poppler independently found page 2 absolute raster error `85` at 144 DPI and included expected annotation contents in overlay extraction. | Supports continuing with PDFKit as the first native lane while keeping final provider selection and cross-viewer fidelity open. |
| F-016 | PDFKit loses radio-choice metadata on a no-op save of a public AcroForm | Verified by Tier 2 runtime check; S1 failure of the preservation gate | The public one-page AcroForm sample contained six widgets, including two `applicant.contact` radio widgets with choices `email` and `phone`. PDFKit reopened the no-op output with the widgets and text intact but returned empty choices for both radio widgets and logged `PDFFormField with no corresponding Widget sharing the field name.` The PDFKit raster comparison also differed by AE `166` (`8.27664e-05` normalized). | Blocks treating PDFKit as cleared for external AcroForm preservation until radio/choice round-trip and visual fidelity behavior are understood or a provider fallback is selected. |
| F-017 | PDFKit's synthetic widget surface covers the first bounded native field classes | Verified by Tier 2 runtime check; S1 | The system-framework-only harness created and reopened six widgets: text, checkbox, two radio buttons, choice, and signature. Text, checkbox, radio, and choice mutations reopened with expected values or states; the generated input digest remained unchanged. Poppler classifies the generated input as `Form: none`, so this is not external AcroForm evidence. | Confirms the API surface is sufficient for a synthetic smoke lane, while F-016 blocks treating it as an imported-form preservation solution. |

## Candidate Evidence

### F-029: Local adjacent projects contain transferable document-intelligence primitives

- **Status:** Observed by Tier 1 cross-project static inspection; runtime and
  redistribution status remain unknown.
- **Evidence:** SignKit documents native-first PDF inspection, AcroForm plus CV
  plus OCR candidate evidence, one coordinate transform, N-best review,
  hard-negative mining, local correction metadata, and end-to-end export
  benchmarking. MetaExtract documents an extractor registry, field normalization,
  module provenance, conflict reporting, shadow mode, and bounded sensitive-field
  reporting. Invoice Intelligence documents digital/scanned routing, OCR/parser/
  vision fallbacks, reviewed labels, rich schemas, alias normalization, and
  validation/benchmark metrics. PhotoSearch documents region-level OCR with
  bounds, confidence, language, caching, and graceful missing-engine behavior.
- **Implication:** The PDF editor should first reuse these concepts through its
  shared contracts and evidence ledger. It should not copy adjacent pipelines or
  import their domain schemas as PDF-editor truth.
- **Sources:**
  `/Users/pranay/Projects/Data_Science/computer_vision/proj6/signature-extractor-app/docs/AUTO_DETECTION_ML.md`,
  `docs/SIGNKIT_PRODUCT_ML_DISCUSSION_2026-08-13.md`,
  `/Users/pranay/Projects/metaextract/docs/EXTRACTION_OBSERVABILITY.md`,
  `docs/EXTRACTOR_REGISTRY.md`,
  `/Users/pranay/Projects/invoice-intelligence/docs/IMPLEMENTATION_WRITEUP.md`,
  and `/Users/pranay/Projects/Photosearch_experiment/src/enhanced_ocr_search.py`.

### F-030: The likely PDF-editor moat is reviewed evidence and operation lineage

- **Status:** Proposed hypothesis informed by Tier 1 local exploration.
- **Evidence:** Adjacent projects separately emphasize provenance, review,
  corrections, hard negatives, fallback observability, validation, and local
  privacy. The PDF editor already has source-bound operations, candidate evidence,
  templates, and validation contracts.
- **Implication:** A compounding advantage should be measured as improved safe
  completion, abstention, correction reuse, and recovery across providers, not as
  the number of OCR engines or a single detector score.
- **Falsifier:** Reviewed correction history fails to improve completion or
  creates unacceptable privacy, storage, or support cost.

### F-031: Cross-project code import is not yet justified

- **Status:** Unknown pending module-level provenance and compatibility review.
- **Evidence:** The neighboring projects have different owners, domains,
  runtimes, schemas, dependency sets, and maturity/evidence levels. Some contain
  bundled artifacts, historical documents, generated files, or local data.
- **Implication:** The next safe transfer is a documented adapter contract,
  fixture category, metric, or failure taxonomy. A code or dependency import
  requires its own license, security, privacy, test, packaging, and rollback gate.

## Current Competitor Exploration Addendum

### F-032: ihatepdf.cv demonstrates a broad local-first PDF utility surface

- **Status:** Observed by Tier 1 current-source web inspection.
- **Evidence:** The current home page advertises 46 tools spanning merge, split,
  compression, conversion, text editing, forms, OCR, encryption, password
  removal, redaction, flattening, metadata scanning, AI, repair, compare, scan,
  P2P sharing, collaboration, and business utilities.
- **Implication:** A local PDF engine can support a broad task-oriented utility
  surface, but the PDF editor should grow from validated contracts rather than
  copying the complete breadth immediately.
- **Source:** [ihatepdf.cv home](https://www.ihatepdf.cv/).

### F-033: ihatepdf.cv exposes useful browser architecture patterns

- **Status:** Observed by Tier 1 current-source static inspection; runtime
  performance remains unknown.
- **Evidence:** Its technical blog describes PDF.js 3.11.174, pdf-lib 1.17.1,
  WebAssembly, workers, IndexedDB for binary data, localStorage for metadata,
  volatile RAM, device-adaptive limits, batch processing, canvas memory release,
  and a PWA/service-worker shell. Public assets include a manifest and service
  worker with cache and share-target behavior.
- **Implication:** These are candidates for the PDF editor's web architecture,
  especially resource preflight, storage tiers, and installable entry points.
  Exact limits and performance must be established on our corpus and browsers.
- **Sources:** [technical blog](https://www.ihatepdf.cv/technical-blog),
  [manifest](https://www.ihatepdf.cv/manifest.json), and
  [service worker](https://www.ihatepdf.cv/sw.js).

### F-034: “No upload” is a capability-specific claim, not a universal network claim

- **Status:** Observed by Tier 1 static inspection; normal-operation packet
  behavior remains unknown.
- **Evidence:** The site claims local PDF processing, while its public bundle
  initializes Microsoft Clarity and references external CDNs. The technical blog
  describes sending extracted text to Gemini for AI chat, and the P2P page
  describes STUN/WebRTC network coordination. This does not prove ordinary PDF
  bytes are uploaded during local editing, but it does establish multiple
  separate network/data-flow surfaces.
- **Implication:** The PDF editor must describe privacy per capability: source
  bytes, extracted text, OCR output, telemetry, analytics, signaling metadata,
  payment metadata, and nothing-transmitted modes.
- **Sources:** [technical blog](https://www.ihatepdf.cv/technical-blog),
  [Chat with PDF](https://www.ihatepdf.cv/chat-with-pdf),
  [P2P Share](https://www.ihatepdf.cv/p2p-share), and the public bundle inspected
  on 2026-08-24.

### F-035: ihatepdf.cv's high-risk editing, OCR, repair, and security claims need independent gates

- **Status:** Observed claims; not independently verified in this project.
- **Evidence:** The site claims same-font text replacement, automatic OCR editing,
  95-99% OCR accuracy on clean typed scans, permanent redaction, AES-256
  encryption, a 15-plus-category privacy scanner, five-strategy repair, and
  broad conversion fidelity.
- **Implication:** These claims become corpus experiment ideas, not adopted
  capabilities. The PDF editor needs render, semantic, structural, security, and
  recovery oracles before making equivalent claims.
- **Sources:** [text editor](https://www.ihatepdf.cv/edit-pdf-text),
  [OCR PDF](https://www.ihatepdf.cv/ocr-pdf),
  [privacy scanner](https://www.ihatepdf.cv/privacy-scanner), and
  [repair PDF](https://www.ihatepdf.cv/repair-pdf).

### F-036: The listed ihatepdf.cv source link is not currently usable as provenance

- **Status:** Verified by current source access attempt; the linked GitHub page
  returned 404 during this pass.
- **Evidence:** The public home page exposes a GitHub link to
  `github.com/pranavcode2442/ihatepdf-tools`; opening that URL returned 404.
- **Implication:** Do not copy code, dependencies, licenses, or architecture
  assumptions from the link. Recheck source availability and ownership before
  treating it as open-source evidence.
- **Source:** [listed GitHub link](https://github.com/pranavcode2442/ihatepdf-tools).

### F-001: PDF.js is a browser-first rendering and inspection layer

- **Status:** Verified by Tier 1 source inspection.
- **Evidence:** `PDFPageProxy` exposes page viewport calculation, text-content
  extraction, annotation retrieval, and rendering. `AnnotationStorage` stores
  changed annotation data. The project source is Apache-2.0 licensed.
- **Implication:** PDF.js is a strong browser renderer and inspection provider,
  but the inspected API does not establish a general PDF writer or arbitrary
  existing-content editor.
- **Sources:**
  - <https://mozilla.github.io/pdf.js/api/draft/module-pdfjsLib-PDFPageProxy.html>
  - <https://mozilla.github.io/pdf.js/api/draft/module-pdfjsLib.html>
  - <https://raw.githubusercontent.com/mozilla/pdf.js/master/src/display/api.js>
  - <https://raw.githubusercontent.com/mozilla/pdf.js/master/src/display/annotation_storage.js>
  - <https://raw.githubusercontent.com/mozilla/pdf.js/master/LICENSE>

### F-002: PDFBox covers JVM rendering, extraction, and AcroForm mutation

- **Status:** Verified by Tier 1 source inspection.
- **Evidence:** The 3.0.8 API exposes `PDFRenderer`, `PDFTextStripper`,
  `PDAcroForm`, and `PDDocument` lifecycle/save APIs. The project README and
  license identify Apache-2.0 distribution.
- **Implication:** PDFBox is the strongest permissively licensed all-in-one
  candidate in the inspected JVM set. It still needs corpus testing before any
  unrelated-content preservation claim.
- **Sources:**
  - <https://javadoc.io/static/org.apache.pdfbox/pdfbox/3.0.8/org/apache/pdfbox/rendering/PDFRenderer.html>
  - <https://javadoc.io/static/org.apache.pdfbox/pdfbox/3.0.8/org/apache/pdfbox/text/PDFTextStripper.html>
  - <https://javadoc.io/static/org.apache.pdfbox/pdfbox/3.0.8/org/apache/pdfbox/pdmodel/interactive/form/PDAcroForm.html>
  - <https://javadoc.io/static/org.apache.pdfbox/pdfbox/3.0.8/org/apache/pdfbox/pdmodel/PDDocument.html>
  - <https://raw.githubusercontent.com/apache/pdfbox/trunk/README.md>
  - <https://raw.githubusercontent.com/apache/pdfbox/trunk/LICENSE.txt>

### F-003: qpdf is a structural transformation and validation primitive

- **Status:** Verified by Tier 1 source inspection.
- **Evidence:** qpdf documents itself as a C++ library for structural,
  content-preserving transformations, object/page manipulation, JSON inspection,
  encryption, linearization, and syntax management. It explicitly says it is not
  a viewer, content-creation library, or semantic PDF-content editor.
- **Implication:** qpdf is useful below an editor for inspection, normalization,
  and safe structural operations, but cannot supply rendering or blank-region
  semantics.
- **Sources:**
  - <https://qpdf.readthedocs.io/en/stable/overview.html>
  - <https://qpdf.readthedocs.io/en/stable/json.html>
  - <https://qpdf.readthedocs.io/en/stable/cli.html>
  - <https://raw.githubusercontent.com/qpdf/qpdf/main/README.md>

### F-004: pdf-lib is a permissive JavaScript writer and form layer

- **Status:** Verified by Tier 1 source inspection.
- **Evidence:** The project documents creating and modifying PDFs in browser,
  Node, Deno, and React Native environments. Its public API exposes page drawing,
  PDF forms, field types, flattening, and document save operations. The project is
  MIT licensed.
- **Implication:** pdf-lib is a practical overlay and native-form writer for a
  browser-first product. It is not a renderer and does not establish semantic
  editing of existing text or arbitrary page content.
- **Sources:**
  - <https://pdf-lib.js.org/>
  - <https://raw.githubusercontent.com/Hopding/pdf-lib/master/src/api/PDFDocument.ts>
  - <https://raw.githubusercontent.com/Hopding/pdf-lib/master/src/api/form/PDFForm.ts>
  - <https://raw.githubusercontent.com/Hopding/pdf-lib/master/LICENSE.md>

### F-005: MuPDF is a high-capability native option with a major license gate

- **Status:** Verified by Tier 1 source inspection; commercial terms not assessed.
- **Evidence:** The source tree exposes document and annotation APIs, including
  widget/form-related annotation types. The project README/COPYING identify the
  AGPL/commercial licensing model. `CHANGES` documents `fz_check_document` repair
  behavior and warns that edits may be lost when repair is required.
- **Implication:** MuPDF is technically attractive for a native high-fidelity
  product, but distribution must pass a separate legal/licensing decision. Repair
  behavior is a direct reason to require save/reopen and fidelity tests.
- **Sources:**
  - <https://raw.githubusercontent.com/ArtifexSoftware/mupdf/master/README>
  - <https://raw.githubusercontent.com/ArtifexSoftware/mupdf/master/COPYING>
  - <https://raw.githubusercontent.com/ArtifexSoftware/mupdf/master/include/mupdf/pdf/annot.h>
  - <https://raw.githubusercontent.com/ArtifexSoftware/mupdf/master/include/mupdf/pdf/document.h>
  - <https://raw.githubusercontent.com/ArtifexSoftware/mupdf/master/CHANGES>

### F-006: Poppler provides native rendering, forms, annotations, and signatures

- **Status:** Verified by Tier 1 source inspection; exact component-license matrix
  remains open.
- **Evidence:** The official GLib and Qt API documentation exposes page geometry,
  form fields, text/button/choice/signature field types, setters, and signature
  validation/signing APIs. The inspected Qt6 source header carries GPL v2-or-later
  terms.
- **Implication:** Poppler is a capable native reader/form provider, but its GPL
  boundary and lack of a demonstrated general-purpose semantic writer make it a
  poor default for a permissively distributed editor without further review.
- **Sources:**
  - <https://poppler.freedesktop.org/>
  - <https://poppler.freedesktop.org/api/glib/>
  - <https://poppler.freedesktop.org/api/glib/PopplerFormField.html>
  - <https://poppler.freedesktop.org/api/glib/poppler-Poppler-Page.html>
  - <https://poppler.freedesktop.org/api/qt6/classPoppler_1_1FormField.html>
  - <https://poppler.freedesktop.org/api/qt6/classPoppler_1_1Page.html>
  - <https://cgit.freedesktop.org/poppler/poppler/plain/qt6/src/poppler-form.h>

### F-007: PoDoFo is a native structure/writing candidate, not a complete reader

- **Status:** Partly verified by Tier 1 source inspection.
- **Evidence:** The project README and public headers describe in-memory PDF
  documents/pages, parsing and creation, annotations/forms, incremental updates,
  and document-level manipulation. The inspected source headers use LGPL-2.0-or-
  later OR MPL-2.0 SPDX expressions.
- **Implication:** PoDoFo can be a writer/structure adapter beside a renderer,
  but it should not be selected as the sole reader/editor engine without runtime
  and fidelity validation.
- **Sources:**
  - <https://raw.githubusercontent.com/podofo/podofo/master/README.md>
  - <https://raw.githubusercontent.com/podofo/podofo/master/src/podofo/main/PdfMemDocument.h>
  - <https://raw.githubusercontent.com/podofo/podofo/master/src/podofo/main/PdfPage.h>

### F-008: pikepdf exposes qpdf through Python

- **Status:** Verified by Tier 1 source inspection.
- **Evidence:** pikepdf describes itself as a Python library built on qpdf, with
  access to PDF objects, pages, saving, and AcroForm structures. Its project
  license is MPL-2.0.
- **Implication:** pikepdf is useful for local/server-side structural tooling and
  experiments, but it is not a browser renderer or a complete interactive editor.
- **Sources:**
  - <https://pikepdf.readthedocs.io/en/latest/api/main.html>
  - <https://raw.githubusercontent.com/pikepdf/pikepdf/main/README.md>
  - <https://raw.githubusercontent.com/pikepdf/pikepdf/main/LICENSE.txt>

### F-009: No inspected candidate provides general static blank-region detection

- **Status:** Inferred from the inspected public surfaces; requires corpus testing.
- **Evidence:** The APIs expose native annotations/forms, text, geometry, page
  objects, or drawing primitives, but no candidate documents a reliable general
  detector for blank boxes and entry regions in otherwise static PDFs.
- **Implication:** Static detection is a product-owned pipeline, not a library
  checkbox. It must retain evidence and uncertainty and require user confirmation
  before mutation.

### F-010: The first safety boundary should be bounded filling, not arbitrary reflow

- **Status:** Accepted safety boundary; long-term capability expansion remains in scope.
- **Rationale:** The sources support rendering, form mutation, drawing overlays,
  and structural transforms, but none establish safe arbitrary semantic editing
  with preservation of unrelated content. Bounded filling and annotation make the
  preservation invariant testable and reversible.

### F-011: The attached Form 6 is a static, text-extractable PDF rather than an AcroForm

- **Status:** Verified by Tier 1 fixture inspection.
- **Evidence:** `/Users/pranay/Desktop/RAr0Lq2Avu.pdf` is two pages at 612 x 841.68
  points, reports `Form: none`, `JavaScript: no`, `Encrypted: no`, and yields text
  and font data through Poppler tools. `pdfimages -list` reports one embedded JPEG;
  the visible grids, rules, boxes, and tables are primarily document geometry.
- **Implication:** The fixture directly tests static-region detection, semantic
  grouping, label association, and safe overlay placement. Native field inspection
  must correctly return zero fields without treating that as a detection failure.
- **Source:** [`docs/form6-benchmark.md`](docs/form6-benchmark.md), fixture SHA-256
  `2cf1421343c22676f15eff0ec6f31a4df6e7f7975dc0f3d88d2b29a1dcc79d34`.

### F-012: PDFKit is a credible native macOS shell provider but is not open-source

- **Status:** Verified by Tier 1 official documentation inspection.
- **Evidence:** Apple documents PDFKit as a framework to display and manipulate
  PDFs. `PDFDocument` provides reading, writing, searching, and selection; the
  framework documents widgets for text, button, and choice fields, and
  `PDFAnnotation` exposes widget field types and values.
- **Implication:** PDFKit should be evaluated for the primary native shell, but it
  must remain behind a provider adapter and cannot be treated as proof of static
  detection or unrelated-content preservation. It is a platform framework, not an
  open-source engine.
- **Sources:**
  - <https://developer.apple.com/documentation/pdfkit.md>
  - <https://developer.apple.com/documentation/pdfkit/pdfdocument.md>
  - <https://developer.apple.com/documentation/pdfkit/pdfannotation.md>

### F-013: The autoresearch pattern is useful only with safety gates ahead of score

- **Status:** Proposed, grounded in inspected local and upstream implementations.
- **Evidence:** Upstream autoresearch fixes preparation/evaluation conditions and
  uses a bounded run, one mutable training surface, a metric, and keep/discard
  history. The local MLX port uses `prepare.py`, `program.md`, a mutable training
  path, and `results.tsv`; the invoice-intelligence loop adds reviewed ground truth,
  validation, latency, cost, failure, and objective metrics.
- **Implication:** PDF experiments need immutable source/manifests/evaluators and
  lexicographic hard gates for source preservation, reopenability, unsafe
  autofill, and resource safety before optimizing detection or latency.
- **Sources:**
  - <https://github.com/karpathy/autoresearch>
  - `/Users/pranay/Projects/autoresearch/autoresearch-mlx/README.md`
  - `/Users/pranay/Projects/invoice-intelligence/experiments/autoresearch_loop.py`
  - [`docs/autoresearch-adaptation.md`](docs/autoresearch-adaptation.md)

### F-014: OCR candidates are evidence adapters, not field detectors

- **Status:** Verified by Tier 1 official-source inspection; runtime quality and
  packaging remain unknown.
- **Evidence:** Apple Vision documents `VNRecognizeTextRequest` for locating and
  recognizing text in images, with language, accuracy/speed, and result controls,
  and lists macOS availability. Tesseract documents a 5.x OCR engine, a
  programmer API, broad language support, and Apache 2.0 licensing. PaddleOCR's
  official README documents OCR plus PP-Structure pipelines with coordinate-rich
  text/table output and an Apache 2.0 project license. Docling's official README
  documents PDF layout understanding, OCR, local or air-gapped execution, and an
  MIT codebase license while warning that individual model licenses are separate.
- **Implication:** OCR should run only for scanned or text-poor pages, and its
  output should be retained as uncertain evidence for label association and
  geometry inference. It must not directly create or verify a fill region. Form 6
  is already text-extractable, so OCR is not required for its first benchmark lane.
  Apple Vision is the simplest native macOS candidate; Tesseract is the simplest
  permissive baseline; PaddleOCR or Docling should be considered only when the
  corpus requires layout-aware scanned-document handling.
- **Sources:**
  - <https://developer.apple.com/documentation/vision/vnrecognizetextrequest.md>
  - <https://tesseract-ocr.github.io/tessdoc/>
  - <https://raw.githubusercontent.com/tesseract-ocr/tesseract/main/LICENSE>
  - <https://raw.githubusercontent.com/PaddlePaddle/PaddleOCR/main/README.md>
  - <https://raw.githubusercontent.com/PaddlePaddle/PaddleOCR/main/LICENSE>
  - <https://raw.githubusercontent.com/DS4SD/docling/main/README.md>
  - <https://raw.githubusercontent.com/DS4SD/docling/main/LICENSE>

### F-015: PDFKit passes the first bounded Form 6 lane with residual fidelity risk

- **Status:** Verified by Tier 2 runtime check; S1 pass. The check is not S2 or S3.
- **Evidence:** On 2026-08-23, `benchmark/test_pdfkit_benchmark.sh` compiled and ran
  with Xcode 26.3, Swift 6.2.4, macOS SDK 26.2, and target
  `arm64-apple-macosx15.0`. The result is preserved in
  [`benchmark/results/2026-08-23-pdfkit-form6/result.json`](benchmark/results/2026-08-23-pdfkit-form6/result.json).
  PDFKit reported two pages, zero native widgets, non-empty text, successful no-op
  reopen, exact provider-local original/no-op PNG equality, one reopened FreeText
  annotation, unchanged provider text, and unchanged source digest.
- **Independent check:** Poppler matched original/no-op extracted text and found the
  expected annotation contents in overlay extraction. At 144 DPI, Poppler raster
  comparison reported page 1 absolute error `0` and page 2 absolute error `85`
  (`4.12378e-05` normalized metric).
- **Implication:** PDFKit is viable for the next benchmark lane, but the result is
  not a final-provider decision or a universal preservation guarantee. Renderer
  variance, native widget fixtures, malformed inputs, signatures, and independent
  viewer behavior remain unverified.
- **Sources:**
  - [`docs/pdfkit-benchmark.md`](docs/pdfkit-benchmark.md)
  - [`benchmark/PDFKitBenchmark.swift`](benchmark/PDFKitBenchmark.swift)
  - [`benchmark/results/2026-08-23-pdfkit-form6/result.json`](benchmark/results/2026-08-23-pdfkit-form6/result.json)
  - <https://developer.apple.com/documentation/pdfkit/pdfdocument>
  - <https://developer.apple.com/documentation/pdfkit/pdfpage>

### F-016: PDFKit loses external AcroForm radio choices on no-op save

- **Status:** Verified by Tier 2 runtime check; S1 failure of the defined widget-state
  preservation gate.
- **Input:** Public sample form from
  <https://pdftoolskit.org/samples/sample-form.pdf>; local artifact
  [`benchmark/results/public-sample-form.pdf`](benchmark/results/public-sample-form.pdf);
  SHA-256 `5a681d44622f2ee577808e77f034525314d48a628b9cad26f7788564c9e922e8`.
- **Evidence:** The source is one-page A4 and Poppler identifies `Form: AcroForm`.
  PDFKit found six widgets with `/Btn`, `/Ch`, and `/Tx` types. After a no-op save,
  page/widget count, text extraction, and source digest remained intact, but both
  `applicant.contact` radio widgets lost their original `choices` array
  `[`email`, `phone`]`. The PDFKit raster comparison differed by AE `166`
  (`8.27664e-05` normalized). PDFKit logged
  `PDFFormField with no corresponding Widget sharing the field name.`
- **Mutation check:** A text widget mutation to `PDFKit benchmark` survived reopen,
  so the failure is specific to complete widget-state preservation rather than all
  PDFKit field writes.
- **Implication:** The external AcroForm lane is a real provider failure for the
  current preservation contract. Do not weaken the gate or claim PDFKit support for
  imported radio/choice forms based on the synthetic pass.
- **Sources:**
  - [`docs/pdfkit-widget-benchmark.md`](docs/pdfkit-widget-benchmark.md)
  - [`benchmark/PDFKitAcroFormBenchmark.swift`](benchmark/PDFKitAcroFormBenchmark.swift)
  - [`benchmark/results/2026-08-23-public-acroform/result.json`](benchmark/results/2026-08-23-public-acroform/result.json)
- <https://pdftoolskit.org/sample-pdfs>

### F-017: PDFBox has a current permissive all-in-one JVM release line

- **Status:** Verified by Tier 1 official-source inspection; runtime fidelity remains
  unknown.
- **Evidence:** The official PDFBox site describes an open-source Java library for
  creating, manipulating, and extracting PDF content, with command-line utilities,
  form filling, image rendering, preflight, and digital-signing features. The
  download page exposes PDFBox `3.0.8` and the maintained `2.0.37` line; the site
  identifies Apache License 2.0 distribution and dates the releases to July 2026.
- **Implication:** PDFBox remains the strongest permissive control lane for a
  process-backed or JVM-native core. Release activity is maintenance evidence, not
  proof of save fidelity, imported-widget preservation, or safe arbitrary editing.
- **Sources:**
  - <https://pdfbox.apache.org/>
  - <https://pdfbox.apache.org/download.html>
  - <https://javadoc.io/doc/org.apache.pdfbox/pdfbox/latest/index.html>

### F-018: PDFium is an embeddable Chromium component, not a turnkey editor

- **Status:** Verified by Tier 1 source and public-header inspection; exact packaged
  dependency inventory remains unknown.
- **Evidence:** The official README requires Chromium build tooling and documents
  x64 Windows/Linux/macOS, x86 Windows, and arm Android targets. It says embedders
  should use the `public/` headers, which PDFium tries to keep stable, while code
  outside that directory may change at any time. The public surface includes
  rendering, form-fill, annotation, page-object editing, and signature headers; the
  inspected public headers identify BSD-style licensing.
- **Implication:** PDFium is a strong low-level rendering/form primitive for a team
  willing to own Chromium-scale build and embedding work. It does not by itself
  establish a document UI, product workflow, static-region detector, or simple
  cross-platform distribution path.
- **Sources:**
  - <https://pdfium.googlesource.com/pdfium/+/refs/heads/main/README.md>
  - <https://pdfium.googlesource.com/pdfium/+/refs/heads/main/public/fpdfview.h>
  - <https://pdfium.googlesource.com/pdfium/+/refs/heads/main/public/fpdf_formfill.h>
  - <https://pdfium.googlesource.com/pdfium/+/refs/heads/main/public/fpdf_annot.h>
  - <https://pdfium.googlesource.com/pdfium/+/refs/heads/main/public/fpdf_edit.h>
  - <https://pdfium.googlesource.com/pdfium/+/refs/heads/main/public/fpdf_signature.h>

### F-019: MuPDF continues to expand its native and WebAssembly surface

- **Status:** Verified by Tier 1 official-source inspection; commercial terms and
  runtime behavior remain open.
- **Evidence:** The official release history records MuPDF `1.28.0` on 2026-06-26,
  including separate field/widget APIs for signature validation, robustness fixes,
  document-area detection, OCR-related tooling, and improved annotation undo/redo.
  The official JavaScript binding describes browser, Node, Bun, and Deno execution
  through WebAssembly with rendering, annotation, redaction, merge/split, and save
  operations. The official releases page states that embedding requires AGPL
  compliance or a commercial license.
- **Implication:** MuPDF is a technically credible native or WebAssembly control
  candidate, but it remains gated by distribution licensing and corpus validation.
  Its breadth does not remove the need for immutable-source and save/reopen gates.
- **Sources:**
  - <https://mupdf.com/releases/history>
  - <https://mupdf.com/releases>
  - <https://github.com/ArtifexSoftware/mupdf.js>
  - <https://mupdf.readthedocs.io/en/latest/license.html>

### F-020: Poppler has an active release line and explicit signature/form APIs

- **Status:** Verified by Tier 1 official-source inspection; exact component-license
  matrix and general writer scope remain open.
- **Evidence:** The official site lists Poppler `26.08.0`, released 2026-08-02, and
  exposes cpp, GLib, Qt5, and Qt6 frontends. The release history records signature
  checking improvements, malformed-document crash fixes, form improvements, and
  annotation changes. The GLib API exposes signature-field enumeration and
  synchronous/asynchronous cryptographic signature validation. The inspected Qt6
  header carries GPL v2-or-later terms.
- **Implication:** Poppler is a maintained native reader/form/signature candidate,
  but it is not a permissive default and the inspected evidence still does not
  establish a general-purpose semantic writer.
- **Sources:**
  - <https://poppler.freedesktop.org/>
  - <https://poppler.freedesktop.org/releases.html>
  - <https://poppler.freedesktop.org/api/glib/PopplerFormField.html>
  - <https://poppler.freedesktop.org/api/glib/PopplerDocument.html>
  - <https://cgit.freedesktop.org/poppler/poppler/plain/qt6/src/poppler-form.h>

### F-021: PoDoFo is a current native writer/structure primitive without rendering

- **Status:** Verified by Tier 1 official-source inspection; release/version alignment
  remains open.
- **Evidence:** The official README describes a portable C++17 parser/writer with
  high-level annotation and form inspection, incremental updates, and PAdES-B
  signing. The generated `1.2.0` documentation explicitly says PoDoFo does not
  provide rendering and documents `PdfMemDocument` loading, password handling,
  broken-XRef inspection, encryption, and AcroForm access. Existing source
  inspection exposed a `1.1.2` candidate version, so the documentation/release
  version boundary must be resolved before adoption.
- **Implication:** PoDoFo is useful beside a renderer or as a bounded writer
  experiment, not as the sole reader/editor engine. Its version discrepancy and
  lack of rendering increase adapter and validation burden.
- **Sources:**
  - <https://github.com/podofo/podofo>
  - <https://podofo.github.io/podofo/documentation/>
  - <https://podofo.github.io/podofo/documentation/classPoDoFo_1_1PdfMemDocument.html>

### F-022: Commercial SDKs provide useful control cases but are not open-source defaults

- **Status:** Verified by Tier 1 vendor documentation and pricing-page inspection;
  independent runtime and contractual review remain unknown.
- **Evidence:** Nutrient documents a PDFium-based Web SDK with client-side browser
  processing, no server dependency or Microsoft Office license requirement, and
  demos for annotations, form filling, and form creation. Apryse documents UI-free
  WebViewer processing, editing, forms, digital signatures, redaction, and a
  universal macOS library covering arm64 and x86_64. Both vendors expose modular or
  sales-led pricing rather than public fixed SDK prices in the inspected pages.
- **Implication:** These SDKs are valuable feature/fidelity control cases if the
  product can accept proprietary procurement, but they do not answer the requested
  open-source composition. Their feature pages are capability evidence, not proof
  of preservation on this project's corpus.
- **Sources:**
  - <https://www.nutrient.io/api/web>
  - <https://apryse.com/pricing>
- <https://docs.apryse.com/web/guides/get-started/without-viewer>
- <https://docs.apryse.com/core/guides/get-started/mac>

### F-023: Browser storage and file access are permissioned, quota-bound capabilities

- **Status:** Verified by Tier 1 current web-platform documentation; project
  storage behavior remains a product implementation gate.
- **Evidence:** The File System Access API requires user-selected permissions
  for ordinary file access where supported. OPFS is private to a page origin,
  available in workers, and subject to browser storage quotas. IndexedDB stores
  structured data and blobs, but quota and eviction behavior vary by browser and
  mode.
- **Implication:** A browser-only app can be local-first without treating local
  browser state as a backup. It needs explicit ephemeral, local-draft, and
  file-backed modes plus a picker/download fallback.
- **Sources:**
  - <https://developer.mozilla.org/en-US/docs/Web/API/File_System_API>
  - <https://developer.mozilla.org/en-US/docs/Web/API/File_System_API/Origin_private_file_system.>
  - <https://developer.mozilla.org/en-US/docs/Web/API/IndexedDB_API>

### F-024: Tesseract.js is a browser OCR worker, not a direct PDF OCR pipeline

- **Status:** Verified by Tier 1 project documentation; accuracy and performance
  on this corpus remain unknown.
- **Evidence:** Tesseract.js wraps Tesseract through WebAssembly and a worker,
  but its FAQ says PDF input is not supported directly. A browser implementation
  must render PDF pages to images before recognition and package or load worker,
  WASM, and language assets. The project also documents that the standard model
  does not support handwritten text.
- **Implication:** Browser OCR is an experiment with a separate memory, asset,
  language, and accuracy gate. OCR output remains evidence and cannot silently
  become a field or edit operation.
- **Sources:**
  - <https://github.com/naptha/tesseract.js/blob/master/docs/faq.md>
  - <https://github.com/naptha/tesseract.js/blob/master/docs/local-installation.md>
  - <https://github.com/tesseract-ocr/tesseract>

### F-025: PDFBox is a permissive companion control lane, not fidelity proof

- **Status:** Verified by Tier 1 current official-source inspection; runtime
  preservation on this corpus remains unknown.
- **Evidence:** Apache PDFBox documents Apache-2.0 distribution, existing-PDF
  manipulation, Unicode text extraction, form filling, image rendering,
  preflight, page operations, and digital signing.
- **Implication:** PDFBox is a strong local JVM companion candidate for a
  controlled comparison lane. Java packaging, process lifecycle, dependency
  inventory, malformed-input limits, and corpus save/reopen tests remain
  required before product adoption.
- **Sources:**
  - <https://pdfbox.apache.org/>
  - <https://pdfbox.apache.org/download.html>

### F-026: MuPDF.js offers a broad WebAssembly surface with an AGPL/commercial gate

- **Status:** Verified by Tier 1 current official-source inspection; commercial
  terms and project-corpus fidelity remain unknown.
- **Evidence:** The official MuPDF.js project documents browser WebAssembly
  execution with rendering, structured text, annotations, widgets, redaction,
  page operations, and saving. The MuPDF project and release site state an AGPL
  or commercial licensing boundary for embedding.
- **Implication:** MuPDF.js is a technically credible high-fidelity experiment,
  but not a permissive default. Any distribution requires an explicit license
  decision and exact packaged-dependency review.
- **Sources:**
  - <https://github.com/ArtifexSoftware/mupdf.js/>
  - <https://mupdf.com/releases>
  - <https://github.com/ArtifexSoftware/mupdf>

### F-027: OCRmyPDF is a process-oriented OCR pipeline with dependency and security boundaries

- **Status:** Verified by Tier 1 current official-source inspection; packaging
  and product threat review remain unknown.
- **Evidence:** OCRmyPDF documents searchable OCR output and PDF/A-oriented
  processing. Its current introduction identifies Ghostscript as a required
  dependency and warns that OCRmyPDF is not designed to be secure against
  malware-bearing PDFs. The project’s core license and dependency licenses must
  be reviewed separately.
- **Implication:** OCRmyPDF belongs behind an isolated local worker or companion
  boundary, with resource limits, temporary-file hygiene, dependency inventory,
  and an explicit license decision. It should not be treated as a browser
  dependency or as field semantics.
- **Sources:**
  - <https://ocrmypdf.readthedocs.io/en/stable/introduction.html>
  - <https://ocrmypdf.readthedocs.io/en/latest/>
  - <https://ocrmypdf.readthedocs.io/en/v12.7.1/contributing.html>

### F-028: An installed companion creates a browser-to-native trust and lifecycle boundary

- **Status:** Verified for the native-messaging deployment shape by Tier 1
  browser documentation; localhost-RPC details remain proposed architecture.
- **Evidence:** Browser native-messaging documentation describes an installed
  native application, an extension permission, host-manifest allowlisting, and
  a JSON stdin/stdout message boundary. The browser does not install or manage
  the native application.
- **Implication:** A companion requires installer, signing, update, uninstall,
  version negotiation, origin/extension allowlisting, authenticated requests,
  limits, cancellation, and recovery documentation. It cannot be introduced as
  an invisible helper binary.
- **Sources:**
  - <https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Native_messaging>

## 2026-08-24 Native/Web Fidelity Expansion Addendum

### F-037: Outside-region validation is now a bounded proof in both adapters

- **Status:** Verified by Tier 2 native tests and Tier 3 isolated browser runs.
- **Evidence:** Native `PDFImpactValidator` and browser
  `web/pdf-impact-validator.mjs` compare extracted text and rendered pixels
  outside operation-owned page-space regions. The browser corpus emitted passed
  `outsideRegionText` and `visualDiff` checks for native-field and overlay
  exports. Native overlay export reports the same check kinds.
- **Implication:** The product can make a narrower preservation statement for
  tested operations and regions. It still cannot claim arbitrary semantic edit
  safety, byte identity, independent-viewer parity, or general raster parity.
- **Sources:** `Sources/PDFEditorCore/PDFImpactValidator.swift`,
  `web/pdf-impact-validator.mjs`, `Tests/web_pdf_proof_playwright_test.mjs`,
  and `Tests/PDFEditorCoreTests/PDFEditorCoreTests.swift`.

### F-038: Browser geometry evidence is available, but current precision is not cleared

- **Status:** Verified by Tier 3 isolated browser corpus emission; precision and
  recall remain unknown.
- **Evidence:** `web/pdf-geometry-detector.mjs` consumes PDF.js operator-list
  geometry and text items, then emits vector rectangle, checkbox-shape,
  repeated-cell, underline, whitespace, and label-association evidence. The
  existing static corpus now produces geometry-backed candidates, including the
  known provider failures and malformed/resource cases.
- **Implication:** Web geometry detection can progress in parallel with native
  `PDFVectorStreamParser` and `StaticRegionDetector`, but it must be calibrated
  against decorative borders, long rules, tables, and unlabeled shapes before
  candidate recall or precision claims.
- **Sources:** `web/pdf-geometry-detector.mjs`,
  `Sources/PDFEditorCore/PDFVectorStreamParser.swift`,
  `Sources/PDFEditorCore/StaticRegionDetector.swift`, and the browser contract
  fixture output.

### F-039: Missing operation coordinates must remain unknown, not passed

- **Status:** Verified by native unit test and shared validation behavior.
- **Evidence:** An operation without a page-space coordinate makes native and
  browser outside-region impact checks return `unknown`. Native validation
  promotes an otherwise clean report to `validatedWithWarnings`; browser
  validation promotes unknown impact checks to the warning-level status.
- **Implication:** Compatibility operations can still be decoded and diagnosed,
  but they cannot support the “surrounding content was preserved” statement.
  New UI paths should always bind coordinates and source digests before creating
  operations.
- **Sources:** `Sources/PDFEditorCore/PDFImpactValidator.swift`,
  `web/pdf-impact-validator.mjs`, and the native impact validator test.

### F-040: The remaining excluded claims need separate capability lanes

- **Status:** Mapped as a living implementation program; not complete.
- **Evidence:** `docs/full-capability-build-program.md` now assigns every major
  reader, form, geometry, OCR, editing, page-operation, security, signature,
  accessibility, template, companion, and collaboration lane to shared
  contracts, native/web adapters, evidence gates, and explicit status.
- **Implication:** “Build everything” is now actionable without collapsing
  exploration into unsupported claims. OCR web, text-run replacement, redaction,
  sanitization, cryptographic signatures, XFA, PDF/UA, independent-viewer
  parity, and broad conversion remain named work rather than hidden gaps.
- **Source:** [`docs/full-capability-build-program.md`](docs/full-capability-build-program.md).

### F-041: Browser geometry candidates now expose four requested evidence families

- **Status:** Verified by the Tier 3 browser corpus fixture; detector precision,
  recall, and native/browser semantic parity remain open.
- **Evidence:** `web/pdf-geometry-detector.mjs` emits `vectorRectangle` evidence
  for bounded rectangles, a checkbox-specific vector-rectangle summary paired
  with `suggestedFieldType: "checkbox"`, `whitespace` evidence for inferred
  entry regions, and paired `textLabel` plus `spatialRelationship` evidence
  when a label is associated by page-space proximity. The strengthened browser
  fixture test observes all four categories across the existing manifest.
- **Implication:** The web detector can now explain why a candidate exists and
  how a label was associated without silently creating an AcroForm field. This
  is sufficient for reviewed completion experiments, not for automatic filling
  or a production precision/recall claim.
- **Sources:** `web/pdf-geometry-detector.mjs`,
  `Tests/web_pdf_contract_fixture_test.mjs`, and `docs/fixtures/manifest.md`.

### F-042: Browser exports now have a fail-closed outside-region text and raster gate

- **Status:** Verified by a dedicated Tier 3 isolated Chrome test.
- **Evidence:** `web/pdf-impact-validator.mjs` is separate from the pdf-lib
  writer. It compares source and reopened output through PDF.js, checks text
  outside operation-owned page-space regions, renders both documents at a fixed
  scale, and compares pixels outside those regions. The dedicated test proves
  no-op pass, unauthorized mutation failure, authorized-region pass, and
  `unknown` for missing or mismatched operation coordinates.
- **Implication:** Browser export validation can now make a bounded preservation
  statement for the authorized operation regions and refuse a clean result when
  those regions cannot be reconstructed. It still does not establish
  independent-viewer parity, byte identity, object-level preservation, or
  general semantic editing safety.
- **Sources:** `web/pdf-impact-validator.mjs`,
  `Tests/web_pdf_impact_validator_test.mjs`,
  `web/index.html`, and `docs/audits/browser-pdf-proof-evidence-2026-08-24.md`.

### F-043: Reusable completion templates need separate fingerprint, mapping, and profile lifecycles

- **Status:** T1 contract/runtime verified on native and browser lanes; browser
  capture/review is verified, while encrypted-store integration and native UI
  remain open.
- **Evidence:** `TemplateContracts.swift` and
  `pdf-template-contract.mjs` implement keyed layout fingerprints, normalized
  page and candidate signatures, confirmed mapping records, separate versioned
  profile records, and proposal-only matching. Native and web tests reject raw
  label leakage into templates, distinguish exact layouts from known variants
  and no-match cases, preserve profile revisions, and reject revoked or
  mismatched contracts.
- **Implication:** Recurring completion can learn reviewed structure without
  turning a template into a copy of the source PDF or a profile database. The
  matcher can preselect approved mapping IDs for review, but it cannot authorize
  a value or create a source-bound edit operation.
- **Sources:** `Sources/PDFEditorCore/TemplateContracts.swift`,
  `web/pdf-template-contract.mjs`,
  `Tests/PDFEditorCoreTests/PDFEditorCoreTests.swift`,
  `Tests/web_template_contract_test.mjs`,
  `Tests/web_template_browser_test.mjs`, and
  `docs/template-system-design.md`.

### F-044: Completion materialization and template learning need independent gates

- **Status:** Native and browser runtime contracts verified; browser review UI
  is verified, while native UI and provider adapter wiring remain open.
- **Evidence:** `TemplateRuntimeContracts.swift` and the browser completion
  adapter require mapping approval, value approval, current native target
  resolution, matching page coordinates, and an exact source digest before
  producing operations. Revision promotion requires strict validated reopen,
  unchanged source, matching source digest, and no failed or unknown checks.
- **Implication:** A profile selection or layout match cannot silently become a
  write or change future template behavior. The session remains authoritative,
  and learning remains pending until validated promotion.
- **Sources:** `Sources/PDFEditorCore/TemplateRuntimeContracts.swift`,
  `web/pdf-template-contract.mjs`, `Tests/PDFEditorCoreTests/PDFEditorCoreTests.swift`,
  `Tests/web_template_contract_test.mjs`, and
  `Tests/web_template_browser_test.mjs`.

### F-045: Local template persistence must be encrypted or explicitly ephemeral

- **Status:** Native AES-GCM record codec and browser encrypted IndexedDB
  primitive verified; Keychain custody and recovery UX remain open.
- **Evidence:** `TemplateStoreCodec.swift` seals authenticated records without
  exposing profile values, while `pdf-template-store.mjs` derives AES-GCM keys
  from a local passphrase, rejects source bytes, and exposes a separate
  in-memory mode. Browser round-trip and deletion tests passed.
- **Implication:** The product has a safe storage boundary to build UI around,
  but it must not label browser storage as backup or imply recoverability before
  passphrase recovery, import/export, eviction, and deletion behavior are
  specified.
- **Sources:** `Sources/PDFEditorCore/TemplateStoreCodec.swift`,
  `web/pdf-template-store.mjs`, `Tests/web_template_store_test.mjs`,
  `Tests/web_template_browser_test.mjs`, and
  `docs/template-system-design.md`.

### F-046: Browser capture and completion review can share the runtime contract

- **Status:** Browser UI proof verified; native review UI and encrypted-store
  integration remain open.
- **Evidence:** `web/index.html` now captures a draft template from inspected
  native fields and directly editable static candidates, exposes explicit
  mapping checkboxes, activates only a reviewed draft, prepares a session
  proposal with session-only values, and keeps Apply disabled until each entry
  has mapping and value approval. `Tests/web_template_browser_test.mjs`
  verifies the capture, activation, preparation, and blocked-apply sequence.
- **Implication:** The web surface can exercise the same proposal and operation
  contracts as native without making the browser UI a second document model.
  Persistence, native UI, provider capability errors, and full-field value
  typing still need their own evidence.
- **Sources:** `web/index.html`, `web/pdf-template-contract.mjs`,
  `Tests/web_template_browser_test.mjs`, and
  `docs/template-system-design.md`.

### F-047: Reviewed template capture must append immutable child revisions

- **Status:** Native and browser capture/revision behavior verified; native
  review UI and production persistence wiring remain open.
- **Evidence:** `TemplateCaptureContracts.swift` requires a source digest,
  creates value-free proposed mappings, requires a decision for every mapping,
  and returns a new active revision with a new ID and parent link. The browser
  adapter mirrors those invariants through `captureTemplateDraft`,
  `activateTemplateRevision`, and `appendTemplateRevision`. The browser UI
  now retains the draft and appends the active child. Native Swift tests and
  Node/browser tests passed the round-trip and duplicate/missing-review gates.
- **Implication:** A reviewed completion cannot silently rewrite the draft that
  produced it. Local history can show the proposal, the decisions, the active
  child, and later explicit revisions independently, which gives rollback and
  audit semantics before encrypted persistence is integrated.
- **Sources:** `Sources/PDFEditorCore/TemplateCaptureContracts.swift`,
  `web/pdf-template-contract.mjs`, `web/index.html`,
  `Tests/PDFEditorCoreTests/PDFEditorCoreTests.swift`,
  `Tests/web_template_contract_test.mjs`,
  `Tests/web_template_browser_test.mjs`, and
  `docs/template-system-design.md`.

### F-048: Browser persistence needs separate store and profile authorization

- **Status:** Browser lifecycle behavior verified in isolated Chrome; production
  backup UX, passphrase recovery, and native Keychain parity remain open.
- **Evidence:** `web/pdf-template-store.mjs` now authenticates an encrypted
  metadata record before store access, encrypts profile payloads with a second
  profile-specific AES-GCM envelope, requires explicit profile unlock, clears
  in-memory profile keys on lock, and refuses profile reads while locked.
  `Tests/web_template_security_browser_test.mjs` deliberately fails wrong store
  and profile secrets before passing the correct unlock path.
- **Implication:** A browser session that can inspect layouts does not
  automatically gain access to recurring personal values. The store and profile
  boundaries can be presented as separate user-visible trust decisions.
- **Sources:** `web/pdf-template-store.mjs`,
  `Tests/web_template_security_browser_test.mjs`,
  `docs/shared-contracts.md`, and `docs/decisions.md` D-013.

### F-049: Eviction recovery must restore ciphertext, not reconstruct plaintext

- **Status:** Browser eviction, backup restore, deletion, and zero-content
  logging verified at Tier 3/S1 with deliberate wrong-secret and invalid-backup
  failures.
- **Evidence:** The browser test closes and deletes the IndexedDB database,
  observes `evicted`, refuses normal unlock, rejects an invalid backup, restores
  the encrypted metadata and record envelopes, requires profile unlock again,
  and recovers the template and profile. It then deletes both records and the
  whole store. Backup and diagnostic JSON are checked for profile values,
  passphrases, PDF markers, IDs, and arbitrary content.
- **Implication:** Browser storage loss is visible and recoverable only when the
  user retains an encrypted backup and the required secrets. The product must
  not silently create an empty replacement or describe browser storage as a
  backup.
- **Sources:** `web/pdf-template-store.mjs`,
  `Tests/web_template_security_browser_test.mjs`,
  `docs/template-system-design.md`, and `docs/decisions.md` D-013.

### F-050: Template family matching needs recurring-version evidence before threshold promotion

- **Status:** Reviewer-labeled class benchmark verified at Tier 2/S1 with
  deliberate policy mutation; live PDF.js fingerprint smoke remains Tier 3/S1.
  Production family matching remains disabled.
- **Evidence:** `web/template-match-benchmark.mjs` scores geometry, native field
  sequence, keyed anchors, and region signatures after exact and known-variant
  precedence. `Tests/web_template_match_benchmark_test.mjs` passes 24 cases:
  two exact, two known variant, six family positives, six ambiguous cases, one
  stale refusal, and seven no-match false-positive gates. Five structured classes
  calibrate to thresholds from `0.7772` through `0.8624`. The scanned class has
  exact and known-variant evidence but family acceptance is disabled because no
  family-positive case exists. Lowering all class thresholds to zero and removing
  the ambiguity margin fails on hard negatives and ambiguous selections.
- **Implication:** A high structural score is only a review-ranking signal. The
  matcher must abstain on equal evidence, stale sources, and hard negatives;
  values and operations remain separately review-gated. The current labels are
  single-curator evidence with independent agreement not measured. Thresholds
  must not be promoted from controlled perturbations to batch acceptance without
  real recurring versions, held-out evaluation, reviewer agreement, and native/
  browser fingerprint parity.
- **Sources:** `web/template-match-benchmark.mjs`,
  `Tests/fixtures/template_matching_reviewed_fixtures.mjs`,
  `Tests/web_template_match_benchmark_test.mjs`,
  `Tests/web_template_match_benchmark_browser_test.mjs`, and
  `docs/audits/recurring-template-class-calibration-evidence-2026-08-24.md`.

### F-051: Native and browser contract shape exists, but semantic parity is not cleared

- **Status:** First serialized corpus baseline verified at Tier 2/S1 native plus
  Tier 3/S1 browser. Eight manifest fixtures emitted; 61 normalized mismatches
  remain open.
- **Evidence:** `PDFContractHarness` serializes native PDFKit inspection,
  coordinates, candidates, empty edit-session lineage, and no-op validation.
  `Tests/pdf_contract_parity_test.mjs` serializes the same browser bundle from
  PDF.js/pdf-lib, compares source identity, page facts, fields, candidates,
  coordinates, operations, validation, accessibility, and security, and writes
  `benchmark/results/contract-parity-2026-08-24/parity-report.json`.
- **First mismatches:** PDF.js rounds three page-box groups; text character
  counts differ on four page groups; public AcroForm button/radio value and
  choice metadata differs; browser geometry detection emits candidates where
  native emits none on six fixtures; Form 6 has 29 native versus 97 browser
  candidates; validation check applicability differs; encrypted browser export
  fails while native no-op export validates; and accessibility/security
  summaries retain provider-scoped states.
- **Implication:** Native/web parity is a measured semantic contract, not a
  byte-level or provider-API identity claim. The first remediation priorities
  are field semantics, page-coordinate precision, encrypted writer capability,
  validation applicability, and detector quality. No mismatch should be hidden
  by broad normalization before its product meaning is reviewed.
- **Sources:** `Sources/PDFContractHarness/main.swift`,
  `Tests/pdf_contract_parity_test.mjs`,
  `docs/audits/native-web-contract-parity-evidence-2026-08-24.md`, and
  `benchmark/results/contract-parity-2026-08-24/parity-report.json`.

### F-070: PDFBox corpus expansion shows pixel-perfect no-op parity; detector certainty recalibrated under a 0.80 ceiling

- **Date:** 2026-08-25
- **Status:** Runtime-verified (Tier 2/S1) for the corpus lane; signed/XFA and
  password-protected corpus remain open.
- **PDFBox corpus evidence:** the generalized lane
  (`benchmark/pdfbox-lane/run-corpus.sh`) ran five fixtures with per-fixture
  JSON under `benchmark/results/2026-08-25-pdfbox-corpus/`. Raster parity at
  72 dpi: public AcroForm sample AE 0 / mean delta 0.000000; both rotation
  fixtures AE 0 (PDFRenderer auto-honors `/Rotate 90`, rendering 792×612 and
  841×612). The encrypted fixture fails cleanly as
  `encryptedUnsupported`/`InvalidPasswordException` with exit 0 and unchanged
  input digest — an explicit documented failure state, not a crash. The
  field-less native-widget fixture is a valid negative control. Both rotation
  fixtures contain zero AcroForm dictionaries (byte scan + `qpdf --json` +
  probe concur): they derive from the field-less `fixture.pdf`, so field gates
  apply only where fields exist.
- **Detector calibration:** vector-region detection scores were flat
  (0.85/0.90/0.80) regardless of evidence quality. New `detectionScore`
  weights parsed geometry at 0.55 with bounded increments for repeated cells
  (+0.08), proximity label (+0.10), and semantic type match (+0.07), capped at
  0.80 and returning 0 without geometry. No heuristic candidate can present
  itself as near-certain; the Form 6 corpus now scores 0.55–0.80 by evidence
  instead of a uniform 0.9.
- **Implication:** PDFBox no-op output is visually indistinguishable from the
  source on the available corpus at 72 dpi, strengthening the D-007 split
  (PDFKit default for AcroForm-free documents; PDFBox companion lane for
  AcroForm documents). The calibration removes the certainty overstatement
  flagged in F-023.
- **Limits:** 72 dpi raster parity is not universal fidelity; signed, XFA,
  password-protected (with-password policy), and large documents remain
  untested through the lane; PDFBox `getOnValues()`/`PDChoice.getValue()`
  asymmetries are worked around, not fixed upstream.
- **Sources:** `benchmark/pdfbox-lane/RadioProbe.java`,
  `benchmark/pdfbox-lane/run-corpus.sh`,
  `benchmark/results/2026-08-25-pdfbox-corpus/`,
  `Sources/PDFEditorCore/StaticRegionDetector.swift`,
  `Tests/PDFEditorCoreTests/ReviewFixVerificationTests.swift`,
  `docs/pdfbox-packaging-review.md`.

### F-071: Native incremental form writer resolves RG-001 for bounded field edits

- **Date:** 2026-08-25
- **Status:** Runtime-verified (Tier 2/S1) on the public AcroForm sample;
  appearance regeneration and broader corpus remain open.
- **Evidence:** `Sources/PDFEditorCore/PDFIncrementalFormWriter.swift` ports the
  verified web-lane semantics to native Swift: classic xref tables and
  FlateDecode xref streams are parsed, field objects are located through a raw
  AcroForm tree walk (UTF-16BE hex `/T` names decoded — the sample encodes all
  six field names as hex strings), and bounded `/V`+`/AS` edits are appended
  as a genuine incremental update with a `/Prev`-chained xref. The source is
  asserted as a byte-exact prefix inside the writer and again in the export
  path. Routing: AcroForm documents accept only native field-value edits;
  everything else stays fail-closed; compressed-object and encrypted sources
  are refused with precise errors. Durable artifact:
  `benchmark/results/2026-08-25-native-incremental/` — qpdf `--check` exit 0,
  byte-exact 10,768-byte prefix verified with `cmp`, pikepdf reopen shows
  `/V 'Incremental'` on the correct container field node (11) with radio
  choice metadata (`/AP /N`, `/AS`) untouched; PDFKit inspection reads the
  new value through inheritance. Seven tests in
  `PDFIncrementalWriterTests.swift` cover parsing, dict patching, radio
  semantics (parent/kid state selection, clearing, unknown-state fail-closed),
  string escaping, prefix preservation, routing, and the guard.
- **New knowledge:** the sample's field tree uses container nodes
  (10→11→12…) where widget kids inherit `/FT`; appearance states must be
  extracted from any node carrying `/AP`, not just `/FT=Btn` holders. Field
  `/T` values are UTF-16BE hex-encoded. Radio edits write `/V` on the
  terminal field node plus `/AS` on each widget kid — matching the web lane's
  objNum 24/25/30 evidence exactly.
- **Limits:** edited text widgets still show stale appearance streams until a
  viewer regenerates them from `/V` (value-level oracle passes; edited-region
  raster parity is unproven); xref-stream sources beyond FlateDecode are
  refused; object-stream-compressed field documents fail closed pending a
  normalization lane.
- **Implication:** RG-001 moves FAIL → PARTIAL. The native lane can now edit
  external AcroForm documents without the PDFKit writer's known radio-choice
  destruction, using the same source-preserving mechanism that passed RG-002
  on the web lane.
- **Sources:** `Sources/PDFEditorCore/PDFIncrementalFormWriter.swift`,
  `Sources/PDFEditorCore/PDFKitProvider.swift`,
  `Tests/PDFEditorCoreTests/PDFIncrementalWriterTests.swift`,
  `benchmark/results/2026-08-25-native-incremental/`,
  `web/pdf-incremental-form-writer.mjs`.

### F-072: Accessibility, recovery, and structural-fidelity pass closes the OPEN gate list

- **Date:** 2026-08-25
- **Status:** Implementation-verified (Tier 2/S1); human-observation
  remainders documented per gate.
- **Evidence:** All nine previously OPEN gates now carry implementation
  evidence; the registry stands at 55 PARTIAL / 4 PASS with zero FAIL and
  zero OPEN:
  - RG-005/RG-052: structural tag-tree detection via the CGPDF catalog
    (`/StructTreeRoot`, `/MarkInfo` `/Marked`) — PDFKit document attributes
    proved unreliable for tagging. Inspection reports the authored tree or
    explicitly marks it unavailable; export validation fails structure-tree
    loss with evidence and passes byte-preserving lanes by construction.
  - RG-043: search match counts, current match (position + page + snippet),
    page changes, and no-match states post via `NSAccessibility`
    `.announcementRequested` and are recorded in
    `lastAccessibilityAnnouncement` for verification. (The parallel lane had
    independently added the announcer; the two implementations were merged
    rather than duplicated.)
  - RG-057: the ⌘F focus event previously fired without effect; the document
    canvas now consumes it, expands the search HUD, and focuses the field.
  - RG-058: the last unguarded canvas animation (search expand) now honors
    Reduce Motion.
  - RG-059: window minimum reduced 1080×700 → 720×480; HUD chrome is
    contrast-aware under Increased Contrast; no fixed-size fonts exist
    (Dynamic Type intact).
  - RG-029: recovery evidence mapped — crash-interruption suite (payload/
    pair/metadata generation preservation, first-save absence), termination
    flush, provider-level export-failure tests, malformed-input rejection.
  - RG-006/007: implementation surfaces (native announcements/focus/motion/
    contrast; web lane's 46+11 aria- attributes) documented with explicit
    human-observation remainders.
- **Implication:** every gate now has either a passing oracle or a PARTIAL
  status with named, owned remainders — mostly human observation
  (VoiceOver/screen-reader workflows, 200%-zoom passes) and corpus breadth.
- **Sources:** `Sources/PDFEditorCore/PDFKitProvider.swift`,
  `Sources/PDFEditorRecovery/AppModel.swift`,
  `Sources/PDFEditorApp/DocumentCanvasView.swift`,
  `Sources/PDFEditorApp/PDFEditorApp.swift`,
  `Tests/PDFEditorAppRecoveryTests/`, `docs/release-gates.md`.

## Open Questions

- Exact native macOS engine/provider and the boundary to the browser companion.
- Distribution model and acceptable copyleft obligations.
- Whether static blank regions should become real AcroForm fields, annotations,
  overlays, or an internal assistive layer until export.
- Required level of arbitrary PDF content editing versus safe bounded edits.
- Whether OCR/model-assisted detection may process documents locally only.
- Whether scanned-document support belongs in the first slice, and if so whether
  the native Vision path or a packaged open-source OCR adapter is the baseline.
- Initial corpus types: government forms, scanned forms, invoices, contracts,
  tables, or mixed PDFs.

### F-023: Three-lane agent review produced five confirmed fixes and tracked follow-ups

- **Date:** 2026-08-25
- **Status:** Verified by read-only parallel review (core safety, macOS shell,
  provider lane) against the implemented sources; five fixes applied and
  test-verified in the same session.
- **Evidence:** Five review findings were confirmed by direct code inspection
  and fixed:
  1. `PDFImpactValidator.compareRasterOutsideRegions` silently passed when page
     rendering failed (zero-dimension rasters compared equal, empty pixel loop,
     ratio 0). Fixed: `raster(for:scale:)` returns `nil` on failure and the
     comparator fails the page closed; two non-interpolated page-number strings
     fixed in the same pass.
  2. `NativeField.id` embedded PDFKit's global annotation enumeration index,
     unstable across save/reload when non-widget annotations interleave;
     `validate()` reconciles by id, so legitimate exports could fail
     nondeterministically. Fixed: per-(page, name) occurrence counter with the
     index retained only as a duplicate-name tie-breaker.
  3. The AcroForm export guard used a raw `/AcroForm` byte scan (false
     positives in strings; false negatives under object streams). Confirmed at
     `PDFKitProvider.export`; structural CGPDF catalog detection is a tracked
     follow-up.
  4. `ProfileStore` heuristic matching had an operator-precedence bug
     (`a || b && c`), letting an employer-named field match any semantic key.
     Fixed with parentheses.
  5. `applyFieldValue` enforced the signature prohibition only via a disabled
     Button; `.onSubmit` bypassed it. Fixed with a model-level guard, and
     `applyBulkFill` now enforces per-operation permission requirements and
     reports skipped operations.
- **Stale shell findings confirmed already correct in current code:**
  `undoLastEdit` replays before mutating the operation list, and export
  publication uses atomic `replaceItemAt` rather than delete-then-move.
- **Remaining tracked follow-ups (P2 unless noted):**
  - AcroForm guard: replace byte scan with structural CGPDF catalog detection.
  - Button-field retention validation cannot detect a wrong radio/checkbox
    selection and whitespace values can false-fail; resolve expected kid by
    `buttonWidgetStateString` and trim consistently.
  - Signature `.overlayImage` operation is unimplemented in the provider and the
    sign sheet is not yet wired into the UI; hide or implement.
  - OCR provenance is discarded: merged candidates should carry
    `ocr_region` kind plus confidence floor, matching box, capped pixels, and
    off-main execution.
  - Static detector still runs on fabricated uniform line geometry; derive line
    bounds from real glyph geometry and mark synthetic evidence.
  - Detector certainty overstatements: unlabeled squares scored 0.85 as
    "checkboxes" and grouped regions 0.90 from weak keyword signals; downgrade
    to `.unknown`/lower scores.
  - Outside-region raster exclusion ignores page rotation and pixel loops are
    unbounded; transform rects through rotation and cap the pixel budget.
  - P3s: session sidecar file permissions and value retention, unstable
    `annotation.hash` link identity, resource-limit gaps (post-read size check,
    unbounded outline recursion, triple source hashing), redo bypassing replay,
    dead code and hardcoded `textChangedOutsideOperations = false`.
- **Implication:** The slice now fails closed on unverifiable visual evidence
  and no longer overstates detection certainty in the fixed paths, but
  detector/OCR provenance and AcroForm structure handling remain the largest
  correctness gaps before any broader fidelity claim.
- **Sources:** `Sources/PDFEditorCore/PDFImpactValidator.swift`,
  `Sources/PDFEditorCore/PDFKitProvider.swift`,
  `Sources/PDFEditorCore/ProfileStore.swift`,
  `Sources/PDFEditorApp/AppModel.swift`; review transcripts from the core-safety,
  macOS-shell, and provider-lane subagents (2026-08-25).

## Research Completeness

### Established

- The capability frontier and major license families are sufficiently mapped to
  compare the candidates and reject a single-engine assumption.
- Native AcroForm detection is a distinct, higher-confidence path from static
  blank-region suggestion.
- Rendering, detection, editing, and fidelity validation should be separate
  architectural responsibilities.
- OCR candidates and their broad local/licensing shape are mapped well enough to
  define an adapter boundary, but not to select or ship one.

### Contested

- Exact write/save fidelity across malformed, hybrid, encrypted, signed, and
  object-stream-heavy documents remains unmeasured.
- Poppler and PoDoFo component-level licensing boundaries need version-specific
  legal review before distribution claims.

### Unknown

- Which native provider meets the corpus fidelity and packaging bar.
- Whether a browser-only product can meet the target fidelity bar.
- Runtime precision/recall for static-region detection and OCR.
- Incremental-save behavior and signature preservation under the selected writer.
- Exact packaging, performance, memory, and maintenance costs on the target OSes.

### Not Researched

- OCR runtime selection, model packaging, and benchmark results.
- Broader PDFKit corpus results beyond Form 6, including native widget mutation and
  malformed/rotated/encrypted input behavior.
- External AcroForm behavior beyond the public sample, including signatures, XFA,
  malformed fields, field hierarchies, and multiple-choice edge cases.
- Current CVE/security histories for every candidate.
- User research, market alternatives, and legal advice.
- Real-document benchmark results.

### Freshness

Key sources were checked on 2026-08-24. Candidate versions inspected include PDF.js
6.2.108, MuPDF 1.28.2, PDFBox 3.0.8, PoDoFo 1.1.2 plus generated 1.2.0 docs,
pdf-lib 1.17.1, qpdf 12.4.0, pikepdf 10.9.0, and Poppler 26.08.0 where the source
pages exposed those versions. PDFium is tied to Chromium source/build state rather
than a simple standalone release line.

### Decision Impact

The remaining unknowns do not block a proposed bounded architecture, but they do
block claiming a final engine, cross-platform fidelity, or licensing clearance.

### F-052: Independent preservation is now measurable, but rotated operation replay remains open

- **Status:** Verified at Tier 3/S3 for the bounded no-op and public-form mutation
  paths; general PDF preservation remains open.
- **Evidence:** `benchmark/independent-preservation-validator.mjs` uses Poppler
  `pdfinfo`, `pdftotext`, and `pdftoppm` plus qpdf structural status without
  importing PDF.js. `Tests/pdf_independent_preservation_test.mjs` proves that
  an unauthorized reviewed native-field export fails both independent text and
  raster checks, while the same export passes when its source-bound operation
  region is supplied. The test also reopens deterministic 90-degree and mixed
  90/180-degree fixtures and checks their rotation facts. The parity runner
  retains native and browser no-op bytes and writes
  `benchmark/results/contract-parity-2026-08-24/independent-preservation-report.json`.
- **Observed baseline:** 9/9 valid sources reopened through Poppler; the
  malformed input failed as expected. Native no-op outputs passed independent
  reopen/text/raster 9/9. The refreshed browser no-op run passed 9/9 produced
  outputs, including the encrypted byte-preserved export. qpdf structural
  warnings remain explicit on existing public AcroForm/Form 6 artifacts.
- **Implication:** The product can claim a bounded independent preservation
  check for the supported paths, not arbitrary semantic edit fidelity. Viewer
  reopen, qpdf structure, outside-region text, and outside-region raster are
  separate checks and must not be collapsed into one green status.
- **Next gate:** Add a rotated reviewed-operation replay fixture with crop-box
  offsets, then classify qpdf warnings in an accepted-variance registry with
  an owner, tolerance, rationale, and falsifier. A GUI control-viewer
  observation remains separate from this machine-renderer evidence.
- **Sources:** `benchmark/independent-preservation-validator.mjs`,
  `Tests/pdf_independent_preservation_test.mjs`,
  `benchmark/generate_rotation_fixtures.sh`,
  `docs/audits/independent-preservation-rotated-viewer-evidence-2026-08-24.md`,
  and `benchmark/results/contract-parity-2026-08-24/independent-preservation-report.json`.

### F-053: OCR and high-fidelity editing belong behind an optional local companion

- **Status:** Accepted product decision in D-009; implementation and provider
  adoption remain open.
- **Evidence:** The browser proof covers PDF.js inspection, reviewed candidate
  evidence, bounded pdf-lib overlays/form attempts, operation lineage, reopen,
  and independent outside-region preservation for the supported non-encrypted
  paths. The refreshed parity run retains 75 normalized semantic mismatches, with
  imported external AcroForm behavior still provider-specific. Project-local
  cross-project exploration shows that
  OCR is most useful as geometry-bearing evidence with model/language provenance,
  while SignKit, MetaExtract, Invoice Intelligence, and PhotoSearch each carry
  reusable but separately owned parser, OCR, provenance, review, and hard-negative
  patterns. Current source research also identifies browser OCR's PDF-to-image,
  WASM/model, memory, and language-pack burden, and a material licensing/runtime
  boundary for OCRmyPDF, Ghostscript, PDFBox packaging, and MuPDF/MuPDF.js.
- **Decision:** The browser is the zero-install local core, while OCR and
  high-fidelity editing belong in an explicitly installed optional companion
  capability plane when the provider advertises the capability and passes the
  same contract, source-binding, recovery, and independent validation gates.
  Native Vision OCR remains a native adapter, not evidence for browser parity.
- **Implication:** The browser UI must render `companionRequired` or
  `unsupported` as an honest state and remain usable without the companion. The
  companion must never silently upload bytes, silently rewrite the source, or
  turn a provider feature list into a fidelity claim. Browser OCR can remain a
  bounded experiment for supported documents, but it must not silently create
  fields or mutate source content.
- **Falsifier:** The browser and companion split cannot express a required
  long-term capability, a provider passes the defined gates but cannot be
  packaged or operated safely, or the shared contract cannot represent the
  provider's semantics without losing provenance.
- **Next gate:** Define the companion capability handshake, then run separate
  OCR and high-fidelity provider bake-offs against the existing corpus only when
  a browser failure or measured workflow trigger justifies the installation
  surface.
- **Sources:** [`docs/web-deployment-decision.md`](docs/web-deployment-decision.md),
  [`docs/cross-project-document-intelligence-exploration.md`](docs/cross-project-document-intelligence-exploration.md),
  [`docs/audits/native-web-contract-parity-evidence-2026-08-24.md`](docs/audits/native-web-contract-parity-evidence-2026-08-24.md),
  [`docs/audits/independent-preservation-rotated-viewer-evidence-2026-08-24.md`](docs/audits/independent-preservation-rotated-viewer-evidence-2026-08-24.md).

### F-054: Reviewed template abstention and candidate evidence are semantically aligned across Swift and browser

- **Status:** Verified bounded conformance at Tier 2/S1 native plus Tier 3/S1
  isolated Chrome; live PDF-derived fingerprint parity remains open.
- **Evidence:** `PDFTemplateParityHarness` and
  `Tests/template_match_native_browser_parity_test.mjs` consume the same
  canonical 24-case reviewed corpus. The native and browser lanes agree on
  every state, selected template identity, abstention flag, false-positive gate,
  score, candidate identity/state/reason/components, and class policy. The
  retained report records 0 semantic mismatches and 0 evidence mismatches.
- **Observed baseline:** Both lanes report exact 2, knownVariant 2, familyMatch
  6, ambiguous 6, stale 1, and noMatch 7. Both select 10 cases and abstain on
  14. The isolated browser run reports no console or page errors.
- **Implication:** The shared matcher semantics and safety abstention behavior
  can be tested across native and web before either provider is allowed to claim
  production recurring completion. This is stronger than selected-ID parity
  because it checks the evidence that justified the decision.
- **Limits:** The corpus is value-free and single-curator. The native side is a
  Swift benchmark adapter over shared benchmark values, not an independent
  PDFKit extraction of the source PDFs. No PDF byte, renderer, recall, or
  reviewer-agreement claim follows from this result.
- **Next gate:** Independently extract fingerprints from the same real PDFs in
  native and browser lanes, compare geometry, field sequence, anchors, and
  regions, and retain this corpus as the decision-semantics conformance gate.
- **Sources:** `Sources/PDFEditorCore/TemplateBenchmarkContracts.swift`,
  `Sources/PDFTemplateParityHarness/main.swift`,
  `Tests/template_match_native_browser_parity_test.mjs`,
  `benchmark/results/template-matching/2026-08-24-reviewed-corpus.json`,
  `benchmark/results/template-matching/2026-08-24-native-run.json`,
  `benchmark/results/template-matching/2026-08-24-native-browser-semantic-parity.json`,
  and `docs/audits/template-native-browser-semantic-parity-evidence-2026-08-24.md`.

### F-055: Reviewed correction events improve bounded target coverage without weakening abstention

- **Status:** Verified controlled measurement at Tier 2/S1 Node plus Tier 3/S1
  isolated Chrome; real-user completion benefit remains unknown.
- **Evidence:** `web/template-correction-benchmark.mjs` promotes explicit
  same-family corrections through the existing strict learning gate, appends an
  immutable child revision, measures reviewed-target coverage, selects the
  unchanged parent on rollback, and replays hard negatives. The machine report
  is `benchmark/results/template-matching/2026-08-24-correction-benefit.json`.
- **Observed baseline:** Five structured variants begin `noMatch` with zero
  surfaced reviewed targets. After promotion, all five become `exact` with one
  surfaced reviewed target each, a coverage lift of 5. Rollback returns all
  five to `noMatch` with zero surfaced targets. All 35 promoted-revision
  hard-negative checks abstain.
- **Privacy boundary:** Correction records contain no profile values, raw
  labels, PDF bytes, screenshots, or passphrases. A hard-negative correction
  mutation is rejected before child revision creation. The metric is intentionally
  target coverage, not filled-value correctness or speed.
- **Implication:** Reviewed correction events can be treated as a reversible,
  source-bound proposal accelerator. They must not be treated as permission for
  silent value resolution, broad family acceptance, or production accuracy
  claims.
- **Falsifier:** Held-out recurring versions fail to gain reviewed target
  coverage, user corrections do not agree with the promoted mapping, rollback
  cannot restore the parent behavior, or any hard-negative selection occurs.
- **Next gate:** Build a held-out recurring-version study with independent
  reviewer labels, per-field correctness, accepted corrections, stale-source
  recovery, and time-on-task observation while keeping values out of diagnostics.
- **Sources:** `web/template-correction-benchmark.mjs`,
  `Tests/web_template_correction_benchmark_test.mjs`,
  `Tests/web_template_correction_benchmark_browser_test.mjs`,
  `benchmark/results/template-matching/2026-08-24-correction-benefit.json`,
  and `docs/audits/reviewed-template-correction-benefit-evidence-2026-08-24.md`.

### F-056: ihatepdf-inspired experiment definitions now have durable native/browser parity

- **Status:** Verified evidence-definition and semantic-contract parity at Tier
  2/S1 native and Node plus Tier 3/S1 isolated Chrome; six capability runs
  remain planned.
- **Evidence:** `Tests/fixtures/ihatepdf_experiment_ledger.json` contains six
  versioned entries, six linked cases, current fixture references, coordinate
  policy, review and abstention rules, validation obligations, named hard
  negatives, falsifiers, and rollback paths. The Swift and browser projections
  compare with 0 semantic mismatches, and the report records 4/4 ledger
  mutations rejected.
- **Observed cases:** E-001 text-run replacement preservation, E-002 OCR
  layer alignment, E-003 privacy preflight and sanitization, E-004 repair and
  recovery, E-005 device-adaptive browser limits, and E-006 compare/operation
  impact maps.
- **Implication:** Competitor breadth is now an admission-controlled experiment
  program. A future provider implementation must retain the case identity,
  source digest, coordinate projection, review boundary, validation obligations,
  and falsifier rather than turning a feature page into an unqualified product
  claim.
- **Limits:** This parity result is contract evidence, not OCR accuracy,
  arbitrary text-edit fidelity, sanitization completeness, repair recovery,
  cross-device performance, or independent-viewer impact proof. The malformed
  fixture was hashed but not repaired.
- **Next gate:** Execute E-006 or E-002 against real outputs only after its
  provider and independent-validator gate is defined. Keep the remaining cases
  planned until their corpus oracle and recovery path are implemented.
- **Sources:** `Tests/fixtures/ihatepdf_experiment_ledger.json`,
  `web/ihatepdf-experiment-contract.mjs`,
  `Sources/PDFExperimentParityHarness/main.swift`,
  `Tests/ihatepdf_experiment_parity_test.mjs`,
  `benchmark/results/ihatepdf-experiments/2026-08-24-semantic-parity-report.json`,
  and `docs/audits/ihatepdf-experiment-ledger-parity-evidence-2026-08-24.md`.

### F-057: Cross-project evidence and PDF corpus parity are now machine-gated

- **Status:** Verified at Tier 1/S1 source inventory plus Tier 2/S1 native and
  Tier 3/S1 isolated Chrome semantic parity; adjacent runtime reuse remains
  unproven.
- **Evidence:** `Tests/fixtures/cross_project_evidence_ledger.json` records six
  versioned entries spanning SignKit, MetaExtract, Invoice Intelligence,
  PhotoSearch, extracted_forms, and the historical signature auto-detect web
  project. The ledger references 18 source artifacts and stores paths and
  hashes, not PDF bytes, profile values, screenshots, or extracted content.
  `Tests/fixtures/pdf_corpus_semantic_parity_fixture.json` records one case for
  each of the 11 existing PDF fixtures. The combined consumer is
  `Tests/cross_project_evidence_ledger_parity_test.mjs`.
- **Observed baseline:** The retained report
  `benchmark/results/cross-project-ledger/2026-08-24-ledger-parity.json`
  passes with 6 ledger entries, 11 corpus cases, 18 source references, 4
  parity mismatches, and 0 unexpected mismatches. The four mismatches are two
  `candidate-semantic-set` and two `candidate.count` differences, limited to
  the static Form 6 fixture and its mixed-rotation derivative. The malformed
  input fails inspection in both lanes as expected.
- **Provenance finding:** The live
  `benchmark/results/2026-08-23-public-acroform/noop.pdf` digest is
  `9ed5ff75fec3a5f51847160e81d5413d1797a84005a02a757787f477b1f934f8`, while
  the existing manifest declares a different digest. The harness records this
  as source identity drift and leaves both the manifest and binary unchanged.
- **Implication:** The project now has a durable admission boundary for
  transferring patterns from adjacent OCR, parser, signature, and metadata
  work. Native and browser adapters can be compared on user intent and safety
  semantics without forcing byte identity or silently erasing detector
  differences.
- **Limits:** This does not prove neighboring runtime quality, license or
  redistribution clearance, OCR accuracy, arbitrary text editing, independent
  viewer parity, or universal PDF fidelity. The four candidate mismatches
  remain open.
- **Next gate:** Independently extract fingerprints from the same live PDFs in
  both lanes, then calibrate precision, recall, correction distance, and
  hard-negative abstention by document class before admitting OCR, parser, or
  companion implementations.
- **Sources:** `Tests/fixtures/cross_project_evidence_ledger.json`,
  `Tests/fixtures/pdf_corpus_semantic_parity_fixture.json`,
  `Tests/cross_project_evidence_ledger_parity_test.mjs`,
  `benchmark/results/cross-project-ledger/2026-08-24-ledger-parity.json`,
  `benchmark/results/contract-parity-2026-08-24/parity-report.json`, and
  `docs/audits/cross-project-evidence-ledger-parity-evidence-2026-08-24.md`.

### F-058: Expanded corpus separates safe failure from fidelity support

- **Status:** Verified at Tier 1/S1 fixture provenance, Tier 2/S1 native and
  independent-parser evidence, and Tier 3/S1 isolated Chrome evidence.
- **Observed:** Six derived fixtures cover hybrid text/raster/form content,
  degraded scans, rotation, AES-256 encryption, intentional truncation, and a
  40-page hybrid stress input. The browser contract gate passed all 17 cases
  with zero console or page errors. Native/browser parity passed with six
  classified mismatches and zero unexpected mismatches. Poppler/MuPDF reopened
  53 eligible PDFs, and qpdf output checks passed 55 generated PDFs with six
  known recoverable Form 6 warnings and zero hard failures.
- **Safety boundary:** The malformed fixture correctly fails inspection in
  both lanes and produces no published output. The encrypted hybrid supports
  password open and byte-preserving no-op export, while encrypted edits remain
  rejected before download. Unauthorized text and raster mutations fail, while
  authorized source-bound regions pass.
- **Implication:** Corpus breadth now tests distinct parser, coordinate,
  resource, encryption, and failure-state boundaries without upgrading any one
  provider to universal PDF support. The encrypted page-box rounding mismatch
  and Form 6 detector mismatches remain named, scoped, and visible.
- **Limits:** No OCR accuracy claim, arbitrary text-edit claim, signed/XFA/
  PDF-UA claim, malformed-object repair claim, or resource ceiling claim beyond
  the measured 40-page fixture is admitted.
- **Sources:** `benchmark/generate_browser_corpus.sh`,
  `docs/fixtures/manifest.md`, `Tests/fixtures/pdf_corpus_semantic_parity_fixture.json`,
  `docs/audits/browser-corpus-fidelity-evidence-2026-08-25.md`, and the retained
  reports under `benchmark/results/contract-parity-2026-08-24/`.

### F-059: Provider availability must not be mistaken for provider support

- **Status:** Verified at Tier 1/S1 design and fixture inspection plus Tier
  2/S1 native and browser contract tests. Runtime installation and companion
  execution remain unknown.
- **Observed:** The existing architecture accepted a browser core plus an
  optional companion, but did not yet own the admission semantics needed to
  distinguish installed, measured, enabled, partial, revoked, quarantined, and
  expired capabilities. The new registry and negotiator make those states
  explicit without changing the shared PDF payloads.
- **Safety properties:** Enabled capabilities require an exact artifact-bound
  measurement. Unapproved licenses, installed-but-unmeasured providers,
  revoked/quarantined providers, and source-limit mismatches abstain. Selection
  is deterministic and emits reason codes. The registry is value-free.
- **Fixture evidence:** Browser PDF.js/pdf-lib reader is enabled for its passed
  reader measurement; native Vision OCR is measured-partial; PDFBox is
  installed-but-unmeasured; MuPDF is quarantined with license review open. This
  is deliberate evidence classification, not provider adoption.
- **Implication:** OCR and high-fidelity engines can be installed and measured
  over time without creating a new PDF document model or forcing the browser
  and native lanes onto one engine. Capability enablement becomes reversible
  and explainable at the admission boundary.
- **Limits:** No installer verification, authenticated bridge, sandbox,
  cancellation, memory enforcement, live provider bake-off, revocation feed,
  or real OCR/high-fidelity execution is claimed.
- **Sources:** `docs/provider-capability-system-design.md`,
  `Sources/PDFEditorCore/ProviderCapabilityContracts.swift`,
  `web/provider-capability-contract.mjs`,
  `Tests/fixtures/provider_capability_registry.json`,
  `Tests/provider_capability_contract_test.mjs`, and
  `Tests/PDFEditorCoreTests/ProviderCapabilityContractTests.swift`.

### F-060: Text identity can agree while provider geometry remains unsafe for replacement

- **Status:** Verified at Tier 3/S1 native and isolated Chrome runtime evidence
  across the current 18-entry execution manifest. Replacement support remains
  abstained.
- **Observed:** The new `pdf-editor.text-run-ocr-alignment` projection measured
  81 pages, with 29 pages exposing comparable text evidence and 10 pages where
  native OCR could be compared with browser selectable text. Mean text-hash
  agreement was 0.6593. PDFKit and PDF.js often identified the same normalized
  text fingerprint, but their provider rectangles did not agree within two
  points; OCR geometry did not agree within three points on the measured OCR
  pages.
- **Safety properties:** All 18 cases were source-bound. Two malformed inputs
  failed safely. Seventy-one pages without usable browser OCR/reference
  evidence produced explicit abstentions. No raw text, OCR values, replacement
  values, pixels, passwords, or source bytes were retained. No provider was
  allowed to silently replace text.
- **Implication:** Provider text objects cannot be passed directly into a future
  replacement writer. A provider-independent text-box control, class-specific
  transform calibration, browser OCR capability, and outside-region/raster/
  reopen/viewer proof are required before semantic replacement can be enabled.
- **Limits:** This is not universal PDF text-editing, OCR language, handwriting,
  font-fidelity, PDF/UA, signature, XFA, or independent-viewer parity evidence.
  Visual overlays and native form filling remain different operation types.
- **Sources:** `web/text-run-ocr-alignment-benchmark.mjs`,
  `Sources/PDFTextRunOCRBenchmark/main.swift`,
  `Tests/text_run_ocr_alignment_browser_test.mjs`,
  `benchmark/results/text-run-ocr-alignment/browser-and-native.json`, and
  `docs/audits/text-run-ocr-alignment-evidence-2026-08-25.md`.

### F-061: Native/browser candidate agreement is measurable but not yet equivalent

- **Status:** Verified at Tier 2/S1 native and Tier 3/S1 isolated Chrome
  corpus evidence, with S3 mutation coverage for the comparator.
- **Observed:** The fresh 18-fixture candidate report contains 206 native
  candidates and 140 browser candidates. One-to-one page-space pairing forms
  118 geometry pairs, with 49 fully equivalent pairs, 88 native-only
  candidates, and 22 browser-only candidates. Native directional coverage is
  native candidate coverage by browser pairs is 57.28%, browser candidate
  coverage by native pairs is 84.29%, and symmetric agreement F1 is 68.21%.
- **Mismatch clusters:** 59 coordinate-space mismatches, 18 field-type
  mismatches, 14 entry-mode mismatches, 2 review-state mismatches, 2
  geometry-precision mismatches, and 2 grouping mismatches. The rotated Form 6
  derivative has zero fully equivalent pairs because rotation coordinate space
  differs across all 59 matched regions.
- **Safety properties:** The report is source-digest-bound and omits provider
  IDs, labels, evidence prose, scores, timestamps, and output digests. It does
  not treat native or browser as ground truth, and it preserves provider-only
  candidates for review instead of discarding them.
- **Implication:** Candidate parity now provides a concrete remediation map for
  detector taxonomy, grouping, and rotation normalization. It is not a
  precision/recall result because the current 18-fixture corpus has no reviewed
  target labels for these provider candidates.
- **Mutation evidence:** Provider-ID and prose mutations remain equivalent;
  candidate-kind, evidence-kind, and large-coordinate mutations are detected.
- **Limits:** Reviewed candidate adjudication, split/merge pairing, candidate-
  bearing scanned and OCR fixtures, and broader real-world form classes remain
  open.
- **Sources:** `web/candidate-parity.mjs`,
  `Tests/native_browser_candidate_parity_report_test.mjs`,
  `Tests/candidate_parity_mutation_test.mjs`,
  `benchmark/results/semantic-parity/2026-08-25/candidate-parity-report.json`,
  and `docs/audits/native-browser-candidate-parity-evidence-2026-08-25.md`.

### F-062: Session privacy needs execution provenance above document preflight

- **Status:** Verified at Tier 2/S1 native and Tier 3/S1 isolated Chrome
  runtime evidence across the current 18-entry corpus.
- **Observed:** Existing preflight described source risk surfaces but could not
  state whether OCR ran, where processing occurred, how a source was retained,
  or which validated output was produced. The new session envelope fills that
  lifecycle gap without duplicating document content.
- **Safety properties:** Sixteen readable native and browser fixtures emitted
  source-bound records. Native reports `local-device`; browser reports
  `local-browser`; current corpus OCR is `not-used`; successful exports carry
  output digests and reopen validation. Two malformed inputs have no session
  record rather than a fabricated privacy claim.
- **Mutation evidence:** Swift and browser tests reject stale digests, true
  privacy flags, not-used OCR with usage evidence, and successful exports
  without output digest/reopen provenance.
- **Implication:** Future OCR, companions, remote services, persistent browser
  storage, and eviction/recovery flows must emit actual typed locality and
  retention states. They cannot inherit local no-OCR defaults.
- **Limits:** Runtime provenance for real OCR, companion IPC, remote services,
  browser eviction, source deletion confirmation, and encrypted persistence is
  not claimed by this no-OCR corpus run.
- **Sources:** `web/pdf-session-provenance.mjs`,
  `Sources/PDFEditorCore/SessionPrivacyProvenanceContracts.swift`,
  `Sources/PDFEditorCore/DocumentSessionContracts.swift`, the session
  provenance tests, and the session provenance audit.

### F-063: Browser export preservation now has an explicit independent-renderer join

- **Status:** Verified at Tier 3/S1 across the current 18-fixture corpus, with
  S3 focused mutations for provider divergence and missing PDF.js checks.
- **Observed:** Poppler 26.08.0 independently reopened and measured all 16
  readable browser no-op exports. Source digests matched 16/16. Poppler
  outside-region text and raster verdicts agreed with the PDF.js
  `outsideRegionText` and `visualDiff` checks for 16/16 readable fixtures.
  Two malformed fixtures remained `expectedFailure` with `unknown` text and
  raster comparison, not a fabricated pass.
- **Safety properties:** The report preserves provider-specific evidence,
  source/output digests, page geometry, and qpdf structural status. It reports
  `divergence` when PDF.js and Poppler disagree, and `unknown` when either gate
  is absent. The focused mutation test proves both behaviors.
- **Implication:** Independent renderer evidence is now connected to the
  browser gate without making Poppler a replacement authority or hiding
  provider disagreement. The full parity runner regenerates the comparison
  report beside the detailed preservation report.
- **Limits:** This is no-op/export preservation evidence. It does not prove
  arbitrary semantic editing, universal raster equivalence, MuPDF three-way
  agreement, GUI-viewer parity, redaction, signatures, XFA, PDF/UA, or
  production support.
- **Sources:** `benchmark/browser-export-independent-viewer-validator.mjs`,
  `benchmark/independent-preservation-validator.mjs`,
  `Tests/browser_export_independent_viewer_validator_test.mjs`,
  `benchmark/results/semantic-parity/2026-08-25/independent-browser-viewer-report.json`,
  and `docs/audits/independent-browser-viewer-comparison-evidence-2026-08-25.md`.

### F-064: Preservation metrics must remain visible when export is withheld

- **Status:** Verified at Tier 2/S1 source-contract level and Tier 3/S1
  isolated Chrome runtime level.
- **Observed:** The browser validation pipeline already computed page-level
  outside-region text equality and raster pixel metrics, but the review/export
  panel reduced them to one message per check. Reviewers could see that an
  export failed without seeing changed-page counts, changed-pixel counts,
  ratios, channel deltas, or the comparison basis.
- **Implemented:** Optional value-minimized `metrics` fields now travel on the
  existing `outsideRegionText` and `visualDiff` checks. The panel renders text
  and raster status, compared/changed page counts, pixel counts, ratio, maximum
  channel delta, scale/tolerance, operation count, and evidence basis.
- **Safety properties:** Raw `sourceOutside` and `outputOutside` strings are
  not rendered. Byte-preserving no-op exports identify source-digest equality
  rather than claiming a raster loop ran. Failed and unknown checks remain
  visible and styled as such.
- **Runtime evidence:** A public-sample no-op export displayed passing metrics.
  A static Form 6 reviewed overlay displayed failed metrics with one changed
  page and 385 changed pixels out of 2,317,088, while the export remained
  withheld by the existing validator.
- **Limits:** The panel is presentation of PDF.js evidence. It is not
  independent Poppler proof, pixel-buffer equality between renderers, PDF/UA,
  arbitrary semantic-edit, redaction, signature, XFA, or production evidence.
- **Sources:** `web/index.html`,
  `Tests/web_reader_contract_test.mjs`,
  `Tests/web_pdf_proof_playwright_test.mjs`, and
  `docs/audits/browser-preservation-metrics-evidence-2026-08-25.md`.

### F-065: Independent fidelity needs normalized measurements and operation binding

- **Status:** Verified at Tier 2/S3 focused independent-renderer evidence;
  fresh current-browser full-corpus regeneration remains unknown because the
  existing 4173 browser surface timed out before PDF.js initialization.
- **Observed:** The Poppler/PDF.js report already compared typed verdicts, but
  retained bundles produced before the browser metrics surface had no
  normalized PDF.js measurement payload. The wrapper also did not propagate
  serialized browser edit operations into Poppler's outside-region validator.
- **Implemented:** The report now preserves provider-specific normalized text
  and raster metrics, labels measurement comparability explicitly, and passes
  `editSession.operations` into the independent validator. Missing operation
  lineage and coordinate/page mismatches produce `unknown` rather than an
  empty authorization region.
- **Mutation evidence:** The focused test proves baseline agreement, deliberate
  PDF.js divergence failure, missing-gate unknown, comparable normalized
  measurements, valid operation binding, and coordinate-mismatch abstention.
- **Implication:** Status agreement can be used for no-op corpus evidence, but
  edited-operation promotion requires fresh browser bundles with metrics and
  source-bound serialized operation regions.
- **Limits:** Poppler remains the selected independent engine for this lane.
  MuPDF three-way comparison, GUI-viewer parity, and fresh full-corpus browser
  regeneration remain open.
- **Sources:** `benchmark/browser-export-independent-viewer-validator.mjs`,
  `Tests/browser_export_independent_viewer_validator_test.mjs`, and
  `docs/audits/independent-browser-viewer-comparison-evidence-2026-08-25.md`.

### F-066: Encrypted local persistence now preserves template history and profile isolation

- **Status:** Verified at native focused runtime and browser isolated-Chrome
  runtime; long-term recovery and deletion surfaces remain active.
- **Observed:** Native `EncryptedPDFTemplateStore` persists the existing
  `PDFTemplateRevisionSet` with AES-GCM and a Keychain-backed template key.
  `EncryptedPDFProfileVault` uses a separate directory and Keychain account.
  Browser IndexedDB persists encrypted template-history and profile-history
  records, with a distinct profile-derived key, explicit unlock, backup
  recovery, deletion, and zero-content diagnostics.
- **Safety evidence:** Native ciphertext does not contain template or profile
  values. Missing revision parents are rejected. Corrupt primary data recovers
  only from an authenticated backup and reports `recoveredFromBackup`. Wrong
  profile keys fail. Browser tests pass wrong-passphrase rejection, IndexedDB
  eviction recovery, profile/template deletion, source-byte exclusion, and
  zero-content log filtering.
- **Product integration:** The live web page no longer writes profile values to
  plaintext IndexedDB. Template persistence is an explicit encrypted revision
  action, and profile persistence requires explicit vault unlock. The native
  `AppModel` now uses the revision-preserving profile vault through its existing
  `UserProfile` projection.
- **Implication:** Recurring-layout learning can persist reviewed mappings and
  profile references without making a template a copy of the source PDF or a
  hidden sensitive-value database.
- **Limits:** Secure erasure from OS/browser backups, Keychain-loss recovery,
  passphrase recovery, quota exhaustion, multi-tab conflict handling,
  cross-platform encrypted-backup parity, and native SwiftUI persistence
  controls remain unverified.
- **Sources:** `Sources/PDFEditorCore/EncryptedTemplatePersistence.swift`,
  `web/pdf-template-store.mjs`, `web/index.html`, focused native/browser tests,
  and the encrypted persistence audit.

### F-067: Template completion requires two independently bound approvals

- **Status:** Verified at native Tier 2/S2, browser contract Tier 2/S2, and
  isolated Chrome Tier 4/S1 evidence.
- **Observed:** Completion entries now carry separate mapping and profile-value
  approval records. Mapping approval binds the mapping, resolved provider
  target, and page-space coordinate. Profile-value approval binds the profile,
  profile revision, semantic key, and SHA-256 of the exact typed value.
- **Safety evidence:** Value approval without mapping approval is rejected.
  Mapping approval without value approval is rejected. Changing an approved
  value fails the old digest binding. Changing native target resolution resets
  mapping approval. No template edit operation is created before both records
  pass the source and coordinate gates.
- **Product integration:** Native SwiftUI exposes separate mapping and exact
  profile-value controls through `AppModel`. The browser review panel exposes
  separate `Approve mapping` and `Approve exact profile value` controls and
  leaves Apply disabled for unreviewed entries.
- **Implication:** A recurring template can accelerate reviewed completion
  without turning a layout match into permission to use a stale or unintended
  profile value.
- **Limits:** Automated macOS UI interaction evidence, profile revision change
  during an open proposal, and collaborative multi-reviewer authorization
  remain open. The browser no-profile path is explicitly session-only.
- **Sources:** `Sources/PDFEditorCore/TemplateRuntimeContracts.swift`,
  `Sources/PDFEditorApp/AppModel.swift`, `Sources/PDFEditorApp/ContentView.swift`,
  `web/pdf-template-contract.mjs`, `web/index.html`, focused tests, and
  `docs/audits/template-review-workflow-evidence-2026-08-25.md`.

### F-068: Structural fingerprint parity isolates provider divergence

- **Status:** Verified at Tier 2/S1 over the retained native and browser
  bundles for all 18 current corpus entries, with focused S3 mutations for
  source binding, rotation, permissions, candidate population, coordinate
  space, and tolerated text representation drift.
- **Observed:** A dedicated value-minimized fingerprint projection agrees on
  the two expected malformed failure states. Sixteen readable fixtures retain
  provider divergence. Permission observability differs on 16 fixtures, text
  character counts differ within tolerance on 8, encrypted-hybrid page-box
  precision differs on 1, and the two static Form 6 fixtures differ across
  candidate count, field-type distribution, grouping, evidence composition,
  label-association population, geometry, and coordinate-space metadata.
- **Safety properties:** The fixture retains source SHA-256 only for binding and
  excludes raw labels, evidence prose, provider IDs, timestamps, output
  digests, and PDF bytes. Malformed inputs remain explicit equal failure states,
  not fabricated successful parity.
- **Implication:** Native/browser parity must be repaired by feature family.
  Permission fallback, text segmentation, candidate grouping/classification,
  rotation normalization, and encrypted page-box precision are separate
  engineering problems and must not be collapsed into one aggregate score.
- **Limits:** The result consumes existing emitted bundles. It is not a fresh
  native/browser regeneration, independent-viewer proof, reviewed candidate
  precision/recall result, or arbitrary PDF editing guarantee. The browser
  permission values remain conservative fallback observations until the adapter
  can distinguish observed source permissions from unknown coverage.
- **Sources:** `web/pdf-fingerprint-parity.mjs`,
  `benchmark/generate_fingerprint_parity.mjs`,
  `Tests/fixtures/pdf_fingerprint_parity_fixture.json`,
  `benchmark/results/semantic-parity/2026-08-25/fingerprint-parity-report.json`,
  `Tests/native_browser_fingerprint_parity_test.mjs`, and
  `docs/audits/native-browser-fingerprint-parity-evidence-2026-08-25.md`.

### F-069: PDFBox passes the external-AcroForm gate PDFKit fails; five review fixes landed with fail-closed evidence

- **Date:** 2026-08-25
- **Status:** Runtime-verified (Tier 2/S1) for the PDFBox lane and the five
  Swift fixes; broader PDFBox corpus and raster parity remain open.
- **PDFBox lane evidence:** `benchmark/pdfbox-lane/` (RadioProbe.java + run.sh)
  against the same public sample that fails in PDFKit. PDFBox 3.0.8
  (`pdfbox-app` fat jar, SHA-512 `76884723…e9600` verified against the published
  digest) preserved `applicant.contact` radio export values `email|phone`
  across a no-op save/reload with `perFieldDiffs: []` across all six fields,
  retained a mutated text value, and left the source unchanged. All four oracle
  booleans (`noOpReopen`, `widgetStateEquivalent`, `mutatedReopen`,
  `originalUnchanged`) are true; the PDFKit gate fails `widgetStateEquivalent`
  on the identical fixture (F-016). The native-widget fixture correctly
  reports `fieldCount: 0` (no `/AcroForm` dictionary), a valid negative
  control. Observed PDFBox quirks: `getOnValues()` returns a `Set` while
  `getExportValues()` returns a `List`; unchecked radios report value `"Off"`
  even when not in export values; `PDChoice.getValue()` is a list.
- **Implication:** The radio-choice loss is PDFKit-specific, not systemic.
  PDFBox is now the leading form-aware provider lane; PDFKit remains
  acceptable for AcroForm-free documents behind the structural export guard.
- **Five fixes landed with tests (`ReviewFixVerificationTests`):**
  1. Structural AcroForm detection via the CGPDF catalog replaces the raw
     `/AcroForm` byte scan. The byte scan false-positived on the literal
     string in annotation/content text and false-negatived under object
     streams. A fixture whose FreeText contents are literally `/AcroForm` now
     exports successfully; real AcroForm documents remain blocked for edited
     exports with the unchanged user-facing message.
  2. Radio/checkbox retention validation now requires exactly the requested
     kid on and every sibling off (`buttonValueRetained`). The previous
     "any kid off matches an off request" rule validated documents with the
     wrong kid selected; whitespace trimming is now symmetric.
  3. Signature `.overlayImage` stays fail-closed with a precise reason:
     system PDFKit exposes no image-annotation API that survives save
     (header-verified: stamps are name-only; custom appearance streams are
     not serializable through the public API). The operation is rejected
     before any file is written; the form-aware provider lane is the tracked
     path.
  4. OCR candidates now preserve provenance: `detectOCR` emits `.ocrRegion`
     kind, confidence-derived scores capped at 0.6, recognized text plus
     confidence in evidence, and drops observations below the 0.35 floor
     (mirroring the CV geometry provider) instead of silently downgrading
     them to anonymous text-anchored guesses.
  5. Raster comparison is rotation-aware and budget-bounded: page rotation is
     resolved through PDFKit (`page.rotation`; `CGPDFPageGetRotationAngle` is
     Swift-obsoleted), the pixel-to-user mapping applies the /Rotate inverse,
     and pages above the 4M-pixel budget are downsampled (failing closed to
     `.unknown` below the 0.2 minimum scale) instead of allocating unbounded
     bitmaps.
- **New PDFKit rendering knowledge (empirical, probe-verified):** for
  `/Rotate 90` pages, `PDFPage.draw(with: .cropBox, to:)` renders rotated
  content into a context sized by the UNROTATED crop box (612×792, not
  swapped), clipping overflow; `CGPDFPage.getBoxRect(.cropBox)` also returns
  unrotated dimensions. User→display maps as `(x,y) → (y, width − x)` for
  90° clockwise. The validator's exclusion mapping was verified against the
  observed changed-pixel bounding box, not assumed.
- **Verification:** `swift test` 128/128 (two consecutive full runs);
  fixture-gated Form 6 and public-AcroForm tests; `swift build -c release`;
  `benchmark/pdfbox-lane/run.sh` PASS. One transient failure of the Form 6
  candidate-count assertion occurred during a concurrent parallel-agent
  refactor of `PDFVectorStreamParser`/tests and is owned by that lane.
- **Sources:** `Sources/PDFEditorCore/PDFKitProvider.swift`,
  `Sources/PDFEditorCore/PDFImpactValidator.swift`,
  `Sources/PDFEditorCore/StaticRegionDetector.swift`,
  `Sources/PDFEditorRecovery/AppModel.swift`,
  `Tests/PDFEditorCoreTests/ReviewFixVerificationTests.swift`,
  `benchmark/pdfbox-lane/`,
  `benchmark/results/2026-08-25-pdfbox-public-acroform/result.json`.
