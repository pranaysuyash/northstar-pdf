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

### F-050: Template family matching needs reviewed hard negatives before threshold promotion

- **Status:** Reviewed benchmark verified at Tier 2/S1 with deliberate policy
  mutation; live PDF.js corpus smoke verified at Tier 3/S1. Production family
  matching remains disabled.
- **Evidence:** `web/template-match-benchmark.mjs` scores geometry, native field
  sequence, keyed anchors, and region signatures after exact and known-variant
  precedence. `Tests/web_template_match_benchmark_test.mjs` passes exact,
  known-variant, family, ambiguous, stale, and two no-match cases. The near-
  family negative scores `0.41` and the unrelated corpus negative scores about
  `0.305` under the current `0.76` family threshold. A deliberate mutation that
  lowers the threshold to `0.10` and removes the ambiguity margin fails the
  benchmark as required. The browser companion extracts fingerprints from the
  public sample and Form 6 PDFs through PDF.js and rejects the Form 6 false
  positive with a score of about `0.0273`.
- **Implication:** A high structural score is only a review-ranking signal. The
  matcher must abstain on equal evidence, stale sources, and hard negatives;
  values and operations remain separately review-gated. Thresholds must not be
  promoted from controlled perturbations to batch acceptance without real
  recurring versions, reviewer-labeled mappings, and document-class-specific
  hard negatives.
- **Sources:** `web/template-match-benchmark.mjs`,
  `Tests/fixtures/template_matching_reviewed_fixtures.mjs`,
  `Tests/web_template_match_benchmark_test.mjs`, and
  `Tests/web_template_match_benchmark_browser_test.mjs`.

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
