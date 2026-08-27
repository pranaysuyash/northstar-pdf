# JTBD-01 READ — Layouts & Contextual Modes (First Principles)

**Date:** 2026-08-26
**Status:** Design exploration — some items implemented, some ideas unvalidated
**Source:** Discussion with user; extends `jtbd-01-read-expanded-analysis-2026-08-26.md`
**Doctrine alignment:** §3 (do things smartly), §8 (capability routing), long-term foundations

---

## 1. First Principle: Layout Is a Viewport Decision

The READ job's Display stage answers one question: **what should be visible at the same time, and in what spatial relationship?**

A single page is one answer. But reading is rarely single-page-only. The reader's actual needs:

| Need | Layout answer |
|---|---|
| "I want context + detail" | Split view / freeze panes |
| "I want to compare" | Diff modes, side-by-side |
| "I want reference material available" | Window-in-window |
| "I want the table to stay readable" | Frozen headers / sortable grid |
| "I want the image big" | Image-open mode |

So layout is **not a decoration** — it is a *routing decision* about which regions of a document are primary (interactive, scrolling) and which are reference (fixed, pinned).

---

## 2. Layout Taxonomy (READ)

### 2.1 Window-in-Window
A secondary pane showing a different page/region of the *same* document (or a different document), floating above or docked within the main view.

- **Job:** "I need to check page 12's figure while writing on page 3"
- **First principle:** Reference material should not force navigation away from primary work
- **Status:** discussed with prior agent; not implemented

### 2.2 Split View
The document area divided into two independent scrollable regions (vertical or horizontal split).

- **Job:** "I need to see two parts of the document at once"
- **First principle:** independent scroll positions per pane
- **Status:** discussed with prior agent; not implemented

### 2.3 Diff Modes
Compare source vs. edited document — overlay highlights on canvas, or side-by-side comparison.

- **Status:** ✅ **Implemented** — visual diff overlay + side-by-side comparison exist in the app (DiffComparisonView, diff overlay in DocumentCanvasView)

### 2.4 Freeze / Fixed Panes (Excel-style) — **NEW, not discussed before**
Pin a region of the page so it stays visible while the rest scrolls.

- **Job:** "I need the table header / column labels / a spec row to stay visible while I scan the body"
- **First principle:** *reference context* should be spatially stable while *detail* scrolls
- **Examples in PDF:**
  - Wide tables → freeze header row (column names)
  - Spreadsheets → freeze first N columns (row IDs, dates)
  - Long forms → freeze the field labels column
  - Legal docs → freeze running header/footer
- **Mechanics:** the viewport splits into a pinned region + scrollable region; the pinned region re-composites the same page region at the same scale while the scrollable region translates.
- **Status:** idea — unvalidated. Requires the tile-based renderer to composite pinned + scrollable regions, which the pipeline now supports.

### 2.5 Reading Modes (from earlier analysis)
Study / Skim / Reference / Review — optimize the *presentation* for the *context*.

---

## 3. Content-Aware Modes (Context Routing)

First principle: **the document's structure should decide its presentation.**

The parser already detects content type per page/region (text blocks, tables, headings, images). Route the *mode* from that:

| Content detected | Suggested mode | Why |
|---|---|---|
| **Table** | Scrollable + sortable grid | Tables are data; data wants sorting, filtering, column freeze |
| **Image / diagram** | Open-as-image (zoom, pan, extract) | Images want pixel-level inspection, not text flow |
| **Form** | Form mode (already exists) | Forms want field navigation, not reading |
| **Legal / contract** | Reference mode (freeze headers) | Legal docs want clause + header context |
| **Wide table with frozen header** | Freeze-pane mode | Header stays while body scrolls |
| **Multi-column article** | Single-column reflow (where permitted) | Reflow aids linear reading |

**Status:** the detection layer exists (`ImprovedTextExtractor` detects blocks/tables/headings); the *routing* does not. This is a natural next feature — the pipeline already returns structured extraction, so mode selection is a pure function of content.

---

## 4. Ideas (Unvalidated — capture only)

These are not commitments; they are recorded so they are not lost:

1. **Freeze-pane gesture:** drag a divider to pin a column/row — Excel-like
2. **Sortable table view** — click column header to sort extracted table data
3. **Column freeze preset** — detect table structure, offer "freeze header row" automatically
4. **Image passthrough** — double-click an image region to open it in a zoom viewer
5. **Header/footer freeze** — auto-pin running headers on long documents
6. **Multi-view memory** — remember which layout was active per document (extends layout restore)
7. **Layout presets** — "Compare", "Study", "Table" layouts as one-click modes
8. **Region pinning across pages** — pin a region that persists while flipping pages (e.g., a formula reference)

---

## 5. Relationship to Existing Work

| Existing piece | How it connects |
|---|---|
| `TileBasedDisplay` | Freeze panes need tile rendering of pinned + scrollable regions |
| `RenderingPipeline` | Mode routing is a pure function of `extractText()` structure |
| `ImprovedTextExtractor` | Already detects tables, headings, blocks — the mode signal |
| Layout restore (RG-057) | Per-document layout memory can extend to per-document mode |
| Diff modes | Already implemented — the reference implementation of "layout as routing" |

---

## 6. Next Steps (when prioritized)

1. **Validate freeze-pane** — a prototype: pin header row on a wide table fixture
2. **Mode routing** — map content type → suggested mode, surface as a toolbar suggestion
3. **Sortable table** — extracted table data → sortable grid (leverages table extraction)

---

**Evidence:** This doc supersedes nothing; it extends the READ analysis with layout/mode thinking and records ideas for later triage.