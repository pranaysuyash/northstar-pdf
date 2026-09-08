# Native GUI Click-Through Runbook (Human Protocol)

**Status:** PROTOCOL ONLY — no run has been executed under this runbook. A completed
pass produces per-persona updates to `docs/simulations/RUN-MAC-P*.md` plus a
`docs/simulations/RUN-LOG.md` entry; this file authorizes no claim by itself.
**Date:** 2026-09-07
**Canonical personas:** `docs/personas/buyer-personas.md` (Rosa P1, Marcus P2, Priya P3, Jordan P4, Alex P5)
**Supersedes for the GUI lane:** headless-only coverage in `RUN-MAC-P1/P2/P3/P4`
(the `PDFContractHarness` runs stand as contract evidence; they do not prove GUI behavior).
**Companion protocol:** `docs/simulations/NATIVE-SIM-PROTOCOL.md` (ZCode/AX method, verdict scale, stop conditions).

## 0. What this pass answers

RUN-LOG.md open item (1): "native GUI click-through with timer (Jordan/Rosa)."
This runbook extends that to all four GUI personas (Rosa, Marcus, Priya, Jordan)
so each `RUN-MAC-P*` headless PASS gains or fails a human GUI counterpart.
Alex (P5, developer/SDK) is explicitly out of scope: no GUI task exists for the
contract/parity sweep.

## 1. Prerequisites

- [ ] Display Mac (physical or VNC with real WindowServer — headless SSH without a
      display session is not acceptable for this pass).
- [ ] Built app: `.build/debug/PDFEditor` from a recorded HEAD (record `git rev-parse
      --short HEAD`, full `git status --short`, and the binary mtime in the run doc).
      Do not rebuild mid-pass; if a rebuild is unavoidable, restart the affected
      persona script from step 1 and record both provenances.
- [ ] Fixtures present at the paths in §2 (verify with `shasum -a 256`, record digests;
      resolve the known stale-digest warning on `public-sample-form.pdf` per RUN-LOG
      open item (2) before scoring Priya — a digest mismatch is friction, not a silent fix).
- [ ] Timer visible (stopwatch app or phone). Screenshot capability checked once up
      front: `screencapture -x /tmp/gui-probe.png`; if TCC denies, AX-tree notes plus
      typed observation transcripts are the evidence of record (per NATIVE-SIM-PROTOCOL).
- [ ] No prior app state: fresh user defaults / first-run state, or record exactly
      what persisted state was present.

## 2. Fixture list (from `evidence/mac-P*-manifest.md`)

| Persona | Fixtures |
|---|---|
| Rosa (P1) | `docs/benchmarks/pdfkit-form6-run-2026-08-23/noop.pdf` (static Form 6, 0 native fields — forces reviewed-suggestion path); `benchmark/results/rotation-corpus/rotated-form6-mixed.pdf` (rotation robustness) |
| Marcus (P2) | `benchmark/results/browser-corpus/hybrid-text-raster-form.pdf`; `benchmark/results/browser-corpus/encrypted-hybrid.pdf` (must reject cleanly); `benchmark/results/navigation-corpus/navigation-metadata.pdf` (attachments/metadata preflight) |
| Priya (P3) | `benchmark/results/public-sample-form.pdf` (public AcroForm — native-field path; F-016 radio-choice lane untouched, record don't re-prove); `benchmark/results/2026-08-23-pdfkit-widgets/fixture.pdf` |
| Jordan (P4) | `benchmark/results/navigation-corpus/navigation-metadata.pdf` (search/thumbnails/outline); plus the static GUI inventory referenced in `RUN-MAC-P4-Jordan.md` |

## 3. Per-persona task scripts (timed)

Start the timer at step 1 of each script. Every persona follows
open → review → fill → undo → export; persona-specific gates are inline.

### T-GUI-Rosa (target: repeat fill < 2 min/file, buyer-personas P1 success criteria)

1. **Open** the Form 6 fixture. Expect: 2 pages, source digest shown/bound, no native fields.
2. **Review:** one static text-entry suggestion surfaces as a *reviewed suggestion*
   (never auto-applied). Apply "Reviewed value".
3. **Fill:** edit the applied value to "Updated value" via keyboard only (tab navigation).
4. **Undo:** undo the edit; expect the reviewed value restored, then dismiss/restore the suggestion.
5. **Manual placement:** place one manual text entry where the detector is unhelpful.
6. **Export:** export to a NEW copy, reopen it, confirm values present and surrounding
   content undisturbed. Record export-gate verdict (`validated`/blocked + reason).

### T-GUI-Marcus (adds regulated gates — buyer-personas P2 success criteria)

1. **Open** `hybrid-text-raster-form.pdf`. Expect: privacy preflight panel renders
   (metadata, attachments, scripts) plus session provenance envelope before any edit.
2. **Review + fill** as Rosa steps 2–3, confirming every candidate stays proposal-only.
3. **Negative gate:** open `encrypted-hybrid.pdf`, attempt edit/export. Expect: explicit
   `encryptedUnsupported` rejection, no partial output, no crash.
4. **Undo:** restore to clean state; preflight still agrees with source digest.
5. **Export** with the gate: confirm a stale-digest or unsupported-op state would block
   (observe the blocking reason path at least once, even if triggered deliberately).

### T-GUI-Priya (native fields + abstention — buyer-personas P3 success criteria)

1. **Open** `public-sample-form.pdf`. Expect: native fields fill directly (no suggestion
   cards for native widgets); radio/choice widgets render without data loss in the GUI.
2. **Profile/template:** confirm profile vault unlock is separate from store unlock
   (explicit friction, not failure); template card visible; ambiguous/stale match
   abstains (proposal-only, nothing silently applied).
3. **Fill** one native text field + toggle one checkbox/radio; **undo** both.
4. **Export + validate** (reopen). Do NOT attempt to clear F-016 via the GUI —
   the PDFBox split-lane re-proof is RUN-LOG open item (3), separate lane.

### T-GUI-Jordan (first-run clarity < 5 min — buyer-personas P4 success criteria)

1. **First run:** from fresh state, open the navigation fixture with no training.
   Expect: 5-mode rail (Reader→Understand→Complete→Organize→Review) navigable,
   purpose of each mode guessable.
2. **Discoverability sweep:** search, thumbnails, outline, manual placement, diff
   toggle, shortcuts panel — each found without docs. Record time-to-find each.
3. Stop the < 5 min clock when Jordan's core loop (open → understand → complete one
   field → export) is done; continue the sweep untimed afterwards.

## 4. What to record per step

Use one row per step in the persona's run-doc table:

- **Expected** (copied from §3 before the run — fill the table skeleton first).
- **Observed** (what the GUI actually did, verbatim labels/reasons where relevant).
- **Verdict** per step: PASS / FRICTION / FAIL.
- **Time-to-first-fill** (seconds from fixture open to first value committed) — required
  for Rosa and Jordan, recommended for Marcus and Priya.
- **Total script time** per fixture.
- **Screenshots optional:** `evidence/gui-<persona>-beat<N>-<slug>.png` when TCC permits;
  otherwise note "AX/transcript only" — never block a verdict on missing screenshots.
- **Friction list:** anything slow, confusing, or keyboard-inaccessible, even on PASS.

## 5. Pass/fail rubric (same scale as RUN-LOG + NATIVE-SIM-PROTOCOL)

- **PASS:** every step verdict PASS; export `validated`; no data loss; no outbound
  network observed; undo restores prior state.
- **PASS WITH FRICTION:** product behavior correct but with timing over target,
  discoverability stumbles, or environment caveats (stale manifest digest, TCC-blocked
  screenshots, prebuilt-binary provenance) — each friction itemized, none hidden.
- **FAIL + stop that persona:** app crash or data loss; any outbound network call from
  the app during the journey (air-gap violation); export that silently mutates content
  beyond the reviewed edits (preservation-invariant violation). File the gap, stop only
  that persona's script, continue the others.

## 6. Where to file results

1. Update the matching run doc in place: `docs/simulations/RUN-MAC-P1-Rosa.md`,
   `RUN-MAC-P2-Marcus.md`, `RUN-MAC-P3-Priya.md`, `RUN-MAC-P4-Jordan.md` — append a
   `## GUI click-through (<date>)` section with the step table, timings, friction list,
   and verdict. Do not rewrite the headless sections.
2. Update `docs/simulations/RUN-LOG.md`: flip the per-persona GUI status and close or
   restate open item (1) with the run-doc links.
3. Screenshots (if any) go under `docs/simulations/evidence/` with the `gui-` prefix;
   never embed participant PII — fixtures only.
