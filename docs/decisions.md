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

## D-002 Amendment: PDFBox Passes the External-AcroForm Gate PDFKit Fails

- **Date:** 2026-08-25
- **Status:** Active provider evidence; final provider selection remains open
- **Evidence:** The PDFBox control lane (`benchmark/pdfbox-lane/run.sh`) passed
  all four oracle booleans on the public AcroForm sample that PDFKit fails
  (F-016): no-op reopen, widget-state equivalence (radio export values
  `email|phone` preserved with zero per-field diffs across all six fields),
  mutated text retention, and source-unchanged. The `pdfbox-app-3.0.8` fat jar
  SHA-512 was verified against the published digest. The native-widget fixture
  without an AcroForm dictionary correctly reports zero fields (negative
  control).
- **Decision impact:** The radio-choice loss is PDFKit-specific, not systemic.
  PDFBox becomes the leading form-aware provider lane for documents PDFKit
  cannot safely edit. PDFKit remains acceptable for AcroForm-free documents
  behind the structural catalog guard. JVM packaging, raster/visual parity,
  and the broader corpus remain open gates before any provider adoption.
- **Falsifier/next:** Run the same corpus (rotated, malformed, encrypted,
  signed, large) through the PDFBox lane; add raster comparison; resolve JVM
  packaging and license review before treating PDFBox as the default
  form-aware writer.
- **Owner:** Project owner; the lane maintains machine evidence under
  `benchmark/results/2026-08-25-pdfbox-public-acroform/`.

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
- **Status:** Accepted design direction; native and browser capture/review surfaces, encrypted persistence, profile-vault separation, automatic profile-resolution abstention, revision migration review, and adapter parity implemented. Provider fidelity, device stress, and production UI automation remain active evidence lanes.
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
- **Validation:** `node Tests/web_template_match_benchmark_test.mjs` passes 24
  reviewer-labeled cases across exact, known variant, family, ambiguous, stale,
  and seven no-match negatives. The class calibration separates five structured
  classes with thresholds from `0.7772` through `0.8624`; scanned documents have
  exact and known-variant coverage but family acceptance is disabled because no
  family-positive evidence exists. A weakened threshold and zero ambiguity margin
  fail the benchmark on hard negatives and ambiguous cases. The browser fixture
  exposes the same class-policy resolver for live PDF.js fingerprints.
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

## D-017: Keep Class Calibration Review-Only Until Recurring Versions Are Real

- **Date:** 2026-08-24
- **Status:** Accepted calibration artifact; not a production matching default
- **Context:** A single global family threshold hides meaningful differences
  between AcroForms, static printed forms, widgets, rotated pages, and scans.
  Conversely, a class threshold derived from controlled examples can create a
  false impression of production accuracy if the examples are not genuinely
  recurring source versions.
- **Selected path:** Maintain a value-free reviewer-labeled corpus with explicit
  document classes, exact and known-variant precedence, stale refusal, family
  positives, ambiguous candidates, and hard negatives. Derive a threshold per
  class only when positive and negative scores are separable. Disable family
  acceptance for classes without positive evidence. Keep every family result as
  a reviewed proposal and preserve the corpus, score components, labels, and
  mutation failures as durable evidence.
- **Alternatives considered:** Use one global threshold, rejected because it
  hides class-specific false positives; enable family matching for scans from
  negative-only evidence, rejected because recall is unmeasured; use an opaque
  embedding score, rejected because reviewer explanations and mutation gates
  would be weaker.
- **Trade-offs:** Class policies add calibration and fixture maintenance, but
  they make abstention explicit and allow the product to be conservative for
  OCR-only or under-represented classes. Controlled perturbations provide
  repeatable safety evidence but do not establish real-world recall.
- **Validation:** The 24-case benchmark and calibrated class-policy replay pass;
  setting all class thresholds to zero and removing ambiguity margins fails on
  hard negatives and ambiguous cases. See
  [`docs/audits/recurring-template-class-calibration-evidence-2026-08-24.md`](audits/recurring-template-class-calibration-evidence-2026-08-24.md).
- **Falsifiers:** A held-out recurring version falls below its class threshold,
  a hard negative exceeds it, reviewer agreement is low, PDFKit and PDF.js
  fingerprints diverge semantically, or a weakened-policy mutation stops
  failing.
- **Rollback:** Remove the class-policy consumer and retain exact, known-variant,
  stale, and manual completion behavior. Keep the corpus and negative evidence.
- **Owner:** Project owner; corpus review owns labels, shared matching owns
  state and abstention semantics, and native/web adapters own fingerprint parity.

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

## D-018: Require Native and Browser Semantic Parity for Reviewed Template Decisions

- **Date:** 2026-08-24
- **Status:** Accepted bounded conformance gate; live PDF-derived fingerprint parity remains open
- **Context:** The reviewed template benchmark already had class-aware policies,
  hard negatives, ambiguity cases, and stale-source refusal in the browser lane.
  A browser-only pass could still hide a divergence in a future native adapter,
  especially around abstention and evidence components. The native and browser
  lanes therefore need to consume one canonical corpus and compare decision
  semantics before recurring completion behavior is promoted.
- **Selected path:** Add a Swift `PDFTemplateParityHarness` over
  `PDFEditorCore/TemplateBenchmarkContracts.swift`. Generate one value-free
  corpus from the reviewed fixture ledger, run the native Swift matcher, run the
  browser matcher in isolated Chrome, and compare state, selection, abstention,
  false-positive gates, score, candidate identity/state/reason/components, and
  class policy. Preserve the native run, corpus, and semantic parity report as
  dated artifacts.
- **Alternatives considered:** Compare only selected template IDs, rejected
  because a matching selection can conceal evidence or policy drift; compare
  serialized JSON byte-for-byte, rejected because object key order and omitted
  optional nulls are representation details; derive separate fixture corpora,
  rejected because disagreement about input is not adapter parity; use live
  PDFKit/PDF.js extraction as the first gate, deferred because provider extraction
  drift would mix source acquisition and matcher conformance in one failure.
- **Trade-offs:** A duplicated Swift and browser matcher implementation creates
  an opportunity for algorithm drift, but that drift is exactly what this gate
  is intended to expose. The value-free canonical corpus protects privacy and
  makes failures deterministic, while leaving live fingerprint extraction as a
  deliberately separate adapter gate.
- **Validation:** `node Tests/template_match_native_browser_parity_test.mjs`
  passed all 24 cases with zero semantic mismatches and zero evidence
  mismatches. Both lanes reported exact 2, knownVariant 2, familyMatch 6,
  ambiguous 6, stale 1, and noMatch 7. Both selected 10 cases and abstained on
  14. The first run exposed omitted native null selection identities and raw
  policy key-order comparison; both were corrected in the harness and the
  rerun passed. See
  [`docs/audits/template-native-browser-semantic-parity-evidence-2026-08-24.md`](audits/template-native-browser-semantic-parity-evidence-2026-08-24.md).
- **Falsifiers:** Native and browser state or abstention diverges on a reviewed
  case; candidate evidence differs while the selected state remains equal; a
  hard-negative mutation selects a template; or live PDF-derived fingerprints
  cannot be reconciled without suppressing product-relevant evidence.
- **Rollback:** Keep browser class calibration review-only, remove the native
  parity consumer if it proves too noisy, and retain the corpus and failure
  history. Do not promote family matching or silently weaken abstention to make
  the report pass.
- **Owner:** Project owner; shared matching owns state semantics, native and web
  adapters own independent extraction, and corpus review owns labels and
  false-positive adjudication.

## D-019: Measure Reviewed Corrections as Source-Bound Coverage Lift

- **Date:** 2026-08-24
- **Status:** Accepted controlled measurement; automatic learning remains disabled
- **Context:** A pending learning event and strict promotion gate proved that
  unsafe corrections could be blocked, but the project had not measured whether
  a reviewed correction created useful recurring completion coverage. A benefit
  metric must not require storing profile values or accepting hard negatives.
- **Selected path:** Measure `reviewedTargetCoverage`, the count of reviewed
  mappings surfaced in a completion proposal without resolving profile values.
  Use five controlled structured recurring variants whose baseline state is
  `noMatch`, promote each through an explicit same-family correction and strict
  validated/reopenable source-bound checks, then compare promoted and rollback
  states. Replay all seven hard-negative fixtures against every promoted child.
- **Alternatives considered:** Measure filled values, rejected because values
  are sensitive and correctness would be synthetic; measure only match state,
  rejected because a selected template can still expose zero usable reviewed
  targets; learn from every completion automatically, rejected because one-off
  user behavior must remain pending evidence; delete the child on rollback,
  rejected because immutable history and auditability are required.
- **Trade-offs:** The coverage metric is privacy-preserving and deterministic,
  but it is only a workflow proxy. It cannot establish user-time benefit,
  value correctness, or real-world recall. Exact source admission improves
  reviewed recurrence coverage while deliberately refusing broad family
  generalization.
- **Validation:** `node Tests/web_template_correction_benchmark_test.mjs`
  passed five scenarios with coverage lift 0 to 5, rollback to zero, 35/35
  hard-negative abstentions, zero profile values, and no source bytes or raw
  labels. `node Tests/web_template_correction_benchmark_browser_test.mjs`
  passed the same result in isolated Chrome with zero console and page errors.
  The first run exposed an over-broad privacy sentinel that confused a keyed
  token with raw content; narrowing the sentinel produced the passing rerun.
- **Falsifiers:** A promoted correction does not increase reviewed target
  coverage; rollback cannot restore the parent behavior; a hard negative is
  selected; raw content enters correction records or diagnostics; or held-out
  recurring versions show poor reviewer acceptance or value correctness.
- **Rollback:** Keep correction events pending, revoke or stop selecting the
  child revision, and retain the parent and child history. Do not promote the
  coverage result into automatic profile resolution or batch acceptance.
- **Owner:** Project owner; template runtime owns promotion and rollback
  invariants, corpus review owns same-family decisions, and native/web adapters
  own future held-out extraction and completion evidence.

## D-020: Version ihatepdf-Inspired Capabilities as Evidence-Ledger Experiments

- **Date:** 2026-08-24
- **Status:** Accepted and implemented as contract evidence; capability execution
  remains planned per entry
- **Context:** The ihatepdf.cv exploration identified six useful product
  patterns, but a feature list alone could turn unverified competitor claims
  into premature implementation or parity assumptions. The project needs a
  durable admission point for corpus work across native and web providers.
- **Selected path:** Add one canonical JSON ledger with six versioned entries:
  text-run replacement preservation, OCR layer alignment, privacy preflight and
  sanitization, repair and recovery, device-adaptive browser limits, and
  compare/operation impact maps. Link each entry to one semantic parity case,
  source fixture, coordinate policy, review and abstention policy, validation
  kinds, hard negatives, falsifier, and rollback path. Project the same ledger
  independently through Swift and browser adapters and compare semantic records
  rather than bytes or key order.
- **Alternatives considered:** Keep the six ideas only in prose, rejected
  because they would have no stable input or falsifier; implement each feature
  immediately, rejected because provider, licensing, privacy, and independent
  validation gates are not yet cleared; use one shared JavaScript projector for
  both lanes, rejected because it would not detect native/browser semantic drift.
- **Trade-offs:** The ledger adds a small contract surface before visible feature
  breadth, but it keeps the long-term capability program explainable,
  source-bound, reversible, and provider-neutral. The parity harness proves
  agreement about intent and safety policy, not capability fidelity.
- **Validation:** `swift build --product PDFExperimentParityHarness` passed.
  `node Tests/ihatepdf_experiment_parity_test.mjs` passed six cases with zero
  semantic mismatches, four of four deliberate ledger mutations rejected, and
  zero isolated-Chrome console or page errors. See
  [`docs/audits/ihatepdf-experiment-ledger-parity-evidence-2026-08-24.md`](audits/ihatepdf-experiment-ledger-parity-evidence-2026-08-24.md).
- **Falsifiers:** Native and browser projections diverge; a required ledger
  invariant can be removed without rejection; the referenced corpus cannot
  support the stated experiment oracle; or the six experiments add no measured
  completion, preservation, privacy, or recovery value after execution.
- **Rollback:** Remove the parity consumer and disable an experiment entry while
  retaining the ledger, source fixtures, prior reports, and shared contracts.
  Do not delete source artifacts or silently promote a planned entry to a
  supported feature.
- **Owner:** Project owner; experiment contracts own schema, native/web adapters
  own projections, and each future capability lane owns execution evidence.

## D-021: Make Cross-Project Evidence and Corpus Parity an Admission Gate

- **Date:** 2026-08-24
- **Status:** Accepted and implemented as a long-term evidence boundary
- **Context:** Local SignKit, MetaExtract, Invoice Intelligence, PhotoSearch,
  extracted_forms, and historical web work contain potentially valuable OCR,
  parser, signature, provenance, and review patterns. Copying code or treating
  prior project claims as proof would create unclear ownership, privacy,
  licensing, and fidelity boundaries. The PDF editor also needs one durable
  native/web fixture before new providers are admitted.
- **Selected path:** Maintain a canonical six-entry cross-project JSON ledger
  with source paths and hashes, truth and license/provenance status, inputs and
  outputs, coordinate space, privacy class, transferable primitives, explicit
  non-imports, falsifier, and rollback. Maintain a separate eleven-case PDF
  corpus parity fixture that compares source identity, geometry, fields,
  candidates, operation intent, validation, security, and accessibility across
  the Swift native and browser adapters. Compare semantic records, not PDF
  bytes, and record provider or detector differences rather than normalizing
  them away.
- **Alternatives considered:** Import adjacent OCR or parser modules directly,
  rejected because runtime ownership, dependencies, privacy, and licensing are
  not yet cleared; keep the inventory in prose only, rejected because source
  drift and missing falsifiers would be hard to audit; require byte-identical
  native and browser PDFs, rejected because provider serialization is not the
  shared product contract.
- **Trade-offs:** The ledger adds provenance maintenance and the parity gate
  permits known candidate mismatches to remain open. This is intentional. It
  preserves long-term first-principles traceability while allowing browser and
  native engines to evolve behind a common semantic model.
- **Validation:** `node Tests/cross_project_evidence_ledger_parity_test.mjs`
  built the native harness and passed with 6 ledger entries, 18 source
  references, 11 corpus cases, 4 explicitly allowed candidate mismatches, and
  0 unexpected mismatches. Native and browser both produced the expected
  inspection failure for the truncated fixture. The combined report records
  one existing manifest/live-artifact digest drift without rewriting either
  source.
- **Falsifiers:** An unreviewed source is silently treated as production
  evidence; a source path or digest cannot be reproduced; native and browser
  disagree on a required semantic field outside the declared mismatch policy;
  the malformed or security cases diverge; or the ledger allows a capability
  without a falsifier and rollback path.
- **Rollback:** Disable the combined ledger consumer or a ledger entry while
  retaining prior reports and source references. Do not delete adjacent
  projects, rewrite the corpus to remove drift, or promote a static evidence
  entry into a runtime dependency.
- **Owner:** Project owner; this repository owns synthesis, contract policy,
  and parity reports. Adjacent projects retain ownership of their source and
  claims. Native and browser adapters own provider execution evidence.

## D-022: Expand the Browser Corpus Before Expanding Provider Claims

- **Date:** 2026-08-25
- **Status:** Accepted and implemented as a long-term fidelity boundary
- **Context:** The existing browser proof covered ordinary forms, OCR input,
  rotation, encryption, malformed truncation, and repeated pages, but did not
  exercise those risks in a single hybrid corpus with independent reopen and
  preservation evidence. Treating the current reader proof as general PDF
  support would hide parser, coordinate, resource, and failure-state gaps.
- **Selected path:** Maintain six reproducible local derived fixtures for
  hybrid text/raster/form content, degraded scans, rotated hybrid pages,
  AES-256 encrypted hybrid content, intentional malformed truncation, and a
  40-page hybrid stress input. Run the declared browser contract, native/web
  parity, independent-viewer, qpdf, and outside-region preservation gates.
  Record expected malformed rejection as a successful safety outcome, not as a
  viewer reopen pass.
- **Alternatives considered:** Claim broad browser fidelity from the ordinary
  corpus, rejected because it would conflate coverage with support; use only
  synthetic in-memory objects, rejected because source bytes, passwords, and
  provider recovery behavior are part of the risk; normalize all provider
  differences away, rejected because the encrypted geometry and Form 6
  candidate differences are useful evidence.
- **Trade-offs:** Derived fixtures are reproducible and privacy-minimizing but
  cannot represent every real-world PDF producer. The 40-page fixture tests a
  bounded resource shape but not production memory or latency ceilings. The
  encrypted fixture proves password open and no-op preservation, not encrypted
  editing or unsupported-encryption behavior.
- **Validation:** The browser contract gate passed 17 cases with zero console
  or page errors. Native/browser parity passed with six classified mismatches
  and zero unexpected mismatches. Poppler/MuPDF independently reopened 53
  eligible PDFs. qpdf output checks passed 55 generated PDFs with six known
  recoverable warnings and zero hard failures. The preservation validator
  rejected unauthorized text/raster mutations and accepted authorized
  source-bound mutations.
- **Falsifiers:** A new valid fixture fails independent reopen unexpectedly;
  a malformed fixture mutates or publishes output; an encrypted edit bypasses
  the pre-export guard; a coordinate or source-digest mismatch is silently
  accepted; or any undeclared parity mismatch appears.
- **Rollback:** Remove only the derived fixture generation and its manifest
  rows while retaining the historical reports and source fixtures. Do not
  rewrite source PDFs, erase mismatch records, or downgrade a failed safety
  outcome into an unsupported omission.
- **Owner:** Project owner; corpus generation owns provenance, native/browser
  adapters own execution evidence, and independent validators own reopen and
  preservation claims.

## D-023: Negotiate Local Providers Through an Independent Admission Plane

- **Date:** 2026-08-25
- **Status:** Accepted as the long-term provider architecture; contract slice
  implemented, runtime plane remains gated
- **Context:** OCR and high-fidelity PDF engines will eventually need to be
  installed locally, measured against the corpus, replaced, quarantined, and
  revoked. Treating an executable, package name, or provider version as
  support would allow unmeasured or legally unresolved engines to mutate PDFs.
  Adding engine-specific fields to the shared PDF contracts would make every
  provider change a document-contract migration.
- **Selected path:** Add a separate `pdf-editor.provider-capability` and
  `pdf-editor.provider-capability-registry` admission plane. Keep installation,
  runtime health, exact artifact identity, license state, capability state,
  measurement records, source limits, negotiation decisions, and revocations
  explicit. Native, browser, and companion adapters continue to emit the
  existing document, coordinate, candidate, edit-session, and validation
  contracts.
- **Alternatives considered:** Route to the first installed engine, rejected
  because installation is not evidence; select one universal PDF engine,
  rejected because native/browser deployment and licensing differ; put
  capability status into `pdf-editor.document`, rejected because provider
  admission is lifecycle metadata and would amplify contract changes; use an
  arbitrary companion command endpoint, rejected because it creates an
  unbounded execution and path-injection boundary.
- **Trade-offs:** The registry adds a small admission model and measurement
  maintenance burden, but it makes provider replacement, rollback, and
  revocation explainable. It also means an installed engine may remain visibly
  unavailable until its capability-specific evidence and license review close.
- **Validation:** Browser registry and negotiation test passed 12 checks.
  Native Swift provider capability tests passed 7 tests for shared-fixture
  decode, round-trip, exact artifact binding, duplicate rejection, measured
  selection, unmeasured abstention, and duplicate-ID fail-closed behavior. The
  fixture records browser reader enabled, Vision OCR partial, PDFBox unmeasured,
  and MuPDF quarantined states.
- **Falsifiers:** A default request can select an unmeasured, unlicensed,
  revoked, quarantined, or source-incompatible provider; a measurement is not
  bound to the exact artifact digest; the native and browser negotiators differ
  on a required decision; or a companion request can invoke an arbitrary local
  command.
- **Rollback:** Disable provider admission and retain the browser/native
  baseline adapters. Remove only a provider manifest or capability measurement,
  not source PDFs, operation logs, validation reports, or historical outputs.
  Revoke a capability before uninstalling its provider.
- **Owner:** Project owner; the admission registry owns routing policy, each
  adapter owns execution evidence, the measurement runner owns benchmark
  provenance, and the companion host owns process isolation and bridge safety.

## D-024: Build Every Long-Term Capability Lane; Gate Activation and Claims

- **Date:** 2026-08-25
- **Status:** Accepted implementation doctrine
- **Context:** Earlier deployment notes used browser-only first-release language
  to describe rollout sequencing. That language was being misread as a product
  scope decision, even though the long-term program includes OCR, high-fidelity
  editing, companion providers, batch, large-document, security,
  accessibility, templates, and recovery across native and web surfaces.
- **Selected path:** Continue implementing every long-term capability lane
  behind shared contracts, provider adapters, fixtures, benchmarks, failure
  states, privacy controls, and rollback paths. Use the provider registry and
  release gates to decide when a capability is enabled or claimed for a
  document class. Keep the browser core functional without an installed
  companion, but treat companion absence as a runtime availability state, not
  as a reason to omit the companion implementation.
- **Alternatives considered:** Stop companion and OCR work until the browser
  wedge is proven, rejected because it turns a rollout gate into a permanent
  scope reduction; enable every installed engine immediately, rejected because
  installation is not measurement, licensing, security, or fidelity evidence;
  force one engine across native and web, rejected because it weakens
  replaceability and ignores platform runtime differences.
- **Invariants:** “Not implemented,” “installed but unmeasured,” “measured
  partial,” “abstained,” “revoked,” and “unsupported for this source” remain
  distinct states. No gate may be closed by deleting the evidence needed to
  pass it. No provider may change the shared PDF contracts merely to expose
  engine-specific behavior.
- **Validation:** The browser and native companion handshake contracts now
  round-trip the same fixture, bind requests to source digests and session
  nonces, require typed limits, support cancellation, and reject invalid
  input modes before provider execution. See
  `docs/audits/provider-capability-system-evidence-2026-08-25.md`.
- **Falsifiers:** A capability cannot be implemented without weakening source
  binding or privacy; the typed bridge cannot isolate commands and paths; the
  native and browser contracts cannot express the same abstention or
  validation semantics; or the full lane program creates unrecoverable data
  loss or licensing exposure. If any occurs, split or redesign that lane while
  retaining the long-term capability objective.
- **Rollback:** Disable only the affected capability or provider admission,
  preserve source PDFs, operation logs, validation reports, fixtures, and
  prior adapters, and record the failed gate. Do not rewrite historical
  evidence into a narrower product claim.
- **Owner:** Project owner; each capability lane owns its implementation and
  evidence, the shared contract owns semantic parity, and provider admission
  owns activation, revocation, and recovery.

## D-025: Use One Normalized Native/Web Parity Comparator Before Provider Expansion

- **Date:** 2026-08-25
- **Status:** Accepted and implemented
- **Context:** Native PDFKit and browser PDF.js/pdf-lib emit different provider
  metadata, identifiers, diagnostics, and byte layouts. The project needed a
  comparison that protected shared product semantics before OCR or an installed
  companion could add another source of provider variation.
- **Selected path:** Keep the native and browser serialized bundles intact,
  project both through `web/pdf-contract-parity.mjs`, and compare source
  identity, page geometry and rotation, field semantics, candidate evidence
  families, page-space coordinates, operation lineage, validation states, and
  metadata summaries. Ignore only explicitly listed representation noise.
  Preserve all provider and detector mismatches for fixture-level
  classification rather than normalizing them away.
- **Alternatives considered:** Compare PDF bytes, rejected because provider
  serialization differs; compare raw JSON, rejected because timestamps,
  provider IDs, and diagnostic prose create false divergence; force the current
  corpus to zero mismatches, rejected because it would erase candidate and
  coordinate evidence; add OCR or a companion first, rejected because a new
  provider would make the existing parity boundary harder to diagnose.
- **Validation:** The current seventeen-entry corpus run produced 6 classified
  mismatches and 0 unexpected mismatches. The focused mutation harness passed
  8 checks and detected source-digest, page-coordinate, field-kind,
  candidate-evidence, and validation-state mutations while ignoring provider
  metadata and diagnostic prose changes.
- **Falsifiers:** A semantic mutation is not detected; a representation-only
  mutation changes the semantic result; a native/browser bundle omits a
  required field from the projection; or a new provider changes parity status
  without a declared fixture-level mismatch policy.
- **Rollback:** Keep the raw native/browser bundles and reports, disable only
  the normalized comparator consumer, and preserve the mutation cases. Do not
  rewrite the corpus or broaden ignored fields to make a new provider pass.
- **Owner:** Shared parity harness owns normalization and mismatch policy;
  native and browser adapters own their serialized bundles; each provider
  expansion must pass this comparison before its evidence is promoted.

## D-026: No Permanent Product Scope Exclusions From Evidence Gates

- **Date:** 2026-08-25
- **Status:** Accepted correction to the project doctrine
- **Context:** The phrase “outside the first unrestricted promise” and related
  browser-only wording incorrectly framed arbitrary reflow, visual-to-native
  field creation, universal OCR, permanent redaction, cryptographic signatures,
  XFA, collaboration, hosted processing, and companion execution as if they
  were product exclusions. The project owner explicitly requires everything to
  be explored, implemented, measured, and documented long term.
- **Selected path:** Keep the full capability frontier as the product target.
  Sequence implementation by dependency and risk, but represent incomplete
  work through typed capability states and provider-specific gates. A claim may
  be withheld while its implementation proceeds. A runtime may abstain while
  its provider, fixtures, benchmark, recovery path, and UI explanation are
  built.
- **Alternatives considered:** Define a narrow bounded product and stop at
  overlays, rejected because it imposes an unauthorized product boundary;
  claim every listed capability immediately, rejected because evidence and
  safety would become dishonest; collapse all lanes into one engine, rejected
  because native, web, companion, hosted, and independent-validator runtimes
  have different boundaries.
- **Invariants:** No capability row is a permanent non-goal solely because it
  is deferred, gated, blocked, or unsupported by the current provider. No
  capability may silently mutate source content, claim legal validity, or hide
  uncertainty. Every lane remains linked to a contract, provider path,
  corpus, validator, privacy/security model, and rollback plan.
- **Validation:** The canonical frontier, inventory, capability matrix,
  full-capability program, deployment decision, task plan, and implementation
  status now carry this interpretation. The normalized native/web parity gate
  remains the prerequisite for adding provider evidence, not a reason to
  remove OCR or companion lanes.
- **Falsifiers:** A complete capability cannot be represented without changing
  the shared contracts; evidence states cannot distinguish unavailable from
  unsafe or unmeasured; or the full program cannot preserve source, privacy,
  recovery, and legal boundaries. Such a result requires redesign of that lane,
  not deletion of the capability objective.
- **Rollback:** Revert only the affected adapter or activation decision,
  preserve the capability contract, fixtures, reports, and historical scope
  record, and keep the lane active with a named blocker and next experiment.
- **Owner:** Project owner; the shared contract and evidence program own
  semantic integrity, while each native, web, companion, hosted, and validator
  lane owns execution and recovery evidence.

## D-027: Treat Safe Completion as Reviewed Readiness, Never Silent Autofill

- **Date:** 2026-08-25
- **Status:** Accepted controlled metric decision
- **Context:** The correction benchmark measured reviewed-target coverage lift
  and hard-negative replay, but a single coverage number could be misread as
  completed-field success. The project needs distinct metrics for correction
  benefit, abstention, hard-negative safety, and completion readiness.
- **Selected path:** Add the versioned `pdf-editor.reviewed-completion-metrics`
  contract. Measure reviewed correction lift, ambiguous/stale/no-match
  abstention, hard-negative false-positive rate, source-bound validation,
  explicit mapping/value review guards, rollback restoration, and silent
  autofill count. A safe-completion result means a reviewed target is ready for
  explicit value review. It never means a value was silently materialized.
- **Alternatives considered:** Use surfaced-target count as completed fields,
  rejected because it hides value review; optimize aggregate match accuracy,
  rejected because hard-negative harm can disappear inside a mean; measure
  only promoted revisions, rejected because rollback and abstention are safety
  outcomes; store example values for realism, rejected because metrics must stay
  value-free.
- **Invariants:** One hard-negative selection fails the metric. One ambiguous or
  stale selection fails the metric. Any materialization without explicit
  mapping and value review fails the metric. Source digest, source unchanged,
  and output reopenability are required for safe-completion readiness. Reports
  contain counters and states, not content.
- **Validation:** Node and isolated Chrome both pass the controlled benchmark:
  5/5 reviewed corrections improve coverage, 14/14 abstention cases abstain,
  0/7 hard negatives select, 35/35 promoted hard-negative replays abstain,
  5/5 cases pass source-bound safe-completion guards, and silent autofill is 0.
  The mutation suite passes five bypass-killing checks. The native Swift core
  decodes the browser artifact's nested metrics payload and passes two focused
  contract tests, including rejection of a selected hard negative. This proves
  serialized contract consumption and invariant rejection, not native/browser
  aggregation equivalence.
- **Falsifiers:** Held-out reviewed recurring documents show no coverage lift;
  reviewer acceptance or value correctness declines; a provider selects a hard
  negative; a stale or ambiguous case is selected; or a completion export can
  proceed without explicit value review.
- **Rollback:** Keep the metric contract and evidence reports, revoke or stop
  selecting the affected correction child revisions, and disable only the
  metric-dependent activation path. Do not weaken denominators or delete
  negative cases to restore a passing aggregate.
- **Owner:** Shared metric contract owns definitions and aggregation; native,
  browser, companion, and hosted adapters own their source-bound evidence.

## D-028: Compare OCR and Companion Providers on the Governed Corpus

- **Date:** 2026-08-25
- **Status:** Accepted measured-partial provider decision; promotion blocked
- **Context:** The provider admission contracts existed, but the project had
  not compared local OCR and optional companion approaches on the same governed
  corpus using accuracy, latency, privacy, licensing, and recovery gates.
- **Selected path:** Measure native Vision and installed Tesseract through the
  same value-free OCR evidence shape. Record OCRmyPDF, PDFBox, and MuPDF as
  explicit uninstalled, unmeasured, or quarantined states until their exact
  runtime, artifact digest, licensing, security, and corpus evidence exists.
  Keep OCR observations as candidate evidence and never as silent field truth.
- **Alternatives considered:** Promote Tesseract from the clean smoke test,
  rejected because it failed the noisy-scan gate; assign OCR accuracy to PDFBox,
  rejected because PDFBox is a document-structure provider rather than an OCR
  engine; treat MuPDF availability as adoption, rejected because AGPL/commercial
  licensing and provider measurement are separate gates; score unavailable
  companions as zero, rejected because non-measurement is not a performance
  result.
- **Invariants:** Reports contain counters, confidence aggregates, digests,
  statuses, and error codes, never OCR text, ground truth, passwords, source
  bytes, screenshots, or profile values. Malformed input must fail without
  output. Encrypted input requires explicit local unlock. Provider failures,
  timeouts, cancellation, and revocation must not publish partial output or
  silently change provider semantics.
- **Validation:** The six-input runner measured Vision at mean anchor recall
  `0.944`, median `92.5 ms`, p95 `391.0 ms`; Tesseract 5.5.0 at mean recall
  `0.778`, median `188.1 ms`, p95 `417.3 ms`. Vision passed the provisional
  class gate; Tesseract failed the noisy scan at `0/3`. Privacy passed,
  malformed/encrypted/large recovery checks passed, the comparison test passed
  17 checks, and companion runtime recovery remains explicitly unmeasured.
- **Falsifiers:** Vision loses its noisy/rotated/encrypted class gates; local
  OCR leaks content or passwords; a provider publishes output after malformed,
  timeout, cancellation, or revocation failure; or a companion does not produce
  measurable corpus improvement after its license and runtime gates pass.
- **Rollback:** Keep the comparison artifact and negative evidence, revoke or
  downgrade only the affected capability state, preserve the shared OCR and
  provider contracts, and route to another measured provider or abstain. Do not
  delete failed fixtures or turn an unmeasured companion into a fallback.
- **Owner:** Provider admission and corpus evidence own the gates; native,
  browser, and companion adapters own execution, recovery, and output
  validation.

## D-029: Cross-Project Exploration Is a Full Implementation Mandate

- **Date:** 2026-08-25
- **Status:** Accepted owner direction and implementation doctrine
- **Context:** The cross-project exploration surfaced transferable capability
  patterns from SignKit, MetaExtract, Invoice Intelligence, PhotoSearch,
  `extracted_forms`, and a historical web detector. Earlier language described
  these as salvageable references and could be read as permission to stop at a
  bounded reader/editor slice. The owner direction is that everything
  transferable must be built for the long-term native and web PDF platform.
- **Selected path:** Rebuild every transferable capability as a PDF Editor-owned
  lane: native-first inspection, geometry and OCR evidence, parser/provider
  routing, normalized schemas and aliases, conflict/provenance reporting,
  reviewed labels and corrections, hard-negative mining, template/profile
  separation, signature adapters, batch and large-document workflows, privacy
  preflight and sanitization, redaction, accessibility, collaboration, hosted
  and explicitly installed companion providers, and independent validation.
  Sequence by dependency and risk, but never turn sequencing into a permanent
  product boundary.
- **Alternatives considered:** Keep adjacent work as research only, rejected
  because it discards the existing local advantage; copy neighboring projects
  directly, rejected because it violates ownership, provenance, privacy, and
  contract discipline; enable every provider immediately, rejected because
  installation is not measurement, licensing, security, or fidelity evidence.
- **Ownership boundary:** PDF Editor owns its shared contracts, adapters,
  evidence graph, corpus, operation history, templates, validation, and user
  experience. SignKit keeps signature extraction and assets; MetaExtract keeps
  its metadata system; Invoice Intelligence keeps invoice semantics;
  PhotoSearch keeps media metadata; packaged artifacts remain quarantined until
  independently verified. No neighboring source, database, private value,
  generated artifact, or Git state becomes an implicit dependency.
- **Invariants:** Every transferable lane has a contract projection, at least
  one native/web/provider path, governed fixtures, provenance and license
  status, privacy/security policy, failure and recovery states, benchmark,
  documentation, and an activation gate. `Deferred`, `Gated`, `Unmeasured`,
  `Quarantined`, `Blocked`, and `Abstained` describe current readiness only.
  Silent mutation, silent autofill, hidden content transfer, unsupported legal
  claims, and evidence deletion remain prohibited safety violations.
- **Validation:** The cross-project ledger and native/web normalized parity
  harness are the baseline for provider projections. The current six-entry,
  eighteen-reference ledger and seventeen-case corpus report retain their
  classified mismatches and source-identity drift. Future lane evidence must
  add to that record rather than replace it with aggregate scores.
- **Falsifiers:** A transferable lane cannot be represented without weakening
  source binding, privacy, recovery, licensing, or semantic parity; or the
  neighboring evidence is found to be misattributed, unlawful, or technically
  incompatible. The response is to redesign, quarantine, or change provider,
  while retaining the capability objective and documenting the blocker.
- **Rollback:** Revoke only the affected provider or activation path. Preserve
  the PDF Editor contract, fixtures, negative cases, reports, and prior adapter;
  record the failed experiment and continue with the next provider or explicit
  abstention state.
- **Owner:** Project owner; PDF Editor capability lanes own their native, web,
  companion, hosted, and validator implementations, while adjacent projects
  remain read-only sources and owners of their non-transferable assets.

## D-030: Make the Compounding Evidence Assets First-Class Implementations

- **Date:** 2026-08-25
- **Status:** Accepted implementation doctrine; registry implemented
- **Context:** The project identified its moat as the evidence and workflow
  assets that compound across replaceable OCR libraries and PDF engines:
  source binding, geometry fixtures, multi-signal evidence, candidate review,
  mappings, hard negatives, operation lineage, provider divergence, independent
  validation, templates, calibration, corpus governance, and workflow recovery.
  These assets must not remain as scattered prose, benchmark side effects, or
  implicit assumptions.
- **Selected path:** Maintain the versioned
  `pdf-editor.moat-asset-registry` as an accountability layer above the shared
  PDF contracts. Every asset has a stable ID, owner, native path, browser path,
  contract references, governed fixtures, validators, retained evidence,
  privacy class, retention policy, and completion gate. The registry is
  validated by executable tests and reports implemented, partial, open,
  blocked, and quarantined states without deleting incomplete work.
- **Alternatives considered:** Keep the moat as narrative documentation,
  rejected because it cannot route implementation or detect missing references;
  make benchmark scores the moat, rejected because scores do not preserve
  provenance, recovery, privacy, or provider replaceability; put evidence
  bookkeeping into the PDF mutation contracts, rejected because registry
  evolution should not change document semantic compatibility.
- **Invariants:** Registry records are zero-content by default. They may contain
  IDs, digests, provider metadata, counters, timings, error codes, and report
  digests, but not page text, OCR values, profile values, passwords, source
  bytes, screenshots, or signature assets. Hard negatives and provider
  divergences are append-only evidence. Reviewed corrections never authorize
  silent autofill or source mutation.
- **Validation:** The registry contains 16 assets and the executable registry
  test resolves every native, web, contract, fixture, validator, and evidence
  reference. Existing source-binding, parity, template, preservation, corpus,
  and completion metrics gates remain the underlying evidence for those assets.
- **Falsifiers:** An asset cannot be represented without exposing content,
  weakening source binding, violating ownership or license boundaries, or
  creating an unreviewable learning path. In that case the asset representation
  or provider adapter must be redesigned, not hidden or removed.
- **Rollback:** Remove or revoke only the affected adapter, evidence consumer,
  or registry status promotion. Preserve the registry schema, asset ID,
  fixtures, negative cases, reports, and historical observations.
- **Owner:** Project owner; the shared-contract, corpus, validator, provider,
  template, and recovery lanes own their asset implementations, while the
  registry owns cross-lane traceability and zero-content governance.

## D-031: Keep Privacy Preflight Observational and Sanitization Source-Bound

- **Date:** 2026-08-25
- **Status:** Accepted implementation decision
- **Context:** PDF metadata, embedded files, actions, external destinations,
  signatures, XFA, rich media, and incremental revisions can carry privacy or
  integrity risk. A report that exposes raw values creates a new data leak, but
  a report that calls a PDF clean without a mutation and independent reopen
  proof creates a false safety claim.
- **Selected path:** Emit a dedicated `pdf-editor.preflight` contract with
  source digest, presence bits, counts, classifications, bounded possible-token
  evidence, reason codes, and explicit sanitization limits. Keep raw values,
  names, URLs, bytes, text, OCR, passwords, pixels, and active-content payloads
  out of the report. Implement sanitization separately as a typed new-copy
  operation with output digest, removed/preserved/unknown inventory, provider
  capability, recovery, and independent validation.
- **Alternatives considered:** Put raw metadata into the shared document
  contract, rejected because preflight reports are often retained or shared;
  make token presence proof of executable content, rejected because bounded
  scans cannot establish reachability; mark the source clean after inspection,
  rejected because inspection does not mutate or neutralize anything.
- **Invariants:** Preflight never executes actions, fetches destinations,
  changes source bytes, removes content, or claims a clean PDF. An expected
  current source digest may be supplied and stale reports must fail. Unknown
  scan/provider states remain visible rather than becoming negative evidence.
- **Validation:** Native PDFKit and browser PDF.js emit the same report shape;
  Node, native Swift, and isolated Chrome tests cover zero-content serialization,
  stale binding, unknown-state handling, false clean claims, and UI aggregate
  rendering. Sanitization, post-sanitize fidelity, signatures, XFA, rich media,
  hidden revisions, and adversarial recovery remain active build gates.
- **Falsifiers:** The report cannot remain value-free, its counts diverge in a
  way that changes user safety decisions, or a sanitizer cannot produce a
  source-bound independently reopened output with an honest removed/preserved/
  unknown inventory. The response is to change the report/provider contract or
  abstain, never to weaken the claim language.
- **Rollback:** Revoke the preflight UI or a provider scan capability while
  retaining the source, contract version, tests, and evidence. A failed
  sanitizer provider is quarantined and cannot change the observational report.
- **Owner:** PDF Editor contract, privacy, sanitizer, and validation lanes.

## D-032: Govern Browser Work With Measured Device and Document Budgets

- **Date:** 2026-08-25
- **Status:** Implemented contract and benchmark; physical-device calibration remains open
- **Context:** Large PDFs, high-DPI pages, OCR, batch work, cancellation, and browser recovery fail through resource exhaustion as often as through PDF semantics. Browser APIs expose incomplete and privacy-variable device signals, while document cost varies by page count, geometry, raster density, rotation, and selectable text. Fixed limits would be either unsafe on constrained devices or unnecessarily slow on capable devices.
- **Selected path:** Emit a versioned browser-resource-policy envelope from the browser adapter and mirror it in the native core. Normalize available device, browser, storage, connection, and document facts; choose bounded render, OCR, batch, and recovery budgets; expose decision states and reason codes; and bind checkpoints to the source digest and operation ID. Use explicit opt-in for OCR and batching, adaptive checkpoint intervals, abort-aware work, and fail-closed partial-output handling.
- **Alternatives considered:** hard-coded page/byte warnings, rejected because they ignore pixel cost and device signals; unrestricted parallelism, rejected because browser memory pressure and tab termination are not recoverable evidence; runtime telemetry containing page text or OCR values, rejected because performance instrumentation must not become a content side channel; a browser-only policy with no native mirror, rejected because native and web sessions need a serialized semantic comparison surface.
- **Invariants:** No unbounded concurrency or byte/page budget; OCR never activates without an explicit request and confirmation boundary; unknown memory signals produce conservative limits and visible unknown evidence; cancellation never promotes partial output; recovery resumes only when source digest and operation ID match; logs contain IDs, counts, states, reason codes, digests, and timings only; source bytes are never mutated by the policy.
- **Validation:** Browser contract checks pass across five device profiles and six document classes, including low-memory, save-data, high-DPI, rotated, scanned, malformed, and 40/120-page stress cases. The benchmark emits 30 value-free rows. Native Swift decodes and validates each serialized policy from that benchmark. Isolated Chrome verifies live fixture emission, source binding, conservative unknown-signal behavior, explicit OCR admission, and zero-content runtime summaries.
- **Falsifiers:** A real device shows an unbounded or unsafe budget, a document class repeatedly exceeds its budget without a recoverable state, checkpoint replay accepts a stale source, cancellation promotes partial output, or privacy review finds content in a policy/event report. The response is to adjust the policy or provider boundary and retain the failing case, not to hide the failure behind a larger limit.
- **Rollback:** Revoke only the adaptive scheduler or a capability-specific budget profile. Preserve the shared document/edit contracts, source bytes, checkpoints, cancellation evidence, and fixed conservative reader path.
- **Owner:** PDF Editor resource governance, native/web adapter, OCR, batch, and recovery lanes. Revisit after physical-device and real companion measurements, browser-version changes, or a new governed stress class.

## D-033: Benchmark Text Replacement and OCR Alignment Before Enabling Either

- **Date:** 2026-08-25
- **Status:** Implemented evidence contract; replacement and OCR promotion remain open
- **Context:** The project needs long-term text-run replacement and OCR-layer
  alignment across native and browser providers. A browser text item, a PDFKit
  selection, and a Vision observation can refer to the same visible content
  while using different segmentation and rectangles. Treating those provider
  objects as interchangeable would make the source-preservation promise
  untestable.
- **Selected path:** Add a shared value-free
  `pdf-editor.text-run-ocr-alignment` projection, run it against the complete
  eighteen-entry fixture execution list, and retain native and browser evidence
  plus page-level comparisons. Keep true `textRunReplacement` explicitly
  review-required and abstained until semantic identity, geometry, outside-region
  text, raster, reopen, and independent-viewer gates pass. Treat absent browser
  OCR as an explicit abstention, never as inferred text or field authority.
- **Alternatives considered:** Use raw provider text and rectangles directly,
  rejected because it leaks content and conflates provider coordinate semantics;
  treat an overlay as replacement, rejected because visual placement does not
  edit the existing text object; use OCR confidence alone, rejected because
  recognition quality does not prove page-space alignment or preservation.
- **Invariants:** Reports bind to the source digest and fixture lineage. Raw
  text, OCR values, replacement values, pixels, passwords, and source bytes are
  never retained. Native and browser may differ in run segmentation and bytes,
  but must expose comparable source, page, coordinate, evidence, review,
  operation, and validation states. Unsupported replacement and missing OCR
  remain visible abstentions.
- **Validation:** Native PDFKit/Vision and browser PDF.js were run on all 18
  current fixtures. Sixteen inspected successfully and two malformed inputs
  failed safely. The report covered 81 pages, 29 pages with comparable text
  evidence, 10 measured OCR/reference pages, and 71 safe OCR abstentions.
  Source binding, zero-content logging, no silent replacement, and abstention
  gates passed. Text geometry at two points and OCR geometry at three points
  failed and are retained as provider-fidelity mismatches in
  `docs/audits/text-run-ocr-alignment-evidence-2026-08-25.md`.
- **Falsifiers:** A future provider claims replacement while it cannot identify
  a stable run, preserve outside-region content, reopen independently, or
  explain its coordinate transform; or an OCR lane emits text without source,
  model, bounds, confidence, and review lineage. The response is quarantine or
  abstention, not a relaxed threshold or hidden mismatch.
- **Rollback:** Revoke the run projection or a provider capability while
  preserving source bytes, hashes, reports, negative cases, and the existing
  overlay/form writer. No report deletion or relabeling is allowed.
- **Owner:** PDF Editor native/web semantic projection, OCR, replacement,
  corpus, and independent-validation lanes.

## D-034: Build the Complete PDF Capability Frontier

- **Date:** 2026-08-25
- **Status:** Accepted long-term product doctrine
- **Context:** Previous competitor notes used words such as “defer,” “reject,”
  “first release,” and “not authorized” while discussing capabilities that are
  part of the requested complete PDF reader/editor. Those words could be read
  as permanent scope exclusions. The product direction is broader: every
  capability a serious PDF reader/editor can, should, or would reasonably
  provide remains a build target.
- **Selected path:** Build the full native, browser, companion, hosted,
  provider, validator, accessibility, security, collaboration, AI, P2P,
  conversion, repair, OCR, redaction, signature, XFA, reflow, page-operation,
  template, batch, and recovery frontier. Sequence by dependency, risk,
  provider fit, privacy, licensing, and evidence. The shared contracts remain
  the stable semantic spine while multiple adapters and independent validators
  supply the capability-specific implementations.
- **Alternatives considered:** Restrict the product to the current PDFKit and
  PDF.js subset, rejected because it converts present provider limitations into
  permanent product limits; copy a competitor's entire feature count without
  independent proof, rejected because feature presence is not fidelity,
  privacy, or recovery evidence; enable every UI action immediately, rejected
  because an unvalidated mutation would violate source preservation and trust.
- **Invariants:** No capability row may be deleted merely because it is
  deferred, gated, blocked, unknown, quarantined, or unsupported by the current
  provider. Those states govern routing and claims for a source class. Every
  lane must eventually have a contract, implementation, provider or provider
  family, corpus, validator, privacy/security boundary, recovery behavior,
  parity projection, and documentation. Safety gates sequence implementation;
  they do not narrow the target.
- **Validation:** `docs/full-capability-build-program.md`,
  `task_plan.md`, `docs/capability-matrix.md`, and the competitor exploration
  now state the full-capability doctrine explicitly. Text-run replacement and
  OCR alignment remain the active implementation lane, with the current
  provider mismatch retained as evidence rather than an omission decision.
- **Falsifiers:** A proposed capability cannot be represented without a safe
  operation model, provider path, recovery path, or truthful claim state. The
  response is to build the missing contract/provider/validator or quarantine
  the runtime path, not to delete the capability from the program.
- **Rollback:** Revoke or roll back only the affected provider, adapter,
  operation, or activation path. Preserve the capability row, source fixtures,
  failed evidence, and migration path so another provider can implement it.
- **Owner:** Project owner and the corresponding native, browser, companion,
  hosted, provider, security, accessibility, collaboration, AI, and validation
  lanes.

## D-035: Normalize Native/Browser Representation Noise, Not Product Semantics

- **Date:** 2026-08-25
- **Status:** Accepted implementation decision
- **Context:** Native PDFKit and browser PDF.js/pdf-lib emit different provider
  identities, generated IDs, timestamps, diagnostic messages, output bytes,
  and output digests. Comparing those fields directly would report false
  product mismatches, while removing all provider differences would hide real
  detector, coordinate, field, operation, or validation drift.
- **Selected path:** Use the versioned `pdf-editor.native-web-semantic-parity`
  normalization policy. Exclude provider IDs/versions/platform labels,
  timestamps, generated IDs, diagnostic prose, validation messages, and output
  digests from semantic equality. Retain their presence and provider identity
  as provenance facts. Require source SHA-256, page-space geometry, fields,
  candidate evidence, operation intent, navigation/accessibility/security
  facts, and validation state to remain comparable. Classify mismatches against
  the reviewed fixture descriptor and fail only on unexpected mismatches.
- **Alternatives considered:** Compare serialized bundles directly, rejected
  because provider metadata and generated output identity are not product
  semantics; compare only page text, rejected because forms, candidates,
  coordinates, operations, and validation are core product contracts; normalize
  all geometry differences, rejected because the encrypted-hybrid precision
  difference is an active fidelity question.
- **Invariants:** Source digest is input identity and cannot be normalized away.
  Output digest is derived-artifact provenance and is never a semantic parity
  signal. Exact projection digest equality is distinct from comparator
  equivalence under declared tolerances. Declared mismatches remain visible and
  append-only. No parity pass upgrades byte identity, text-object preservation,
  raster equivalence, OCR correctness, companion fidelity, or independent-viewer
  agreement.
- **Validation:** The fresh 18-fixture report records 16 readable source
  bindings matching in both lanes, 2 matching malformed failure states, 6
  declared detector/geometry mismatches, and 0 unexpected mismatches. The
  normalization mutation test passes provider, timestamp, nested ID, message,
  and output-digest mutations without creating semantic mismatches.
- **Falsifiers:** A provider-only field changes the normalized projection, a
  source digest is accepted stale, an unexpected mismatch is classified as
  allowed, or a report exposes output-digest values as equality evidence. The
  response is a comparator or schema correction, not a relaxed gate.
- **Rollback:** Revoke the new report artifact or comparator minor version
  while retaining the prior parity report, source bundles, mismatch cases, and
  mutation tests. Do not delete evidence or relabel open mismatches as parity.
- **Owner:** Native/browser contract, corpus, provider, and independent
  validation lanes.

## D-036: Keep Privacy Preflight Read-Only and Compare Its Facts Across Adapters

- **Date:** 2026-08-25
- **Status:** Accepted implementation decision
- **Context:** A privacy preflight report must identify metadata, embedded data,
  annotations, scripts, revisions, and network or security boundaries without
  becoming a sanitizer, executing content, or leaking document values. Native
  PDFKit and browser PDF.js expose different APIs and coverage strengths, so
  their reports need a shared semantic contract and an explicit unknown state.
- **Selected path:** Use `pdf-editor.preflight` 1.1. Emit value-minimized,
  source-digest-bound reports from both adapters. Treat attachments, normalized
  annotation kinds, script indicators, revision markers, and coverage as
  separate typed surfaces. Preserve `unknown` and `partial` rather than
  turning absent provider support into a clean result. Compare privacy facts
  while excluding provider identity, timestamps, generated IDs, and output
  digests from semantic equality.
- **Alternatives considered:** Use one provider's report as authority, rejected
  because it hides adapter gaps; claim clean when no indicators are observed,
  rejected because bounded scans and missing revision parsers are not
  sanitization; store raw metadata, attachment names, or action payloads,
  rejected because the preflight artifact must remain value-minimized.
- **Invariants:** Preflight never executes actions, fetches destinations,
  mutates source bytes, removes data, validates signature cryptography, or
  claims a PDF is clean. Every report is source-bound. Every unknown count is
  derived and validator-checked. A provider mismatch remains append-only
  evidence.
- **Validation:** The 18-fixture native/browser report contains 16 readable
  reports and 2 matching malformed failures. Three metadata keyword-presence
  mismatches remain on `public-sample-form.pdf`; no attachment, annotation,
  script, revision, coverage, source-binding, or raw-content mismatch remains.
- **Falsifiers:** A report includes forbidden content, claims sanitization,
  executes content, accepts stale source identity, silently collapses unknown
  coverage, or the comparator hides a privacy fact. The response is a contract,
  validator, adapter, or provider correction, not weaker comparison.
- **Rollback:** Revoke the report or comparator revision while retaining source
  fixtures, native/browser outputs, mismatches, and mutation evidence. Future
  sanitization and revision-parser lanes must emit new source-bound artifacts.
- **Owner:** Native/web preflight, corpus, provider, security, and independent
  validation lanes.

## D-037: Require Semantic Label Gates and Hard-Negative Calibration for Static Geometry

- **Date:** 2026-08-25
- **Status:** Accepted implementation decision
- **Context:** Vector rectangles, checkbox-shaped paths, underlines, and
  whitespace are common in PDFs but do not inherently represent editable
  fields. A nearest-text heuristic can promote decorative layout into a
  review queue and can associate a label with the wrong shape when provider
  text geometry is approximate.
- **Selected path:** Native PDFKit and browser PDF.js detectors use the shared
  evidence vocabulary and a field-intent label gate. Labeled small squares are
  eligible for checkbox suggestions; isolated or unlabeled shapes abstain.
  Grouped cells, input rectangles, underlines, whitespace, and label
  association are evaluated against reviewed positive and hard-negative cases.
  The calibration report compares page, class, evidence, review state, and
  abstention while ignoring provider-specific candidate IDs.
- **Alternatives considered:** Treat every rectangle or line as a field,
  rejected because it creates unsafe false positives; use only score cutoffs,
  rejected because generic geometry can score highly without field intent; use
  native or browser output as authority, rejected because the product contract
  must survive provider changes.
- **Invariants:** Hard-negative false-positive rate is zero on the controlled
  calibration set. Positive recall is complete on reviewed cases. A candidate
  remains a suggestion requiring review. Source bytes and source digest remain
  immutable. Evidence reports contain case IDs, counts, scores, and states,
  not user document content.
- **Validation:** The two-page synthetic fixture passes 5/5 positive recall,
  0/5 hard-negative false positives, 5/5 hard-negative abstention, and native
  versus browser semantic parity. Native extraction now uses PDFKit selection
  line bounds rather than evenly spaced page-string bands.
- **Calibration report:** The machine report now records overall and per-class
  precision, recall, false-positive rate, abstention, near-target diagnostics,
  and failure clusters. The browser and native runs are 1.00 precision and
  1.00 recall on the controlled set with zero observed clusters. The parity
  runner also kills positive-removal, hard-negative-promotion, and
  required-evidence-stripping mutations.
- **Falsifiers:** A provider promotes a generic or unlabeled hard negative, a
  positive loses recall, a provider mismatch is hidden by ID normalization, or
  a score is presented as calibrated probability without reviewed evidence.
- **Rollback:** Revoke this calibration revision and retain the source,
  labels, reports, and mismatch history. Restore the previous detector only as
  a provider experiment, never by relabeling hard negatives as positives.
- **Owner:** Shared candidate evidence, native/web adapters, corpus, and
  independent validation lanes.

## D-038: Measure OCR Evidence Across Native, Browser WASM, and Companion Controls

- **Date:** 2026-08-25
- **Status:** Accepted implementation decision, promotion blocked
- **Context:** OCR is a provider capability, not a single truth source. Native
  Vision, a local Tesseract process, browser WASM, OCRmyPDF, PDFBox, and MuPDF
  have different runtime, licensing, coordinate, output, and recovery
  boundaries. Availability of an executable or package is not evidence that it
  is safe for recurring form completion.
- **Selected path:** Run native Vision, local Tesseract CLI, and browser
  Tesseract.js through one source-bound, value-free comparison contract. Normalize
  confidence to `[0,1]`, normalize bounds to `normalizedLowerLeft`, retain
  valid-bound counts and union-alignment evidence, and record privacy, license,
  recovery, and companion availability separately. Keep OCR observations as
  reviewed candidate evidence; they never silently create fields or replace
  source content.
- **Measured result:** On six governed inputs, Vision reached mean anchor recall
  `0.944`, CLI Tesseract `0.778`, and browser WASM `0.778`. Vision passed the
  provisional accuracy gate. Both Tesseract lanes failed the noisy-scan case
  at `0/3`. Browser WASM produced no external requests in the local-asset run,
  but p95 recognition was `11,945.9 ms` and its noisy union IoU against Vision
  was `0.083`. Malformed, encrypted, and large-input recovery checks passed at
  the current partial level.
- **Companion state:** OCRmyPDF is unavailable, PDFBox is unavailable without
  a configured JAR, and MuPDF passed only a render control. None has companion
  OCR crash, timeout, cancellation, partial-output, or distribution-license
  evidence in this run.
- **Alternatives considered:** Treat any high confidence as field authority,
  rejected because confidence is provider evidence and noisy cases can be
  confidently wrong. Treat browser WASM as equivalent to native because it is
  local, rejected because accuracy, segmentation, latency, model loading, and
  memory still diverge. Treat installed MuPDF as OCR evidence, rejected because
  the measured capability is rendering control only.
- **Invariants:** Source bytes and digests remain immutable. Reports contain no
  recognized text, screenshots, passwords, or profile values. External network
  behavior is recorded per browser run. Unknown and unmeasured companion states
  remain explicit. A provider failure or partial result cannot publish a field,
  OCR layer, or export.
- **Falsifiers:** Confidence leaves `[0,1]`, coordinate transforms lose page
  orientation, report content leaks, browser assets fetch externally without a
  declared boundary, noisy hard negatives are promoted, or companion runtime
  failures are hidden as success. Correct the adapter or gate; do not weaken
  the comparison.
- **Rollback:** Revoke the provider measurement revision and retain the source
  corpus, artifact digests, reports, divergence cases, and mutation evidence.
  Future preprocessing, language, OCRmyPDF, PDFBox, MuPDF, and companion work
  must publish new source-bound evidence rather than rewriting this result.
- **Owner:** OCR providers, native/web adapters, corpus/provenance, privacy,
  licensing, recovery, and independent validation lanes.

## D-039: Keep Semantic Text-Run Replacement Separate From Visual Overlays

- **Date:** 2026-08-25
- **Status:** Accepted implementation decision, typed slice implemented
- **Context:** The full-capability program requires editing existing PDF text,
  but PDFKit and pdf-lib do not provide evidence that drawing new text over an
  existing run rewrites the original text object. Treating an overlay as text
  replacement would corrupt extraction semantics and make the “surrounding
  text was not touched” promise untestable.
- **Selected path:** Add a dedicated `textRunReplacement` operation bound to a
  source-run ID, original text hash, source digest, page-space bounds,
  coordinate convention, optional font fingerprint, review lineage, and
  reversible state. Keep the replacement value in the active session only;
  recovery metadata records only the typed payload kind and reference.
  Native PDFKit and browser pdf-lib reject the operation until a provider proves
  semantic rewrite and independent preservation evidence.
- **Alternatives considered:** Route through `overlayText`, rejected because
  it leaves original text objects underneath. Accept OCR confidence as proof,
  rejected because OCR is evidence and can diverge on noisy or rotated input.
  Claim same-font visual similarity is semantic preservation, rejected because
  fonts, glyphs, ligatures, RTL, clipping, transparency, and extraction order
  can still change.
- **Invariants:** A replacement target is source-bound and coordinate-bound.
  It cannot be destructive or silently applied. A failed or unknown validation
  state blocks publication. Outside-region text and raster checks, reopen, and
  independent-viewer evidence remain separate from the operation contract.
- **Validation:** Native JSON round-trip and explicit PDFKit rejection pass;
  browser operation construction and pre-export rejection pass. The bounded
  browser simple-run provider now rewrites one unique same-width ASCII literal
  in a classic uncompressed stream and passes qpdf structure, Poppler
  extraction, source/output reopen, and independent outside-region text/raster
  checks. This evidence is restricted to that declared class.
- **Provider boundary:** The bounded writer is not routed for compressed,
  escaped, repeated, Unicode, embedded-font, ligature, RTL, clipping,
  transparency, overlap, incremental-update, signed, XFA, or unknown content
  streams. PDFKit and the general browser writer remain fail-closed for the
  generic operation until those classes have separate evidence.
- **Next gate:** Build the same-font simple-run provider experiment, then add
  embedded-font, Unicode, ligature, RTL, clipping, transparency, overlap,
  table, and abstention fixtures with independent extraction and rendering.
- **Rollback:** Revoke the operation from provider admission while retaining
  its contract, source-run fixtures, failed probes, and mutation evidence. Do
  not relabel an overlay as a replacement to keep a provider green.
- **Owner:** Shared operation contract, native/web writers, text-run corpus,
  OCR alignment, and independent preservation validation lanes.

## D-040: Compare Native and Browser Candidates by Geometry Before Semantics

- **Date:** 2026-08-25
- **Status:** Accepted implementation decision, candidate parity measured with
  provider divergence retained
- **Context:** The whole-document parity comparator exposed Form 6 candidate
  sets as a raw semantic-array mismatch. That made grouping, type assignment,
  rotation, and provider-only suggestions difficult to distinguish. Candidate
  IDs and label prose are provider-specific and privacy-sensitive, while page
  geometry and typed evidence are shared product semantics.
- **Selected path:** Add a dedicated `pdf-editor.native-web-candidate-parity`
  projection. Pair same-page candidates by page-space IoU `>= 0.80`, use one-to-
  one deterministic assignment, then compare kind, suggested field type, entry
  mode, evidence families, review state, grouping, and coordinate space. Report
  native-only and browser-only candidates, directional coverage, agreement F1,
  and matched semantic differences without selecting a provider as authority.
- **Alternatives considered:** Compare raw candidate IDs, rejected because IDs
  are generated by each provider. Compare only counts, rejected because counts
  hide grouping and one-sided regions. Treat the larger candidate set as truth,
  rejected because additional candidates can be false positives. Normalize all
  candidates into one detector taxonomy before comparison, rejected because it
  would erase the provider divergence the project needs to remediate.
- **Invariants:** Source digests remain required for readable fixtures. Labels,
  evidence prose, scores, timestamps, output digests, and provider IDs are not
  serialized in the report. Candidate agreement is not accuracy. Malformed
  fixtures must agree on explicit failure without fabricated candidate output.
- **Validation:** The fresh 18-fixture report records 206 native candidates,
  140 browser candidates, 118 geometry pairs, 49 fully equivalent pairs, 88
  native-only candidates, 22 browser-only candidates, and 6 mismatch clusters.
  Five mutation checks preserve representation invariance and detect semantic
  kind, evidence, and coordinate drift.
- **Falsifiers:** A report leaks candidate content, treats provider agreement as
  reviewed accuracy, hides one-sided candidates, accepts stale source identity,
  or loses rotation/type/grouping mismatches. Correct the projection or corpus,
  not the mismatch policy.
- **Rollback:** Revoke the candidate parity report version while retaining the
  raw native/browser bundles, source digests, mismatch artifacts, and mutation
  evidence. Do not delete or relabel provider-only candidates.
- **Owner:** Native/browser candidate adapters, shared coordinate contract,
  reviewed corpus, detector taxonomy, privacy, and independent validation.

## D-041: Govern Every PDF Session With Explicit Privacy and Export Provenance

- **Date:** 2026-08-25
- **Status:** Accepted implementation decision, native/browser contract and
  corpus evidence implemented
- **Context:** Document preflight can report metadata, embedded data, actions,
  revisions, and sanitization limits, but it cannot explain the data flow of a
  complete editing session. A local reader can still load a remote runtime, run
  OCR, retain source bytes in a draft, or produce an unvalidated export. One
  privacy badge would hide those differences.
- **Selected path:** Add `pdf-editor.session-provenance` 1.0 above document
  preflight. Bind it to the source SHA-256 and session ID. Record processing
  locality, data egress class, OCR use, source retention/deletion, export
  source/output digests, validation/reopen state, operation count, and provider
  IDs. Keep source bytes, text, OCR words, values, filenames, URLs, and pixels
  out of the record. Attach it to native recovery sessions and browser fixture
  snapshots.
- **Alternatives considered:** Treat document preflight as sufficient, rejected
  because it says nothing about the session runtime. Treat local UI as proof of
  local processing, rejected because dependency/runtime, OCR, companion, and
  remote data flows differ. Store raw session events, rejected because they
  create an unnecessary sensitive telemetry channel.
- **Invariants:** Unknown is not local. A successful export requires an output
  digest, validation state, and reopen evidence. A stale source binding, true
  content-inclusion flag, contradictory OCR state, or malformed successful
  export is rejected. Failed open fixtures do not receive fabricated session
  provenance.
- **Validation:** Sixteen readable native and browser fixtures emitted valid
  records. Native reports `local-device`; browser reports `local-browser` with
  no egress under the bundled runtime. Current corpus OCR is explicitly
  `not-used`. Two malformed fixtures have no session record. Swift recovery
  Codable tests, browser unit/live tests, and the full parity run pass.
- **Falsifiers:** Any adapter emits content values, claims no egress while
  sending source bytes, loses source binding, reports OCR as unused after a
  provider ran, or calls an unvalidated output successful. Correct the adapter
  or contract rather than weakening the validator.
- **Rollback:** Revoke the session provenance attachment while retaining the
  source-bound document/edit/preflight contracts and existing recovery files.
  Readers must treat absent provenance as `unknown`, never as `local`.
- **Owner:** Native/browser sessions, OCR providers, companion lifecycle,
  persistence/recovery, privacy, and export validation lanes.

## D-042: Join, But Do Not Collapse, PDF.js and Independent Renderer Evidence

- **Date:** 2026-08-25
- **Status:** Accepted implementation decision, Poppler comparison implemented
  and measured on the current browser export corpus
- **Context:** The project already had a Poppler preservation validator and a
  PDF.js browser validation gate, but the reports were separate. A passing
  independent render could therefore be misread as proof that the browser gate
  passed, while a provider disagreement had no canonical status.
- **Selected path:** Keep PDF.js as the browser inspection and validation
  provider. Keep Poppler as a separately rendered text/raster/reopen control.
  Add a versioned comparison envelope that preserves each result and derives
  only `agree`, `divergence`, `unknown`, or `expectedFailure`. Integrate it into
  the full native/browser parity runner.
- **Alternatives considered:** Replace PDF.js validation with Poppler, rejected
  because Poppler is not the browser runtime and cannot prove browser DOM,
  operation, or PDF.js behavior. Merge Poppler and MuPDF into one optimistic
  score, rejected because provider disagreement must remain visible. Compare
  only output byte digests, rejected because independent preservation is about
  semantic and raster impact, not byte identity.
- **Invariants:** Source digests remain bound. Missing, stale, malformed, or
  unavailable evidence cannot become a pass. A disagreement fails the joined
  report. Expected malformed failures remain explicit and do not contaminate
  readable-fixture measurements. The comparison does not alter the shared PDF
  contracts.
- **Validation:** Focused Node test passes baseline agreement, an intentional
  PDF.js raster divergence, and missing-gate unknown state. The current 18-case
  corpus report has 16 readable passes, 2 expected malformed failures, 16/16
  readable text agreements, 16/16 readable raster agreements, and 0 unexpected
  divergences.
- **Falsifiers:** The comparison hides a provider failure, equates unknown with
  passed, loses rotation/encryption evidence, or claims arbitrary edited-PDF
  fidelity from no-op exports. Correct the report or evidence boundary rather
  than weakening the gate.
- **Rollback:** Revoke the joined report while retaining the detailed Poppler
  preservation report, PDF.js validation bundles, and focused mutation test.
  Existing PDF.js and independent preservation gates remain usable separately.
- **Owner:** Browser export validation, independent renderer adapters, shared
  operation regions, corpus governance, and native/browser parity reporting.

## D-043: Expose Preservation Metrics Without Exposing Document Content

- **Date:** 2026-08-25
- **Status:** Accepted implementation decision, browser review/export surface
  implemented and measured
- **Context:** The browser validator computed outside-region text and raster
  evidence, but the review panel displayed only check messages. That made a
  failed export hard to diagnose and encouraged reviewers to treat a boolean
  status as the whole preservation result.
- **Selected path:** Add optional metrics to the existing validation checks and
  render a dedicated preservation section in the review/export panel. Show
  status, compared/changed pages, changed/compared pixels, ratio, maximum
  channel delta, render scale, channel tolerance, operation count, and basis.
  Keep raw extracted text out of the UI.
- **Alternatives considered:** Display the full source/output text comparison,
  rejected because validation UI would become a content-bearing logging
  surface. Display only a green/red badge, rejected because it hides failure
  magnitude and comparison basis. Create a second validator for the UI,
  rejected because the existing PDF.js impact validator is the canonical
  source of browser evidence.
- **Invariants:** Metrics are optional and backward-compatible. Unknown and
  failed states remain visible. Source-digest equality is labeled as a
  byte-preserving basis, not rendered raster evidence. A failed preservation
  check still withholds the export.
- **Validation:** Source contract checks pass 51/51. Isolated Chrome no-op
  export displays passing metrics. Isolated Chrome static-overlay failure
  displays failed metrics with one changed page and 385/2,317,088 changed and
  compared pixels. Both focused runs have zero console and page errors.
- **Falsifiers:** The UI displays raw document text, hides unknown or failed
  checks, claims pixels were rendered when only digest equality was measured,
  or permits a failed export to download. Correct the rendering boundary and
  preserve the underlying validator.
- **Rollback:** Remove the panel presentation while retaining the optional
  metrics fields and validator evidence. Existing validation behavior and
  export withholding remain unchanged.
- **Owner:** Browser review/export surface, PDF.js impact validator, privacy
  logging boundary, accessibility review, and independent renderer comparison.

## D-044: Preserve Independent Provider Measurements and Operation Binding

- **Date:** 2026-08-25
- **Status:** Accepted implementation decision, normalized report extension
  implemented and focused mutation-tested
- **Context:** The Poppler/PDF.js comparison already joined provider verdicts,
  but the report did not preserve normalized PDF.js metrics and did not pass
  serialized browser edit operations into the independent validator. That was
  sufficient for retained no-op exports but unsafe for future edited exports.
- **Selected path:** Extend the independent comparison envelope with separate
  Poppler and PDF.js normalized metrics, a `comparable`/`notComparable`/
  `notMeasured` measurement state, and an explicit `operationBinding` record.
  Pass `editSession.operations` to Poppler. Treat missing operation lineage or
  coordinate/page mismatch as `unknown`, never as an empty authorization map.
- **Alternatives considered:** Compare only provider statuses, rejected because
  measurement provenance would be lost. Treat an absent operation list as an
  empty region set, rejected because edited content could be misclassified.
  Require exact cross-renderer pixel counts, rejected because independent
  rasterizers legitimately produce different pixel boundaries and tolerances.
- **Invariants:** Provider verdicts remain separate. No-op digest shortcuts are
  not reported as rendered comparisons. The independent validator never runs
  an edited export without source-bound reviewed regions. Provider metric
  differences are retained as evidence and are not silently normalized away.
- **Validation:** Focused independent-viewer test passes baseline agreement,
  divergence, missing-gate, normalized metric comparability, valid operation
  binding, and coordinate-mismatch abstention. The retained corpus report
  remains 16 readable passes, 2 expected malformed failures, and 0 unexpected
  verdict divergences.
- **Falsifiers:** A valid edited export is accepted without serialized regions,
  a coordinate mismatch becomes a pass, or a no-op shortcut is presented as a
  comparable raster measurement.
- **Rollback:** Revert only the report extension and retain D-042's original
  status-level comparison and low-level Poppler evidence. No PDF source or
  shared document contract changes are required.
- **Owner:** Independent renderer adapter, browser export contract, operation
  lineage, and parity-report maintenance.

## D-045: Encrypt Local Template History and Separate Profile Values

- **Date:** 2026-08-25
- **Status:** Accepted implementation decision, native and browser persistence
  implemented and focused-tested
- **Context:** The template design already prohibited source bytes and profile
  values in templates, but durable native and browser storage needed a concrete
  revision, deletion, recovery, and key-boundary implementation. The live web
  profile panel also had a legacy plaintext IndexedDB path that contradicted
  the privacy-first design.
- **Selected path:** Persist the existing native `PDFTemplateRevisionSet` and
  the equivalent browser template-history envelope as authenticated encrypted
  records. Keep a primary and recovery copy. Use separate native template and
  profile directories and Keychain accounts. In the browser, use an encrypted
  IndexedDB store key plus a distinct profile passphrase-derived key. Make
  template save and profile unlock explicit UI actions. Wire the native app
  model to the revision-preserving profile vault through a compatibility
  projection so the UI does not create a second profile contract.
- **Alternatives considered:** Store template JSON in plaintext IndexedDB or
  Application Support, rejected because keyed fingerprints and mappings are
  still sensitive layout metadata. Put profile values inside template
  revisions, rejected because a layout artifact must not become a value vault.
  Silently generate a browser encryption key, rejected because it would give
  poor recovery semantics and make the privacy boundary opaque. Delete only
  the current revision, rejected because old recovery copies would retain
  values and mappings.
- **Invariants:** Source PDF bytes never enter either store. Revision IDs are
  unique and parent-linked. Primary corruption can recover only from an
  authenticated backup and returns a visible recovery state. Wrong keys fail
  closed. Deletion removes primary and recovery files or all related browser
  records. Diagnostics contain no values, PDF bytes, filenames, labels, or
  passphrases.
- **Validation:** Native persistence tests pass 2/2. Browser Node store and
  contract tests pass. Isolated Chrome security and template adapter tests
  pass for profile unlock, wrong passphrase, eviction recovery, deletion,
  zero-content logging, and reviewed capture. The live page no longer uses the
  former plaintext profile database.
- **Falsifiers:** Any raw profile value appears in a persisted envelope, a
  template passphrase opens profile plaintext without the profile key, a
  corrupted primary is returned as healthy, a deleted backup remains
  readable, or page load silently prompts/stores a secret. Any falsifier
  requires disabling the affected persistence path until corrected.
- **Rollback:** Disable the explicit persistence UI while retaining encrypted
  records and recovery backups. Do not re-enable plaintext profile storage.
  Existing in-memory completion and source-bound export remain available.
- **Owner:** Native and browser local persistence adapters, Keychain/IndexedDB
  recovery, template revision contracts, profile vault, and zero-content
  diagnostics.

## D-046: Separate Mapping Approval from Profile-Value Approval

- **Date:** 2026-08-25
- **Status:** Accepted implementation decision, native and browser review
  workflow implemented and mutation-tested
- **Context:** The template runtime already had `mappingReview` and
  `valueReview`, but a profile value could be placed directly into a completion
  proposal and the two statuses did not carry enough provenance to prove that
  the reviewed target and reviewed value were still the same inputs. A changed
  provider target or changed profile value could otherwise leave a stale
  approval-looking state.
- **Selected path:** Keep the two statuses as compatibility projections and
  add explicit `mappingApproval` and `profileValueApproval` records. Mapping
  approval binds mapping ID, resolved target ID, and page-space coordinate.
  Profile-value approval binds profile ID, profile revision ID, semantic key,
  and SHA-256 of the typed value. Both records must validate before the core
  materializer can create an operation. Target resolution invalidates mapping
  approval. Value editing invalidates profile-value approval.
- **Alternatives considered:** Treat a confirmed template mapping as enough
  authorization for all future values, rejected because target correctness and
  value correctness are different user decisions. Store approval only as a
  boolean, rejected because it cannot detect stale profile revisions or direct
  value mutation. Let the UI decide whether to enable Apply, rejected because
  native and browser callers could bypass the surface. Copy profile values into
  templates, rejected by the separate encrypted vault boundary.
- **Invariants:** No `EditOperation` is created by template completion until
  both approvals are valid. The source digest, coordinate page, target binding,
  profile revision, semantic key, and value digest all match the current
  proposal. Approval records are value-bearing only in the in-memory session;
  template persistence remains value-free by default.
- **Validation:** Native Swift tests pass 92 tests in 10 suites. Browser
  contract and isolated Chrome template workflow tests pass. Deliberate stale
  value and target mutations are rejected. The browser review surface exposes
  separate mapping and exact profile-value controls.
- **Falsifiers:** A changed value or target can still materialize with the old
  approval, an old completion proposal without binding records can materialize,
  or any UI route creates operations without the core gate. Disable template
  apply and preserve the source if any falsifier appears.
- **Rollback:** Disable template completion application while keeping the
  encrypted template/profile stores and manual/native field paths. Do not
  reintroduce direct profile-to-operation materialization.
- **Owner:** Shared completion runtime, native SwiftUI review surface, browser
  review surface, encrypted profile vault, and source-bound operation ledger.
## D-047: Compare native and browser structural fingerprints by feature family

- **Date:** 2026-08-25
- **Status:** Accepted implementation decision, fingerprint fixture and
  mutation-tested comparator implemented over the current 18-entry corpus
- **Context:** The existing serialized semantic parity report normalized
  provider IDs, timestamps, output digests, and operation identifiers, while
  the candidate report paired detected regions. Neither artifact gave one
  privacy-minimized structural view of what each provider observed before
  candidate pairing. Aggregate parity therefore risked hiding whether a
  mismatch came from page geometry, text segmentation, widget discovery,
  candidate grouping, evidence composition, or permissions.
- **Selected path:** Emit a versioned structural fingerprint from each retained
  native and browser bundle. Compare page geometry, rotation, text shape,
  fields, candidates, evidence families, coordinate spaces, navigation,
  annotations, permissions, security, and accessibility feature by feature.
  Keep source digest only for identity binding. Exclude raw labels, evidence
  prose, provider IDs, timestamps, output digests, and PDF bytes.
- **Alternatives considered:** Compare whole-bundle JSON, rejected because it
  promotes provider serialization noise to product divergence. Compare only
  candidate pairs, rejected because it cannot explain page, field, permission,
  or extraction differences that occur before pairing. Store raw extracted
  labels in the fixture, rejected because a parity artifact must not become a
  second document-content store.
- **Invariants:** Source digest mismatch is never semantic equality. Malformed
  expected failures remain explicit states. Character-count deltas within the
  established tolerance are representation differences, not semantic failures.
  Permission, coordinate, page-box, field, and candidate-population changes
  remain visible structural divergence. Fingerprint generation never creates
  edit operations or changes source PDF bytes.
- **Validation:** The fixture covers 18 entries. Two expected malformed failure
  states are equal, eight readable cases have semantic divergence only, and
  eight readable cases have mixed semantic and tolerated text differences.
  Permission observability differs on 16 entries, text counts on 8, encrypted
  page-box precision on 1, and static Form 6 candidate families on 2. Focused
  mutations detect rotation, permissions, stale source digest, candidate count,
  coordinate-space, and tolerated text drift.
- **Falsifiers:** A raw label or provider timestamp enters the fixture, a
  source-digest mutation is not reported, a candidate coordinate mutation is
  hidden, or a malformed failure is counted as a readable semantic pass.
  Disable parity promotion and retain the raw provider bundles if any
  falsifier appears.
- **Rollback:** Remove the generated fingerprint fixture/report and comparator
  from release gating while retaining the existing serialized contract parity
  and candidate-pair reports. No shared PDF contract migration is required.
- **Owner:** Native/browser inspection adapters, structural fingerprint
  comparator, candidate detector, coordinate normalization, permission
  reporting, and corpus governance.

Implementation and evidence:

- [`web/pdf-fingerprint-parity.mjs`](../web/pdf-fingerprint-parity.mjs)
- [`benchmark/generate_fingerprint_parity.mjs`](../benchmark/generate_fingerprint_parity.mjs)
- [`Tests/fixtures/pdf_fingerprint_parity_fixture.json`](../Tests/fixtures/pdf_fingerprint_parity_fixture.json)
- [`benchmark/results/semantic-parity/2026-08-25/fingerprint-parity-report.json`](../benchmark/results/semantic-parity/2026-08-25/fingerprint-parity-report.json)
- [`Tests/native_browser_fingerprint_parity_test.mjs`](../Tests/native_browser_fingerprint_parity_test.mjs)
  - [`docs/audits/native-browser-fingerprint-parity-evidence-2026-08-25.md`](audits/native-browser-fingerprint-parity-evidence-2026-08-25.md)

## D-048: RG-002 form-writer direction — incremental custom writer, not PDFKit for external forms

- **Date:** 2026-08-25
- **Status:** Adopted implementation, validated 2026-08-25 (RG-002 moved to
  `PASS`; exploration-grade only for the optional PDFium/PDFBox companion paths)
- **Context:** `RG-001` FAIL proves PDFKit drops external AcroForm radio-choice
  metadata on save (`F-016`). The product invariant is immutable source bytes,
  reversible edits, local-first, no egress, and unchanged-region digest
  invariance (`RG-017`/`RG-018`). The question is "what satisfies the
  source-preserving form-writer invariant without leaving local-first or taking a
  copyleft/commercial dependency," not "which PDF library is best."
- **Selected path:** Build a minimal **form-aware writer as an incremental PDF
  update serializer** (append only changed field `/V`/`/AS`/`/AP` via chained
  `/Prev` xref). Original byte stream is prefix-identical by construction, so
  `RG-017`/`RG-018` hold; edits are reversible by stripping the appended section
  or replaying the `EditOperation` inverse. Render with PDFKit; validate with the
  already-installed qpdf/Poppler. Evaluate **PDFium** (permissive, native dylib +
  web WASM, closes XFA/JS gap) as the fallback engine and **PDFBox** (Apache-2.0
  JVM companion) as the preservation oracle, only after L2 license/supply-chain
  review and after the falsifiable §2 checks in the exploration pass.
- **Alternatives considered:** pdf-lib as external-form writer — rejected
  (rewrites `/AP` with Helvetica on field touch). pdfcpu — rejected (corrupts
  external Adobe forms, Iss #861). Full parse+re-serialize via qpdf/pikepdf —
  rejected (violates source-integrity; already stated insufficient in `RG-002`).
  Poppler/iText/Aspose as shipped writers — rejected (GPL/commercial/AGPL gates).
  MuPDF/itext — deferred (capability-strong, AGPL/commercial until a licensing
  decision).
- **Invariants:** Original byte-prefix digest must match source after every
  edit. Unchanged-object digests must not change. Signatures (`RG-014`) and XFA
  (`RG-015`) remain abstain states. Local-first, no egress, and license-clean
  shipped binary are non-negotiable.
- **Validation:** Smallest safe experiment on `benchmark/results/public-sample-form.pdf`
  — incremental append of one radio value, reopened by Poppler (choice preserved)
  and PDFKit (read-back), with original-prefix + unrelated-object digests
  asserted unchanged (Tier 3 / S3). Falsifier: run the same value set through a
  full-rewrite writer; assert original-prefix digest does NOT match → proves
  `RG-017` violation and falsifies the rejected (b)/(d-non-incremental) paths.
- **Falsifiers:** A chosen radio value is lost on Poppler reopen; the original
  prefix digest changes after an edit; a sibling widget or its `/AP`/font is
  mutated; a new runtime dependency is adopted without L2 license review; a
  shipped binary becomes GPL/AGPL/commercial-encumbered.
- **Rollback:** Discard the incremental appender and revert to PDFKit bounded
  edits for the Form 6 lane only; keep qpdf/Poppler validators. No shared contract
  migration required.
- **Owner:** Form-writer implementation, PDFKit render/review surface, qpdf/Poppler
  validation, `PDFImpactValidator`, corpus governance, license review (L2).

Implementation and evidence:

- [`docs/explorations/provider-custom-oss-exploration-2026-08-25.md`](../docs/explorations/provider-custom-oss-exploration-2026-08-25.md)
- [`benchmark/results/public-sample-form.pdf`](../benchmark/results/public-sample-form.pdf)
- Existing validators: [`benchmark/test_pdfkit_benchmark.sh`](../benchmark/test_pdfkit_benchmark.sh),
  qpdf/Poppler in-environment reopen checks (RG-003/RG-016)

## D-049: Separate local recovery from portable cross-device recovery

- **Date:** 2026-08-25
- **Status:** Accepted implementation decision; browser runtime evidence
  passed; native package-wide execution awaits an unrelated app-target repair
- **Context:** Encrypted template and profile persistence needs product-facing
  backup, import, lost-passphrase, quota, deletion, Keychain, profile unlock,
  worker, and cross-device behavior. A single recovery artifact cannot safely
  serve both same-store recovery and portable transfer because local store
  identities are useful anti-mix-up bindings while cross-device transfer must
  intentionally change the destination identity.
- **Selected path:** Keep two artifacts conceptually separate. An encrypted
  backup contains opaque authenticated records. A recovery envelope contains
  the vault key encrypted with a separate passphrase. A cross-device bundle
  carries both, requires explicit user confirmation, restores the key and
  records, then re-keys the destination browser vault to the recovery
  passphrase. Native Keychain-backed stores use their configured app identity
  and typed store kind checks. Browser ordinary recovery remains IndexedDB-name
  bound; browser cross-device recovery is the only explicit portability path.
- **Worker boundary:** Validate backup shape, record count, and serialized size
  in a module worker without passing a passphrase, CryptoKey, IndexedDB handle,
  PDF bytes, or decrypted payload. The worker result includes an explicit
  `plaintextInspected: false` fact.
- **Invariants:** Source PDF bytes are never persisted by the template/profile
  vault; template and profile stores remain separate; profiles remain locked
  after template recovery; malformed, wrong-kind, stale, or unauthenticated
  artifacts are rejected before replacement; deletion retains only value-free
  audit data; wrong passphrases never silently create an empty store.
- **Alternatives considered:** Bind every recovery envelope to its source
  database, rejected for portable recovery. Make the backup self-decrypting,
  rejected because one leaked file would contain both records and key access.
  Send backup validation through the main UI thread, rejected because it
  widens the plaintext/key handling surface without benefit.
- **Validation:** Browser Chrome proof restored a bundle into a different
  IndexedDB name, passed worker ciphertext validation, recovered encrypted
  template/profile records, preserved profile locking, re-keyed the
  destination, and reopened it. Native core target build passed; native tests
  are present but package-wide execution is blocked by unrelated existing
  AppKit/PDFKit errors in `DiffComparisonView.swift`.
- **Falsifiers:** A portable bundle can be imported without explicit recovery
  confirmation; destination unlock fails after re-key; profile values are
  readable before profile unlock; backup JSON contains plaintext; worker
  receives a decryption key or PDF bytes; wrong-store artifacts replace local
  records; or deletion audit contains values.
- **Rollback:** Disable cross-device UI while retaining same-store encrypted
  backup and recovery. Disable worker acceleration and run the same structural
  validator synchronously. No PDF document or edit-operation contract change
  is required.
- **Owner:** Native/browser persistence adapters, Keychain/profile vault
  integration, recovery UI, worker isolation, corpus privacy governance, and
  release evidence.

Implementation and evidence:

- [`Sources/PDFEditorCore/LocalPersistenceContracts.swift`](../Sources/PDFEditorCore/LocalPersistenceContracts.swift)
- [`Sources/PDFEditorCore/EncryptedTemplatePersistence.swift`](../Sources/PDFEditorCore/EncryptedTemplatePersistence.swift)
- [`web/pdf-template-store.mjs`](../web/pdf-template-store.mjs)
- [`web/pdf-cross-device-recovery.mjs`](../web/pdf-cross-device-recovery.mjs)
- [`web/pdf-vault-worker.mjs`](../web/pdf-vault-worker.mjs)
- [`Tests/PDFEditorCoreTests/EncryptedTemplatePersistenceTests.swift`](../Tests/PDFEditorCoreTests/EncryptedTemplatePersistenceTests.swift)
- [`Tests/web_template_security_browser_test.mjs`](../Tests/web_template_security_browser_test.mjs)
- [`docs/audits/local-persistence-product-surface-evidence-2026-08-25.md`](audits/local-persistence-product-surface-evidence-2026-08-25.md)

## D-050: Promote reviewed detector semantics above provider parity

- **Date:** 2026-08-25
- **Status:** Accepted implementation decision; controlled reviewed fixture
  passes; broader corpus adjudication remains active
- **Context:** The native/browser candidate parity report records provider
  divergence across 18 fixtures, including 78 semantic mismatches across
  document and provider projections. Treating those differences as either
  universal failures or silent equivalence would both be incorrect. The
  detector needs a reviewed-region layer that measures product safety rather
  than provider serialization similarity.
- **Selected path:** Add `pdf-editor.detector-semantic-comparison` version
  1.0. Use stable reviewed region IDs from the governed sidecar, select
  candidates with minimum recognition evidence, then separately compare the
  full expected evidence-family set, label association, grouping, and false-
  positive severity. Compute precision, recall, positive abstention, correct
  hard-negative abstention, and severity burden for each adapter. Compare
  native and browser outputs by reviewed identity, not provider candidate ID.
- **Alternatives considered:** Treat the larger provider candidate set as
  truth, rejected because provider-only candidates may be false positives.
  Use provider candidate parity as accuracy, rejected because agreement is not
  reviewed ground truth. Require full expected evidence for candidate
  admission, rejected because it collapses evidence-family drift into recall
  failure and hides a detected-but-under-explained region.
- **Invariants:** Reviewed IDs are stable and source-bound. Reports contain no
  labels, evidence prose, provider IDs, evidence IDs, scores, timestamps,
  output digests, profile values, or PDF bytes. A hard negative must abstain.
  A candidate must remain review-only and cannot create an edit operation.
  False-positive severity is explicit and weighted. Provider mismatches remain
  diagnostic until they change a reviewed detector outcome or safety property.
- **Validation:** Native PDFKit and browser PDF.js both pass the controlled
  10-region fixture with precision 1.00, recall 1.00, correct abstention 1.00,
  evidence-family agreement 1.00, label association 1.00, grouping agreement
  1.00, severity burden 0, and zero reviewed-region parity mismatches. Five
  independent candidate mutations are killed by reviewed-region,
  false-positive, evidence-family, label-association, and grouping clusters.
- **Falsifiers:** A provider ID becomes the reviewed identity; a hard negative
  is promoted without a severity failure; evidence-family, label, or grouping
  drift is hidden by aggregate precision; raw content enters the report; or a
  broader corpus mismatch changes a reviewed region without being surfaced.
- **Rollback:** Retain the existing calibration and candidate parity reports,
  revoke only the reviewed semantic report gate, and preserve all raw provider
  bundles and mutation evidence. No shared PDF document or edit-operation
  contract migration is needed.
- **Owner:** Static detector adapters, reviewed corpus governance, evidence
  fusion, coordinate normalization, candidate taxonomy, and safety validation.

Implementation and evidence:

- [`web/detector-semantic-comparison.mjs`](../web/detector-semantic-comparison.mjs)
- [`Tests/detector_semantic_comparison_test.mjs`](../Tests/detector_semantic_comparison_test.mjs)
- [`benchmark/results/detector-calibration/detector_calibration_labels.json`](../benchmark/results/detector-calibration/detector_calibration_labels.json)
- [`benchmark/results/detector-calibration/detector-semantic-comparison-report.json`](../benchmark/results/detector-calibration/detector-semantic-comparison-report.json)
- [`docs/audits/detector-semantic-comparison-evidence-2026-08-25.md`](audits/detector-semantic-comparison-evidence-2026-08-25.md)
