# PDF Reader/Editor Feature and Expansion Inventory

**Owner:** `/Users/pranay/Projects/pdf_editor`
**Date:** 2026-08-24
**Status:** Consolidated documentation pass initiated for the user request.
**Source set:** `docs/pdf-feature-frontier.md`, `docs/native-web-platform-matrix.md`, `docs/proposed-architecture.md`, `docs/implementation-status.md`, `docs/market-strategy.md`, `docs/decisions.md`, `docs/open-source-landscape.md`, `docs/pdf-engine-comparison.md`, `docs/platform-options.md`, `task_plan.md`.

## Scope and status grammar

This register is separate from implementation evidence. It is a feature-exploration and expansion ledger used for planning and discussion before final scope lock.

- **Implemented**: present in the current native prototype / documented execution lane.
- **Partially implemented**: available in a narrow context, with caveats.
- **Planned**: accepted for the long-term capability program; implementation is
  not complete.
- **Gated**: requires explicit provider, corpus, safety, or legal/security evidence.
- **Deferred**: intentionally out of scope for now.
- **Not in active slice**: deliberately sequenced after the current safety and
  provider gates; not rejected from the long-term product.

## Core invariants (cross-cutting behavior)

- **Immutable source bytes** per session.
- **Operation-log and provenance** (`operationId`, source, target, previous value, destructive flag).
- **Deterministic coordinate model** (page-space with page index + crop box + rotation provenance).
- **Explicit confidence boundaries** for candidates (never auto-apply). 
- **Export validation** before success claim (reopen, page count/geometry check, and evidence-backed diffs).
- **Local-first baseline** for core workflow.
- **Provider-neutral contracts** shared by native and web adapters.

## Feature inventory by family

### 1) Reading and navigation

| Feature | Native status | Web-local status | Notes |
|---|---|---|---|
| Open/import PDF | Implemented | Implemented | Password-aware open path in native; file picker + encrypted fallback in web companion. |
| Continuous view modes, zoom, rotate, pan, page jump | Implemented | Implemented | Single, continuous, two-page with fit-width/fit-page/zoom and page jump controls on both lanes. |
| Thumbnails and page labels | Implemented (prototype) | Implemented (prototype) | Native labels now use document labels; web renders a thumbnail strip and label list. |
| Text selection and copy | Implemented/partial | Implemented/partial | Native uses PDFKit selection; web supports page-text extraction and copy button fallback. |
| Search + match highlighting | Implemented/partial | Implemented/partial | Both lanes include match discovery + page navigation; native visual highlighting remains best-effort. |
| Links, named destinations, outlines/bookmarks | Implemented/partial | Implemented/partial | Safe-link handling and outline traversal are now implemented with conditional fallback. |
| Attachments/metadata/permissions visibility | Implemented/partial | Implemented/partial | Both lanes expose what provider can read and surface conditional unknowns. |
| Password/encrypted PDFs | Implemented/partial | Implemented/partial | Password callbacks are wired and explicit prompts are used before open failures. |
| Accessibility reading order/tags | Conditional | Conditional | No full PDF/UA claim until a validator lane is completed. |

### 2) Native interactive form workflow

| Feature | Native status | Web-local status | Notes |
|---|---|---|---|
| Native AcroForm inventory | Implemented | Implemented (proof) | Browser PDF.js inventory records widget kind, value, choices, page-space bounds, and source digest. |
| Fill text field | Implemented | Implemented (proof) | pdf-lib setter plus PDF.js reopen validation on the reviewed public sample form. |
| Fill checkbox | Implemented | Implemented (proof) | Browser setter path is wired; broader checkbox corpus and appearance regression remain open. |
| Radio groups | Gated | Gated | Current lane drops radio-choice metadata on no-op save in public fixture; gate remains visible. |
| Combo/list fields | Conditional | Conditional | Supported in concept, requires stronger preservation evidence. |
| Signature widgets (inventory only) | Implemented (inventory) | Planned | No cryptographic signature claims until the dedicated integrity and trust gates close. |
| Required-format validation | Planned | Planned | Provider metadata plus product-level checks. |
| Field keyboard navigation | Planned | Planned | Required for large-form completion speed. |
| Save from completed native fields | Planned | Planned | Must pass export reopen + preservation gates. |
| Fill from templates/profiles | Planned | Planned | Must be user-approved mappings, not heuristic auto-fill. |
| Create new fillable field objects | Deferred | Deferred | Delayed until high-confidence field semantics and compatibility proof. |

### 3) Static blank-region detection and suggestion loop

| Feature | Native status | Web-local status | Notes |
|---|---|---|---|
| Vector/text geometry candidate detection | Implemented (conservative text-anchored) | Implemented (proof) | Browser detects colon-anchored entry regions and records evidence/confidence. |
| Underline-like blank detection | Implemented/partial | Implemented (proof) | Browser detects underline-like text clues; vector boxes and OCR remain separate. |
| Checkbox/radio-like shape detection | Planned | Planned | Needs better false-positive controls across tables/decoration. |
| Empty scanned-box detection | Planned | Planned | OCR/layout lane needed; not a browser-core default until its evidence gates close. |
| Label association and ambiguity display | Planned | Planned | Needed for confidence calibration. |
| Candidate type inference (date/number/text/etc.) | Planned | Planned | Useful only as suggested type, never final truth. |
| Guided “next blank” entry flow | Planned | Planned | UI/workflow path, not auto-apply. |
| Convert candidate into native form field | Deferred | Deferred | Requires separate semantics and compatibility gate. |
| Reusable template capture | Deferred | Deferred | Requires template versioning + source fingerprints. |

### 4) Bounded editing and markup

| Feature | Native status | Web-local status | Notes |
|---|---|---|---|
| Add text overlay | Implemented | Implemented (proof) | Explicit candidate review, lower-left coordinate preview, pdf-lib draw, and reopen validation. |
| Add image/stamp/logo | Implemented | Planned | Must carry source and provenance. |
| Draw/highlight/underlin/strike/note/freehand | Implemented (core) | Planned | Overlays and annotations are different from native content rewrite. |
| Move/resize/recolor overlays | Planned | Planned | Requires stable geometry persistence across reopen. |
| Review/check/correct overlay before export | Implemented (core) | Implemented (proof) | Candidate selection, preview, operation list, undo, and validation status are visible in the browser panel. |
| Edit existing in-place text objects | Conditional | Conditional | Requires provider-level semantic edit proof; long-term capability, not silently implied by overlays. |
| Edit existing images | Conditional | Conditional | Same as text objects; not default promise. |
| Whiteout/cover content | Conditional | Conditional | Not redaction claim; visible as masking only unless proven. |
| Watermark/header/footer/page numbers | Planned | Planned | Useful batch deterministic feature with clear semantics. |
| Background replacement | Deferred | Deferred | High-risk content rewrite lane. |

### 5) Security-sensitive and integrity features

| Feature | Native status | Web-local status | Notes |
|---|---|---|---|
| Review comments/notes | Implemented | Planned | In line with bounded annotation strategy. |
| Redaction marking | Deferred | Deferred | No-op removal claim blocked until verification. |
| Permanent redaction apply | Gated | Gated | Must prove vector/raster/metadata/content persistence removal end-to-end. |
| Metadata/sanitize/removal | Deferred | Deferred | Requires exact scope and pre/post comparison artifact. |
| Remove JS/actions and unsafe behavior | Gated | Gated | Safe default is isolate and explicit user consent for risky actions. |
| Permissions/password/encryption handling | Gated | Gated | Distinct paths for open permission vs edit authorization. |
| Visual/drawn signatures | Implemented (overlay) | Planned | UX-only utility signature or initials. |
| Digital signature validation | Gated | Gated | Must separate integrity, trust chain, and unknown states. |
| Signature verification report | Gated | Gated | Not a core release contract today. |

### 6) Page and document operations

| Feature | Native status | Web-local status | Notes |
|---|---|---|---|
| Reorder pages | Implemented (prototype) | Planned | Part of page operations slice. |
| Insert/delete/extract pages | Implemented (prototype) | Planned | Depends on provider-safe output validation. |
| Split/merge PDFs | Implemented (prototype) | Planned | Merge/split in bounded operations lane. |
| Rotate pages / normalize orientation | Implemented (prototype) | Planned | Must preserve page boxes with provenance. |
| Crop/media/trim/bleed editing | Conditional | Conditional | Requires provider and geometry precision evidence. |
| Blank-page detection/removal | Planned | Planned | Helpful cleanup lane when corpus includes noisy scans. |
| N-up/booklet/imposition | Deferred | Deferred | Sequenced after core page operations and provider-safe output validation. |
| PDF/image/text conversion | Conditional | Conditional | Output path exists in ecosystem but feature claims are conversion-specific. |
| OCR/import conversions | Gated | Gated | OCR + conversion policy is separate, especially for scanned-first corpora. |
| Compare revisions | Implemented (validation lane) | Planned | Compare reports are core to integrity posture. |
| Batch pipelines | Deferred | Conditional/Deferred | Batch is deferred for product quality and risk controls. |

### 7) OCR, layout, extraction, and intelligence

| Feature | Native status | Web-local status | Notes |
|---|---|---|---|
| Detect scanned/no-text pages | Implemented (candidate) | Planned | Required for OCR lane selection. |
| OCR text layer | Implemented as adapter | Gated | Vision adapter exists; full scanned quality benchmark deferred. |
| OCR bounding boxes | Implemented path | Planned | Useful for candidates only when confidence is tracked. |
| Deskew/denoise/rotate preprocessing | Gated | Gated | Useful later under local worker policy. |
| Table/layout/reading-order analysis | Deferred | Deferred | Valuable after larger corpus. |
| Key-value extraction | Conditional | Conditional | Export artifact first, then structure extraction. |
| Sidecar JSON/CSV/text output | Planned | Planned | Useful for audit/review and downstream integrations. |
| Template matching/lane reuse | Deferred | Deferred | Requires versioned layout fingerprints. |

## Cross-platform status summary

- **Native macOS lane**: core baseline is implemented through provider-neutral contracts + PDFKit adapter + SwiftUI/AppKit shell.
- **Web local-first lane**: design approved as next safe experiment; no feature implementation should outpace contract and evidence parity with native.
- **High-fidelity native/commercial lanes**: PDFBox, MuPDF, PDFium, Apryse, Nutrient remain controlled alternatives pending licensing and corpus proof.

## Expansion register (next logical expansions)

1. Export pipeline hardening against rotated/malformed/encrypted/signed corpora.
2. Independent-viewer and raster-diff parity checks for every export class.
3. OCR/scan lane with quality report and language/resource constraints.
4. Candidate-to-template creation with reusable anchors and confidence governance.
5. Batch completion and job reporting once recovery semantics are stable.
6. Role-based operation history viewer and compliance report for regulated workflows.
7. Controlled redaction and sanitization lane with before/after verification.
8. Digital signature validation lane as separate trust model only.

## Persona mapping used for this feature pass

All personas are now taken from local download: `/Users/pranay/Desktop/personas_23rdaug26.zip`.

Recommended persona slices for this feature/expansion planning round:

- **Product/UX surface design**
  - `PER-0543` Product Feature Designer
  - `PER-0795` Form Experience Designer
  - `PER-0326` Product UX Designer
  - `PER-0550` Accessibility & Inclusive Design Specialist
  - `PER-0328` Accessibility UX Designer

- **Architecture and correctness control**
  - `PER-0001` Refactor Decision Architect
  - `PER-1138` Full-Stack Dev
  - `PER-0796` Developer Experience Engineer
  - `PER-0788` Admin Operations & Control Plane Architect

- **Decision quality, risk, and audit framing**
  - `PER-0924` Failure Mode Architect
  - `PER-0922` Epistemic Integrity Architect
  - `PER-0923` Evidence Architect
  - `PER-0931` Mechanism Designer

- **Expansion economics and GTM clarity**
  - `PER-0337` Product Strategist
  - `PER-1422` Pricing Strategist
  - `PER-0954` Ecosystem Strategy Lead / Market strategy peers

- **Agentic/implementation pipeline roles (if this becomes AI-assisted)**
  - `PER-0680` AI Systems Architect
  - `PER-0891` Agent Observability Architect
  - `PER-0897` Agent Evaluation Architect

- **Policy / signature / compliance context (future-later lanes)**
  - `PER-0913` Policy QA Specialist
  - `PER-0903` Agent Simulation & Scenario Designer
  - `PER-0912` Coverage Comparison Specialist

### Persona operating note

This project’s persona repository rules require project-specific and generic roles to stay separated where applicable and named-only roles not to be treated as fully expanded personas.

## Required follow-up for complete closure

- Keep this register aligned with `docs/implementation-status.md` after each phase.
- Add a companion matrix for every feature indicating *measured result* once corpus gates are executed.
- Keep the user-facing docs explicit about non-goals: arbitrary full-text reflow, silent heuristic field conversion, and legal-signature guarantees.

## Governed expansion matrix by lane and pass criteria

This matrix sets explicit governance for expansion decisions across native, web-local, and companion/server lanes.

### Lane governance model

- Native macOS lane: first-source truth for the product’s local-first core experience.
- Web lane: browser reader and interaction layer sharing the same contracts.
- Companion lane: isolated high-compute or high-complexity provider (OCR/analysis/batch/signature/pdf preflight).
- Companion remains opt-in and explicit in the user flow.

### Expansion governance rules

- **No lane may claim full feature parity without its own passed criteria.**
- **Every expansion row must pass criteria in all columns before user-facing release of that feature.**
- **Provider exceptions must be listed per row.**
- **Any failed criterion keeps the feature in Gated status until fixed or explicitly deferred.**

### Feature vs lane governed matrix

| Feature family | Feature | Primary lane | Secondary/support lane(s) | Required pass criteria | Required evidence |
|---|---|---|---|---|---|
| Reading and navigation | Open/import, render, navigation, zoom, rotate, page jump | Native | Web | Native can handle malformed, large, and rotated PDFs without hard crash in smoke fixtures; web supports same core flows on supported browsers with graceful fallback for unsupported features. | Reopen success, no crash, rendering count, memory cap checks, and parity report for a representative corpus. |
| Reading and navigation | Search and match highlighting | Native | Web | Search index updates after edit, highlight count and offsets stay stable across reopen on tested fixtures. | Fixture-based text search test matrix including Unicode and line-wrap pages. |
| Reading and navigation | Links/outlines/bookmarks | Native | Web | At least known-nesting/anchor links open safely; no automatic script execution. | Link and destination regression test with allowlist policy. |
| Native forms | Native widget inventory and value operations | Native | Web | Inventory returns stable IDs/types/rects and values are read/updated without dropping existing form metadata. | Widget contract test, no-op and edit-save-open checks with external and native sample set. |
| Native forms | Radio choice preservation | Native | Native and companion lanes | No-loss of choice metadata, labels, and export values on save/reopen for multi-widget groups. | Public AcroForm fixture pass with no warning and expected choice array retention. |
| Native forms | Combo/list choices and flags | Native | Companion | Preserved semantics for selected option, export value, and fallback label after export reopen. | Choice fixture suite with option order/label/value assertions. |
| Native forms | Signature widget inventory only | Native | Web | Inventory includes widget type and state but does not validate cryptographic trust by default. | Presence test and no destructive mutation on read-only path. |
| Static detection | Static candidate proposal | Native | Web | Candidate recall with bounded false-positive rate and uncertainty scoring; no auto-apply. | Ground-truth benchmark with abstention rate and reviewer acceptance logs. |
| Static detection | Label association and candidate ranking | Native | Web | Label distance + reading-order heuristics reduce mis-assignment against mixed-layout fixtures. | Precision on label binding and ordered suggestion audits across rotated/multi-column pages. |
| Static detection | OCR-backed detection | Companion | Native and web consume OCR evidence | OCR output has bounded confidence and provenance metadata per region before candidate creation. | OCR corpus test and minimum-confidence policy with rejection cases. |
| Bounded editing | Text overlay and free-text fills | Native | Web | Edits render visibly in same session and survive reopen with unchanged unrelated content. | Reopen/diff checks and coordinate replay test for every operation type. |
| Bounded editing | Overlay move/resize/recolor | Native | Web | Geometric transforms persist under reopen and export with deterministic rounding and page-space conversion. | Transform replay test across non-90deg rotations and crop-box variants. |
| Bounded editing | Text/image stamp overlays | Native | Web | Overlay artifacts remain within approved page bounds and preserve DPI/format constraints. | Export raster comparison + metadata check. |
| Bounded editing | Note/highlight/annotation review | Native | Web | Annotation visibility, edit/delete behavior, and metadata survival are deterministic. | Annotation lifecycle test including undo/redo and reopen checks. |
| Bounded editing | Existing object editing (in-place) | Companion | Native/Web for review | Only enabled where provider proof confirms no unintended content drift; else remains disabled. | Object-level fixture suite, diff threshold proof, and explicit opt-out switch. |
| Security and integrity | Visual signatures/stamps | Native | Web | Signature fields and overlay signatures do not claim legal validity in UI. | UI copy audit + user-consent labeling tests. |
| Security and integrity | Redaction mark | Native | Companion for apply lane | Marked regions produce immutable audit record before and after apply requests. | Marking-only tests; apply lane remains gated until legal/persistence validation. |
| Security and integrity | Permanent redaction | Companion | Native/Web read/showcase only after apply lane verified | Redaction proves object/hidden-layer/text/metadata removal on text, vector, raster, and metadata inspection. | Dual-pass inspection plus independent validator comparison. |
| Page/document operations | Reorder/insert/delete/extract | Native | Web + companion | Page graph remains valid and page counts remain expected after each operation. | Operation replay suite with before/after manifest and no-op stability checks. |
| Page/document operations | Split/merge and rotate normalize | Native | Web | Output remains open by multiple viewers with geometry preserved to tolerance. | External-viewer smoke test and geometry checks on merge/split outputs. |
| Page/document operations | PDF to image/text export | Native | Web + companion | Exports remain deterministic and not silently lossy for supported operations. | Export integrity manifest and checksum/traced file validation. |
| OCR and extraction | Scan/rotated page handling | Companion | Native and web consume artifacts | OCR confidence gates, language config, and crop/rotation correctness tracked per page. | Ground-truth scanned benchmark with per-page error and confidence slices. |
| OCR and extraction | Sidecar JSON/CSV/CSV artifact | Native | Web + companion | Sidecars include source page ranges, coordinate system, policy flags, and confidence. | Contract schema and parser compatibility smoke test. |
| Product governance | Export validation report | Native | Web + companion | Every successful export includes provenance, warnings, failures, and next-check actions. | Report schema regression and user-visible warning assertions. |
| Product governance | Undo/rebuild recovery | Native | Web | Undo is operation-specific and does not clear source or prior accepted history. | Operation log replay and recovery scenario test. |

### Pass/fail governance thresholds

- **Readiness threshold:** any feature with a `Deferred` or `Gated` status in the feature inventory can only move to `Planned` after all pass criteria above are passed in the designated lane.
- **Release threshold:** any feature moving to `Implemented` or user-facing `Go` state must pass two independent providers where practical and one independent-viewer check.
- **Evidence threshold:** at least one machine-generated artifact, one operator-visible report, and one residual-risk note must be attached per feature.
- **Governance threshold:** if a provider path changes (for example from PDFKit to PDFBox), pass criteria remain active and must be rerun before feature claim changes.
