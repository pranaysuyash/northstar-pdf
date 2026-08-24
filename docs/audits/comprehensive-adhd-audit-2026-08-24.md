# Comprehensive ADHD Audit: PDF Editor

**Date:** 2026-08-24
**Mode:** ADHD (5-frame parallel divergent ideation → converge → deepened focus)
**Scope:** Current app state, long-term opportunities, features, end state, first principles alignment, doctrine alignment
**Frames used:** Regulator, 10-year-old, Competitor, Game Design, Infinite Budget

---

## 1. Brief

**Problem:** Audit the PDF editor holistically — what it is, what it should become, what it's missing, what it's doing right, and what nobody is thinking about yet.

**Reframe:** This is not "a PDF editor." It is a **local-first document mutation pipeline with an evidence moat** — a trust architecture disguised as a product. The audit should evaluate it on that axis.

---

## 2. Current State Assessment

### What Exists (Observed — Tier 1)

| Surface | Status | Evidence |
|---|---|---|
| Native macOS app | SwiftUI/AppKit shell, PDFKit adapter, working reader/completion/export | `Sources/PDFEditorApp/`, `swift test` (42 tests) |
| Web companion | HTML/JS, PDF.js + pdf-lib, working reader/completion/export | `web/index.html`, `node Tests/web_editor_workflow_test.mjs` |
| Shared contracts | JSON envelope, document/candidate/edit/validation contracts | `Sources/PDFEditorCore/SharedContracts.swift`, `web/pdf-template-contract.mjs` |
| Static region detection | Vector geometry, label association, grouped cells, character grids | `Sources/PDFEditorCore/StaticRegionDetector.swift` |
| OCR adapter | Apple Vision with coordinate transform | `Sources/PDFEditorCore/OCR.swift` |
| Template system | Fingerprinting, capture, activation, encrypted store, learning events | `TemplateContracts.swift`, `TemplateStoreCodec.swift`, `pdf-template-contract.mjs` |
| Impact validation | Outside-region text and raster comparison | `PDFImpactValidator.swift`, `pdf-impact-validator.mjs` |
| Independent validation | Poppler, qpdf, MuPDF gates | `benchmark/*.sh`, `Tests/pdf_independent_preservation_test.mjs` |
| Documentation | 90-gate release registry, 25+ docs, market strategy, capability build program | `docs/` directory |

### What's Working Well

1. **Evidence discipline is exceptional.** Every claim has a truth label, evidence tier, and sensitivity level. This is rare even in mature projects.
2. **The contract architecture is genuinely novel.** Provider-neutral JSON envelopes that native and web can both emit and compare — this is the foundation of a real moat.
3. **The review-first design is correct.** Never silently converting static regions to fields is the right safety boundary. It's boring but load-bearing.
4. **The undo/checkpoint system is clever.** Source replay + periodic checkpoints = O(1) undo without full-document copies. Good engineering.
5. **The doctrine alignment is thorough.** Truth taxonomy, proportional rigor, authorization envelope, semantic salvage — this project walks the talk.

### What's Missing or Weak

1. **No user has touched this.** Zero user observation, zero usability testing, zero pricing test. The market strategy is assumption-based with explicit falsifiers, which is honest, but the product is still a demo.
2. **The template system is over-built for the current stage.** Encrypted stores, learning events, revision histories, profile management — all without a single real user filling a real form repeatedly.
3. **The web UI is a single HTML file.** 2700+ lines of inline JavaScript. This works for a proof but is unmaintainable for a product.
4. **No accessibility runtime evidence.** VoiceOver and screen-reader observation gates are explicitly OPEN (RG-006, RG-007).
5. **The 75 semantic mismatches in native/web parity** are preserved as evidence but not classified or resolved.
6. **No keyboard shortcuts for the core completion workflow.** Tab to next field, Enter to confirm, Escape to dismiss — the bread and butter of form filling.
7. **No batch/multi-document support.** The market thesis is about repeated paperwork completion. One document at a time doesn't match the use case.
8. **No profile/autofill integration.** The template system has the contracts but no real profile data flow (name, address, phone from a local profile).
9. **No export format options.** PDF is the only output. No flattened PDF, no annotated PDF, no sidecar data.
10. **No cloud sync or sharing.** The market strategy says "later," but for a paid product, even local-only sharing (AirDrop, iMessage) needs a clean path.

---

## 3. Divergent Ideas by Frame

### Frame 1: Regulator
*You audit systems for compliance and failure modes. What must be provable, traceable, or refusable here?*

| # | Idea | Score | Notes |
|---|---|---|---|
| R1 | **Build an immutable audit trail export** — every session produces a signed JSON-LD ledger of every operation, review decision, timestamp, and validation result that can be tendered as evidence in regulated workflows | [N8 V7 F9] | High fit for regulated SMB wedge. The contracts already have the data model. |
| R2 | **Add a "regulation compliance mode" toggle** that emits PDF/UA, Section 508, and ADA compliance reports alongside every export — even if the app doesn't guarantee compliance, it proves it checked | [N7 V6 F7] | The gates exist (RG-004, RG-052). The gap is the UI/report. |
| R3 | **Implement "proof of no-change" certificates** — a cryptographic receipt (SHA-256 + timestamp) that proves the source bytes were not modified in regions outside the edit boundary | [N8 V5 F8] | The impact validator already does this informally. Making it a first-class artifact is the step. |
| R4 | **Create a redaction certification workflow** — mark → preview → apply → verify with independent viewer proof → certificate | [N6 V4 F6] | Blocked for claims (RG-014), but the workflow design is a differentiator. |
| R5 | **Add chain-of-custody tracking** — who opened, who edited, when, what changed, who exported. Not audit logging for enterprise; local-only forensic breadcrumbs for the user. | [N7 V6 F8] | Low cost, high trust signal. The operation log is already there. |
| R6 | **Build a tamper-evident export format** — embed source digest, operation hash chain, and validation results as PDF metadata so any viewer can verify provenance | [N7 V5 F7] | Extends the existing validation report into a portable artifact. |

### Frame 2: 10-Year-Old
*Naive but unencumbered. What would a curious kid think this should do?*

| # | Idea | Score | Notes |
|---|---|---|---|
| Y1 | **"Why can't I just take a picture and it fills the form?"** — camera capture → OCR → auto-detect blanks → fill. The obvious user mental model that the current app deliberately avoids. | [N6 V5 F5] | Trap: this is the "silent autofill" the project explicitly rejects. But it IS the user mental model. |
| Y2 | **"Why do I have to click each blank? Can't it just fill them all at once from what I already know?"** — profile-based bulk fill from a saved identity. The template system has the contracts; this is the UX. | [N8 V7 F9] | High fit. The template system exists for exactly this. The gap is the UX and profile data flow. |
| Y3 | **"Can I share the filled form with my friend so they can fill theirs too?"** — share the template, not the document. The fingerprint + mapping record is sharable; the profile values stay local. | [N9 V6 F9] | This is the template sharing use case. Privacy-preserving by design. |
| Y4 | **"What if the form changes and I have to redo everything?"** — automatic re-matching when a new version of the same form arrives. Template fingerprinting already handles this. | [N7 V6 F8] | The `matchTemplate` function exists. The UX for "new version detected" doesn't. |
| Y5 | **"Why can't I see what changed between my original and the filled version?"** — side-by-side diff view. The impact validator computes this; surface it visually. | [N7 V7 F8] | The data exists. The visual diff doesn't. High value for the "proof of no-change" promise. |
| Y6 | **"Can the app learn my common fields and suggest them automatically?"** — the learning event system exists in the template contracts but has no visible behavior. | [N6 V5 F7] | Trap: premature automation. But the reviewed-learning path is safe. |

### Frame 3: Competitor
*Hostile competitor or attacker. What exploits or sabotages the obvious solution? Then invert.*

| # | Idea | Score | Notes |
|---|---|---|---|
| C1 | **Attack: The 75 native/web mismatches are a trust bomb.** If a user edits on native, switches to web, and gets different results, trust evaporates. Invert: make parity the FIRST product feature, not a testing artifact. | [N8 V6 F9] | The mismatches are preserved as evidence. The inversion is: surface them in the UI. |
| C2 | **Attack: Adobe's free Acrobat Reader already does form filling.** Why pay? Invert: Adobe doesn't prove preservation. Position as the "proof-of-change" tool, not the "fill forms" tool. | [N9 V7 F9] | This IS the market strategy thesis. Make it sharper. |
| C3 | **Attack: The static detector will always have false positives.** Every false positive erodes trust faster than a missed field. Invert: let the user train the detector per-document with explicit "this IS a field / this IS NOT" feedback. | [N7 V6 F8] | The review system exists. Adding per-document training feedback is incremental. |
| C4 | **Attack: If the companion is required for real work, it's just a worse Acrobat.** Invert: make the browser core genuinely useful WITHOUT the companion. The bounded-completion loop is the right boundary. | [N7 V7 F7] | Already the architecture. The risk is that the boundary is too narrow for real forms. |
| C5 | **Attack: The template system's encrypted store creates a new failure mode (lost passphrase = lost templates).** Invert: make passphrase recovery trivial — the templates are layouts, not secrets. | [N8 V6 F8] | Lost-passphrase recovery is explicitly open. The insight: templates don't need encryption-level protection, they need integrity protection. |
| C6 | **Attack: The 90-gate release registry will never close.** It's a complexity trap disguised as rigor. Invert: cut the gate list to 15 hard gates and make everything else advisory. | [N7 V5 F7] | Partially true. The current disposition already separates GO/NO-GO. The risk is analysis paralysis. |

### Frame 4: Game Design
*Treat the user as a player. What are the loops, rewards, friction, save-states?*

| # | Idea | Score | Notes |
|---|---|---|---|
| G1 | **"Completion score"** — after filling a form, show: fields filled, fields left, accuracy of suggestions accepted, time taken. Not gamification for its own sake; it's the user's completion progress. | [N7 V7 F7] | The data is all there (candidates, operations, field counts). The display isn't. |
| G2 | **"Smart next"** — instead of "Next blank →", use evidence to predict which blank the user most likely wants next based on reading order, field type, and current progress. | [N8 V7 F9] | The guided-next-blank navigation exists. Making it evidence-ranked is the step. |
| G3 | **"Template speedrun"** — for recurring forms, measure how fast the user completes a new instance vs. the last one. Show improvement over time. The market thesis is about repeated completion. | [N8 V6 F8] | The learning events exist. The visualization of improvement doesn't. |
| G4 | **"Save state / resume"** — auto-save completion progress per document so the user can close and come back. Currently operations are in-memory only. | [N9 V8 F9] | Critical gap. The operation log exists but isn't persisted. This is the #1 missing product feature. |
| G5 | **"Difficulty rating"** — classify documents by how many fields, how complex the layout, how many detected vs. native fields. Help the user estimate effort before starting. | [N6 V6 F6] | Nice-to-have. The data exists (page count, field count, candidate count). |
| G6 | **"Undo tree, not undo stack"** — branching undo. If the user tries two different approaches to a field, they can switch between them. | [N6 V4 F5] | The checkpoint system supports this architecturally but the product doesn't expose it. Low priority. |

### Frame 5: Infinite Budget (10 Years)
*Infinite compute, infinite engineers, a decade. What's the maximalist version?*

| # | Idea | Score | Notes |
|---|---|---|---|
| B1 | **The "document operating system"** — a local runtime that understands PDF structure at the object level, can reason about form semantics, and provides a plugin API for third-party document intelligence. | [N9 V4 F8] | This is the SDK/CLI lane from the market strategy. The provider contracts are the first primitive. |
| B2 | **Universal form understanding** — train a model on millions of public forms to predict field labels, types, groupings, and required status with 99%+ accuracy. Ship the model locally. | [N8 V3 F7] | Trap: this is "AI that edits PDFs," which the strategy explicitly avoids. But the reviewed-learning data from users IS the training signal. |
| B3 | **Cross-document intelligence** — link related forms across documents (same client, same project, same form family) and propagate knowledge. The evidence graph compounds. | [N9 V4 F9] | This IS the "moat hypothesis" from Phase 10. The evidence ledger is the foundation. |
| B4 | **Real-time collaboration on local documents** — CRDT-based collaborative form filling with local-first conflict resolution. No server required for pairs/small teams. | [N8 V4 F6] | Deferred in the current plan but genuinely useful for the team plan tier. |
| B5 | **Document-as-API** — every validated export is also a programmatic interface. Query: "what fields were filled, what evidence supported each, what changed outside the edit boundary." | [N8 V5 F9] | The JSON contracts already support this. The API surface just doesn't exist yet. |
| B6 | **Privacy-preserving federated learning** — every user's reviewed corrections improve a shared model without sharing document content. The evidence graph without the evidence bytes. | [N7 V3 F5] | Wild. Fascinating. But the product needs users before this matters. |

---

## 4. Clusters

### Cluster A: "The Evidence Product" (trust + proof + audit)
**Underlying angle:** Make the evidence discipline the product, not just the engineering practice.

| Idea | Score | Source |
|---|---|---|
| R1 — Immutable audit trail export | N8 V7 F9 | Regulator |
| R3 — Proof of no-change certificates | N8 V5 F8 | Regulator |
| R6 — Tamper-evident export format | N7 V5 F7 | Regulator |
| R5 — Chain-of-custody tracking | N7 V6 F8 | Regulator |
| C2 — Position as proof-of-change tool | N9 V7 F9 | Competitor |
| Y5 — Visual diff view | N7 V7 F8 | 10-year-old |
| B5 — Document-as-API | N8 V5 F9 | Infinite Budget |

### Cluster B: "The Completion Machine" (form filling UX + speed + profiles)
**Underlying angle:** Make form filling fast, repeatable, and personalized.

| Idea | Score | Source |
|---|---|---|
| Y2 — Bulk fill from saved identity | N8 V7 F9 | 10-year-old |
| G2 — Smart next blank | N8 V7 F9 | Game Design |
| G4 — Save state / resume | N9 V8 F9 | Game Design |
| Y3 — Share templates, not documents | N9 V6 F9 | 10-year-old |
| Y4 — Re-match on new form versions | N7 V6 F8 | 10-year-old |
| G3 — Template speedrun metrics | N8 V6 F8 | Game Design |
| G1 — Completion score/progress | N7 V7 F7 | Game Design |
| C3 — Per-document detector training | N7 V6 F8 | Competitor |

### Cluster C: "The Trust Architecture" (parity + safety + recovery)
**Underlying angle:** Make the safety guarantees observable and recoverable.

| Idea | Score | Source |
|---|---|---|
| C1 — Surface parity mismatches in UI | N8 V6 F9 | Competitor |
| C5 — Template passphrase recovery | N8 V6 F8 | Competitor |
| R2 — Regulation compliance reports | N7 V6 F7 | Regulator |
| Y6 — Visible learning from corrections | N6 V5 F7 | 10-year-old |
| G6 — Undo tree | N6 V4 F5 | Game Design |

### Cluster D: "The Platform Play" (SDK + plugins + intelligence)
**Underlying angle:** Build primitives that compound across documents and users.

| Idea | Score | Source |
|---|---|---|
| B1 — Document operating system | N9 V4 F8 | Infinite Budget |
| B3 — Cross-document intelligence | N9 V4 F9 | Infinite Budget |
| B4 — Local-first collaboration | N8 V4 F6 | Infinite Budget |
| B6 — Federated learning | N7 V3 F5 | Infinite Budget |
| B2 — Universal form understanding | N8 V3 F7 | Infinite Budget |

### Cluster E: "The User Reality" (observed behavior + real workflows)
**Underlying angle:** The product has never been used by a real person filling a real form.

| Idea | Score | Source |
|---|---|---|
| Y1 — Camera capture → fill | N6 V5 F5 | 10-year-old |
| C4 — Browser core must be useful alone | N7 V7 F7 | Competitor |
| C6 — Cut the gate list | N7 V5 F7 | Competitor |
| G5 — Document difficulty rating | N6 V6 F6 | Game Design |

---

## 5. Converge — Shortlist

### Top 4 Picks (by weighted score: novelty 0.35 + viability 0.40 + fit 0.25)

1. **★ G4 — Save state / resume** `[N9 V8 F9]` → weighted 8.40
   - **Why:** The #1 gap between "demo" and "product." Users cannot close the app and come back. The operation log exists but isn't persisted. This is table stakes for a real completion tool.
   - **Not obvious:** Everyone assumes save works. Nobody checks.

2. **★ Y2+Bulk fill — Profile-based bulk fill from saved identity** `[N8 V7 F9]` → weighted 8.05
   - **Why:** The template system has the contracts for exactly this. The gap is the profile data flow and the "fill all" UX. This is the core value of the product for repeated paperwork.
   - **★ Non-obvious because:** The template system's complexity has obscured that the simple version (name + address + phone → fill all matching fields) is the actual product.

3. **★ R1+C2 — Make evidence the product** `[N8 V7 F9]` → weighted 8.05
   - **Why:** The evidence discipline is world-class but invisible to users. An audit trail export, proof-of-no-change certificate, and visual diff view would make the "preservation" promise tangible and testable.
   - **★ Non-obvious because:** Competitors have form filling. Nobody has proof-of-preservation.

4. **G2 — Smart next blank** `[N8 V7 F9]` → weighted 8.05
   - **Why:** The guided-next-blank exists but doesn't use evidence ranking. For a 10-page form, the difference between "next blank" and "smart next blank" is the difference between tedious and fast.

### Traps

| Idea | Trap Reason |
|---|---|
| Y1 — Camera capture → fill | This is the "silent autofill" the architecture explicitly rejects. The user mental model is real but the safety boundary is correct. |
| B2 — Universal form understanding | "AI that edits PDFs" is the exact position the market strategy avoids. The reviewed-learning path is the safe version. |
| C6 — Cut the gate list | The gates are what make this project trustworthy. Cutting them for speed is the kind of shortcut that creates the Acrobat problem. |
| G6 — Undo tree | The checkpoint architecture supports this but the product complexity isn't justified by the use case. |
| B6 — Federated learning | Product needs users first. The evidence graph is the foundation but federated learning is 5+ years out. |

---

## 6. Deepened Branches

### Branch 1: Save State / Resume (The Demo → Product Bridge)

**Sketch:** The current operation log (`operations: [EditOperation]`) is in-memory only in both `AppModel.swift` (native) and the web session state. To make this a real product:

1. **Persist the operation log** to a sidecar `.pdfedit` file alongside the PDF, or to IndexedDB in the web lane. The log contains: source digest, every operation with ID/timestamp/value/previousValue, every review decision, and the validation report.
2. **On reopen**, if a `.pdfedit` sidecar exists with a matching source digest, offer to resume the session. Show: "You were filling this form. Resume where you left off?"
3. **Handle drift:** if the source PDF changed since the last session, show the diff (which the impact validator can compute) and ask the user whether to replay operations against the new source or start fresh.
4. **Handle expiry:** if the sidecar is older than N days, warn but don't block. The operations are still valid against the source digest.

**Load-bearing risk:** The sidecar file must not contain sensitive form values in plaintext. Encrypt the values at rest, or keep the sidecar as a session pointer (digest + operation types + candidate statuses) without values.

**First concrete step:** Add a `SessionStore` protocol to `PDFEditorCore` with `save(session:)` and `load(digest:)` methods. Implement for file-system sidecar on native, IndexedDB on web. Wire into `AppModel.open()` and `performExport()`.

**Child ideas:**
- Auto-save on every operation (cheap if the sidecar is append-only)
- Session history: show last 5 sessions per document with timestamps
- Cross-device resume: if the user has the same PDF on laptop + phone, the sidecar could be AirDropped/shared (without values)
- "Continue where you left off" welcome-back screen with progress bar

---

### Branch 2: Profile-Based Bulk Fill (The Core Value)

**Sketch:** The template system captures layout fingerprints, reviewed mappings, and revision histories. But there's no profile data flow — no "my name is X, my address is Y" that auto-fills matching fields.

1. **Build a local profile store** — a simple JSON structure with semantic keys: `firstName`, `lastName`, `email`, `phone`, `address`, `city`, `state`, `zip`, `ssn`, `dob`, plus custom keys. Stored locally, never uploaded.
2. **On template activation**, match profile semantic keys to template mapping semantic keys. Auto-populate values where the match is exact.
3. **Show a "Fill all from profile" button** — one click fills every matched field. The user still reviews before export.
4. **For unmatched fields**, show them as empty with a "profile not found" hint. The user fills manually.
5. **After filling**, offer to save new values back to the profile (with explicit consent).

**Load-bearing risk:** Profile data is sensitive (SSN, DOB, etc.). The encrypted store from `TemplateStoreCodec` can hold it, but the key management must be solid. Lost passphrase = lost profile is the failure mode from C5.

**First concrete step:** Define `UserProfile` contract in `SharedContracts.swift`. Build a `ProfileStore` with encrypt/decrypt and unlock/lock. Wire into the template completion flow.

**Child ideas:**
- Import profile from a previous fill (learn from completed documents)
- Multiple profiles (personal, work, family members)
- Profile versioning (address changed, phone changed)
- "Fill from vCard" import for contact fields
- Profile sharing between devices (encrypted export/import)

---

### Branch 3: Evidence as Product (The Trust Moat)

**Sketch:** The evidence discipline (truth labels, evidence tiers, impact validation, parity harness) is the project's deepest strength but is invisible to users. Making it visible creates a product category.

1. **Export an audit report** alongside every PDF export — a JSON-LD file with: source digest, every operation, every review decision, every validation check, every impact result, timestamps, and the provider used. This is the "proof of what changed and what didn't."
2. **Visual diff view** — show the user a side-by-side: original page on left, filled page on right, with outside-edited-regions highlighted green (unchanged) and edited regions highlighted blue. The impact validator already computes this data.
3. **"Verify this document" feature** — let any user (not just the editor's user) open an export + audit report and independently verify the claims. This is the "chain of custody" for the filled document.
4. **Share the audit report** — attach it to the PDF as a hidden metadata layer, or as a separate file. When the document is sent to a client, the audit report proves what was filled and what was preserved.

**Load-bearing risk:** The audit report must not contain sensitive form values. It should contain operation types, regions, and validation results, not the actual text the user typed.

**First concrete step:** Add `AuditReport` contract to `SharedContracts.swift`. Emit it from the export pipeline. Add a "View audit" button in the export success UI.

**Child ideas:**
- PDF/A-3 embedding of the audit report inside the PDF itself
- Blockchain-free timestamping (RFC 3161 or similar) for the audit report
- "Trust score" — a single number summarizing how many validation checks passed
- Integration with document management systems that need provenance trails
- "Compare two exports" — show exactly what changed between two fills of the same form

---

## 7. First Principles Assessment

### The 10 Invariants (from `full-capability-build-program.md`) — Are They Being Followed?

| # | Invariant | Current adherence | Gap |
|---|---|---|---|
| 1 | Source PDF immutable by default | ✅ Strong | None — this is the core architectural decision |
| 2 | Native field ≠ static suggestion | ✅ Strong | Both types are explicitly separate in contracts |
| 3 | Coordinates name unit/origin/box/rotation | ✅ Strong | `PDFCoordinateSpace` is thorough |
| 4 | Detector output = evidence with confidence | ✅ Strong | Scores, evidence items, and review gating exist |
| 5 | Every mutation typed, source-bound, reviewable, replayable | ✅ Strong | `EditOperation` contract is well-designed |
| 6 | Validation distinguishes passed/warning/failed/skipped/unknown | ✅ Strong | `ValidationCheckStatus` enum covers all |
| 7 | "Outside-region unchanged" is bounded proof | ✅ Partial | Impact validator works but is provider-local |
| 8 | OCR = geometry-bearing evidence | ✅ Strong | Vision adapter preserves uncertainty |
| 9 | Visual signature ≠ crypto signature; whiteout ≠ redaction | ✅ Strong | Explicitly called out in contracts |
| 10 | Native/web agree on intent, not bytes | ⚠️ Partial | 75 mismatches preserved but not classified |

**Verdict:** The invariants are genuinely followed, not just documented. The one gap (#10) is actively tracked. This is the strongest first-principles adherence I've seen in a side project.

### Doctrine Alignment

| Doctrine | Alignment | Evidence |
|---|---|---|
| Operating Doctrine 8.0 | ✅ Full | Truth taxonomy, authorization envelope, proportional rigor all applied |
| Exploration Doctrine | ✅ Full | Cross-project intelligence, competitor analysis, feature frontier all documented |
| Research Doctrine | ✅ Full | Primary sources cited, recency noted, evidence tiers assigned |
| Architecture Doctrine | ✅ Full | Provider-neutral contracts, canonical ownership, migration paths recorded |
| Testing Doctrine | ✅ Partial | S0-S3 sensitivity labels used; more S3 mutation tests needed |
| Security/Privacy/Safety | ✅ Partial | Threat model documented; runtime security audit still OPEN (RG-024) |
| Release Readiness | ⚠️ Partial | 90 gates defined; only 3 at PASS, most PARTIAL or OPEN |
| Documentation Doctrine | ✅ Full | Every decision recorded with date, context, alternatives, risks |

---

## 8. End State Vision

### The 18-Month End State (if execution stays doctrine-aligned)

**Product:** "The only PDF tool that proves it didn't break your document."

- Native macOS app + web companion, both with full completion workflows
- Profile-based bulk fill for recurring paperwork
- Session save/resume across restarts
- Audit trail export with visual diff
- Template sharing (layout only, no values)
- 50+ document corpus with independent viewer validation
- VoiceOver + screen-reader evidence captured
- PDFBox alternative provider lane evaluated
- OCR for scanned documents (local, with confidence display)

**Business:** Free reader/filler + $79/year Pro for unlimited completion, audit reports, and batch operations.

**Moat:** The evidence graph that compounds across providers, documents, and users — nobody else has this.

### The 5-Year End State

**Product:** The document intelligence platform.

- Document-as-API: every export is queryable
- Cross-document intelligence: related forms link and share knowledge
- Federated learning: reviewed corrections improve a shared model without sharing content
- Local-first collaboration: CRDT-based team form filling
- Plugin ecosystem: third-party document intelligence adapters
- Regulated-industry certification: the audit trail IS the compliance artifact

---

## 9. Provocation

**What if the product is not a PDF editor at all, but a "document trust engine" — and PDF is just the first format?**

The shared contracts, evidence model, and validation pipeline are format-agnostic at the abstract level. The same architecture could work for Word documents, Excel spreadsheets, scanned images, or even structured data files. "Complete this document without breaking anything" is a universal problem. PDF is the hardest version of it, which is why starting here is smart — but the end state might be broader than any single format.

---

## 10. Implicit and Explicit Task Lists

### Explicit Tasks (Work — Directly Required)

| ID | Task | Priority | Phase | Gate |
|---|---|---|---|---|
| T-001 | **Persist operation log to sidecar/IndexedDB for session resume** | P0 | B1 | RG-030 |
| T-002 | **Build local profile store with encrypt/decrypt** | P0 | B1/B2 | New |
| T-003 | **Wire profile data into template completion flow** | P0 | B2 | New |
| T-004 | **Add "Fill all from profile" button** | P1 | B2 | New |
| T-005 | **Classify the 75 native/web semantic mismatches** | P1 | B0 | RG-019 |
| T-006 | **Reduce browser geometry false positives** | P1 | B2 | New |
| T-007 | **Add privacy preflight report (metadata, attachments, scripts)** | P1 | B4 | New |
| T-008 | **Add OCR alignment fixtures** | P1 | B2 | RG-008 |
| T-009 | **Run provider bake-off against OCR/security corpus** | P2 | B2/B4 | New |
| T-010 | **Add rotated reviewed-operation replay** | P2 | B3 | RG-011 |
| T-011 | **Add malformed/encrypted/signed/XFA corpus fixtures** | P2 | B4 | RG-012, RG-014, RG-015 |
| T-012 | **Capture VoiceOver workflow evidence (native)** | P2 | B5 | RG-006 |
| T-013 | **Capture screen-reader workflow evidence (browser)** | P2 | B5 | RG-007 |
| T-014 | **Add qpdf variance classification for generated outputs** | P2 | B0 | RG-003 |
| T-015 | **Profile native app on representative hardware** | P2 | B5 | New |
| T-016 | **Define companion capability handshake protocol** | P2 | B4 | New |
| T-017 | **Add keyboard shortcuts for core completion workflow** (Tab/Enter/Escape) | P1 | B1 | New |
| T-018 | **Add visual diff view (original vs. filled)** | P1 | B1 | New |
| T-019 | **Export audit report alongside PDF** | P1 | B1 | New |
| T-020 | **Refactor web UI from single HTML file to module structure** | P2 | B1 | New |
| T-021 | **Cut gate registry to 15 hard gates + advisory rest** | P1 | Release | New |
| T-022 | **Add multi-document/batch completion support** | P2 | B3 | New |
| T-023 | **Add session history (last 5 sessions per document)** | P2 | B1 | New |
| T-024 | **Add "new version detected" re-matching flow** | P2 | B2 | New |
| T-025 | **Add completion progress bar** | P2 | B1 | New |
| T-026 | **Add export format options (flat PDF, annotated PDF, sidecar)** | P2 | B3 | New |
| T-027 | **Add multiple profile support (personal/work/family)** | P2 | B2 | New |
| T-028 | **Add profile import from vCard** | P3 | B2 | New |
| T-029 | **Add template sharing (layout only, encrypted export/import)** | P2 | B2 | New |
| T-030 | **Add per-document detector training feedback** | P2 | B2 | New |

### Implicit Tasks (Exploration — Required Before Decisions)

| ID | Task | Purpose | Phase |
|---|---|---|---|
| E-001 | **Observe 5 real users filling real forms** | Validate the "repeated paperwork" thesis. Does anyone actually fill the same form type repeatedly? | Pre-B1 |
| E-002 | **Test pricing hypothesis with a landing page + waitlist** | Is $79/year the right price? Will anyone pay? | Pre-B1 |
| E-003 | **Benchmark completion time: app vs. Adobe vs. paper** | Is the product actually faster? For what form types? | B1 |
| E-004 | **Evaluate PDFBox as alternative native provider** | The public AcroForm failure needs a second opinion. | B2 |
| E-005 | **Map the exact set of "repeated paperwork" PDF types** | What forms do the target users fill? Government? Medical? Financial? Legal? | Pre-B1 |
| E-006 | **Prototype the visual diff view** | Does showing the diff change user trust? Observable effect. | B1 |
| E-007 | **Test audit report with a compliance officer** | Does the export prove enough for regulated workflows? | B4 |
| E-008 | **Evaluate CRDT options for local collaboration** | Which library? Yjs? Automerge? What's the overhead? | Deferred |
| E-009 | **Prototype camera capture → OCR → fill flow** | Even though the project rejects silent autofill, the user mental model is real. What's the safe version? | B2 |
| E-010 | **Benchmark template matching on 50+ real-world forms** | Does the fingerprint approach work for common form families? | B2 |
| E-011 | **Evaluate Form 6 against PDFBox** | Compare provider fidelity for the primary benchmark fixture. | B2 |
| E-012 | **Research Section 508 / PDF/UA validation tools** | What validators exist? What's the evidence bar? | B5 |
| E-013 | **Test encrypted store UX with non-technical users** | Is passphrase management a dealbreaker? What's the recovery path? | B1 |
| E-014 | **Explore PDF/A-3 embedding for audit reports** | Can the audit report live inside the PDF? What viewers support it? | B4 |
| E-015 | **Map the "document trust" category** | Is anyone else positioning on preservation + proof? Who are the adjacent competitors? | Strategy |

---

## 11. Long-Term Opportunities (Ranked by Strategic Value)

| Rank | Opportunity | Why It Matters | Prerequisite |
|---|---|---|---|
| 1 | **Evidence-as-product** | Nobody else proves preservation. This is a category, not a feature. | Audit report export (T-019) |
| 2 | **Profile-based bulk fill** | This is the core value for the repeated-paperwork wedge. | Profile store (T-002) |
| 3 | **Session persistence** | Without this, the app is a demo, not a product. | Sidecar/IndexedDB (T-001) |
| 4 | **Template sharing** | Network effects without cloud. Users share layouts, not content. | Profile store + sharing UX |
| 5 | **Document-as-API** | Turns the validation pipeline into a programmable interface. | JSON contracts (already exist) |
| 6 | **Cross-document intelligence** | The evidence graph compounds. Each document makes the next one easier. | User base + template adoption |
| 7 | **Regulated-industry certification** | Long sales cycle but high contract value and defensibility. | Audit trail + independent validation |
| 8 | **SDK/CLI for developers** | Extends the platform beyond the app. | Stable contracts + documentation |
| 9 | **Local-first collaboration** | Team form filling without cloud dependency. | CRDT evaluation (E-008) |
| 10 | **Federated learning** | Privacy-preserving intelligence compounding. | User base + model architecture |

---

## 12. Risk Register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **75 native/web mismatches grow instead of shrink** | Medium | High | Classify and resolve top 10 product-relevant mismatches first (T-005) |
| **Users don't actually fill the same form repeatedly** | Medium | Critical | Validate with real users before building profile system (E-001, E-002) |
| **PDFKit AcroForm failure blocks native progress** | High | Medium | Run PDFBox bake-off in parallel (E-004, E-011) |
| **Encrypted store passphrase loss creates support burden** | Medium | High | Build recovery path before launch (C5) |
| **90-gate list prevents shipping** | Medium | Medium | Cut to 15 hard gates (T-021) |
| **Template system complexity discourages adoption** | Medium | Medium | Build simple profile-fill flow first, template system second (T-003 vs. T-004) |
| **Browser UI becomes unmaintainable** | High | Medium | Refactor to modules before adding features (T-020) |
| **No accessibility evidence blocks regulated sales** | High | High | Capture VoiceOver + screen-reader evidence (T-012, T-013) |
| **Competitor ships "AI form fill" that's good enough** | Medium | High | Lean into the "proof of preservation" differentiation (C2) |
| **Real corpus reveals detection quality is too low** | Medium | High | Expand benchmark before claiming production-grade (E-010) |

---

## 13. Summary

This project is **exceptionally well-architected and documented** — better than most funded startups. The first-principles invariants are genuinely followed, the evidence discipline is world-class, and the contract architecture is a real foundation.

The primary risk is **analysis paralysis**: 90 release gates, 25+ documentation artifacts, 10+ benchmark harnesses, and zero users. The product needs to cross the chasm from "evidence-generating engine" to "tool people actually use for daily work."

The three highest-leverage actions are:
1. **Ship session persistence** — makes the app usable for real work
2. **Build profile-based bulk fill** — makes the app worth using repeatedly
3. **Surface the evidence as a product feature** — makes the app worth paying for

Everything else is important but secondary to getting these three into real users' hands.
