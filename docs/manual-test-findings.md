# Manual Test Findings — Northstar Mac app

Every issue found during hands-on testing lands here with an F-ID.
Nothing lives only in chat. The tester files; the fixer updates status
and links the fix. Timing regressions link their P-ID from
`docs/perf-test-plan.md`.

## How to file (copy this)

```
## F-___ — <short title>
- Date:
- Area: (launch / reading / fill / overlays / undo / sign / annotate /
  author / organize / templates / export / governance / companion / study / robustness)
- Severity: crash / data-loss-risk / wrong-output / slow (P-ID: ___) / papercut / question
- Repro: 1. ... 2. ... 3. ...
- Fixture: (pdf name + pages, or "empty state")
- Expected:
- Actual: (+ screenshot path if any)
- Timing (if perf): median of 3, config debug/release:
- Status: open → fixing → fixed-unverified → verified-closed
- Fix ref: (commit / PR / "fixed in session YYYY-MM-DD")
- Verified by: (re-test date + result)
```

Severity guide: **crash** (app dies), **data-loss-risk** (source touched,
export corrupt, recovery lost), **wrong-output** (looks fine but bytes wrong —
always re-open the export in Preview to check), **slow** (needs P-ID +
numbers), **papercut** (annoying but correct), **question** (is this intended?).

## Open findings

## F-003 — Traffic lights missing after maximize (menu bar visible, fullscreen suspected)
- Date: 2026-09-07
- Area: launch / windowing
- Severity: question (pending confirmation)
- Repro: 1. Launch app 2. Maximize (green button → fullscreen?) 3. Traffic lights gone from top-left
- Expected: standard macOS chrome; in fullscreen, hover-at-top reveals traffic lights
- Actual: no close/minimize buttons visible
- Notes: no custom window-style code in repo (grep `hiddenTitleBar|windowStyle|styleMask` = clean) —
  standard WindowGroup windows always have traffic lights except in fullscreen (hover to reveal).
  Needs tester confirm: hover mouse at very top — do they slide down?
  If not, escalate to wrong-output.
- Status: open

## F-004 — Blank canvas when opening a past-session file (sidebars populated, page white)
- Date: 2026-09-07
- Area: reading / rendering
- Severity: wrong-output (data-loss-adjacent: user can't see their doc)
- Repro: 1. Launch 2. Maximize 3. "Continue where you left off" → open `yes_off_unchecked_basic` 4. Canvas blank white; thumbnail + inspector fine
- Expected: page renders
- Actual: blank canvas
- Root cause (agent, code-read): `PipelineCanvasView.updateNSView` never loaded documents into
  the pipeline (`projectionRevision` accepted but ignored) + `makeNSView`'s async load had no
  post-load redraw (first-render-before-load race). Pipeline with no data calls `completion(nil)` → white.
- Fix ref: session 2026-09-07 — `syncPipelineDocument` (instance-identity gate, load-generation
  guard, post-load `reloadPage`), wired into make+updateNSView (`PipelineCanvasView.swift`).
  Deliberately NOT gated on revision (bumps per keystroke → would re-parse whole doc per edit).
- Status: fixing → needs tester verify (open doc A → open doc B → canvas must redraw) + agent
  screenshot-verify first-open below
- Pre-existing warning noted during fix: `pageIndex` MainActor-isolation warn at
  `PipelineCanvasView.swift:249` (`navigateToPage`) predates this change — left untouched.

## F-005 — Menu bar says "PDFEditor", product is "Northstar"
- Date: 2026-09-07
- Area: launch / identity
- Severity: papercut (trust/polish: looks like a dev build)
- Repro: launch →  menu bar shows "PDFEditor"
- Expected: "Northstar" (`ProductIdentity.displayName`, bundle id `com.northstar.pdf`)
- Actual: raw SwiftPM binary has no bundle → macOS falls back to process name
- Fix direction: package `Northstar.app` bundle (Info.plist `CFBundleName=Northstar`) via
  `scripts/package_mac_app.sh` — also unlocks icon + file associations later
- Status: open

## F-006 — Doc view looks unpolished vs empty state (no glass, flat, no motion)
- Date: 2026-09-07
- Area: design system
- Severity: papercut (whole-surface; scoping needed)
- Notes: empty state is already decent; doc view (toolbar/sidebars/canvas chrome) is utilitarian.
  Asks: glassmorphism materials, modular components, animations, image assets.
  Refs exist (`ref-*` images). Scoped as next workstream — needs direction pick (which ref?)
  + surface order (doc chrome first?) before implementation.
- Status: open

## Closed findings

### Session 2026-09-07 — build warnings (filed by agent, verified by build)
- F-001 · actor-isolated `egressGate` warning (`ContentView.swift:223`) —
  fixed via `public nonisolated let egressGate` (`CompanionBridge.swift:195`);
  boundary preserved (gate defaults disabled, all state access still `await`).
  Status: verified-closed (forced rebuild, warning gone, app relaunched).
- F-002 · dead `?? 0` on non-optional `selectedPageIndex` (`ContentView.swift:798`) —
  simplified to direct read. Status: verified-closed (same rebuild).

## Test-session log

| Date | Tester | Build/config | Areas covered | F-IDs filed | Notes |
|---|---|---|---|---|---|
| 2026-09-07 | Pranay | debug | — | — | Testing begins; app running, plan + ledger created |
