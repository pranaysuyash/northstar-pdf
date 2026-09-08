# Persona Simulation Log — Native Mac lane (launch priority)

> **Scope warning (2026-09-07):** the RUN-MAC-P1..P5 verdicts below cover the **headless contract/provider lane only** (open → inspect → validate via `PDFContractHarness`). A parallel Tier-4 GUI run the same day — `RUN-2026-09-07-N2N1-native-first-run-and-fill.md` — walked the real app GUI (ZCode computer use) and returned **FAIL**: fill-mode scan never completes on a native-widget fixture (GAP-C P0), argv/Apple-Event opens broken or half-wired (GAP-A/B P0), recents-click zombie process (GAP-D P1), AX label gaps (GAP-E P2). Gaps filed to `docs/audits/persona-launch-acceptance-audit-2026-09-07.md` §10.12. **No headless PASS in this log implies the GUI journey works.** GUI remediation path: `NATIVE-GUI-CLICKTHROUGH-RUNBOOK.md`, fix order GAP-C → A/B/D per the N2N1 next-commands.

**Personas:** `docs/personas/buyer-personas.md` (Rosa, Marcus, Priya, Jordan, Alex — grounded in `docs/market-strategy.md` + D-005 wedge)
**Protocol:** `docs/simulations/SIMULATION-PROTOCOL.md` (web-era, superseded for launch) → this log records the **native** runs that replace it for launch decisions.
**Runner:** prebuilt `.build/debug/PDFContractHarness` (PDFKit, macOS 26.6.2) + per-persona mini-manifests in `evidence/`. Full `swift build`/`swift test` exceeded tool timeouts; binaries from `.build/debug` were used and this is stated per-run, not hidden.

| Run | Persona | Fixtures | Result | Evidence |
|-----|---------|----------|--------|----------|
| RUN-MAC-P1 | Rosa (real-estate, repeat packet) | 2 (Form 6 + rotated-mixed) | **PASS** | `RUN-MAC-P1-Rosa.md`, `evidence/mac-P1-*` |
| RUN-MAC-P2 | Marcus (clinic, regulated) | 3 (hybrid + encrypted + nav/attachments) | **PASS** | `RUN-MAC-P2-Marcus.md`, `evidence/mac-P2-*` |
| RUN-MAC-P3 | Priya (bookkeeper, native fields) | 2 (public AcroForm + widgets, pristine `5a68…` post-D-077) | **PASS WITH FRICTION** (radio Mixed → D-076; fixture incident closed) | `RUN-MAC-P3-Priya.md`, `evidence/mac-P3-*` |
| RUN-MAC-P4 | Jordan (admissions, bursty) | 1 (navigation corpus) + static GUI inventory | **PASS (headless) / GUI click-through OPEN** | `RUN-MAC-P4-Jordan.md`, `evidence/mac-P4-*` |
| RUN-MAC-P5 | Alex (developer, SDK) | cross-run contract review (8/8 inspected) | **PASS WITH FRICTION** (full `swift test` deferred) | `RUN-MAC-P5-Alex.md` |

**Superseded (kept, not deleted):** web-core Playwright runs P1–P3 passed (`evidence/sim-P{1,2,3}-*-2026-09-07.json`, harness `tools/simulate_persona_run.mjs`) but web is deprioritized for launch; they are not launch evidence.

**2026-09-07 findings-closure round (doctrine-governed, "do all" scope):**
- Closed: fixture incident via D-077 (pristine restore, gates re-green); encrypted-refusal verified (writer S3 + provider S2; compressed-refusal retirement + sig/XFA-observational gaps recorded); 96 focused Swift tests green across 11 suites; provider licenses refreshed (`docs/audits/provider-license-refresh-2026-09-07.md`, PoDoFo discrepancy resolved); radio scope proposed (D-076).
- Human-gated protocols written (not executed): `NATIVE-GUI-CLICKTHROUGH-RUNBOOK.md`, `docs/research/pricing-validation-protocol-2026-09-07.md`, `docs/research/user-interview-guide-2026-09-07.md`.
- Verdict: `docs/release-evidence-pack-2026-09-07.md` — CONDITIONAL GO on the bounded unit, NO-GO on unrestricted release.
- Remaining: D-076 ratification; RG-135 + GUI + pricing passes; warm-cache full `swift test` (RecoveryCrashInterruption hang in this env); CI wiring for governance test on fixture changes; Bouncy Castle review; harness input-path audit.

**Open items before launch claims (updated 2026-09-07):** D-076 ratification; native GUI click-through with timer; manifest incident closed via D-077 (CI wiring + input-path audit still owed); F-016-class radio/choice evidence current on pristine bytes; warm-cache full `swift test` (this-env hang documented); encrypted-edit refusal verified (contract-layer unit + sig/XFA fail-closed still open).
