# macOS HIG Rule-by-Rule Design Audit (macos-design-guidelines skill)

**Project:** PDF Editor
**Audit date:** 2026-08-24
**Skill applied:** `/Users/pranay/.zcode/skills/macos-design-guidelines/SKILL.md` (Apple HIG codified into numbered, checkable rules)
**Audit scope:** Native macOS surface only (`Sources/PDFEditorApp/` — `PDFEditorApp.swift`, `AppCommands.swift`, `ContentView.swift`, `AppModel.swift` UI-facing state). The web companion is out of scope for HIG rules; parity implications are noted where relevant.
**Companion document:** [`macos-app-design-review-and-todo-2026-08-24.md`](macos-app-design-review-and-todo-2026-08-24.md) (architecture-first review, different skill). This audit is deliberately rule-cited and UI-convention-focused; it does not repeat that document's architecture findings except to record deltas.
**Mode:** Read-only source audit. No product code changed in this pass.
**Evidence tier:** T1 / S0 (static source inspection), with cross-references to existing T2 evidence.

---

## 1. Verdict on the skill's usefulness

**Useful. Keep it in the project toolkit.** Three reasons:

1. It converts HIG from prose guidance into numbered rules with an evaluation
   checklist, which makes compliance auditable and re-runnable after UI changes.
2. It found concrete, user-visible gaps the architecture-first review did not
   enumerate (drag-and-drop opening, context menus, Open Recent, document title
   bar state, Reduce Motion, search field placement).
3. Cross-checking it against the existing design review exposed that the review
   ledger is stale in at least five places (see §4). A rules-based re-audit is a
   cheap way to keep that ledger honest.

It does **not** cover architecture, state ownership, or product semantics — the
existing design review and doctrine own those. The two documents are complements,
not alternatives.

---

## 2. Compliance summary

| Skill section | Weight | Status | Notes |
|---|---|---|---|
| 1. Menu Bar | CRITICAL | **Mostly compliant** | Standard structure, shortcuts, dynamic enablement. Missing: Open Recent, Print, state checkmarks, action-specific Undo titles, Cmd+0. |
| 2. Windows | CRITICAL | **Partially compliant** | Resizable, multi-window, close confirmation. Missing: document name in title, edited indicator, proxy icon. |
| 3. Toolbars | HIGH | **Mostly compliant** | Labeled items, segmented view control, status area. Not customizable; search not in toolbar. |
| 4. Sidebars | HIGH | **Deviation** | `HSplitView` panes instead of `NavigationSplitView`; sidebar-style list present; no collapse toggle. |
| 5. Keyboard | CRITICAL | **Mostly compliant** | Strong command coverage, Esc/Return conventions, keyboard placement mode. No arrow-key selection in lists. |
| 6. Pointer | HIGH | **Weak** | No context menus, no drag-and-drop, no hover states, no cursor changes. |
| 7. Notifications/Alerts | MEDIUM | **Compliant** | Inline status, alerts only for destructive decisions, no spam. |
| 8. System Integration | MEDIUM | **Absent (packaging-gated)** | No app bundle, Dock icon, Open Recent, Share, App Intents. README already declares no production packaging. |
| 9. Visual Design | HIGH | **Compliant** | Semantic fonts/colors, dark-mode capable, accent respected. |
| 10. Popovers | MEDIUM | **Minor deviation** | Single-field inputs use sheets where popovers are lighter. |
| 11. Accessibility | CRITICAL | **Mostly compliant** | Extensive labels/hints/traits (WCAG audit work). Missing: Reduce Motion, arrow-key list navigation. |

---

## 3. Rule-by-rule findings (native app)

Compliant items are summarized first; each finding below carries the skill rule
number, a truth status, and file evidence.

### 3.1 Confirmed strengths (do not regress)

- **Rule 1.1/1.2** — Standard menu structure exists. App-specific commands are
  correctly placed in the View menu (Zoom, Reader Mode) via
  `CommandGroup(after: .toolbar)`; Find/page navigation correctly extend Edit
  (`AppCommands.swift:283-330`, `332-380`). Every action menu item has a
  shortcut except where noted below.
- **Rule 1.3 (enablement)** — `PDFEditorCommandRouter.isEnabled` centralizes
  dynamic enablement (dirty state, permissions, search state) and drives both
  menu disabled states and help text (`AppCommands.swift:51-87`).
- **Rule 1.5** — Settings scene exists; `SettingsLink` with Cmd+,
  (`AppCommands.swift:388-393`, `PDFEditorApp.swift:91-93`).
- **Rule 2.1/2.2/2.3** — Window resizable with minimums (1080×700), multiple
  windows via `WindowGroup` with per-window `@State` model
  (`PDFEditorApp.swift:52-69`), fullscreen inherited from SwiftUI.
- **Rule 2.6** — Standard traffic lights, standard title bar. No custom chrome.
- **Rule 3.1/3.3/3.5** — Unified toolbar with labeled icon buttons, segmented
  reader-mode picker, status text item (`ContentView.swift:108-163`).
- **Rule 4.2** — Page list uses `.listStyle(.sidebar)` with vibrancy
  (`ContentView.swift:646`).
- **Rule 5.3/5.4** — Esc/Return conventions respected in sheets; default-action
  buttons wired (`PasswordPromptView`, `WelcomeView`).
- **Rule 5.5-adjacent** — Manual placement mode is keyboard reachable (Return /
  Space place at page center) — `InteractivePDFView.keyDown`
  (`ContentView.swift:1520-1535`). This exceeds typical prototype quality.
- **Rule 7.3/7.5** — Routine feedback uses the inline toolbar status message
  (`model.statusMessage`), not modal alerts. NSAlert is reserved for
  dirty-document decisions (`AppCommands.swift:153-216`). This is textbook.
- **Rule 9.1-9.4** — Semantic text styles throughout; system colors with
  opacity modifiers (dark-mode safe); `.tint`/accent respected;
  `PDFView.backgroundColor = .windowBackgroundColor`.
- **Rule 11.1** — Extensive `accessibilityLabel`/`accessibilityHint`/traits on
  page rows, candidate rows, search results, the PDF view, and permission-gated
  controls (from the 2026-08-24 WCAG audit work).

### 3.2 Violations and gaps

#### G-01 · Rule 2.4 — Window title never identifies the document (P1)

- **Truth:** Observed. `WindowGroup("PDF Editor", id: "pdf-editor")` is a fixed
  title (`PDFEditorApp.swift:85`). No `navigationTitle`, no `representedURL`,
  no proxy icon, no edited-state indicator.
- **Impact:** With multi-window supported (and encouraged by the New Document
  flow), every window reads "PDF Editor". Users cannot tell which document is
  which from the Window menu, Mission Control, or Cmd+` switching. The app
  tracks `isDirty` but never shows it in the window chrome (close-button dot).
- **Related:** Existing review F-MAC-003/T-MAC-003 (lifecycle) — this is the
  chrome-visible half of that task.

#### G-02 · Rule 6.3 + Anti-pattern 15 — No drag-and-drop anywhere (P1)

- **Truth:** Observed. No `onDrop`/`dropDestination`/`draggable` in the app
  sources (grep-verified).
- **Impact:** A PDF cannot be opened by dropping it on the window, the
  WelcomeView, or the Dock. "Mac is a drag-and-drop platform" is the skill's
  explicit anti-pattern #15, and for a document app, drop-to-open is the single
  most expected drag interaction.

#### G-03 · Rules 1.4/6.2 — No context menus anywhere (P2)

- **Truth:** Observed. Zero `.contextMenu` uses.
- **Impact:** Right-click does nothing on page rows, candidate rows, native
  fields, search hits, profiles, or the PDF view (which should offer Zoom/
  Rotate/Actual Size/Copy Page Text). Power users lose the fastest path to
  element-specific actions (Dismiss/Restore candidate, Apply field, Copy snippet).

#### G-04 · Rules 1.1/8.1 — No Open Recent, no Dock menu (P2, packaging-coupled)

- **Truth:** Observed. No recent-documents tracking or menu.
- **Impact:** Standard File menu expectation; also feeds the Dock menu once the
  app is bundled. Note: full behavior (Dock menu, Finder association) requires
  an .app bundle with declared document types — currently out of scope per
  README, but the in-app Open Recent menu does not.

#### G-05 · Rule 1.3 — Menu state feedback incomplete (P3)

- **Truth:** Observed.
  - Reader Mode items (Single/Continuous/Two Pages) and Zoom items show no
    checkmark for the active mode (`AppCommands.swift:333-379`).
  - Undo/Redo titles are static ("Undo"), not action-specific ("Undo Text
    Placement") — HIG Rule 1.3 example is exactly this case.
  - "Actual Size" lacks the standard Cmd+0 shortcut (skill shortcut table).

#### G-06 · Rule 3.4 — Search field is not in the toolbar (P3, decide)

- **Truth:** Observed. Search lives in a custom `ReaderControlBar` below the
  toolbar (`ContentView.swift:523-584`). Cmd+F focuses it correctly via the
  focus-event channel.
- **Assessment:** Functional but nonstandard. macOS convention (Preview, Mail,
  everything) is a trailing toolbar search field via `.searchable`. Moving it
  would also collapse the two-row control bar and reduce the toolbar/zoom
  redundancy noted in G-12. Alternatively, document the deviation deliberately.

#### G-07 · Rule 3.2 — Toolbar not user-customizable (P3)

- **Truth:** Observed. `ToolbarItemGroup` without customization identifier.
- **Assessment:** Acceptable for the current stage; becomes expected for a pro
  document tool at packaging time.

#### G-08 · Rule 4.1 — Split panes instead of a collapsible sidebar (P3, decide)

- **Truth:** Observed. `HSplitView` with page list (200-280pt) and inspector
  (320-460pt) panes (`ContentView.swift:401-447`). No collapse toggle, no
  persistence of pane widths, no Cmd+Ctrl+S-style shortcut.
- **Assessment:** HSplitView gives free resizing (good) but no collapse
  affordance and forces the 1080pt minimum width. A 3-column
  `NavigationSplitView` would buy standard collapse behavior, smaller usable
  minimums, and state persistence. Trade-off: more SwiftUI behavior to tame
  with the PDFKit view. This is a design decision, not a defect — decide and
  record it.

#### G-09 · Rule 5.7 — No arrow-key selection in lists (P2)

- **Truth:** Observed. `PageList`, search results, candidate list, and field
  list are all `Button` rows without `List(selection:)` bindings
  (`ContentView.swift:586-648`, `781-894`, `1208-1249`).
- **Impact:** Up/Down arrows do not move selection; keyboard users must Tab
  through every row. For a page list this is the primary expected navigation.

#### G-10 · Rule 11.3 — Reduce Motion not respected (P2)

- **Truth:** Observed. `setCurrentSelection(selection, animate: true)` always
  animates (`ContentView.swift:1760`); no `accessibilityReduceMotion` reads
  anywhere in the app sources.
- **Impact:** Existing review F-MAC-015/T-MAC-013 already tracks the
  accessibility matrix; this is the one concrete, cheap instance to fix.

#### G-11 · Rule 6.5/6.1 — No cursor or hover affordances (P3)

- **Truth:** Observed. Manual placement mode keeps the arrow cursor (a
  crosshair is the expected affordance); custom rows have no hover state.
  The "Rotate ⟲"/"⟳" and "−"/"+" buttons use text glyphs instead of SF
  Symbols, and the "−"/"+" buttons lack distinct accessibility labels.

#### G-12 · Anti-pattern 6 + Rule 3 — Control redundancy and sheet weight (P3)

- **Truth:** Observed.
  - Zoom is controlled from three places: toolbar scale picker, Zoom menu, and
    the control-bar slider + −/+ buttons. Reader mode is in the toolbar and the
    menu (fine) but the control bar adds more chrome.
  - Single-field inputs use modal sheets: `ManualTextSheet` (one text field),
    `NewProfileButton` (one text field). HIG prefers popovers/inline for
    single-step inputs.
- **Related:** Existing F-MAC-017/T-MAC-017 (toolbar IA).

#### G-13 · Rules 1.1/1.5 — Print and Help surfaces absent (P3)

- **Truth:** Observed. No Cmd+P even though `permissions.canPrint` is surfaced
  in the inspector; Help menu is the empty default; no About customization.

#### G-14 · Verify at runtime — possible duplicate "Bring All to Front" (P3)

- `CommandGroup(after: .windowArrangement)` adds "Bring All to Front"
  (`AppCommands.swift:382-386`). Modern SwiftUI's default Window menu may
  already include it. One-minute runtime check; remove the custom item if
  duplicated.

#### G-15 · Rule 8 (all) — System integration absent, packaging-gated (deferred)

- No .app bundle, Dock icon, ShareLink, Spotlight, Services, App Intents, or
  AppleScript. README explicitly disclaims production packaging, so these are
  future-gate items, not current defects — except ShareLink for an exported
  copy, which is trivially addable inside the export-completion flow.

### 3.3 Items checked and found compliant (no action)

Escape/cancel paths; alert suppression not needed (alerts are rare and
decision-bearing); Dock badge n/a; Quick Look n/a (PDFs open natively);
Notification Center unused (correct); Services n/a at this stage; multi-select
n/a (single-selection model is appropriate for the review-first workflow);
Reduce Transparency (surfaces use standard materials/opacity-on-system-colors —
adequate without explicit handling); Increase Contrast/Bold Text (standard
controls and semantic styles adapt; custom overlay colors are system colors).

---

## 4. Deltas vs. the 2026-08-24 design review ledger

The existing review (`macos-app-design-review-and-todo-2026-08-24.md`) was
written against an older or different slice of the app. Current source shows:

| Ledger item | Ledger status | Current status (this audit) |
|---|---|---|
| F-MAC-002 / T-MAC-002 — shared model across windows | P1 open | **Materially changed:** `AppModel` is now per-window `@State` inside `PDFEditorWindow` (`PDFEditorApp.swift:53`). Runtime two-window independence still unverified. |
| F-MAC-003 / T-MAC-006 — incomplete command surface | P1 open | **Largely implemented:** Find/Find Next/Prev, page navigation, Zoom and Reader Mode menus, centralized router enablement, Settings link all exist. Remaining: G-04 Open Recent, G-05 state polish, G-13 Print. |
| F-MAC-004 / T-MAC-004 — permission gates | P1 open | **Partially implemented in UI:** Copy Page Text, search, OCR, field editing, overlays are all disabled with explanatory help when permissions deny (`ContentView.swift` gating helpers). Domain-layer enforcement matrix still to verify. |
| F-MAC-005 / T-MAC-005 — no durable recovery | P1 open | **Partially implemented:** `RecoveryPairStore`, `SessionPayloadStore`, `RecoveryStatusView`, recovery confirmations on close. Durability/crash evidence still owed. |
| F-MAC-009 / T-MAC-009 — highlights as PDF annotations | P2 open | **Resolved in current code:** highlights now draw in a dedicated `PDFPresentationOverlayView` NSView layer; no PDF annotations are inserted (`ContentView.swift:1415-1463`). Non-persistence into export still worth a fixture-level proof. |
| F-MAC-015 / T-MAC-013 — native accessibility | P1 open | **Partially implemented:** extensive labels/hints/traits (WCAG audit pass). Remaining concrete gap: G-10 Reduce Motion, G-09 arrow-key lists. |

Ledger hygiene task: update the review document (or annotate via addendum) so
future waves don't re-plan completed work.

---

## 5. Task extraction

Explicit tasks below are directly mandated by HIG rules (this skill). Implicit
tasks are implied by the rules, by packaging reality, or by cross-surface
parity obligations. Existing-ledger tasks are referenced, not duplicated.

### 5.1 Explicit tasks (new, from this audit)

| ID | Priority | Task | Rule | Related ledger |
|---|---|---|---|---|
| HIG-01 | P1 | Show document filename in window title; edited-state indicator tied to `isDirty`; proxy icon via `representedURL` when source URL known | 2.4 | T-MAC-003 |
| HIG-02 | P1 | Accept PDF drops: on the window, on the WelcomeView, (later) on the app icon — routed through the existing admission checks in `openImportedPDF` | 6.3, AP-15 | — |
| HIG-03 | P2 | Context menus: page rows (go/copy text), candidate rows (select/dismiss/restore), native fields (apply), search hits, PDF view (zoom/rotate/fit/copy), profiles (switch/save) | 1.4, 6.2 | — |
| HIG-04 | P2 | Open Recent submenu with per-window dirty guard, persisted; Dock menu when bundled | 1.1, 8.1 | T-MAC-003 |
| HIG-05 | P2 | Arrow-key selection in PageList and search results via `List(selection:)`; Cmd+Up/Down first/last | 5.7 | T-MAC-013 |
| HIG-06 | P2 | Reduce Motion: gate `animate: true` and any future transitions on `accessibilityReduceMotion` | 11.3 | T-MAC-013 |
| HIG-07 | P2 | Print command (Cmd+P) gated on `canPrint`, honoring the export-only philosophy (print the projected copy) | 1.1/1.2 | — |
| HIG-08 | P3 | Menu state polish: checkmarks on active reader mode/zoom; "Undo <action>" titles; Cmd+0 for Actual Size | 1.2, 1.3 | — |
| HIG-09 | P3 | Decide search placement: move to toolbar `.searchable` (recommended) or record deliberate deviation | 3.4 | T-MAC-017 |
| HIG-10 | P3 | Decide split architecture: 3-column `NavigationSplitView` (recommended: standard collapse + persistence + smaller minimum width) vs. keep `HSplitView` and record rationale | 4.1 | — |
| HIG-11 | P3 | Cursor crosshair in placement mode; hover states on rows; SF Symbols for rotate; a11y labels for −/+ zoom buttons | 6.1, 6.5, 11.1 | — |
| HIG-12 | P3 | Replace single-field sheets with popovers (manual text, new profile); de-duplicate zoom controls between control bar and toolbar | 10, AP-6 | T-MAC-017 |
| HIG-13 | P3 | Help menu content (even a stub topic) and About panel text | 1.1, 1.5 | — |
| HIG-14 | P3 | Runtime check: remove custom "Bring All to Front" if SwiftUI already provides it | 1.6 | — |
| HIG-15 | P3 | Toolbar customization via `.toolbar(id:)` — schedule with packaging wave | 3.2 | T-MAC-017 |

### 5.2 Implicit tasks (implied, not yet owned anywhere)

| ID | Priority | Task | Why implicit |
|---|---|---|---|
| IMP-01 | P1 | Update the 2026-08-24 design review ledger with the §4 deltas so waves 1-5 don't re-plan finished work | Documentation drift is a correctness risk for the whole TODO system |
| IMP-02 | P1 | Runtime two-window independence check (two PDFs, independent undo/search/selection/export) — the per-window model exists but no evidence exists | Ledger acceptance criteria for T-MAC-002 require proof, not structure |
| IMP-03 | P2 | Public model seam `scheduleViewStateAutosave()` (or equivalent) — the missing API called out in the `ContentView.swift:82-85` comment; blocks view-state persistence (Rule 2.5) and recovery restoration | Recorded only as a code comment today |
| IMP-04 | P2 | App bundling gate: .app bundle, Info.plist document types, custom Dock icon, Finder/Double-click open — unlocks Dock menu, drop-on-icon, Open Recent completeness | README defers production packaging; rules 8.x become applicable only then |
| IMP-05 | P3 | Web parity check after native toolbar/search/menu changes (native changes must not silently fork the contract surface in `docs/native-web-platform-matrix.md`) | Project parity doctrine |
| IMP-06 | P3 | ShareLink on export completion (trivial now, listed separately because export flow owns it) | Rule 8.4, but tied to export UX |
| IMP-07 | P3 | Settings: once real preferences exist (default reader mode, zoom, recovery retention per ledger open questions), move informational rows to About/Help | Rule 1.5 accuracy; F-MAC-017/T-MAC-018 |

### 5.3 Sequencing recommendation

1. **Now (cheap, high-visible):** HIG-01, HIG-02, HIG-06, HIG-08, HIG-14,
   IMP-01, IMP-02.
2. **Next (interaction depth):** HIG-03, HIG-05, HIG-09+HIG-10 (one design
   decision together), HIG-12.
3. **With lifecycle/packaging waves:** HIG-04, HIG-07, HIG-13, HIG-15, IMP-03
   through IMP-07, aligned to the existing review's wave structure.

---

## 6. Open questions for discussion

1. **Search placement + control bar (HIG-09/12):** collapse `ReaderControlBar`
   into the toolbar entirely (`.searchable`, zoom segmented control, page
   field)? My recommendation: yes — it removes a whole chrome row, standardizes
   search, and resolves the zoom triple-redundancy in one move.
2. **Sidebar architecture (HIG-10):** `NavigationSplitView` 3-column vs.
   `HSplitView` status quo. Recommendation: NavigationSplitView, mainly for
   standard collapse + smaller minimum window (1080pt is large for 13"
   screens).
3. **Print (HIG-07):** print the projected (edited) copy or refuse print for
   dirty documents until export? Recommendation: print the projection with a
   subtitle note, consistent with the review-first philosophy.
4. **Title-bar dirty indicator semantics:** with export-only workflows, is the
   edited dot sufficient, or should the title carry "(unexported changes)"?
   Recommendation: dot only; the close/new/open alerts already carry the prose.
5. **Whether HIG-03 context menus duplicate the inspector's** purpose for this
   review-first product — i.e., keep context menus minimal (navigation +
   dismiss/restore + copy) rather than mirroring every inspector action.

## 7. Completeness statement

Audited: full native UI surface (app entry, scene, commands, toolbar, control
bar, sidebar, inspector, PDFKit representable + overlay layer, sheets, alerts,
settings, welcome) against every numbered rule and checklist item in the
`macos-design-guidelines` skill; cross-checked against the existing design
review ledger.

Not established by this pass: runtime behavior (menu duplication check, two-
window independence, drag-drop round-trips, VoiceOver output under the new
labels) — these require a running app and are captured as tasks (HIG-14,
IMP-02). No code was modified.
