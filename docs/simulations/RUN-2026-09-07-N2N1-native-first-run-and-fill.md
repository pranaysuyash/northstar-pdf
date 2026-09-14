# RUN-2026-09-07 — Native Sim N2+N1: First-Run, Document-Open Paths, Fill-Mode Scan

**Date:** 2026-09-07, ~10:55–11:25
**Personas:** N2 PER-0303 Onboarding/Activation Designer + N1 PER-0121 Launch QA & Validation Manager (bench per `NATIVE-SIM-PROTOCOL.md`)
**Binary:** `.build/debug/PDFEditor`, built 2026-09-07 08:36, re-built 11:05 (HEAD `aa599f5` + dirty tree; parallel-agent edits in flight — binary provenance is approximate)
**Fixtures:** `benchmark/datasets/checkbox-fixtures/yes_off_unchecked_basic.pdf` sha256 `294a2716…506886a` (native checkbox widget, 1 field)
**Method:** ZCode computer use, AX-first; 3 app launches; environment under parallel-agent load (stuck `swiftpm-testing-helper` 39+ min CPU, Marker OCR + ffmpeg active; 96 GB RAM, no dominant hog)

## Verdict: **FAIL** (journey-blocking defects found; several strong surfaces confirmed)

The wedge journey (open → Fill → review → edit → export) is **not completable in the GUI today**: the fill-mode scan never completes, and every programmatic document-open path is broken in a distinct way. Onboarding surfaces themselves are strong.

## Step table

| # | Step (expected) | Observed | Verdict |
|---|---|---|---|
| 1 | Launch → welcome window | Window "Northstar" appears; value prop "PDF workflow: read, shape, and export a separate copy"; tagline; preservation promise "The source stays untouched. Edits become a separate export copy"; CTAs Open a PDF… / New blank · Letter / Create from Images/Clipboard/Markdown; no tours | **PASS** (N2: promise→product alignment good) |
| 2 | First-run recents | Later launches show "Continue where you left off" (`pdfEditor.home.recentDocuments`) with the fixture registered — recents survive restarts and register programmatic opens | **PASS** (N2) |
| 3 | Launch with document argument (`PDFEditor <file>`) | Process alive, **no window ever appears** (idle at 0% CPU, 10 s) | **FAIL** → GAP-A |
| 4 | Apple Event open (`tell app … to open POSIX file`) | Document loads into the existing window (Document context shows fixture, page rail "1 fields", footer "0 / 1 fields filled") **and** a second empty welcome window spawns; **menu bar stays disabled** (File items disabled despite open document) in both runs | **FAIL** → GAP-B |
| 5 | Switch intent to Fill mode | Radio toggles; footer "Scanning page 1 for fillable areas…" | PASS (start) |
| 6 | Scan completes (≤ s for a 15 KB fixture) | **Never completes.** Run 2: still "Scanning…" at 15 s. Run 1 (earlier instance): transitioned to **"Memory pressure: cleared non-essential caches"** and stayed there; in both runs the **menu bar went fully disabled** during scan and never recovered (main thread idle in event loop, 0% CPU — wedged state flag, not a hang) | **FAIL** → GAP-C |
| 7 | Recovery-session banner (after SIGTERM restarts) | "Recovery session available — 3 local record(s)" with Inspect/Discard; expand copy: "A local session can be inspected before you continue working…" | **PASS** (honest; Discard correctly *not* exercised — may contain user data) |
| 8 | Reader tab → Capability Passport | Per-session LOCAL capability evidence: read/extract ✓, complete native fields ✓ ("export remains a separate copy"), annotate ✓, organize ✓, "Export a separate copy — operation ledger passes the export permission gate" ✓, Privacy preflight ✓, no warnings; metadata/permissions rendered | **PASS** — strongest trust surface in the app (N4 demo material) |
| 9 | Welcome recents button ("Open yes_off_unchecked_basic.pdf") | Click dispatch uncertain (`possibly_sent`, AX `cannot_complete`); **all app windows closed**, process alive with zero windows, no crash report | **FAIL** → GAP-D (needs repro) |
| 10 | In-app panel open (File-Open path isolation) | Panel opens (AX visible); helper action-binding degraded mid-session (environment); navigation incomplete — **isolation inconclusive this run** | **BLOCKED (environment)** |
| 11 | Air-gap check | No network config touched; EgressGate enforced in transport (code-level, prior audit). Runtime network capture not yet possible (journey blocked at step 6) | PENDING |

## Gaps (filed to `docs/audits/persona-launch-acceptance-audit-2026-09-07.md` §10.12)

- **GAP-A (P0):** argv/document-argument launch is windowless → buyer "Open With" path dead on arrival.
- **GAP-B (P0):** Apple-Event open works but spawns a duplicate welcome window and never enables the menu bar; both programmatic opens skip whatever wiring makes the UI fully live.
- **GAP-C (P0):** Fill-mode scan never completes on a native-widget fixture; under memory pressure it aborts with an honest status but leaves the menu bar wedged disabled with no Retry affordance.
- **GAP-D (P1):** Recents-button click closed all windows leaving a zombie process (single observation; reproduce before fix).
- **GAP-E (P2):** AX label of the Fill-mode radio is the raw SF Symbol name `pencil.and.list.clipboard` (not "Fill"); File > Open… disabled on the welcome surface (button-only open) is unusual; intent-picker label missing in recovery-expanded state (s-8) but present in fresh state (s-14) — AX tree inconsistency.

## Environment caveats (not app defects, but they shaped the run)

- Windows spawn on a secondary display at negative-Y coordinates; CUA pixel binding fails there until a window lands on the main display. Screenshots via `screencapture -x` work regardless (evidence copies in `/tmp/ns-*.png` during run; re-capture beats on re-runs).
- The CUA helper's app-identity/action binding degrades after ~10–15 min for this bundle-less SPM binary; fresh `get_app_state` tokens recover it temporarily. A proper .app bundle (RG-122 work) will likely fix both this and the argv path.
- Parallel-agent load caused AX traversal timeouts (8 s wall-clock) and one transient memory-pressure event.

## Next commands

1. Fix GAP-C first (scan lane): reproduce headlessly if possible; inspect the scan task launch path for a dropped continuation; add cancel/retry.
2. Reproduce GAP-A/B/D with a minimal script (`osascript` open + AX menu dump) after GAP-C, since they share the programmatic-open wiring.
3. Re-run this protocol end-to-end, then continue to export-byte validation (step 12+) and the N3 discoverability sweep.

---

## Remediation & partial re-verification (2026-09-08)

Fixes landed same-day (D-080, D-081): native-fields-first auto-OCR guard + honest failure status + 45 s watchdog + pressure-handler status preservation (`AppModel.swift`); `PDFEditorExternalOpenRouter` owning argv + Launch Services opens with scratch-window cleanup (`PDFEditorApp.swift`); per-segment AX labels on the intent picker (`ContentView.swift`). Build: **green** in an isolated scratch path (shared `.build` held by the parallel agent); `swiftc -parse` clean.

Re-run against the fixed binary (Apple-Event open of the same fixture):

| Step | Prior run | This run | Verdict |
|---|---|---|---|
| Fill mode activation | Stuck "Scanning…" 15 s+, then pressure-abort | Status "Fill mode — 0 / 1 fields filled"; no scan triggered (page has a native field) | **PASS** (PL-I29) |
| Menu bar during mode switch | Fully disabled, never recovered | Save…/Export Copy…/Append/Open all enabled throughout | **PASS** (menu wedge gone) |
| AX labels for intent radios | `pencil.and.list.clipboard` | "Read / Fill / Sign / Edit" | **PASS** (PL-I32) |
| Apple-Event open | Duplicate welcome window + disabled menus | Document loads; menus enable; field editor functional (Checked toggle + Apply Field Value) | **PARTIAL** — duplicate window still spawns *after* the router's cleanup (ordering) → **PL-I30b** |
| Field apply → export | Unreachable | Field editor opens and arms, but the ad-hoc binary's keychain re-prompt loop (PL-I36, new) blocks unattended completion; export validation still owed | **BLOCKED (environment)** |

Evidence: screenshots `/tmp/ns-check*.png` (session-temporary; re-capture on next run for the archive). argv path not yet re-exercised (router code identical for both entry points; queue tested via the Apple-Event path). Next: PL-I30b deferred-cleanup pass, then the full PL-V04 battery (apply → export → byte validation) and the argv leg.

**PL-I30b closure (2026-09-08/09):** deferred sweep passes (0.5 s/1.5 s) added to the router and rebuilt; Apple-Event open now ends with **exactly one window** holding the document (AX-verified: fixture loaded, 1 field, consent row present). Remaining from this run: the apply→export→byte-validation leg (blocked only by the ad-hoc keychain prompt loop, PL-I36) and the argv leg — both fold into the next full PL-V04 battery.
