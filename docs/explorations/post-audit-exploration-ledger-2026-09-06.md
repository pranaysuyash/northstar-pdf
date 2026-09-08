# Post-Audit Exploration Ledger (2026-09-06)

**Provenance:** opened by `docs/audits/epistemic-integrity-audit-per-0922-2026-09-06.md` §7.3 (X1–X7).
**Status of every entry:** exploration candidate — **discovery does not imply implementation** (Operating Doctrine §9). Each entry states the proposition, current evidence, hypothesis, falsifier, next check, and consequences. Nothing here is authorized for implementation by its existence here.

| ID | Exploration | Disposition | Priority |
|---|---|---|---|
| X1 | Real-document corpus for OCR + parity gates | Research → document → implement slice | HIGH (unblocks T4, fixes EI-A7 unfalsifiability) |
| X2 | Tamper-evident audit trail (hash-chained, file-backed) | Research + design doc | MEDIUM (absorbs N9 aftermath + 08-24 blueprint item) |
| X3 | Companion transport canonical choice | Research → owner decision | MEDIUM (feeds N1 follow-through) |
| X4 | Legacy web plane retirement date | Owner decision + plan doc | MEDIUM |
| X5 | MuPDF as third independent viewer engine | License research (owner gate) + bake-off | LOW-MEDIUM |
| X6 | AppModel decomposition seams map | Read-only architecture study | LOW (6,080 LOC; no current pain) |
| X7 | AI-native spine design doc | Product/design research | MEDIUM (ties to $4.99 AI pricing direction) |

---

## X1 — Real-document corpus for OCR and parity gates

- **Proposition:** the synthetic fixtures (8 ImageMagick-rendered OCR pages; pikepdf-generated form corpus) may not predict behavior on real produced documents.
- **Current evidence (Observed):** Vision baseline WER 0.000 on the synthetic OCR corpus makes the absolute 0.10 threshold near-unfalsifiable (`benchmark/results/ocr-corpus/ocr-wer-baseline.json`); the parity corpus is intentionally vocabulary-diverse but machine-generated (RG-134 row).
- **Hypothesis:** a 20-page sample of the governed corpus (scans, real producer output) with human-verified `.gt.txt` will show (a) Vision WER materially above 0.000 on degraded inputs, and (b) form-field round-trip gaps on real-world AcroForm quirks not present in pikepdf output.
- **Falsifier:** real-corpus WER ≈ synthetic WER and round-trip ≈ 1.000 → gates are already representative; document and close.
- **Next check:** sample 20 governed fixtures, hand-write ground truth, run `benchmark/compare_ocr_wer.py` + `AcroFormParityExperiment` over them; record per-document-class WER.
- **If true:** add the real slice as a second gated corpus ( RG-136 heavy lane). **If false:** record "synthetic gates representative" as evidence in release-gates.

## X2 — Tamper-evident audit trail

- **Proposition:** the corrected `AuditTrail` (rolling window, value-free) is still plain UserDefaults JSON — a rebuild as a hash-chained, file-backed, exportable ledger would make "audit" claims structurally trustworthy and absorb the 2026-08-24 blueprint's never-landed "cryptographic export manifest."
- **Current evidence:** `PrivacyAuditTrail.swift` (post-2026-09-06 fix: honest rolling window); no hash chaining anywhere; EncryptedTemplatePersistence holds a second, unrelated audit-event type (EI-B2).
- **Hypothesis:** a chain design (`event_hash = SHA256(prev_hash || canonical_event)`) with export-before-eviction and one canonical store is deliverable in a bounded slice; the two audit concepts should unify first.
- **Falsifier:** no user/operator flow ever reads the trail → build nothing (capability without consumer). Check support/operator docs first.
- **Next check:** write the design doc (threat model: who tamper-proofs against — local user, other processes, buggy writer?), unify the two audit types, then decide.

## X3 — Companion transport canonical choice

- **Proposition:** three transports (HTTP, AF_UNIX socket, subprocess-launch local) all exist; HTTP is now gate-enforced (N1, 2026-09-06) but the product should declare one canonical remote path and one canonical local path.
- **Current evidence:** `CompanionTransport.swift` factory + tests; RG-126 egress invariant; zero-egress doctrine (HTTP disabled by default, now enforced at the transport).
- **Hypothesis:** local = AF_UNIX (V-04 native socket, no egress surface), remote = HTTP+TLS with EgressGate allow-list; subprocess launch stays a recovery/dev convenience, not a product lane.
- **Falsifier:** a real companion integration requires a transport the pairing cannot cover → widen rather than collapse.
- **Next check:** enumerate actual/planned companion providers (CompanionBridge consumers), pick pairing per lane, record as decision record with the owner.

## X4 — Legacy web plane retirement

- **Proposition:** `web/app.js` (5,734-line legacy surface) + React surface both deploy; a dated retirement closes the dual-target cost.
- **Current evidence:** dual-surface is a documented decision (D-009/G4/A-15); A-11…A-16 gate sunset behind React parity work; both deploy targets remain live.
- **Hypothesis:** retirement is gated on exactly A-11 (mutation gate), A-12/A-13 (capability parity), A-14 (test retargeting) — sequencing, not new discovery.
- **Next check:** owner sets the target date after A-11 lands; no doc to write until then beyond this pointer.

## X5 — MuPDF as third independent engine

- **Proposition:** adding MuPDF to RG-131 makes control-viewer observation triple-engine and removes "two engines agree" ambiguity.
- **Current evidence:** PDFKit + Poppler dual-engine live (RG-131 PASS 38/38); pdf.js provides the browser-side independent channel; MuPDF is AGPL-3.0 (commercial licensing separate) — **license acceptance is an owner gate** (T15).
- **Hypothesis:** mutool draw gives per-page PNG + text at the same CLI shape as pdftoppm/pdftotext, so `ControlViewerObservation` gains a third lane at bounded cost.
- **Falsifier:** AGPL rejected by owner → record no-go with reason (license constraint = legitimate no-go ground) and consider pdfium (Apache-2.0) as the alternative third engine.
- **Next check:** owner license decision first; then a 1-day bake-off spike if accepted.

## X6 — AppModel decomposition seams

- **Proposition:** `AppModel.swift` (6,080 LOC) conflates session lifecycle, document operations, recovery persistence, OCR coordination, and UI presentation state; a seams map should precede any extraction.
- **Current evidence:** Recovery target already exists (SessionPayloadStore, RecoveryPairStore are separate); A-9 open since 2026-08-25; `@Observable` fan-out noted by the perf audit.
- **Hypothesis:** three extractable seams exist with low blast radius: (1) OCR/page-analysis coordination, (2) export pipeline state, (3) companion negotiation lifecycle. Window/session ownership must land first (execution order #2 in the canonical inventory).
- **Falsifier:** measured change-amplification data shows no multi-concern edits → leave it; decomposition without pressure is abstraction theater (REVIEW_DOCTRINE §84).
- **Next check:** one week of `git log -p` analysis on AppModel hot regions before writing any design.

## X7 — AI-native spine design doc

- **Proposition:** three work streams point at the same thesis — an inspectable agent layer over the document: EMPTY-STATE-SKETCHES-4 (AI-native Cursor-loop batch), `AgentCommandHUD` (native), and the untracked `SessionSidePanel.tsx` (React WIP). A single design doc should unify vocabulary, authority boundaries, and the human-inspection surface.
- **Current evidence:** product ambition = AI-native (project memory); pricing direction re-anchored AI at $4.99 (D-052-era direction); HUD and panel exist as independent fragments.
- **Hypothesis:** the right primitive is "agent actions as reviewable ledger entries bound to document operations" — reusing the operation-ledger architecture the editor already has, so every AI action is an `EditOperation` with provenance rather than a side channel.
- **Falsifier:** the ledger-reuse constraint makes the UX unusable (latency/granularity mismatch) → fall back to parallel-side-panel with explicit apply gates.
- **Next check:** consolidate the three fragments into one design doc (owner review), incl. authority boundaries (what the agent may execute vs propose) aligned with the zero-egress doctrine.

---

**Stopping rule for this ledger:** entries graduate to decisions/tasks via their own approval gates; entries with no movement and no falsification after two audit cycles (≈2 weeks) get re-assessed or parked with a reason. Never delete entries — park them (divergent-pool preservation rule).
