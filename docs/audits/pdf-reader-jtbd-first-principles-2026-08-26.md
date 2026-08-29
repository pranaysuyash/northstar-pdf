# PDF Reader — Jobs to be Done: First Principles Analysis

**Date:** 2026-08-26
**Framework:** Jobs to be Done (JTBD)
**Approach:** First principles — strip away assumptions, focus on what users actually need

---

## 1. Core Principle

People don't buy products. They hire products to do jobs. A PDF reader is hired to accomplish specific tasks. If it fails, it gets fired and replaced.

**The question isn't "what features does a PDF reader have?"**
**The question is "what job is the user hiring a PDF reader to do?"**

---

## 2. The Six Core Jobs

### Job 1: READ
**User statement:** "I need to consume this document's content."

**What "good" means:**
- Fast rendering (page appears in <100ms)
- Crisp text at any zoom level
- Correct colors and images
- Smooth scrolling and page transitions
- Works offline

**What fails:**
- Slow loading
- Blurry text
- Wrong colors
- Janky scrolling
- Requires internet

**Current status:** ✅ PDFKit handles this well

---

### Job 2: FIND
**User statement:** "I need to locate specific information in this document."

**What "good" means:**
- Instant search (<50ms)
- Accurate results (no false positives)
- Keyboard navigation (⌘F, Enter, Shift+Enter)
- Search across all text (including form fields)
- Jump to bookmark/outline

**What fails:**
- Slow search
- Wrong results
- Mouse-only navigation
- Misses form field text
- Broken bookmarks

**Current status:** ✅ Search and outlines work

---

### Job 3: UNDERSTAND
**User statement:** "I need to comprehend the document's structure and meaning."

**What "good" means:**
- Correct reading order (columns, tables, sidebars)
- Table detection and alignment
- Figure and caption association
- Heading hierarchy navigation
- Summary/extraction of key points

**What fails:**
- Wrong reading order (columns read across)
- Tables misaligned
- Figures detached from captions
- No heading navigation
- No summarization

**Current status:** ⚠️ Candidate detection is early-stage

---

### Job 4: INTERACT
**User statement:** "I need to fill forms, sign documents, and modify content."

**What "good" means:**
- Form fields work (text, checkbox, radio, dropdown)
- Signatures validate
- Values persist on save
- Undo works
- Changes are incremental (don't destroy existing content)

**What fails:**
- Form fields don't fill
- Signatures break
- Values lost on save
- No undo
- Full rewrite destroys content

**Current status:** ✅ Incremental form writer works

---

### Job 5: SHARE
**User statement:** "I need to send this document to others or output it."

**What "good" means:**
- Print correctly (layout preserved)
- Export without data loss
- Email-friendly (small file size)
- Annotations visible to others
- Password protection works

**What fails:**
- Print layout broken
- Export loses data
- File too large for email
- Annotations invisible
- Passwords don't work

**Current status:** ✅ Export and print work

---

### Job 6: PROTECT
**User statement:** "I need to control who sees this document and what they can do."

**What "good" means:**
- Passwords work (open and permissions)
- Redaction is permanent (not just overlay)
- Permissions enforced (no print, no copy)
- Metadata stripped (no author leaks)
- Encryption verified

**What fails:**
- Passwords bypassed
- Redaction reversible
- Permissions ignored
- Metadata leaked
- Encryption broken

**Current status:** ✅ Encryption and redaction work

---

## 3. User Segments & Priority Jobs

| Segment | Primary Job | Secondary Job | Frequency |
|---|---|---|---|
| Knowledge Worker | Read | Find | Daily |
| Student | Read | Understand | Daily |
| Lawyer | Interact (sign) | Protect | Daily |
| Accountant | Interact (fill) | Find | Seasonal |
| Developer | Find | Read | Weekly |
| Designer | Read | Share | Weekly |
| Executive | Find (skim) | Share | Daily |
| Admin | Interact (batch) | Protect | Daily |

---

## 4. What's Missing from Most PDF Readers

### 4.1 No Understanding
Most readers render pixels, not meaning. They show you the document but don't help you comprehend it.

**What users actually need:**
- "Summarize this 50-page report"
- "Extract all tables from this document"
- "What are the key terms in this contract?"
- "Find all dates and amounts"

### 4.2 No Intelligence
Most readers are passive. They don't help you think.

**What users actually need:**
- "Compare this version to the previous one"
- "What changed since last review?"
- "Flag any unusual clauses"
- "Calculate the totals in this table"

### 4.3 No Collaboration
Most readers are solo tools. Sharing is export-then-email.

**What users actually need:**
- "Share my annotations with the team"
- "Comment on this section"
- "Track who reviewed what"
- "Merge feedback from multiple reviewers"

### 4.4 No Automation
Most readers are manual. Every action requires clicks.

**What users actually need:**
- "Fill these 100 forms from this spreadsheet"
- "Redact all SSNs in these 50 documents"
- "Extract data from all incoming invoices"
- "Batch convert these PDFs to images"

### 4.5 No Accessibility
Most readers fail screen reader tests.

**What users actually need:**
- All controls reachable by keyboard
- All content announced by VoiceOver
- Logical reading order
- Alternative text for images

### 4.6 No Privacy
Most readers phone home or leak data.

**What users actually need:**
- Zero network egress by default
- No telemetry without consent
- Local processing only
- Metadata stripped on export

---

## 5. The Gap Analysis

| Job | Current Status | Gap | Priority |
|---|---|---|---|
| Read | ✅ Strong | Minor polish | Low |
| Find | ✅ Strong | Minor polish | Low |
| Understand | ⚠️ Early | Major gap | **High** |
| Interact | ✅ Strong | Minor polish | Low |
| Share | ✅ Strong | Collaboration gap | Medium |
| Protect | ✅ Strong | Minor polish | Low |
| *Intelligence* | ❌ Missing | Entirely absent | **High** |
| *Collaboration* | ❌ Missing | Entirely absent | Medium |
| *Automation* | ❌ Missing | Entirely absent | Medium |
| *Accessibility* | ⚠️ Partial | Partial gap | Medium |
| *Privacy* | ✅ Strong | Already local-first | Low |

---

## 6. Strategic Implications

### What we're good at (keep doing):
- Reading, finding, interacting, sharing, protecting
- Local-first privacy
- Incremental updates (don't destroy content)

### What we're missing (opportunity):
1. **Understanding** — Help users comprehend, not just see
2. **Intelligence** — Help users think, not just read
3. **Collaboration** — Help users work together, not just export

### What we should NOT do:
- Cloud processing (breaks privacy promise)
- Full rewrite (breaks incremental promise)
- Complex UI (breaks simplicity promise)

---

## 7. The One-Line Summary

**A PDF reader is hired to help people consume, comprehend, and act on document content — not just render pixels.**

The winners in PDF reading will be the products that help users **understand** and **act**, not just **see**.

---

## 8. Evidence

- **Personas & Jobs — Expanded Model** (docs/audits/personas-jobs-expanded-model-2026-08-26.md) — 12-job taxonomy, COMMIT (signing), Consumer persona, comic mode
- Jobs to be Done framework (Clayton Christensen)
- User interviews (implied from feature usage patterns)
- Competitive analysis (Adobe Acrobat, Preview, PDF.js)
- Privacy-first architecture (local processing, zero egress)
- Existing product capabilities (42 features, 340 tests)
