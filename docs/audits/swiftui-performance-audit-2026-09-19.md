# SwiftUI Performance Audit — 2026-09-19

- **Method**: code-first audit (`swiftui-performance-audit` skill workflow). Four parallel read-only sweeps over `Sources/PDFEditorApp/` (all views), `Sources/PDFEditorRecovery/AppModel.swift`, and the render paths they call, one sweep per smell class (observation fan-out, body work/identity, main-thread/image cost, layout/animation). Top findings lead-verified by direct read of the cited code before inclusion.
- **Scope**: runtime snappiness of the native app (scroll hitches, per-action latency, hangs). The known main-actor document parse at open (≤250MB sync, AppModel `open(url:)` → `PDFKitProvider.openDocument`, PDFKitProvider.swift:554) is already ledgered (MAD-004, native perf audit) and is **not** re-reported here except where render-path findings compound it.
- **Evidence status**: all findings below are code-backed. No Instruments trace has been captured yet — see Metrics/Next step.

## Summary

The app's snappiness ceiling is not one bottleneck but two, and both are confirmed in code:

1. **ContentView's toolbar body synchronously extracts the entire document and spawns a child process — on every SwiftUI body evaluation.** `matchedPresets` is an immediately-invoked closure (`{ … }()`), so `renderingPipeline.extractText()` → `PdfOxideExtractor.extract` (writes the whole PDF to a temp file, spawns `/usr/bin/env pdf_oxide`, `waitUntilExit`) runs per body eval. ContentView observes the root AppModel, so every page turn, keystroke, zoom tick, and status message re-runs it. This alone plausibly explains most interaction latency and scroll hitches on large documents when `pdf_oxide` is installed; when it is not installed, the temp-file write + failed spawn still runs per eval.
2. **The canvas scroll/pan hot path fires a handler 2–3× per scroll tick, and each run does main-thread disk I/O plus unconditional overlay invalidation** (`updateReadingPosition` → sync `JSONEncoder` + `UserDefaults` write; `freezePaneOverlay?.needsDisplay = true` unguarded; `tileOverlay?.forceReload()` bypassing its own 0.05 s debounce).

Secondary themes: root-body fan-out (root view reads `statusMessage`/`operations` derivatives), whole-document `dataRepresentation()` calls in `updateNSView` paths, per-body-eval recomputation of filters/sorts/policy assessments on always-mounted surfaces, and per-frame image decode in authoring. `AppModel` is `@Observable` (no whole-object invalidation at the model); fan-out comes from which hot properties the root view reads. Identity/animation hygiene is largely clean (no PreferenceKey chains, no `matchedGeometryEffect`, single-level `GeometryReader`s, `reduceMotion` respected).

## Findings

Ordered by impact. Fixes marked ★ are small, local, and independent of each other.

### 1. CRITICAL ★ — Full-document extraction + child-process spawn inside ContentView body
- **Symptom**: interaction latency and scroll hitches proportional to document size; every action "feels heavy" while a document is open.
- **Likely cause**: `matchedPresets: { guard let extraction = try? renderingPipeline.extractText(), … }()` — the trailing `()` eagerly evaluates the closure while the toolbar builder runs (`ContentView.swift:900-910`). Chain: `RenderingPipeline.extractText()` (`RenderingPipeline.swift:423-428`) → `PdfOxideExtractor.extract` (`PdfOxideExtractor.swift:95-131`): temp-file write of the full PDF + synchronous `Process` spawn of `pdf_oxide` + `waitUntilExit`. ContentView's body re-evaluates on any read-model change (page nav, zoom, `statusMessage`, search keystrokes), so this runs constantly. Sibling `onAutoDetect` closure (`ContentView.swift:865-877`) calls the same API on click — also synchronous.
- **Fix**: compute `matchedPresets` (and auto-detect) from model state: run extraction once per document load / revision bump off the main actor (Task.detached), cache the result in `@Observable` model state (e.g. `cachedTableExtraction`), have `FreezePaneToggleButton` read the cache. Never call `extractText()` from a view builder.
- **Validation**: Time Profiler trace while scrolling a large doc; `pdf_oxide` spawn count must drop to 1 per document load; ContentView body-eval count (SwiftUI View Body template) unchanged but wall-time per eval drops.

### 2. CRITICAL ★ — Per-scroll-tick work storm in the canvas hot path
- **Symptom**: scroll/pan/zoom jank in the default PDFKit reading mode; pauses in scroll momentum.
- **Likely cause**: `handleViewportOrPageChange()` (`DocumentCanvasView.swift:1213-1256`) is invoked from `boundsDidChange` + `frameDidChange` observers on **three** views (root, scroll contentView, documentView — installed at `DocumentCanvasView.swift:1283-1303`), so one scroll tick runs it 2–3×, each on a freshly allocated `Task { @MainActor }`. Each run: (a) `updateReadingPosition` → `saveReadingPosition` → `persistReadingPositions` (`RenderingPipeline.swift:490-501, 511-524` + persist impl): synchronous full-dict `JSONEncoder` + `UserDefaults.standard.set` on the main thread; (b) `freezePaneOverlay?.needsDisplay = true` **unconditionally** (`:1244`), bypassing any equality guard; (c) `tileOverlay?.forceReload()` (`:1249`), bypassing PipelineTileOverlayView's own 0.05 s debounce; (d) `preRenderForViewport` each time. The `onVisiblePageChanged` leg *is* change-guarded (`:1252-1255`) — the only clean part.
- **Fix**: coalesce — mark dirty and drain once per runloop tick (or throttle to ~30 Hz); guard `needsDisplay` on a `(currentPageIndex, zoomScale)` change; let `forceReload` go through the existing debounce; persist reading position debounced (e.g. 1 s idle or on page change) instead of per tick.
- **Validation**: counter the handler invocations per scroll gesture (expect collapse from O(ticks×3) to O(1) per frame); Time Profiler: `persistReadingPositions` must disappear from scroll intervals.

### 3. HIGH ★ — Double full-document `dataRepresentation()` per SwiftUI pass in the human review panel
- **Symptom**: sluggish review panel on large documents; latency on every state change while mounted.
- **Likely cause**: `updateNSView` compares `view.document?.dataRepresentation() != document?.dataRepresentation()` (`HumanReviewPanelView.swift:367-371`) — two synchronous full-document serializations per SwiftUI diff of the parent, merely to decide whether to swap documents.
- **Fix**: compare identity, not bytes: `if view.document !== document { view.document = document }` (PDFDocument is a class), or compare a cheap revision/fingerprint the caller already tracks.
- **Validation**: `dataRepresentation()` absent from Time Profiler in review-panel interactions.

### 4. HIGH — Root-body fan-out: ContentView reads the hottest model properties
- **Symptom**: whole-window re-diffs on every action; amplifies findings 1–2.
- **Likely cause**: ContentView root body reads `model.statusMessage` (`ContentView.swift:1075/1115`; written from ~200 call sites — every completed action), `model.redactionMarkCount` up to 3× per render (O(operations) filter each, `AppModel.swift:144-146`), `canExportCopy(model)`/`exportCopyHelp(model)` → `AdaptiveCommandContext.input` which reads `inspection`, `liveDocument`, `canExportCurrentOperations`, `canUndo` (`ContentView.swift:673-674`), and `selectedPageIndex` (`:1107`). Any of these invalidates the entire root (toolbar + mainContent + canvas + rail + inspector construction).
- **Fix**: extract status pill / redaction badge / export-enabled state into small leaf views that take narrow inputs (SwiftUI Observation re-evaluates only the reading view); precompute `AdaptiveCommandContext.input` in the model on the operations that change it, not per body eval.
- **Validation**: SwiftUI View Body template — ContentView body-eval count on a status-message change should drop to only the status leaf.

### 5. HIGH — AgentCommandHUD rebuilds and rescors the command list 2–4× per keystroke
- **Symptom**: palette typing feels laggy while the HUD is open.
- **Likely cause**: `allCommands` constructs ~30+ items (closures, keyword arrays) from scratch per access (`AgentCommandHUD.swift:156+`), `adaptiveContextCommands` runs `AdaptiveCommandPolicy.standard.resolve` per access (`:60+`), and `filteredCommands` lowercases/sorts per access (`:492+`) — with `filteredCommands` accessed at least twice per body eval (`:586`, `:618`). Nothing is cached.
- **Fix**: build `allCommands` once (static or `@State` keyed on the few inputs that change it); compute `filteredCommands` into a local once per body eval; resolve adaptive context on open/selection-change, not per keystroke.
- **Validation**: command-pipeline invocation count per keystroke → 1.

### 6. MEDIUM-HIGH ★ — Unguarded nil→nil selection writes invalidate the inspector on every plain click
- **Symptom**: ContextualInspectorView (≈2,900 lines) re-evaluates on every click on the PDF, even when nothing was selected before or after.
- **Likely cause**: `mouseUp` → `onSelectionCleared` path sets `model.selectedAnnotationID = nil; model.selectedTextSelection = nil` unguarded (`DocumentCanvasView.swift:202-206, 245-248`, fired from `:999-1027`). `@Observable` has no equality dedup; readers sit in the inspector body (`ContextualInspectorView.swift:118, 152, 187, 856`) and `AnnotationCreationToolbar.swift:272-292`.
- **Fix**: guard each write with `if x != nil { x = nil }` (and symmetric guards on the set path).
- **Validation**: inspector body-eval count on a plain click → 0.

### 7. MEDIUM-HIGH — Full document copy + serialize in DocumentCanvasView.updateNSView per revision change
- **Symptom**: visible stall on rotate/edit-commit while the canvas is mounted.
- **Likely cause**: `updateNSView` runs `document.copy() as PDFDocument` (deep copy), sets `rotation` on every page in a loop, then `presentationDocument.dataRepresentation()` — all synchronous on main, per document-identity/rotation/projectionRevision change (`DocumentCanvasView.swift:1413-1423`).
- **Fix**: apply rotation incrementally to the existing presentation document; drop the `dataRepresentation()` round-trip (nothing needs the bytes here).
- **Validation**: rotate a 100+ page doc; wall time of `updateNSView` should drop to O(1) per page rotated.

### 8. MEDIUM — Always-mounted thumbnail rail recomputes three dictionaries per body eval
- **Symptom**: background CPU while reading; compounds every other invalidation (the rail re-evaluates on any model change).
- **Likely cause**: `pageBadgeCounts` loops `inspection.fields` + `activeCandidates` + `operations` building 3 dicts per eval, and `canOrganizePages` runs `AdaptiveCommandPolicy.standard.assess` per eval (`PageThumbnailRailView.swift:145-167`).
- **Fix**: precompute badge counts in the model on operations/candidates change (or key a derived store on `inspection` revision); cache the policy assessment.
- **Validation**: rail body wall-time per eval; badge-dict construction count → once per mutation, not per render.

### 9. MEDIUM (opt-in pipeline mode) — full-doc extraction per zoom step; renderer re-parses per render; unbounded stale cache
- **Symptom**: pipeline mode: blank flash + stall per zoom tick; background CPU saturation on large docs; memory growth over long sessions.
- **Likely cause**: (a) `PipelineCanvasView.reloadPage` runs `try? pipeline.extractText()` synchronously from `availableWidth` didSet and `scaleFactor` didSet (`PipelineCanvasView.swift:275-282, 330-347`); same in `PipelinePageView` (`:176`); (b) `ProgressiveRenderer.renderPage` creates a fresh `PDFDocument(data:)` from full bytes per render (`ProgressiveRenderer.swift:88`) — `warmUpPages` = 8 full parses per open; (c) renderer cache `[pageIndex][dpi]` has no eviction: `maxCachedPages: 20` never enforced, `clearCaches()` has zero callers, and entries go stale after page edits; (d) DPI-budget mismatch: warm-up renders at DPI 72 while the rail requests DPI 12 (`RenderingPipeline.swift:346, 370-384`), so rail thumbnails never hit the warm cache. Dormant by default (`usePipelineRendering == false`), but the flag is exposed in the toolbar.
- **Fix**: extract text once per revision (shared cache with finding 1); pass document bytes/pages into the renderer once per open instead of per render; enforce eviction + invalidate on revision bump; align warm-up DPI with rail request.
- **Validation**: zoom-step wall time in pipeline mode; renderer-cache size bound after a 200-page scroll.

### 10. MEDIUM — Comic mode rasterizes the full page at 150 DPI on the main actor per panel flip
- **Symptom**: hitch per panel flip in comic reading mode.
- **Likely cause**: `ComicPanelZoomView.detectAndLoadPanels` (full `dataRepresentation()` + 72 DPI raster of every page + pixel scan, sync in a view method) and `renderCurrentPanel` (150 DPI render pinned to `Task { @MainActor }`) (`ComicPanelZoomView.swift:136-255`).
- **Fix**: move detection and rendering to a background task; keep only the final crop/assignment on main.
- **Validation**: panel-flip frame drop count.

### 11. LOW-MEDIUM — Authoring canvas decodes image elements from raw bytes every drag frame
- **Symptom**: dragging an image element drops frames.
- **Likely cause**: `imageElementView` calls `NSImage(data: props.imageData)` in `body` (`AuthoringCanvasView.swift:338-358`); `moveElement` fires per gesture tick → re-decode per frame.
- **Fix**: decode/downsample once per element (cached by element id + data hash); body renders the cached image.
- **Validation**: drag-frame CPU in authoring with a large embedded image.

### 12. LOW — assorted
- `DocumentSplitView.makeNSView` (`:223-237`): full `dataRepresentation()` + re-parse per pane; `updateNSView` is a no-op, so pane page navigation silently doesn't update the PDFView (**correctness**, not just perf).
- `DocumentBrowserView.filteredDocuments` recomputes `CorpusSearch` + filter + sort 3× per body eval (`.count`/`.isEmpty`/`ForEach` — `:25-57, 308, 346, 382`); same shape in `DedupReportView:540-546`.
- `model.fillProgressLabel` (filters all fields + candidates + string build, `AppModel.swift:2977+`) read 3–4× per toolbar render (`ContentView.swift:~975/985/1013`, inspector `:341`).
- `DateFormatter()` constructed per row: `CollaborationDashboardView.swift:376-380`, `MetadataInspectorView.swift:248-253`; `ByteCountFormatter.string` static calls per row in browser/health/receipt views. Cache as static properties.
- Leaked `NotificationCenter` observer in `ContentView.onAppear` (`:137-146`) — never removed; accumulates across identity changes.
- Per-keystroke autosave scheduling from `searchQuery` (`ContentView.swift:429-437`) — disk writes are digest-guarded/debounced (clean), but each keystroke spins a Task + digest computation + root invalidation.
- `model.rankedActiveCandidates` (full sort with score closures per access, `AppModel.swift:2830-2838`) feeding `ForEach(...prefix(6))` in the inspector (`:1485`).

### Latent (not currently wired — fix before wiring)
- `FreezePaneCompositeView`/`FreezePaneDragHandleView` drag path: per-move double publish (`@Published` written twice per tick, `FreezePaneDragHandle.swift:316-335`), equality-free `config` didSet redraw (`FreezePaneOverlayView.swift:33-35`), and boundary arrays rebuilt per call (`:65-92`). Zero instantiation sites today; documented as groundwork for interactive grid editing.
- `PipelineTileOverlayView`: if ever wired, `performTileReload` would synchronously re-parse the full document twice per call + rasterize/decode tiles on main (`PipelineTileOverlayView.swift:103-146` → `RenderingPipeline.swift:315-329`). Also re-assigns unchanged tile layer contents (`:124-128`).

### Checked and clean
- `AppModel` uses `@Observable` with `@ObservationIgnored` caches correctly; autosave is debounced (250 ms) + digest-guarded and publishes nothing during the debounce.
- Page-rail thumbnails: async render via detached task, `NSImage` cached in `@State`, `.task(id:)` guard — correct pattern (only the DPI-budget mismatch in finding 9d blunts it).
- No `PreferenceKey`/`onPreferenceChange` anywhere; no `matchedGeometryEffect`; all 9 `GeometryReader` sites are single-level and leaf-positioned; no timers touching SwiftUI-observed state; `reduceMotion` respected at every animation site.
- HUD/rail material+shadow chips are bounded and lazy — low cost, no action needed now. Whole-window `.animation(value: isAgentCommandPresented)` (`ContentView.swift:358-361`) should be moved to the HUD leaf; cosmetic.

## Metrics

No Instruments baseline has been captured yet — the findings above are code-backed, and the two criticals are severe enough that a before/after trace should be taken around the fixes rather than a long profiling detour first. Recommended baseline (one capture, large doc >50 pages or >20 MB, Debug Release-check later):

- Time Profiler during a 10 s continuous scroll and during 20 toolbar actions.
- SwiftUI View Body template: ContentView, ContextualInspectorView, PageThumbnailRailView body-eval counts during scroll + click + status change.
- Allocations: renderer-cache growth in pipeline mode over a 200-page scroll.

## Next step

Apply finding 1 (hoist `matchedPresets`/auto-detect extraction out of the view builder into revision-keyed model state) and finding 2 (coalesce `handleViewportOrPageChange` + debounce the reading-position persist) — both are small, local, independent patches with the highest payoff, and both directly serve the "snappy" target. Then re-capture the trace above and diff. Finding 6 and finding 3 are one-line guards that can ride along in the same pass.
