# Northstar Buyer Personas — Simulation Set v1

**Date:** 2026-09-07
**Source:** `docs/market-strategy.md` segments + D-005 wedge (bounded local completion)
**Product promise under test:** Complete bounded fields + reviewed entry regions while preserving the rest of the source. No silent autofill. Export to new copy with edit log + recovery.
**Surfaces under test:** `web/index.html` (PDF.js 4.2.67 + pdf-lib, air-gapped) + `Tests/web_editor_workflow_test.mjs` harness. Native SwiftUI shell noted where persona needs it but not driven in this run.

## Persona roster (5)

### P1 — Rosa Alvarez, Solo Real-Estate Transaction Coordinator
- **Segment:** Professional/admin SMB wedge (NAICS 53, 3.1M nonemployers). First learning market.
- **Job:** Completes 8–12 seller disclosure / intake packets per week. Same 2-page Form-6-like packet recurs with new client data.
- **Current workaround:** Acrobat Reader free + print-scan-email. Loses radio/checkbox state on some files; retypes addresses.
- **Frequency / value:** Daily. Will pay if repeat fill < 2 min/file and nothing shifts on print.
- **Constraints:** No IT dept. MacBook Air. Must never upload client PII to cloud without consent. Needs undo + reprint.
- **Accessibility:** Keyboard-only completion (tab through fields), 100–150% zoom.
- **Success criteria:** (1) native fields fill directly, (2) static blank boxes surface as *reviewed suggestions* not auto-applied, (3) export validates + reopens, (4) template/profile reuse across weekly repeats.
- **Simulation task (T-Rosa):** Open static Form 6 fixture → review 1 text-entry suggestion → apply "Reviewed value" → edit to "Updated value" → undo → dismiss/restore → manual text placement → export+validate.

### P2 — Marcus Chen, Clinic Front-Office Lead (Regulated)
- **Segment:** Regulated/public-sector design constraint (NAICS 62, 2.2M). Later expansion, but must not break trust now.
- **Job:** Intake + consent packets, 20/day across 3 staff. HIPAA-sensitive. Needs auditability: who changed what, source preserved.
- **Current workaround:** Paper clipboard + Sejda free tier (hits daily limit). Worried about PHI leaving device.
- **Frequency / value:** Very high, but procurement slow. Team plan only if privacy preflight + provenance are visible.
- **Constraints:** Local-only by default. Must see privacy preflight (metadata, attachments, scripts) before export. No silent OCR upload. Deletion/recovery must be explicit.
- **Accessibility:** Section 508 keyboard nav, field cues, screen-reader labels on completion queue.
- **Success criteria:** (1) preflight + session provenance visible, (2) reviewed-only completion, (3) export gate blocks stale/unsupported ops, (4) vault/backup story understandable.
- **Simulation task (T-Marcus):** Same fill loop as Rosa BUT with added gates: assert preflight panel renders, privacy/provenance envelope present, export blocked on stale digest (negative), undo restores clean state.

### P3 — Priya Nair, Freelance Bookkeeper (12 SMB clients)
- **Segment:** Finance/admin SMB (NAICS 52/56). Highest repeat-volume wedge.
- **Job:** W-9s, invoices, expense packets. Same layouts monthly. Wants profile-driven bulk fill (name/address/EIN) + template reuse.
- **Current workaround:** PDFgear free + spreadsheet copy-paste. No template memory; retypes every month.
- **Frequency / value:** 30+ docs/mo. $79 one-time + $39/yr renewal (D-052) fits if template + profile vault saves 15+ min/week.
- **Constraints:** Values encrypted local vault (12-char passphrase), cross-device recovery. Fears silent family-match applying wrong client values.
- **Accessibility:** Search + copy-page-text for reconciliation.
- **Success criteria:** (1) profile vault unlock separate from store unlock, (2) template capture/match stays proposal-only, (3) ambiguous/stale abstains, (4) bulk fill reviewable per-field.
- **Simulation task (T-Priya):** Fill loop + template card visible, profile panel present, ambiguous-match abstention rule verified via contract unit (no silent apply). Documents that full profile/template E2E needs unlocked vault (explicit friction, not failure).

### P4 — Jordan Lee, Grad Admissions Assistant
- **Segment:** Education (NAICS 61, 860K). Occasional-but-bursty.
- **Job:** 200 applications in 3 weeks, then nothing for months. Needs first-run clarity: open → understand → complete without training.
- **Current workaround:** Preview on Mac (breaks some AcroForms) + email.
- **Frequency / value:** Bursty → subscription fails (market falsifier). One-time $79 fits; must be obvious in < 5 min.
- **Constraints:** Low patience. Needs mode rail (Reader→Understand→Complete→Organize→Review), shortcuts help, search, thumbnails.
- **Accessibility:** Skip-link, ARIA live status, zoom + rotate.
- **Success criteria:** (1) 5-mode rail navigable, (2) search/thumbnails/outline work on load, (3) manual placement discoverable when detector unhelpful, (4) diff overlay shows what changed.
- **Simulation task (T-Jordan):** Navigation/discoverability sweep: mode tabs, search, thumbnails, manual placement, diff toggle, shortcuts panel.

### P5 — Alex Rivera, Indie Hacker Evaluating Local SDK
- **Segment:** Developer/automation (deferred until contracts stable).
- **Job:** Wants deterministic local PDF ops via contract + CLI for batch intake. Reads `docs/shared-contracts.md`, runs parity harnesses.
- **Current workaround:** pdf-lib scripts + qpdf. Hit AcroForm radio-loss with PDFKit.
- **Frequency / value:** Usage-based later. Today: contract stability, parity evidence, mutation guards.
- **Constraints:** `connect-src 'none'` air-gap must hold. Rejects silent provider promotion.
- **Success criteria:** (1) `pdf-contract-parity` + mutation gates pass, (2) companion host stays typed/narrow, (3) fingerprint parity fixture current.
- **Simulation task (T-Alex):** Contract/parity test sweep (no UI): run parity, mutation, preservation gates; verify air-gap + version pin.

## Relation to other persona surfaces (anti-duplication note, 2026-09-07)

- This file is the **market buyer lens** (who pays, job frequency, willingness-to-pay, borrowing from `docs/market-strategy.md`).
- Sim-execution overlays (auditor/validator roles that walk the app) live in `../simulations/personas/NS-PERSONA-PACK.md` and reference the Master Persona Registry — they are a different purpose, not a competing buyer definition.
- Reviewer/designer bench personas (PER-*) are vendored in this directory's `INDEX.md` with source-SHA provenance for audits.
- If a future buyer persona duplicates an NS-P or PER- role, merge here by reference rather than forking.

## Non-goals for this run (historical — web era; Mac is now the launch surface, see RUN-LOG scope warning)

- No e-signature transaction claims, no cloud OCR, no XFA, no PDF/UA authoring — all remain explicit abstentions per capability matrix.
- Native macOS shell GUI is covered by `../simulations/RUN-2026-09-07-N2N1-native-first-run-and-fill.md` (Tier-4 FAIL with GAP-A..E) and `../simulations/NATIVE-GUI-CLICKTHROUGH-RUNBOOK.md`, not by headless runs alone.
