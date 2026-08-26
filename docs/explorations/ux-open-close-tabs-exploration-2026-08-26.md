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

- Competitive facts: Adobe support docs/community (superuser.com/questions/149948), Apple Preview support pages (support.apple.com/guide/preview/prvw1495), Foxit KB (kb.foxit.com/s/articles/360040661331), PDF Expert blog (pdfexpert.com/how-to-read-pdf), superuser.com/questions/20675 (Okular/Foxit/Skim tab support), makeuseof.com Okular review.
- Repo evidence: file:line citations in §1 and §3 above.
- Idea generation: 5 isolated divergent agents (frames: game designer, inversion, 3am on-call, hostile competitor, 10-year-old) + 3 focus/deepen agents, run 2026-08-26.
