# Decision Records

**Canonical owner:** `/Users/pranay/Projects/pdf_editor/docs/decisions.md`
**Reviewed:** 2026-08-24
**Status:** Active working decisions; final provider selection remains open

This file is the canonical owner for durable product and evaluation decisions in
this discovery workspace. Research findings remain in [`../findings.md`](../findings.md);
runtime evidence belongs in [`pdfkit-benchmark.md`](pdfkit-benchmark.md).

## D-001: Bounded Filling Is the First Safety-Critical Implementation Slice

- **Date:** 2026-08-23
- **Status:** Accepted working decision
- **Approval source:** The current user instructed: “call subagents and do all,”
  after the recommended next action was presented. This authorizes the bounded
  research, benchmark, documentation, and implementation scope below; it does not
  satisfy separate legal, production, or Git gates.
- **Context:** Static blank-region detection is probabilistic, while arbitrary
  existing-text reflow has no demonstrated preservation oracle in the inspected
  candidates. The project needs a safety-critical implementation slice before
  expanding into the full long-term capability frontier.
- **Selected path:** Start with reading, native-field filling, reviewed
  static-region suggestions, reversible overlays/annotations, export to a new
  copy, undo/recovery, and save/reopen validation. This is the first
  implementation and evidence slice, not a permanent product boundary.
  Arbitrary text reflow and automatic conversion of heuristic candidates into
  verified fields require their own provider and validation paths.
- **Options considered:**
  - Arbitrary semantic PDF editing: rejected for this phase because preservation
    and semantic intent are not yet testable across the target corpus.
  - Static detection followed by silent autofill: rejected because false positives
    can alter legal, identity, or signature-related content without review.
  - Bounded filling with explicit review: selected because the mutation boundary is
    visible, reversible, and benchmarkable.
- **Trade-offs:** The first implementation slice is narrower than a
  desktop-publishing editor, but it can make a defensible preservation claim for
  a defined document class while the long-term platform expands.
- **Risk:** Users may expect arbitrary content editing; the UI and documentation
  must state the boundary clearly.
- **Validation:** Form 6 benchmark plus a later mixed corpus must verify output
  reopenability and content outside edited regions.
- **Revisit trigger:** Arbitrary reflow becomes a required product outcome, or a
  provider passes an independently reviewed semantic-editing oracle.
- **Owner:** Project owner; implementation agent maintains the evidence record.

## D-002: Native macOS First, PDFKit First Benchmark Lane

- **Date:** 2026-08-23
- **Status:** Accepted benchmark direction; provider adoption remains proposed
- **Context:** The primary surface is native macOS, with a browser/local web surface
  secondary. The local environment has Xcode 26.3, Swift 6.2.4, and macOS SDK 26.2.
- **Selected path:** Evaluate PDFKit first behind provider-neutral document,
  candidate, edit, and validation contracts. Use one headless Swift source file and
  system frameworks before creating a Swift Package or UI project.
- **Options considered:**
  - PDF.js plus pdf-lib: retained as the secondary browser lane.
  - PDFBox: retained as a permissive JVM control lane if PDFKit fails fidelity or
    packaging gates.
  - MuPDF/Poppler/PoDoFo/PDFium: retained as conditional native lanes; not selected
    before runtime and license evidence.
  - Full Xcode application scaffold: deferred because the first questions are
    parser, renderer, writer, and fidelity questions rather than UI questions.
- **Trade-offs:** PDFKit is platform-specific and opaque, but avoids premature
  cross-platform abstraction and matches the confirmed primary user surface.
- **Risk:** PDFKit save/reopen behavior may vary by macOS release and may not meet
  the fidelity bar. The benchmark must not convert API capability into adoption.
- **Validation:** No-op save/reopen, page render comparison, native widget inventory,
  bounded annotation round trip, and original-byte preservation.
- **Rollback/migration:** Keep provider-neutral contracts; switch the adapter to
  PDFBox or a native open-source provider if the gates fail.
- **Revisit trigger:** Any hard benchmark failure, required non-macOS parity, or
  licensing/distribution constraint that invalidates the system-framework path.
- **Owner:** Project owner; benchmark artifacts record the result.

## D-003: Permissive Dependencies by Default; OCR Deferred

- **Date:** 2026-08-23
- **Status:** Accepted working defaults; legal review remains separate
- **Selected path:** Prefer permissive dependencies for the distributable core.
  Apple system frameworks are acceptable for the native macOS shell. Defer scanned
  document OCR until a corpus requires it; Form 6 is text-extractable and does not
  need OCR for the first lane.
- **OCR candidates:** Apple Vision for native macOS, Tesseract as the permissive
  baseline, and PaddleOCR or Docling only for a later layout-aware scanned lane.
- **Rejected for now:** Adding OCR, model files, or a cloud provider before a
  scanned-document requirement and local resource/license evaluation exist.
- **Trade-offs:** The first benchmark cannot answer scanned-form accuracy, but it
  avoids adding model/runtime risk to a vector/text extraction problem.
- **Revisit trigger:** The approved first corpus includes scanned or text-poor PDFs.
- **Owner:** Project owner; any model/dependency adoption needs its own provenance,
  license, resource, and security record.

## D-004: Safety Gates Precede Accuracy Scores

- **Date:** 2026-08-23
- **Status:** Active
- **Selected path:** Benchmark acceptance is lexicographic. A candidate must first
  preserve the source digest, produce a reopenable output, avoid unsafe autofill,
  and respect resource/error boundaries. Only then do precision/recall, latency,
  and memory comparisons matter.
- **Rationale:** A detector or writer that scores better while changing unrelated
  content is not an improvement.
- **Required evidence:** Record environment, fixture digest, provider/version,
  command, output artifacts, oracle, result, evidence tier, sensitivity, residual
  risk, and exact next check.
- **Revisit trigger:** The benchmark corpus or product mutation boundary changes.

## Decision History

No earlier decision records are superseded. The initial architecture and comparison
documents remain proposed design inputs; D-001 through D-004 make the working
execution choices explicit without upgrading runtime behavior to verified product
behavior.

## Research Update: Native and Commercial Control Lanes

- **Date:** 2026-08-24
- **Status:** Evidence update; no provider adoption decision
- **Context:** The follow-up source sweep closed several release, API-surface, and
  distribution gaps for PDFBox, PDFium, MuPDF, Poppler, PoDoFo, Nutrient, and Apryse.
- **Evidence:** PDFBox has active Apache-2.0 release lines and documented forms,
  rendering, extraction, signing, and preflight. PDFium is a Chromium-toolchain
  component with public embedder headers and BSD-style header signals. MuPDF remains
  broad but AGPL/commercial. Poppler has current native form/signature APIs but GPL
  terms in inspected frontend headers. PoDoFo documents writing and incremental
  updates but no rendering, with a source/documentation version discrepancy.
  Nutrient and Apryse document broad proprietary SDK surfaces with sales-led pricing.
- **Decision impact:** Keep the native-first bounded architecture and provider-neutral
  contracts. Retain PDFBox as the permissive JVM control lane, PDFium as a low-level
  native embedding lane, and Nutrient/Apryse only as commercial control cases. Do not
  convert release activity, API breadth, or vendor claims into fidelity or adoption
  evidence.
- **Alternatives considered:** Select the broadest API immediately (rejected because
  no provider has passed the target corpus); treat PDFium as a turnkey editor
  (rejected because its public contract is an embedder surface); infer exact vendor
  price or legal clearance from pricing pages (rejected because terms remain
  procurement and legal questions).
- **Validation/falsifier:** Run the same external AcroForm, static-form, malformed,
  rotated, encrypted, signed, and unrelated-content preservation fixtures through at
  least PDFKit, PDFBox, and one native open-source lane before provider selection.
- **Owner:** Project owner; the next provider lane maintains the machine evidence.

## D-002 Amendment: Initial PDFKit Lane Passed With a Cross-Renderer Caveat

- **Date:** 2026-08-23
- **Status:** Active; final provider selection remains open
- **Evidence:** The Form 6 harness run recorded in [`pdfkit-benchmark.md`](pdfkit-benchmark.md)
  passed its PDFKit-local checks at Tier 2/S1.
- **Result:** PDFKit opened the fixture, identified zero native widgets, rendered
  both pages, reopened a no-op output with equivalent page/text/widget state, and
  reopened one bounded FreeText annotation while preserving the input digest.
- **Caveat:** Poppler's independent rasterizer found page 2 absolute error `85` at
  144 DPI between the source and PDFKit no-op output. Poppler also includes the
  expected annotation contents in overlay text extraction. These observations do
  not reject PDFKit, but they prevent a universal fidelity claim.
- **Decision impact:** Continue with a broader corpus and independent-viewer lane;
  do not select PDFKit as the final provider yet.
- **Revisit trigger:** Native widget round-trip, rotated/malformed/encrypted fixtures,
  or independent viewer checks fail the defined gates.

## D-002 Amendment: External AcroForm Preservation Is Not Cleared

- **Date:** 2026-08-23
- **Status:** Active; PDFKit remains an evaluated candidate, not the selected provider
- **Evidence:** The public AcroForm lane in [`pdfkit-widget-benchmark.md`](pdfkit-widget-benchmark.md)
  produced Tier 2/S1 failure evidence.
- **Result:** PDFKit reopened six widgets, preserved page/widget count, source digest,
  text extraction, and a text mutation, but dropped the `choices` array from both
  radio widgets sharing `applicant.contact`. PDFKit logged a field/widget-sharing
  warning. The shell gate correctly exited nonzero while preserving the result JSON.
- **Decision impact:** Do not weaken the widget-state gate. PDFKit cannot yet be
  treated as cleared for external AcroForm preservation. Continue with a second
  public sample and an alternative-provider comparison before product implementation.
- **Alternatives considered:** Treat radio choices as presentation-only (rejected;
  choices are part of the field contract), limit the product to text/checkbox fields
  (rejected as premature scope reduction), or select another provider now (deferred
  until a comparable external sample and license review exist).
- **Revisit trigger:** A reproduced PDFKit fix/compatibility path, a provider that
  preserves the field hierarchy and choices, or a deliberate product-scope change.

## D-005: Commercial Wedge Is Bounded Local Document Completion

- **Date:** 2026-08-24
- **Status:** Proposed commercial direction; not a final product approval
- **Context:** Broad PDF editing is a mature incumbent category with free and
  low-cost substitutes. The strongest product evidence so far is for bounded
  filling, preservation, review, and recovery rather than arbitrary PDF reflow.
- **Selected direction:** Position the first product as a local-first tool for
  completing forms and structured paperwork without disturbing surrounding
  content. Target professional and regulated small businesses first, while
  retaining an individual reader/filler path.
- **Options considered:**
  - Generic Acrobat alternative: rejected as too broad and feature-count driven.
  - AI-first automatic form editing: rejected because heuristic false positives
    are unsafe without user review and preservation gates.
  - E-signature/workflow suite: deferred because identity, retention, audit,
    permissions, and support requirements change the product risk class.
  - Developer/API-first product: deferred until the local document/edit contract
    and provider behavior are stable.
- **Pricing hypothesis:** Test free reading/native filling, Pro at `$79/year` or
  `$9.99/month`, and a small Team plan around `$149/seat/year`; keep cloud OCR
  opt-in and separately metered.
- **Trade-offs:** The narrower wedge reduces immediate feature breadth and may
  limit enterprise reach, but makes preservation, recovery, and user trust
  testable. A subscription may fail if the workflow is only occasional.
- **Validation:** Interviews and observed workflows in the selected service
  sectors; pricing test; suggestion acceptance; repeat use; and expanded
  cross-viewer provider benchmarks.
- **Falsifiers:** Low recurrence, low willingness to pay, failure to preserve
  external AcroForm semantics, or customers requiring e-signature/admin features
  before purchase.
- **Rollback/revisit:** Return to a reader/annotation utility, a one-time purchase,
  or a developer tooling direction if the recurring completion wedge is not
  validated.
- **Owner:** Project owner; implementation agent maintains the evidence record.

## D-006: Implement the Native macOS Vertical Slice Behind Provider-Neutral Contracts

- **Date:** 2026-08-24
- **Status:** Accepted implementation decision; final provider remains open
- **Approval source:** The current user instructed the agent to continue and “do all”
  after the implementation scope and next steps were stated. This authorizes
  ordinary implementation, testing, documentation, and filesystem verification in
  this project. It does not authorize Git mutations, production deployment,
  external service writes, or legally binding signature claims.
- **Context:** Research established a bounded product boundary and native-first
  direction, while PDFKit has a known external AcroForm radio-choice preservation
  failure and no provider has passed the full corpus.
- **Selected path:** Build a macOS SwiftUI/AppKit shell, a provider-neutral core,
  and a PDFKit adapter for inspection, native field edits, reviewed overlays,
  export-to-new-copy, reopen validation, and recovery-visible failures. Keep
  provider selection replaceable and preserve all existing benchmark gates.
- **Rejected alternatives:** Waiting for final provider selection before any UI or
  contract work would delay the product while the provider-neutral boundaries are
  already testable; exposing PDFKit types directly would make the known failure and
  future migration harder to contain.
- **Trade-offs:** The first slice is macOS-focused and will not claim broad PDF
  fidelity. A later PDFBox/native comparison must exercise the same contract and
  corpus.
- **Validation:** `swift test`, `swift build`, generated fixture round trips,
  preserved public AcroForm failure, Form 6 reopen/export checks, and later
  independent-viewer/corpus gates.
- **Rollback/migration:** Remove or replace the adapter while retaining the core
  contract, edit log, fixtures, and validation reports.
- **Owner:** Project owner; implementation agent maintains evidence and docs.
# Decision record: cross-platform feature frontier before web implementation

**Date:** 2026-08-24  
**Status:** Accepted architecture direction; deployment shape superseded by D-009  
**Scope:** Native macOS app and local-first web app  
**Owner:** Pranay

## Context

The project already contains a native macOS prototype, provider evaluation, and
benchmarks for safe form completion. The next question is which broader PDF
features should be available in both the native and web applications, and which
provider composition can support them without weakening the “do not touch other
text” promise.

## Decision under review

Use a shared provider-neutral model for document facts, page-space coordinates,
candidate evidence, typed operations, undo/replay, and export validation. Use
platform adapters for rendering, native file access, PDF writing, and OCR.

Recommended first web composition: PDF.js for browser parsing/rendering and
pdf-lib for bounded writing and overlays. Continue PDFKit for the macOS native
shell behind the existing adapter. Keep PDFBox and MuPDF/MuPDF.js as separately
gated alternatives rather than adding them before corpus evidence and license
review.

## Alternatives considered

1. **One engine everywhere:** technically appealing, but it forces the product
   into the engine’s license and platform constraints and may make the native
   shell or browser bundle heavier than needed.
2. **PDF.js only:** strong reader and inspection foundation, but not a complete
   PDF writer for the requested editing/export workflow.
3. **pdf-lib only:** practical writer for browser overlays/forms, but not a
   renderer and not proof of safe semantic editing of existing content.
4. **MuPDF everywhere:** potentially strong fidelity and broad surface, but the
   AGPL/commercial license boundary is a material distribution decision.
5. **Hosted server first:** enables batch, OCR, and collaboration, but changes
   the privacy model and introduces storage, retention, security, and operations
   work before the local completion workflow is proven.

## Rationale

The user value is fast, safe completion of real-world PDFs. A split viewer/
writer composition keeps the web core local and permissive while the shared
operation model protects product semantics. A provider is not considered
adopted merely because it can open a PDF or pass a synthetic fixture. External
forms, no-op saves, Unicode, rotated pages, annotations, OCR, and independent
viewer checks remain explicit gates.

## Consequences

- Native and web exports may differ in byte layout while preserving the same
  operation intent and safety report.
- Provider adapters and contract fixtures become first-class maintenance work.
- “Normal PDF editing” remains bounded until object-level and reflow evidence is
  available.
- The web app needs explicit ephemeral, local-draft, and file-backed storage
  modes with browser fallbacks.
- OCR, redaction, and cryptographic signatures remain separate risk lanes.

## Validation and falsifier

Run the same representative corpus against the native and browser lanes. This
decision is falsified if the browser-only composition cannot preserve the
required native-form/overlay cases, if coordinate transforms fail under rotation
or crop boxes, or if the target user workflow requires arbitrary paragraph
reflow or collaboration as a first-order requirement.

## Recovery

Keep the shared operation contracts and fixtures. Replace a provider adapter or
add a local companion without rewriting the document/session UI. Do not remove
the existing PDFKit evidence or weaken a failed preservation gate.

## D-007: Versioned Native/Web Contract Envelope

- **Date:** 2026-08-24
- **Status:** Accepted implementation decision; browser adapter remains pending
- **Context:** The existing Swift core had provider-neutral model types, but the
  document, candidate, operation, and validation data did not yet carry enough
  version, coordinate, evidence, provider, or check provenance to serve as a
  stable native/web boundary.
- **Selected path:** Add `PDFContractVersion`, `PDFContractHeader`, and the
  generic `PDFContractEnvelope` with concrete document and validation aliases.
  Use `PDFPageRegion` for page-space coordinates, structured
  `CandidateEvidence` for detection provenance, `CandidateReviewDecision` for
  user confirmation, structured `EditPayload` for typed operation values, and
  `ValidationCheck` for individual proof states. Extend existing models
  additively so current PDFKit call sites and compatibility fields remain valid.
- **Compatibility rule:** Accept the same major version and an equal or older
  minor version. Decode absent additive fields with safe defaults. Reject future
  contract versions before mutation and do not silently map unknown enum values.
- **Alternatives considered:**
  - Share PDFKit/PDF.js object models directly: rejected because the APIs and
    provider semantics differ.
  - Use unversioned dictionaries: rejected because field meaning and safety
    invariants would drift without a negotiation point.
  - Replace `EditOperation` wholesale: rejected because the current native
    adapter and tests already use its compatibility fields.
- **Trade-offs:** The envelope is more verbose and conservative than a loose
  JSON object. In return, a stale inspection, wrong source digest, unsupported
  provider operation, or unknown validation state can be surfaced explicitly.
- **Validation:** `swift test` passed 11 tests, including document envelope
  round-trip/version negotiation, backward candidate decoding, rotated page
  coordinates, structured choice payloads, edit-session source binding, and
  validation-check lineage. This is contract evidence, not native/web PDF
  fidelity evidence.
- **Rollback/migration:** Keep the existing compatibility fields and remove or
  replace only the envelope/adapters. Do not discard the operation log or
  existing provider benchmarks.
- **Revisit trigger:** A web adapter needs a different serialization format, a
  major safety invariant changes, or a provider requires semantics that cannot
  be represented without a contract major-version change.
- **Owner:** Project owner; native and web adapter implementations maintain
  fixture compatibility.

## D-008: Privacy-First Recurring Template System

- **Date:** 2026-08-24
- **Status:** Accepted design direction; T1 contract/runtime, immutable local capture/revisions, and browser review surface implemented, native review UI and adapter wiring pending
- **Context:** The reader/editor can now inspect native fields, detect static
  candidates, queue reviewed operations, preserve source bytes, and validate
  exports. Recurring forms need faster completion without turning a template
  into a copy of a sensitive PDF or a silent autofill authority.
- **Selected path:** Create a separate versioned `pdf-editor.template`
  contract. Store a local keyed layout fingerprint, reviewed mapping records,
  evidence references, revision lineage, match/review policy, and learning
  history. Keep source PDFs outside the template store. Keep profile values in a
  separate explicitly unlocked local vault, referenced only by semantic keys.
  Match results remain proposals. Every applied value produces the existing
  source-bound `EditOperation`, and active template revisions change only after
  explicit save/update following a successful validated session.
- **Privacy boundary:** Default local-only processing, no raw PDF bytes, no raw
  labels, no screenshots, and no profile values in template records. Raw labels
  may be held as encrypted local explainability data only when the user opts
  in. Browser persistence is opt-in and must state eviction/backup limits. No
  sync is part of the local-first core.
- **Matching rule:** Distinguish exact source identity, exact layout identity,
  known variant, family match, ambiguous match, stale match, and no match. Exact
  and high-confidence matches may preselect compatible mappings, but values are
  still previewed and reviewed before operation creation. Ambiguous or stale
  matches abstain.
- **Learning rule:** Learn only user-confirmed structure and mapping changes.
  Store them first as pending local learning events. Failed or unvalidated
  exports cannot create active template revisions. Template updates create a
  new revision with a parent revision ID and remain revocable.
- **Alternatives considered:**
  - Store a completed PDF as the template: rejected because it retains source
    content and values, encourages brittle coordinate replay, and blurs source
    and template ownership.
  - Store raw labels and profile values in one local template JSON: rejected
    because export, backup, and sync become accidental PII exfiltration paths.
  - Silently apply exact matches: rejected because source publishers can alter
    fields, page boxes, or semantics while preserving superficial similarity.
  - Cloud-first shared templates: deferred because it changes the privacy,
    retention, key-management, deletion, and tenant-isolation risk class.
- **Trade-offs:** Keyed fingerprints reduce cross-workspace linkability but
  make templates less portable. Separate profile references improve privacy but
  require an explicit unlock and value-preview step. Immutable revisions and
  learning review add friction but prevent silent drift and make rollback
  possible.
- **Validation and falsifier:** Add T1 contract round-trips, no-raw-content
  assertions, fingerprint variant tests, stale/ambiguous abstention tests,
  wrong-source rejection, failed-export no-learning tests, revision revocation
  tests, and native/web fixture parity. Falsify this direction if users require
  collaboration or multi-device synchronization as a first-order workflow and
  the local-only model cannot meet that need without an acceptable client-side
  encryption and key-recovery design.
- **Rollback/migration:** Keep the current document, candidate, operation, and
  validation contracts unchanged. A template store can be disabled or deleted
  without affecting source PDFs or existing completion sessions. If the
  fingerprint algorithm changes, create `layout-features-2` and a new template
  revision rather than reinterpreting old fingerprints in place.
- **Owner:** Project owner; native and web adapters share the contract and
  privacy gates.

## D-009: Browser Core with an Optional Local Companion Capability Plane

- **Date:** 2026-08-24
- **Status:** Accepted product decision; companion implementation remains gated
- **Approval source:** The current user explicitly asked for the deployment
  decision between browser-only OCR/high-fidelity editing and an installed local
  companion. This records the resulting long-term architecture decision. It
  authorizes the corresponding planning and documentation updates, not companion
  packaging, legal approval, Git mutation, or release.
- **Decision detail:** [`docs/web-deployment-decision.md`](web-deployment-decision.md)
- **Scope correction:** The earlier working title and first-release language
  described rollout sequencing, not the long-term product boundary. This record
  now owns the long-term browser core plus companion capability-plane
  architecture. The historical staging recommendation remains preserved in the
  detailed document.
- **Context:** The project now has a bounded browser PDF.js/pdf-lib proof and
  shared native/web contracts, but OCR, independent-viewer fidelity, large-file
  behavior, native/web parity, and final provider selection remain open. The
  deployment question is which capabilities belong in the browser core and
  which require the explicitly installed companion plane over the long term.
- **Selected path:** Build a browser-first local core for reading, supported
  native-field filling, reviewed static candidates, bounded overlays,
  annotations, page operations, and validated new-copy export. Build an
  explicitly installed optional companion capability plane for OCR,
  high-fidelity editing, batch processing, large-document work, and other
  provider-dependent capabilities. Both surfaces consume the same long-term
  contracts and validation model. Bounded operations define safe mutation
  semantics, not a short-term feature ceiling.
- **Why:** The browser core provides zero-install reach and a strong local
  foundation, while the companion gives the long-term platform a place for
  native runtimes, model assets, filesystem access, process isolation, and
  high-fidelity providers. OCR and high-fidelity editing must be explicit
  capabilities because their runtime and evidence requirements differ, not
  because they are outside the product vision.
- **Alternatives considered:** A required companion from day one was rejected as
  too much lifecycle and support burden before the browser baseline and bridge
  are measured. Hosted/self-hosted processing was deferred because it changes
  privacy, retention, tenant, and source-of-truth obligations. MuPDF/MuPDF.js
  remains a high-fidelity candidate behind an AGPL/commercial decision. PDFBox
  remains the permissive JVM control lane. Browser OCR remains experimental until
  a corpus accuracy and runtime gate exists.
- **Consequences:** The browser UI must expose unsupported, companion-required,
  encrypted, signature, and fidelity states honestly. The companion is an
  adapter and optional capability provider, not a second product truth. The
  project must continue browser export, independent-viewer, parity, OCR,
  high-fidelity, accessibility, and support-policy gates as the long-term
  platform expands.
- **Validation:** Run each capability through the same corpus and shared
  contracts. Companion providers require bridge threat-model, license,
  packaging, recovery, resource-limit, and independent-viewer gates before
  promotion from experiment to supported capability.
- **Falsifiers:** The launch corpus is predominantly scanned/handwritten and
  browser OCR cannot meet defined thresholds; required form classes fail browser
  export; browser limits make the core workflow unreliable; users require local
  batch/OCR/high-fidelity work at launch and accept installation; or a selected
  provider requires a companion or a different licensing posture.
- **Migration/rollback:** Keep shared contracts, source digests, operations,
  templates, and validation reports independent of the companion. If a companion
  is absent or removed, the browser-supported subset remains usable and preserves
  explicit unsupported reasons. No source PDF is rewritten as part of this
  decision.
- **Owner:** Project owner; implementation agent maintains the evidence record.

## D-010: Cross-Project Evidence Graph Before Capability Import

- **Date:** 2026-08-24
- **Status:** Accepted exploration and planning decision; implementation pending
- **Context:** Local SignKit, MetaExtract, Invoice Intelligence, PhotoSearch, and
  form-extraction work contains relevant OCR, parser, PDF inspection, candidate,
  provenance, validation, and privacy patterns. Copying code or adding all
  dependencies would create duplicate ownership and blur evidence status.
- **Selected path:** Treat the reusable moat as a provider-neutral, reviewed
  evidence and operation graph. First record a cross-project evidence ledger and
  run native/web semantic contract parity on the existing PDF corpus. Only then
  consider importing an adapter, fixture category, model, parser, or companion
  capability behind the PDF editor's contracts.
- **What is reusable:** source-digest binding, page-space geometry, native-first
  inspection, OCR regions, candidate evidence, N-best review, hard negatives,
  reviewed correction events, schema/alias discipline, fallback routing,
  validation families, corpus separation, and explicit privacy/claim boundaries.
- **What remains owned elsewhere:** SignKit signature extraction/cleanup/assets
  and vault; MetaExtract's general metadata registry; Invoice Intelligence's
  invoice schema/prompts; PhotoSearch's media catalog and OCR search. These are
  references or future adapters, not PDF-editor core sources of truth.
- **Alternatives considered:** Copy adjacent pipelines into this project
  (rejected because it creates a second source of truth); select one OCR engine
  now (rejected because corpus and workflow evidence are incomplete); create a
  general document-intelligence platform immediately (deferred until repeated
  cross-product demand proves shared ownership reduces complexity).
- **Trade-offs:** The evidence-led route delays feature breadth and dependency
  consolidation, but preserves rollback, provenance, privacy, and provider
  replaceability. A copied implementation may produce faster local progress but
  would make future parity and maintenance harder to reason about.
- **Validation:** The next ledger must record source path, owner, truth status,
  input/output schema, coordinate space, privacy class, license/provenance state,
  and test/runtime evidence. The parity fixture must compare normalized semantic
  records rather than byte-identical PDF output.
- **Falsifiers:** No shared evidence shape can represent the required workflows;
  adjacent capabilities cannot be legally or technically isolated; or measured
  correction reuse does not improve safe completion enough to justify the
  storage, review, and maintenance cost.
- **Rollback:** Delete or disable an adapter/ledger consumer without changing
  source PDFs, existing contracts, operation history, templates, or native/web
  supported behavior. Do not move source corpora between projects implicitly.
- **Owner:** Project owner; this project maintains the synthesis and parity gates.

## D-011: ihatepdf.cv Is a Product Reference, Not a PDF Fidelity Authority

- **Date:** 2026-08-24
- **Status:** Accepted exploration boundary; experiments pending
- **Context:** ihatepdf.cv presents a compelling local-first browser product with
  a broad tool catalog and a public technical explanation that overlaps with
  the PDF.js plus pdf-lib composition under evaluation here.
- **Selected path:** Salvage the product patterns of task-oriented tool entry,
  PWA/share-target behavior, storage tiers, resource preflight, batching,
  compare, privacy scanning, repair intake, and explicit capability modes. Add
  competitor-inspired corpus experiments for text-run replacement, OCR alignment,
  privacy sanitization, repair, adaptive limits, and semantic/visual comparison.
  Keep the PDF editor's differentiated core as reviewed form completion,
  source-bound operations, evidence, templates, and validation.
- **Claim boundary:** Treat all site feature, accuracy, privacy, security, legal,
  offline, and fidelity statements as observed public claims until independently
  verified. “No upload” must be scoped per capability because the public surface
  also exposes analytics, external assets, AI text transmission, and P2P/STUN
  behavior.
- **Alternatives considered:** Copy the competitor's full feature catalog now
  (rejected because breadth would outrun validation and support capacity); select
  its exact engines and numeric limits (rejected because public description is
  not corpus evidence); ignore it because it is broad (rejected because its
  composition and browser resource strategy are useful competitive signals).
- **Trade-offs:** Adopting the patterns improves the web product's usability and
  long-term surface strategy, while keeping each risky capability behind a
  typed gate delays visible breadth. This preserves the project's trust wedge.
- **Validation:** Use the six proposed experiments in
  [`docs/competitor-ihatepdf-cv-exploration-2026-08-24.md`](competitor-ihatepdf-cv-exploration-2026-08-24.md). Require source digest binding,
  output reopenability, independent-viewer checks where relevant, privacy data
  flow, and explicit unknown/unsupported states.
- **Falsifiers:** The site-inspired patterns do not improve completion or
  comprehension; browser resource limits make the local-first surface unreliable;
  or the target users value broad conversion breadth more than high-trust form
  completion and validation.
- **Rollback:** Keep the shared contracts and corpus. Remove a tool route,
  capability adapter, or PWA surface without changing source PDFs, operation
  history, template records, or native provider behavior.
- **Owner:** Project owner; implementation agent maintains the evidence record.

## D-012: Promote Outside-Region Impact Checks to a Shared Fidelity Gate

- **Date:** 2026-08-24
- **Status:** Accepted and implemented in native and browser adapters
- **Context:** The browser proof previously reported that object-level text
  preservation outside edited regions was not implemented. The native provider
  had a whole-page extracted-text comparison that could not distinguish an
  authorized field or overlay change from an unrelated change. The remaining
  excluded claims require a narrower, operation-aware proof before general
  editing work expands.
- **Selected path:** Add provider-local text-item/character comparisons and
  fixed-scale raster comparisons outside the page-space regions owned by the
  operation. Emit the shared `outsideRegionText` and `visualDiff` validation
  checks, include metrics where available, and return `unknown` when an
  operation lacks coordinates. Keep independent-viewer, byte-identity, PDF/UA,
  redaction, signature, XFA, and arbitrary semantic-editing claims separate.
- **Alternatives considered:** Compare output bytes (rejected because normal
  PDF serialization changes bytes); compare whole-page text (rejected because
  authorized edits become false failures); compare only the edited value
  (rejected because unrelated changes remain invisible); claim full semantic
  editing from a local raster diff (rejected because it exceeds the evidence).
- **Trade-offs:** The gate is more expensive than a digest/reopen check and can
  produce provider-specific unknown or failure results, but it directly tests
  the user-facing preservation promise without forcing native and web engines
  to produce identical output.
- **Validation:** Native `swift test` passes 29 tests, including missing-
  coordinate fail-closed behavior and overlay impact checks. Browser reader,
  completion, workflow, accessibility, and corpus fixture runs pass with
  `outsideRegionText` and `visualDiff` checks emitted. Browser geometry evidence
  is now operator-list-backed, but its precision is not cleared.
- **Falsifiers:** The metric passes exports with known outside-region mutations;
  tolerated rendering differences hide meaningful content; operation regions
  are routinely missing or misprojected; or the check cannot distinguish
  intentional changes from unrelated changes on the reviewed corpus.
- **Rollback:** Remove the validator consumers and preserve the shared contracts
  and existing source-bound export gates. Never downgrade unknown impact checks
  to passed and never delete the corpus or emitted evidence.
- **Owner:** Project owner; native and web adapters own provider-specific
  implementations while the shared validation contract owns status semantics.

## D-013: Separate Browser Store Unlock, Profile Unlock, and Eviction Recovery

- **Date:** 2026-08-24
- **Status:** Accepted implementation decision; browser lifecycle contract and
  targeted security evidence implemented, production persistence UX pending
- **Context:** The first browser template store encrypted records with a
  passphrase, but store access and profile-value access were the same boundary.
  Browser eviction, wrong secrets, deletion, backup recovery, and diagnostics
  therefore lacked explicit state and evidence.
- **Selected path:** Keep IndexedDB as the browser persistence substrate and
  add an authenticated encrypted metadata record for store unlock. Encrypt
  profile payloads inside a second profile-specific AES-GCM envelope with a
  separate passphrase. Expose explicit `unlock`, `lock`, `unlockProfile`,
  `lockProfile`, `inspectHealth`, `exportEncryptedBackup`,
  `restoreEncryptedBackup`, `remove`, and `deleteStore` operations. Detect
  likely eviction as missing authenticated metadata plus a non-sensitive local
  presence hint. Recover only from ciphertext backup envelopes.
- **Privacy decision:** Use `createZeroContentLogger` with an allowlisted event
  schema containing only event code, record kind, mode, state, and count. Do not
  log record IDs, PDF text, labels, profile values, source bytes, passphrases,
  stack traces, or arbitrary exception messages.
- **Alternatives considered:** Treat the store passphrase as profile unlock
  (rejected because any unlocked template session would expose profile values);
  restore plaintext JSON (rejected because backups become a PII export path);
  silently recreate an empty store after eviction (rejected because it hides
  data loss); use browser quota estimates as durability proof (rejected because
  estimates are advisory and browser-specific).
- **Trade-offs:** A second profile secret adds a deliberate interaction and
  profile recovery responsibility, but it narrows the exposure window. A
  ciphertext backup is recoverable only when the user retains both the backup
  and passphrases. The presence hint improves eviction diagnosis but is not a
  durable authority because browser storage can remove it too.
- **Validation:** `Tests/web_template_security_browser_test.mjs` passes store
  lock and unlock, wrong store/profile secret rejection, profile lock and
  unlock, deletion of records and the whole store, simulated IndexedDB
  eviction, invalid-backup rejection, ciphertext-only backup restore, health
  states, and zero-content log assertions in isolated Chrome.
- **Falsifiers:** A browser cannot reliably distinguish eviction from first use
  on the supported target matrix; backup restoration cannot preserve encrypted
  records across the target browser versions; profile unlock causes unacceptable
  completion friction; or any diagnostic sink receives content outside the
  allowlisted schema.
- **Rollback:** Disable opt-in browser persistence and fall back to the
  ephemeral store. Preserve template contracts and completion sessions. Do not
  delete existing encrypted records unless the user explicitly invokes
  `deleteStore`.
- **Owner:** Project owner; browser storage adapter owns implementation and
  browser evidence, while the shared template/profile contracts own record
  shape and privacy invariants.

## D-014: Calibrate Template Family Matching With Reviewed Hard Negatives

- **Date:** 2026-08-24
- **Status:** Accepted benchmark decision; automatic family acceptance remains
  disabled
- **Context:** The shared template design names family and ambiguous states, but
  the production browser/native matchers were intentionally deterministic and
  did not yet have evidence for a structural threshold. Enabling a threshold
  without hard negatives could turn similar-looking forms into silent future
  mutations.
- **Selected path:** Add a value-free reviewed benchmark adapter with explicit
  fixture provenance, deterministic exact and known-variant precedence,
  explainable geometry, native-field, keyed-anchor, and region components, a
  `0.76` family threshold, a `0.05` ambiguity margin, and mandatory abstention
  for ambiguous, stale, and no-match cases. Exercise it against controlled
  perturbations of the real public sample and against the existing Form 6
  browser extraction. Keep the adapter separate from the production
  `matchTemplate` materialization boundary until real recurring families are
  reviewed.
- **Alternatives considered:** Enable family matching from proposed weights
  alone, rejected because no corpus calibration exists; use a single opaque
  embedding score, rejected because evidence and false-positive explanations
  would be difficult to audit; use exact digest only, retained as the safe
  fallback but insufficient for recurring publisher variants.
- **Trade-offs:** Controlled fingerprints provide repeatable S1 and S3 evidence
  quickly, but they do not establish real-world family recall. The benchmark
  intentionally accepts the maintenance cost of expected state, selection, and
  abstention records so a future matcher cannot improve recall by silently
  widening acceptance.
- **Validation:** `node Tests/web_template_match_benchmark_test.mjs` passes seven
  reviewed cases across exact, known variant, family, ambiguous, stale, and two
  no-match negatives. A weakened threshold and zero ambiguity margin fail the
  benchmark. `node Tests/web_template_match_benchmark_browser_test.mjs` passes
  against PDF.js fingerprints from the public sample and Form 6 files; the Form
  6 false-positive gate returns `noMatch` with no selection.
- **Falsifiers:** Real recurring versions produce unacceptable family false
  positives; reviewer agreement is low; the score components are unstable
  across PDF.js and PDFKit fingerprints; or the weakened-policy mutation no
  longer fails the hard-negative cases.
- **Rollback:** Keep exact and known-variant matching plus manual completion,
  remove the thresholded benchmark consumer, and preserve fixture and review
  history. Do not delete source PDFs, template revisions, or negative evidence.
- **Owner:** Project owner; native and browser adapters own extraction and
  provider parity, while the shared matcher contract owns state and abstention
  semantics.

## D-015: Preserve Native/Web Parity Mismatches as Evidence

- **Date:** 2026-08-24
- **Status:** Accepted baseline decision; remediation remains open
- **Context:** The shared contracts existed in native and browser code, but the
  project had no executable corpus harness that serialized both sides and
  compared their semantics. Without that baseline, provider differences could
  be mistaken for parity or hidden by manually edited fixtures.
- **Selected path:** Add `PDFContractHarness` as a native Swift executable and
  `Tests/pdf_contract_parity_test.mjs` as the browser/Node orchestrator. Run
  both against the manifest corpus, perform no-operation export validation,
  normalize only random IDs, timestamps, provider metadata, diagnostic prose,
  output digests, and browser-only fields, then retain the raw bundles and full
  mismatch report under `benchmark/results/contract-parity-2026-08-24/`.
- **Alternatives considered:** Compare serialized JSON byte-for-byte, rejected
  because provider IDs, timestamps, key ordering, and engine-specific fields
  are not product semantics; compare only source digests, rejected because it
  would miss field, geometry, candidate, operation, validation, security, and
  accessibility drift; normalize all provider differences away, rejected
  because that would erase the exact gaps the project needs to resolve.
- **Trade-offs:** The refreshed report is intentionally noisy and records 75 normalized
  mismatches. That noise is valuable because it separates PDF.js page-box
  rounding, detector divergence, public AcroForm button metadata, encrypted
  export behavior, validation applicability, and accessibility scope. A future
  accepted-variance registry can reduce noise only after each class has an
  owner, rationale, tolerance, and falsifier.
- **Validation:** The harness compiled and ran across all ten manifest
  entries. Source digests matched for every successfully inspected fixture;
  the truncated PDF failed in both lanes. The first baseline is recorded in
  `docs/audits/native-web-contract-parity-evidence-2026-08-24.md` and the
  machine report under `benchmark/results/contract-parity-2026-08-24/`.
- **Falsifiers:** The harness misses a deliberate field-kind, coordinate,
  candidate-evidence, operation-lineage, or validation-status mutation; a
  provider emits different source digests for the same input; or the
  comparator's normalization hides a product-relevant difference.
- **Rollback:** Retain the shared contracts and provider tests, remove only the
  parity consumer if it proves too noisy, and preserve the emitted bundles and
  mismatch report as historical evidence. Do not delete the corpus or rewrite
  the baseline to obtain a clean result.
- **Owner:** Project owner; native and browser adapters own their serialized
  outputs, while the parity harness owns comparison policy and evidence
  provenance.

## D-016: Keep Independent Preservation and Provider Reopen as Separate Gates

- **Date:** 2026-08-24
- **Status:** Accepted bounded gate; rotated operation replay remains open
- **Context:** The browser impact validator compared source and output through
  PDF.js, which was useful for local feedback but could not be called an
  independent raster check. The parity harness also deleted validated native
  no-op outputs, preventing a second parser/renderer from inspecting those
  exact bytes.
- **Selected path:** Add a content-minimizing Poppler/qpdf adapter. Use
  `pdfinfo` for page facts and rotations, `pdftotext -bbox-layout` for hashed
  outside-region text, `pdftoppm` for outside-region RGB diffs, and qpdf for a
  separate structural status. Retain native and browser no-op outputs under
  the dated parity evidence directory. Add deterministic 90-degree and mixed
  90/180-degree fixtures and a mutation-sensitive browser test.
- **Alternatives considered:** Treat PDF.js as independent, rejected because
  it shares the browser reader renderer; use byte comparison, rejected because
  valid providers may serialize different bytes; make qpdf warning status the
  same as viewer reopen status, rejected because the existing corpus contains
  recoverable structural warnings while Poppler can still reopen it; add a
  GUI viewer assertion immediately, deferred because human/operator evidence
  needs its own controlled observation surface.
- **Trade-offs:** Poppler improves renderer independence and qpdf improves
  structural visibility, but neither proves semantic object preservation or
  PDF/UA. Retaining export bytes increases evidence size, so the artifacts are
  dated, corpus-scoped, and must never contain source-profile values or raw
  extracted text in reports.
- **Validation:** `node Tests/pdf_independent_preservation_test.mjs` fails an
  unauthorized reviewed export on both text and raster checks, passes with its
  source-bound operation region, reopens the output through Poppler, and checks
  90-degree plus mixed 90/180-degree fixtures. `node Tests/pdf_contract_parity_test.mjs`
  writes the ten-fixture independent report. The malformed source fails as
  expected and encrypted browser no-op export is byte-preserving while encrypted
  editing remains explicitly unavailable.
- **Falsifiers:** Poppler and PDF.js disagree on a reviewed region after a
  documented coordinate conversion; a deliberate unauthorized mutation does
  not fail; rotation or crop-box transforms leak changes outside the reviewed
  region; qpdf warnings are hidden; or retained artifacts include document
  content rather than bounded hashes and counters.
- **Rollback:** Keep the browser-local impact checks and stop consuming the
  independent report; preserve the rotation fixtures and evidence as history.
  Do not weaken the existing qpdf output gate or delete source/output records
  to obtain a clean result.
- **Owner:** Project owner; the preservation validator owns independent
  comparison policy, native/web adapters own output bytes, and the corpus
  manifest owns fixture provenance.

## D-010: Intent-Driven Editor Modes (Read / Fill / Sign / Edit)

- **Date:** 2026-08-24
- **Status:** Accepted implementation decision
- **Approval source:** User instructed: "build everything you found — first principles, long term
  and doctrines aligned." This authorizes implementation of the mode system, its SwiftUI surface,
  supporting AppModel state, and all associated documentation within this project. It does not
  authorize Git mutations, production deployment, cryptographic-signature claims, or changes to
  provider contracts beyond what the existing adapter already supports.
- **Context:** The current UI has a flat tool surface that requires users to understand the
  editor's internal model (native fields, candidates, overlays) before they can act. The four
  real user intents — read, fill, sign, edit — have different risk profiles, different permission
  requirements, and different visual cues. Surfacing them uniformly creates cognitive noise and
  weakens the bounded-completion promise of D-001 and D-005.
- **Selected path:** Introduce a typed `EditorMode` enum (`.read`, `.fill`, `.sign`, `.edit`)
  as first-class `AppModel` state. Add a mode segmented control to the toolbar. Add an
  intent-inference router on page tap. Add a Fill highlight overlay layer to `PDFKitView`. Add
  a Sign sheet (draw/type/image/saved). Add an Edit palette to the inspector. All new operations
  route through the existing provider.apply chain; no bypass of existing safety gates.
- **First-principles rationale:**
  - Bounded mutation promise (D-001): mode is never auto-mutated from source; always user-driven.
  - Safety gates precede accuracy (D-004): L3 ops (redact apply, flatten) always require explicit confirmation regardless of mode.
  - Commercial wedge (D-005): Fill mode directly expresses the "complete forms without disturbing surrounding content" promise.
  - Provider-neutral contracts (D-006/D-007): EditorMode lives in DocumentModel.swift; no PDFKit types exposed outside the adapter.
  - Local-first invariant: no new network calls; signature storage is app-sandboxed.
- **Rejected alternatives:**
  - Auto-enter Fill mode when fields detected: rejected — assumes intent, may surprise users.
  - Merge Fill and Edit: rejected — different risk profiles; Edit allows irreversible ops that Fill must never trigger accidentally.
  - Separate Sign app target: rejected — unnecessary complexity; sign is a bounded subset of the same document session.
- **Trade-offs:** Mode adds state that must be reset on open. Missed reset or bypass could expose
  Edit affordances in Read mode. Mitigated by reset in open(url:) and independent L3 gate checks.
- **Validation:** Unit tests for mode reset, tab order, fill progress, and L3 gate firing.
  Regression: Form 6 and AcroForm benchmarks must still pass unmodified.
- **Falsifiers:** Mode persists across documents; Read-mode click mutates document; L3 confirmation skippable.
- **Rollback:** Remove EditorMode and mode pill; inspector sidebar and existing field/candidate workflows remain functional.
- **Design document:** docs/intent-mode-design.md
- **Owner:** Project owner; implementation agent maintains evidence and docs.
