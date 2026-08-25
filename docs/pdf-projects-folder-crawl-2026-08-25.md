# Projects Folder — PDF Tooling Inventory (2026-08-25)

**Scope:** PDF-related libraries, engines, vendored copies, Python venvs, and bundled `.app`
frameworks **inside `/Users/pranay/Projects` only**. Machine-wide package-manager tooling is
deliberately excluded here — see `docs/pdf-local-system-crawl-2026-08-25.md` for brew/system pip.
This is the "what's actually in my code" companion to the online catalog
(`docs/pdf-ecosystem-deep-research-2026-08-25.md`).

**Method:** `find` over `/Users/pranay/Projects` (maxdepth 9–10), name-whitelisting
pdf/mupdf/fitz/pike/pdfium/pdfjs/pdf-lib/pdfkit/surya; enumeration of `site-packages` +
`node_modules`; inspection of `.app/Contents/Frameworks`. The first pass timed out on the final
`site-packages` loop; the re-run enumeration is authoritative.

---

## 1. Per-Project PDF Inventory

### 1.1 JavaScript / TypeScript (node_modules or vendored)
| Project | PDF lib(s) | Version | Apparent use |
|---|---|---|---|
| **pdf_editor** (this repo) | `web/vendor/pdfjs` + `web/vendor/pdf-lib` | pdf.js **4.2.67**, pdf-lib **1.17.1** | The product: browser reader + writer. |
| **SentinelTwin** | `node_modules/.pnpm/pdf-lib@1.17.1` | pdf-lib **1.17.1** | Web PDF form-fill (same pin as pdf_editor). |
| **travel_agency_agent/frontend** | `node_modules/.pnpm/pdfjs-dist@5.7.284` | pdf.js **5.7.284** | Web PDF render — **newer than pdf_editor's 4.2.67** (local upgrade ref). |
| **orbitcover-d2c** | `node_modules/pdfkit` | pdfkit | Node PDF generation. |
| **oc-mobile** | `node_modules/pdfkit` | pdfkit | Node PDF generation. |

### 1.2 Python (per venv, versions from dist-info)
| Project / venv | PDF-related packages (version) | License flags |
|---|---|---|
| **AIMLGlossary/venv** | ReportLab 4.3.0, Pillow 11.1.0 | ReportLab BSD-3 |
| **Data_Science/…/image_border/backend/venv** | PyPDF2 3.0.1 ⚠️dep, pikepdf 10.0.2 (MPL), Pillow 11.0.0, ReportLab 4.4.5 | — |
| **Data_Science/…/proj6/signature-extractor-app/.venv** | pikepdf 10.0.0, pypdf 5.4.0, pypdfium2 5.0.0 (PDFium, Apache), ReportLab 4.4.4 | PDFium permissive |
| **Data_Science/…/proj6/signature-extractor-app/venv** | **PyMuPDF 1.26.5** ⚠️AGPL, pikepdf 10.0.0, pypdf 5.4.0, pypdfium2 5.0.0, ReportLab 4.4.4 | PyMuPDF AGPL |
| **LLM/audio/venv_audio** | pypdf 5.1.0, Pillow 10.4.0 | — |
| **LLM/rag/venv** | pdf2image 1.17.0, pdfminer.six 20250327, pdfplumber 0.11.6, pikepdf 9.7.0, pypdf 5.4.0, PyPDF2 3.0.1 ⚠️dep, pypdfium2 4.30.1 (PDFium) | PDFium permissive |
| **medpiper/insurance_app/.local-tools/surya-eval** | **surya 0.21.1** ⚠️(non-commercial), pypdfium2 5.9.0 (PDFium) | Surya restricted |
| **medpiper/insurance_app/venv** | **PyMuPDF 1.28.0** ⚠️AGPL, pymupdf4llm 1.28.0 ⚠️(inherits PyMuPDF), pdfminer.six 20260107, pdfplumber 0.11.10, pypdfium2 5.11.0 (PDFium), Pillow 12.3.0, tabulate | PyMuPDF/pymupdf4llm AGPL |
| **metaextract/.venv.bak** | pypdf 6.5.0, Pillow 12.0.0, pillow_heif | — |
| **oc-mobile/apps/extract-bridge/.venv** | **PyMuPDF 1.27.2.3** ⚠️AGPL | PyMuPDF AGPL |
| **orbitcover-d2c/.venv** | **PyMuPDF 1.27.2.3** ⚠️AGPL | PyMuPDF AGPL |
| **pranay/.venv** | pypdf 6.14.2 | — |
| **udemy/…** | tabulate (not PDF) | — |

### 1.3 Bundled PDF engine inside a shipped `.app`
| Path | Engine | Version | Note |
|---|---|---|---|
| **extracted_forms/signkit-macos-arm64/SignKit.app/Contents/Frameworks/pymupdf** | PyMuPDF | (framework) | SignKit.app **bundles PyMuPDF** as a macOS framework → AGPL obligation if distributed. |

---

## 2. Engine / License Spread (deduped across Projects)

| Engine | License | Count of installs in Projects | Where |
|---|---|---|---|
| **PyMuPDF / fitz** | **AGPL-3.0 / commercial** | **5** (+1 in SignKit.app) | orbitcover-d2c, oc-mobile extract-bridge, Data_Science sig-extractor (venv), medpiper, SignKit.app |
| **pypdfium2 (PDFium)** | Apache-2.0 | 4 | LLM/rag, Data_Science sig-extractor (×2), medpiper (×2 incl. surya-eval) |
| **pypdf** | BSD-3 | 6 | LLM/rag, Data_Science sig-extractor, LLM/audio, metaextract, pranay, medpiper |
| **pdfplumber** | MIT | 2 | LLM/rag, medpiper |
| **pdfminer.six** | MIT | 2 | LLM/rag, medpiper |
| **pikepdf** | MPL-2.0 | 4 | Data_Science image_border, Data_Science sig-extractor (×2), LLM/rag |
| **pdf2image** | MIT | 1 | LLM/rag |
| **reportlab** | BSD-3 | 4 | AIMLGlossary, Data_Science image_border, Data_Science sig-extractor, LLM/rag |
| **pillow** | HPND | many | ubiquitous |
| **PyPDF2** | BSD-3 | 2 | ⚠️ **deprecated** (system + Data_Science image_border + LLM/rag) |
| **pymupdf4llm** | AGPL-3.0 | 1 | medpiper |
| **surya** | Custom non-commercial/paid | 1 | medpiper surya-eval |
| **pdf-lib (JS)** | MIT | 2 | pdf_editor, SentinelTwin |
| **pdf.js (JS)** | Apache-2.0 | 2 | pdf_editor (4.2.67), travel_agency_agent (5.7.284) |
| **pdfkit (JS)** | MIT | 2 | orbitcover-d2c, oc-mobile |

---

## 3. Cross-Project Observations

1. **AGPL exposure is the headline.** PyMuPDF (×5 + SignKit.app framework), pymupdf4llm, and Surya
   are all copyleft/commercial-restricted. If any of these projects are distributed closed-source,
   they need an **Artifex (PyMuPDF)** and/or **datalab (Surya)** commercial license. This is a
   *portfolio-wide* risk, not just a pdf_editor concern.
2. **PDFium is already the de-facto permissive engine.** `pypdfium2` is installed in 4 places
   (LLM/rag, Data_Science sig-extractor ×2, medpiper). It is Apache-2.0 and could replace PyMuPDF
   for render/extract wherever AGPL is a problem.
3. **Version drift / reuse opportunities:**
   - `travel_agency_agent` runs **pdf.js 5.7.284** — a local, newer reference for pdf_editor's
     pinned **4.2.67** upgrade (re-test the geometry detector + parity gates first).
   - **pdf-lib 1.17.1** is duplicated in pdf_editor + SentinelTwin (fine — MIT, stalled upstream).
   - **PyPDF2 3.0.1** (deprecated) lingers in 2 Projects venvs → migrate to `pypdf`.
4. **Sibling PDF projects** (relevant to pdf_editor's document-intelligence roadmap — see
   `docs/cross-project-document-intelligence-exploration.md`): **metaextract** (pypdf extraction),
   **invoice-intelligence** / **invoice_exp**, **extracted_forms/signkit** (PyMuPDF signing),
   **Data_Science/proj6/signature-extractor-app** (PyMuPDF + PDFium; has a *PDFium-Qt native crash*
   history — `issue_review_pdfium_qt_native_crash_2026-08-12.md`), **medpiper** (PyMuPDF +
   pymupdf4llm + Surya → insurance PDF to LLM), **oc-mobile** (PyMuPDF extract bridge).

---

## 4. Reuse / Consolidation Opportunities for `pdf_editor`

- **Local upgrade reference exists:** borrow `travel_agency_agent`'s pdf.js 5.7.284 to validate the
  pdf_editor 4.2.67 → 6.x (or 5.7) bump before touching the CDN pins.
- **PDFium already on disk:** if the web/native companion needs higher-fidelity render or XFA, the
  `pypdfium2` (PDFium) installs prove it builds/runs locally — reuse instead of pulling a new dep.
- **Surya/Marker eval exists:** medpiper's `surya-eval` venv is a ready ML-OCR testbed for the
  pdf_editor OCR gap (web OCR parity experiment in the research doc §11.1).
- **Signature precedent exists:** SignKit.app + Data_Science signature-extractor-app are prior art
  for PDF signing/extraction in this portfolio — mine before building pdf_editor's signing path.

---

## 5. Recommendations (Projects-scoped)

1. **Audit Artifex + datalab license obligations** across the 5 PyMuPDF + Surya installs *before*
   any of those repos ship; or swap PyMuPDF → `pypdfium2`/PDFium where features allow.
2. **Migrate PyPDF2 → pypdf** in the 2 lingering venvs (deprecated since 2023).
3. **Pin pdf.js consistently** — adopt travel_agency_agent's 5.7.284 (or newer) in pdf_editor after
   regression tests.
4. **Centralize a shared PDF utility venv** (PDFium + pypdf + pdfplumber) to stop re-installing
   engines per project — reduces AGPL surface and version drift.
5. **Optional deeper pass:** extract SignKit.app's bundled PyMuPDF version, and diff the
   pdf.js/pdf-lib vendor pins across pdf_editor vs SentinelTwin vs travel_agency_agent for a
   single source-of-truth.

---

## 6. Verification Notes
- Data captured 2026-08-25 via `find` + `site-packages` enumeration over `/Users/pranay/Projects`.
- Versions read from `*.dist-info` / vendored copies; where a package had no dist-info (e.g.
  SignKit.framework) the engine is noted without a precise version.
- Excluded: machine-wide brew/system pip (see `pdf-local-system-crawl-2026-08-25.md`), `/System`,
  `/private`, `/Library` system, iCloud/network.
