# macOS App Design Skill Audit — 2026-09-11

Auditor: ZCode (Pranay's agent), using the `macos-app-design` skill
(`/Users/pranay/.zcode/skills/macos-app-design/SKILL.md` + `references/macos-design-guide.md`).

Scope: the native Mac shell — `Sources/PDFEditorApp/**`, `Sources/PDFEditorRecovery/AppModel.swift`
(UI-relevant paths), `Sources/PDFEditorCore/{DesignSystem,ThemeManager}.swift`, and the packaged
`dist/Northstar.app`. This audit is a design-citizenship pass; it intentionally does not re-litigate
the document-lifecycle findings already ledgered in
`docs/audits/macos-app-design-review-and-todo-2026-08-24.md` (F-MAC-001…019), which remain the
architectural baseline. Findings below use the `MAD-` prefix (macOS App Design) to avoid collision.

App archetype (per skill deliverable #1): **Document-based pro tool** (open/inspect/edit/export PDFs)
with an emerging **AI-agent command layer** (AgentCommandHUD). Library surfaces (Document Browser,
Version History, Governance) are sheets/auxiliary windows, not a persistent sidebar.

---

## 1. Executive assessment

The native shell is *far* more Mac-native than the average SwiftUI app: a real command layer routed
through one `PDFEditorCommandRouter`, ~60 menu commands with shortcuts and state-driven enablement,
82 `.help()` tooltips, a keyboard-driven ⌘K command palette, standard Settings scene (⌘,),
multi-window with a carefully engineered external-open router, drag-and-drop in, haptics, and 101
accessibility annotations on the core reading surfaces. The design tokens (`ThemeManager`,
`AppColors`) derive from system colors and adapt to light/dark.

The gaps cluster in five places:

1. **Dishonest stubs at the platform boundary** — App Intents and Print return success strings
   without doing the work. This is the most damaging class of finding because it breaks user trust
   exactly where the app touches macOS (Shortcuts, ⌘P).
2. **Packaging is not shippable** — no app icon, no PDF file association (the Info.plist says so
   itself). The buyer path "double-click a PDF → Northstar" cannot become default behavior.
3. **Main-thread document parse on open** — `open(url:)` synchronously loads bytes + parses +
   inspects on the `@MainActor` model; large documents hang the UI (the one remaining headline perf
   item from the 2026-08-25 perf audit).
4. **Accessibility has coverage, not completeness** — reduce-motion is respected in the two biggest
   views but not in 4 other animating files; reduce-transparency and system Increase Contrast have
   zero handling anywhere; status is conveyed by color-only dots in dashboards.
5. **Toolbar overload + material card-itis in the inspector** — ~11 toolbar elements in the reading
   layout, and the inspector expresses hierarchy through 20+ rounded-rect `.regularMaterial` cards
   rather than layout/grouping, which is the exact anti-pattern the macOS design system calls out.

---

## 2. What the app already does right (preserve these)

| Area | Evidence |
|------|----------|
| Single command authority | `AppCommands.swift:60-331` — every menu item routes through `PDFEditorCommandRouter` into typed `AppModel` actions (skill §6.1 "internal app intents" pattern, exactly as prescribed) |
| Settings | `PDFEditorApp.swift:436-438` `Settings { SettingsView() }`; `ContentView.swift:2269-2289` TabView + `.tabItem`, `Form` + `.formStyle(.grouped)`, `@AppStorage` |
| Multi-window | `PDFEditorApp.swift:419-425` WindowGroup; per-window `@State AppModel` (`PDFEditorWindow`); dirty-state close/open/new confirmations (`AppCommands.swift:246-330`) |
| External open determinism | `PDFEditorApp.swift:311-400` — one router for Finder/argv/Apple-event opens; scratch-window sweep invariant "no external open may discard work" |
| Command palette | `AgentCommandHUD.swift` — ⌘K, `@FocusState`, `.onKeyPress` arrows/escape (`AgentCommandHUD.swift:706-720`), fuzzy items with labels+hints (`:614-615`) |
| Keyboard coverage | ⌘N/⌘O/⌘W/⌘S/⌘Z/⌘F/⌘G/⌘K, page nav, zoom, reading modes ⌘1-4, Security Vault ⌘8 (`AppCommands.swift`, `ContentView.swift:685`) |
| Tooltips | 82 `.help()` calls across the app target |
| AX on core surfaces | `DocumentCanvasView.swift:140-141,304-307` (canvas element + page with value/hint), `ContextualInspectorView.swift:1509-1511` (candidate cells with `isSelected` traits), `DiffComparisonView.swift:155-189` |
| Reduce motion (partial) | `ContentView.swift:108,341` etc. (7 env reads), `DocumentCanvasView.swift:53` |
| Semantic colors | `ThemeManager.swift:153-181` `AppColors` maps to `.labelColor`/`.windowBackgroundColor`/`.controlAccentColor` etc.; 762 semantic fonts vs 51 hardcoded sizes |
| System text | Inline editing uses a real `NSTextField` host (`DocumentCanvasView.swift:642-` `InlineEditorTextFieldHost`) — inherits the Mac text ecosystem |
| Drag & drop in | Canvas, welcome, thumbnail rail, batch merge (`ContentView.swift:344,1383`, `PageThumbnailRailView.swift:85`, `BatchMergeSheet.swift:81`) |
| Haptics | `.sensoryFeedback` on toolbar actions (7 usages) — ADA "Delight" rubric |
| HONESTY label | AX label workaround for segmented picker symbol leak (`ContentView.swift:716-721`, sim finding PL-I32) |

---

## 3. Detailed findings

### MAD-001 (Critical): App Intents are success-stubbed — Shortcuts lies to the user
`Sources/PDFEditorApp/PDFEditorAppIntents.swift`:
- `SanitizePDFIntent.perform()` (`:26-29`) checks the file exists, then returns
  `"PDF Sanitized successfully on-device (Zero Network Egress). Metadata stripped."` **without
  running any sanitizer**.
- `ExtractTableCSVIntent.perform()` (`:57-60`) and `ComparePDFVersionsIntent.perform()`
  (`:81-83`) return canned strings equally.
- `NorthstarShortcutsProvider` (`:88-99`) exposes "Sanitize PDF with [app]" as a system Shortcut
  phrase, so a user can invoke it from Spotlight/Shortcuts and be told it worked.

The real pipelines exist (`PDFSanitizer`, `TableExtractor`, `DocumentDiff` in PDFEditorCore) — the
intents just don't call them. This is the inverse of the repo's own epistemic-integrity doctrine.

### MAD-002 (Critical): Print is a stub that prints an empty view
`Sources/PDFEditorCore/PublishPipeline.swift:220-237` — `publishToPrinter` creates
`NSPrintOperation(view: NSView(), printInfo:)` (an **empty** view), runs it, and returns
`success: true` with a page count. And there is no ⌘P / Print… menu item anywhere in
`AppCommands.swift` — so the only print path that exists is one that prints nothing while claiming
success.

### MAD-003 (Critical): No app icon, no PDF file association — packaging blocks the buyer path
`dist/Northstar.app/Contents/Info.plist` states it directly:
`<!-- No icon yet (F-006 asset pass); no file associations yet. -->`
- No `.icns`/`.appiconset`/Icon Composer `.icon` asset anywhere in the repo.
- No `CFBundleDocumentTypes` / `LSItemContentTypes` for `com.adobe.pdf` → the app cannot be set as
  the default PDF handler and doesn't appear naturally in Finder's "Open With".
- No `LSApplicationCategoryType`, no `NSHumanReadableCopyright`.
The External Open Router (PDFEditorApp.swift:312) is well-built, but it only solves the "app is
already chosen" half of the path.

### MAD-004 (Critical): Document open parses synchronously on the main actor
`AppModel.swift:1735-1760` — `open(url:)` (a `@MainActor` method) calls
`provider.openDocument(url:password:)` which does `loadData(from:)` + `PDFDocument(data:)` + a full
`inspection(for:data:)` in one synchronous call (`PDFKitProvider.swift:55-76`), then runs
`verifyDigitalSignatures()` / `inspectXFA()` inline. Preflight and companion negotiation are
correctly `Task.detached` (`:1783`, `:1810`), which makes the remaining synchronous parse the
standing outlier. This is the last of the three 2026-08-25 hang root causes; the "Moby Dick test"
(open large doc, scroll, resize) cannot pass while open blocks the main thread.

### MAD-005 (High): No Help system at all
No `CommandGroup(replacing: .help)`, no `NSHelpManager`, no help book, no in-app help links. The
default SwiftUI Help menu item activates and does nothing. The app's differentiated concepts
(Export-only model, adaptive commands, evidence graph, agent palette) are exactly the things new
users need one paragraph of explanation for.

### MAD-006 (High): Toolbar overload in the reading layout
`ContentView.swift:577-948` — `appToolbar` installs: New, Open, Undo, Redo, Export menu,
Workspace menu, editor-mode segmented picker, ⌘K palette button, reader-mode segmented picker,
Diff menu, reading-mode menu, freeze-pane toggle, bookmark menu, status suggestion region.
That is ~13 elements. The macOS design system's own signal: "Crowded toolbar = signal to remove
or demote actions." Specific demotion candidates:
- Reading-mode menu duplicates the View ▸ Reading Mode menu verbatim (`:784-810` vs
  `AppCommands.swift:572-596`).
- Freeze-pane toggle is a niche power feature (`:813-863`).
- Bookmark menu is document content, belongs in the thumbnail rail or inspector (`:866-911`).
- The reader-mode + Diff pair could collapse into one "View" segmented/menu cluster.

### MAD-007 (High): Inspector hierarchy is expressed by material cards, not layout
`ContextualInspectorView.swift` (2,930 lines) contains 20+ `.background(.regularMaterial, in:
RoundedRectangle(cornerRadius: 8…12))` card wrappers (`:1595,1618,2152,2184,2246,2287,2322,2381,
2431,2505,2607,2659,2809,2838` …) plus five `.thinMaterial` panels (`:324,411,465,516,567,901`).
The system rule is the opposite: express hierarchy via layout and grouping, remove decorative
backgrounds/borders. `SecurityVaultSheet` shows the same pattern (`:177,228,392,433,502,555`),
and `SecurityVaultSheet.swift:177` nests a material card inside a material panel — the
"glass-on-glass" stacking anti-pattern (verify at runtime; nesting materials compounds translucency
cost and muddy hierarchy).

### MAD-008 (High): Reduce Transparency and system Increase Contrast are unhandled
- Zero uses of `accessibilityReduceTransparency` / `NSWorkspace…ShouldReduceTransparency` anywhere
  in `Sources/`. With ~50 material-backed surfaces, Reduce Transparency rendering is untested and
  unadapted (e.g. `.foregroundStyle(.white.opacity(0.2))` strokes on material chrome —
  `DocumentCanvasView.swift:443,598` — may become invisible when materials flatten).
- The app defines its OWN "High contrast" toggle (`ThemeManager.swift`, Settings
  `ContentView.swift:2398`) but never consults the system-level
  `NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast`. A user who turns on Increase
  Contrast system-wide gets nothing; two competing notions of high contrast is a Mac-citizenship
  miss and an inclusivity rubric failure.

### MAD-009 (High): Reduce Motion respected in only 2 of 6 animating files
Animations with no reduce-motion gate: `ContextualInspectorView.swift` (3), `DocumentSplitView.swift`
(1), `FreezePaneDragHandle.swift` (1), `PageThumbnailRailView.swift` (1). `ContentView` (14
animations) and `DocumentCanvasView` do gate correctly. Also `ContentView.swift:144-145` carries a
stale comment ("Apple Design §12: translucent toolbar — .ultraThinMaterial on macOS") describing a
custom toolbar material that no longer exists — the toolbar is a standard SwiftUI toolbar now.
Delete the comment or restore the intent.

### MAD-010 (Medium): Missing standard shortcuts — ⌘0 (Actual Size), ⌘P (Print)
`AppCommands.swift:539-551` — Actual Size / Fit Page / Fit Width have no shortcuts. Every major
Mac PDF reader binds ⌘0 = Actual Size (Preview, PDF Expert, Skim). Combined with MAD-002, print is
doubly absent: no command, no implementation.

### MAD-011 (Medium): "Confirm/Reject Field" live in the Edit menu
`AppCommands.swift:460-473` places form-review commands in the Edit menu (`CommandGroup(after:
.textEditing)`), where users expect Cut/Copy/Paste-family items. They are review-workflow commands
— a Form/Review menu (or the Tools area) fits the mental model better. Also ⌘⌫ for "Reject Field"
collides with the standard text-editing "delete to start of line" binding when a text field has
focus (the inline editor host uses a real NSTextField — verify no conflict in practice).

### MAD-012 (Medium): No Share, no drag-out, no Quick Look, no Services
- No `NSSharingService`/`ShareLink` anywhere. The natural moment is right after
  `Export Copy…` — offer Share on the exported file.
- No `.onDrag`/`.draggable`: you cannot drag a page (or the doc) out to Finder/Mail/Messages,
  which is a core PDF-app interaction (drag a page thumbnail into an email).
- No `QLPreviewPanel` integration (e.g., Quick-Looking an export before committing).
- No Services menu participation (e.g., a "Sanitize PDF" service on PDF files).
None block launch, but they're all "good Mac citizen" table-stakes for a document tool.

### MAD-013 (Medium): Color-only status in dashboards
`GovernanceDashboardView.swift:320,362` and `CollaborationHistoryView.swift:166` render status as
10×10 colored `Circle()`s with no shape/icon/text redundancy (skill: never encode meaning by color
alone; add icon+label or SF Symbol). Needs verification of whether adjacent text carries the state
in every row — several rows show only the dot.

### MAD-014 (Medium): Hardcoded point sizes on chrome overlays break Dynamic Type
51 `.font(.system(size:))` calls vs 762 semantic. Document-content sizes are fine (PDF rendering is
point-based), but chrome text is also fixed: zoom pill and canvas controls at 11–12pt
(`DocumentCanvasView.swift:336,375,391,404`), annotation toolbar at 12–14pt
(`AnnotationCreationToolbar.swift:63,212`). These will not scale with user text-size settings.

### MAD-015 (Low): Stale/misleading comments referencing removed chrome
`ContentView.swift:145` (translucent-toolbar comment, see MAD-009). `AuthoringCanvasView.swift:168`
uses `.background(.bar)` on what the comment tree suggests are content-area bars — confirm it's
actually a bar layer. Minor but they mislead the next auditor.

### MAD-016 (Low): `menuStyle(.borderlessButton)` on toolbar menus (6 usages)
`ContentView.swift:909`, `DocumentCanvasView.swift:366,467,546`, `PageThumbnailRailView.swift:44`,
`FreezePaneOverlayView.swift:835`. System toolbar menus style themselves correctly; forcing
borderless-button is a small custom-chrome deviation with no stated justification.

### MAD-017 (Low): "Save…" semantics
`AppCommands.swift:405-414` binds ⌘S to Export Copy under the label "Save…". The export-only model
is a deliberate, documented product decision (source never overwritten) and the confirm alerts
explain it well. Keeping ⌘S mapped to the safest real action is defensible; but the item label
could be "Export…" with ⌘S shown, which is more honest than "Save…" doing an export. Product call,
not a defect.

### MAD-018 (Info): Window-level observations
- Native tabbing/fullscreen come free with WindowGroup (no explicit config found; defaults apply).
  Verify tabbing with multiple documents actually preserves per-window model state
  (F-MAC-002 lineage).
- Standalone `Window` scenes (governance, companion-health) have no commands/toolbar of their own —
  fine for dashboards.
- Min size 720×480 with RG-059 justification (`PDFEditorApp.swift:248`) — good.

---

## 4. Explicit findings vs implicit findings

### Explicit (directly visible in code/artifacts)
- MAD-001..004: stubbed intents, stubbed print, missing icon/file-association, main-actor parse.
- MAD-005, 010, 011: no Help, no ⌘0/⌘P, misplaced Edit-menu commands.
- MAD-006, 007, 009, 015, 016: toolbar overload, inspector card-itis, partial reduce-motion,
  stale comments, borderless menu styles.
- MAD-008, 013, 014: zero reduce-transparency/system-contrast handling, color-only status dots,
  fixed-size chrome fonts.
- MAD-012: absent Share/drag-out/QuickLook/Services.

### Implicit (must become product/architecture decisions — research + document before implementing)
- Whether Northstar is **document-first** (Preview-like: window = file) or **library-first**
  (persistent sidebar shell). Today it's document-first with library surfaces as sheets. This is
  the same open decision as the empty-state redesign (A1 Agent Desk spine vs R1 Library shell,
  EMPTY-STATE-SKETCHES batches) — one decision should settle both.
- **Liquid Glass readiness plan** for macOS 26: the app targets macOS 15 and uses classic
  materials. When the min OS moves to 26, the correct migration is: toolbars/sidebars/HUD →
  `.glassEffect`/system bars; inspector cards → de-materialized grouped sections (MAD-007 is the
  prep work). Document the plan now so the migration is a cleanup, not a redesign.
- **Inspector decomposition**: `ContextualInspectorView` at 2,930 lines is the largest view in the
  app and concentrates the card-itis. Splitting by mode (read/fill/sign/edit) is implied by the
  adaptive-command architecture but hasn't been done.
- **VoiceOver end-to-end proof**: labels exist, but the ADA rubric asks "can a VoiceOver user
  complete the core workflow (open → fill field → export)?" — that's a sim/persona run, not a grep.
- **Command map as a durable doc**: the skill's deliverable #3 (menus + shortcuts for every
  feature) exists only as code. A generated `docs/` command map would make drift visible.
- **Localizability**: all UI strings are hardcoded English literals (no localization files). For
  the paid-early-access/GA question this is a scope decision, not a bug.
- **Settings IA**: General/Governance/Companion-Health reflects the dev-era governance obsession;
  reading preferences, export defaults, and AI/agent behavior have no home.

---

## 5. Task ledger

Statuses: `open` / `in-progress elsewhere` / `decided`. Implementation tasks (I), research &
documentation tasks (R), decisions (D).

### Implement (explicit findings)

| ID | Task | Finds | Size | Notes |
|----|------|-------|------|-------|
| MAD-I1 | Wire `SanitizePDFIntent`/`ExtractTableCSVIntent`/`ComparePDFVersionsIntent` to the real Core pipelines (or delete them + the Shortcuts provider until wired) | MAD-001 | M | Honesty first: shipping a lying Shortcut is worse than no Shortcut. `PDFSanitizer`/`TableExporter`/`DocumentDiff` exist. |
| MAD-I2 | Real print: `NSPrintOperation` with a `PDFView` of the live document + `File ▸ Print…` (⌘P) menu command; delete the empty-view stub | MAD-002, 010 | S | |
| MAD-I3 | App icon pass (Icon Composer, layered, dark/tinted/clear variants) + `CFBundleDocumentTypes` for PDF + `LSApplicationCategoryType` + copyright in the bundle script | MAD-003 | M | Already tracked as F-006 in the bundle script comment; this audit re-raises it as buyer-path-critical. |
| MAD-I4 | Move document open off the main actor: async `open` with progress, publish inspection when parsed; keep the confirm/deny gates | MAD-004 | L | The last open perf item from 2026-08-25. Careful: session digest/recovery invariants must survive. |
| MAD-I5 | Add Help: `CommandGroup(replacing: .help)` with real topics (export-only model, adaptive commands, palette, vault) — even a short local HTML book beats nothing | MAD-005 | M | |
| MAD-I6 | Toolbar declutter: demote reading-mode menu (dup of View menu), freeze-pane toggle, bookmark menu; cluster reader-mode+Diff | MAD-006 | M | Do after the A1/R1 shell decision (D1) to avoid rework. |
| MAD-I7 | Inspector de-card: replace rounded-rect material cards with grouped sections (`Form`/section headers), fix the nested-material in SecurityVaultSheet | MAD-007 | M | Prep for Liquid Glass. |
| MAD-I8 | Gate remaining animations on `accessibilityReduceMotion` (ContextualInspectorView, DocumentSplitView, FreezePaneDragHandle, PageThumbnailRailView); delete stale §12 comment | MAD-009, 015 | S | |
| MAD-I9 | Honor system `accessibilityDisplayShouldIncreaseContrast` (merge with the app toggle: system on ⇒ forced on, app toggle only adds); audit materials under `accessibilityReduceTransparency` | MAD-008 | M | |
| MAD-I10 | Add ⌘0 Actual Size (+ consider ⌘9/⌘8-family for Fit); move Confirm/Reject Field out of Edit into a Form/Review group; re-map Reject Field off ⌘⌫ | MAD-010, 011 | S | |
| MAD-I11 | Share (ShareLink on exported copy), drag-out (`.onDrag` page thumbnails / document), Services menu for Sanitize | MAD-012 | M | |
| MAD-I12 | Status-dot redundancy: icon or text beside every colored state circle (Governance, Collaboration views) | MAD-013 | S | |
| MAD-I13 | Replace fixed chrome font sizes with semantic styles or `.system(size:, relativeTo:)` on overlay chrome | MAD-014 | S | |

### Research + document (implicit findings)

| ID | Task | Output |
|----|------|--------|
| MAD-R1 | VoiceOver + keyboard-only end-to-end run of the core workflow (open → fill/sign → export), log gaps as PL-style findings | sim/audit doc in `docs/simulations/` or `docs/audits/` |
| MAD-R2 | Reduce Transparency + Increase Contrast + Reduced Motion pass over every material surface; screenshot evidence per surface | evidence doc, pattern of `docs/audits/*-evidence-*.md` |
| MAD-R3 | Liquid Glass (macOS 26) migration plan: which surfaces become glass, which de-materialize; depends on MAD-I7 | plan doc |
| MAD-R4 | Generated command map (menus + shortcuts + toolbar + palette) as a checked-in doc with a generator script in `tools/` | `docs/` + `tools/` (reusable, per AGENTS.md tools practice) |
| MAD-R5 | Moby Dick performance re-run after MAD-I4: open ≥250MB doc, scroll, resize; record hitch metrics | update `docs/audits` perf evidence + `benchmark/` |
| MAD-R6 | Localizability survey (string extraction cost, layout risk with German/Japanese) — scope decision input for GA | short research note |
| MAD-R7 | Settings IA proposal aligned to the paid-early-access persona (reading prefs, export defaults, agent behavior) | proposal doc |
| MAD-R8 | Window tabbing verification: tab two documents, confirm per-window model/recovery independence (F-MAC-002 lineage) | evidence doc |

### Decisions needed (product)

| ID | Decision | Context |
|----|----------|---------|
| MAD-D1 | Document-first vs library-first shell | Blocks MAD-I6; same decision as empty-state A1/R1 pick |
| MAD-D2 | Keep ⌘S→Export Copy label as "Save…" or rename to "Export…" | MAD-017; small but user-trust-adjacent |
| MAD-D3 | Ship App Intents at GA at all (and at what depth: Shortcuts phrases vs parameter automation) | MAD-001 scope |
| MAD-D4 | Localization commitment level for paid early access | MAD-R6 gates this |

---

## 6. Skill Definition-of-Done scorecard (current state)

| Checklist item | Status |
|---|---|
| Standard menu bar; key commands discoverable | ✅ (gaps: no Print, no Help content, ⌘0 missing) |
| Settings via ⌘, native feel | ✅ |
| Undo/redo reliable | ✅ (adaptive-gated, replay-based; see F-MAC-006 for caveats) |
| Copy/paste/selection normal in text surfaces | ✅ (NSTextField host; canvas selection untested for Services) |
| Multi-window sensible; resize robust | ✅ (model-independent proof = MAD-R8) |
| Custom bars/backgrounds removed unless justified | ❌ inspector/vault card-itis (MAD-007) |
| Liquid Glass for nav layers; content clear | ◐ materials mostly on chrome; nesting violations to fix |
| No glass-on-glass | ❌ SecurityVaultSheet nesting (verify + fix) |
| App icon modern, multi-appearance | ❌ none at all (MAD-I3) |
| SF Symbols appropriate | ✅ |
| VoiceOver labels for interactive elements | ◐ 101 annotations, dashboards + custom drag targets lag |
| Full keyboard navigation | ◐ palette + search good; annotation/candidate cells unproven |
| Reduced motion/transparency/contrast tested | ❌ motion partial; transparency + system contrast zero |
| Large-document responsiveness | ❌ main-actor parse (MAD-I4) |

**Verdict consistent with the persona launch audit: not GA-ready on Mac-citizenship alone.**
The four Critical items (MAD-001..004) are all fixable without architecture changes except I4.

---

## 7. Method note

Sub-agent dispatches for this audit failed twice (allowance exhausted + content-blocked), so all
evidence was collected directly via targeted search and file reads in this session. Every finding
above carries a file:line citation from the current working tree (git status shows heavy uncommitted
drift from the parallel codex lane — re-verify line numbers before editing, per the standing
parallel-agent protocol).
