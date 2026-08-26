# Exploration: Open-state defaults, close-last-document behavior, multi-document tabs

- **Date:** 2026-08-26
- **Trigger:** User feedback: (a) default layout on open should be centered or last choice, ideally with "save this layout"; (b) what happens when closing the only PDF without quitting; (c) is there multi-tab support?
- **Method:** ADHD-style divergent brainstorm — 5 isolated parallel cognitive frames (game designer, inversion, 3am on-call, hostile competitor, 10-year-old), 30 raw ideas → scored → clustered → top 3 deepened. Plus competitive web research (Acrobat, Preview, Foxit, PDF Expert, Okular) and a mining pass over existing repo docs.
- **Status:** Exploration only. No decision made yet. Candidate decision records pending user pick.
- **Canonical doctrine source:** `/Users/pranay/Downloads/OPERATING_DOCTRINE.md` v6.1 family; project instructions per `/Users/pranay/Projects/pdf_editor/OPERATING_DOCTRINE.md`.

---

## 1. Current state of the app (verified, Tier 1 static inspection)

| Question | Current behavior | Evidence |
|---|---|---|
| Default view on open | Fit-width / continuous / zoom 1.0 / rotation 0 for any *new* document | `AppModel.swift:131-134` |
| View-state persistence | Full autosave (page, mode, scale mode, zoom, rotation) ~250ms debounce, keyed by source SHA-256 digest in `~/Library/Application Support/PDFEditor/Sessions/*.pdfedit`; restored when reopening the same file | `ContentView.swift:214-222`, `AppModel.swift:3604-3624, 2510-2532, 4082, 4152-4180` |
| Global "last used" preference | None. Only editor *intent mode* persists across docs (`persistModeAcrossDocuments`, D-010 pattern: reset-on-open by default + opt-in persistence) | `AppModel.swift:142-145`; `Docs/intent-mode-design.md:287` |
| "Save this layout" control | Does not exist | — |
| Closing last document | Only ⌘W (window-scoped). Leaves app running window-less; no hub/empty state shown on close (WelcomeView appears only when replacing a doc in-window) | `AppCommands.swift:30,143-146,252-281`; `PDFEditorApp.swift:109-160`; `ContentView.swift:161-168` |
| Tabs | None. Multi-doc = multiple windows (⌥⌘N), one AppModel per window. One roadmap seed: "Move Tab to New Window when tabs are supported" | `PDFEditorApp.swift:243-249`; `AppCommands.swift:113-120`; `Docs/northstar-macos-landscape-and-product-direction-2026-08-25.md:420` |

## 2. What other players do (live research, Tier 2 web sources)

| App | Default view on open | View-state memory | Last-document close | Multi-doc model |
|---|---|---|---|---|
| **Adobe Acrobat** | Per Preferences → Documents | **Opt-in** "Restore last view settings when reopening documents"; off by default | Home/start screen exists; closing doc returns toward it | Tabs since DC 2017; tear-out to window |
| **macOS Preview** | Settings → PDF: default display mode (Continuous/Single/Two Pages) for first-time opens | Toggle "Start on the last viewed page"; page stored in **file xattr** (`com.apple.Preview.UIstate.v1`) — travels with the file; zoom-mode remembered across docs once chosen | Empty window possible; no hub | Every doc its own window; Merge All Windows available but criticized (PDF Expert marketing targets this pain) |
| **Foxit** | Preferences-based | Opt-in "Restore last view settings when reopening" (History category) | — | **Tabs by default** + tear-out-to-window + Allow Multiple Instances + split view + tab groups |
| **PDF Expert (Mac)** | Reading layouts continuous/single | Remembers reading position | — | Tabbed view is a headline feature; ⌃Tab switching; drag-reorder tabs |
| **Okular** | Configure Okular → Open new files in tabs (opt-in) | Session restore | — | Optional tabs |

**Synthesis:** the industry converged on three separable knobs we currently conflate:
1. **Resume point** (page/scroll) — nearly everyone restores it, at least opt-in.
2. **Magnification/layout policy** (fit vs remembered %) — split between fixed defaults and global/per-doc memory; nobody forces one answer.
3. **Container model** (tab vs window) — treated as a *preference*, never a hard-coded single answer (except PDF Expert's tabs-first).

Our app is already *ahead* on knob 1 (automatic per-digest restore, better than Acrobat's opt-in) but silent on knobs 2 and 3, and its close semantics are accidental rather than designed.

## 3. Internal constraints that shape any solution

- Northstar archetype is locked: *"Document-based editor with independent document windows"* (`northstar…md:213-215`); *"no cross-window undo/search leakage"* (`:484`). Tabs must extend windows, not replace them.
- Persisted view state must live in `ViewState` contracts, never edit geometry (`shared-contracts.md:280`).
- T-MAC-003 (audit) is the designated home for the lifecycle contract incl. close/dirty/confirmation rules.
- G-04/HIG-04 already plans a persisted Open Recent submenu + Dock menu — a recents model will exist anyway; the close-hub should reuse it, not fork it.
- IMP-07 reserved a Settings slot for "default reader mode, zoom" — the global policy picker has a reserved home.
- D-010 established the accepted precedent: **reset-on-open by default + Settings opt-in to preserve**.

## 4. Wide idea pool (30 ideas, clustered, scored N/V/F out of 10)

### Cluster A — Restore correctness & state hygiene (on-call frame)
- Digest-versioned view state; mismatch ⇒ neutral default like a cache miss `[N4 V9 F8]`
- Apply saved state only after first successful render pass `[N5 V8 F8]`
- Atomic write + one previous generation for self-heal `[N3 V9 F7]`
- Snap out-of-bounds persisted values (page > EOF, rotation ∉ {0,90,180,270}) `[N4 V8 F8]`

### Cluster B — Close-as-hub (empty state)
- Hub world / continue screen: recents as load slots with their saved layouts `[N6 V8 F9]`
- First-class designed empty state: document shelf (recents + pinned) `[N5 V9 F9]`
- Close morphs window into launcher state, never empty, never quit `[N6 V8 F8]`
- Instant close + Reopen Closed Document (⌘⇧T-style); confirm only when dirty `[N6 V9 F9]`
- Ghost of last doc dimmed behind a pause menu `[N8 V5 F6]`
- Document graveyard shelf of live thumbnails `[N7 V4 F5]`
- Breathing corner thumbnail `[N8 V3 F4]` · Filmstrip ribbon `[N9 V2 F3]`

### Cluster C — Layout memory models
- ★ **Decouple resume point (always per-doc) from magnification policy (Settings-chosen)** `[N8 V8 F9]`
- "Save this layout" pin per document, surfaced near zoom readout with clear-pin affordance `[N7 V7 F7]`
- Named layouts ("Reading", "Forms", "Wide table") as app-wide library `[N7 V7 F7]`
- Auto-persist after user customizes twice (tutorial wheels come off) `[N8 V4 F5]`
- Silent per-document-type layout probe picks initial zoom `[N8 V5 F6]`
- Zoom inherited from doc identity (forms big, novels tall) `[N8 V3 F5]`
- Rewind timeline of layout snapshots `[N7 V4 F4]`
- Random sample from user's historical layouts `[N10 V1 F2]` · Forced 400% first choice `[N9 V1 F2]` *(novelty theater)*

### Cluster D — Container model (tabs/windows)
- Tabs = fast-travel, windows = side-by-side; both exist, tabbing is a preference `[N5 V8 F9]`
- Native NSWindow tabbing over WindowGroup (system menus free) `[N5 V8 F9]`
- Auto-merge windows into tabs (Safari-style Merge All Windows) `[N5 V7 F7]`
- Drag-window-onto-window spawns workspace `[N6 V5 F5]` · Mandatory tabs + ephemeral pop-outs `[N6 V4 F4]`
- Endless tablecloth `[N10 V1 F1]` · Weight-stack recency inversion `[N9 V2 F2]` *(traps)*

## 5. Convergence — shortlist and why

1. **Decoupled view memory (Cluster C ★)** — highest weighted score (8.25). Directly answers feedback point (a); reuses D-010's proven reset+preference pattern; zero regression risk since autosave path stays untouched; fixes the latent bug class where a restored zoom misplaces the scroll anchor.
2. **Close-as-hub + undoable close (Clusters B)** — 7.95. Answers point (b); WelcomeView already exists as substrate; Open Recent (G-04) gives it data for free; converts today's undefined behavior into a designed transition. Non-obvious-but-viable pick: making close *instant and undoable* instead of dialog-guarded.
3. **Native macOS tabbing (Cluster D)** — 7.2. Answers point (c) with near-zero custom UI; preserves the independent-window archetype and per-window isolation doctrine by construction; matches Acrobat/Foxit/PDF Expert parity expectations.

**Rejected/traps (one-line reasons):**
- Random layout sampling / forced 400% open — novelty theater, actively hostile UX.
- Ghost/graveyard/filmstrip/breathing-thumbnail empty states — heavy build cost for decorative value; hub-with-recents delivers the same recovery value cheaply.
- Custom tab-bar UI inside one window — violates the independent-window doctrine and duplicates what NSWindow tabbing provides free.
- Magic auto-persistence after N customizations — unpredictable behavior; users can't explain state (doctrine: operator/user must be able to explain what happened).

## 6. Deepened branches

### Branch 1 — Decoupled view memory
**Sketch:** Split restore into two layers: *resume point* (selectedPageIndex + scroll anchor + view-mode — always restored from the digest-keyed session) and *layout policy* (readerScaleMode/readerZoom/readerRotation — gated by new UserDefaults enum `LayoutRestorePolicy { fixedDefault, lastUsedGlobally, perDocument }`). Autosave keeps writing full snapshots unchanged; only the restore path consults policy. A **File ▸ Save This Layout** command writes an explicit `pinnedLayout` into that digest's durable record, overriding all policy. Settings mirrors the existing `persistModeAcrossDocuments` toggle as a three-way picker.
**Load-bearing risk:** order-of-application drift — if scale resets after scroll-anchor restore, the anchor lands on wrong visual position. Must apply magnification first, then recompute the scroll anchor against post-scale geometry.
**First concrete step:** add the enum next to `persistModeAcrossDocuments` (`AppModel.swift:142`) and thread it into snapshot restore (~`:2645`) so only gated fields are conditionally assigned.
**Sub-ideas:** pinned-layout toolbar badge with one-click clear; named-layouts library; fractional scroll anchor (visible-rect ratio) for exact resume across rotation; transient "Restored saved layout" status message; export/import layouts via session payload envelope.

### Branch 2 — Close-as-hub
**Sketch:** Add **Close Document** distinct from Close Window. On last-document close, keep the window and swap to an upgraded hub (WelcomeView + just-closed row + recents from the planned G-04 store). Push closed URL onto a recently-closed stack; **Reopen Closed Document (⌘⇧T)** pops it through the normal open path (recovery store restores view state automatically). Dirty guard stays exactly as-is before entering the flow.
**Load-bearing risk:** atomicity of dirty-confirm ↔ stack-push, and session-scoped honesty — the undo stack dies at relaunch unless persisted; either persist it unified with Open Recent or scope it explicitly and say so.
**First concrete step:** lifecycle action intercepting last-document closes to present the hub behind the existing dirty guard (no undo stack yet).
**Sub-ideas:** persisted recentlyClosed unified with Open Recent; "just closed" live-thumbnail row; same mental model extended to tab closes; drag-from-hub into split arrangements; hub entry triggers stale-recovery compaction.

### Branch 3 — Native macOS tabbing
**Sketch:** Set hosting `NSWindow.tabbingMode = .preferred` + shared `tabbingIdentifier` via a small NSViewRepresentable window accessor. Each tab remains its own NSWindow with own AppModel/undo/recovery — isolation doctrine holds for free. System supplies Show Previous/Next Tab, Move Tab to New Window, Merge All Windows. Settings toggle maps to Safari-like granularity (prefer tabs always / in full screen / never).
**Load-bearing risk:** SwiftUI doesn't guarantee NSWindow identity — WindowGroup can recreate windows during restoration/stage management, silently dropping tabbingMode; delegate attachment and tabbing settings must be re-asserted defensively, and lifecycle bookkeeping should hang off NSWindowDelegate, not SwiftUI scene phase alone.
**First concrete step:** WindowTabbingModifier setting tabbingMode/tabbingIdentifier on the root view; manually verify two documents merge and Move Tab to New Window preserves per-window undo.
**Sub-ideas:** Settings-driven tab policy remembering last-used mode; restorableState-based tab-group restoration across launches (differentiator vs Acrobat); drag-tab-out positioning; per-tab proxy-icon thumbnails; cross-window ⌘P document switcher that respects isolation.

## 7. Recommendation (opinionated, per skill contract)

Ship in this order:
1. **Branch 1** (small, high-certainty, directly answers the feedback; includes Save This Layout).
2. **Branch 2** (medium; turns the biggest daily papercut — closing last doc — into a designed moment; prerequisite plumbing overlaps G-04).
3. **Branch 3** (medium; do after 1–2 so the hub and close semantics are settled before adding containers; also satisfies the pre-seeded roadmap item).

Plus Cluster A items as cheap hardening riders on Branch 1's restore path (out-of-bounds snapping, render-pass-gated apply).

## 8. Falsifiers / revisit triggers

- If digest-keyed restore proves to already satisfy users' "remember my zoom" expectation in testing, drop `lastUsedGlobally` from the policy enum (keep two-way).
- If NSWindow tabbing proves unstable under SwiftUI restoration (window recreation drops tabs mid-session), fall back to explicit "Open in New Window" + Merge All Windows via manual `addTabbedWindow:` and re-review.
- Revisit if Apple formalizes SwiftUI-native tabbing APIs (removes the defensive re-assertion burden).

---

# PART II — Round 2: beyond parity (cross-industry transplants)

*Appended 2026-08-26 after user direction: "we don't fall into what everyone's doing, we also explore new ideas, what maybe works in other industries, new age solutions."*

## 10. User suggestions (recorded as given)

1. **Window-in-window like video / Google Meet** — "like videos etc have this window in window or like when you are on a google meet and switch to another tab you get again something like window in window."
2. **Same-tab split windows like Chrome and IDEs** — "chrome and ides have these same tab two windows, split window."
3. **Diff views like IDEs** — "for ides diffs etc."
4. General directive: explore what works in other industries and new-age solutions; don't just copy PDF competitors.

## 11. Cross-industry pattern research (live sources, Tier 2 web)

### Picture-in-picture beyond video
- **Document Picture-in-Picture API** (Chrome, standardized 2024): always-on-top window holding *arbitrary content*, not just `<video>`. Key semantics: floats above everything, never outlives opener, one per tab, "back to tab" return affordance. Explicitly pitched for productivity apps: notes, docs, timers, editors (developer.chrome.com/docs/web-platform/document-picture-in-picture; MDN).
- **Google Meet auto-PiP**: automatically detaches to floating mini-UI when you switch tabs or screenshare; configurable trigger ("only when I switch tabs" / "always"); full interactive controls retained in miniature; explicit "Back to tab" re-dock (support.google.com/meet/answer/13665919).
- **Arc Mini Player**: media auto-detaches when you navigate away from its tab; hover-resize; site-level opt-out (resources.arc.net).
- **Takeaway:** the pattern has *graduated from media to general UI*. The Meet trigger model (navigation away ⇒ context survives as a float) is directly transplantable to "switch documents while mid-form-fill."

### Split view inside one tab/window
- **Edge split screen** (shipped): two sites side-by-side **in a single tab**; active/inactive views with distinct borders; toolbar applies to active view only; drag-tab-to-edge creates split; "separate two tabs" exits split but keeps both (explore.microsoft.com/edge/features/split-screen).
- **Chrome split view** (shipped): same model — two views per tab, click-to-activate, swap positions, separate/close individual views, drag-and-drop edge zones with "+ Create split view" affordance (support.google.com/chrome/answer/16971124).
- **VS Code editor groups**: unlimited side-by-side groups; `splitEditorInGroup` shows **two views of the same file**; grid layouts vertical+horizontal; closing last editor closes the group (vscode-docs userinterface.md).
- **Foxit already has split view + tab groups** for PDFs (Part I §2) — split is *parity-adjacent*, but our differentiator can be the diff/temporal layer below.

### Diff-view engineering lessons
- Side-by-side comparison fails when implemented as **two independently scrolling panes** — they drift, and equal scrollTop ≠ equal position when content heights differ. The robust pattern: **one scroll container, rows of paired cells**, so misalignment is unrepresentable rather than synchronized (dev.to "Two scrolling panes is the wrong way to build a side-by-side diff", 2026-08-12). Directly applicable to any split/diff mode we build.
- Word-level intra-line diff marks (with whitespace-token preservation) are what make side-by-side actually readable.

## 12. Round 2 wide pool (30 ideas, 5 new frames, clustered, scored N/V/F out of 10)

### Cluster E — PiP / floating reference (user-suggested direction)
- ★ **Reference PiP**: detach any page/region/search result into an always-on-top mini-pane that survives doc/app switching `[N7 V7 F9]`
- Hub-and-spoke workspace: persistent hub holds all states; spokes are disposable floats that check out and return state `[N7 V7 F8]`
- Ember dock: close compresses doc into warm searchable ember at screen edge, re-expands on glance `[N8 V5 F6]`
- Microbiome tray: closed docs as dormant thumbnails that auto-summarize/re-index in background `[N7 V4 F5]`
- Auto-PiP on app-switch via NSWorkspace notifications (Meet trigger generalized) `[N7 V6 F8]` *(sub-idea promoted)*

### Cluster F — Same-window splits & temporal diff (user-suggested direction)
- **Split-in-group**: two regions of the SAME document side-by-side in one window, shared scroll container where alignment matters `[N5 V8 F8]`
- ★ **Version time-scrub**: timeline under the page replays the operation ledger — edits/fills/highlights evolve frame-by-frame like video scrubbing `[N8 V6 F7]`
- Semantic diff lens between two PDF versions (AI overlay highlights changed clauses) `[N9 V4 F7]`
- Market-maker comparison pair: detect cross-compare intent, guarantee bilateral visibility `[N8 V5 F6]`

### Cluster G — Attention economics (markets frame)
- Reference lending strip: cheap sidecar of parked reference cards borrowable by any pane `[N8 V6 F7]`
- Attention clearing house: idle docs auto-demote to thumbnails, buy back on citation `[N7 V5 F6]`
- Bid-based screen inches / volatility pricing / futures leases `[N9 V3 F4]` *(traps — users cannot explain state)*

### Cluster H — Spatial maximalism
- Freeform canvas constellation with AI-drawn connection lines between related docs `[N9 V4 F6]`
- Reading orbits: annotations/bookmarks/linked docs as satellite objects around each doc `[N8 V5 F6]`
- Depth-based window manager (push docs into dimmed background layers) `[N8 V3 F4]`
- Foveal/peripheral ribbon reading across page boundaries `[N9 V4 F5]`
- Portable view-state "lenses" attachable to text and draggable across documents `[N8 V4 F6]`
- Pages with mass/inertia gravity piles; infinite spatial canvas; apoptosis edit visualizations *(wildcards)*

## 13. Round 2 convergence

Shortlist (weighted score):
1. **Reference PiP** `[7.5]` — the user's own instinct, validated by the platform trend (Document PiP API, Meet, Arc). Solves the #1 real workflow: fill form in A using data from B without keeping both fully open.
2. **Version time-scrub** `[6.95]` — **moat play**: requires an immutable operation ledger, which we already have and competitors don't. Foxit's static Compare becomes table stakes; nobody does temporal self-comparison. Synergizes with the northstar "what changed" report (one replay engine serves both).
3. **Reference lending strip** `[6.95]` — the memory-cheap substrate that makes PiP workflows scale; parked items are ~50–100KB descriptors, not live sessions; naturally app-scoped so isolation doctrine holds.

Split-in-group `[6.95]` rides along as the alignment-safe container these compose into.

Traps rejected: attention auctions/volatility pricing (unexplainable state), pure 3D depth managers (hardware theater), full spatial canvas (productivity tax for form-fillers).

## 14. Deepened branches (Round 2)

### Branch 4 — Reference PiP
**Sketch:** Borderless `NSPanel` (.nonactivatingPanel, .floating level, canJoinAllSpaces, fullScreenAuxiliary) hosting a SwiftUI mini-pane rendering either a read-only page snapshot (PDFPage.thumbnail — cheap, isolation-immune) or a live-linked projection through a narrow read-only protocol over the source AppModel (never sharing the model itself). Detach via selection context menu; Meet-style *suggested* detach (non-modal ghost pin button) when switching away mid-form-fill — never silent auto-detach. Close writes a lightweight detach record into session state; reopen restores snapshot-first, upgrades to live-link if source still open.
**Load-bearing risk:** live-linked panes are a hidden second consumer of a per-window AppModel — any mutation through the projection or dangling subscription after source close violates the isolation doctrine. Snapshot default avoids it at the cost of staleness → pair with a "region changed since detach" pulse badge.
**First concrete step:** spike — NSPanel showing static thumbnail of page N of doc A, verify float-across-spaces + clean focus return. No live linking yet.
**Sub-ideas:** multi-pane pinned stacks auto-tiled at screen edge; heuristic detachment moments (field focused >Ns, search result clicked); cross-app pairing via NSWorkspace notifications; snapshot staleness pulse badge; drag mini-pane onto another window → docks as in-window overlay.

### Branch 5 — Split-in-group + version time-scrub
**Sketch:** "Compare with self" opens a second region of the same document in one window; aligned pairs render as ONE scroll container of (pageA, pageB) row tuples — drift unrepresentable (per the diff-engineering lesson); independent panes only on explicit break. Version scrub maps ledger indices to a timeline strip; scrubbing renders ghost overlays of fills/annotations over the never-changing base render via `documentState(atLedgerIndex:)` replay. Composes: split panes can show op N vs op M of the same page = live before/after diff. Same engine emits the northstar "what changed" report.
**Load-bearing risk:** interactive-rate replay fidelity — scrub must re-apply arbitrary ledger prefixes fast and deterministically; a wrong-looking history is worse than none. Mitigate with lazy per-page delta projections validated against digests.
**First concrete step:** pure function `documentState(atLedgerIndex:)` + unit test asserting replay matches live state per recorded operation on a fixture session (reuses recovery-replay path).
**Sub-ideas:** color-coded timeline ticks by operation kind; onion-skin opacity slider between two ledger points; export a scrub range as PDF + change report; per-page Git-blame-style gutter in thumbnail rail; scrub-linked split panes.

### Branch 6 — Reference lending strip
**Sketch:** Parked item = lightweight descriptor {digest, pageIndex, rect, kind, viewState, ~150px thumbnail} — never a live PDFDocument/PDFView. Strip is app-scoped (holds no edit sessions ⇒ safe under isolation doctrine). Capture: drag selection to strip edge, ⌘⇧D park current view, park search results from find panel. Borrow promotes inline / to float / swaps into viewport; demote serializes scroll back and destroys renderer. ~50–100KB/card; 50-card strip ≈ single-digit MB.
**Load-bearing risk:** digest rot — source PDF changes on disk after parking ⇒ stale references trusted during form-filling (worse than no feature). Require mtime/digest check at borrow time + "reference drifted" affordance.
**First concrete step:** descriptor model + strip UI with manual capture (⌘⇧D, click-to-borrow-as-float) against a hardcoded two-doc fixture; validate promote/demote view-state round-trip and flat memory.
**Sub-ideas:** cross-document diff borrow (form-matching highlight); ⌘C auto-parks snippet cards with provenance (clipboard-history for PDFs); borrow chains pre-staging neighbor pages; ephemeral ⌘⇧S compare-with-auto-restore; strip persistence across launches as project context.

## 15. Combined roadmap picture (Round 1 + Round 2 layered)

| Wave | Ships | Source |
|---|---|---|
| 1 | Decoupled view memory + Save This Layout (+ restore hardening riders) | Part I Branch 1 |
| 2 | Close-as-hub + ⌘⇧T reopen | Part I Branch 2 |
| 3 | Native macOS tabbing | Part I Branch 3 |
| 4 | Split-in-group (same-doc two regions, drift-proof container) | Part II Branch 5a |
| 5 | Reference PiP (NSPanel snapshots first, live-link later) | Part II Branch 4 |
| 6 | Lending strip feeding PiP/split | Part II Branch 6 |
| 7 | Version time-scrub on the operation ledger (moat) | Part II Branch 5b |

Rationale for ordering: waves 1–3 settle the *memory and container* contracts the later features consume (view state schema, hub/recents store, window identity). PiP before scrub because it's lower-risk and answers the daily form-fill pain; scrub last because it's highest-value but depends on ledger-projection engineering.

## 16. Round 2 falsifiers / revisit triggers

- If NSPanel PiP proves flaky across Spaces/full-screen on target macOS versions, degrade to in-window compact overlays (loses cross-app value, keeps cross-doc value).
- If ledger replay can't hit interactive rates for scrub, ship scrub markers (jump-to-op) instead of smooth scrubbing — markers alone are still differentiated.
- Revisit Document-PiP-style patterns if Apple ships an AppKit-native equivalent (would remove the NSPanel management burden).

## 17. Part II provenance

- Chrome Document Picture-in-Picture API: developer.chrome.com/docs/web-platform/document-picture-in-picture; MDN Web API docs.
- Google Meet auto-PiP: support.google.com/meet/answer/13665919.
- Arc Mini Player: resources.arc.net/hc/en-us/articles/19234766331799.
- Edge split screen: explore.microsoft.com/en-us/edge/features/split-screen.
- Chrome split view: support.google.com/chrome/answer/16971124.
- VS Code editor groups / split-in-group: github.com/microsoft/vscode-docs (docs/getstarted/userinterface.md).
- Diff-view engineering lesson: dev.to "Two scrolling panes is the wrong way to build a side-by-side diff" (2026-08-12).
- Idea generation: 5 isolated divergent agents (frames: remove-load-bearing-assumption, biology, logistics, markets, infinite-budget-spatial) + 3 focus/deepen agents, run 2026-08-26.

## Part I provenance

---

# PART III — Round 3: acceleration, emergence, provenance — and the fantasy line

*Appended 2026-08-26. User direction: "keep exploring until you think now everything is just fantasy." Five frames not yet used: speedrunner, ant colony, regulator, hardware engineer, $0-budget.*

## 18. Round 3 wide pool (30 ideas, clustered, scored N/V/F out of 10)

### Cluster I — Workflow acceleration (speedrunner)
- ★ **Cross-document field graph**: fill one form; matching fields across all open PDFs populate from one value set `[N8 V7 F9]` *(synergy: extends existing field-suggestions architecture)*
- **Universal omnibox**: one input resolves text/page/field/annotation + selection-context verbs (`[N6 V8 F8]`
- Selection-as-verb-target palette (select amount → extract / sum / find-everywhere) `[N7 V7 F7]`
- Ghost-keystroke macros with positional anchors replayable across documents `[N6 V6 F6]`
- Edge-fling park slivers at screen boundaries `[N7 V5 F6]` *(overlaps Reference PiP)*
- Batch-inspect folder as one continuous canvas with global operations `[N7 V4 F5]`

### Cluster J — Emergent organization (ant colony)
- Field "scent": repeated same-value fills offer that value on focus anywhere `[N8 V6 F8]` *(merges into field graph)*
- Copy-paste traffic trails surface diff-and-merge candidates `[N8 V4 F5]`
- Co-open timing threads auto-assemble tab groups `[N8 V4 F5]`
- Heat-momentum scroll physics near annotated hotspots `[N8 V4 F4]`
- Ink desaturation lived-in map; highlight-color code drift `[N8/N9 V2-3 F3-4]`

### Cluster K — Provenance made tangible (regulator) ★ moat cluster
- **Sealed-signature graying**: post-signature edits desaturate the signature in real time `[N8 V7 F8]`
- **Field blame gutter**: op-id + timestamp per filled value, version-control style `[N8 V7 F8]`
- **Digest notary slots**: pin a page digest; every open shows green/red vs recomputed bytes `[N7 V8 F7]`
- Chain-break quarantine naming the first failing operation `[N7 V7 F7]`
- Break-the-seal ritual with recorded refusal acknowledgment `[N7 V7 F7]`
- **Counterparty receipt**: export emits a hand-off verifiable digest-chain receipt `[N8 V6 F7]`

### Cluster L — Rendering physics as interaction (hardware engineer)
- Tile-cache patina, backpressure scrolling, prefetch frontier, frame-budget time dilation, memory tide, ink-curing commits `[N8-9 V2-4 F2-5]`

### Cluster M — $0-budget crude versions (validates cheap fallbacks for everything)
- View memory via NSWindow state restoration + xattr stash (~50 lines); hub via `NSDocumentController.recentDocumentURLs` + Quick Look thumbnails; tabs = one line `.tabbingMode = .preferred`; split/PiP = NSSplitViewController + second PDFView on shared PDFDocument / nonactivating NSPanels; scrub slider bound to UndoManager steps
- New crude ideas: **page tear-off** (drag thumbnail to Finder → single-page PDF, ~20 lines) `[V9]`; **cross-document find bar** (one search across all open docs → NSTableView of hits) `[V9]`

## 19. Round 3 convergence

1. **Cross-document field graph** `[7.85]` — highest score of all three rounds. Deepen-agent verified it layers onto the *existing* pipeline (FieldLabelCanonicalizer → ProfileStore.matchScore → suggestion chips): only scope, fan-out, provenance badges, and consent UX are new.
2. **Tangible provenance instruments** `[~7.5 avg]` — four UIs over ONE ledger-query engine; they can never disagree about tamper state. Unique to our architecture.
3. **Universal omnibox** `[7.3]` — extends the northstar's already-specified ⌘G stable-result-ID language into browser-command-palette territory.

## 20. Round 3 deepened branches

### Branch 7 — Cross-document field graph
**Sketch:** Session-scoped index keyed by canonicalized displayName mapping confirmed fills to {docDigest, fieldID, value, timestamp}. On confirm, publish; other open documents' inspector cards show the same provenance-badged chip ("from W-4.pdf · Full Name"). Scent variant falls out free: frequency-ranked values per canonical label. Consent is load-bearing: chips stay opt-in taps; "apply to all matching" is an explicit batch action with a review list — never silent population.
**Load-bearing risk:** wrong-value propagation into N legal documents (same-label-different-meaning collisions, e.g., "Date"). Mitigations: match-explanation cards, per-field gates never bypassed, label-collision abstention, provenance chain walk for retract.
**First concrete step:** extend ProfileStore.lastValueSuggestions into CrossDocumentFieldGraph; provenance-badged chips before profile suggestions; validate against two documents in swift tests.
**Sub-ideas:** batch-apply sheet with diff preview; hover provenance chain + one-click retract everywhere; scent decay ranking; collision disambiguation card; additive session-contract entries carrying label *hashes* not raw values (zero-content logging doctrine).

### Branch 8 — Tangible provenance instruments
**Sketch:** One engine — `query(digest, since_op_id?) -> OpChain` with signature-boundary markers. Graying = live subscription (ops after signature sequence number ⇒ desaturate). Notary slots = pinned queries recomputed on open. Blame gutter = reverse scan for last-setting op. Receipt = canonical serialization of chain head. All consume identical projection ⇒ consistent tamper state by construction.
**Load-bearing risk:** quasi-legal weight of visuals — graying could falsely imply invalidity for legitimate post-signature annotation; green slots confer false confidence on third-party signatures we never witnessed being applied. Engine must distinguish "bytes unchanged since first observation" from "cryptographically valid," and copy must say so.
**First concrete step:** implement the query API with signature-boundary markers; build graying as first consumer.
**Sub-ideas:** tamper-distance meter (op-count/byte-delta badge); receipt verification endpoint (paste receipt → diff since issuance); notary slot export inside review report; "unwitnessed" boundary marker for pre-existing third-party signatures; ledger-navigable time-travel scrubber *(links back to Branch 5)*.

### Branch 9 — Universal omnibox
**Sketch:** ⌘K overlay normalizing queries into typed results: text hits (PDFDocument.findString), pages ("p12"), form fields (fuzzy over AcroForm names+labels, cached per document), annotations, recents. Ranking = kind prior × match quality × position boost × recency; stable result IDs let ⌘G/⇧⌘G cycle without re-ranking. Selection publishes a SelectionContext that pins verb rows (Sum / Extract / Find Everywhere) which vanish when selection clears. Existing find infrastructure becomes omnibox providers, not a parallel path.
**Load-bearing risk:** heterogeneous ranking feels unpredictable — "12" must deterministically mean page 12, not a text hit. Explicit prefixes (p:/f:/a:/) and sticky last-used-kind are load-bearing day one.
**First concrete step:** Provider protocol + shell with two providers (findString, page-number parsing) wired to existing ⌘G cycling.
**Sub-ideas:** namespace prefixes doubling as filters; recent-destinations ring as zero-query state; inline HUD preview during ⌘G traversal; fuzzy field provider cached with document; verb bar under highlighted results.

## 21. THE FANTASY LINE — saturation verdict

After 3 rounds, 10 cognitive frames, ~90 raw ideas, and 9 deepened branches, the idea space is mapped. Classification of the residual tail:

**Still real (would survive a build-feasibility filter):**
- Everything in waves 1–7 (Part II §15) plus Branches 7–9 above, plus the $0-budget fallbacks (Cluster M) proving each has a cheap entry version, plus page tear-off and cross-document find bar as micro-features.

**Theater — looks profound, fails the productivity test (why we stop here):**
- Rendering-physics interactions (memory tide, time dilation, backpressure friction, cache patina): they surface *internal plumbing* as gameplay. Fascinating demo, daily tax for a form-filler. Violates "user must be able to explain what happened."
- Emergent social-ish behaviors (co-open silk threads, ink desaturation maps, color-code telepathy): state the user cannot predict, verify, or turn off meaningfully. Same doctrine violation, worse: silently changes what documents look like.
- Attention auctions/futures leasing (markets tail): metaphor collapse — nobody wants to manage a portfolio of pixels.

**The pattern across all three rounds:** ideas stayed viable exactly as long as they transplanted a *mechanism* (resume memory, PiP containment, ledger replay, label matching). They turned fantastical the moment they transplanted a *mood* (thermal warmth, living ink, market anxiety). That's the falsifiable line, and we've hit it.

**Recommendation:** exploration is saturated. Freeze the frontier map as: Waves 1–7 + Branches 7–9 (ten buildable units), each with a documented $0-budget fallback. Next action should be building Wave 1, not Round 4.

## 22. Part III provenance

- Idea generation: 5 isolated divergent agents (frames: speedrunner, ant colony, regulator, hardware engineer, $0-budget) + 3 focus/deepen agents, run 2026-08-26.
- Repo synergy evidence: `Docs/explorations/field-suggestions-exploration-2026-08-25.md`, `Docs/provider-capability-system-design.md` (read by Branch 7 deepen agent); northstar ⌘G spec (Branch 9).

---

# PART IV — Round 4: lead deepens + Lightroom/DAW transplants

*Appended 2026-08-26 per user direction to continue exploring remaining leads (F35–F40) and follow newly found transplant domains.*

## 24. Round 4 results

### 24.1 Deepened leads (Branches 10–15)

**Branch 10 — Selection-as-verb palette** *(F35)*
One `VerbEngine` in PDFEditorCore: selection classified into typed SelectionContext (span, numeric tokens, nearby fields); verbs are pure `(context) -> [Verb]` with applicability predicates. Omnibox ⌘K and anchored palette are **two renderers over one ranked verb list**. Palette wins where the verb's argument IS the selection (page-local sum, fill-this-field); appears ~150ms post-selection-settle, <30ms classification budget; heavy verbs stream results via badge instead of blocking. **Risk:** verb spam — each verb needs measured false-positive rate before shipping. **First step:** prototype "Sum amounts on page" end-to-end against cached page text. Sub-ideas: deferred-result streaming badge; find-everywhere bridge into search infra; fired-vs-dismissed telemetry loop.

**Branch 11 — Anchored macros** *(F36)*
Because edits are already typed ops carrying labels/page indices (not pixel coords), recording a macro = serializing a contiguous op range — undo history and macro candidates are the same data structure viewed differently. Replay resolves anchors at run time ("field labeled Date"), dodging the coordinate-brittleness that killed IDE macros. Ledger immutability adds what Photoshop never had: dry-run replay on shadow copy + first-class failure ops + transactional rollback. **Risk:** brittleness moves from coordinates to ambiguity — silent wrong-stamping; mitigation = mandatory resolution report gated behind confirmation. **First step:** "save last N ops as macro" with verbatim coordinate passthrough (proves plumbing, serves same-template workflows immediately). Sub-ideas: ghost-preview overlay diff before commit; parameterized slots with prompts; insert-pause anchors; fallback chains (exact→fuzzy→relative→abort); folder-batch replays recorded as auditable success/failure entries.

**Branch 12 — Batch-inspect mode** *(F37)*
Four phases over the headless core: scan/index (existing preflight per file + match extraction keyed by digest) → aggregate (unified result surface, hits carry {docID, page, rect}) → review (diff-style preview, nothing mutates until commit) → commit (per-document transactions, sequential headless, recovery manifest records {sourceDigest → backupPath + opLog}). Failure of 3 of 50 files ⇒ 47 committed, 3 quarantined with reasons, all reversible. **Risk:** irreversible bulk redaction across corpora — mandatory preview, digest-keyed originals retention with explicit purge policy, per-document atomicity. **First step:** `batchSession(folderURL)` returning scan/index report as JSON before any UI. Sub-ideas: virtualized unified match surface; named re-runnable operation bundles ("redact SSNs + stamp DRAFT"); progressive commit streaming with cancel-safe checkpoints.

**Branch 13 — Paste traffic ledger** *(F38 — ant-colony idea salvaged to explainable form)*
Relationship discovery kept, pheromone field dropped: every copy/paste or cross-doc field write appends a visible row to a per-document Traffic list (source→target→timestamp). Clustering runs only when the user opens Traffic view; suggestions cite their evidence rows inline; one-line compare suggestion only at explicit moments (open/export), dismissible once. **Risk:** provenance decay — clusters must stay traceable to concrete transfer rows forever, else opacity returns. **First step:** instrument flows into a persisted traffic log + read-only Traffic inspector panel (no suggestions yet).

**Branch 14 — Named-layouts library** *(F39)*
App-wide array of `{id, name, scaleMode, zoom(absolute-only), viewMode, rotation, pagePositionPolicy}` — fit-modes rather than absolute zoom keeps layouts sensible across page sizes. Precedence: doc pin > last applied named layout > global LayoutRestorePolicy. Layouts are **apply-once snapshots**, not sticky state — no enum change needed. **Risk:** scope creep into preset-manager-with-sync; stickiness would duplicate the pin's job. **First step:** refactor pin path into shared `LayoutSnapshot` struct + `apply(snapshot:)`; "Save Current as Layout…" serializes through the identical pipeline. Sub-ideas: "Reset to policy default" menu item; aspect-ratio auto-naming; .json export before any iCloud sync.

**Branch 15 — Fractional scroll anchor** *(F40)*
Extend ViewStateSnapshot to `{pageIndex, fractionIntoPage, anchorX, anchorY}` — both normalized against intrinsic unrotated crop-box geometry, so they survive resize/fit changes free; rotation maps axes at restore time. Restore order load-bearing: displayMode → magnification → force layout → single `go(to:on:)`. Single-page mode ignores fractions; crop-box change >10% discards anchor, keeps page. **Risk:** continuous-mode layout isn't final until after a layout pass — restore must defer one cycle, causing potential wrong-position flash unless drawing is suppressed one frame. **First step:** failing unit test capturing mid-doc snapshot, simulating 90° rotation + resize, asserting restored visible-rect-center matches within epsilon. Sub-ideas: page-space CGPoint anchor variant; "pin to text" refinement via nearest-character resolution; debug crosshair overlay.

### 24.2 New-frame pools (scored N/V/F out of 10)

**Lightroom transplants:**
- ★ **Before/after Y|Y split** — original vs edited state side-by-side, zero diff algorithm needed `[N6 V8 F8]`
- Ledger snapshots: named in-session bookmarks pointing into the op ledger for quick A/B `[N7 V7 F7]`
- Copy settings between documents (annotation/stamp/crop styles like Develop sync) `[N7 V6 F7]`
- Session filmstrip `[N5 V7 F6]` *(overlaps hub/recents)* · flags/smart collections on sessions `[N6 V5 F5]` · auto-sync batch replay `[N7 V6 F6]` *(overlaps macros+batch)*

**DAW transplants:**
- ★ **Bounce-in-place**: bake selected pages' ops into a self-contained PDF handoff artifact; original untouched — the natural exit ramp from non-destructive editing `[N7 V7 F8]`
- **Workspace scenes**: named snapshots of entire multi-window arrangement recallable in one click (mixer scenes → window management) `[N7 V6 F7]`
- Freeze/flatten document → locked render cache, cheap reopen without full ledger replay `[N7 V6 F6]`
- Comping edit-takes per page `[N9 V4 F5]`, loop-brace review ranges `[N8 V4 F5]`, automation lanes `[N9 V3 F4]` *(drifting toward fantasy for productivity use)*

### 24.3 Round 4 convergence

Six leads fully designed (Branches 10–15), plus **three new buildable units**: Y|Y before-after split, bounce-in-place handoff, workspace scenes. Heavy overlap observed (filmstrip≈hub, auto-sync≈macros+batch, copy-settings≈macro subset) — marginal novelty declining sharply.

### 24.4 Updated saturation verdict

Round 4 was worth running: it converted six vague leads into engineered designs and added three units. But the overlap ratio tripled versus Round 3, and the DAW tail (comping, automation lanes) already shows mood-transplant drift. Marginal value per additional round is now clearly negative-to-flat. **Saturation re-confirmed at Round 4. Exploration closes here.**

## 25. Part IV inventory additions

| # | Finding | Type |
|---|---|---|
| F41 | VerbEngine: omnibox verbs and selection palette must be renderers of ONE ranked verb engine | B/C |
| F42 | Macro record/replay ≈ serialized ledger range; dry-run + transactional replay possible due to immutability | B |
| F43 | Anchor resolution needs mandatory resolution-report gate; failure modes move from coords to ambiguity | H |
| F44 | Batch mode: per-document transactions + quarantine lane + digest recovery manifest; redaction demands originals-retention policy | B/H |
| F45 | Paste traffic must be an inspectable ledger, never ambient behavior; clusters cite evidence rows | B/C |
| F46 | Named layouts are apply-once snapshots; sticky state would duplicate pins and break precedence | C |
| F47 | Scroll anchor stored in unrotated crop-box normalized space survives rotation/resize by construction; restore defers one layout cycle (flash risk) | H/B |
| F48 | Y\|Y before/after split requires no diff algorithm — render two states | B |
| F49 | Bounce-in-place is the canonical exit ramp from non-destructive ledger to shareable artifacts | B |
| F50 | Workspace scenes = mixer-scene model applied to multi-window arrangements; supersedes per-doc layouts for power users | E |
| F51 | Freeze/flatten as perf primitive: frozen docs skip full ledger replay on reopen | E |

## Part IV provenance

- Idea generation: 6 focus/deepen agents (leads F35–F40) + 2 divergent agents (frames: Lightroom/photo-editing pipeline, DAW/music production), run 2026-08-26.

---

---

# PART V — Round 5: CAD / legal / cartography / archive / aviation

*Appended 2026-08-26 per user direction ("another pass… when you feel it's getting into fantasy"). Five untouched transplant domains.*

## 26. Round 5 pool (30 ideas, scored N/V/F out of 10)

### CAD/architecture
- ★ **Export profiles**: each export declares which op types are included/flattened/omitted (print flags over the ledger) `[N8 V6 F8]`
- **Live-linked overlays**: attach another PDF as digest-aware reference overlay; stale-marker until re-synced (xrefs) `[N8 V6 F7]`
- Model-bound vs view-bound annotation anchoring (survive crop/rotation) `[N7 V6 F6]` *(also a correctness finding)*
- Per-region edit locks `[N7 V6 F6]` · design options per page picked at export `[N8 V5 F6]` · sheet-set issues with generated index `[N6 V5 F5]`

### Legal practice
- ★ **Bates stamping engine** with ledger-recorded renumber-on-insert `[N6 V9 F7]`
- Exhibit tags → auto-generated linked exhibit list `[N7 V7 F7]` · redline mode w/ accept/reject state `[N7 V6 F7]` · playbook review checkpoints `[N7 V6 F7]` · clause library `[N6 V7 F6]` · privilege log builder `[N6 V5 F5]`
- *(Cluster insight: these five are one vertical — a "matter" workspace — not five features)*

### Cartography
- ★ **Thematic overlays**: toggleable layers — all links / all fields / all tracked changes over the rasterized page `[N6 V8 F7]`
- **Legend panel** decoding annotation symbols with live counts per page `[N6 V8 F7]`
- Inset viewport map in corner of spread `[N5 V8 F7]` · citable document-coordinate graticule `[N7 V5 F5]` · route/reading-path annotations `[N8 V4 F5]` · zoom-dependent text generalization `[N8 V3 F4]` *(fantasy for text documents)*

### Museum/archive
- Custody-transfer logging on export (loans) `[N7 V6 F7]` *(extends counterparty receipt)*
- Finding aids: auto-generated hierarchical session inventory `[N7 V5 F5]` · deaccession workflow for deliberate deletion `[N6 V5 F5]` · significance-based safeguard tiers (appraisal) `[N8 V4 F5]` · exhibition labels on share `[N7 V4 F5]` · conservation treatment records `[N6 V5 F5]`

### Aviation CRM
- ★ **Sterile mode** during sign/submit (Focus-filter integration, default-on, reversible) `[N8 V7 F7]`
- Challenge-response field checklist with learned collapse `[N7 V6 F7]` · post-flight debrief toast `[N7 V6 F7]` · typed 'GO' for undo-exceeding bulk ops `[N7 V6 F6]` · readback only on overwrite collisions `[N7 V6 F6]` · fixed scan-order flows `[N7 V5 F6]`

## 27. Deepened bundles (Branches 16–18)

**Branch 16 — Legal practitioner toolkit** *(one primitive, four shells)*
Everything reduces to a typed `DesignationOp`: region anchor (page/rect or text range) + metadata template. Bates = designation family whose projection is the numbering map; exhibit tags generate the linked list; redlines add accept/reject resolution state; privilege marks assemble the running log. Index documents are pure projections over the op stream — regenerate free after undo or renumbering. One anchor-resolution layer, one projection renderer, four thin shells. **Risk:** renumbering cascades corrupt positional anchors ⇒ anchors must be identity-based; redline fidelity will be judged against Word compare/Litera. **First step:** `DesignationOp` in the typed ledger + one projection rendering an index table; prove insert-a-page-mid-document survival before any UI.

**Branch 17 — Export profiles**
Declarative predicates over the ledger: `rebuild(ledger.filter(profile))` — northstar's "export never reads view state" satisfied by construction. Three-layer schema: type-level defaults, instance pins ("keep op #47 verbatim"), dependency manifest from the ledger's causal graph. Resolver computes transitive closure of retained-op dependencies; omission fails fast on dangling references; flattening replaces subtree with leaf op. Export sheet shows read-only include/flatten/omit buckets + validation report. Composes: bounce-in-place bakes profile ID+hash into artifacts; receipts cite `{profileId, profileHash, ledgerRange}` ⇒ every export reproducible from `(ledger, profile)` alone. **Risk:** dependency-manifest incompleteness silently under-reports breakage — must be exhaustive and versioned with op schemas. **First step:** pure `resolveProfile(ledger, profile) -> violations` dry-run + three seed profiles as fixtures against a synthetic cross-referencing ledger. Sub-ideas: inheritance deltas ("Client copy + legal hold"); user-language loss lint enumerating what recipients won't see; live bucket inspector scrubbing ops in real time.

**Branch 18 — Commit-discipline suite (calibrated)**
Frequency × irreversibility matrix decides which mechanisms earn friction: typed GO non-negotiable but reserved for ops exceeding undo capacity or touching signed/flattened documents; readback fires only on overwrite collision (silent pass-through otherwise); checklist collapses to a green summary banner after demonstrated mastery (learned-preference doctrine); sterile mode default-on via macOS Focus integration (free, familiar, reversible); debrief is a dismissible toast, never modal. **Composition rule: ceremony substitutes for undo ONLY where undo is impossible — everywhere else undoability wins.** **Risk:** ceremony creep breeds dismissal reflexes, weakening even the typed-GO gate when it matters. **First step:** typed-GO as modifier on the planned batch confirmation sheet + dismissal-latency telemetry before adding any other member.

## 28. Round 5 verdict — the axis shift

Round 5 still yielded mechanisms (the well was deeper than Round 4 suggested), **but every viable idea moved off the app shell onto two new axes**:
1. **Vertical domains** — legal/matter workflows (Branch 16), compliance/export semantics (17)
2. **Commit & exit semantics** — how work leaves the app safely (17, 18)

Zero new shell-interaction units surfaced (overlays/legend/inset-map are inspector features, not navigation models). Further shell rounds would now yield mood transplants — cartography's generalization and the archive tail already show the drift. **Shell exploration: closed at Round 5. Vertical/export exploration: opened, with Branches 16–18 as its founding candidates.** Whether to run vertical-domain passes (healthcare, government forms, insurance) is a product-strategy decision, not an exploration-momentum one.

## 29. Part V inventory additions

| # | Finding | Type |
|---|---|---|
| F52 | Legal toolkit = ONE DesignationOp primitive + projections; identity-based anchors mandatory for renumber survival | B/H |
| F53 | Redline fidelity bar is Word compare/Litera — ship only if round-trip parity plausible, else abstain | C |
| F54 | Export profiles make "export never reads view state" true by construction; receipts/bounce artifacts should cite `{profileId, hash, ledgerRange}` | B/C |
| F55 | Op dependency manifest must be exhaustive + versioned with schemas or profile resolution silently under-reports breakage | H |
| F56 | Commit ceremony substitutes for undo ONLY where undo impossible; universal trigger = undo-capacity threshold | C/B |
| F57 | Dismissal-latency telemetry should gate rollout of any commit-ceremony mechanism | H |
| F58 | Sterile mode best implemented as macOS Focus-filter integration, not in-app dimming | E |
| F59 | Thematic overlays + legend are cheap inspector wins sharing one annotation-index query | M/E |
| F60 | Live-linked overlays need digest-watch + stale markers — same machinery as parked-reference rot checks (F22) | E/C |


## 30. Parked exploration area: vertical-domain passes (for later)

*Recorded 2026-08-26 per user direction. This is deliberately **not** run now.*

**What was observed:** Rounds 1–5 exhausted the app-shell interaction space; Round 5's surviving ideas all migrated onto vertical domains and exit/commit semantics. The shell question ("what's left to discover about how the app itself should behave?") is answered. A different question remains open and parked: *"which user domains deserve purpose-built depth on top of our primitives?"*

**Candidate verticals identified but not explored:**
| Vertical | Anchor evidence | Hypothesized fit with existing primitives |
|---|---|---|
| Legal / litigation | Branch 16 toolkit; Bates/exhibits/redlines/privilege log all reduce to DesignationOp | High — ledger + designations are the natural substrate |
| Government forms | Existing form-fill candidate detection + field-suggestions + cross-doc field graph (Branch 7) | High — repetitive labeled fields across form families |
| Healthcare (HIPAA-sensitive) | Redaction/batch machinery (Branch 12), provenance instruments (Branch 8) | Medium — privacy constraints raise the bar |
| Insurance / claims | Batch mode + export profiles + custody logging | Medium — document-heavy claim packets |
| Compliance/audit shops | Review reports, notary slots, receipts (northstar ledger-report concept) | Medium |

**Entry criteria for running this pass later:**
1. Product-strategy prioritization has chosen commercial direction (anchor: `Docs/pdf-pricing-marketing-exploration-2026-08-25.md`, `Docs/market-strategy.md`).
2. At least Waves 1–3 shipped (shell contracts stable), ideally Wave 7 time-scrub proving the ledger-projection engine.
3. Each pass must reuse the established method: divergent transplant frames per domain → score → deepen → explainability filter (mechanisms yes, moods no).

**Why parked rather than dropped:** the legal toolkit (F52) already shows verticals multiply value of core primitives cheaply — one primitive became four features. The same leverage likely exists in the other rows. This is expansion *of* the moat, not discovery of it.

## Part V provenance

- Idea generation: 5 isolated divergent agents (frames: CAD/architecture, legal practice, cartography, museum/archive curation, aviation CRM) + 3 focus/deepen agents (Branches 16–18), run 2026-08-26.
- Parked verticals recorded per user direction same day.

# APPENDIX — Master findings inventory (explicit + implicit)

*Extracted 2026-08-26 as the actionable index of Parts I–III; extended by Parts IV–V (F41–F60). Status legend: **B** = buildable unit, **H** = hardening/correctness finding, **C** = constraint to respect, **M** = micro-feature, **E** = future exploration.*

### Explicit findings (directly observed/stated) — Parts I–III
| # | Finding | Type | Source |
|---|---|---|---|
| F1 | New docs open fit-width/continuous fixed; no global last-used preference | B (Wave 1) | §1, `AppModel.swift:131-134` |
| F2 | Per-digest view autosave already exceeds competitor parity (Acrobat/Foxit are opt-in) | C (asset) | §1–2 |
| F3 | No "Save This Layout" control anywhere | B (Wave 1) | §1 |
| F4 | Close is window-scoped only; last-doc close strands app window-less with no designed state | B (Wave 2) | §1 |
| F5 | No tabs; multi-window ⌥⌘N; roadmap pre-seeds "Move Tab to New Window when tabs are supported" | B (Wave 3) | §1, northstar:420 |
| F6 | Document PiP API (2024) proves always-on-top arbitrary-content panes are a mainstream pattern | E→B (Wave 5) | §11 |
| F7 | Meet auto-PiP trigger model (navigate-away ⇒ context survives as float) transplantable | B (Wave 5) | §11 |
| F8 | Edge/Chrome split-view-in-one-tab + VS Code split-in-group are now standard patterns | B (Wave 4) | §11 |
| F9 | Two independently-scrolling panes drift; paired-row single scroller is the robust diff/split structure | C | §11 |
| F10 | Field-suggestions pipeline (canonicalizer→matchScore→chips) extends directly cross-document | B (Branch 7) | §20 |
| F11 | Immutable operation ledger uniquely enables time-scrub, provenance instruments, change reports — competitors can't copy without the ledger | B/C (moat) | §14, §20 |
| F12 | Every major candidate has a ~50-line crude fallback ($0-budget proof) | C (de-risking) | §18 Cluster M |
| F13 | Planned Open Recent (G-04) is the shared substrate for hub/recents/recently-closed | C | §3 |
| F14 | IMP-07 reserved Settings slot fits the LayoutRestorePolicy picker | C | §3 |

### Implicit findings (surfaced by analysis) — Parts I–III
| # | Finding | Type | Source |
|---|---|---|---|
| F15 | Latent restore-order hazard: magnification must apply BEFORE scroll-anchor recompute, else anchor lands wrong even today | H | §6 Branch 1 |
| F16 | Restore path lacks out-of-bounds snapping (page > EOF, rotation ∉ {0,90,180,270}, zoom outside clamps) | H | §4 Cluster A |
| F17 | Saved-state apply should gate on first successful render pass (corrupt blob must not wedge initial UI) | H | §4 Cluster A |
| F18 | Atomic-write + previous-generation self-heal worth auditing in SessionStore | H | §4 Cluster A |
| F19 | Recently-closed stack must unify with Open Recent persistence or be explicitly session-scoped | H/C | §6 Branch 2 |
| F20 | SwiftUI WindowGroup can silently recreate NSWindows — tabbingMode/delegates need defensive reassertion | C/H | §6 Branch 3 |
| F21 | PiP live-link requires a narrow read-only projection protocol; snapshot-first with staleness pulse badge is safe default | C/B | §14 Branch 4 |
| F22 | Parked-reference descriptors rot when source bytes change — borrow-time digest check + "reference drifted" affordance required | H | §14 Branch 6 |
| F23 | Visual tamper signals acquire quasi-legal weight; must distinguish "bytes unchanged since observation" from "cryptographically valid"; third-party signatures are "unwitnessed" boundary | C/H | §20 Branch 8 |
| F24 | Cross-doc value propagation needs consent gates never bypassed + label-collision abstention + provenance-chain retract | C/H | §20 Branch 7 |
| F25 | Zero-content logging doctrine ⇒ field-graph session entries carry label hashes, not raw values | C | §20 Branch 7 |
| F26 | Omnibox heterogeneous ranking must be deterministic (namespace prefixes p:/f:/a:/) or muscle memory breaks | C/H | §20 Branch 9 |
| F27 | Hub entry is a natural trigger for stale-recovery compaction | E | §6 Branch 2 sub-idea |
| F28 | UndoManager is a sufficient cheap ledger-projection for v1 scrub (before full typed-op replay) | E | §18 Cluster M |
| F29 | Split/diff alignment should be unrepresentable-by-construction (row tuples), independent panes only on explicit break | C | §11, §14 Branch 5 |
| F30 | Fantasy boundary falsifier: mechanism transplants stay viable; mood transplants fail explainability doctrine | C (scope guard) | §21 |

### Micro-features
| # | Finding | Type |
|---|---|---|
| F31 | Page tear-off: drag thumbnail to Finder → single-page PDF (~20 lines) | M |
| F32 | Cross-document find bar across all open documents → results table | M |
| F33 | "Restored saved layout" transient status message on pinned-layout open | M |
| F34 | Pinned-layout toolbar badge near zoom readout with one-click clear | M |

### Exploration leads — status after Rounds 4–5
| # | Lead | Outcome |
|---|---|---|
| F35 | Selection-as-verb palette | Designed — Branch 10 |
| F36 | Ghost-keystroke macros w/ positional anchors | Designed — Branch 11 |
| F37 | Batch-inspect folder canvas | Designed — Branch 12 |
| F38 | Copy-paste traffic trails | Salvaged to ledger — Branch 13 |
| F39 | Named-layouts library | Designed — Branch 14 |
| F40 | Fractional scroll anchor | Designed — Branch 15 |
