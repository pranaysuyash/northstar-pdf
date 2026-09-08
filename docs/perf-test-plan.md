# Perf Test Plan — Northstar Mac app

How we make it buttery smooth: every testable feature gets a timing,
every timing gets a baseline, every regression gets a finding ID.
Targets are provisional until baselines land; debug builds are slower
than release, so always record which config ran.

## Measurement methods

| Method | What it captures | Command / protocol |
|---|---|---|
| M1 launch script | Spawn → visible window ("time to open") | `./scripts/measure_app_launch.sh 3` (cold-ish), `... 3 --warm` |
| M2 headless harness | Doc open/inspect, page render, export per fixture (JSON) | `swift run PDFPerformanceBenchmark --fixture <pdf> --inspect --render-page <n> --export --export-output-directory <dir>` (run `--help` for flags) |
| M3 stopwatch | Interaction timings a human feels (manual test) | Phone stopwatch or `date +%s%3N` before/after; 3 reps, record median |
| M4 Activity Monitor | Memory / CPU / energy spot-checks | Record footprint at rest + during large-doc scroll |

Rules: 3 reps minimum, record median. Note machine, config (debug/release),
fixture name, page count. A "regression" = >20% over baseline median.

## Timing matrix

Format: ID · feature action · method · provisional target · baseline (filled as measured).

### Launch & open
- P-01 · Cold-ish launch to visible window · M1 · ≤ 1500ms debug / ≤ 800ms release · baseline: ___
- P-02 · Warm relaunch to visible window · M1 --warm · ≤ 800ms debug · baseline: ___
- P-03 · Open small PDF (≤10pp) to first page visible · M3 · ≤ 1000ms · baseline: ___
- P-04 · Open large PDF (100+pp) to first page visible · M3 · ≤ 3000ms · baseline: ___
- P-05 · Open encrypted PDF (password → visible) · M3 · ≤ 1500ms + typing · baseline: ___
- P-06 · Reopen recent document ("continue where you left off") · M3 · ≤ 1000ms · baseline: ___
- P-07 · Headless inspect: small / large fixture · M2 · record only · baseline: ___

### Reading & navigation
- P-10 · First-page render after open (headless) · M2 --render-page · ≤ 300ms · baseline: ___
- P-11 · Page turn (click/arrow → new page sharp) · M3 · ≤ 200ms (feels instant) · baseline: ___
- P-12 · Continuous scroll through 100pp (no stutter) · M3 subjective + M4 · no visible jank · baseline: ___
- P-13 · Zoom in/out to sharp · M3 · ≤ 300ms · baseline: ___
- P-14 · Fit Page / Fit Width switch · M3 · ≤ 300ms · baseline: ___
- P-15 · Thumbnail rail fully populated (100pp) · M3 · ≤ 3000ms, progressive OK · baseline: ___
- P-16 · Search across doc, first results shown · M3 · ≤ 1000ms (small) / ≤ 5000ms (large) · baseline: ___
- P-17 · Search next/prev jump · M3 · ≤ 200ms · baseline: ___
- P-18 · Outline/bookmark jump · M3 · ≤ 300ms · baseline: ___

### Form fill & completion
- P-20 · Native field list populated after open · M3 · ≤ 1000ms · baseline: ___
- P-21 · Keystroke → glyph in field (typing latency) · M3 subjective · no perceptible lag · baseline: ___
- P-22 · Checkbox/radio toggle feedback · M3 · ≤ 100ms · baseline: ___
- P-23 · Static-region detection pass (analysis → suggestions) · M3 · ≤ 5000ms · baseline: ___
- P-24 · Overlay placement commit · M3 · ≤ 300ms · baseline: ___
- P-25 · Undo / redo round-trip · M3 · ≤ 200ms · baseline: ___

### Signatures, annotations, authoring
- P-30 · Signature draw stroke latency · M3 subjective · ink follows pen, no trail lag · baseline: ___
- P-31 · Signature place onto page · M3 · ≤ 300ms · baseline: ___
- P-32 · Annotation commit (highlight/note/shape) · M3 · ≤ 300ms · baseline: ___
- P-33 · New from Images/Markdown to visible doc · M3 · ≤ 2000ms · baseline: ___
- P-34 · Append pages into open doc · M3 · ≤ 2000ms · baseline: ___

### Organize
- P-40 · Page reorder drag → settled · M3 · ≤ 300ms · baseline: ___
- P-41 · Extract/split to new doc visible · M3 · ≤ 2000ms · baseline: ___
- P-42 · Batch merge (N files → result) · M3 · record, scales with size · baseline: ___
- P-43 · Page rotate feedback · M3 · ≤ 300ms · baseline: ___

### Templates
- P-50 · Capture layout → mapping list · M3 · ≤ 1000ms · baseline: ___
- P-51 · Vault unlock · M3 · ≤ 1000ms · baseline: ___
- P-52 · Encrypted backup export / restore · M3 · ≤ 3000ms · baseline: ___
- P-53 · Apply reviewed completion · M3 · ≤ 2000ms · baseline: ___

### Review & export
- P-60 · Export Copy (small doc) to file on disk · M3 + M2 --export · ≤ 2000ms · baseline: ___
- P-61 · Export Copy (large doc) · M3 · ≤ 10s · baseline: ___
- P-62 · Sanitized export · M3 · ≤ P-60 + 50% · baseline: ___
- P-63 · Flattened export · M3 · ≤ P-60 + 50% · baseline: ___
- P-64 · OCR layer synthesis (per 10 pages, scanned fixture) · M3 · record only · baseline: ___
- P-65 · Export validation pass → verdict shown · M3 · ≤ 2000ms · baseline: ___
- P-66 · Diff compare view render · M3 · ≤ 2000ms · baseline: ___
- P-67 · Export PNG of page · M3 · ≤ 1000ms · baseline: ___

### Resources (M4, large doc)
- P-70 · Idle footprint after open (MB) · M4 · record only · baseline: ___
- P-71 · Peak during continuous scroll (MB / %CPU) · M4 · no runaway growth · baseline: ___
- P-72 · Footprint after close (leak check: returns near pre-open) · M4 · ≤ +50MB vs before · baseline: ___

## Baseline log

| Date | Config | Machine | P-ID | Median | Notes |
|---|---|---|---|---|---|
| 2026-09-07 | debug (arm64) | Pranay's Mac | P-01 | 668ms | 5 cold-ish runs: 668/724/700/647/658ms. One earlier 111ms outlier discarded as stale-window race before Swift poller. Script: `scripts/measure_app_launch.sh` + `scripts/window_poll.swift` (CGWindowList poll). |
| 2026-09-07 | debug (arm64) | Pranay's Mac | P-07 | open_load 81–92ms | Headless harness, 2 fixtures (1pp + 200pp generated). Raw: `benchmark/results/perf-baseline/2026-09-07/headless-inspect-render.json`. |
| 2026-09-07 | debug (arm64) | Pranay's Mac | P-10 | page_render ~0.65ms | Same run. Suspiciously fast — verify what the render stage actually measures before trusting. |
| 2026-09-07 | debug (arm64) | Pranay's Mac | P-70 | ~23MB resident (1pp) / ~27MB (200pp) | Same run, `--memory`. Physical footprint 6.6MB → 11MB. |

## Targets policy

Provisional targets above are feel-based (instant < 200ms, fast < 1s,
tolerable < 3s). After baselines land, targets become `≤ baseline median`
(no-regression rule) plus the aspirational release-build column. Any
measurement >20% over baseline median → file a finding (F-ID) in
`docs/manual-test-findings.md` and link it here.
