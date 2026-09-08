# Northstar Sim Persona Pack (NS-P) — project-scoped expansions

**Date:** 2026-09-07 · **Scope:** project-specific simulation personas for the native macOS app (`NATIVE-SIM-PROTOCOL.md`).
**Registry discipline:** canonical personas live in `~/Desktop/Understanding_Personas_sept6` (Master Persona Registry). Per repository rule 5 ("Product-specific personas remain explicitly scoped… generic roles and project-specific variants can coexist"), these NS-P variants are repo-scoped simulation overlays referencing canonical parents. Registry sync is ledgered as PL-D15 (pending, owner ritual).

---

## NS-P1 — Maya, Recurring Form Filler (wedge buyer)

- **Parent concept:** JTBD-04 interact/form completion (repo `jtbd-04-*`); buyer-class embodiment of the D-052 wedge.
- **Who:** operations coordinator at a 6-person insurance brokerage; fills W-9/ACORD-style forms weekly; not technical; jargon-intolerant; buys $79 one-time if it saves ~20 min/week.
- **Mandate:** complete real recurring forms end-to-end without reading documentation, trusting every value she submits.
- **Central questions:** Can I finish my form? Do I understand why each value was suggested? Can I undo? Will the recipient's software accept my export?
- **Sim script:** fill `checkbox-fixtures/*`, `radio-fixtures/*`, `choice-fixtures/dropdown_strings.pdf` with realistic values (name/address/phone per field type); inspect EVIDENCE panel per field; undo one edit; export copy; **open the export in Preview via Apple Event** and confirm field values render in a second reader; repeat on the same template (recurring-calibrator context).
- **Pass:** all field types completable via GUI; evidence visible per accepted value; export valid in Preview; no menu wedges; total time recorded.
- **Failure modes she'd hit (watchlist):** scan hang (PL-I29), symbol-labeled controls (PL-I32), paywall/entitlement surprises (none built yet).

## NS-P2 — Recovery & State Integrity Auditor

- **Parent:** PER-0121 Launch QA & Validation Manager (native state-integrity specialization; complements repo `RecoveryCrashInterruptionTests`).
- **Mandate:** prove that quit, crash, kill, and window actions never lose work and never leave zombie states.
- **Central questions:** What happens at every interruption point? Does recovery restore or at least honestly offer? Can any action close all windows without explanation?
- **Sim script:** matrix of SIGTERM / SIGKILL / Cmd-Q at: fresh launch, doc open, mid-fill, post-export; relaunch each; exercise recovery banner Inspect/Restore/Discard; exercise recents buttons; open/close multiple windows.
- **Pass:** zero data loss; recovery restores or explicitly discards; no windowless zombie processes; recents never destroys windows.
- **Watchlist:** GAP-D (recents click closed all windows), recovery banner "3 local records" semantics, autosave timing under kill.

## NS-P3 — Export Preservation Validator

- **Parent:** PER-0370 Sales Engineer (prove-vs-claim specialization on the source-preservation invariant).
- **Mandate:** verify byte-level truth of "the source stays untouched; edits become a separate export copy."
- **Central questions:** Does the export contain only reviewed edits? Is the unchanged prefix byte-identical? Does the sanitized variant leak metadata? Does flattened export fail closed?
- **Sim script:** record source sha256; make N reviewed edits; export copy; validate with `qpdf --check` (or pikepdf if available) + byte-prefix comparison + field-value diff; export sanitized variant and dump metadata; attempt flattened export of a form doc and confirm fail-closed behavior.
- **Pass:** export opens in Preview; only reviewed edits differ; sanitized variant carries no authored metadata beyond documented set; no silent mutation.

## NS-P4 — Assistive-Tech Operator

- **Parent:** PER-0318 Accessibility Specialist (native AX/VoiceOver lens; complements `wcag-and-accessibility-audit-per-pdev-0169.md`).
- **Mandate:** complete the critical journey using only the accessibility tree — as VoiceOver would.
- **Central questions:** Is every control labeled with human words? Are disabled states explained? Is focus order sane? Can intent modes be distinguished?
- **Sim script:** AX-only walk of first-run → open → fill → export; flag every raw-symbol label, unlabeled button, duplicated label ("0 / 1 fields filled" appearing as both text and value), inconsistent labels between states; verify "Why actions are quiet" disclosure is reachable and readable.
- **Pass:** zero unlabeled controls on the critical path; all state changes announced in the tree.

## NS-P5 — Privacy Forensics Auditor

- **Parent:** project-scoped; complements `PrivacyAuditTrail` / EgressGate code audits and the ihatepdf contrast claim (which must survive the same scrutiny we applied to the competitor).
- **Mandate:** prove the air-gap at runtime, not just in code review.
- **Central questions:** Does any journey emit traffic? Do sockets open even without payload? Is the audit trail value-free at runtime?
- **Sim script:** start `nettop`/`lsof -i` capture for the app pid; run full journey; diff connections against an allowlist (Apple system services only); inspect PrivacyAuditTrail artifacts for document values.
- **Pass:** zero non-system endpoints during any journey; audit trail contains no document content.
- **Note:** requires the journey to be completable first (blocked by PL-I29/PL-I30) — first run scheduled after those land.

---

## Pending expansions (blocked, ledgered)

- **NS-P6 License Activator** — post-purchase activation/entitlement/lapse journey; blocked on commerce (PL-I04). Parent: PER-0129 Access & Gating Strategist.
- **NS-P7 Localization Reader** — deferred per §10.10.
- **NS-P8 Team Admin** — deferred per D-052.
