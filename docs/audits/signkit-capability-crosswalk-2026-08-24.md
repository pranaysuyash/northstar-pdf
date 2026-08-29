# SignKit to PDF Editor Capability Crosswalk

**Date:** 2026-08-24  
**Status:** Active audit and exploration map  
**Canonical owner:** `/Users/pranay/Projects/pdf_editor`  
**Adjacent source owner:** `/Users/pranay/Projects/Data_Science/computer_vision/proj6/signature-extractor-app`  
**Scope:** SignKit product, native workflow, explored roadmap, public web, and metadata-first workspace as inputs to the long-term PDF Editor web platform  
**Current evidence level:** Tier 1 static inspection of current source and documents, with historical Tier 4 native/browser evidence called out separately

> **Native implementation note (2026-08-26):** The signature *extraction* capability
> discussed here was reimplemented natively inside this repository (no SignKit
> runtime dependency), because end users do not have SignKit installed. See
> `docs/audits/signature-extraction-native-capabilities-2026-08-26.md` for current
> capabilities, the explicit no-ML limitation, and the roadmap. Treat SignKit as a
> *reference*, not the canonical owner, for extraction.

## Why this map exists

The PDF Editor work should build on the product and evidence-system work that
already exists in SignKit. This map prevents two opposite mistakes:

1. forgetting capabilities that were already explored or implemented in SignKit;
2. treating every SignKit proposal, concept surface, or historical proof as a
   current PDF Editor runtime capability.

The prototype in `Web-Prototype.zip` establishes the long-term visual and
workflow direction for this repository:

```text
Reader -> Understand -> Complete -> Organize -> Review
```

SignKit adds the operational and evidence direction:

```text
source -> inspect -> select/evidence -> transform -> review -> execute ->
validate -> export -> recover/audit
```

These are complementary. The first describes the user-facing PDF workbench.
The second describes the trustworthy execution system behind it.

## Evidence legend

| Status | Meaning in this map |
| --- | --- |
| **Observed** | A current file, route, module, document, or UI surface was inspected. |
| **Historically verified** | A prior SignKit run or report records a successful check, but it was not re-run in this PDF Editor audit. |
| **Locally demonstrated** | A local web or native surface exposes the behavior, with the boundary stated. |
| **Proposed** | Explicitly described as roadmap, design, research, or future direction. |
| **Inferred** | A transferable architectural interpretation, not a claim that the source project implements it. |
| **Unknown** | Requires fresh runtime, browser, deployment, privacy, or product verification. |

Static inspection is not end-to-end proof. A concept page is not the canonical
application. A metadata-only workspace is not browser-native document signing.
A passing historical test is not current release evidence.

## Source inventory inspected

### SignKit product and execution sources

| Source | What it contributes |
| --- | --- |
| `PRODUCT.md` | Product thesis, local-first workflow, privacy behavior, buyer-facing boundaries, and long-term Legal/HR document-operations direction. |
| `DESIGN.md` | Shared execution-core model, platform split, operator personas, Workflow Dashboard, grants, recipes, folder triplet, and fail-closed behavior. |
| `docs/README.md` | Desktop-first signature extraction, selection and cleanup, PDF signing, audit logs, rotation-aware mapping, and runtime boundary. |
| `docs/analysis/2026-08-04_signkit_roadmap_intelligence.md` | Broad capability and roadmap inventory from ingestion through Vault, PDF completion, controlled workflows, workspace control plane, and possible Hybrid. |
| `tests/test_integration_workflows.py` | Historical integration coverage for extraction, Vault round-trip, watermark verification, PDF signing, auto-detection, SVG export, and quality analysis. |
| `desktop_app/processing/extractor.py` and related native sources | Local extraction ownership, processing behavior, and the source of truth that should not be replaced by a provisional web implementation. |
| SignKit `OPERATING_DOCTRINE.md` | Authorization, evidence, privacy, release, and first-principles operating constraints. |

### SignKit web sources

| Surface | What was observed |
| --- | --- |
| `web/live/` | Canonical or retained public acquisition surface, including checkout/configuration and product messaging. |
| `web/new_landing_page/` | Newer landing variant and local preview route. It is a separate surface, not proof that the deployed root has parity. |
| `web/cloud_workspace/` | Metadata-first control-plane workspace with templates, executions, local jobs, state transitions, recovery actions, and passport/manifest concepts. |
| `web/concepts/2026-07-31-workbench-experience/` | Workbench exploration with a stronger operational workspace direction. |
| `web/concepts/2026-07-31-workspace-experience/` | Workspace and execution-oriented information architecture exploration. |
| `web/concepts/2026-08-13-document-registration-studio/` | Document registration and provenance-oriented exploration. |
| `web/concepts/2026-07-31-topology-experience/` | Local, cloud, and hybrid topology framing. |
| `web/concepts/2026-07-31-b2c-redesign/` | Acquisition and product-story exploration. |
| `web/concepts/2026-07-31-product-museum-living-ui/` | Product narrative and capability presentation exploration. |
| `web/concepts/2026-07-31-customer-work-experience/` | Customer-facing work and workflow framing. |
| `web/e2e/specs/contractdesk_workspace.spec.js` | Browser contract evidence for the metadata-only workspace and local-companion boundary. |
| `web/e2e/specs/index_visual.spec.js` | Public visual checks for the deployed acquisition surface. These do not prove the local workspace or native workflow. |

## SignKit capability inventory

This is the broad inventory to preserve. It is intentionally larger than the
first PDF Editor slice.

### 1. Image ingestion and safety

**Observed or documented in SignKit:**

- PNG and JPEG ingestion through native file selection and drag/drop paths.
- Extension, magic-byte, PIL, file-size, image-dimension, pixel-count, and
  malformed-input validation.
- Null-byte, path-traversal, suspicious-path, secure-temporary-file, and
  invalid-selection handling.
- EXIF-aware auto-rotation and rotation-preserving coordinate behavior.
- Local source-path handling and explicit rejection of unsupported or unsafe
  input.

**Transfer to PDF Editor:** source identity, file safety, decode failure
states, bounded resource use, and explicit capability errors belong in the
document intake contract. PDF Editor should not copy SignKit's image-specific
processing code.

### 2. Selection, viewer, and coordinate evidence

**Observed or documented in SignKit:**

- Rectangle selection with persistence, dimensions, position, clear, select,
  pan, zoom, fit, reset, wheel, and keyboard behavior.
- Source, preview, and result distinctions.
- Coordinate mapping across source image, preview crop, rotated image, and PDF
  page space.
- Candidate regions, selection validation, context-dependent controls, and PDF
  rendering/cache behavior.

**Transfer to PDF Editor:** the existing PDF Editor geometry contracts should
  evolve into a provider-neutral coordinate graph. Every region must state its
  page, coordinate space, transform, source digest, and confidence or evidence
  origin. A rectangle without that context is not a safe placement contract.

### 3. Processing and evidence generation

**Observed or documented in SignKit:**

- Threshold and auto-threshold controls, live previews, color input, alpha and
  background removal, transparent PNG export, and quality analysis.
- Auto-detection candidates with forensic or K-means-style exploration,
  classical fallbacks, golden fixtures, and watermark/source hashes.
- Otsu/adaptive thresholding, morphology, blur, grayscale, ink extraction,
  vectorization/SVG, OCR/typed extraction, and signature/seal classification
  as explored capability areas.
- Optional ML/model paths, corpus and benchmark proposals, feedback and
  hard-negative collection.
- Explicit failure explanations and async processing helpers.

**Transfer to PDF Editor:** use the same multi-signal pattern for document
understanding:

```text
native PDF structures -> text/geometry -> rendered pixels -> OCR/vision ->
candidate fusion -> review -> validated mutation
```

No detector score, OCR result, or model output should silently become an
editable PDF field. The provider must emit evidence, limitations, and an
abstention state.

### 4. Export and local Vault

**Observed or documented in SignKit:**

- PNG/JPEG variants, background selection, JPEG quality, trim/DPI controls,
  naming/location dialogs, clipboard export, and user-facing completion/error
  messages.
- Local library and encrypted Vault direction with IDs, metadata, thumbnails,
  tags, search, reuse, and usage references.
- Provenance, consent, revocation, secure deletion, recovery, backup/restore,
  key-loss and key-rotation concerns identified as future or open work.

**Transfer to PDF Editor:** make asset and operation lineage first-class. A
signature asset, annotation, template, or imported value needs a source
reference and ownership boundary. PDF Editor should use an asset reference
contract, not assume that it owns or stores SignKit Vault bytes.

### 5. PDF workspace and signing

**Observed or documented in SignKit:**

- Open/close and multipage PDF rendering, page navigation, cache behavior,
  signature placement/movement/resize, multiple signatures, and rotation-aware
  mapping.
- PDF signing, audit logs, manifests, session persistence, stack profiles, and
  output verification.
- Native field and candidate concepts, field taxonomy, anchors, ratio-aware
  placement, notes/annotations, and save/export behavior.
- Explored future directions including templates, form autofill, compare,
  redaction, merge/split, password handling, PDF/A, tamper evidence, evidence
  packages, certificate signing, timestamps, signing order, and undo/redo.

**Transfer to PDF Editor:** PDF Editor owns the document workspace, page model,
native field contract, inferred candidate contract, typed operations, export,
and validation. SignKit contributes the signature-specific asset and placement
semantics through an explicit adapter or future shared contract.

### 6. Templates, recipes, and controlled workflows

**Observed or documented in SignKit:**

- Local template storage, migration, update/delete, multi-binding, exact/family
  matching, and review-only matching.
- Unsigned input, signed output, and optional review folder separation.
- Role bindings, coordinates, imports, dry runs, draft/activated states,
  discovery for new files, duplicate suppression, and driver validation.
- Grants, assets, folder scopes, queues, processing, review, output
  validation, pause/resume, retry, cancel, failed/completed/quarantine states,
  operator controls, history, status, and audit.
- Open concerns around idempotency, crash and partial recovery, backpressure,
  notification, retention, cross-device behavior, event mapping, and failure
  explanation.

**Transfer to PDF Editor:** the five-mode UI must eventually support repeatable
  document operations, not only one-off edits. The initial implementation can
  keep workflow automation unavailable, but the contracts must leave room for
  template revisions, review gates, idempotency keys, quarantine, retry, and
  recovery rather than baking everything into one local component state.

### 7. Auth, licensing, packaging, and release

**Observed or documented in SignKit:**

- Trial, Starter, Team, and Business entitlement concepts.
- Grants and roles such as approver, runner, asset, and folder scope.
- Profile behavior, PyInstaller packaging, codesigning, native QA, and
  diagnostics concerns.
- Open identity, membership, receipts, refunds, activation, update, App Store,
  DMG, and accessibility work.

**Transfer to PDF Editor:** model authorization and capability discovery as
  explicit state, but do not invent subscription gates in the PDF Editor UI
  before there is a product decision. Provider capability manifests should
  distinguish unsupported, not entitled, offline, blocked, and failed.

### 8. Backend and metadata-only workspace

**Observed or documented in SignKit web workspace:**

- Authentication shell and workspace token behavior.
- Templates, executions, local jobs, document inspection records, and a merge
  of remote workspace executions with local desktop jobs.
- Workflow states including `pending_review`, `received`, `ready_for_review`,
  `needs_correction`, `approved`, `awaiting_participant`, `signed`, `exported`,
  `exception`, and `cancelled`.
- Actions including request review, request correction, approve, sign, export,
  retry, and cancel, with recovery guidance.
- Passport/manifest fields for topology, workflow/template version, aggregate
  status, input hash, decision rules, replay/idempotency policy, and the
  `metadata_only_no_document_bytes` boundary.
- Local inspection of a PDF through an isolated worker with source-byte
  deletion after the result, while the cloud workspace records metadata rather
  than hosting document bytes.

**Critical boundary:** this is a metadata-first control-plane proof. It is not
proof of browser-native PDF signing, cloud document-byte storage, or a complete
remote execution backend.

**Transfer to PDF Editor:** adopt the passport, transition graph, event lineage,
topology, and recovery concepts as neutral contracts. Keep document bytes
local unless a separate privacy/storage decision establishes consent,
ownership, encryption, retention, deletion, authorization, and stronger
runtime evidence.

### 9. Public acquisition and commercial surface

**Observed or documented in SignKit:**

- Root landing and retained landing variants.
- Redirect and route ownership distinctions.
- Checkout configuration and plan routing through the existing providers.
- Analytics, visual smoke tests, and production parity concerns.

**Transfer to PDF Editor:** separate product acquisition, browser workspace,
native companion, and provider/API evidence. A strong landing page or local
concept is not a release proof for the document workflow.

## Crosswalk into the PDF Editor five-mode product

| PDF Editor mode | SignKit-derived capability input | First-principles contract to preserve | Current PDF Editor boundary |
| --- | --- | --- | --- |
| **Reader** | Viewer controls, source/result distinction, local inspection, source hashes, rotation and page awareness | `DocumentSession`, source digest, page identity, coordinate space, provider status, cancellation and recovery | PDF.js reader/controller owns rendering and navigation. |
| **Understand** | Multi-signal inspection, OCR geometry, native fields, candidate ranking, hard negatives, abstention | `EvidenceGraph`, evidence origin, provider/model identity, confidence semantics, limitations, page boxes and transforms | PDF.js facts, geometry detector, OCR/vision adapters, and shared contracts feed evidence. |
| **Complete** | Signature asset provenance, placement, native field editing, review queue, undo/redo, output verification | Typed operation, explicit target type, source binding, review decision, operation lineage, reversible/rejected/blocked states | `pdf-lib` and bounded overlays own supported writes; inferred findings require confirmation. |
| **Organize** | Templates, recipes, page workflows, folder triplet, queue/retry/quarantine, idempotency | Page operation set, stable page IDs, workflow/template revision, execution identity, retry and recovery model | Future provider capability; must not be hidden from the product model because implementation is staged. |
| **Review** | Audit logs, passport/manifest, state transitions, corrections, validation, recovery guidance | Append-only events, validation report, export lineage, new-copy guarantee, reopen/preservation evidence | Export provider plus independent structural, visual, semantic, and provenance validation. |

## Reusable primitives, ownership, and non-copy boundaries

### Reuse as concepts or neutral contracts

- Source digest and immutable-source binding.
- Original, transformed, preview, and exported representation lineage.
- Evidence items with provider, method, coordinates, confidence semantics, and
  limitations.
- Candidate ranking, review decisions, corrections, hard negatives, and
  validation outcomes.
- Asset IDs and provenance references without assuming ownership of another
  project's bytes.
- Execution passports, append-only event records, state-transition graphs,
  correlation IDs, idempotency keys, and recovery instructions.
- Local/Cloud/Hybrid topology as an explicit deployment choice over shared
  contracts, not as three silently different products.
- Template/recipe revisions, grants, roles, folder scopes, queues, retries,
  quarantine, and output validation.

### Keep owned by SignKit

- Signature extraction and cleanup algorithms.
- Signature/seal-specific classification and heuristics.
- Signature asset Vault storage and its encryption/key-management decisions.
- Signature-specific claims, quality metrics, native desktop execution, and
  packaged app release behavior.
- SignKit's public acquisition, checkout, and entitlement authority.

### Keep owned by PDF Editor

- PDF document session and page model.
- PDF.js rendering, text layer, navigation, search, and browser lifecycle.
- Native PDF field semantics and PDF-specific candidate taxonomy.
- Typed PDF mutations, page organization, template matching, export, reopen,
  preservation, and PDF output validation.
- The Reader, Understand, Complete, Organize, and Review information
  architecture.

### Future shared boundary, if justified

If both projects need it, introduce a separately versioned neutral contract for
document evidence, assets, placement, execution receipts, and validation. Do
not create a direct runtime dependency from PDF Editor into SignKit's private
modules, or copy SignKit code into the browser. A shared contract must have:

- explicit schema version and migration rules;
- source and ownership references;
- coordinate and transform definitions;
- privacy class and retention behavior;
- provider/model identity and capability state;
- replay, idempotency, and failure semantics;
- fixtures and cross-project compatibility tests.

## Capability-state model for the web implementation

The prototype and SignKit both imply that “not connected yet” is a product
state, not a reason to erase the capability from the architecture.

| State | Meaning | User-facing behavior |
| --- | --- | --- |
| `available` | Provider and contract are usable for the current session. | Enable action and expose evidence/validation. |
| `loading` | Provider is working or a worker is initializing. | Show progress, allow cancellation, preserve source. |
| `partial` | Some evidence or operations are available, others are not. | Expose what is covered and what is missing. |
| `reader_only` | Document is safely viewable but no mutation path is currently valid. | Keep navigation/search available and explain the boundary. |
| `blocked` | A user, document, provider, entitlement, privacy, or environment condition prevents the action. | Give a recovery path or explicit reason. |
| `failed` | The attempted operation failed. | Preserve source, record failure, allow retry or alternate path. |
| `validated` | Output passed the applicable validation lanes. | Permit export/hand-off with a durable receipt. |

This state model must be shared by the shell, mode navigation, provider
adapters, operation history, and Review mode. It should not be reconstructed
independently inside each button or panel.

## Exploration backlog and falsifiers

These are deliberate follow-up questions, not silently accepted capabilities.

| Question | Required evidence before promotion |
| --- | --- |
| Can SignKit signature assets be imported into PDF Editor safely? | Versioned asset contract, provenance fixture, coordinate transform fixture, privacy/ownership decision, and native/browser round-trip test. |
| Can PDF Editor call SignKit processing locally? | Explicit adapter boundary, process/session lifecycle, cancellation, error mapping, no hidden source-byte movement, and end-to-end local proof. |
| Should browser Understand use SignKit or a separate provider? | Comparative corpus with digital, scanned, rotated, multilingual, low-DPI, handwritten, and mixed pages; evidence quality and latency measurements. |
| Can SignKit workflow recipes map to PDF Editor Organize? | Crosswalk for template revision, page identity, role/grant scope, idempotency, retry, quarantine, and recovery. |
| Is metadata-only workspace compatible with PDF Editor? | Confirmed privacy/storage ADR, metadata schema, source-byte boundary, auth/ownership model, and separate control-plane versus execution tests. |
| Are public SignKit claims current? | Fresh deployed route/content, checkout, privacy, and browser proof. Historical local or concept evidence is insufficient. |
| What belongs in a shared contract? | Two concrete consumers, compatible ownership/privacy semantics, fixtures, migration policy, and a rollback plan. |

## Immediate implications for this repository

1. Keep the prototype's full five-mode scope intact. React migration and the
   first Reader slice are architecture work, not a reduction of Understand,
   Complete, Organize, or Review.
2. Extend the existing PDF Editor contracts toward source-bound evidence,
   provider capability states, operation lineage, and validation receipts.
3. Treat SignKit integration as an adapter and contract problem. Do not import
   SignKit's private implementation or make this repository depend on its
   runtime by accident.
4. Add fixtures for signature asset provenance, OCR/evidence geometry, review
   decisions, operation recovery, and metadata-only topology before calling a
   shared path production-ready.
5. Keep static, local-runtime, browser-runtime, native-runtime, and deployed
   evidence separate in every future audit.
6. Revisit `task_plan.md` and the implementation map after the contract
   inventory is converted into executable fixtures and provider manifests.

## Relationship to existing PDF Editor exploration

The broader cross-project synthesis remains in
[`docs/cross-project-document-intelligence-exploration.md`](../cross-project-document-intelligence-exploration.md).
This document is the SignKit-specific expansion of that row, including the
web surfaces, metadata-only workspace, full capability inventory, ownership
boundary, and concrete crosswalk into the prototype's five modes.

The prototype-specific implementation boundary is in
[`docs/design-implementation-map.md`](../design-implementation-map.md). This
audit supplies the prior product and workflow evidence that map intentionally
did not have before this pass.

## Audit limitations

- This audit did not change the SignKit checkout.
- It did not claim current deployed SignKit parity from local source or prior
  reports.
- It did not claim browser-native PDF signing from the metadata-only workspace.
- It did not select a final OCR, vision, ML, cloud, or hybrid provider.
- It did not authorize Git staging, commits, pushes, deployment, or movement of
  document bytes across project boundaries.
