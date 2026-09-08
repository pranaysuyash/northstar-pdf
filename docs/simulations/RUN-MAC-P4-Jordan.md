# RUN-MAC-P4 — Jordan Lee (Admissions Assistant, Bursty) — Native Mac lane

**Date:** 2026-09-07 · **Surface:** Native macOS, PDFKit provider via prebuilt `.build/debug/PDFContractHarness` + static GUI inventory of `Sources/PDFEditorApp` (no display automation in this env)
**Persona goal:** First-run clarity in < 5 min during a 200-application burst: open → understand → complete → review, with zero training.
**Fixture (mini-manifest `evidence/mac-P4-manifest.md`):**
- `benchmark/results/navigation-corpus/navigation-metadata.pdf` (3 pages, nested outlines, page-label ranges, URLs, attachment — exercises Reader/Understand surfaces)

## Steps (expected → observed)
| # | Step | Expected | Observed | Result |
|---|------|----------|----------|--------|
| 1 | Inspect navigation corpus | opens, 3 pages, structure extracted | `inspected`, digest `80216d04…`, 3 pages, outlines/labels/links in contract, preflight ✓, `validated` | PASS |
| 2 | Harness exit code | 0 | `EXIT:0` | PASS |
| 3 | GUI surface inventory (static) | five-mode journey + discovery affordances exist in the shipping shell | `ContentView`, `DocumentBrowserView`, `DocumentSplitView`, `PageThumbnailRailView`, `HumanReviewPanelView`, `ExportReviewReceiptView`, `SearchEngine` (core), shortcuts via `AppCommands` all present in `Sources/PDFEditorApp` | PASS (static) |

## Verdict: PASS (headless) / GUI CLICK-THROUGH OPEN
Document-structure extraction (the Understand-mode fuel: outlines, labels, links, attachments) works natively. What Jordan actually experiences — mode rail, thumbnails, search, shortcuts help, diff view — exists in the app sources but was *inventoried, not clicked* in this environment (no display automation). The earlier web-core discoverability sweep (P4 web) is superseded per launch priority and does not substitute for a native click-through.

## Follow-ups
1. On a Mac with display: launch the built `PDFEditor` (`swift run PDFEditor` or `.build/debug/PDFEditor`), open the navigation fixture, and walk Reader → Understand → Complete → Organize → Review with a timer. Record time-to-first-fill.
2. Bursty-pricing check stands: Jordan's usage pattern supports one-time ($79, D-052), not subscription — already reflected in decisions.
