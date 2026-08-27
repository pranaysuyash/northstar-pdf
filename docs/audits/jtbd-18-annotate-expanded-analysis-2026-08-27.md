# JTBD-18 ANNOTATE — Expanded 22-Dimension Analysis

**Date:** 2026-08-27
**Framework:** Expanded Analytical Framework (22 dimensions)
**Job:** "I need to mark up and comment on this document"
**Status:** First-principles, long-term, doctrine-aligned analysis
**Extends:** `personas-jobs-expanded-model-2026-08-26.md` §11.1

---

## Purpose

ANNOTATE is the commentary job — adding a layer of meaning on top of a document without modifying the document itself. It's the Reviewer's primary job: the markup IS the product. This analysis maps every dimension from first principles.

---

## 1. WHO

### 1.1 Person

| Persona | Core Need | Expertise | Frequency | Our Support |
|---|---|---|---|---|
| Legal reviewer | Clause-by-clause markup | Legal | Daily | ✅ Highlight + note |
| Editor | Manuscript feedback | Publishing | Daily | ⚠️ No reply threads |
| Teacher | Grading + feedback | Education | Daily | ⚠️ Basic marks only |
| Student | Study highlights | Academic | Daily | ✅ Highlight + note |
| Researcher | Paper annotations | Academic | Weekly | ⚠️ No structured review |
| Manager | Approval marks | Business | Weekly | ⚠️ Basic marks only |
| Compliance officer | Audit marks | Regulatory | Weekly | ⚠️ No export format |
| Translator | Translation notes | Linguistic | Daily | ⚠️ No sidecar export |

### 1.2 Actor

| Actor | How they annotate | Our support |
|---|---|---|
| Sighted human | Visual highlighting | ✅ Mark model exists |
| Keyboard user | Shortcut-based marking | ⚠️ No shortcuts defined |
| Touch user | Finger-based marking | ❌ No touch support |
| Screen reader user | Audio annotation | ❌ No accessible annotation |
| Automated process | Programmatic annotation | ⚠️ Sidecar is machine-readable |

### 1.3 Stakeholder

| Stakeholder | Impact of annotation failure | Severity |
|---|---|---|
| Reviewer | Marks lost, rework needed | HIGH |
| Author | Feedback unclear | HIGH |
| Organization | Compliance evidence missing | CRITICAL |
| Student | Study material lost | MEDIUM |
| Legal team | Review evidence destroyed | CRITICAL |

---

## 2. WHAT

### 2.1 Thing (What Gets Annotated)

| Object | Annotation challenge | Our capability | Gap |
|---|---|---|---|
| Text paragraph | Highlight, note, underline | ✅ 5 mark types | Small |
| Form field | Field-level comment | ⚠️ Form fill exists, no comments | Medium |
| Image region | Visual markup | ❌ No image annotation | Large |
| Table cell | Cell-level comment | ⚠️ Table detection exists | Medium |
| Signature area | Signature verification mark | ⚠️ Signature guard exists | Small |
| Page margin | Margin note | ⚠️ Notes exist, no margin UI | Small |
| Cross-page reference | Link between marks | ❌ No cross-reference | Large |

### 2.2 Action

| Action | Frequency | Our support | Priority |
|---|---|---|---|
| Highlight text | Every session | ✅ AnnotationMark.highlight | CRITICAL |
| Add note | Most sessions | ✅ AnnotationMark.note | CRITICAL |
| Underline text | Many sessions | ✅ AnnotationMark.underline | HIGH |
| Strikethrough | Some sessions | ✅ AnnotationMark.strikethrough | MEDIUM |
| Freehand draw | Rare | ✅ AnnotationMark.freehand | LOW |
| Search annotations | Most sessions | ✅ AnnotationStore.search | HIGH |
| Export annotations | Some sessions | ✅ JSON/MD/plaintext export | HIGH |
| Tag annotations | Some sessions | ✅ AnnotationMark.tags | MEDIUM |
| Reply to mark | Often | ❌ No reply system | HIGH |
| Delete mark | Some sessions | ✅ AnnotationStore.delete | HIGH |
| Toggle visibility | Some sessions | ✅ AnnotationMark.isVisible | MEDIUM |
| Color-code marks | Most sessions | ✅ 8 preset colors | HIGH |

### 2.3 Artifact

| Artifact | Purpose | Our support |
|---|---|---|
| AnnotationMark | Individual mark (highlight, note, etc.) | ✅ |
| AnnotationStore | Per-document mark collection | ✅ |
| Sidecar JSON | Portable annotation file | ✅ |
| Markdown export | Human-readable review sheet | ✅ |
| Plain text export | Simple mark list | ✅ |
| Review report | Aggregated review summary | ❌ Not implemented |
| Mark heatmap | Visual density of marks per page | ❌ Not implemented |

---

## 3. WHEN

### 3.1 Sequence (The Annotation Lifecycle)

| Phase | What happens | Our support |
|---|---|---|
| 1. First read | User reads document | ✅ |
| 2. Mark creation | User creates highlight/note | ⚠️ No creation UI yet |
| 3. Mark review | User reviews their own marks | ✅ Search + filter |
| 4. Mark refinement | User edits note content | ✅ AnnotationStore.update |
| 5. Mark organization | User tags/categorizes marks | ✅ AnnotationMark.tags |
| 6. Mark export | User exports marks for sharing | ✅ Export formats |
| 7. Mark merge | User merges with partner's marks | ✅ AnnotationMerger |
| 8. Mark archival | User archives old marks | ❌ No archival |

### 3.2 Duration

| Activity | Duration | Our support |
|---|---|---|
| Create a highlight | 2 seconds | ✅ Fast model |
| Write a note | 30 seconds | ✅ Note field |
| Search annotations | 5 seconds | ✅ Fast search |
| Review all marks | 5-30 minutes | ⚠️ No marks-only view |
| Export marks | 10 seconds | ✅ Fast export |
| Merge marks | 1-5 minutes | ✅ Conflict resolution |

### 3.3 Frequency

| User type | Annotation frequency | Volume |
|---|---|---|
| Legal reviewer | 50-200 marks per document | HIGH |
| Editor | 100-500 marks per manuscript | HIGH |
| Teacher | 10-50 marks per assignment | MEDIUM |
| Student | 5-20 marks per chapter | LOW |
| Manager | 2-10 marks per report | LOW |

---

## 4. WHERE

### 4.1 Location of Marks

| Location | Description | Our support |
|---|---|---|
| In-text highlight | Over selected text | ✅ Bounds-based |
| Margin note | Side of the page | ⚠️ Note exists, no margin UI |
| Above/below text | Interlinear note | ❌ No inline placement |
| Cross-page | Link between pages | ❌ No cross-reference |
| Document-level | Overall comment | ❌ No document-level note |

### 4.2 Storage Location

| Storage | Pros | Cons | Our support |
|---|---|---|---|
| In-PDF annotations | Portable, standard | Pollutes doc, permission issues | ❌ By design |
| Sidecar JSON | Clean, independent, fast | Not portable to other tools | ✅ Implemented |
| Database | Fast search, rich queries | Not portable | ❌ Not implemented |
| Cloud | Sync across devices | Privacy concerns | ❌ Not implemented |

**Our choice: Sidecar JSON** — aligns with source-preservation doctrine (§3), privacy (§12), and non-destructive design.

---

## 5. WHY

### 5.1 Reason

| Why annotate | Depth | Our support |
|---|---|---|
| Highlight important text | Surface | ✅ Highlight marks |
| Add explanatory note | Deep | ✅ Note marks |
| Flag issues for review | Surface | ✅ Strikethrough marks |
| Create study material | Deep | ✅ Highlight + note |
| Track reading progress | Surface | ⚠️ Position persistence |
| Provide feedback to author | Deep | ⚠️ No reply threads |
| Prove review happened | Compliance | ⚠️ Export exists |
| Build knowledge base | Deep | ⚠️ Search exists |

### 5.2 Consequence of Failure

| Failure | Impact | Severity |
|---|---|---|
| Marks lost | Rework, frustration | HIGH |
| Can't search marks | Time wasted finding notes | HIGH |
| Marks not portable | Can't share review | HIGH |
| Marks modify PDF | Source corrupted | CRITICAL |
| Marks invisible after close | Study material gone | HIGH |

---

## 6. HOW

### 6.1 Method

| Method | Description | Our support |
|---|---|---|
| Visual highlighting | Colored overlay on text | ✅ Mark model |
| Text notes | Free-form text attached to mark | ✅ Note field |
| Structured tags | Categorical labels | ✅ Tag system |
| Color coding | Visual categorization | ✅ 8 colors |
| Search/filter | Find specific marks | ✅ Query system |
| Export | Share marks externally | ✅ 3 formats |
| Reply/thread | Discussion on marks | ❌ Not implemented |
| Voice note | Audio annotation | ❌ Not implemented |

### 6.2 The Annotation Data Model

```swift
AnnotationMark {
  id: UUID                    // Unique identifier
  type: AnnotationType        // highlight/underline/note/strikethrough/freehand
  pageIndex: Int              // Where in the document
  bounds: PDFRect             // Exact region
  selectedText: String        // What was marked (for search)
  note: String                // User's commentary
  color: AnnotationColor      // Visual category (8 presets)
  createdAt: Date             // When created
  updatedAt: Date             // When last modified
  isVisible: Bool             // Can be hidden without deleting
  tags: [String]              // Organizational labels
}
```

### 6.3 Store Architecture

```
AnnotationStore
├── marks: [AnnotationMark]       // All marks for current document
├── documentID: String            // Which document
├── sidecarURL: URL?              // Where to persist
├── CRUD operations               // add/update/delete
├── search (AnnotationSearchQuery) // Find marks by criteria
├── queries                       // marksForPage, allTags, marksByType
└── export (JSON/MD/plaintext)    // Share marks externally
```

---

## 7. WHO USES WHAT — Sub-Job Weighting

### 7.1 User × Sub-Job Matrix

| User | Create Marks | Search Marks | Export Marks | Tag Marks | Reply to Marks | Why |
|---|---|---|---|---|---|---|
| **Legal reviewer** | 🔴 Critical | 🔴 Critical | 🔴 Critical | 🟡 Medium | 🔴 Critical | Must prove review happened |
| **Editor** | 🔴 Critical | 🔴 Critical | 🟡 Medium | 🟡 Medium | 🔴 Critical | Discussion is the product |
| **Teacher** | 🔴 Critical | 🟡 Medium | 🟡 Medium | 🟢 Low | 🔴 Critical | Feedback is the product |
| **Student** | 🔴 Critical | 🟡 Medium | 🟢 Low | 🟢 Low | 🟢 Low | Study material |
| **Researcher** | 🔴 Critical | 🔴 Critical | 🔴 Critical | 🔴 Critical | 🟡 Medium | Citation tracking |
| **Manager** | 🟡 Medium | 🟡 Medium | 🟡 Medium | 🟢 Low | 🟢 Low | Quick marks |

### 7.2 Mark Type Usage by Persona

| Mark Type | Legal | Editor | Teacher | Student | Researcher |
|---|---|---|---|---|---|
| Highlight | 🔴 | 🔴 | 🔴 | 🔴 | 🔴 |
| Note | 🔴 | 🔴 | 🔴 | 🟡 | 🔴 |
| Underline | 🟡 | 🟡 | 🟡 | 🟡 | 🟡 |
| Strikethrough | 🔴 | 🔴 | 🟡 | 🟢 | 🟡 |
| Freehand | 🟢 | 🟢 | 🟡 | 🟢 | 🟢 |

---

## 8. CURRENT STATE — Implementation Evidence

### 8.1 What Exists

| Component | File | Status | Tests |
|---|---|---|---|
| AnnotationMark model | AnnotationMarks.swift | ✅ Complete | Codable, Sendable |
| AnnotationType enum | AnnotationMarks.swift | ✅ 5 types | highlight/underline/note/strikethrough/freehand |
| AnnotationColor enum | AnnotationMarks.swift | ✅ 8 colors | yellow/green/blue/pink/orange/purple/red/gray |
| AnnotationStore | AnnotationStore.swift | ✅ Complete | CRUD + search + export |
| AnnotationSearchQuery | AnnotationMarks.swift | ✅ Complete | type/color/text/page/tags/visibility |
| Export (JSON) | AnnotationStore.swift | ✅ Complete | ISO8601 dates, sorted keys |
| Export (Markdown) | AnnotationStore.swift | ✅ Complete | Grouped by page, emoji icons |
| Export (Plain text) | AnnotationStore.swift | ✅ Complete | Simple list format |
| Sidecar persistence | AnnotationStore.swift | ✅ Complete | .pdf.annotations.json |
| Tag system | AnnotationMarks.swift | ✅ Complete | Tags array + allTags query |
| Visibility toggle | AnnotationMarks.swift | ✅ Complete | isVisible flag |
| Study loop (marks-based) | StudyLoop.swift | ✅ Complete | Review/recall/quiz modes |
| Collaboration merge | AnnotationMerger.swift | ✅ Complete | 4-way merge with conflicts |

### 8.2 What's Missing

| Gap | Severity | Priority | First-principle reason |
|---|---|---|---|
| Mark creation UI | CRITICAL | CRITICAL | Can't create marks without UI |
| Mark overlay rendering | CRITICAL | CRITICAL | Marks invisible without rendering |
| Reply/thread system | HIGH | HIGH | Discussion is the product for editors |
| Review report | MEDIUM | HIGH | Aggregated view of all marks |
| Mark heatmap | LOW | MEDIUM | Visual density indicator |
| Cross-page references | LOW | LOW | Advanced linking feature |
| Voice notes | LOW | LOW | Accessibility enhancement |

### 8.3 Critical Gap: No Creation UI

**The annotation model and store are complete, but there is no UI to create marks.** The user cannot:
1. Select text and create a highlight
2. Click to add a note
3. Draw freehand marks

This is the single largest gap — the data model exists, the persistence exists, the search exists, the export exists, but the creation entry point is missing.

---

## 9. FIRST-PRINCIPLES ASSESSMENT

### 9.1 Is This a Real Job?

**Yes.** The expanded model (§11.1) correctly identifies ANNOTATE as distinct from INTERACT:
- INTERACT operates the document (fills fields, changes data)
- ANNOTATE adds commentary (changes no document data)

The evidence: the Reviewer persona's primary output IS the annotation. For a legal reviewer, the highlights and notes ARE the deliverable.

### 9.2 Are We Aligned to Doctrines?

| Doctrine | Alignment | Evidence |
|---|---|---|
| §3 Do things smartly | ✅ | Sidecar = non-destructive, portable |
| §5 Evidence-based | ✅ | Timestamps on every mark |
| §8 Capability activation | ✅ | Annotations are opt-in per document |
| §12 Privacy value-free | ✅ | Marks are user's commentary, not document content |

### 9.3 The Build Order is Correct

```
ANNOTATE (J18) — foundation
    ↓
LEARN (J3) — uses marks as substrate
    ↓
COLLABORATE (J19) — marks that travel
```

ANNOTATE is the right starting point. But the critical gap (no creation UI) means the foundation exists but the entry point doesn't.

---

## 10. LONG-TERM VISION

### 10.1 The Annotation Spectrum

```
BASIC (now)              STRUCTURED (future)      INTELLIGENT (far future)
Highlight + Note         Reply threads + Templates  AI-suggested marks
5 types, 8 colors       Custom types + workflows   Auto-categorization
Search + export         Review reports + scoring   Sentiment analysis
✅ Implemented          ❌ Not started            ❌ Not started
```

### 10.2 What Basic Annotations Prove

Before building threads and templates, basic annotations answer:
1. Do users actually highlight and note? (usage signal)
2. Which mark types are most used? (type signal)
3. How many marks per document? (volume signal)
4. Do users export? (sharing signal)
5. Do users search? (retrieval signal)

---

## 11. EVIDENCE

- `Sources/PDFEditorCore/AnnotationMarks.swift` — mark model (5 types, 8 colors, tags, visibility)
- `Sources/PDFEditorCore/AnnotationStore.swift` — CRUD + search + export + sidecar persistence
- `Tests/PDFEditorCoreTests/AnnotationMarksTests.swift` — 29 tests
- `Sources/PDFEditorCore/StudyLoop.swift` — marks-based study loop (LEARN dependency)
- `Sources/PDFEditorCore/AnnotationMerger.swift` — merge algorithm (COLLABORATE dependency)
- `docs/audits/personas-jobs-expanded-model-2026-08-26.md` §11.1 — original analysis
