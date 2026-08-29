# Rendering Pipeline 1st-Principles Architecture

**Date:** 2026-08-28
**Status:** Observed + Verified
**Evidence tier:** Tier 3 (integration — pipeline wired into app, tests pass)
**Test sensitivity:** S1 (all tests pass), S2 (overlay hack reverted before rebuild)

## 1. Decision context

The rendering pipeline (`ProgressiveRenderer`, `TileBasedDisplay`, `RenderingPipeline`) existed as protocol abstractions and CLI wrappers. PDFKit handled all actual pixel rendering. The pipeline's output was never composited into the view.

**Question:** What is the first-principles solution for wiring the pipeline into the UI?

## 2. Options considered

### Option A: Overlay hack (rejected)
- PDFKit renders invisibly at zPosition 0
- Pipeline tiles render on top at zPosition 50
- **Problems:** redundant rendering (both render same pixels), visual conflict (opacity blending), interaction disconnect (PDFKit handles taps on its own rendering), wasted memory

### Option B: Pipeline as sole renderer (chosen)
- Pipeline renders pages as images via `renderPageProgressive()` and `getViewportTiles()`
- PDFKit demoted to data source only (text rects, link URLs)
- Interaction overlay reads from pipeline text extraction for hit-testing
- **Advantages:** single source of truth for pixels, progressive quality works naturally, no redundant rendering

### Option C: Hybrid mode (implemented as fallback)
- PipelineTileOverlayView composites pipeline tiles above PDFKit
- Used when full pipeline replacement isn't desired (e.g., when PDFKit annotations are needed)
- Less ideal than Option B but pragmatic for annotation-heavy workflows

## 3. Implementation

### PipelineCanvasView (`Sources/PDFEditorApp/PipelineCanvasView.swift` — 383 lines)
- NSViewRepresentable wrapping NSScrollView + PipelinePageView
- Pipeline renders pages as images via `renderPageProgressive()`
- Text selection via `TextBlock` hit-testing from pipeline extraction
- Zoom, scroll, page navigation all wired to pipeline state
- Progressive quality: low DPI → medium → high as user stops scrolling

### PipelineTileOverlayView (`Sources/PDFEditorApp/PipelineTileOverlayView.swift` — 162 lines)
- NSView compositing pipeline tiles as CALayers above PDFKit
- Debounced reload (50ms) on scroll/zoom changes
- Viewport-aware tile management — only renders visible tiles
- Progressive quality upgrades tracked per-tile

### PipelinePageView (`Sources/PDFEditorApp/PipelinePageView.swift`)
- Exists as orphaned prototype — superseded by PipelineCanvasView
- Preserved for reference; not wired into app

## 4. Architecture (1st principles)

```
PipelineCanvasView (NSViewRepresentable)
  └── NSScrollView (zoom, scroll)
        └── PipelinePageView (pipeline renders pages as images)
              ├── CALayer (pipeline tile images — THE visible pixels)
              │     └── renderPageProgressive() → low → medium → high
              └── InteractionOverlayView (text selection, links)
                    └── reads: pipeline extractText() → [TextBlock]

PDFKit: demoted to data source
  ├── extractText() → TextBlock.bounds for hit-testing
  ├── loadDocument() → pipeline caching
  └── NOT used for rendering
```

**Alternative (hybrid mode):**
```
PDFKit rendering (zPosition 0) — INVISIBLE, interaction only
  └── PipelineTileOverlayView (zPosition 50) — VISIBLE, pixel source
        └── FreezePaneOverlayView (zPosition 100) — frozen rows/cols
```

## 5. Evidence

- 10 tile overlay tests pass (`PipelineTileOverlayTests.swift`)
- 21 architecture tests pass (`PipelineRendererArchitectureTests.swift`)
- 1199/1199 tests pass overall
- Progressive render times tracked in `PageTile.renderTimeMs`

## 6. Doctrine alignment

- §3 Do things smartly: pipeline handles rendering, PDFKit handles data — separation of concerns
- §5 Evidence-based: every render is measurable, tile times tracked
- §8 Capability routing: different DPI for different zoom levels
- §12 Privacy stays value-free: overlay never inspects content, just positions

## 7. Alternatives not taken

- **GPU rendering:** Pipeline uses CPU-based tile rendering. GPU acceleration (Metal/Vulkan) is a future exploration.
- **WebGPU fallback:** Not applicable — native app uses AppKit.
- **Full PDFKit replacement:** PipelineCanvasView replaces PDFKit rendering entirely. This is the true 1st-principles solution. The tile overlay is the pragmatic hybrid.

## 8. Risks

- PDFKit may still handle some rendering (annotations, form fields) even in hybrid mode
- Pipeline rendering adds latency on first page load (progressive quality mitigates)
- Memory usage: pipeline tiles + PDFKit data source = ~2x memory vs PDFKit alone

## 9. Open questions

- Should PipelineCanvasView be the default, or should hybrid mode remain default?
- How does this interact with PDFKit annotation editing (form fields, signatures)?
- GPU rendering path for high-DPI displays?

## 10. Addendum — renderer toggle wiring (2026-08-28, same day)

The earlier architecture decision left one wiring gap: the pipeline was a
**drop-in replacement** for PDFKitView but nothing switched between them.
This addendum records the toggle wiring that closed the gap.

### What was wired

- `AppModel.usePipelineRendering: Bool = true` — **pipeline is the default**
  renderer (matches the 1st-principles decision; PDFKit is the fallback).
- `DocumentCanvasView.pdfCanvas` switches between `PipelineCanvasView` and
  `PDFKitView` on this flag, sharing the same callbacks and interaction
  surface (projection revision, view mode, rotation, candidates, fields,
  fill highlights, inline editor, presentation ops, commit/dismiss).
- `PipelineCanvasView` was extended to the full PDFKitView interface so the
  switch is source-compatible.
- `ContentView` exposes a **Pipeline Renderer toggle** inside the reading-mode
  menu (cpu icon = pipeline active, doc.viewfinder = PDFKit).

### Behavior matrix

| Mode | Pixels | Interaction | Fallback |
|---|---|---|---|
| Pipeline (default) | PipelineCanvasView renders pages as images | Text selection via TextBlock hit-testing | PDFKit demoted to data source only |
| PDFKit (legacy) | PDFKit renders | Full existing behavior | — |

### Evidence

- Full suite passes with pipeline as default (1294/1294 at wiring time;
  1301/1301 after fingerprint work).
- Files: `AppModel.swift` (+2 lines), `DocumentCanvasView.swift` (+87 net),
  `PipelineCanvasView.swift` (383 → 446 lines), `ContentView.swift` (+8).

### Open follow-ups (unchanged from §9)

- PDFKit annotation editing (form fields, signatures) interaction with
  pipeline mode remains to be verified interactively.
- GPU rendering path for high-DPI displays remains open.
