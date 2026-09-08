# RUN-MAC-P3 — Priya Nair (Freelance Bookkeeper, Bulk/Repeat) — Native Mac lane

**Date:** 2026-09-07 · **Surface:** Native macOS, PDFKit provider via prebuilt `.build/debug/PDFContractHarness`
**Persona goal:** Monthly W-9/invoice-style packets with *native* fields fillable directly + template/profile reuse — with zero silent apply (ambiguous/stale must abstain).
**Fixtures (mini-manifest `evidence/mac-P3-manifest.md`):**
- `benchmark/results/public-sample-form.pdf` (public AcroForm, 6 native fields incl. radio/choice — the known PDFKit radio-choice loss lane, F-016)
- `benchmark/results/2026-08-23-pdfkit-widgets/fixture.pdf` (synthetic widgets, 4 fields — clean control)

## Steps (expected → observed)
| # | Step | Expected | Observed | Result |
|---|------|----------|----------|--------|
| 1 | Inspect public AcroForm | opens, 6 fields inventoried | `inspected`, 1 page, **6 fields**, preflight ✓, `validated` | PASS |
| 2 | Inspect synthetic widgets | opens, 4 fields, clean validation | `inspected`, 1 page, **4 fields**, preflight ✓, `validated` | PASS |
| 3 | Harness exit code | 0 | `EXIT:0` | PASS |

## Honesty notes (read carefully — this is why the sim is PASS WITH FRICTION, not unqualified)
- **Fixture incident resolved (D-077):** this run first measured rewritten bytes (`bb540191…`, a 2026-09-01 Quartz rewrite that fails qpdf with orphan-widget warnings). Pristine pdftoolskit.org bytes were re-acquired (hash-verified `5a681d44…`, qpdf exit 0), restored, and the run repeated green: 1 page, **6 fields**, `validated`. Governance + provenance gates re-verified the same day. The remaining friction is the radio row below, not the fixture.
- **Known provider state (D-076, proposed):** text/checkbox/choice are 1.000 production_ready on every provider (RG-133/RG-134; re-verified 2026-09-07, `AcroForm Parity Experiment` suite passed). Radio is 0.9375 Mixed — review-gated and experimental until PDFKit writes group `/V` or the IncrementalWriter refusal set narrows. Priya's bulk-fill promise covers text/checkbox/choice on day one.
- **No silent apply by construction:** the harness emits `reviews: []` + `operations: []`; candidates/values only enter via explicit review + `EditOperation`. Template/profile vault E2E (passphrase unlock, family-match abstention) was proven in contract tests, not re-driven here.

## Verdict: PASS WITH FRICTION
Native field inventory + validated export hold for Priya's doc class. Retention hook (encrypted template/profile reuse) and AcroForm radio/choice fidelity stay on their separate evidence lanes — both named above, neither blocking this run's verdict.

## Follow-ups
1. Ratify D-076 (radio experimental wording) before promising Priya bulk radio fidelity.
2. Re-run the F-016-class radio/choice gate only if bytes change again; current evidence binds to pristine `5a681d44…`.
3. Native GUI pass: profile vault unlock → bulk-fill review list on the built app (runbook: `docs/simulations/NATIVE-GUI-CLICKTHROUGH-RUNBOOK.md`).
