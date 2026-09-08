# Human-Gate Observation Runbook

Repeat per release candidate. Each gate produces a dated record under
`docs/audits/`; observation without a record is not evidence. No Git mutations.

## G1. Packaged `.app` window/menu observation

1. `swift build -c release --product PDFEditor` (isolated scratch path if a
   parallel worker holds the shared cache).
2. Wrap the release executable in a temporary `.app` under `/tmp` (never in
   the repo tree). Launch with no document.
3. Record: frontmost `AXWindow` presence, window title, menu-bar enumeration
   (`Apple, <Product>, File, Edit, View, Window, Help`), File-menu items.
4. Open a public governed fixture; record visible document window + title.
5. Known limit: raw SwiftPM executables and `System Events` without Assistive
   Access do not constitute a usable-app observation. Previous probes
   (2026-08-25) observed zero windows from a temp bundle — that is a scoped
   runtime limitation, not release evidence.

## G2. Termination-flush observation

1. Open a fixture in the packaged app, make one known local edit (do not
   export), quit via the standard menu.
2. Reopen; assert the recovery generation replays exactly that edit and the
   source digest is unchanged. Record generation IDs and envelope digests —
   never payload values.

## G3. VoiceOver + full-keyboard run (macOS baseline, record OS version)

Script: open → navigate pages → select field and suggestion → enter/apply →
Undo/dismiss/restore → export → read validation outcome → dismiss dialogs
with Esc/Return only. Record traversal order anomalies, unnamed controls
(`System Events` button-name gaps are known), focus-restoration failures,
and reduced-motion behavior. Candidate evidence and validation severity must
be announced, not just displayed.

## G4. Two-window independence

Open two different PDFs. Assert independent source digests, operations, undo
stacks, selections, search results, export destinations. Close one; assert
the other is unaltered.

## G5. Large-document timing

Measure open, projection rebuild, undo/redo, autosave, replay, overlay
redraw, export validation on small/medium/large/scanned/annotated PDFs.
Policy-layer replay (`web/browser-resource-policy.mjs` over
`Tests/fixtures/browser_resource_policy_benchmark.json`) is a unit check,
not a device measurement — 30 cases in ~5ms says the policy is free, nothing
about render/OCR on hardware.

## Rerun policy (from `docs/flaky-register.md`)

Browser lanes run against a quiet tree or isolated worktree; two consecutive
greens required. SwiftPM-cache collisions (parallel workers) invalidate the
run, not the code.
