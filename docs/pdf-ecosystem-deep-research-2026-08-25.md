# PDF Library, Engine & Feature Ecosystem — Deep Research (Native + Web)

**Date:** 2026-08-25 · **Scope:** All PDF-related libraries, engines, parsers, extractors, OCR,
and feature tooling across ecosystems, **evaluated for both the native (macOS/Swift) and web
(browser/JS) surfaces of `pdf_editor`**. · **Evidence tier:** Local machine = verified by
direct inspection (Aug 2026); library facts = verified against primary sources (GitHub/PyPI/npm/
official docs) by research agents in Aug 2026; items that could not be positively confirmed are
flagged **[verify]**.

> This document is the companion deep-dive to `docs/open-source-landscape.md`,
> `docs/pdf-engine-comparison.md`, and `docs/pdf-feature-frontier.md`. Those cover the project's
> gated adoption decisions; this one is the *exhaustive catalog* of what exists and what each
> option can/cannot do, plus scoped further-exploration areas. The product is **two surfaces**: a
> zero-install **browser core** and an installed **native companion**; both sit behind
> provider-neutral contracts (see `Sources/PDFEditorCore/SharedContracts.swift` and
> `web/pdf-contract-mutation-gate.mjs`).

---

## 0. Executive Summary

- **The product already has a real, working stack on both surfaces.** Native = Apple **PDFKit** +
  **Vision** OCR + a custom vector-stream parser + a conservative static detector, all behind
  provider-neutral contracts. Web = **PDF.js 4.2.67** (reader) + **pdf-lib 1.17.1** (writer) +
  a PDF.js operator-list geometry detector + a fail-closed mutation gate.
- **Neither surface can do everything, by design and by engine limit.** Both are **read + light
  edit + form-fill/overlay** engines. They cannot (without a heavier engine): rasterize-and-OCR
  on the web, sign, do high-fidelity content editing, handle XFA, or guarantee Adobe-grade PDF 2.0
  fidelity.
- **Licensing is the hidden decider.** PDFKit/CGPDF/Vision are free *but Apple-only*. PDFium is
  Apache-2.0 (the only permissive reference-grade engine — bundle it for XFA/JS/fidelity). MuPDF
  is AGPL (commercial license needed for closed source). Poppler is GPL (dead for proprietary Mac
  apps). The web stack (pdf.js Apache-2.0, pdf-lib MIT) is clean; adding Tesseract.js (Apache-2.0)
  keeps it clean.
- **Biggest capability gap on the web = OCR and high-fidelity editing.** Native already covers OCR
  via Vision; web has *no* OCR today. Browser OCR is feasible with Tesseract.js (WASM) or a native
  companion hand-off; full in-browser editing/signing realistically needs a commercial WASM engine
  (Nutrient/Apryse) or a bundled PDFium/MuPDF WASM build.
- **Actively maintained vs stalled matters.** pdf.js is at v6 (project pins **4.2.67** — upgrade
  available). pdf-lib is **stalled since 2021** (1.17.1). PyMuPDF, pypdf, OCRmyPDF, Tesseract,
  qpdf, Poppler, PDFium, MuPDF all active. Camelot revived to 2.0 in 2026.

---

## 1. Local Machine Inventory (verified on this Mac, 2026-08-24)

Direct inspection of `/opt/homebrew`, system Python, and managed runtimes:

| Tool / package | Version | License | Role | Notes |
|---|---|---|---|---|
| **poppler** (pdftotext, pdfinfo, pdftoppm, pdfimages, pdftocairo) | 26.08.0 | GPL-2.0+ | Text extract + rasterize (CLI) | Installed via brew. GPL — *not* safe to link into a proprietary app. |
| **qpdf** | 12.4.0 | Apache-2.0 | Structural transform, encrypt/decrypt, linearize | Permissive. Already used by project's `independent-preservation-validator.mjs`. |
| **mupdf-tools / mutool** | 1.28.2 | AGPL-3.0 / commercial | Render + edit + extract (CLI) | Artifex. AGPL unless paid. |
| **tesseract** + **tesseract-lang** | 5.5.0 | Apache-2.0 | OCR engine + language packs | CPU-only LSTM. Local OCR available today. |
| **leptonica** | (dep of tesseract) | BSD-2 | Image preprocessing for Tesseract | — |
| **imagemagick** | 7.x | ImageMagick (Apache-2.0-like, custom) | Image convert/preprocess | `convert` deprecated → use `magick`. |
| **PyPDF2** (system python3) | 3.0.1 | BSD-3 | PDF merge/split/encrypt | **Deprecated** — superseded by `pypdf`. Do not build on it. |
| **Pillow** (system python3) | 11.3.0 | HPND | Image I/O (pre/post OCR) | — |
| **Ghostscript** | **NOT installed** | AGPL/commercial | PS/PDF raster, PDF/A | Absent. Camelot `lattice` would need it if used. |
| **OCRmyPDF** | **NOT installed** | AGPL-3.0 | Scanned → searchable PDF | Absent (pip). Can `pip install` if needed; AGPL. |
| **pdftk** | **NOT installed** | GPL | PDF toolkit (legacy) | Absent; qpdf covers its use cases. |

**Managed runtimes** (`/Users/pranay/.workbuddy-ai/binaries/...`): Python 3.13 and Node 22 — no
PDF packages pre-installed in their venvs. **No external Swift packages** are declared in
`Package.swift` — the native app is 100% local code + Apple frameworks.

**Implication:** This machine can *already* run a local OCR pipeline (Tesseract 5.5 + qpdf) and a
high-fidelity extract/render pipeline (poppler/mutool) for benchmarking and a potential local
companion/CLI, without pulling cloud services.

---

## 2. Capability Taxonomy (what "PDF work" actually means)

Every library below is judged on these axes. Use this as the scorecard:

1. **Parse / structure** — read the COS object model, xref, content streams.
2. **Text extraction** — pull character/text with coordinates.
3. **Layout / block extraction** — group text into lines/blocks/reading order; geometry-aware.
4. **Table extraction** — recover row/column/grid structure (ruled or whitespace).
5. **OCR** — image/scanned → text (offline vs cloud).
6. **Rendering / rasterization** — page → PNG/bitmap at fidelity.
7. **Editing / mutation** — insert/delete/reorder pages, redact, content surgery.
8. **Forms** — **AcroForm** (fill/create) and **XFA** (dynamic XML forms).
9. **Annotations** — highlight/ink/link/widget create+modify.
10. **Digital signatures / security** — encrypt, permissions, PKCS#7 sign/validate.
11. **Generation** — author PDFs from scratch (layout engine).
12. **JS / Actions** — execute embedded JavaScript (form calc, doc actions).
13. **Runtime** — native (C/C++/Rust/Swift), Python, Node, **Browser/WASM**, Cloud.

---

## 3. The Two Surfaces of `pdf_editor` (current architecture)

### 3.1 Native (macOS 15, Swift SPM)
- **Reader/renderer:** Apple **PDFKit** (`PDFDocument`/`PDFPage`/`PDFView`).
- **OCR:** Apple **Vision** `VNRecognizeTextRequest` (on-device, Neural Engine).
- **Static-region detection:** `Sources/PDFEditorCore/StaticRegionDetector.swift` + custom
  `PDFVectorStreamParser.swift` (conservative, review-first).
- **Safety:** `PDFImpactValidator.swift`, `DocumentDiff.swift`, `SessionRecoveryStore.swift`
  (fail-closed, undo/recover).
- **Contracts:** `SharedContracts.swift`, `DocumentSessionContracts.swift` (provider-neutral).
- **Benchmarks:** `benchmark/PDFKitBenchmark.swift`, `PDFKitWidgetBenchmark.swift`.

### 3.2 Web (browser, vanilla JS modules)
- **Reader/renderer:** **PDF.js 4.2.67** — vendored in `web/vendor/pdfjs/` with CDN fallback to
  `unpkg`/`jsdelivr` (see `web/app.js` `pdfjsRuntimeURLs`). Worker sourced locally.
- **Writer:** **pdf-lib 1.17.1** — vendored `web/vendor/pdf-lib/pdf-lib.min.js`.
- **Static-region detection (web twin of native):** `web/pdf-geometry-detector.mjs` derives
  candidates from the PDF.js **operator list** (path geometry) + text items — the browser
  equivalent of `PDFVectorStreamParser`/`StaticRegionDetector`.
- **Safety gate:** `web/pdf-contract-mutation-gate.mjs` — fail-closed *before* `pdf-lib` write
  (mirrors native `PDFImpactValidator`).
- **Preservation oracle:** `web/pdf-impact-validator.mjs` (independent outside-region compare).
- **Templates:** `web/pdf-template-*.mjs`, `web/template-match-benchmark.mjs`,
  `web/template-correction-benchmark.mjs` (privacy-first, encrypted store via `crypto.subtle`).
- **OCR on web:** **absent today.** Vision OCR is native-only; the browser has no OCR path yet.
- **Run model:** `python3 -m http.server 4173` → `open http://127.0.0.1:4173/web/`.

**Parity contract:** both surfaces emit the same serialized document/coordinate/candidate/edit
bundles (see `docs/audits/*-parity-evidence-2026-08-24.md`). Final provider adoption is
**evidence-gated** — no engine is "final" yet.

---

## 4. Ecosystem A — Native / Core Engines (C/C++/Rust/Swift/Apple/Java/PHP)

### 4.1 Apple / Swift / macOS
| Engine | License | Verdict for pdf_editor |
|---|---|---|
| **PDFKit** (Quartz) | Proprietary (free w/ Apple OS) | ✅ Primary native viewer/annotator/AcroForm-fill. ❌ No XFA, no OCR, no JS exec, no true content edit, weak signing, fidelity good-not-Acrobat. |
| **CGPDF** (Quartz) | Proprietary | ✅ Highest-fidelity native renderer + raw COS read. The rasterization step before Vision OCR. No writer. |
| **Vision** `VNRecognizeTextRequest` | Proprietary | ✅ **The project's OCR today** — offline, on-device, Neural Engine. Pair with CGPDF rasterization. Image-only (blind to text layer). |
| **VisionKit** | Proprietary | Camera-scan glue (iOS-focused). Minor relevance. |

**Apple stack summary:** PDFKit = convenient high-level shell; CGPDF = faithful low-level
renderer/COS reader; Vision = the OCR bolted on after rasterizing. None edit content, run JS, or
do XFA.

### 4.2 Core C/C++ engines
| Engine | Lang | License | Key strengths | Key weaknesses | Verdict |
|---|---|---|---|---|---|
| **PDFium** (Google) | C++ | **Apache-2.0** | Reference rendering; AcroForm **+ XFA**; JS exec (V8); strong text/layout. Powers Chrome. | Not an editor/generator; building is heavy; signing workable but not first-class. | ⭐ **Bundle for XFA/JS/fidelity/editing fallback** — only permissive reference engine. |
| **MuPDF / Artifex** (mutool, PyMuPDF) | C | **AGPL-3.0 / commercial** | Best all-round open toolkit: render+extract+edit+generate, tiny footprint. | AGPL (pay for closed source); weak XFA; signing maturing. | ⭐ If AGPL acceptable or Artifex licensed — edit+generate+extract in one lib. |
| **qpdf** | C++ | **Apache-2.0** | Best permissive structural tool: split/merge/encrypt/linearize/repair. | No render/text/edit of content. | ✅ Already used; keep for sanitize/merge/encrypt. |
| **Poppler** (pdftotext etc.) | C++ | **GPL-2.0+** | Best free text+render on Linux; great CLI. | GPL → unusable in proprietary Mac app; no edit/forms/JS. | ⚠️ Local/benchmark only; **never link into the shipped app**. |
| **libharu** | C | zlib/libpng | Tiny permissive generator. | Write-only; aging. | Optional for generation. |
| **PoDoFo** | C++17 | LGPL (lib)/GPL (tools) | Full read/modify C++ API. | No renderer; no XFA; partial forms/signing. | Pair with PDFium/MuPDF if C++ edit needed. |
| **PDF-Writer** (Hummus) | C++ | **Apache-2.0** | Permissive high-throughput create/merge (Node bindings = muhammara). | No render/OCR; partial forms/sign. | ✅ Server-side creation. |
| **Ghostscript** | C | **AGPL-3.0 / commercial** | PS/PDF interpret, PDF/A, print. | AGPL; large. | Local/benchmark; not for app. |

### 4.3 Commercial native
| Engine | License | Note |
|---|---|---|
| **DynaPDF** | Commercial (royalty-free tiers) | Best pure generator + signing + forms (partial XFA). |
| **Foxit PDF SDK** | Commercial | Near-Acrobat parity: XFA, JS, edit, sign, OCR add-on. |
| **Quick PDF Library / Debenu** (Foxit-owned) | Commercial | 900+ fn API, royalty-free. |
| **Apryse / PDFTron**, **Nutrient / PSPDFKit** | Commercial | Own engines, excellent macOS/iOS + **web/WASM** support (see §6). |

### 4.4 Java / PHP / Rust (completeness)
- **Apache PDFBox** (Java, Apache-2.0): full read/write/forms/sign; rendering below native engines. ✅ JVM apps.
- **OpenPDF** (Java, LGPL/MPL): iText-5 descendant; generation/edit/sign; no render.
- **iText 7/8** (Java/.NET, AGPL/commercial): top-tier generation/signing/PDF-A; no render.
- **TCPDF** (PHP, LGPLv3): server-side generation; write-only. **mPDF** (PHP, GPL): HTML/CSS→PDF.
- **Rust:** `lopdf` (read/modify), `printpdf`/`genpdf` (generate), `pdf-extract` (text),
  `pdf-writer` (Typst's high-quality tagged-PDF writer), `pdfium`/`pdfium-render` bindings
  (bring PDFium render/forms/XFA into Rust). **No mature pure-Rust renderer** as of Aug 2026
  [verify].

### 4.5 Verification / standards
- **veraPDF** (Java, GPLv3+/MPLv2): the reference **PDF/A + PDF/UA** conformance validator. Use for
  archival/compliance claims — not an engine.

### 4.6 macOS-first verdict (native)
Start with **PDFKit** (view/annotate/AcroForm) + **Vision** (OCR) + **qpdf** (sanitize). **Bundle
PDFium** (Apache-2.0, permissive) to cover XFA, JavaScript, higher fidelity, and editing/extraction
PDFKit can't do. Reach for **MuPDF** only if AGPL is acceptable or Artifex is licensed. **Never**
use Poppler in a proprietary Mac app (GPL). Buy **Foxit/Apryse/Nutrient/DynaPDF** when XFA+editing
+signing+support are core revenue.

---

## 5. Ecosystem B — Python

| Library | License | Role | Verdict |
|---|---|---|---|
| **PyMuPDF** (`fitz`) | AGPL-3.0 / commercial | Render+extract+edit+forms+annotations, fast (MuPDF C core). | ⭐ Best all-rounder; AGPL blocks closed source. |
| **pypdf** | BSD-3 | Split/merge/rotate/encrypt/fill (pure Py). | ✅ Permissive restructure; no render/extract. |
| **pypdfium2** | Permissive (PDFium BSD) | Fast render+text (geometry). | ✅ Permissive PDF→image/text. |
| **pdfminer.six** | MIT | Precise coordinate text/layout parser. | ✅ Foundation for extraction. |
| **pdfplumber** | MIT | Ergonomic chars/lines/rects + tables. | ✅ Best permissive extraction layer. |
| **pdfrw** | MIT | Read/write (legacy). | ❌ Dead since 2017; migrate. |
| **borb** | AGPL/commercial | Pure-Py read/create/edit/**sign**. | Niche all-in-one; small team. |
| **Camelot** | MIT | **Table extraction** (lattice/stream). Revived **2.0.0 (2026)** on playa-pdf. | ⭐ Best structured tables. |
| **tabula-py** | MIT | Tables via Java PDFBox. | Needs JVM; maintenance cooled. |
| **pdf2image** | MIT | Poppler wrapper → PIL. | Needs Poppler. |
| **PyPDF2** | BSD-3 | Legacy. | ❌ Deprecated → use pypdf. |
| **ReportLab** | BSD-3 (+PLUS commercial) | Best Py generator (Platypus). | ✅ Generate from data. |
| **WeasyPrint** | GPL-3.0/commercial | HTML/CSS→PDF (real engine). | ✅ Best HTML→PDF; GPL. |
| **fpdf2** | LGPL-3.0 | Tiny generator. | ✅ Simple generation. |
| **pdfkit** (wkhtmltopdf wrapper) | MIT | HTML→PDF via dead WebKit. | ⚠️ Avoid; use WeasyPrint/Playwright. |
| **OCRmyPDF** | AGPL-3.0 | Scanned → searchable PDF/A (Tesseract+qpdf). | ⭐ Standard OCR pipeline. |
| **pikepdf** | MPL-2.0 | Safe structural restructure (qpdf bind). | ✅ Backbone of OCRmyPDF; library-friendly. |
| **tika-python** | Apache-2.0 | Universal multi-format extract (JVM). | Overkill for PDF-only. |
| **layoutparser** | Apache-2.0 | ML layout region detection (on images). | Research/ML pipelines. |
| **pdftext** (datalab) | Apache-2.0 | PyMuPDF-class speed, permissive. | ✅ Apache alternative to PyMuPDF. |
| **Surya / Marker** (datalab) | Custom non-commercial / paid | ML OCR+layout+table / PDF→Markdown. | ⭐ Best for scans+RAG; license-restricted. |

**Python verdict:** pick per task — `pypdf`/`pikepdf` for restructure, `PyMuPDF`/`pdfplumber`/`pdftext`
for extract, `Camelot` for tables, `ReportLab`/`WeasyPrint` for generate, `OCRmyPDF`+`Tesseract`
for OCR, `Surya`/`Marker` for ML-grade scans. This is the natural **local companion / CLI** stack for
`pdf_editor` (the Mac already has Tesseract + qpdf + poppler + mutool).

---

## 6. Ecosystem C — JavaScript / TypeScript / **Web** (the browser core)

### 6.1 What the project's web app uses today
- **PDF.js 4.2.67** (Mozilla, **Apache-2.0**) — reader/renderer. Vendored + CDN fallback.
  Current upstream is **v6.2.x (2026)** → upgrade candidate (v6 needs `Promise.withResolvers`;
  polyfill for old runtimes).
- **pdf-lib 1.17.1** (MIT) — writer. **Stalled since 2021.** No rasterization, no OCR, no
  signing, no semantic read.
- Geometry detector + fail-closed mutation gate (provider-neutral, mirrors native).

### 6.2 Browser-capable library catalog
| Library | License | Browser? | Role | Verdict for web |
|---|---|---|---|---|
| **pdf.js / pdfjs-dist** | Apache-2.0 | ✅ Both | Render + text/layout read. | ⭐ The web reader. Read-only (no write path). Upgrade 4.2.67 → 6.x. |
| **pdf-lib** | MIT | ✅ Both | Create/merge/fill/overlay. | ✅ Writer. Stalled; no render/OCR/sign. |
| **unpdf** | MIT | ✅ **Edge/worker** | Extraction + raster (pdf.js serverless build). | ⭐ For AI/RAG ingestion + edge; `extractTextItems` for geometry. |
| **Tesseract.js** | Apache-2.0 | ✅ WASM | **Browser OCR** (WASM build of Tesseract). | ⭐ The way to add web OCR offline/private. Heavy (~10MB+ wasm/data). |
| **muhammara** | MIT | ❌ Node only | Rich manipulation (Hummus C++). | Server-side only; not web. |
| **node-poppler** | MIT | ❌ Node only | Poppler wrapper (needs system bin). | Server/CLI only. |
| **pdfkit** | MIT | ⚠️ Node-first | Low-level generate. | Server generation. |
| **@react-pdf/renderer** | MIT | ✅ Both | Declarative React→PDF. | If UI-generation in React. |
| **pdfmake** | MIT | ✅ Both | Declarative tables. | Table-heavy generation. |
| **jsPDF** | MIT | ✅ Browser-first | Lightweight generate. | "Download as PDF" button. |
| **pdfme** | MIT | ✅ Both | Template-driven gen + designer. | Repeatable documents. |
| **pdf-parse v2** (mehmet-kozan) | MIT | ✅ Both | Maintained text+image+table extract. | Replace dead classic `pdf-parse`. |
| **pdfcpu** (Go) | Apache-2.0 | ⚠️ wasm/sidecar | Structural ops. | Via wasm wrapper (alitrack/pdfcpu) for browser structural work. |
| **Nutrient Web SDK** | Commercial | ✅ Browser | Full viewer/edit/annotate/sign/OCR-addon (PDFium-based). | Buy for turnkey in-browser edit+sign. |
| **Apryse / PDFTron WebViewer** | Commercial | ✅ Browser | 30+ format engine, edit/sign/redact. | Buy for multi-format + enterprise. |
| **PDFium WASM / mupdf.js** | Apache-2.0 / AGPL | ✅ WASM | Bring PDFium/MuPDF to browser. | Self-bundle for XFA/edit beyond pdf-lib [verify maturity]. |

### 6.3 The pdf.js vs pdf-lib split (reader vs writer) — concrete
- **pdf.js = READER.** Parses model, renders canvas, exposes text/geometry. **Cannot save changes.**
- **pdf-lib = WRITER.** Builds/mutates byte streams (pages, text, shapes, merge, fill, flatten).
  **Never renders or OCRs.**
- They are complementary, not competitors. Canonical web stack: *view+extract* with pdf.js/unpdf,
  *modify+generate* with pdf-lib. The project already does exactly this.

### 6.4 What the browser CAN and CANNOT do today
**Can (with pdf.js + pdf-lib):** render, select/search text, extract geometry, detect static
regions (operator-list), fill AcroForm fields, place reversible overlays, synthesize native text
fields after review, export + reopen-validate. **Cannot (without heavier engine):** rasterize→OCR
(no Tesseract.js yet), digital signing, true content editing, XFA, guaranteed PDF 2.0 fidelity, JS
execution. **Browser constraints:** no filesystem (sandboxed), WASM/worker limits, CDN fallback
needed for offline-resilience (project already pins 3 sources).

### 6.5 Web OCR options (the missing piece)
- **Tesseract.js** (WASM, Apache-2.0): run the *same* Tesseract 5 models locally in-browser.
  Privacy-preserving, offline. Best first step to give the web core OCR parity with native Vision.
- **Cloud OCR** (Textract / Google Document AI / Azure Document Intelligence / LlamaParse): via
  `fetch` from the web app — but breaks the local-first privacy posture; needs a native/companion
  hand-off or explicit user opt-in.
- **Surya / Marker / EasyOCR / PaddleOCR:** no first-class browser build (heavy ML runtimes);
  feasible only via ONNX/WASM experiments or server-side. [verify]
- **Recommended web OCR path:** Tesseract.js for offline/private; defer ML-grade (Surya) to the
  native companion or a local server.

---

## 7. Ecosystem D — OCR / Table / Layout / Document Intelligence

### 7.1 Local / offline OCR
| Tool | License | Note |
|---|---|---|
| **Tesseract 5.5.x** | Apache-2.0 | LSTM; ~100+ langs (tessdata_best/fast); CPU; fully offline. **Installed here (5.5.0).** |
| **Tesseract.js** | Apache-2.0 | WASM port → browser OCR. |
| **PaddleOCR** | Apache-2.0 | Strong multilingual ML OCR (PaddlePaddle); server/Python; no browser build. |
| **EasyOCR** | Apache-2.0 | Easy ML OCR (PyTorch); no browser build. |
| **kraken** | Apache-2.0 | Trainable OCR (historical/scripts). |
| **OCR-D / ocrd** | Various (FOSS) | Modular OCR pipeline framework. |
| **SimpleOCR** | Proprietary (free tier) | Legacy desktop. |

### 7.2 Scanned-PDF → searchable pipeline
- **OCRmyPDF** (AGPL-3.0): deskew/rotate/language/PDF-A + Tesseract + qpdf. **The standard.** Not
  installed here (can `pip install`).

### 7.3 Cloud OCR / doc-intel (privacy tradeoff explicit)
- **AWS Textract**, **Google Document AI**, **Azure AI Document Intelligence**, **ABBYY**,
  **Mathpix**, **LlamaParse** (LlamaIndex). High accuracy + structure, but **send document off-device**
  → incompatible with local-first posture unless user-opt-in/companion-mediated.

### 7.4 Layout + table + ML models
| Tool | License | Strength |
|---|---|---|
| **layoutparser** | Apache-2.0 | ML region detection on page images. |
| **LayoutLM / LayoutLMv3**, **DiT** (HF) | Apache-2.0 / MIT | Document understanding (text+layout). |
| **Table Transformer** (HF) | Apache-2.0 | Cell-level table structure recovery. |
| **deepdoctection** | Apache-2.0 | Pipeline orchestration for layout/table/OCR. |
| **Camelot / Tabula** | MIT | Deterministic table pull (see §5). |
| **unstructured.io** | MIT | RAG partition orchestration. |
| **Marker** (datalab) | Custom non-commercial/paid | PDF→Markdown (tables/equations). ⭐ RAG. |
| **Nougat** (Meta) | CC-BY-4.0 | Math/scientific OCR→LaTeX/Markdown. |
| **Surya** (datalab) | Custom non-commercial/paid | Unified OCR+layout+reading-order+table (VLM). ⭐ Scans. |
| **GOT-OCR2, InternVL, Donut, TrOCR, DocTR, MinerU, olmOCR** | Mixed | Modern 2023-2026 OCR/parsing models. |

### 7.5 OCR / table verdict
- **Privacy-first local stack:** Tesseract 5 + OCRmyPDF (CLI/companion) or **Tesseract.js** (web);
  **Surya/Marker** for ML-grade scans on a local server/companion.
- **Best tables:** Camelot (deterministic) → Table Transformer / Surya (ML) for messy layouts.
- **Best math/scientific:** Nougat / Marker / Mathpix.
- **Cloud worth it only when:** rare languages, messy scans at scale, or structured form extraction
  where you explicitly accept the privacy cost (user opt-in / companion mediation).

---

## 8. Unified Feature Matrix (★ = strong, ◐ = partial, ✗ = none)

| Engine / Lib | Parse | Text | Layout | Tables | OCR | Render | Edit | AcroForm | XFA | Annot | Sign | Gen | JS | Runtime |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| PDFKit | ◐ | ★ | ◐ | ✗ | ✗ | ★ | ◐ | ★ | ✗ | ★ | ◐ | ◐ | ✗ | Native (Apple) |
| CGPDF | ★ | ✗ | ✗ | ✗ | ✗ | ★ | ✗ | ✗ | ✗ | ✗ | ✗ | ◐ | ✗ | Native (Apple) |
| Vision | ✗ | ✗ | ✗ | ✗ | ★ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | Native (Apple) |
| PDFium | ★ | ★ | ★ | ✗ | ✗ | ★ | ◐ | ★ | ★ | ★ | ◐ | ✗ | ★ | Native/WASM |
| MuPDF | ★ | ★ | ★ | ✗ | ✗ | ★ | ★ | ★ | ◐ | ★ | ◐ | ★ | ◐ | Native/WASM |
| qpdf | ★ | ✗ | ✗ | ✗ | ✗ | ✗ | ◐ | ◐ | ✗ | ✗ | ◐ | ✗ | ✗ | Native |
| Poppler | ★ | ★ | ◐ | ✗ | ✗ | ★ | ✗ | ◐ | ✗ | ◐ | ◐ | ✗ | ✗ | Native (GPL) |
| PyMuPDF | ★ | ★ | ★ | ★ | ✗ | ★ | ★ | ★ | ◐ | ★ | ◐ | ★ | ◐ | Python |
| pypdf | ★ | ◐ | ✗ | ✗ | ✗ | ✗ | ★ | ★ | ✗ | ◐ | ◐ | ✗ | ✗ | Python |
| pdfplumber | ★ | ★ | ★ | ★ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | Python |
| Camelot | ✗ | ◐ | ✗ | ★ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | Python |
| OCRmyPDF | ✗ | ✗ | ✗ | ✗ | ★ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | Python/CLI |
| ReportLab | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ★ | ✗ | ◐ | ◐ | ★ | ✗ | Python |
| pdf.js | ★ | ★ | ★ | ◐ | ✗ | ★ | ✗ | ◐ | ✗ | ★ | ✗ | ✗ | ✗ | **Browser** |
| pdf-lib | ★ | ◐ | ✗ | ✗ | ✗ | ✗ | ★ | ★ | ✗ | ◐ | ✗ | ★ | ✗ | **Browser** |
| Tesseract.js | ✗ | ✗ | ✗ | ✗ | ★ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | **Browser/WASM** |
| Nutrient/Apryse | ★ | ★ | ★ | ★ | ◐ | ★ | ★ | ★ | ★ | ★ | ★ | ★ | ★ | **Browser/commercial** |

---

## 9. Licensing Quick-Reference

- **Permissive / safe for proprietary (no copyleft):** PDFium (Apache-2.0), qpdf (Apache-2.0),
  PDF-Writer (Apache-2.0), pypdf (BSD-3), pdfminer.six (MIT), pdfplumber (MIT), pypdfium2
  (permissive), pdftext (Apache-2.0), pdf-lib (MIT), pdf.js (Apache-2.0), Tesseract/Tesseract.js
  (Apache-2.0), Camelot/tabula-py (MIT), pikepdf (MPL-2.0, library-friendly), ReportLab (BSD-3),
  libharu (zlib), PDFBox (Apache-2.0), TCPDF (LGPLv3), fpdf2 (LGPL-3.0), PoDoFo (LGPL lib).
- **Copyleft / commercial-restricted (requires care or payment):** PyMuPDF (AGPL), MuPDF
  (AGPL), Ghostscript (AGPL), OCRmyPDF (AGPL), WeasyPrint (GPL), borb (AGPL), **Poppler (GPL —
  blocks proprietary)**, Surya/Marker (custom non-commercial), iText (AGPL), mPDF (GPL), veraPDF
  (GPL/MPL).
- **Commercial (no copyleft, per-seat/OEM):** DynaPDF, Foxit SDK, Quick PDF Library, Apryse,
  Nutrient, Artifex (MuPDF/GS), ABBYY, Mathpix.
- **Apple frameworks (PDFKit/CGPDF/Vision):** proprietary but free *inside Apple-distributed apps*;
  Apple-only, no source access.

**Decision rule for pdf_editor:** keep the shipped app on Apache-2.0/MIT/BSD/MPL + Apple frameworks.
Avoid GPL (Poppler) in the binary. Treat AGPL (MuPDF/PyMuPDF/OCRmyPDF/WeasyPrint) as "commercial
license or keep out of the distributed product." Bundle PDFium (Apache-2.0) for the fidelity/XFA/JS
gap. Add Tesseract.js (Apache-2.0) for web OCR without license risk.

---

## 10. Recommendations for `pdf_editor` (both surfaces)

### 10.1 Native
1. **Keep PDFKit + Vision + qpdf** as the free baseline (view, OCR, sanitize).
2. **Prototype bundling PDFium** (Apache-2.0) behind the existing provider-neutral contract to
   close XFA / JavaScript / higher-fidelity / editing gaps — this is the highest-leverage,
   license-clean move.
3. **Benchmark MuPDF** only if AGPL/commercial is acceptable (it would collapse render+edit+extract
   into one engine).
4. Use the **local Python stack** (Tesseract 5.5 + qpdf + poppler/mutool) as the benchmark oracle and
   a local companion/CLI plane (machine already has them).

### 10.2 Web
1. **Upgrade pdf.js 4.2.67 → 6.x** (with `Promise.withResolvers` polyfill) — current, security,
   performance. Keep the 3-source CDN/local fallback.
2. **Add Tesseract.js** to give the browser core offline/private OCR parity with native Vision
   (privacy-first, no cloud). This is the single biggest web-capability gap today.
3. **Keep pdf-lib** as writer but track its stall; evaluate **unpdf** for edge/extraction and
   **pdfcpu-wasm** for structural ops if needed.
4. **For in-browser edit/sign/XFA beyond pdf-lib**, either (a) hand off to the native companion, or
   (b) evaluate a commercial WASM engine (Nutrient/Apryse) or a self-bundled PDFium/MuPDF WASM build
   [verify maturity].
5. **Maintain the fail-closed mutation gate** (`pdf-contract-mutation-gate.mjs`) — it is the
   architectural equalizer between surfaces; do not let a new engine bypass it.

---

## 11. Further Exploration Areas (scoped, with open questions + experiments)

These are the explicit next investigations the current research does **not** close. Each lists the
question, why it matters, and a concrete experiment.

1. **Web OCR parity (highest priority).**
   - *Q:* Can Tesseract.js hit Vision's accuracy on the project's fixture corpus, and at what wasm
     size/latency?
   - *Exp:* Add Tesseract.js to `web/`, rasterize fixtures via pdf.js canvas, OCR, and compare
     text-layer fidelity vs native Vision on the 24-case template corpus; measure wasm download +
     first-paint latency.

2. **PDFium WASM feasibility for the browser.**
   - *Q:* Is a maintainable PDFium WASM build viable to bring XFA/JS/editing to the web without a
     commercial SDK?
   - *Exp:* Prototype `pdfium`/`pdfium-render` WASM in a standalone page; measure bundle size,
     XFA render, form-fill round-trip vs pdf-lib.

3. **pdf.js 6.x upgrade + fidelity regression.**
   - *Q:* Does upgrading 4.2.67 → 6.x change text/geometry extraction such that the existing
     `pdf-geometry-detector` or parity tests break?
   - *Exp:* Branch upgrade, run `Tests/web_editor_workflow_test.mjs` + parity audits; diff.

4. **ML-grade OCR/scan conversion (Surya/Marker) on a local companion.**
   - *Q:* For messy/scanned docs, does Surya/Marker beat Tesseract enough to justify a local server
     or native companion path? License cost?
   - *Exp:* `pip install marker-pdf/surya-ocr`, run on scanned fixtures, compare vs Tesseract 5.5;
     check datalab commercial license terms.

5. **Table extraction in-browser vs companion.**
   - *Q:* Where should table recovery live — browser (Camelot-equivalent via Table Transformer WASM)
     or companion (Camelot/Python)?
   - *Exp:* Benchmark Camelot 2.0 (lattice/stream) on the Form 6 + public-AcroForm corpus; assess a
     WASM Table Transformer port.

6. **Digital signatures across surfaces.**
   - *Q:* How to sign (PKCS#7) locally without a commercial SDK? pikepdf/qpdf preserve; who creates?
   - *Exp:* Prototype signing with `pikepdf`+`cryptography` (companion) and measure what the web
     `crypto.subtle` + a WASM signer would need.

7. **XFA reality on the actual corpus.**
   - *Q:* Do any fixtures use XFA? If yes, PDFKit/mupdf/pdf-lib cannot fill them — PDFium or Foxit
     required.
   - *Exp:* Scan fixture manifests for XFA markers; if present, scope a PDFium-bundled fill path.

8. **Provider-neutral contract extension for a new engine.**
   - *Q:* When PDFium/MuPDF WASM is added, what new contract fields are needed (XFA widgets, JS
     actions, signature objects) beyond the current document/coordinate/candidate/edit bundles?
   - *Exp:* Draft contract diff; add negative tests in `pdf-contract-mutation-gate.mjs`.

9. **PDF/A + accessibility conformance.**
   - *Q:* Can the export claim PDF/A or PDF/UA? veraPDF validation of current pdf-lib output.
   - *Exp:* Run veraPDF (or `pdfa` check) on exported fixtures; fix tagging gaps.

10. **Edge/serverless extraction path.**
    - *Q:* For a hosted tier, is `unpdf` (edge) better than `node-poppler` (fidelity) than
      `pypdfium2`?
    - *Exp:* Benchmark the three on a sample set for text+geometry accuracy and cold-start cost.

---

## 12. Verification Caveats & Sources

- **Local inventory:** verified by direct shell inspection on 2026-08-24 (versions above).
- **Library facts:** verified by research agents against GitHub releases, PyPI, npm, and official
  docs on 2026-08-24/25. Versions for **borb, pypdfium2, pdftext, Surya, Marker, layoutparser** could
  not be pinned to an exact release and are flagged **[verify]** — re-check at integration time.
- **Vendor benchmarks** (OCR/table accuracy scores) are project-reported, not independently
  reproduced here.
- **Primary sources consulted:** github.com repos (pymupdf, py-pdf/pypdf, pdfminer.six, jsvine/
  pdfplumber, camelot-dev, ocrmypdf, ArtifexSoftware/mupdf, qpdf/qpdf, poppler, pdfium, libharu,
  podofo, galkahana/PDF-Writer, Hopding/pdf-lib, mozilla/pdf.js, julianhille/MuhammaraJS, unjs/unpdf,
  datalab-to/*, tesseract-ocr, Vespa/Layout-Parser, huggingface Transformers, apryse/nutrient docs),
  PyPI, npm, Apple Developer Documentation (PDFKit/CGPDF/Vision), verapdf.org.
- **Existing project docs this builds on:** `docs/open-source-landscape.md`,
  `docs/pdf-engine-comparison.md`, `docs/pdf-feature-frontier.md`,
  `docs/cross-project-document-intelligence-exploration.md`, `docs/capability-matrix.md`.
- **This document is research/evidence, not a committed decision.** Final provider adoption in
  `pdf_editor` remains evidence-gated per `README.md` and `task_plan.md`.
