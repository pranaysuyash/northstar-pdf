# PDF Features × Library Matrix

**Status:** Complete inventory of every PDF feature, evaluated against every available library
**Created:** 2026-08-26
**Scope:** Implemented features, planned features, and explorable future features
**Gate:** A-02, RG-001–RG-127

## 1. Implemented Features (42 total)

### 1.1 Reading & Rendering (8 features)

| # | Feature | Status | Current Provider | Best Alternative | Notes |
|---|---|---|---|---|---|
| F-001 | Open/import PDF | ✅ Implemented | PDFKit | MuPDF, PDFium | PDFKit works but has bugs |
| F-002 | Render pages | ✅ Implemented | PDFKit (PDFView) | MuPDF, PDFium | PDFKit tile crash on low-RAM iPads |
| F-003 | Page navigation | ✅ Implemented | PDFKit | MuPDF, PDFium | PDFKit adequate |
| F-004 | Zoom/scale | ✅ Implemented | PDFKit | MuPDF, PDFium | PDFKit adequate |
| F-005 | Rotation | ✅ Implemented | PDFKit | MuPDF, PDFium | PDFKit adequate |
| F-006 | Continuous view | ✅ Implemented | PDFKit | MuPDF, PDFium | PDFKit adequate |
| F-007 | Two-page view | ✅ Implemented | PDFKit | MuPDF, PDFium | PDFKit adequate |
| F-008 | Thumbnails | ✅ Implemented | PDFKit | MuPDF, PDFium | PDFKit adequate |

### 1.2 Text & OCR (6 features)

| # | Feature | Status | Current Provider | Best Alternative | Notes |
|---|---|---|---|---|---|
| F-009 | Extract text | ✅ Implemented | PDFKit | MuPDF, Poppler | Poppler best for extraction |
| F-010 | Search text | ✅ Implemented | PDFKit | MuPDF | PDFKit adequate |
| F-011 | Copy text | ✅ Implemented | PDFKit | MuPDF | PDFKit adequate |
| F-012 | OCR (English) | ✅ Implemented | Apple Vision | Tesseract, PaddleOCR | Vision is native, good quality |
| F-013 | OCR fallback | ✅ Implemented | Apple Vision | Tesseract CLI/WASM | Vision primary, Tesseract backup |
| F-014 | Text-run detection | ✅ Implemented | Custom (PDFVectorStreamParser) | MuPDF | Custom is fine |

### 1.3 Forms & Fields (9 features)

| # | Feature | Status | Current Provider | Best Alternative | Notes |
|---|---|---|---|---|---|
| F-015 | Inspect AcroForm | ✅ Implemented | PDFKit + CGPDF | MuPDF, pypdf | PDFKit has radio bugs |
| F-016 | Fill text fields | ✅ Implemented | PDFIncrementalFormWriter | MuPDF | Writer bypasses PDFKit |
| F-017 | Toggle checkboxes | ✅ Implemented | PDFIncrementalFormWriter | MuPDF | Writer bypasses PDFKit |
| F-018 | Select radio options | ✅ Implemented | PDFIncrementalFormWriter | MuPDF | Writer bypasses PDFKit (F-016 fixed) |
| F-019 | Choice/dropdown | ✅ Implemented | PDFIncrementalFormWriter | MuPDF | Writer bypasses PDFKit |
| F-020 | Field synthesis | ✅ Implemented | PDFKit + custom | MuPDF | Creates new widgets |
| F-021 | Direct text placement | ✅ Implemented | PDFKit + custom | MuPDF | Double-click placement |
| F-022 | Manual placement | ✅ Implemented | PDFKit + custom | MuPDF | User-directed placement |
| F-023 | Field lookup (O(1)) | ✅ Implemented | Custom (inspection cache) | MuPDF | Performance optimized |

### 1.4 Annotations & Overlays (5 features)

| # | Feature | Status | Current Provider | Best Alternative | Notes |
|---|---|---|---|---|---|
| F-024 | FreeText overlay | ✅ Implemented | PDFKit | MuPDF, pdf-lib | Reversible overlay |
| F-025 | Highlight | ✅ Implemented | PDFKit | MuPDF | Visual feedback |
| F-026 | Underline | ✅ Implemented | PDFKit | MuPDF | Visual feedback |
| F-027 | Evidence card | ✅ Implemented | Custom (SuggestionExplainer) | N/A | Shows WHY a suggestion exists |
| F-028 | Diff comparison | ✅ Implemented | PDFKit + custom | MuPDF | Visual diff of changes |

### 1.5 Security & Privacy (7 features)

| # | Feature | Status | Current Provider | Best Alternative | Notes |
|---|---|---|---|---|---|
| F-029 | Password open | ✅ Implemented | PDFKit | MuPDF, pypdf | PDFKit adequate |
| F-030 | Signature detection | ✅ Implemented | Custom (walkAcroFormModel) | MuPDF, pypdf | Refuses edit on signed docs |
| F-031 | XFA detection | ✅ Implemented | Custom (XFAFormProcessor) | MuPDF, pypdf | Refuses edit on XFA docs |
| F-032 | Sanitize metadata | ✅ Implemented | qpdf + pikepdf (CLI) | MuPDF | Strips XMP, empties /Info |
| F-033 | Neutralize actions | ✅ Implemented | Custom (web/pdf-action-neutralize.mjs) | MuPDF | Deletes JS, /OpenAction, /AA |
| F-034 | Hidden revision analysis | ✅ Implemented | Custom (web/pdf-hidden-revision-analyzer.mjs) | MuPDF | Walks /Prev chain |
| F-035 | Network egress assertion | ✅ Implemented | Custom (page.on('request')) | N/A | Proves zero external requests |

### 1.6 Export & Validation (7 features)

| # | Feature | Status | Current Provider | Best Alternative | Notes |
|---|---|---|---|---|---|
| F-036 | Source-preserving export | ✅ Implemented | PDFIncrementalFormWriter | MuPDF | Byte-exact prefix invariant |
| F-037 | Incremental update | ✅ Implemented | PDFIncrementalFormWriter | MuPDF | Xref chain appended |
| F-038 | Appearance streams | ✅ Implemented | PDFIncrementalFormWriter | MuPDF | Self-contained /AP /N |
| F-039 | qpdf validation | ✅ Implemented | qpdf (CLI) | MuPDF | Structural validation |
| F-040 | Poppler validation | ✅ Implemented | Poppler (CLI) | MuPDF | Text/raster/reopen |
| F-041 | pikepdf validation | ✅ Implemented | pikepdf (CLI) | MuPDF | Python-based validation |
| F-042 | Impact validation | ✅ Implemented | PDFImpactValidator | MuPDF | Outside-region comparison |

## 2. Planned Features (12 total)

### 2.1 Text Editing (3 features)

| # | Feature | Status | Current Provider | Best Alternative | Notes |
|---|---|---|---|---|---|
| P-001 | Text-run replacement | 📝 Planned | Abstained | MuPDF, PDFium | Simple ASCII only; font/glyph preservation needed |
| P-002 | Multilingual text editing | 📝 Planned | Not started | MuPDF, PDFium | RTL, CJK, ligatures |
| P-003 | Font-aware editing | 📝 Planned | Not started | MuPDF, PDFium | Preserve original fonts |

### 2.2 Redaction (2 features)

| # | Feature | Status | Current Provider | Best Alternative | Notes |
|---|---|---|---|---|---|
| P-004 | Text redaction | 📝 Planned | PDFContentStreamRedactor | MuPDF | Content stream level |
| P-005 | Image/vector redaction | 📝 Planned | Not started | MuPDF | Object removal |

### 2.3 Advanced Forms (2 features)

| # | Feature | Status | Current Provider | Best Alternative | Notes |
|---|---|---|---|---|---|
| P-006 | XFA form editing | 📝 Planned | Refused (guard) | MuPDF, PSPDFKit | XFA state regeneration needed |
| P-007 | Digital signature creation | 📝 Planned | Refused (guard) | PSPDFKit, MuPDF | Cryptographic signing |

### 2.4 Accessibility (2 features)

| # | Feature | Status | Current Provider | Best Alternative | Notes |
|---|---|---|---|---|---|
| P-008 | PDF/UA authoring | 📝 Planned | Not started | MuPDF, veraPDF | Tagged structure creation |
| P-009 | Accessibility validation | 📝 Planned | veraPDF (CLI) | MuPDF | PDF/UA-1 compliance |

### 2.5 Packaging (3 features)

| # | Feature | Status | Current Provider | Best Alternative | Notes |
|---|---|---|---|---|---|
| P-010 | Codesign + notarize | 📝 Planned | Not started | N/A | Apple Developer account needed |
| P-011 | Auto-update (Sparkle) | 📝 Planned | Not started | N/A | Hosting + EdDSA keys needed |
| P-012 | Crash reporting | 📝 Planned | Not started | N/A | Privacy-bounded telemetry |

## 3. Explorable Features (20+ total)

### 3.1 Advanced Rendering

| # | Feature | Value | Library Options | Effort |
|---|---|---|---|---|
| E-001 | GPU-accelerated rendering | Faster page turns | MuPDF (OpenGL), PDFium | High |
| E-002 | Annotation rendering | Show highlights/underlines | MuPDF, PDFKit | Medium |
| E-003 | Form field rendering | Show filled fields | MuPDF, PDFKit | Medium |
| E-004 | Digital signature rendering | Show signature status | MuPDF, PSPDFKit | High |
| E-005 | XFA form rendering | Show XFA forms | MuPDF, PSPDFKit | High |

### 3.2 Advanced Text Operations

| # | Feature | Value | Library Options | Effort |
|---|---|---|---|---|
| E-006 | Text search with regex | Power user search | MuPDF, Poppler | Medium |
| E-007 | Text highlighting | Visual search results | MuPDF, PDFKit | Low |
| E-008 | Text replacement with formatting | Preserve style | MuPDF, PSPDFKit | High |
| E-009 | Text extraction with layout | Preserve columns | Poppler, MuPDF | Medium |
| E-010 | Text extraction with tables | Preserve structure | Poppler, MuPDF | High |

### 3.3 Advanced Form Operations

| # | Feature | Value | Library Options | Effort |
|---|---|---|---|---|
| E-011 | Form validation | Client-side validation | MuPDF, custom | Medium |
| E-012 | Form calculation | Computed fields | MuPDF, PSPDFKit | High |
| E-013 | Form scripting | JavaScript execution | PSPDFKit | Very High |
| E-014 | Form templates | Reusable forms | MuPDF, custom | Medium |
| E-015 | Form data import/export | CSV, JSON | MuPDF, pypdf | Medium |

### 3.4 Advanced Security

| # | Feature | Value | Library Options | Effort |
|---|---|---|---|---|
| E-016 | Certificate-based signing | Qualified signatures | PSPDFKit, MuPDF | Very High |
| E-017 | Timestamping | Long-term validation | PSPDFKit, MuPDF | High |
| E-018 | Redaction with verification | Prove redaction | MuPDF, custom | High |
| E-019 | Metadata sanitization | Privacy compliance | qpdf, pikepdf, MuPDF | Low |
| E-020 | Hidden content detection | Forensics | MuPDF, custom | High |

### 3.5 Advanced Page Operations

| # | Feature | Value | Library Options | Effort |
|---|---|---|---|---|
| E-021 | Page merge | Combine PDFs | MuPDF, pypdf | Low |
| E-022 | Page split | Extract pages | MuPDF, pypdf | Low |
| E-023 | Page reorder | Drag-and-drop | MuPDF, pypdf | Medium |
| E-024 | Page crop | Trim pages | MuPDF, PDFKit | Low |
| E-025 | Page flatten | Remove interactivity | MuPDF, pypdf | Medium |

### 3.6 Advanced Export

| # | Feature | Value | Library Options | Effort |
|---|---|---|---|---|
| E-026 | PDF/A compliance | Archival format | MuPDF, veraPDF | High |
| E-027 | PDF/X compliance | Print format | MuPDF, veraPDF | High |
| E-028 | PDF/UA compliance | Accessibility | MuPDF, veraPDF | High |
| E-029 | Linearized PDF | Fast web view | MuPDF, qpdf | Medium |
| E-030 | Encrypted export | Password protection | MuPDF, qpdf | Low |

## 4. Library Evaluation Summary

### 4.1 Feature Coverage Matrix

| Feature Category | PDFKit | MuPDF | PDFium | Poppler | pypdf | PSPDFKit |
|---|---|---|---|---|---|---|
| **Reading/Rendering** | ✅ Good | ✅ Excellent | ✅ Excellent | ⚠️ CLI only | ❌ None | ✅ Excellent |
| **Text Extraction** | ✅ Good | ✅ Excellent | ✅ Good | ✅ Excellent | ✅ Good | ✅ Good |
| **OCR** | ❌ None | ❌ None | ❌ None | ❌ None | ❌ None | ❌ None |
| **Form Fields** | ⚠️ Buggy | ✅ Excellent | ✅ Good | ⚠️ Read-only | ✅ Good | ✅ Excellent |
| **Annotations** | ✅ Good | ✅ Good | ✅ Good | ❌ None | ⚠️ Basic | ✅ Excellent |
| **Security** | ⚠️ Basic | ✅ Good | ⚠️ Basic | ⚠️ CLI only | ✅ Good | ✅ Excellent |
| **Redaction** | ❌ None | ✅ Good | ❌ None | ❌ None | ❌ None | ✅ Excellent |
| **Page Operations** | ✅ Good | ✅ Excellent | ⚠️ Basic | ⚠️ CLI only | ✅ Good | ✅ Excellent |
| **Export** | ✅ Good | ✅ Excellent | ✅ Good | ⚠️ CLI only | ✅ Good | ✅ Excellent |
| **Validation** | ⚠️ Basic | ✅ Good | ⚠️ Basic | ✅ Good | ✅ Good | ✅ Good |

### 4.2 License Comparison

| Library | License | Copyleft? | Commercial use? | Source disclosure? |
|---|---|---|---|---|
| **PDFKit** | Proprietary | No | ✅ Yes | No |
| **MuPDF** | AGPL | ✅ Yes | ⚠️ With source | ✅ Required |
| **PDFium** | BSD | No | ✅ Yes | No |
| **Poppler** | GPL | ✅ Yes | ⚠️ With source | ✅ Required |
| **pypdf** | BSD | No | ✅ Yes | No |
| **PSPDFKit** | Commercial | No | ✅ Yes | No |

### 4.3 Performance Comparison

| Library | Rendering Speed | Memory Usage | Startup Time | Form Handling |
|---|---|---|---|---|
| **PDFKit** | Good | Medium | Fast | Poor (bugs) |
| **MuPDF** | Excellent | Low | Fast | Excellent |
| **PDFium** | Excellent | Low | Fast | Good |
| **Poppler** | Good | Medium | Medium | Read-only |
| **pypdf** | N/A | Low | Fast | Good |
| **PSPDFKit** | Excellent | Medium | Fast | Excellent |

### 4.4 Swift Integration Comparison

| Library | Native Swift? | API Quality | Documentation | Community |
|---|---|---|---|---|
| **PDFKit** | ✅ Yes | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ |
| **MuPDF** | ❌ C wrapper | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| **PDFium** | ❌ C++ wrapper | ⭐⭐ | ⭐⭐ | ⭐⭐⭐ |
| **Poppler** | ❌ CLI only | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| **pypdf** | ❌ Python | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| **PSPDFKit** | ✅ Yes | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |

## 5. Recommendations Per Feature

### 5.1 Implemented Features — Keep or Replace

| Feature | Current | Recommendation | Rationale |
|---|---|---|---|
| F-001 Open/import | PDFKit | Keep | Works for most cases |
| F-002 Render pages | PDFKit | Keep (document bugs) | Replace later with PDFium |
| F-003 Page navigation | PDFKit | Keep | Adequate |
| F-004 Zoom/scale | PDFKit | Keep | Adequate |
| F-005 Rotation | PDFKit | Keep | Adequate |
| F-006 Continuous view | PDFKit | Keep | Adequate |
| F-007 Two-page view | PDFKit | Keep | Adequate |
| F-008 Thumbnails | PDFKit | Keep | Adequate |
| F-009 Extract text | PDFKit | Keep | Adequate |
| F-010 Search text | PDFKit | Keep | Adequate |
| F-011 Copy text | PDFKit | Keep | Adequate |
| F-012 OCR (English) | Vision | Keep | Best native option |
| F-013 OCR fallback | Vision | Keep | Best native option |
| F-014 Text-run detection | Custom | Keep | Custom is fine |
| F-015 Inspect AcroForm | PDFKit+CGPDF | Keep | Writer bypasses PDFKit |
| F-016 Fill text fields | IncrementalWriter | Keep | Already bypasses PDFKit |
| F-017 Toggle checkboxes | IncrementalWriter | Keep | Already bypasses PDFKit |
| F-018 Select radio options | IncrementalWriter | Keep | Already bypasses PDFKit |
| F-019 Choice/dropdown | IncrementalWriter | Keep | Already bypasses PDFKit |
| F-020 Field synthesis | PDFKit+custom | Keep | Custom is fine |
| F-021 Direct text placement | PDFKit+custom | Keep | Custom is fine |
| F-022 Manual placement | PDFKit+custom | Keep | Custom is fine |
| F-023 Field lookup | Custom cache | Keep | Performance optimized |
| F-024 FreeText overlay | PDFKit | Keep | Adequate |
| F-025 Highlight | PDFKit | Keep | Adequate |
| F-026 Underline | PDFKit | Keep | Adequate |
| F-027 Evidence card | Custom | Keep | Custom is fine |
| F-028 Diff comparison | PDFKit+custom | Keep | Custom is fine |
| F-029 Password open | PDFKit | Keep | Adequate |
| F-030 Signature detection | Custom | Keep | Custom is fine |
| F-031 XFA detection | Custom | Keep | Custom is fine |
| F-032 Sanitize metadata | qpdf+pikepdf | Keep | CLI tools work |
| F-033 Neutralize actions | Custom | Keep | Custom is fine |
| F-034 Hidden revision | Custom | Keep | Custom is fine |
| F-035 Network egress | Custom | Keep | Custom is fine |
| F-036 Source-preserving export | IncrementalWriter | Keep | Already bypasses PDFKit |
| F-037 Incremental update | IncrementalWriter | Keep | Already bypasses PDFKit |
| F-038 Appearance streams | IncrementalWriter | Keep | Already bypasses PDFKit |
| F-039 qpdf validation | qpdf CLI | Keep | CLI tools work |
| F-040 Poppler validation | Poppler CLI | Keep | CLI tools work |
| F-041 pikepdf validation | pikepdf CLI | Keep | CLI tools work |
| F-042 Impact validation | Custom | Keep | Custom is fine |

### 5.2 Planned Features — Library Recommendations

| Feature | Recommended Library | Rationale |
|---|---|---|
| P-001 Text-run replacement | MuPDF or PDFium | Need font-aware editing |
| P-002 Multilingual text editing | MuPDF or PDFium | Need RTL/CJK support |
| P-003 Font-aware editing | MuPDF or PSPDFKit | Need font preservation |
| P-004 Text redaction | MuPDF | Content stream redaction |
| P-005 Image/vector redaction | MuPDF | Object removal |
| P-006 XFA form editing | PSPDFKit | XFA state regeneration |
| P-007 Digital signature creation | PSPDFKit or MuPDF | Cryptographic signing |
| P-008 PDF/UA authoring | MuPDF or veraPDF | Tagged structure |
| P-009 Accessibility validation | veraPDF (CLI) | Already integrated |
| P-010 Codesign + notarize | N/A (Apple tools) | Not a PDF library |
| P-011 Auto-update (Sparkle) | N/A (Sparkle) | Not a PDF library |
| P-012 Crash reporting | N/A (PLCrashReporter) | Not a PDF library |

### 5.3 Explorable Features — Library Recommendations

| Feature | Recommended Library | Rationale |
|---|---|---|
| E-001 GPU rendering | MuPDF | OpenGL support |
| E-002 Annotation rendering | MuPDF or PDFKit | Both support annotations |
| E-003 Form field rendering | MuPDF | Best form support |
| E-004 Signature rendering | PSPDFKit or MuPDF | Both support signatures |
| E-005 XFA form rendering | PSPDFKit | XFA support |
| E-006 Regex text search | MuPDF or Poppler | Both support regex |
| E-007 Text highlighting | MuPDF or PDFKit | Both support highlighting |
| E-008 Text replacement formatting | MuPDF or PSPDFKit | Font preservation |
| E-009 Text extraction layout | Poppler | Best layout preservation |
| E-010 Text extraction tables | Poppler or MuPDF | Table detection |
| E-011 Form validation | MuPDF or custom | Client-side validation |
| E-012 Form calculation | MuPDF or PSPDFKit | Computed fields |
| E-013 Form scripting | PSPDFKit | JavaScript execution |
| E-014 Form templates | MuPDF or custom | Reusable forms |
| E-015 Form data import/export | MuPDF or pypdf | CSV/JSON support |
| E-016 Certificate signing | PSPDFKit | Qualified signatures |
| E-017 Timestamping | PSPDFKit or MuPDF | Long-term validation |
| E-018 Redaction verification | MuPDF or custom | Prove redaction |
| E-019 Metadata sanitization | qpdf or pikepdf | Already integrated |
| E-020 Hidden content detection | MuPDF or custom | Forensics |
| E-021 Page merge | MuPDF or pypdf | Combine PDFs |
| E-022 Page split | MuPDF or pypdf | Extract pages |
| E-023 Page reorder | MuPDF or pypdf | Drag-and-drop |
| E-024 Page crop | MuPDF or PDFKit | Trim pages |
| E-025 Page flatten | MuPDF or pypdf | Remove interactivity |
| E-026 PDF/A compliance | MuPDF or veraPDF | Archival format |
| E-027 PDF/X compliance | MuPDF or veraPDF | Print format |
| E-028 PDF/UA compliance | MuPDF or veraPDF | Accessibility |
| E-029 Linearized PDF | MuPDF or qpdf | Fast web view |
| E-030 Encrypted export | MuPDF or qpdf | Password protection |

## 6. Architecture Decision Record

### ADR-001: PDF Library Strategy

**Status:** Accepted
**Date:** 2026-08-26
**Context:** PDFKit has known bugs (FB22167174, F-016, tile crashes). Need to decide library strategy.

**Decision:**
1. **Keep PDFKit for rendering** — document known bugs, replace later with PDFium
2. **Use PDFIncrementalFormWriter for all writes** — already bypasses PDFKit
3. **Add MuPDF as CLI validator** — not linked, avoids AGPL
4. **Evaluate PDFium for future** — BSD license, fast rendering
5. **Consider PSPDFKit for commercial** — if budget allows

**Consequences:**
- PDFKit bugs remain for now (rendering only)
- All form operations use IncrementalWriter (bypasses PDFKit)
- MuPDF validates our output without AGPL risk
- PDFium is evaluated for future replacement

### ADR-002: License Strategy

**Status:** Accepted
**Date:** 2026-08-26
**Context:** Need to choose libraries with compatible licenses.

**Decision:**
1. **BSD/MIT preferred** — PDFium, pypdf, custom code
2. **AGPL acceptable for CLI tools** — MuPDF (not linked)
3. **GPL acceptable for validation** — qpdf, Poppler (CLI tools)
4. **Commercial acceptable if justified** — PSPDFKit (professional SDK)

**Consequences:**
- No AGPL code linked into the app
- All CLI tools are separate processes
- Custom code has no copyleft contamination

## 7. Evidence

- `Sources/PDFEditorCore/*.swift` — 70+ source files with PDF features
- `docs/audits/pdf-library-evaluation-2026-08-26.md` — Library evaluation
- `docs/audits/pdfkit-adequacy-audit-2026-08-26.md` — PDFKit verification
- `docs/capability-matrix.json` — 20 capabilities + 5 unsupported
- `docs/support-policy.md` — Platform/browser/encryption matrix
- `findings.md` — F-016 (radio-choice loss), F-017 (synthetic widgets)
