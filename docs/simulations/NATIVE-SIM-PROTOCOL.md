# Native macOS Persona Simulation Protocol v1

**Date:** 2026-09-07
**Surface:** Northstar macOS app (`swift build --product PDFEditor` → `.build/debug/PDFEditor`) — the launch surface per the 2026-09-07 owner re-scope (`docs/audits/persona-launch-acceptance-audit-2026-09-07.md` §10.11).
**Method:** ZCode computer use, accessibility-first (AX tree observations), screenshot fallback; complements `SIMULATION-PROTOCOL.md` (web plane, headless Playwright) — this protocol owns the native plane only.
**Provenance note:** written by the persona-launch-audit session; does not modify the parallel web-plane protocol or its evidence files.

## Persona bench (canonical personas, Understanding_Personas_sept6)

| Sim ID | Persona | Lens on the native app | Journeys |
|---|---|---|---|
| N1 | PER-0121 Launch QA & Validation Manager | readiness-by-evidence across full launch experience, not just app code | critical journeys E2E: open → read → fill → annotate → export → validate |
| N2 | PER-0303 Onboarding/Activation Designer | first encounter → first meaningful completed outcome; activation = demonstrated value, not screens completed | first run, WelcomeView, recents, empty states, open-document path |
| N3 | PER-0302 Feature Discoverability Designer | capability learned in task context without tours/docs; entry-point map | 5-tab inspector, intent modes (Read/Fill/Sign/Edit), search HUD, thumbnails, reading modes |
| N4 | PER-0370 Sales Engineer | real-workflow demo, prove-vs-claim; no demo theater | wedge demo on buyer-like fixture: candidate detection → review → edit → export → validate |
| NS-P1 | Maya, Recurring Form Filler (project-scoped, `personas/NS-PERSONA-PACK.md`) | wedge buyer completing recurring forms with realistic values; trusts every submitted value | fill all field types → evidence check → export → cross-reader validation in Preview |
| NS-P2 | Recovery & State Integrity Auditor (project-scoped) | quit/crash/kill matrix; no data loss, no zombie states | SIGTERM/SIGKILL matrix, recovery restore/discard, recents, multi-window |
| NS-P3 | Export Preservation Validator (project-scoped) | byte-level proof of the preservation promise | export digests, byte-prefix compare, sanitized-variant metadata dump, fail-closed flattened |
| NS-P4 | Assistive-Tech Operator (project-scoped, parent PER-0318) | whole journey via AX only; human labels everywhere | AX-only walk; unlabeled-control census |
| NS-P5 | Privacy Forensics Auditor (project-scoped) | runtime air-gap proof, not code-review proof | nettop/lsof capture during journey vs allowlist; audit-trail value-freeness |

Persona docs: `~/Desktop/Understanding_Personas_sept6/01 Expanded Personas/{03 Product, UX & Help,06 Launch, Growth & Market}/`; project-scoped NS-P overlays: `personas/NS-PERSONA-PACK.md` (registry sync pending, PL-D15).

## Fixtures (sha256 recorded per run)

- Native-widget lane: `benchmark/datasets/checkbox-fixtures/yes_off_unchecked_basic.pdf`, `radio-fixtures/yes_no.pdf`, `choice-fixtures/dropdown_strings.pdf`
- Static-candidate lane: `benchmark/results/diverse-layout-corpus/diverse-form-layout.pdf`
- Reading lane: `benchmark/results/diverse-layout-corpus/diverse-mixed-3page.pdf`

## Universal evidence per run

- `RUN-2026-09-07-N<id>-<slug>.md`: date, persona, goal, binary provenance (mtime, HEAD `aa599f5` + dirty-tree caveat), fixture digests, step table (expected / observed / verdict per step), AX-tree highlights, console/log notes, timings, friction list, verdict.
- Screenshots to `evidence/native-<run>-beat<N>-<slug>.png` when `screencapture` TCC permits; otherwise AX-tree transcript is the evidence of record (recorded in the run doc).
- Verdict scale (same as web protocol): **PASS** / **PASS WITH FRICTION** / **FAIL**.

## Stop conditions

- App crash or data loss during a journey → FAIL, file the gap, stop that persona only.
- Any outbound network call from the app during a journey → FAIL (air-gap/egress-gate violation; privacy claim is a launch pillar).
- Export that silently mutates content beyond the reviewed edits → FAIL (source-preservation invariant).
