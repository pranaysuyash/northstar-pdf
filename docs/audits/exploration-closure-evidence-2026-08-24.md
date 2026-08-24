# PDF exploration closure and implementation boundary

**Date:** 2026-08-24  
**Project:** `/Users/pranay/Projects/pdf_editor`  
**Evidence tier:** Tier 1 research/static inspection at exploration close; later
bounded implementation evidence is recorded below  
**Purpose:** preserve the exact state of the feature exploration, its exclusions,
and the decision required before broad web implementation

## Closure statement

The exploration pass is closed as a documented research and architecture
baseline. At the time of that closure:

- The workspace already contained a native macOS SwiftUI/PDFKit prototype,
  PDFKit benchmark artifacts, and provider-neutral document/operation concepts.
- The feature frontier and native/web platform matrix were documented.
- The open-source provider landscape and license boundaries were documented.
- The shared product boundary was bounded completion, reviewed overlays,
  annotations, page operations, OCR as a separate capability, and export
  validation.
- Arbitrary text reflow, permanent redaction, cryptographic signatures,
  silent static-field conversion, collaboration, and hosted processing were not
  approved as first-build assumptions.
- The web surface was intentionally paused at the exploration boundary. No web
  implementation was part of that research-only closure claim.
- The native slice and web surface were explicitly separate tracks. Native
  provider hardening could continue while the web lane waited for shared
  contract review.

## Subsequent decision addendum

The exploration closure above is historical and correctly records that the
deployment choice was open at that time. On 2026-08-24, D-009 and
[`docs/web-deployment-decision.md`](../web-deployment-decision.md) resolved the
long-term architecture: the browser is the zero-install local core, while OCR
and high-fidelity editing belong in an explicitly installed optional companion
capability plane. This later decision does not retroactively turn the historical
research closure into web implementation evidence or approve companion
packaging. It also does not make the initial bounded slice the ceiling of the
product.

## Artifacts that establish the exploration baseline

- [Feature frontier](../pdf-feature-frontier.md): feature taxonomy, product
  boundary, open-source composition, non-goals, and discovery gates.
- [Native/web platform matrix](../native-web-platform-matrix.md): shared model,
  platform adapters, storage modes, worker boundaries, and deployment shapes.
- [Open-source landscape](../open-source-landscape.md): PDF.js, pdf-lib, PDFBox,
  qpdf, pikepdf, MuPDF/MuPDF.js, Poppler, PoDoFo, OCRmyPDF, Tesseract, and
  Stirling PDF comparison.
- [Research findings](../../findings.md): source-backed technical findings and
  provider constraints.
- [Task plan](../../task_plan.md): phase status, stopping conditions, provider
  gates, and next implementation checkpoint.
- [Progress log](../../progress.md): dated exploration, native implementation,
  contract, browser proof, and template-design entries.
- [Decision records](../decisions.md): architecture decision and later
  superseding implementation decisions.

## Exact decision point at exploration close

The unresolved product decision was:

> Must the first web release remain browser-only, or should OCR and
> high-fidelity editing be provided through an explicitly installed local
> companion?

The alternatives were:

| Option | Value | Cost or risk | Evidence required |
|---|---|---|---|
| Browser-only first | Lowest installation and privacy-operating burden; PDF.js and pdf-lib are easy to distribute | Browser provider fidelity, OCR quality, large-file performance, and offline dependency bundling remain bounded | Same reviewed corpus through reader, candidate, overlay/form export, reopen, and independent comparison |
| Browser plus local companion | Stronger OCR, filesystem, and high-fidelity provider options | Installation, lifecycle, local RPC security, updates, port/authentication, and support burden | Companion threat model, provider/license gate, failure recovery, and measured corpus benefit |
| Hosted or self-hosted processing | Collaboration and batch become easier | Changes source-byte privacy, retention, tenant isolation, deletion, encryption, and operational ownership | Separate privacy, security, retention, and deployment decision |

The research baseline recommended starting browser-only for the bounded reader and
overlay/form experiment, while keeping a companion as an explicit fallback if
the corpus falsifies browser-only fidelity or OCR sufficiency. It did not select
the final provider for all future PDF capabilities.

## Later phase boundary and supersession

After the exploration closure, the project entered later implementation phases:

1. The shared native/web contracts were implemented and tested in
   [`Sources/PDFEditorCore/SharedContracts.swift`](../../Sources/PDFEditorCore/SharedContracts.swift)
   and additive `DocumentModel` fields.
2. A bounded browser proof was implemented in
   [`web/index.html`](../../web/index.html) using PDF.js and pdf-lib.
3. The browser proof was exercised against the existing public AcroForm and
   Form 6 static corpus. Evidence is recorded in
   [`browser-pdf-proof-evidence-2026-08-24.md`](browser-pdf-proof-evidence-2026-08-24.md).
4. A privacy-first recurring-template design was then added in
   [`template-system-design.md`](../template-system-design.md), with T1 local
   reviewed template capture as the current next implementation slice.

These later phases do not invalidate the exploration closure. They supersede
the old “web not started” state for the bounded proof only. They do not upgrade
the browser proof into full web/native parity or settle the browser-only versus
local-companion decision for OCR, arbitrary object editing, or high-fidelity
operations.

## Verification performed for this closure record

- Current files were inspected before documentation changes.
- The workspace remains a non-Git project; no Git staging, commit, branch, or
  remote mutation was performed.
- README links to the feature frontier, shared contracts, browser proof,
  template design, decisions, implementation status, and progress records.
- The web source contract test passes with 37 checks.
- The existing browser proof remains separately documented as Tier 3/4 evidence;
  this closure record does not recategorize its runtime results as research
  evidence.

## Current next decision

The original platform decision remains open for future OCR and high-fidelity
work. The immediate implementation checkpoint is narrower:

> Implement T1 local reviewed template capture, or revise the product boundary
> before template persistence is added.

T1 must not introduce profile values, silent autofill, cloud sync, or a second
  PDF engine. Its acceptance evidence is defined in
  [`template-system-design.md`](../template-system-design.md): contract
  round-trips, no-raw-content assertions, reviewed mapping capture, wrong-source
  rejection, failed-export no-learning, revision lineage, and native/web
  semantic parity.

## Bounded completion exploration update

The owner subsequently chose a narrower implementation experiment before
template persistence: make the existing suggestion surface genuinely usable in
both native and web lanes. This does not reopen the rejected product boundaries.
It tests the smallest useful question: **when a PDF has no native fields, can a
user understand a suggestion, act on it, recover from a mistake, and finish a
document without treating a heuristic as truth?**

### Explored interaction frontier

| Frontier node | Current behavior | Evidence | Open question |
|---|---|---|---|
| Candidate visibility | Page-space highlights identify suggested regions | Browser workflow test and local runtime | Does highlighting remain legible on dense, rotated, and zoomed pages? |
| Candidate review | Evidence, confidence, and text entry are shown before apply | Browser workflow test; native source/build | Does evidence wording improve acceptance decisions? |
| Candidate rejection | Dismissed suggestions leave the active queue and can be restored | Browser workflow test | Should dismissal persist across sessions or remain session-only? |
| Reversible completion | Text is an overlay operation, with edit and undo | Browser workflow test; export proof | What outside-region visual-diff tolerance is acceptable? |
| Manual fallback | User clicks page space and adds text when suggestions are insufficient | Browser workflow test; native implementation | Should manual placement support resize and alignment before images? |
| Cross-lane meaning | Native and web map to the same candidate/status/edit concepts | Shared contracts and implementation status | Where do PDFKit and pdf-lib diverge under the broader corpus? |
| Detector abstention | Small unlabeled cells are withheld instead of flooding the queue | Form 6 native fixture guard: fewer than 100 candidates | Can grouped character cells become one accurate field without false positives? |

### Decision and boundary

This exploration supports keeping `suggested`, `confirmed`, and `rejected` as
first-class candidate states, and keeping manual placement as a separate path.
It does not support auto-application, silent native-field creation, arbitrary
existing-text rewrite, cloud processing, or a production claim about PDF
fidelity. The next high-value experiments are reviewed candidate benchmarks,
rotated/crop-box coordinate cases, assistive-technology observation, and
independent-viewer export checks.

## Consolidated exploration-pass record

This section consolidates the completion report that was previously distributed
across the feature, platform, provider, decision, plan, and progress documents.
It is the single retrieval point for what the exploration established and what
it deliberately did not establish.

### Established workspace state

- The canonical project is the existing `/Users/pranay/Projects/pdf_editor`.
- It contains a native macOS SwiftUI/PDFKit prototype, PDFKit benchmark
  artifacts, provider-neutral contracts, browser proof artifacts, and research
  documents.
- The project remains non-Git. No duplicate project was created and no Git
  staging, commit, branch, remote, or source-PDF mutation was performed for the
  exploration record.
- The native and web lanes remain separate tracks. Native provider hardening can
  continue without implying that a web provider or companion has been selected.

### Feature frontier recorded

The feature taxonomy and platform matrix cover:

- reader fundamentals, navigation, search, text selection, links, outlines, and
  metadata;
- native AcroForm inspection and filling;
- static blank-box and entry-region detection as reviewed candidates;
- human-reviewed text, image, checkmark, date, stamp, signature-appearance, and
  annotation overlays;
- page reorder, insert, delete, split, merge, rotate, extract, and compare;
- OCR-backed search and extraction as a separate evidence-producing capability;
- redaction, cryptographic signatures, accessibility, persistence, export,
  recovery, and validation gates;
- deliberate non-goals for arbitrary paragraph reflow, silent field creation,
  permanent redaction, cryptographic claims, collaboration, and hosted
  processing in the first bounded slice.

Canonical detail: [`pdf-feature-frontier.md`](../pdf-feature-frontier.md) and
[`native-web-platform-matrix.md`](../native-web-platform-matrix.md).

### Architecture recorded

```text
Shared product contracts
  ├─ document facts
  ├─ page-space coordinates
  ├─ native field model
  ├─ static candidate evidence
  ├─ typed edit operations
  ├─ undo/replay
  └─ export validation

Native macOS adapter
  └─ PDFKit, SwiftUI/AppKit, Vision or local OCR workers

Web adapter
  └─ PDF.js, pdf-lib, Web Workers, IndexedDB/OPFS,
     file-picker/download fallback

Optional companion lane
  └─ PDFBox or MuPDF, OCR workers, batch processing,
     high-fidelity operations
```

The shared layer owns user intent, coordinate semantics, candidate evidence,
operation lineage, and validation outcomes. It does not force PDFKit, PDF.js,
pdf-lib, PDFBox, or MuPDF to expose the same provider API or produce byte-
identical output.

### Provider roles recorded

- Native macOS: continue the PDFKit adapter behind the provider-neutral core;
  preserve its known external AcroForm radio-choice failure as an open gate.
- Web reader: PDF.js for browser parsing, rendering, text inspection,
  annotations, and form display.
- Web writer: pdf-lib for bounded drawing, supported form operations, page
  operations, images, fonts, and saving. It is not treated as an arbitrary
  semantic editor.
- Companion/control lane: evaluate Apache PDFBox as the permissive JVM option;
  keep MuPDF/MuPDF.js behind an AGPL/commercial and corpus decision.
- OCR: keep recognition output separate from field semantics. OCR produces text,
  bounds, confidence, language/model provenance, and warnings. It does not
  silently create fields or operations.

### First shared product boundary

The first cross-platform boundary is bounded completion rather than universal
PDF editing:

1. PDF reading and navigation.
2. Native AcroForm inspection and filling where provider gates pass.
3. Static blank-box and entry-region suggestions with evidence, confidence,
   bounds, and label association.
4. Human-reviewed overlays and annotations.
5. Page operations where export and reopen checks pass.
6. OCR-backed search and extraction only when the OCR lane is explicitly
   available and validated.
7. Undo, immutable source handling, new-copy export, reopen checks, and
   validation reports.

The central safety rule is unchanged: a native field has PDF semantics; a
detected box or blank line is only a probabilistic suggestion. The user must
confirm a candidate before it becomes an edit, and a reviewed overlay remains
distinct from creating a real AcroForm field.

### Implementation boundary and evidence status

- The shared native/web contracts are implemented and tested.
- The browser PDF.js/pdf-lib proof is implemented and exercised against the
  existing corpus, including explicit failed provider outcomes.
- Native negative and mutation tests cover stale source digests, unsupported and
  destructive operations, unknown validation states, and coordinate mismatches.
- These artifacts establish contract and bounded workflow evidence. They do not
  establish full native/web parity, universal PDF fidelity, OCR accuracy,
  independent-viewer preservation, or companion readiness.
- The exact current deployment recommendation and its falsifiers are maintained
  in [`web-deployment-decision.md`](../web-deployment-decision.md), D-009, and
  RG-090.

### Consolidated verification record

- Markdown links were checked across the project with no missing relative
  targets after correcting two pre-existing benchmark/runbook paths.
- The browser reader/completion contract check passed 37 checks.
- The full native suite passed 23 tests in 3 suites.
- The doctrine family remained intact after regenerating project context.
- No OCR benchmark, companion package, installer, legal review, user research,
  new dependency, or companion runtime was started in this documentation pass.

This consolidated record is a summary and routing surface. The detailed
feature, provider, contract, deployment, and validation documents linked above
remain the canonical sources for their respective knowledge types.

## Cross-project exploration addendum

**Date:** 2026-08-24  
**Status:** Evidence update to the closure record; no provider or dependency
adoption decision

The exploration was widened to the relevant local OCR, parser, signature,
metadata, and form projects. The detailed source inventory and synthesis are in
[`../cross-project-document-intelligence-exploration.md`](../cross-project-document-intelligence-exploration.md).

The inspected sources include SignKit, MetaExtract, Invoice Intelligence,
PhotoSearch, extracted_forms, and a historical web signature detector. The
transferable patterns are native-first inspection, region-level OCR evidence,
candidate review and abstention, hard-negative mining, reviewed correction
events, schema/provenance registries, hybrid routing, validation families,
corpus separation, and visible privacy/claim boundaries.

This addendum does not mean that adjacent code, models, fixtures, or data may be
copied into the PDF editor. The current decision is to create a cross-project
evidence ledger and native/web semantic parity fixture before importing any
runtime capability. Neighboring repositories were inspected read only in this
pass. Their runtime health, exact license clearance, fixture consent, and
redistribution compatibility remain unknown unless separately verified.
