# PDF Editor Implementation Plan

**Status:** Implementation authorized; web deployment decision documented and
provider adoption remains evidence-gated
**Started:** 2026-08-23
**Project root:** `/Users/pranay/Projects/pdf_editor`

## Goal

Build a decision-grade, source-backed local-first PDF platform for native macOS
and web. The implementation must preserve bounded mutation semantics and
evidence while expanding toward the complete reader, forms, OCR, editing,
templates, security, accessibility, and provider capability frontier. Provider-
specific behavior remains behind adapters and every promotion requires evidence.

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
- Establish research-only files and scope boundaries.
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

### Phase 3: Comparative evaluation

**Status:** complete

- Build a feature/constraint matrix for candidates.
- Separate adopt, wrap, compose, and custom-build decisions.
- Identify non-combinable options and license boundary risks.
- Define a small, representative corpus for later bounded experiments.

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
- Resolve the first-class platform, license tolerance, scope boundary, and
  remaining provider decision with the user.
- User instruction “call subagents and do all” approved the bounded research,
  documentation, implementation, and verification scope. Product behavior remains
  bounded by the accepted architecture; final provider adoption remains gated by
  corpus, license, security, and independent-viewer evidence.

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
threshold mutation gate. The next template unit is native review UI plus
store/adapter wiring and real recurring-family calibration, while provider
fidelity and independent outside-region comparison remain open.

- The provider-neutral core, PDFKit adapter, and native SwiftUI/AppKit shell are
  already present in this workspace and documented in
  [`docs/implementation-status.md`](docs/implementation-status.md).
- Continue native hardening with corpus expansion, independent-viewer checks,
  and provider comparison; do not treat the current PDFKit lane as final.
- Keep the PDFKit public-AcroForm radio-choice failure visible as a product warning
  and provider gate rather than silently accepting degraded semantics.

The bounded web reader/editor proof and contract fixture are implemented and
documented. Its next safe unit is native/web JSON parity and native reviewed
template capture UI, not silent autofill or a second PDF provider. See
[`docs/audits/browser-contract-fixture-evidence-2026-08-24.md`](docs/audits/browser-contract-fixture-evidence-2026-08-24.md)
and [`docs/template-system-design.md`](docs/template-system-design.md).

The first native/web serialized parity harness is now implemented and recorded
in [`docs/audits/native-web-contract-parity-evidence-2026-08-24.md`](docs/audits/native-web-contract-parity-evidence-2026-08-24.md).
It compares semantic projections across the eight-entry manifest and preserves
the first mismatch baseline. The next unit is mismatch classification and
contract/provider remediation, not normalization that merely makes the count
smaller.

### Phase 8: Corpus and alternative providers

**Status:** pending after the vertical slice

- Add PDFBox control-lane evaluation and a second independent native/provider lane
  if packaging and license review permit.
- Add static-region detection, OCR fallback, malformed/encrypted/rotated/scanned
  fixtures, structural checks, and independent-viewer checks.
- Record provider choice, license obligations, performance, and residual risks.

### Phase 9: Web deployment decision

**Status:** Accepted long-term deployment architecture; staged capability rollout
remains evidence-gated

- Keep the browser as the zero-install local core. Its bounded operations are a
  safety and evidence boundary, not the long-term product ceiling.
- Treat an explicitly installed companion as the long-term optional provider
  plane for OCR, high-fidelity editing, batch, large-document, and other native
  runtime capabilities, with a typed
  handshake, source-digest binding, security model, license record, and recovery
  path.
- Do not adopt MuPDF, OCRmyPDF, Tesseract.js, PDFBox, or a companion installer
  until the relevant provider admission gates are met. Exploration and
  controlled bake-offs remain part of the long-term build program.

### Phase 10: Cross-project document-intelligence exploration

**Status:** local evidence mapped; implementation gates pending

The local OCR, parser, signature, metadata, and form projects are recorded in
[`docs/cross-project-document-intelligence-exploration.md`](docs/cross-project-document-intelligence-exploration.md).
The purpose is to salvage transferable primitives while preserving canonical
ownership and avoiding a second extraction pipeline.

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
  and preserve the evidence before adding OCR, parser, companion, or new runtime
  dependencies.

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

The recommended next implementation is the Phase 10 cross-project evidence
ledger plus parity-mismatch classification and geometry/privacy hardening. The
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
and real reviewed-family calibration, not automatic completion. Lost-passphrase
recovery and production persistence UX remain bounded work.
The initial PDFKit lane remains documented in [`docs/pdfkit-benchmark.md`](docs/pdfkit-benchmark.md);
it is evidence for the adapter, not a final provider clearance.

The immediate next decision is not which neighboring codebase to copy. It is
whether the shared evidence ledger and parity fixture should be implemented as
the next bounded unit. OCR and companion adoption remain gated by corpus need,
runtime evidence, security, privacy, licensing, and support cost.

### Phase 11: Competitor and product-surface exploration

**Status:** ihatepdf.cv documented; competitor-inspired experiments queued

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
  privacy preflight reporting, and OCR-layer alignment experiments.
