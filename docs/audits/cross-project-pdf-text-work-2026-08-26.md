# Cross-Project PDF, Text, and Document Processing Work

**Status:** Complete inventory of PDF/text/OCR work across all local projects
**Created:** 2026-08-26
**Scope:** All projects under /Users/pranay/Projects

## 1. Projects with PDF/Text/OCR Work

### 1.1 pdf_editor (Current Project)

**Location:** `/Users/pranay/Projects/pdf_editor`
**Status:** Active — 279 tests, 42 features, 38 libraries evaluated

| Component | Technology | Status |
|---|---|---|
| PDF reading/rendering | PDFKit (macOS) | ✅ Implemented |
| PDF field editing | PDFIncrementalFormWriter (custom) | ✅ Implemented |
| PDF text extraction | PDFKit + custom | ✅ Implemented |
| PDF OCR | Apple Vision | ✅ Implemented |
| PDF validation | qpdf, Poppler, pikepdf (CLI) | ✅ Implemented |
| PDF sanitization | qpdf + pikepdf (CLI) | ✅ Implemented |
| PDF signature detection | Custom (walkAcroFormModel) | ✅ Implemented |
| PDF XFA detection | Custom (XFAFormProcessor) | ✅ Implemented |
| PDF redaction | PDFContentStreamRedactor | ✅ Implemented |
| PDF batch processing | PDFBatchProcessor | ✅ Implemented |

### 1.2 invoice-intelligence

**Location:** `/Users/pranay/Projects/invoice-intelligence`
**Status:** Complete — full pipeline with 5 extraction methods

| Component | Technology | Status |
|---|---|---|
| PDF text extraction | fitz (PyMuPDF) + pdfplumber + pdftotext | ✅ Implemented |
| Image OCR | PaddleOCR + pytesseract | ✅ Implemented |
| Scanned PDF detection | Custom heuristic | ✅ Implemented |
| LLM extraction | OpenAI vision + text | ✅ Implemented |
| Pipeline routing | Hybrid router (scanned vs digital) | ✅ Implemented |
| Benchmarking | Cost, latency, accuracy, JSON validity | ✅ Implemented |

**Key finding:** invoice-intelligence uses a **cascade of PDF libraries**:
1. **fitz (PyMuPDF)** — primary PDF text extraction
2. **pdfplumber** — fallback for text extraction
3. **pdftotext (Poppler CLI)** — final fallback
4. **PaddleOCR** — image/scanned PDF OCR
5. **pytesseract** — fallback OCR

**This is exactly the pattern we should adopt** — multiple libraries with graceful fallback.

### 1.3 metaextract

**Location:** `/Users/pranay/Projects/metaextract`
**Status:** Complete — metadata extraction with provenance tracking

| Component | Technology | Status |
|---|---|---|
| EXIF extraction | Custom engine | ✅ Implemented |
| GPS extraction | Custom engine | ✅ Implemented |
| Mobile metadata | Custom engine | ✅ Implemented |
| Forensic metadata | Custom engine | ✅ Implemented |
| Provenance tracking | Custom (module_provenance) | ✅ Implemented |
| Sensitive field detection | Custom (PII detection) | ✅ Implemented |
| Shadow mode | Custom (parallel execution + diff) | ✅ Implemented |

**Key finding:** metaextract implements **provenance tracking** — recording which module produced each field. This is a pattern we should adopt for PDF extraction.

### 1.4 Data_Science/computer_vision/proj6 (SignKit)

**Location:** `/Users/pranay/Projects/Data_Science/computer_vision/proj6/signature-extractor-app`
**Status:** Complete — signature extraction and PDF placement

| Component | Technology | Status |
|---|---|---|
| Signature extraction | Computer vision (OpenCV) | ✅ Implemented |
| Signature cleaning | Image processing | ✅ Implemented |
| PDF placement | PDFKit | ✅ Implemented |
| Local-first processing | No cloud upload | ✅ Implemented |
| Signature vault | Local storage | ✅ Implemented |

**Key finding:** SignKit is a **local-first PDF signature tool** — exactly the pattern we need for our signature guard.

### 1.5 lenny

**Location:** `/Users/pranay/Projects/lenny`
**Status:** Experiment 1 — regex parsing

| Component | Technology | Status |
|---|---|---|
| Text parsing | Regex, LLM, Hybrid, NLP | 📝 Experiment 1 |
| Transcript analysis | 320 episodes | ✅ Dataset ready |

**Key finding:** lenny explores **multiple parsing strategies** — regex, LLM, hybrid, NLP. This is relevant to our text-run replacement feature.

### 1.6 AIMLGlossary

**Location:** `/Users/pranay/Projects/AIMLGlossary`
**Status:** Complete — multi-format document processing

| Component | Technology | Status |
|---|---|---|
| PDF processing | Multiple libraries | ✅ Implemented |
| DOCX processing | python-docx | ✅ Implemented |
| Image processing | PIL/OpenCV | ✅ Implemented |
| Text extraction | Multiple methods | ✅ Implemented |

### 1.7 commercial-pipeline

**Location:** `/Users/pranay/Projects/commercial-pipeline`
**Status:** Active — SignKit is first client

| Component | Technology | Status |
|---|---|---|
| SignKit client config | Product positioning | ✅ Implemented |
| Prospect tracking | CSV-based | ✅ Implemented |
| Outreach templates | Reusable | ✅ Implemented |

**Key finding:** commercial-pipeline links **SignKit** (signature extraction) to our PDF editor product line.

## 2. Cross-Project Patterns

### 2.1 Library Cascade Pattern (from invoice-intelligence)

```python
# invoice-intelligence pattern:
def extract_pdf_text(path):
    try:
        import fitz  # PyMuPDF — fastest
        doc = fitz.open(path)
        return "\n".join(page.get_text("text") for page in doc)
    except:
        try:
            import pdfplumber  # fallback
            with pdfplumber.open(path) as pdf:
                return "\n".join((page.extract_text() or "") for page in pdf.pages)
        except:
            # Final fallback: CLI tool
            proc = subprocess.run(["pdftotext", "-layout", str(path), "-"], ...)
            return proc.stdout
```

**Recommendation:** Adopt this cascade pattern for PDF text extraction in pdf_editor.

### 2.2 Provenance Tracking Pattern (from metaextract)

```json
{
  "extraction_info": {
    "provenance": {
      "module_provenance": {
        "text": "fitz",
        "fields": "PDFKit",
        "ocr": "Vision"
      }
    }
  }
}
```

**Recommendation:** Add provenance tracking to our DocumentInspection output.

### 2.3 Shadow Mode Pattern (from metaextract)

```json
{
  "extraction_info": {
    "shadow": {
      "fitz": { "text": "..." },
      "pdfplumber": { "text": "..." },
      "diff": { "matches": true }
    }
  }
}
```

**Recommendation:** Run multiple extraction methods in shadow mode to compare results.

### 2.4 Local-First Pattern (from SignKit)

- All processing happens locally
- No cloud upload by default
- User controls data flow
- Signature vault stored locally

**Recommendation:** Maintain this pattern for all PDF operations.

### 2.5 Hybrid Router Pattern (from invoice-intelligence)

```python
def route_pdf(path):
    base_text = extract_pdf_text(path)
    if is_probably_scanned(path, base_text):
        return "ocr_route"  # PaddleOCR + LLM
    else:
        return "text_route"  # fitz + LLM
```

**Recommendation:** Implement similar routing for our OCR fallback.

## 3. Libraries Used Across Projects

| Library | Projects Using | Language | License |
|---|---|---|---|
| **fitz (PyMuPDF)** | invoice-intelligence | Python | AGPL |
| **pdfplumber** | invoice-intelligence | Python | MIT |
| **pdftotext (Poppler)** | invoice-intelligence | CLI | GPL |
| **PaddleOCR** | invoice-intelligence | Python | Apache-2.0 |
| **pytesseract** | invoice-intelligence | Python | Apache-2.0 |
| **PDFKit** | pdf_editor, SignKit | Swift | Proprietary |
| **qpdf** | pdf_editor | CLI | Apache-2.0 |
| **pikepdf** | pdf_editor | Python | BSD |
| **OpenCV** | SignKit | Python | Apache-2.0 |
| **PIL/Pillow** | SignKit, AIMLGlossary | Python | MIT |

## 4. Recommendations for pdf_editor

### 4.1 Adopt invoice-intelligence's cascade pattern

```swift
// Current: PDFKit only
func extractText(from url: URL) -> String? {
    let document = PDFDocument(url: url)
    // ...
}

// Recommended: Multi-library cascade
func extractText(from url: URL) -> String? {
    // 1. Try fitz (fastest)
    if let text = tryFitzExtraction(url) { return text }
    
    // 2. Try pdfplumber (better tables)
    if let text = tryPdfplumberExtraction(url) { return text }
    
    // 3. Try Poppler CLI (most compatible)
    if let text = tryPopplerExtraction(url) { return text }
    
    // 4. Try Apple Vision (OCR fallback)
    if let text = tryVisionOCR(url) { return text }
    
    return nil
}
```

### 4.2 Adopt metaextract's provenance tracking

```swift
// Add to DocumentInspection
struct ExtractionProvenance {
    let textExtractor: String  // "PDFKit", "fitz", "Poppler"
    let fieldInspector: String  // "CGPDF", "MuPDF", "pikepdf"
    let ocrEngine: String?      // "Vision", "Tesseract"
    let confidence: Double
}
```

### 4.3 Adopt metaextract's shadow mode

```swift
// Run multiple extractors in shadow mode
func extractWithShadow(url: URL) -> (primary: String, shadow: String, diff: Bool) {
    let primary = extractWithPDFKit(url)
    let shadow = extractWithPoppler(url)
    let diff = primary != shadow
    return (primary, shadow, diff)
}
```

### 4.4 Adopt SignKit's local-first pattern

- All PDF processing stays local
- No cloud upload by default
- User controls data flow
- Evidence stored locally

### 4.5 Adopt invoice-intelligence's hybrid routing

```swift
// Route based on document type
func routeDocument(url: URL) -> ProcessingRoute {
    let inspection = inspect(url)
    if inspection.isScanned {
        return .ocr(engine: .vision)
    } else if inspection.hasAcroForm {
        return .form(writer: .incremental)
    } else {
        return .overlay(provider: .pdfkit)
    }
}
```

## 5. Transferable Concepts

| Concept | Source | Applicable to pdf_editor? |
|---|---|---|
| Library cascade | invoice-intelligence | ✅ Text extraction |
| Provenance tracking | metaextract | ✅ DocumentInspection |
| Shadow mode | metaextract | ✅ Validation |
| Local-first processing | SignKit | ✅ All operations |
| Hybrid routing | invoice-intelligence | ✅ OCR fallback |
| Benchmarking | invoice-intelligence | ✅ Performance testing |
| Sensitive field detection | metaextract | ✅ Privacy boundary |
| Module conflict detection | metaextract | ✅ Multi-oracle validation |

## 6. Evidence

- `/Users/pranay/Projects/invoice-intelligence/backend/app/services/text_extract.py` — cascade pattern
- `/Users/pranay/Projects/metaextract/docs/EXTRACTION_OBSERVABILITY.md` — provenance tracking
- `/Users/pranay/Projects/Data_Science/computer_vision/proj6/signature-extractor-app/PRODUCT.md` — local-first pattern
- `/Users/pranay/Projects/invoice-intelligence/backend/app/pipelines/registry.py` — hybrid routing
