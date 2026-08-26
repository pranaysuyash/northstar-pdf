# JTBD-01: READ — First Principles Breakdown

**Date:** 2026-08-26
**Job:** "I need to consume this document's content"
**Framework:** First principles — strip away assumptions, focus on what users actually need

---

## 1. Core Principle

Reading is **perception**. The user's eyes (or screen reader) need to receive the document's content accurately, quickly, and comfortably. Any friction in perception breaks comprehension.

**Reading is not rendering.**
**Reading is understanding.**

---

## 2. What "Read" Actually Means

### 2.1 Visual Perception
The user needs to **see** the content.

**Sub-jobs:**
- See text clearly at any zoom level
- See images and diagrams correctly
- See colors accurately
- See layout as the author intended
- See without eye strain

### 2.2 Spatial Navigation
The user needs to **move** through the content.

**Sub-jobs:**
- Go to a specific page
- Scroll smoothly between pages
- Jump to a section (bookmark, outline)
- Return to previous position
- Navigate with keyboard only

### 2.3 Temporal Persistence
The user needs to **remember** where they were.

**Sub-jobs:**
- Resume where they left off
- Remember zoom level
- Remember scroll position
- Remember which pages were read

---

## 3. The Physics of Reading

### 3.1 Speed
Reading speed is limited by rendering speed.

**Budget:**
- Page render: <100ms (instant perception)
- Scroll: 60fps (smooth motion)
- Zoom: <50ms (no lag)
- Page jump: <200ms (instant navigation)

**Why:** If rendering is slow, the user's eyes wait. Waiting breaks flow. Broken flow breaks comprehension.

### 3.2 Clarity
Clarity is limited by resolution and anti-aliasing.

**Requirements:**
- Text sharp at any zoom (vector rendering)
- Images crisp at native resolution
- No artifacts (compression, scaling)
- Correct subpixel rendering

**Why:** Blurry text forces the user to squint. Squinting breaks comprehension.

### 3.3 Accuracy
Accuracy is limited by parsing and rendering fidelity.

**Requirements:**
- Correct font rendering
- Correct color space (sRGB, CMYK, PDI)
- Correct page geometry (MediaBox, CropBox, Rotate)
- Correct layer ordering (transparency, blending)

**Why:** Wrong colors or layout confuse the user. Confusion breaks comprehension.

---

## 4. What Fails in Practice

### 4.1 Rendering Failures
| Failure | Impact | Frequency |
|---|---|---|
| Slow page load | User waits, loses focus | Common on large PDFs |
| Blurry text | User squints, misreads | Common on scaled PDFs |
| Wrong colors | User misinterprets content | Common on print-ready PDFs |
| Missing images | User sees gaps | Common on embedded images |
| Broken layout | User sees gibberish | Common on complex PDFs |

### 4.2 Navigation Failures
| Failure | Impact | Frequency |
|---|---|---|
| Janky scroll | User gets motion sick | Common on large PDFs |
| Wrong page number | User gets lost | Common with custom labels |
| Lost position | User re-reads sections | Common after app switch |
| No keyboard nav | User can't read hands-free | Common in most readers |

### 4.3 Persistence Failures
| Failure | Impact | Frequency |
|---|---|---|
| Position lost on reopen | User re-finds place | Common in web readers |
| Zoom reset | User re-zooms | Common in mobile readers |
| No reading history | User can't backtrack | Common in all readers |

---

## 5. What "Good" Looks Like

### 5.1 Instant Perception
- Page appears before the user finishes moving their finger
- Text is sharp enough to read without squinting
- Colors match the author's intent
- Layout is preserved exactly

### 5.2 Effortless Navigation
- Scroll is buttery smooth
- Page numbers match expectations
- Bookmarks work instantly
- Keyboard shortcuts work everywhere

### 5.3 Seamless Persistence
- Reopen returns to exact position
- Zoom level persists
- Reading history is maintained
- Cross-device sync (optional)

---

## 6. The User's Mental Model

When a user "reads" a PDF, they're actually doing:

1. **Load** — "Open this document"
2. **Orient** — "Where am I? What's this about?"
3. **Scan** — "What's interesting here?"
4. **Read** — "Let me consume this section"
5. **Navigate** — "What's next?"
6. **Return** — "Where was I?"

Each step has friction points. The best reader minimizes friction at every step.

---

## 7. Who Uses What — Sub-Job Weighting

The three sub-jobs are universal, but **how much each matters** varies by user and context.

### 7.1 User × Sub-Job Matrix

| User | Visual Perception | Spatial Navigation | Temporal Persistence | Why |
|---|---|---|---|---|
| **Student** | Critical | Medium | Medium | Needs to read carefully, re-reads sections |
| **Lawyer** | Low | Critical | Critical | Skims, but needs to jump between clauses and return |
| **Executive** | Low | Critical | Low | Skims summaries, jumps to conclusions |
| **Developer** | Medium | Critical | Low | Search-heavy, jumps to API reference |
| **Accountant** | Medium | Low | Low | Reads linearly, fills forms |
| **Designer** | Critical | Medium | Low | Needs color accuracy, layout fidelity |
| **Admin** | Low | Medium | Low | Batch processes, minimal reading |
| **Archivist** | Medium | Low | Critical | Long-term preservation, rare access |

### 7.2 Context × Sub-Job Matrix

The same user weights differently depending on **what they're doing**.

| Context | Visual Perception | Spatial Navigation | Temporal Persistence |
|---|---|---|---|
| **First encounter** | Critical | Medium | Low |
| **Deep reading** | Critical | Medium | Critical |
| **Skimming** | Low | Critical | Low |
| **Reference lookup** | Low | Critical | Low |
| **Review/approval** | Medium | Critical | Critical |
| **Form filling** | Low | Medium | Critical |
| **Signing** | Low | Medium | Critical |
| **Printing** | Critical | Low | Low |

### 7.3 The Insight

**One size does NOT fit all.**

A student reading a textbook needs **visual clarity** (sharp text, correct colors).
A lawyer reviewing a contract needs **navigation** (jump between clauses, return to position).
An executive skimming a report needs **speed** (instant page loads, quick search).

**The best reader adapts to the user's context, not just their identity.**

### 7.4 What This Means

We shouldn't build one "read mode." We should build **reading modes** that optimize for different contexts:

- **Study mode** — visual clarity, progress tracking, annotation tools
- **Review mode** — fast navigation, position persistence, comparison tools
- **Skim mode** — instant rendering, search-first, summary extraction
- **Reference mode** — keyboard navigation, bookmark management, quick jump

---

## 8. Our Current State

### 8.1 What Works
- PDFKit renders accurately
- Search works
- Outlines work
- Page navigation works
- Zoom works

### 8.2 What's Weak
- Large PDFs can be slow
- No reading position persistence
- No reading history
- No dark mode (eye strain)
- No reflow (mobile reading)

### 8.3 What's Missing
- Instant rendering for large PDFs
- Reading progress tracking
- Cross-device position sync
- Accessibility (VoiceOver)
- Night mode / blue light filter

---

## 9. The Gap

The gap between "viewer" and "reader" is:

| Viewer | Reader |
|---|---|
| Renders pixels | Renders meaning |
| Shows pages | Shows progress |
| Displays content | Preserves context |
| Requires attention | Supports flow |

**A viewer shows you the document.**
**A reader helps you consume it.**

---

## 10. Strategic Implications

### What to keep:
- PDFKit rendering (accurate, fast)
- Search and outlines (navigation)
- Zoom and scroll (interaction)

### What to add:
- Reading position persistence
- Reading progress tracking
- Dark mode / eye strain reduction
- Reflow for mobile

### What to avoid:
- Cloud rendering (breaks privacy)
- Complex UI (breaks simplicity)
- Feature bloat (breaks focus)

---

## 11. The One-Line Summary

**Reading is perception. The best PDF reader makes content appear instantly, navigate effortlessly, and persist seamlessly — so the user can focus on comprehension, not the tool.**

---

## 12. Evidence

- First principles analysis (what is reading?)
- User behavior patterns (what do users actually do?)
- Performance budgets (what's fast enough?)
- Current product capabilities (what do we have?)
- Competitive analysis (what do others do?)
