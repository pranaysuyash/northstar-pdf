# PDF Editor Implementation Plan

**Status:** Full capability implementation authorized; deployment and provider
activation remain evidence-gated
**Started:** 2026-08-23
**Project root:** `/Users/pranay/Projects/pdf_editor`

## Goal

Build a decision-grade, source-backed local-first PDF platform for native macOS
and web. The implementation must preserve bounded mutation semantics and
evidence while expanding toward the complete reader, forms, OCR, editing,
templates, security, accessibility, and provider capability frontier. Provider-
specific behavior remains behind adapters and every promotion requires evidence.

No PDF reader/editor capability is permanently excluded from this program. The
full target includes ordinary and advanced editing, OCR, reflow, repair,
redaction, sanitization, conversion, signatures, XFA, accessibility,
collaboration, P2P, AI-assisted workflows, hosted/self-hosted processing,
companions, batch work, and recovery. A capability may be staged, provider-
specific, quarantined, or abstained for a source class, but it remains an
implementation target until built, measured, replaced, or explicitly revoked.

## Full capability mandate

Every capability in the research frontier is a long-term implementation target:
reader behavior, forms, static detection, OCR, arbitrary existing-object
editing, paragraph reflow, redaction, sanitization, signatures, XFA,
accessibility, collaboration, hosted processing, local companions, batch,
large-document handling, templates, and recovery. The plan may sequence these
lanes, but it must not convert sequencing into a permanent product boundary.

`Deferred`, `Gated`, `Blocked`, `Unknown`, and `Abstained` describe execution or
evidence state. They do not mean “do not build.” Each lane requires its own
contract projection, provider adapter, corpus, validator, privacy/security
boundary, failure behavior, recovery path, and documentation before it can be
enabled or claimed for a source class.

## Constraints

- Keep this project separate from `fieldcanvas`.
- Research and document before extending provider or product behavior.
- Prefer primary sources: official project documentation, source repositories,
  specifications, and license files.
- Treat detection as probabilistic unless a native PDF form field exists.
- Never promise preservation of unrelated document content without a validation
  strategy that can prove it for the relevant PDF classes.
- Keep dependency additions, packaging, external service use, and production
  deployment separately reviewable. Git mutations remain unauthorized.

## Phases

### Phase 1: Workspace and problem framing

**Status:** complete

- Confirm the canonical project location.
- Establish research records, capability contracts, and evidence boundaries
  without deleting any long-term capability from the build program.
- Capture the platform fork as an open product decision.

### Phase 2: Capability frontier

**Status:** complete with open validation items

Research the relevant PDF primitives and candidate open-source components:

- PDF rendering and text/geometry extraction.
- Native AcroForm and widget inspection/editing.
- Static blank-box and entry-region detection.
- OCR and document-layout analysis.
- Text/object editing and incremental or overlay-based writing.
- Annotations, signatures, redaction, flattening, and save fidelity.
- Desktop, browser, and shared-core packaging options.
- Licensing, security, platform support, and maintenance risk.

The corpus authority is now the privacy/provenance governed manifest in
[`Tests/fixtures/pdf_corpus_governance_manifest.json`](Tests/fixtures/pdf_corpus_governance_manifest.json),
covering scanned, rotated, malformed, encrypted, handwritten-like,
mixed-content, native-form, static-form, and large-document classes. Every
future capability lane must add or reference a governed fixture before its
provider result can become parity or release evidence.

### Phase 3: Comparative evaluation

**Status:** complete

- Build a feature/constraint matrix for candidates.
- Separate adopt, wrap, compose, and custom-build decisions.
- Identify non-combinable options and license boundary risks.
- Define and maintain the governed corpus for all long-term capability lanes,
  including privacy class, source lineage, expected failure state, allowed
  operations, validator set, refresh policy, and independent evidence report.

### Phase 4: Proposed product design

**Status:** proposed and documented; Form 6 benchmark added

- Define the user workflow and explicit confidence/confirmation states.
- Propose the canonical document model and mutation boundaries.
- Define safety invariants for “do not touch other text.”
- Define error, fallback, recovery, audit, and export behavior.
- Record rejected approaches and falsifiers.

### Phase 5: User review gate

**Status:** accepted through user instruction; working defaults recorded in
[`docs/decisions.md`](docs/decisions.md)

- Present the findings, Form 6 benchmark, and 2–3 architecture approaches.
- Resolve platform topology, license tolerance, and provider placement with the
  user while retaining the complete capability frontier.
- User instruction “call subagents and do all” authorized the full research,
  documentation, implementation, and verification program. Product activation
  and claims remain gated by corpus, license, security, and independent-viewer
  evidence; those gates do not remove a capability from the build program.

### Phase 6: First provider evaluation

**Status:** Form 6 and first widget/AcroForm lanes complete; provider comparison pending

- Delegate independent PDFKit, alternative-provider, and reusable-fixture reviews.
- Implement the smallest test-first headless PDFKit harness.
- Run no-op reopen, render, bounded annotation, source-preservation, and external
  Poppler checks.
- Preserve machine results, artifacts, failure history, evidence tier, sensitivity,
  residual risk, and the next corpus requirements.
- Synthetic PDFKit widget annotations passed, but the public AcroForm sample failed
  because radio-choice metadata was lost on no-op save. Preserve the failure rather
  than weakening the gate.

### Phase 7: Native macOS vertical slice

**Status:** native slice present; browser reader/completion proof present; recurring-template design gate active

The cross-platform feature frontier was expanded on 2026-08-24 before bounded
implementation. See [`docs/pdf-feature-frontier.md`](docs/pdf-feature-frontier.md),
[`docs/native-web-platform-matrix.md`](docs/native-web-platform-matrix.md),
[`docs/open-source-landscape.md`](docs/open-source-landscape.md), and
[`docs/browser-pdf-proof.md`](docs/browser-pdf-proof.md). The browser proof now
uses the shared document, coordinate, operation, and validation contracts and
has passed the reviewed public-AcroForm and static Form 6 corpus flow.

The shared operation and coordinate contracts are implemented and documented in
[`docs/shared-contracts.md`](docs/shared-contracts.md). The browser contract
fixture now emits those records for the manifest corpus. The template runtime
now adds review-gated completion proposals, strict learning promotion, encrypted
local record primitives, and immutable reviewed template capture/revision
lineage. The browser capture path and native/web contract round-trip are
implemented. The reviewed matching benchmark now covers exact, known variant,
family, ambiguous, stale, and hard-negative no-match cases with a deliberate
threshold mutation gate. The reviewed corpus now has class-aware calibration,
but real recurring-family versions, hold-out evaluation, reviewer agreement, and
live PDF-derived native/browser fingerprint parity remain open. The next
template unit is native review UI plus store/adapter wiring, not automatic
completion, while provider fidelity and independent outside-region comparison
remain open.

- The provider-neutral core, PDFKit adapter, and native SwiftUI/AppKit shell are
  already present in this workspace and documented in
  [`docs/implementation-status.md`](docs/implementation-status.md).
- Continue native hardening with corpus expansion, independent-viewer checks,
  and provider comparison; do not treat the current PDFKit lane as final.
- Keep the PDFKit public-AcroForm radio-choice failure visible as a product warning
  and provider gate rather than silently accepting degraded semantics.

The bounded web reader/editor proof and contract fixture are implemented and
documented. Its next safe unit is native reviewed template capture UI and
independent fingerprint extraction parity, not silent autofill or a second PDF
provider. See
[`docs/audits/browser-contract-fixture-evidence-2026-08-24.md`](docs/audits/browser-contract-fixture-evidence-2026-08-24.md)
and [`docs/template-system-design.md`](docs/template-system-design.md).

The first native/web serialized parity harness is now implemented and recorded
in [`docs/audits/native-web-contract-parity-evidence-2026-08-24.md`](docs/audits/native-web-contract-parity-evidence-2026-08-24.md).
It compares semantic projections across the eight-entry manifest and preserves
the first mismatch baseline. The next unit is mismatch classification and
contract/provider remediation, not normalization that merely makes the count
smaller.

The reviewed-template native/browser semantic parity harness is now also
implemented and recorded in
[`docs/audits/template-native-browser-semantic-parity-evidence-2026-08-24.md`](docs/audits/template-native-browser-semantic-parity-evidence-2026-08-24.md).
It runs the same 24-case corpus through Swift and isolated Chrome and compares
state, selection, abstention, false-positive gates, scores, candidate evidence,
and class policy. The next parity unit is independent fingerprint extraction
from the same real PDFs, not a claim of live PDFKit/PDF.js equivalence from the
value-free benchmark alone.

### Phase 8: Corpus and alternative providers

**Status:** OCR comparison implemented with partial evidence; companion and
alternative-provider runtime measurement remains open

- Add PDFBox control-lane evaluation and a second independent native/provider lane
  if packaging and license review permit.
- Add static-region detection, OCR fallback, malformed/encrypted/rotated/scanned
  fixtures, structural checks, and independent-viewer checks.
- Record provider choice, license obligations, performance, and residual risks.

The first shared-corpus OCR/provider bake-off is now implemented in
[`benchmark/compare_ocr_providers.mjs`](benchmark/compare_ocr_providers.mjs) and
recorded in [`docs/audits/ocr-provider-comparison-evidence-2026-08-25.md`](docs/audits/ocr-provider-comparison-evidence-2026-08-25.md).
Native Vision passes the controlled class gate and Tesseract fails the noisy
scan gate. OCRmyPDF, PDFBox, and MuPDF remain explicit unmeasured or
quarantined companion states until their exact runtime, licensing, searchable
layer or fidelity, and recovery evidence exists.

### Phase 9: Web deployment decision

**Status:** Accepted long-term deployment architecture; staged capability rollout
remains evidence-gated

- Keep the browser as the zero-install local core. Its bounded operations are a
  safety and evidence boundary, not the long-term product ceiling.
- Build an explicitly installed companion as the long-term provider plane for
  OCR, high-fidelity editing, batch, large-document, and other native runtime
  capabilities, with a typed
  handshake, source-digest binding, security model, license record, and recovery
  path.
- Implement provider adapters and installers behind the admission contracts;
  do not enable or claim MuPDF, OCRmyPDF, Tesseract.js, PDFBox, or a companion
  capability until the relevant provider admission gates are met. Exploration
  and controlled bake-offs remain part of the long-term build program.

### Phase 10: Cross-project document-intelligence exploration

**Status:** implemented ledger and native/web parity gate; all transferable capability lanes are active implementation targets, with provider admission and evidence gates controlling activation

The local OCR, parser, signature, metadata, and form projects are recorded in
[`docs/cross-project-document-intelligence-exploration.md`](docs/cross-project-document-intelligence-exploration.md).
The purpose is to rebuild every transferable primitive in PDF Editor while
preserving canonical ownership and avoiding a second extraction pipeline. The
cross-project record is therefore an implementation input, not a shortlist or a
permanent scope boundary.

- Build a cross-project evidence ledger with source paths, truth status, owner,
  output schema, coordinate space, privacy class, and license/provenance state.
- Salvage SignKit's native-first inspection, candidate review, hard-negative,
  correction, and end-to-end workflow patterns.
- Salvage MetaExtract's registry, provenance, conflict, shadow-mode, and bounded
  sensitive-field patterns.
- Salvage Invoice Intelligence's routing, schema, review-label, fallback, and
  validation/benchmark patterns without importing invoice semantics.
- Salvage PhotoSearch's region-level OCR, multilingual, cache, and missing-engine
  behavior without importing the media metadata schema.
- The native/web parity baseline now exists. Classify its retained mismatches
  and preserve the evidence while implementing OCR, parser, companion, and new
  runtime lanes. Parity is a prerequisite for honest provider comparison, not a
  reason to stop those lanes.
- Implemented the versioned ledger and 17-case parity fixture at
  [`Tests/fixtures/cross_project_evidence_ledger.json`](Tests/fixtures/cross_project_evidence_ledger.json)
  and [`Tests/fixtures/pdf_corpus_semantic_parity_fixture.json`](Tests/fixtures/pdf_corpus_semantic_parity_fixture.json).
- The combined gate reports six entries, 18 source references, 17 corpus cases,
  six classified mismatches, zero unexpected mismatches, and one preserved
  manifest/live-artifact SHA-256 drift. See
  [`docs/audits/cross-project-evidence-ledger-parity-evidence-2026-08-24.md`](docs/audits/cross-project-evidence-ledger-parity-evidence-2026-08-24.md).
- The expanded browser corpus adds hybrid text/raster/form, noisy scanned,
  rotated hybrid, AES-256 encrypted hybrid, intentionally malformed, and
  40-page hybrid fixtures. The current gate record is
  [`docs/audits/browser-corpus-fidelity-evidence-2026-08-25.md`](docs/audits/browser-corpus-fidelity-evidence-2026-08-25.md).

The moat hypothesis is a reviewed, privacy-preserving evidence and operation
graph that compounds across providers. It remains a hypothesis until correction
reuse and safe-completion improvement are measured.

## Stop Conditions

Stop discovery and ask the user if:

- The target platform materially changes the recommended architecture.
- A license or distribution constraint changes the viable open-source set.
- “Normal PDF editing” is intended to include arbitrary content reflow rather
  than bounded text/object editing.
- A required capability cannot be provided without a proprietary dependency or
  a materially different risk profile.

## Errors Encountered

| Error | Attempt | Resolution |
|---|---:|---|
| Source fetch timeouts | Several | Retained the source URL and marked the affected claims as incomplete or unknown |
| MCP web-reader rate limit (`-429`) | Several | Continued from already retrieved primary sources and preserved the limitation |
| Poppler GitLab/Anubis access block | Several | Used official Poppler API pages and an official cgit source header where available |
| GitHub repository-read quota (`-429`) | 2026-08-23 continuation | Kept the already retrieved source evidence; direct repository reads remain deferred until the quota reset |
| MuPDF documentation path returned `404` | 1 | Used the official repository README, COPYING, headers, and CHANGES instead |

## Next Step

The original exploration closure and its exact platform decision are recorded in
[`docs/audits/exploration-closure-evidence-2026-08-24.md`](docs/audits/exploration-closure-evidence-2026-08-24.md).
The long-term deployment architecture is now accepted in D-009 and
[`docs/web-deployment-decision.md`](docs/web-deployment-decision.md): the first
staged web surface is browser-first, while OCR and high-fidelity editing belong
in an explicitly installed optional companion capability plane. The companion
is not required to use the browser core and has not been approved for packaging.

The cross-project ledger and parity gate are now implemented. The recommended
next implementation is parity-mismatch classification plus independent
fingerprint, geometry, and privacy hardening. The
T1 contract slice from
[`docs/template-system-design.md`](docs/template-system-design.md) is now
implemented: keyed layout fingerprints, reviewed native/static mappings,
separate versioned profiles, no profile values in templates, and native/web
round-trip and matcher tests. The runtime layer now includes encrypted local
record primitives, review-gated operation materialization, and strict learning
promotion. The browser mapping/value review surface is now implemented against
the shared contracts. The browser encrypted-store lifecycle now includes
explicit store/profile unlock, deletion, eviction health, ciphertext backup
restore, and zero-content diagnostics. The next template slice is native
review UI, browser backup/import UX, native Keychain wiring, adapter integration,
and held-out recurring-version calibration, not automatic completion. The
controlled correction-event measurement now shows a bounded reviewed-target
coverage lift while preserving rollback, privacy, and hard-negative abstention;
genuine held-out recurring families, reviewer agreement, value correctness, and
user-time benefit remain required. Lost-passphrase recovery and production
persistence UX remain bounded work.
The initial PDFKit lane remains documented in [`docs/pdfkit-benchmark.md`](docs/pdfkit-benchmark.md);
it is evidence for the adapter, not a final provider clearance.

The immediate engineering choice is which named capability lane to execute
next, using the same source-bound corpus and independent validation. OCR,
parser, signature, companion, batch, security, accessibility, and hosted lanes
remain active implementation work. Their activation and release claims remain
gated by corpus need, runtime evidence, security, privacy, licensing, and
support cost, but no gate authorizes removing the lane from the build program.

### Phase 11: Competitor and product-surface exploration

**Status:** ihatepdf.cv documented; six competitor-inspired experiment contracts implemented, capability execution queued

The current-source exploration of [ihatepdf.cv](docs/competitor-ihatepdf-cv-exploration-2026-08-24.md)
is now part of the project record. It is a product and architecture reference,
not a provider selection or proof of the site's claims.

- Reuse the task-oriented tool-entry, PWA/share-target, resource-preflight,
  storage-tier, compare, and privacy-report ideas as bounded candidates.
- Keep text-run replacement, OCR-to-editable text, permanent redaction, repair,
  compression, conversion, AI, P2P, and collaboration behind typed capability
  and validation gates.
- Add text-run preservation, OCR alignment, privacy sanitization, repair/recovery,
  adaptive browser limits, and semantic/visual compare cases to the evidence
  ledger and corpus plan.
- Implemented the versioned ledger at
  [`Tests/fixtures/ihatepdf_experiment_ledger.json`](Tests/fixtures/ihatepdf_experiment_ledger.json)
  with one semantic parity case per experiment. The independent Swift and
  browser projections agree with zero mismatches, and four deliberate ledger
  mutations are rejected. This proves the evidence definition and contract
  parity only; it does not execute the six provider capabilities.
- Do not add Ghostscript, Tesseract.js, Gemini, P2P signaling, a service worker,
  or a broad converter suite from competitor copy alone.

### Phase 12: Full native/web capability build program

**Status:** impact validation and browser geometry detection built; remaining
capability lanes explicitly mapped and evidence-gated

The living [full capability build program](docs/full-capability-build-program.md)
now records every reader, form, geometry, OCR, editing, page-operation,
security, signature, accessibility, template, companion, and collaboration lane
for both native and web surfaces.

- Built the native and browser outside-region text and raster validators.
- Added an independent Poppler/qpdf preservation validator with text hashes,
  outside-region raster diffs, retained native/web export artifacts, and
  mutation-sensitive authorization tests.
- Added deterministic 90-degree and mixed 90/180-degree rotation fixtures and
  independent reopen evidence for both native and browser no-op outputs.
- Built browser operator-list geometry evidence for vector rectangles, checkbox
  shapes, repeated cells, underlines, whitespace, and label associations.
- Added the browser pre-export contract mutation gate and browser integration
  tests proving stale digests, unsupported/destructive operations, unknown
  validation states, and coordinate mismatches are rejected before pdf-lib.
- Keep OCR web, text-run replacement, redaction, sanitization, signatures, XFA,
  PDF/UA, independent-viewer parity, and broad page/conversion operations behind
  their named corpus and provider gates.
- The next implementation unit is rotated reviewed-operation replay, accepted
  qpdf-variance classification, browser geometry false-positive reduction,
  privacy preflight reporting, and the first capability execution slice from
  the ihatepdf ledger, beginning with E-006 compare impact maps or E-002 OCR
  alignment only after its provider and independent-validator gates are named.

### Phase 13: Capability-negotiated local provider plane

**Status:** Admission and typed protocol slices implemented; installer,
authenticated bridge, and provider execution remain evidence-gated

The long-term provider plane is now defined in
[`docs/provider-capability-system-design.md`](docs/provider-capability-system-design.md).
It is a separate admission contract, not a change to the shared PDF document,
coordinate, candidate, edit-session, or validation contracts.

The provider plane remains downstream of the normalized native/web parity gate
in [`web/pdf-contract-parity.mjs`](web/pdf-contract-parity.mjs). OCR and local
companion execution may be implemented, but each provider result must first be
projectable into the shared semantics and must preserve the parity mutation
guards.

- Keep provider installation, capability evidence, license state, runtime
  health, and revocation as separate facts and state machines.
- Require exact artifact digest, named corpus measurement, report digest,
  source limits, approved license state, and no active revocation before default
  selection.
- Return deterministic selected or abstained decisions with reason codes and
  fallback provider IDs. Do not route to an unmeasured engine merely because it
  is installed.
- Keep browser PDF.js/pdf-lib, native PDFKit/Vision, and companion providers as
  adapters that emit the existing shared PDF contracts.
- Add the authenticated companion transport around the implemented typed
  handshake, then add cancellation/resource enforcement, zero-content
  diagnostics, and the local measurement runner as separate milestones.
- Enable OCR, high-fidelity editing, redaction, or other advanced capabilities
  one capability at a time. A provider passing one capability does not promote
  its engine family globally.

### Phase 14: Compounding moat asset implementation

**Status:** Versioned registry implemented; asset-specific completion gates remain active

The compounding assets are now first-class implementation objects in
[`docs/moat-asset-registry.md`](docs/moat-asset-registry.md) and
[`Tests/fixtures/moat_asset_registry.json`](Tests/fixtures/moat_asset_registry.json).
The registry covers source-digest binding, page-space and crop/rotation
fixtures, multi-signal evidence, candidate explanations and abstention,
reviewed mappings, hard negatives, operation lineage, provider divergence,
independent reopen outcomes, template revisions, confidence calibration, corpus
governance, workflow completion, and recovery.

- Treat the registry as an accountability graph above the shared PDF contracts.
- Every asset must have native, web, contract, fixture, validator, evidence,
  privacy, retention, and completion references.
- Keep implemented, partial, open, blocked, and quarantined states explicit.
- Preserve hard negatives, provider mismatches, failed recovery, source drift,
  and abstention evidence as append-only learning assets.
- Close partial and open assets through named corpus experiments, not aggregate
  feature counts or provider marketing claims.
- Run `node Tests/moat_asset_registry_test.mjs` after changes to contracts,
  providers, corpus governance, templates, validators, or recovery behavior.

### Phase 15: Multi-signal evidence fusion

**Status:** Deterministic native/browser fusion implemented; calibration and
provider-wide evidence admission remain active

- Derive an optional fusion result from the existing candidate evidence items,
  without creating a second candidate or operation model.
- Keep semantic, geometry, language, and relationship evidence separately
  weighted and preserve their IDs, origins, providers, and geometry lineage.
- Abstain on conflicting high-confidence geometry and retain review-only states
  for weak or single-family evidence.
- Verify the same cases through Swift and browser tests before adding OCR or
  companion signals to default routing.
- Calibrate thresholds by governed document class, held-out recurring versions,
  hard negatives, and correction/recovery outcomes. Do not promote a threshold
  from synthetic cases to a universal detector claim.

The first implementation and its evidence record are
[`docs/audits/evidence-fusion-evidence-2026-08-25.md`](docs/audits/evidence-fusion-evidence-2026-08-25.md).

### Phase 16: Reference local companion execution

**Status:** Typed reference host implemented; packaging, transport
authentication, sandboxing, and real provider handlers remain active gates

- Route only the existing typed hello, capability request, and cancellation
  messages through a narrow host.
- Bind each request to the accepted origin, session, nonces, source digest,
  operation IDs, byte/page limits, and timeout.
- Reject stale or mismatched source bytes before a handler runs; enforce output
  limits, cancellation, timeout, and provider abstention states.
- Keep diagnostics allowlisted and value-free. The host must never become an
  arbitrary shell, path resolver, or browser-to-process file API.
- Add OCR, parser, independent-viewer, and high-fidelity handlers only through
  the capability registry, corpus measurements, license review, and shared
  semantic projection tests.

The reference implementation and evidence are
[`web/provider-companion-host.mjs`](web/provider-companion-host.mjs),
[`Tests/provider_companion_host_test.mjs`](Tests/provider_companion_host_test.mjs),
and [`docs/audits/provider-capability-system-evidence-2026-08-25.md`](docs/audits/provider-capability-system-evidence-2026-08-25.md).

### Phase 17: Privacy-first PDF preflight and sanitization evidence

**Status:** Value-minimized preflight implemented in native and browser lanes;
sanitization and post-sanitize proof remain active long-term implementation

- Emit a shared `pdf-editor.preflight` report with source binding, metadata
  presence, embedded-data indicators, network boundaries, possible active
  content, encryption state, and explicit sanitization limits.
- Keep raw metadata values, attachment names, URLs, page/OCR text, source bytes,
  passwords, pixels, profile values, and active-content payloads out of the
  report and diagnostics.
- Reject stale source reports when the current session digest differs, and
  reject clean claims, execution claims, unknown finding states, forbidden
  content fields, and unsupported versions before downstream use.
- Implement the sanitizer as a separate typed new-copy operation with provider
  capabilities, output digest, removed/preserved/unknown inventory,
  incremental-revision policy, signature state, independent reopen evidence,
  resource limits, cancellation, and partial-output recovery.
- Exercise metadata/XMP, embedded file, action, XFA, rich-media, signature,
  malformed-stream, hidden-revision, and independent-viewer cases across
  native PDFKit, browser PDF.js/pdf-lib, qpdf, Poppler, MuPDF, and installed
  companion providers as they become available.

The preflight implementation and current evidence are recorded in
[`docs/audits/pdf-preflight-evidence-2026-08-25.md`](docs/audits/pdf-preflight-evidence-2026-08-25.md).

### Phase 18: Device-adaptive browser limits and recovery

**Status:** Versioned policy, native mirror, scheduler proof, and benchmark implemented; physical-device and real-provider calibration remain active long-term implementation

- Emit the shared `pdf-editor.browser-resource-policy` envelope from the web fixture and mirror its facts, budgets, decisions, and safety invariants in PDFEditorCore.
- Derive bounded render and high-DPI budgets from page geometry, raster density, rotation, page count, device pixel ratio, CPU, memory, viewport, connection, and explicit storage-signal availability. Keep unknown signals visible and conservative.
- Gate OCR and batching behind explicit requests, page/pixel/byte/document budgets, worker concurrency, yields, cancellation, and adaptive checkpoints.
- Bind recovery checkpoints to source digest and operation ID. Reject stale checkpoints and never promote partial output after cancellation or failure.
- Keep policy and event output value-free. Preserve only digests, IDs, counts, timings, states, reason codes, and provider metadata in benchmark artifacts.
- Run the controlled benchmark, native/browser serialized parity, mutation tests, and isolated Chrome fixture. Follow with physical-device calibration, browser-version drift, worker memory, companion crash, and long-run batch measurements as implementation work, not as permission to narrow the capability program.

The implementation and evidence are recorded in
[`web/browser-resource-policy.mjs`](web/browser-resource-policy.mjs),
[`Sources/PDFEditorCore/BrowserResourcePolicyContracts.swift`](Sources/PDFEditorCore/BrowserResourcePolicyContracts.swift),
[`benchmark/benchmark_browser_resource_policy.mjs`](benchmark/benchmark_browser_resource_policy.mjs),
and [`docs/audits/browser-resource-policy-evidence-2026-08-25.md`](docs/audits/browser-resource-policy-evidence-2026-08-25.md).

### Phase 19: Text-run replacement and OCR-layer alignment

**Status:** Native/browser evidence contract and full-corpus benchmark
implemented; provider geometry calibration and true replacement remain active
long-term implementation

- Emit the value-free `pdf-editor.text-run-ocr-alignment` projection from the
  browser PDF.js fixture and the native PDFKit/Vision benchmark executable.
- Bind every run, OCR observation, comparison, and replacement probe to the
  source digest, page index, crop-box page geometry, rotation, provider, and
  evidence origin. Retain hashes, counts, confidence, and states only.
- Compare the complete current fixture execution list, including selectable,
  scanned, hybrid, rotated, encrypted, malformed, handwritten-like, and large
  documents. Treat missing browser OCR and unsupported replacement as explicit
  abstentions.
- Keep the existing overlay/form writer separate from semantic text-run
  replacement. Do not promote a visual overlay, OCR confidence score, or
  provider rectangle into a replacement permission.
- Add a provider-independent text-box control, calibrated geometry policies,
  browser OCR capability, and independent outside-region/raster/reopen/viewer
  validation before enabling a supported replacement operation.

The current implementation and evidence are recorded in
[`web/text-run-ocr-alignment-benchmark.mjs`](web/text-run-ocr-alignment-benchmark.mjs),
[`Sources/PDFTextRunOCRBenchmark/main.swift`](Sources/PDFTextRunOCRBenchmark/main.swift),
and [`docs/audits/text-run-ocr-alignment-evidence-2026-08-25.md`](docs/audits/text-run-ocr-alignment-evidence-2026-08-25.md).

### Phase 20: Native/browser normalized semantic parity report

**Status:** Fresh 18-fixture report implemented and verified; detector,
precision, edit-session, OCR, companion, and independent-viewer parity remain
active long-term implementation

- Emit the same governed corpus through the native PDFKit harness and browser
  PDF.js/pdf-lib fixture.
- Normalize provider IDs and versions, platform labels, timestamps, generated
  object IDs, diagnostic prose, validation messages, and output digests only
  for semantic equality. Retain their presence as provenance facts.
- Preserve source SHA-256, page-space geometry, fields, candidate evidence,
  operations, navigation, accessibility, security, and validation state in
  the semantic projection.
- Classify every mismatch against the reviewed fixture policy and fail the
  gate on unexpected mismatches, not on already declared provider gaps.
- Extend the same report shape to non-noop edits, OCR layers, optional local
  companions, independent viewers, redaction/sanitization, signatures, XFA,
  and future hosted/provider lanes without changing the shared contract.

The implementation and current evidence are recorded in
[`web/pdf-contract-parity.mjs`](web/pdf-contract-parity.mjs),
[`Tests/pdf_contract_parity_test.mjs`](Tests/pdf_contract_parity_test.mjs),
[`Tests/native_browser_semantic_parity_report_test.mjs`](Tests/native_browser_semantic_parity_report_test.mjs),
and [`docs/audits/native-browser-semantic-parity-evidence-2026-08-25.md`](docs/audits/native-browser-semantic-parity-evidence-2026-08-25.md).

### Phase 21: Read-only privacy preflight contract and native/browser report

**Status:** Revision 1.1 implemented; 18-fixture parity report generated; keyword-presence provider mismatch retained

- Emit metadata, attachment, annotation, script, revision, coverage, and
  unknown-coverage facts from native PDFKit and browser PDF.js surfaces.
- Keep preflight observational and source-bound. No action execution, payload
  retention, sanitization claim, or source mutation is permitted.
- Normalize only provider identity and representation noise in parity. Preserve
  all privacy facts and adapter mismatches in a dated machine report.
- Extend the same report to future sanitization, cryptographic, XFA, companion,
  hosted, and independent-viewer lanes without changing the shared semantics.

The implementation and evidence are recorded in
[`web/pdf-preflight.mjs`](web/pdf-preflight.mjs),
[`Sources/PDFEditorCore/PreflightContracts.swift`](Sources/PDFEditorCore/PreflightContracts.swift),
[`Tests/pdf_contract_parity_test.mjs`](Tests/pdf_contract_parity_test.mjs), and
[`docs/audits/native-browser-privacy-preflight-parity-evidence-2026-08-25.md`](docs/audits/native-browser-privacy-preflight-parity-evidence-2026-08-25.md).

### Phase 22: Hard-negative geometry detector calibration

**Status:** Versioned synthetic fixture, semantic label gates, native/browser
parity, overall precision/recall, failure-cluster classification, and
mutation-sensitive zero-false-positive controlled calibration implemented;
real-world geometry expansion remains active long-term implementation

- Maintain reviewed positive and hard-negative evidence for vector rectangles,
  checkbox-shaped paths, underlines, whitespace, and label association.
- Require semantically plausible field-intent labels before geometry becomes a
  candidate. Preserve raw geometry as provider evidence and abstain from
  candidate promotion when intent is generic or absent.
- Compare native PDFKit and browser PDF.js by normalized page-space bounds,
  evidence kinds, field type, expected state, and abstention. Ignore generated
  provider IDs while retaining source digest and report provenance.
- Treat score floors as evidence-strength observations from reviewed fixtures,
  not probabilities or silent-acceptance thresholds.
- Report overall and per-class precision, recall, false-positive rate, and
  abstention. Classify failures into no-near-candidate, evidence, candidate
  kind, field type, and geometry clusters without retaining document content.
- Keep mutation cases that remove positives, promote hard negatives, and strip
  required evidence. The calibration gate must kill each bypass before a
  detector change can be considered safe.
- Expand the fixture ledger with rotated, multilingual, OCR-only, table,
  clipped-path, filled-shape, malformed-stream, and real-world reviewed cases
  before any detector promotion beyond review-only suggestions.

The implementation and current evidence are recorded in
[`web/detector-calibration.mjs`](web/detector-calibration.mjs),
[`Tests/detector_calibration_parity_test.mjs`](Tests/detector_calibration_parity_test.mjs),
and [`docs/audits/detector-hard-negative-calibration-evidence-2026-08-25.md`](docs/audits/detector-hard-negative-calibration-evidence-2026-08-25.md).

### Phase 23: Native, browser WASM, and companion OCR bake-off

**Status:** Three local OCR lanes measured on the governed six-input OCR set;
companion candidates recorded with explicit unavailable or control-only states;
provider promotion remains blocked by accuracy, latency-boundary, licensing,
and recovery evidence

- Measure native Vision, local Tesseract CLI, and browser Tesseract.js WASM
  through the same source-bound OCR evidence shape.
- Normalize provider-specific word coordinates into
  `normalizedLowerLeft` page space and confidence into `[0,1]`. Retain valid
  bounds counts, union bounds, alignment IoU, provider artifact digests, and
  abstention states without serializing recognized content.
- Run the same six inputs covering clean, noisy, simulated handwriting-like,
  rotated, encrypted, and large hybrid PDFs. Keep synthetic handwriting-like
  results from becoming handwriting or signature claims.
- Measure browser asset locality and external-request absence as an explicit
  privacy boundary. Treat model loading, worker startup, memory,
  cancellation, all-page throughput, and language coverage as separate gates.
- Record OCRmyPDF and PDFBox as unmeasured when their runtimes are absent, and
  MuPDF as a high-fidelity render control rather than an OCR result until a
  licensed, source-bound companion runner exists.
- Keep all measured OCR output as candidate evidence only. No OCR score,
  confidence, or aligned bounds may silently create a field, overwrite source
  text, or publish a partial export.

The implementation, report, and evidence are recorded in
[`benchmark/compare_ocr_providers.mjs`](benchmark/compare_ocr_providers.mjs),
[`benchmark/browser_wasm_ocr.mjs`](benchmark/browser_wasm_ocr.mjs),
[`Tests/ocr_provider_comparison_test.mjs`](Tests/ocr_provider_comparison_test.mjs),
and [`docs/audits/ocr-provider-comparison-evidence-2026-08-25.md`](docs/audits/ocr-provider-comparison-evidence-2026-08-25.md).

### Phase 24: Typed semantic text-run replacement

**Status:** Typed operation, fail-closed native/browser provider gates, and a
bounded same-width ASCII literal provider experiment implemented; general
semantic writer and preservation proof remain active build work

- Represent semantic replacement separately from `overlayText` using the
  shared `textRunReplacement` operation kind.
- Bind the operation to a source-run ID, original text hash, source digest,
  page-space bounds, coordinate convention, optional font fingerprint, review
  lineage, and reversible operation metadata.
- Keep replacement values in the active edit session only. Recovery-safe
  session metadata records payload kind and references, never replacement text.
- Reject the operation in PDFKit and pdf-lib until the selected writer can
  identify and rewrite the original text object while proving font, glyph,
  ligature, RTL, clipping, transparency, outside-region, raster, reopen, and
  independent-viewer behavior.
- Exercise the first bounded browser provider for classic uncompressed streams
  and unique same-byte-length ASCII literals. Validate source text change,
  outside text/raster stability, qpdf structure, Poppler extraction, reopen,
  stale digest rejection, and unequal-width abstention.
- Keep OCR-derived text and visual overlays as different operation types. OCR
  evidence may propose a target but cannot authorize semantic replacement.
- Build the next provider experiment against the existing text-run corpus with
  a same-font simple-run case first, then expand to ligatures, embedded fonts,
  Unicode, RTL, columns, tables, clipping, transparency, overlapping objects,
  and negative cases where the provider must abstain.

The current typed slice is implemented in
[`Sources/PDFEditorCore/DocumentModel.swift`](Sources/PDFEditorCore/DocumentModel.swift),
[`Sources/PDFEditorCore/SharedContracts.swift`](Sources/PDFEditorCore/SharedContracts.swift),
[`web/text-run-ocr-alignment-benchmark.mjs`](web/text-run-ocr-alignment-benchmark.mjs),
and guarded by
[`Tests/PDFEditorCoreTests/ContractMutationTests.swift`](Tests/PDFEditorCoreTests/ContractMutationTests.swift)
and [`Tests/text_run_ocr_alignment_contract_test.mjs`](Tests/text_run_ocr_alignment_contract_test.mjs).
The bounded writer experiment is implemented in
[`web/simple-text-run-provider.mjs`](web/simple-text-run-provider.mjs) and
[`Tests/text_run_simple_provider_test.mjs`](Tests/text_run_simple_provider_test.mjs).

### Phase 25: Native/browser semantic candidate parity

**Status:** Candidate projection and fresh 18-fixture report implemented;
provider divergence, reviewed target adjudication, and split/merge handling
remain active long-term implementation

- Project candidate geometry, kind, suggested field type, entry mode, evidence
  families, review state, grouping, and coordinate space without IDs, labels,
  evidence prose, scores, timestamps, or output digests.
- Pair candidates by same-page page-space IoU, then report directional native
  and browser coverage, symmetric agreement F1, equivalent pairs, semantic
  differences, native-only candidates, and browser-only candidates.
- Keep this report separate from reviewed precision/recall. Provider agreement
  is not ground truth, and no provider becomes authoritative merely because it
  emits more candidates.
- Add mutation checks for representation-only changes, candidate-kind drift,
  evidence-kind drift, and coordinate drift before using the report to guide
  detector changes.
- Expand reviewed candidate labels and candidate-bearing corpus classes before
  promoting any detector or changing the shared taxonomy.

The implementation and evidence are recorded in
[`web/candidate-parity.mjs`](web/candidate-parity.mjs),
[`Tests/native_browser_candidate_parity_report_test.mjs`](Tests/native_browser_candidate_parity_report_test.mjs),
[`Tests/candidate_parity_mutation_test.mjs`](Tests/candidate_parity_mutation_test.mjs),
and [`docs/audits/native-browser-candidate-parity-evidence-2026-08-25.md`](docs/audits/native-browser-candidate-parity-evidence-2026-08-25.md).

### Phase 26: Session privacy and export provenance

**Status:** Implemented and corpus-measured; provider-specific OCR, companion,
remote, persistence, deletion, and eviction states remain active build lanes

- Add a shared session-level provenance envelope above document preflight.
- Record processing locality, data egress class, OCR use and retention, source
  retention/deletion, export digests, validation, reopen evidence, and operation
  count without serializing document content or user values.
- Attach the envelope to native recovery sessions and browser fixture snapshots.
- Reject stale source bindings, false privacy flags, contradictory OCR states,
  and successful exports without output identity and reopen validation.
- Refresh the complete corpus and preserve failed-open fixtures as explicit
  no-session outcomes.

Evidence is retained in
[`docs/audits/session-privacy-provenance-evidence-2026-08-25.md`](docs/audits/session-privacy-provenance-evidence-2026-08-25.md).

### Phase 27: Independent browser-export renderer comparison

**Status:** Poppler comparison envelope implemented and measured across the
current browser export corpus; edited-operation, MuPDF three-way, GUI-viewer,
and broader fidelity lanes remain active long-term implementation

- Keep PDF.js as the browser reader and validation provider.
- Keep Poppler as an independent text, raster, page-facts, and reopen control.
- Join provider verdicts without collapsing provider-specific evidence.
- Fail on text/raster divergence, preserve `unknown` for missing evidence, and
  retain malformed expected failures as explicit non-passes.
- Regenerate the joined report from the full native/browser parity runner and
  preserve the detailed low-level Poppler report separately.
- Extend the same typed envelope to edited operations, redaction,
  sanitization, signatures, XFA, PDF/UA, MuPDF, and GUI-viewer controls as
  those capability lanes are implemented and measured.

Implementation and evidence:

- [`benchmark/browser-export-independent-viewer-validator.mjs`](benchmark/browser-export-independent-viewer-validator.mjs)
- [`Tests/browser_export_independent_viewer_validator_test.mjs`](Tests/browser_export_independent_viewer_validator_test.mjs)
- [`docs/audits/independent-browser-viewer-comparison-evidence-2026-08-25.md`](docs/audits/independent-browser-viewer-comparison-evidence-2026-08-25.md)

### Phase 33: Complete encrypted reviewed-template lifecycle

**Status:** Implemented in native and browser adapters. Operational recovery,
interactive accessibility, and sync-service gates remain measurable long-term
hardening work.

- Persist template histories through native encrypted Keychain-backed storage,
  browser encrypted IndexedDB, and encrypted OPFS.
- Keep profile values in separate encrypted vault namespaces and require
  explicit unlock before value resolution.
- Provide capture, mapping review, activation, profile-value review,
  source-bound operation materialization, validated child revision creation,
  and explicit persistence without silent autofill.
- Journal value-free learning events and promote them only after strict export,
  reopen, source, coordinate, and operation-lineage validation.
- Support value-free template transfer import/export, revision diff summaries,
  encrypted backup/recovery, deletion, eviction detection, and client-encrypted
  sync merge with conflict abstention.
- Verify native/browser semantic parity and preserve expected provider
  mismatches instead of normalizing them away.

Implementation and evidence:

- [`Sources/PDFEditorCore/TemplateLifecycleContracts.swift`](Sources/PDFEditorCore/TemplateLifecycleContracts.swift)
- [`Sources/PDFEditorCore/TemplateSyncContracts.swift`](Sources/PDFEditorCore/TemplateSyncContracts.swift)
- [`Sources/PDFEditorCore/EncryptedTemplatePersistence.swift`](Sources/PDFEditorCore/EncryptedTemplatePersistence.swift)
- [`web/pdf-template-store.mjs`](web/pdf-template-store.mjs)
- [`web/pdf-template-sync.mjs`](web/pdf-template-sync.mjs)
- [`Tests/PDFEditorCoreTests/EncryptedTemplatePersistenceTests.swift`](Tests/PDFEditorCoreTests/EncryptedTemplatePersistenceTests.swift)
- [`Tests/web_template_browser_test.mjs`](Tests/web_template_browser_test.mjs)
- [`docs/audits/template-lifecycle-evidence-2026-08-25.md`](docs/audits/template-lifecycle-evidence-2026-08-25.md)

### Phase 30: Encrypted local template persistence and separate profile vaults

**Status:** Native and browser persistence implemented and focused-tested;
secure deletion, Keychain-loss recovery, quota/concurrency stress, backup
cross-platform parity, passphrase recovery, and native persistence controls
remain active long-term implementation lanes

- Persist the existing reviewed template revision contract as an encrypted,
  append-only history with parent and identity validation.
- Keep template layout metadata and profile values in separate encrypted
  namespaces, directories, and key boundaries on native; keep a separate
  profile-derived encryption key in the browser vault.
- Maintain primary and recovery copies, promote only authenticated backups,
  expose `recoveredFromBackup`, and fail closed when both copies fail.
- Remove the live web page's plaintext profile IndexedDB path and require
  explicit user actions for template persistence and profile unlock.
- Preserve zero-content diagnostics and reject source PDF bytes in template
  records.
- Continue into OS/browser backup erasure, Keychain recovery, quota and
  multi-tab conflict behavior, passphrase recovery, encrypted-backup parity,
  and native SwiftUI controls without changing the shared PDF contracts.

Implementation and evidence:

- [`Sources/PDFEditorCore/EncryptedTemplatePersistence.swift`](Sources/PDFEditorCore/EncryptedTemplatePersistence.swift)
- [`web/pdf-template-store.mjs`](web/pdf-template-store.mjs)
- [`web/index.html`](web/index.html)
- [`Tests/PDFEditorCoreTests/EncryptedTemplatePersistenceTests.swift`](Tests/PDFEditorCoreTests/EncryptedTemplatePersistenceTests.swift)
- [`docs/audits/encrypted-template-profile-persistence-evidence-2026-08-25.md`](docs/audits/encrypted-template-profile-persistence-evidence-2026-08-25.md)

### Phase 31: Native and browser dual-approval template completion

**Status:** Mapping and profile-value review workflow implemented in shared
contracts, native SwiftUI, and browser review surfaces; automated macOS UI
interaction, mid-session profile revision changes, collaborative authority,
and export-audit approval projections remain active long-term hardening lanes

- Keep mapping correctness and profile-value correctness as separate decisions.
- Bind mapping approval to mapping ID, provider target resolution, and page-space
  coordinate.
- Bind profile-value approval to profile ID, profile revision ID, semantic key,
  and a typed-value SHA-256 digest.
- Reset mapping approval when native target resolution changes.
- Reset profile-value approval when the displayed value changes.
- Route native and browser Apply actions through the shared materialization gate
  before any operation enters the ledger.
- Preserve encrypted template and profile storage as separate namespaces and
  keep no-profile browser completion session-only.
- Extend the same approval lineage to export audit reports, profile revision
  change detection, macOS UI automation, collaborative review authority, and
  all future OCR, companion, redaction, signing, and accessibility lanes.

Implementation and evidence:

- [`Sources/PDFEditorCore/TemplateRuntimeContracts.swift`](Sources/PDFEditorCore/TemplateRuntimeContracts.swift)
- [`Sources/PDFEditorApp/AppModel.swift`](Sources/PDFEditorApp/AppModel.swift)
- [`Sources/PDFEditorApp/ContentView.swift`](Sources/PDFEditorApp/ContentView.swift)
- [`web/pdf-template-contract.mjs`](web/pdf-template-contract.mjs)
- [`web/index.html`](web/index.html)
- [`Tests/PDFEditorCoreTests/PDFEditorCoreTests.swift`](Tests/PDFEditorCoreTests/PDFEditorCoreTests.swift)
- [`Tests/web_template_contract_test.mjs`](Tests/web_template_contract_test.mjs)
- [`Tests/web_template_browser_test.mjs`](Tests/web_template_browser_test.mjs)
- [`docs/audits/template-review-workflow-evidence-2026-08-25.md`](docs/audits/template-review-workflow-evidence-2026-08-25.md)

### Phase 32: Native/browser structural fingerprint parity

**Status:** Implemented fixture and comparator over the retained 18-entry
corpus; provider remediation remains an active long-term parity lane

- Build a value-minimized structural fingerprint from each native and browser
  inspection bundle.
- Compare page boxes, rotation, text shape, fields, candidate populations,
  evidence families, coordinate spaces, navigation, permissions, security, and
  accessibility by feature family.
- Retain source digest only for binding and exclude raw labels, evidence prose,
  timestamps, provider IDs, output digests, and PDF bytes.
- Preserve malformed expected failures as explicit equal failure-state cases.
- Add mutation tests for source drift, rotation, permissions, candidate count,
  coordinate-space, and tolerated character-count representation changes.
- Feed the named divergence clusters into permission normalization, candidate
  grouping, rotation transforms, page-box precision, text-run alignment, and
  future OCR/provider parity work.
- Keep this phase as measurement and remediation infrastructure, not a
  replacement for independent viewer, edited-output, accessibility, or
  arbitrary semantic-edit evidence.

Implementation and evidence:

- [`web/pdf-fingerprint-parity.mjs`](web/pdf-fingerprint-parity.mjs)
- [`benchmark/generate_fingerprint_parity.mjs`](benchmark/generate_fingerprint_parity.mjs)
- [`Tests/fixtures/pdf_fingerprint_parity_fixture.json`](Tests/fixtures/pdf_fingerprint_parity_fixture.json)
- [`Tests/native_browser_fingerprint_parity_test.mjs`](Tests/native_browser_fingerprint_parity_test.mjs)
- [`docs/audits/native-browser-fingerprint-parity-evidence-2026-08-25.md`](docs/audits/native-browser-fingerprint-parity-evidence-2026-08-25.md)

### Phase 28: Browser preservation metrics review surface

**Status:** Value-minimized text/raster metrics are exposed in the browser
review/export panel and measured in passing and failed export states; native
panel parity, raw PDF.js raster artifact retention, and independent-viewer UI
comparison remain active long-term lanes

- Render the existing `outsideRegionText` and `visualDiff` evidence directly in
  the review/export surface.
- Show page counts, changed-page counts, pixel counts, ratios, channel deltas,
  scale, tolerance, operation count, and evidence basis.
- Preserve raw document text outside the panel and keep unknown/failed states
  visible.
- Keep source-digest equality distinct from rendered raster evidence.
- Extend the same value-minimized presentation to native review surfaces and
  independent Poppler/MuPDF comparisons as those adapters gain UI contracts.

Implementation and evidence:

- [`web/index.html`](web/index.html)
- [`Tests/web_reader_contract_test.mjs`](Tests/web_reader_contract_test.mjs)
- [`Tests/web_pdf_proof_playwright_test.mjs`](Tests/web_pdf_proof_playwright_test.mjs)
- [`docs/audits/browser-preservation-metrics-evidence-2026-08-25.md`](docs/audits/browser-preservation-metrics-evidence-2026-08-25.md)

### Phase 29: Independent renderer metrics and edited-operation binding

**Status:** Normalized Poppler/PDF.js report extension implemented and focused
mutation-tested; fresh full-corpus current-browser metric regeneration and
edited-operation fidelity remain active long-term implementation lanes

- Preserve independent Poppler and PDF.js text/raster measurements separately
  from their normalized verdict agreement.
- Distinguish comparable rendered measurements from source-digest shortcuts and
  absent provider metrics.
- Pass serialized browser edit-session operations into the independent validator
  and abstain on missing or coordinate-mismatched authorization regions.
- Regenerate current browser bundles through the canonical fixture producer,
  then measure reviewed edits against Poppler before promoting any broader
  editing capability.
- Extend the same report shape to MuPDF, PDFium, GUI viewers, redaction,
  signatures, XFA, and PDF/UA as those providers and capability lanes become
  operational.

Implementation and evidence:

- [`benchmark/browser-export-independent-viewer-validator.mjs`](benchmark/browser-export-independent-viewer-validator.mjs)
- [`Tests/browser_export_independent_viewer_validator_test.mjs`](Tests/browser_export_independent_viewer_validator_test.mjs)
- [`docs/audits/independent-browser-viewer-comparison-evidence-2026-08-25.md`](docs/audits/independent-browser-viewer-comparison-evidence-2026-08-25.md)
