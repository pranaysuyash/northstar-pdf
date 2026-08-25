# Local System PDF Tooling — Full Crawl (2026-08-25)

**Scope:** A practical full crawl of this Mac for *any* PDF-related tooling, binaries, libraries,
and vendored engines — both the **machine-wide installed toolchain** (package managers) and the
**`/Users/pranay/Projects` dev tree** (vendored engines, node_modules, Python venvs, bundled
`.app` frameworks). Companion to `docs/pdf-ecosystem-deep-research-2026-08-25.md` (the online
catalog). This doc records **what is actually present on disk right now**.

**Crawl method / exclusions (be explicit):**
- ✅ Package managers: Homebrew (formulae + casks), system `pip`, managed venv, npm globals
  (system + managed node), nvm/pyenv/conda, cargo, gem, go, docker.
- ✅ `/Users/pranay/Projects` (all top-level dirs, node_modules, Python venvs, vendored engines,
  bundled `.app` frameworks).
- ⚠️ **Excluded for speed/permissions:** `/System`, `/private`, `/Library` system frameworks,
  network/iCloud volumes, and other user homes. Browsers (Chrome/Firefox) were listed but their
  internal PDFium/PDF.js bundles were *not* extracted (they are well-known and version-locked to
  the browser). The Projects `site-packages` loop hit a timeout (exit 137) on the last step; the
  re-run enumeration below completes it.

---

## 1. Machine-wide Installed Toolchain (package managers)

### 1.1 Homebrew formulae (PDF/OCR-relevant)
| Package | Version (installed) | License | Role |
|---|---|---|---|
| **poppler** | 26.08.0 | GPL-2.0+ | pdftotext/pdfinfo/pdftoppm/pdfimages/pdftocairo — text + raster. |
| **qpdf** | 12.4.0 | Apache-2.0 | Structural transform, encrypt/decrypt, linearize. |
| **mupdf-tools** | 1.28.2 | AGPL-3.0/commercial | mutool — render+edit+extract CLI. |
| **tesseract** | 5.5.0 | Apache-2.0 | OCR engine (LSTM). |
| **tesseract-lang** | (lang packs) | Apache-2.0 | Tesseract language data. |
| **leptonica** | — | BSD-2 | Image preprocessing (Tesseract dep). |
| **imagemagick** | 7.x | ImageMagick | Image convert/preprocess (`magick`, not `convert`). |
| **cairo / pango / freetype / libpng / libtiff** | — | mixed (permissive) | Graphics/font/image deps used by poppler/mupdf/WeasyPrint. |

**Not installed (confirmed absent):** ghostscript, gs, ocrmypdf, pdftk, pdfium (formula),
podofo (formula), libharu (formula), wkhtmltopdf, weasyprint (formula), reportlab (formula).
Homebrew **casks**: none installed (no cask-managed PDF app).

### 1.2 Python
- **System `/usr/bin/python3` pip:** `Pillow 11.3.0`, `PyPDF2 3.0.1` (⚠️ deprecated — superseded by `pypdf`).
- **Managed venv** (`~/.workbuddy-ai/binaries/python/3.13.12`): no PDF packages installed.
- No `pyenv`, no `conda`, no other `pip` PDF packages at the user level.

### 1.3 Node / others
- **npm globals:** none (system `/opt/homebrew/bin/npm` and managed node 22 — no global PDF pkgs).
- No `nvm`. No `cargo` PDF bins. No `gem` PDF gems. No `go` PDF bins. No matching `docker` images.

**Takeaway:** the machine-wide *global* PDF stack is exactly the brew/pdf set above + system
PyPDF2/Pillow. The real density of PDF tooling lives **inside Projects venvs/node_modules** (§2).

---

## 2. `/Users/pranay/Projects` — Vendored / Per-Project PDF Tooling

This is where "a lot of stuff" actually is. 290+ top-level project dirs; the PDF-relevant ones:

### 2.1 PDF engines vendored in node_modules / apps
| Project | PDF lib found | Version | Note |
|---|---|---|---|
| **pdf_editor** (this repo) | `web/vendor/pdf-lib` + `web/vendor/pdfjs` | pdf-lib 1.17.1, pdf.js 4.2.67 | The product under research (vendor copy). |
| **SentinelTwin** | `node_modules/.pnpm/pdf-lib@1.17.1` | pdf-lib **1.17.1** | Same pinned version as pdf_editor (pnpm). |
| **travel_agency_agent/frontend** | `node_modules/.pnpm/pdfjs-dist@5.7.284` | pdf.js **5.7.284** | **Newer than pdf_editor's 4.2.67** — upgrade candidate reference. |
| **orbitcover-d2c** | `node_modules/pdfkit` | pdfkit | Node PDF generation. |
| **oc-mobile** | `node_modules/pdfkit` | pdfkit | Node PDF generation. |
| **extracted_forms/signkit-macos-arm64** | `SignKit.app/Contents/Frameworks/pymupdf` | PyMuPDF (framework) | **SignKit.app bundles PyMuPDF** as a macOS framework. |

### 2.2 Python PDF packages installed across Projects venvs
Versions captured from `site-packages`. ⚠️ = licensing flag (AGPL) for closed-source use.

| Project / venv | PDF-related packages (version) | Highlights |
|---|---|---|
| **AIMLGlossary/venv** | Pillow 11.1.0, ReportLab 4.3.0 | generation only. |
| **Data_Science/…/image_border/backend/venv** | PyPDF2 3.0.1 ⚠️deprecated, pikepdf 10.0.2 (MPL), Pillow 11.0.0, ReportLab 4.4.5 | structural + gen. |
| **Data_Science/…/proj6/signature-extractor-app/.venv** | pikepdf 10.0.0, Pillow 12.0.0, pypdf 5.4.0, **pypdfium2 5.0.0** (PDFium, Apache) | signature extraction; uses **PDFium**. |
| **Data_Science/…/proj6/signature-extractor-app/venv** | **PyMuPDF 1.26.5** ⚠️AGPL, pikepdf 10.0.0, pypdf 5.4.0, **pypdfium2 5.0.0**, ReportLab 4.4.4 | duplicate venv w/ **PyMuPDF + PDFium**; has `pdf/pdfium_runtime.py` (PDFium Qt native crash notes). |
| **LLM/rag/venv** | pdf2image 1.17.0, pdfminer.six 20250327, pdfplumber 0.11.6, pikepdf 9.7.0, Pillow 11.2.1, pypdf 5.4.0, PyPDF2 3.0.1 ⚠️, **pypdfium2 4.30.1** (PDFium) | **RAG ingestion stack**: plumber + PDFium + pdf2image. |
| **LLM/audio/venv_audio** | pypdf 5.1.0 | minor. |
| **medpiper/insurance_app/.local-tools/surya-eval** | **surya 0.21.1** ⚠️(non-commercial license), pypdfium2 5.9.0 | **Surya OCR** eval env (ML OCR). |
| **medpiper/insurance_app/venv** | **PyMuPDF 1.28.0** ⚠️AGPL, pymupdf4llm 1.28.0, pdfminer.six 20260107, pdfplumber 0.11.10, Pillow 12.3.0, pypdfium2 5.11.0, tabulate | insurance PDF → Markdown/LLM (PyMuPDF + **pymupdf4llm** + PDFium). |
| **metaextract/.venv.bak** | pypdf 6.5.0, Pillow 12.0.0, pillow_heif | document-intel project; uses pypdf. |
| **oc-mobile/apps/extract-bridge/.venv** | **PyMuPDF 1.27.2.3** ⚠️AGPL | OCR/extract bridge (PyMuPDF). |
| **orbitcover-d2c/.venv** | **PyMuPDF 1.27.2.3** ⚠️AGPL | PyMuPDF + pdfkit (Node). |
| **pranay/.venv** | pypdf 6.14.2 | current pypdf. |
| **udemy/…** | tabulate (not PDF) | n/a. |

### 2.3 Cross-project themes (why this matters)
- **PyMuPDF is everywhere (AGPL).** Installed in orbitcover-d2c, oc-mobile extract-bridge,
  Data_Science signature-extractor-app, medpiper, **and bundled inside SignKit.app**. If any of
  these ship closed-source, they need an **Artifex commercial license** — this is a real license
  exposure across the user's portfolio, not just pdf_editor.
- **PDFium is already present (permissive).** Via `pypdfium2` in LLM/rag, Data_Science
  signature-extractor-app (x2), medpiper. PDFium (Apache-2.0) is the clean engine to standardize on
  for render/extract where PyMuPDF's AGPL is undesirable.
- **ML OCR already in use.** `surya` (medpiper surya-eval) — same datalab non-commercial license
  noted in the research doc; `pymupdf4llm` for PDF→Markdown/LLM.
- **Duplicate pdf-lib 1.17.1** in pdf_editor + SentinelTwin; **pdf.js 5.7.284** in
  travel_agency_agent is newer than pdf_editor's 4.2.67 (upgrade reference available locally).
- **Related sibling projects:** `metaextract`, `invoice-intelligence`, `invoice_exp`,
  `extracted_forms/signkit`, `Data_Science/…/signature-extractor-app` — all touch PDF
  parsing/extraction/signing. See existing `docs/cross-project-document-intelligence-exploration.md`.

### 2.4 PDF library inventory across the whole Projects tree (deduped)
| Library | License | Found in (Projects) | Where |
|---|---|---|---|
| **PyMuPDF / fitz** | AGPL-3.0/commercial | orbitcover-d2c, oc-mobile extract-bridge, Data_Science sig-extractor, medpiper, SignKit.app | venv + .app framework |
| **pypdfium2 (PDFium)** | Apache-2.0 | LLM/rag, Data_Science sig-extractor (x2), medpiper surya-eval | venv |
| **pypdf** | BSD-3 | LLM/rag, Data_Science sig-extractor, LLM/audio, metaextract, pranay, medpiper | venv |
| **PyPDF2** | BSD-3 | system, Data_Science image_border, LLM/rag | ⚠️ deprecated |
| **pdfplumber** | MIT | LLM/rag, medpiper | venv |
| **pdfminer.six** | MIT | LLM/rag, medpiper | venv |
| **pikepdf** | MPL-2.0 | Data_Science image_border, Data_Science sig-extractor (x2), LLM/rag | venv |
| **pdf2image** | MIT | LLM/rag | venv |
| **reportlab** | BSD-3 | AIMLGlossary, Data_Science image_border, Data_Science sig-extractor, LLM/rag | venv |
| **pillow** | HPND | many | venv + system |
| **pymupdf4llm** | AGPL-3.0 (inherits PyMuPDF) | medpiper | venv |
| **surya** | Custom non-commercial/paid | medpiper surya-eval | venv |
| **pdf-lib (JS)** | MIT | pdf_editor, SentinelTwin | vendored + node_modules |
| **pdf.js (JS)** | Apache-2.0 | pdf_editor (4.2.67), travel_agency_agent (5.7.284) | vendored + node_modules |
| **pdfkit (JS)** | MIT | orbitcover-d2c, oc-mobile | node_modules |

---

## 3. Browsers / Desktop Apps (listed, bundles not extracted)
Present in `/Applications`: **Google Chrome** (bundles PDFium), **Firefox** (bundles PDF.js),
**Safari** (PDFKit), **Foxit PDF Reader**, **Adobe Acrobat DC**, plus Adobe Creative Cloud apps
(InDesign bundles an Adobe PDF library / `pdfl`). These are the "invisible" PDF engines already on
the machine. Their internal binaries were not extracted (version-locked to the app; well-known).

---

## 4. Licensing Exposure Summary (actionable)
- **AGPL in shipped/portfolio code:** PyMuPDF (×5 projects + SignKit.app), pymupdf4llm, Surya.
  If any of these are distributed closed-source, an Artifex (PyMuPDF) or datalab (Surya) commercial
  license is required. **This is the single biggest finding of the crawl.**
- **Permissive & safe:** pypdfium2/PDFium, pypdf, pdfplumber, pikepdf, pdf2image, reportlab,
  pdf-lib, pdf.js, Pillow.
- **Deprecated:** PyPDF2 (3.0.1) in system + 2 Projects venvs → migrate to `pypdf`.

---

## 5. Recommended Next Steps (from the crawl)
1. **Inventory Artifex/datalab license obligations** across the 5 PyMuPDF + Surya installs before any
   of those projects ship — or swap PyMuPDF → `pypdfium2` (PDFium, Apache-2.0) where features allow.
2. **Standardize on PDFium (pypdfium2)** as the shared local render/extract engine — it is already
   installed in 3 places and is license-clean.
3. **Use travel_agency_agent's pdf.js 5.7.284** as the local upgrade reference for pdf_editor's
   pinned 4.2.67 (after the mutation-gate/parity re-tests in the research doc §11.3).
4. **Migrate PyPDF2 → pypdf** in system + the 2 venvs still on 3.0.1.
5. **Optional deeper crawl:** extract Chrome/Firefox/Adobe bundled PDFium/PDF.js/PDFL versions, and
   scan `/Library/Frameworks`, `~/Library/Frameworks`, and `/opt/homebrew/lib` for any stray dylibs
   (pdfium/mupdf/poppler) — not done here for speed.

---

## 6. Verification Notes
- Brew/system facts: direct shell inspection 2026-08-25.
- Projects enumeration: `find` over `/Users/pranay/Projects` (maxdepth 9–10), name-whitelist for
  pdf/mupdf/fitz/pike/pdfium/pdfjs/pdf-lib/pdfkit/surya; site-packages dist-info enumeration.
- The first Projects pass timed out (SIGTERM) on the final `site-packages` loop; §2.2 is the
  completed re-run and is authoritative.
- Not scanned: `/System`, `/private`, `/Library` (system), network/iCloud, other users.
