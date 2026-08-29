# Creator Archetype — CREATE / DESIGN / PUBLISH

**Date:** 2026-08-28
**Framework:** Expanded Analytical Framework (22 dimensions)
**Jobs:** CREATE (produce), DESIGN (layout/format), PUBLISH (distribute)
**Status:** First-principles, long-term, doctrine-aligned analysis
**Extends:** `jtbd-creator-archetype-expanded-analysis-2026-08-27.md`, `jtbd-01-read-first-principles-2026-08-26.md`

---

## Purpose

The Creator archetype is where the app transitions from a viewer to an authoring tool. While the Reader archetype is about consuming content, the Creator archetype is about PRODUCING, FORMATTING, and DISTRIBUTING documents. This is where the bigger product opportunity lies.

The Reader archetype asked: "How do I understand this document?"
The Creator archetype asks: "How do I make this document exist?"

---

## Taxonomy

| Job | Core statement | Status |
|---|---|---|
| **CREATE** | "I want to produce a new document" | ⚠️ Partial — blank canvas + content elements exist; no rich authoring UI |
| **DESIGN** | "I want this document to look professional" | ❌ Minimal — ContentAuthor has text/shapes; no typography, grid, or style system |
| **PUBLISH** | "I want this document to reach its audience" | ⚠️ Partial — file export exists; no print layout, web export, or distribution pipeline |

---

# 1. CREATE — "I want to produce a new document"

## 1.1 WHO

| Persona | Core need | Expertise | Frequency | Our support |
|---|---|---|---|---|
| Author | Write a new document from scratch | Domain expert | Daily | ⚠️ Blank canvas + text elements |
| Teacher | Create assignments, worksheets, tests | Education | Weekly | ❌ No template-based creation |
| Business analyst | Create reports with data | Business | Weekly | ❌ No structured creation |
| Form designer | Build fillable PDF forms | PDF expert | Weekly | ⚠️ AcroForm writer exists |
| Template creator | Build reusable templates | PDF expert | Monthly | ⚠️ Template store exists, no editor |
| Developer | Generate PDFs programmatically | Technical | Weekly | ⚠️ PDFBatchProcessor |
| Student | Create a simple document | Basic | Monthly | ❌ No simple creation flow |
| Designer | Create visually rich documents | Design | Daily | ❌ No design tools |

## 1.2 WHAT

| Object | Creation challenge | Our capability | Gap |
|---|---|---|---|
| New PDF from scratch | Empty canvas + content | ⚠️ ContentAuthor state machine | Medium — engine exists, no UI |
| Text document | Paragraphs, headings, body text | ⚠️ TextProperties element | Large — no paragraph flow |
| Form template | Fillable fields + layout | ⚠️ AcroForm writer | Medium — no visual designer |
| Report | Headers, footers, sections, page numbers | ❌ No section/layout system | Large |
| Invoice | Structured layout + data binding | ❌ No data binding | Large |
| Certificate | Formal layout + signature | ❌ No layout templates | Large |
| Presentation | Slide-based layout | ❌ Not in scope | N/A |
| Image document | Photos with captions | ⚠️ ImageProperties element | Medium — no caption flow |

## 1.3 WHEN

| Phase | What happens | Our support |
|---|---|---|
| 1. Idea | User decides what to create | ❌ No guidance/templates |
| 2. Structure | Choose document type and layout | ❌ No document type system |
| 3. Content | Write/place content | ⚠️ Text elements work |
| 4. Formatting | Apply visual style | ❌ No style system |
| 5. Review | Check output quality | ⚠️ Diff view for existing docs |
| 6. Finalize | Export as PDF | ✅ Export pipeline |

## 1.4 WHERE

| Context | Creation need | Our support |
|---|---|---|
| Desk (primary) | Full authoring session | ⚠️ ContentAuthor engine |
| Meeting | Quick note/document | ❌ No quick-create |
| Mobile | Draft on-the-go | ❌ No mobile app |
| Education | Assignment/test creation | ❌ No education templates |

## 1.5 WHY

| Why create | Depth | Our support |
|---|---|---|
| Produce a deliverable | Core | ⚠️ Blank canvas exists |
| Build a template | Reusable | ⚠️ Template store, no editor |
| Generate a report | Recurring | ❌ No structured creation |
| Design a form | Interactive | ⚠️ AcroForm |
| Create a certificate | Formal | ❌ No templates |
| Convert notes to PDF | Convenience | ⚠️ Markdown-to-PDF exists |
| Create from images | Media | ✅ Image-to-PDF works |

## 1.6 HOW

| Method | Description | Our support |
|---|---|---|
| Blank canvas | Start from empty page | ⚠️ ContentAuthor engine |
| Template-based | Start from pre-built layout | ⚠️ Template store exists |
| Import + modify | Start from existing PDF | ⚠️ Edit operations |
| Merge + compose | Combine existing PDFs | ✅ BatchMergeSheet |
| Markdown → PDF | Convert text to formatted PDF | ✅ Markdown-to-PDF |
| Image → PDF | Convert images to PDF pages | ✅ Image-to-PDF |
| Clipboard → PDF | Paste content as new PDF | ✅ Clipboard-to-PDF |
| Programmatic | API-based generation | ⚠️ PDFBatchProcessor |

## 1.7 Current State

| Component | Status | Evidence | Lines |
|---|---|---|---|
| ContentAuthor engine | ✅ Complete | `ContentAuthor.swift` — state machine with undo/redo | 497 |
| DocumentElement model | ✅ Complete | `DocumentElement.swift` — text, image, shape, form field elements | 404 |
| ContentAuthor tests | ✅ Complete | `ContentAuthorTests.swift` — 283 lines | 283 |
| New blank PDF | ✅ Working | `AppCommands.swift` — Cmd+N creates blank document | — |
| Image-to-PDF | ✅ Working | `AppModel.swift` — newFromImages | — |
| Clipboard-to-PDF | ✅ Working | `AppModel.swift` — newFromClipboard | — |
| Markdown-to-PDF | ✅ Working | `AppCommands.swift` — newFromMarkdown | — |
| Template store | ⚠️ Partial | TemplateStore, TemplateSyncContracts | — |
| Blank canvas UI | ❌ No UI | ContentAuthor exists but no AuthoringCanvasView | — |
| Paragraph flow | ❌ No flow | Text elements are single-line, no word-wrap | — |
| Font picker | ❌ No picker | Font names are strings, no UI selection | — |
| Color picker | ❌ No picker | Colors are hex strings, no UI selection | — |
| Image placement UI | ❌ No UI | ImageProperties exists, no drag-to-place | — |
| Form field designer | ❌ No UI | FormFieldProperties exists, no visual editor | — |

## 1.8 Assessment

CREATE is **the weakest archetype** in terms of user-facing surface, but the **engine is solid**. The ContentAuthor state machine with undo/redo is the right architecture. The gap is:

1. **No authoring canvas UI** — ContentAuthor exists but there's no view to interact with it
2. **No paragraph flow** — text elements are single-line boxes, not flowing text
3. **No font/color UI** — users can't pick fonts or colors visually
4. **No image drag-and-drop** — images exist as properties but can't be placed interactively

**First principle:** The creation engine is a projection. The ContentAuthor is a pure state machine — elements are descriptors, PDF rendering is a separate concern. This is the right separation. The gap is the presentation layer.

---

# 2. DESIGN — "I want this document to look professional"

## 2.1 WHO

| Persona | Core need | Expertise | Frequency | Our support |
|---|---|---|---|---|
| Designer | Visual layout and typography | Design expert | Daily | ❌ No design tools |
| Marketing | Branded documents | Business | Weekly | ❌ No brand system |
| Teacher | Clean worksheets | Education | Weekly | ❌ No layout tools |
| Business user | Professional reports | Business | Weekly | ❌ No templates |
| Developer | Programmatic styling | Technical | Weekly | ⚠️ Element properties |

## 2.2 WHAT

| Object | Design challenge | Our capability | Gap |
|---|---|---|---|
| Typography | Font selection, sizing, spacing | ⚠️ TextProperties has font/size | Large — no UI, no kerning |
| Color system | Document-wide color palette | ❌ No color system | Large |
| Grid/layout | Page grid, columns, margins | ❌ No grid system | Large |
| Headers/footers | Repeating page elements | ❌ No master pages | Large |
| Page numbers | Auto-numbering | ❌ Not implemented | Medium |
| Styles | Consistent formatting rules | ❌ No style system | Large |
| Images | Placement, sizing, wrapping | ⚠️ ImageProperties exists | Large — no UI |
| Shapes | Lines, rectangles, circles | ⚠️ ShapeProperties exists | Medium — no UI |
| Tables | Structured data layout | ❌ Not implemented | Large |
| Charts | Data visualization | ❌ Not implemented | Large |
| Watermarks | Background text/images | ⚠️ PdfCpuBatchProcessor | Medium — external only |
| Margins/padding | Page whitespace control | ❌ Not implemented | Medium |
| Backgrounds | Page background colors/images | ❌ Not implemented | Medium |

## 2.3 WHEN

| Phase | What happens | Our support |
|---|---|---|
| 1. Choose layout | Select page structure | ❌ No layout picker |
| 2. Set typography | Choose fonts and sizes | ❌ No font picker |
| 3. Apply colors | Set document palette | ❌ No color system |
| 4. Place content | Position elements on grid | ❌ No grid snapping |
| 5. Add repeating elements | Headers, footers, page numbers | ❌ No master pages |
| 6. Polish | Fine-tune spacing and alignment | ❌ No alignment tools |
| 7. Preview | See final output | ⚠️ PDFKit renders |

## 2.4 WHERE

| Context | Design need | Our support |
|---|---|---|
| Desk | Full design session | ❌ No design surface |
| Quick fix | Adjust one element | ❌ No element editing UI |
| Template design | Build reusable layouts | ⚠️ Template store, no editor |

## 2.5 WHY

| Why design | Depth | Our support |
|---|---|---|
| Professional appearance | Core | ❌ No design tools |
| Brand consistency | Business | ❌ No brand system |
| Readability | Core | ❌ No typography controls |
| Accessibility | Compliance | ⚠️ VoiceOver labels exist |
| Visual hierarchy | Communication | ❌ No style system |
| Print readiness | Production | ❌ No print layout |

## 2.6 HOW

| Method | Description | Our support |
|---|---|---|
| Template-based design | Start from pre-designed layout | ⚠️ Template store |
| Element-level styling | Style individual elements | ⚠️ Element properties |
| Document-wide styles | Apply consistent rules | ❌ Not implemented |
| Grid snapping | Align elements to grid | ❌ Not implemented |
| Master pages | Repeating elements across pages | ❌ Not implemented |
| CSS-like cascading | Inherit styles from parents | ❌ Not implemented |

## 2.7 Current State

| Component | Status | Evidence |
|---|---|---|
| TextProperties (font, size, color) | ⚠️ Partial | Data model exists, no UI |
| ImageProperties (source, frame) | ⚠️ Partial | Data model exists, no UI |
| ShapeProperties (type, stroke, fill) | ⚠️ Partial | Data model exists, no UI |
| FormFieldProperties (type, options) | ⚠️ Partial | Data model exists, no UI |
| DocumentElement frame positioning | ✅ Complete | PDFRect frame with x/y/width/height |
| Z-index ordering | ✅ Complete | zIndex property on elements |
| Undo/redo | ✅ Complete | Full undo stack |
| ThemeManager (dark mode) | ✅ Complete | System-following theme |
| Reading modes | ✅ Complete | Study/Skim/Reference/Review |
| Font picker UI | ❌ Nothing | — |
| Color picker UI | ❌ Nothing | — |
| Grid/alignment tools | ❌ Nothing | — |
| Master pages | ❌ Nothing | — |
| Style system | ❌ Nothing | — |

## 2.8 Assessment

DESIGN is **almost entirely unimplemented** as a user surface. The data models exist (DocumentElement, TextProperties, ImageProperties, ShapeProperties) but there are zero UI tools for designing documents. The design gap is the bridge between the ContentAuthor engine and what users see.

**First principle:** Design is a constraint system, not a feature list. A good design tool constrains choices to good outcomes — grid snapping prevents misalignment, style inheritance prevents inconsistency, master pages prevent forgotten headers. Our current state is "everything is possible, nothing is guided."

---

# 3. PUBLISH — "I want this document to reach its audience"

## 3.1 WHO

| Persona | Core need | Expertise | Frequency | Our support |
|---|---|---|---|---|
| Author | Share finished document | Basic | Weekly | ✅ File export |
| Business user | Email/print distribution | Basic | Daily | ✅ File export |
| Teacher | Distribute to students | Education | Weekly | ❌ No distribution |
| Developer | Programmatic publishing | Technical | Weekly | ⚠️ PDFBatchProcessor |
| Legal professional | File signed documents | Legal | Daily | ✅ CommitFlow + export |
| Marketer | Publish to web | Marketing | Weekly | ❌ No web export |

## 3.2 WHAT

| Object | Publishing challenge | Our capability | Gap |
|---|---|---|---|
| PDF export | Save as PDF file | ✅ Export pipeline | Small — works |
| Print | Physical output | ❌ No print layout | Medium |
| Email attachment | Send via email | ❌ No email integration | Medium |
| Web embedding | Publish online | ❌ No web export | Large |
| Cloud upload | Store in cloud | ❌ No cloud integration | Large |
| Version publishing | Publish specific versions | ⚠️ VersionStore exists | Medium — no publish UI |
| Batch publishing | Publish many documents | ⚠️ BatchRunner exists | Medium — no publish pipeline |
| Archive/compress | Reduce file size | ❌ No compression | Medium |
| Metadata tagging | Tag for discovery | ⚠️ DocumentIndex has tags | Small |
| Accessibility export | Accessible PDF | ⚠️ WCAG partial | Large |

## 3.3 WHEN

| Phase | What happens | Our support |
|---|---|---|
| 1. Pre-flight | Check document is ready | ⚠️ PDFPreflightBuilder exists |
| 2. Optimize | Comimize for target medium | ❌ No optimization |
| 3. Format | Choose output format | ⚠️ PDF export only |
| 4. Distribute | Send to audience | ❌ No distribution |
| 5. Track | Know who received it | ❌ No tracking |
| 6. Update | Publish new version | ⚠️ VersionStore exists |

## 3.4 WHERE

| Context | Publishing need | Our support |
|---|---|---|
| Desk | Export to file | ✅ File export |
| Email | Send as attachment | ❌ No integration |
| Web | Publish online | ❌ No web export |
| Print shop | Professional printing | ❌ No print prep |
| Archive | Long-term storage | ❌ No archive format |
| Cloud | Store in cloud | ❌ No cloud integration |

## 3.5 WHY

| Why publish | Depth | Our support |
|---|---|---|
| Share with others | Core | ✅ File export |
| Physical printing | Production | ❌ No print layout |
| Digital distribution | Convenience | ❌ No email/web |
| Compliance | Legal | ⚠️ Signed export |
| Archival | Longevity | ❌ No PDF/A export |
| Accessibility | Inclusion | ⚠️ Partial WCAG |

## 3.6 HOW

| Method | Description | Our support |
|---|---|---|
| File export | Save as PDF on disk | ✅ Export pipeline |
| Print | macOS print dialog | ❌ No print integration |
| Email | Attach to email | ❌ No email integration |
| Web page | Convert to HTML/web | ❌ Not implemented |
| Cloud upload | Upload to cloud storage | ❌ Not implemented |
| Batch export | Export multiple documents | ⚠️ BatchRunner |
| Format conversion | PDF → other formats | ⚠️ External tools only |
| Archive format | PDF/A compliance | ❌ Not implemented |

## 3.7 Current State

| Component | Status | Evidence |
|---|---|---|
| PDF export (file save) | ✅ Complete | `export()` in AppModel |
| Export scratch copy | ✅ Complete | `exportScratchCopy()` |
| Export flattened copy | ✅ Complete | `exportFlattenedCopy()` |
| Export diff report | ✅ Complete | `exportDiffReport()` |
| Template export | ✅ Complete | `exportTemplateRecoveryEnvelope()` |
| Batch merge export | ✅ Complete | BatchMergeSheet |
| Print layout | ❌ Nothing | — |
| Email integration | ❌ Nothing | — |
| Web export | ❌ Nothing | — |
| PDF/A compliance | ❌ Nothing | — |
| File size optimization | ❌ Nothing | — |
| Cloud upload | ❌ Nothing | — |
| Distribution tracking | ❌ Nothing | — |

## 3.8 Assessment

PUBLISH is **minimal but functional**. The app can export PDFs to disk, which covers the core use case. The gaps are:

1. **No print integration** — macOS print dialog is not wired
2. **No format conversion** — PDF is the only output format
3. **No optimization** — no file size reduction or PDF/A compliance
4. **No distribution** — no email, web, or cloud integration

**First principle:** Publishing is a one-way gate. Once a document is published, it's out of your control. The app should make publishing intentional (require explicit action), reversible (keep the source), and auditable (log what was published). The current export pipeline already does this.

---

# 4. CROSS-CREATOR ASSESSMENT

## 4.1 The Creator Flow

```
CREATE (produce) → DESIGN (format) → PUBLISH (distribute)
       ↑                                    ↓
   Templates ←──────────────────── Published artifacts
```

The natural flow: create content, design the layout, publish to audience. Templates loop back — published documents become templates for future creation.

## 4.2 What the Creator Archetype Needs Most

| Priority | Gap | Job | Impact | Effort |
|---|---|---|---|---|
| 1 | Authoring canvas UI | CREATE | Opens entire creation market | HIGH |
| 2 | Paragraph text flow | CREATE | Core authoring capability | HIGH |
| 3 | Font/color picker UI | DESIGN | Basic design capability | MEDIUM |
| 4 | Print integration | PUBLISH | Physical distribution | MEDIUM |
| 5 | Grid/alignment tools | DESIGN | Professional output | MEDIUM |
| 6 | Master pages (headers/footers) | DESIGN | Repeating elements | MEDIUM |
| 7 | Style system | DESIGN | Consistent formatting | MEDIUM |
| 8 | PDF/A compliance | PUBLISH | Archival quality | LOW |
| 9 | Email integration | PUBLISH | Common distribution | LOW |
| 10 | Table creation | CREATE | Structured content | LOW |

## 4.3 Doctrine Alignment

| Doctrine | CREATE | DESIGN | PUBLISH |
|---|---|---|---|
| §3 Do things smartly | ✅ ContentAuthor is pure state machine | ❌ No constraint system | ✅ Export is intentional |
| §5 Evidence-based | ✅ Full undo history | ❌ No design evidence | ✅ Export audit trail |
| §8 Capability activation | ✅ CREATE mode is explicit | N/A | ✅ Export requires action |
| §12 Privacy value-free | ✅ No content in logs | N/A | ✅ Export logged value-free |
| §1 Source preservation | ✅ Elements are descriptors | N/A | ✅ Source never overwritten |

## 4.4 The Creator-Reader Bridge

```
READ (consume) ←→ CREATE (produce)
    ↓                    ↓
UNDERSTAND          DESIGN (format)
    ↓                    ↓
FIND/ANNOTATE       PUBLISH (distribute)
    ↓                    ↓
LEARN/SHARE         COMMIT (bind)
```

Every reader job has a creator counterpart:
- READ ↔ CREATE (consume vs produce)
- FIND ↔ ORGANIZE (search vs index)
- UNDERSTAND ↔ DESIGN (comprehend vs format)
- ANNOTATE ↔ TRANSFORM (mark vs modify)
- SHARE ↔ PUBLISH (receive vs distribute)
- COMMIT ↔ COMMIT (both bind)

## 4.5 Sub-Job Weighting by User

| User | CREATE | DESIGN | PUBLISH | Why |
|---|---|---|---|---|
| Author | 🔴 Critical | 🟡 Medium | 🟡 Medium | Core is writing, design is polish |
| Designer | 🟡 Medium | 🔴 Critical | 🟡 Medium | Core is layout, creation is input |
| Business | 🟡 Medium | 🟡 Medium | 🔴 Critical | Core is distribution, design is brand |
| Teacher | 🔴 Critical | 🟡 Medium | 🔴 Critical | Creates + distributes frequently |
| Student | 🟡 Low | 🟢 Low | 🟡 Medium | Usually consumes, occasionally creates |
| Developer | 🟢 Low | 🟢 Low | 🔴 Critical | Programmatic creation, manual publish |
| Legal | 🟡 Low | 🟢 Low | 🔴 Critical | Signs + distributes, rarely creates |

---

# 5. GAP ANALYSIS — CREATOR vs READER

## 5.1 Feature Coverage Comparison

| Feature area | Reader support | Creator support | Delta |
|---|---|---|---|
| Rendering | ✅ Full (PDFKit + pipeline) | ❌ No creation rendering | Creator behind |
| Text handling | ✅ Search, extract, OCR | ⚠️ Text elements (no flow) | Creator behind |
| Navigation | ✅ Full (thumbnails, links, outlines) | ❌ No creation navigation | Creator behind |
| Search | ✅ Full (exact, fuzzy, regex) | N/A | — |
| Annotations | ✅ Full (highlight, note, mark) | ❌ No creation annotations | Creator behind |
| Forms | ✅ Fill + validate | ⚠️ FormFieldProperties (no UI) | Creator behind |
| Security | ✅ Full (encrypt, sign, redact) | ✅ Same tools apply | Parity |
| Export | ✅ Full | ✅ Same pipeline | Parity |
| Collaboration | ✅ Full (merge, approve) | ✅ Same tools apply | Parity |
| Versioning | ✅ Full | ✅ Same tools apply | Parity |
| Dark mode | ✅ Full | ✅ ThemeManager applies | Parity |
| Accessibility | ⚠️ Partial | ❌ No creation accessibility | Creator behind |

## 5.2 The Asymmetry

The Reader archetype has been built out extensively — 17+ jobs, full pipeline, deep analysis. The Creator archetype has the **engine** (ContentAuthor, DocumentElement, export pipeline) but almost no **surface** (no authoring canvas, no design tools, no publish workflow).

This asymmetry is intentional and correct for a first release: **reading is the primary use case**. But for the app to become a complete PDF tool, the creator surface needs to catch up.

---

# 6. IMPLEMENTATION ROADMAP

## Phase 1 — CREATE Surface (highest leverage)

| # | Feature | Effort | Impact | Dependencies |
|---|---|---|---|---|
| C-1 | AuthoringCanvasView — interactive canvas for placing/editing elements | HIGH | 🔴 Critical | ContentAuthor (exists) |
| C-2 | Paragraph text flow — word-wrap, multi-line text | HIGH | 🔴 Critical | TextProperties (exists) |
| C-3 | Font picker — system font list with preview | MEDIUM | 🟡 High | TextProperties.fontName |
| C-4 | Color picker — document palette + system picker | MEDIUM | 🟡 High | TextProperties.color |
| C-5 | Image drag-and-drop — place images on canvas | MEDIUM | 🟡 High | ImageProperties (exists) |
| C-6 | Element selection + resize + move | MEDIUM | 🔴 Critical | DocumentElement.frame |

## Phase 2 — DESIGN Surface

| # | Feature | Effort | Impact | Dependencies |
|---|---|---|---|---|
| D-1 | Grid/alignment snapping | MEDIUM | 🟡 High | AuthoringCanvasView |
| D-2 | Master pages (headers, footers, page numbers) | HIGH | 🟡 High | Element model |
| D-3 | Style system (paragraph + character styles) | HIGH | 🟡 Medium | Typography model |
| D-4 | Table creation tool | HIGH | 🟡 Medium | Element model |
| D-5 | Page template picker (A4, Letter, custom) | LOW | 🟡 Medium | PageSize model |
| D-6 | Margin/gutter controls | LOW | 🟡 Medium | Page model |

## Phase 3 — PUBLISH Surface

| # | Feature | Effort | Impact | Dependencies |
|---|---|---|---|---|
| P-1 | macOS print dialog integration | MEDIUM | 🟡 High | Print API |
| P-2 | File size optimization (image compression) | MEDIUM | 🟡 Medium | PDF export |
| P-3 | PDF/A compliance export | HIGH | 🟡 Medium | External tools |
| P-4 | Email attachment integration | LOW | 🟡 Medium | macOS Mail |
| P-5 | Batch publish pipeline | MEDIUM | 🟢 Low | BatchRunner |
| P-6 | Distribution tracking (who got what) | HIGH | 🟢 Low | Audit trail |

---

# 7. OPEN QUESTIONS

| # | Question | Impact | Status |
|---|---|---|---|
| OQ-1 | Should the authoring canvas replace PDFKit's renderer for creation mode, or overlay on top? | Architectural | Open |
| OQ-2 | Should templates be the primary creation entry point, or blank canvas? | Product | Open |
| OQ-3 | Should DESIGN support CSS-like cascading styles, or flat per-element styling? | Architectural | Open |
| OQ-4 | Should PUBLISH support non-PDF formats (DOCX, HTML, PNG)? | Product | Open |
| OQ-5 | Should creation mode be a separate app target, or a mode within the existing app? | Architectural | Open |

---

# 8. EVIDENCE

| File | What it proves |
|---|---|
| `Sources/PDFEditorCore/ContentAuthor.swift` (497 lines) | CREATE engine: state machine, undo/redo, element management |
| `Sources/PDFEditorCore/DocumentElement.swift` (404 lines) | Element model: text, image, shape, form field, frame, z-index |
| `Tests/PDFEditorCoreTests/ContentAuthorTests.swift` (283 lines) | Engine tests: add, move, delete, undo, redo, page management |
| `Sources/PDFEditorApp/AppCommands.swift` | File menu: New Document, New from Images, New from Clipboard, New from Markdown |
| `Sources/PDFEditorRecovery/AppModel.swift` | Document creation: blank PDF, image-to-PDF, clipboard-to-PDF, markdown-to-PDF |
| `Sources/PDFEditorCore/PDFIncrementalFormWriter.swift` | Incremental save (shared with TRANSFORM) |
| `Sources/PDFEditorCore/CommitFlow.swift` | Signing flow (shared with COMMIT) |
| `Sources/PDFEditorApp/BatchMergeSheet.swift` | PDF merge (shared with TRANSFORM) |
| `Sources/PDFEditorCore/PdfCpuBatchProcessor.swift` | External tool operations (shared with TRANSFORM) |

---

# 9. COMPARISON WITH READER JTBD ANALYSIS

| Dimension | Reader analysis depth | Creator analysis depth | Gap |
|---|---|---|---|
| Jobs analyzed | 19 (READ, FIND, UNDERSTAND, INTERACT, etc.) | 3 (CREATE, DESIGN, PUBLISH) | Creator has fewer jobs |
| Sub-jobs per job | 5-8 per job | 5-8 per job | Parity |
| 22-dimension coverage | Full for all 19 | Full for all 3 | Parity |
| Implementation status | Many gaps documented | Most gaps are "nothing exists" | Creator further behind |
| Cross-referencing | Deep (library eval, companion, etc.) | Moderate (references reader) | Creator less connected |
| Roadmap | Detailed phases with priorities | Detailed phases with priorities | Parity |

The creator analysis is structurally complete but reveals a stark reality: **the creator surface is almost entirely unimplemented**. The engine exists, the data models exist, the tests exist — but there's no way for a user to actually create a document through the UI.

---

# 10. FIRST PRINCIPLES SUMMARY

## CREATE

**The user statement:** "I want to produce a document."
**The first principle:** Creation is a projection from intent to artifact. The ContentAuthor is the right engine — a pure state machine where every operation produces a new element list. The gap is the presentation layer that maps user intent to element operations.

**What we got right:**
- ContentAuthor as a pure state machine (no side effects, no file I/O)
- Full undo/redo with named operations
- Element model that's codecable (persistence-ready)
- Separation of content from rendering

**What's missing:**
- Authoring canvas (the user can't see or interact with elements)
- Paragraph flow (text is single-line, not flowing)
- Font/color selection (properties exist, UI doesn't)
- Image placement (drag-and-drop)

## DESIGN

**The user statement:** "I want this document to look professional."
**The first principle:** Design is a constraint system. Good design tools constrain choices to good outcomes — grid snapping prevents misalignment, style inheritance prevents inconsistency, master pages prevent forgotten headers. The current state is "everything is possible, nothing is guided."

**What we got right:**
- Element positioning (x/y/width/height)
- Z-index ordering
- ThemeManager (dark mode applies to creation too)

**What's missing:**
- Grid/alignment system
- Style system (paragraph + character styles)
- Master pages (repeating elements)
- Typography controls (kerning, leading, tracking)
- Color system (document palette)

## PUBLISH

**The user statement:** "I want this document to reach its audience."
**The first principle:** Publishing is a one-way gate. Once published, the document is out of your control. The app should make publishing intentional (require explicit action), reversible (keep the source), and auditable (log what was published).

**What we got right:**
- Export pipeline (PDF to file)
- Source preservation (original never overwritten)
- Audit trail (value-free logging)
- Scratch copy export (non-destructive)

**What's missing:**
- Print integration (macOS print dialog)
- Format optimization (file size, PDF/A)
- Distribution (email, web, cloud)
- Distribution tracking
