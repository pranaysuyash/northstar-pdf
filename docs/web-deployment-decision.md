# Long-Term Web Deployment Architecture: Browser Core and Local Companion

**Status:** Accepted product decision; companion implementation remains gated  
**Date:** 2026-08-24  
**Project:** `/Users/pranay/Projects/pdf_editor`  
**Decision owner:** Pranay  
**Evidence basis:** Tier 1 current-source research plus project-local contract,
browser, native, and corpus evidence  
**Canonical purpose:** Own the detailed analysis of the long-term web deployment
shape. The shorter decision summary lives in [`decisions.md`](decisions.md) as
D-009.

## Scope correction

The earlier version of this document framed the choice as a first-release
browser-only boundary. That was rollout sequencing language, not the product's
long-term scope. The long-term product is the complete native and web PDF
platform. The browser is the zero-install local core, and the explicitly
installed companion is the provider plane for OCR, high-fidelity editing, batch,
large-document, and other capabilities that need native runtime or stronger
provider support.

“Bounded” in this document means that a particular mutation has typed intent,
source binding, review state, coordinates, operation lineage, and validation.
It does not mean that the product is permanently limited to overlays or a small
first-release feature set.

## Executive decision summary

### Long-term accepted architecture

Build the web product as a browser-first, local-first core plus an explicitly
installed optional local companion capability plane. The long-term web product
includes OCR, high-fidelity editing, templates, batch processing, large-document
handling, and other capabilities when their provider, security, privacy,
licensing, and validation gates close. The browser core remains useful without
the companion, and the companion must never be a hidden runtime dependency.

This is the accepted long-term product architecture. It does not approve
packaging or shipping a companion immediately. Companion implementation and
provider adoption remain conditional on their admission gates.

The decision is capability-specific:

| Capability | Browser core | Explicit local companion | Long-term placement |
|---|---|---|---|
| OCR text and bounds | Optional bounded browser experiment where supported; never silent field truth | Yes, as a local worker with model/language provenance and bounds | PDF-to-image rendering, WASM/model assets, memory, multilingual calibration, and scanned-layout validation are separate runtime and evidence problems |
| Searchable OCR layer | No | Yes, only through a companion writer path that passes reopen and source-image preservation gates | Recognition output is not a safe PDF mutation by itself |
| High-fidelity existing-object editing | Not owned by the browser core without a provider that passes the gates | Candidate provider lane, then supported companion capability if cleared | pdf-lib does not provide arbitrary existing-text editing and current parity/preservation evidence is not a fidelity clearance |
| Arbitrary paragraph reflow | Long-term exploration, not silently implied by bounded overlays | Long-term provider and semantic-editing lane | Requires a distinct semantic-editing model and stronger preservation oracle |
| Bounded overlays, supported fields, and reviewed candidates | Yes where corpus and validation gates pass | Companion may offer an alternative provider | The browser proof and shared contracts already support this bounded intent |

The native macOS app continues to use local PDFKit and Vision lanes behind the
shared contracts. Native and web provider choices may differ while the long-term
product semantics remain shared.

### Browser core capability promise

The browser core may promise, subject to its capability-specific gates:

- local PDF open, rendering, navigation, thumbnails, search, text selection,
  links, outlines, metadata, and safe error states;
- inspection and filling of supported native PDF form fields;
- reviewed static blank-region suggestions with visible evidence and confidence;
- user-confirmed text, image, checkmark, date, stamp, signature-appearance, and
  annotation overlays where the provider and font/assets support the operation;
- page reorder, insert, delete, split, merge, rotate, and extract where the
  browser writer passes the corpus and reopen checks;
- export to a new file, immutable source handling, source-digest binding,
  operation lineage, reopen validation, and warning-qualified recovery states.

The browser core must not imply, without a matching provider and validation
report:

- reliable OCR for scanned PDFs or every target language;
- arbitrary editing or paragraph reflow of existing page text;
- lossless preservation of every imported AcroForm/XFA/signature/annotation
  structure;
- permanent redaction, cryptographic signing, or signature-validity claims;
- high-fidelity parity with every desktop PDF viewer;
- that a static visual box has become a real native form field;
- that browser storage is a backup or that a local-only path is an absolute
  privacy guarantee independent of browser, extension, and operating-system
  behavior.

### Companion direction

The companion is an opt-in capability plane, not a hidden runtime dependency. It
should expose a
versioned capability handshake and consume the same document, coordinate,
candidate-evidence, edit-operation, and validation contracts as the browser and
native adapters. It may provide stronger local OCR and provider lanes, but it
must not silently upload source bytes, silently mutate the source file, or
convert a provider success into a product-level preservation claim without the
same validation report.

## Why this decision is needed now

The project contains three different kinds of evidence that must not be
collapsed:

1. The native macOS slice demonstrates a PDFKit adapter, local Vision OCR
   integration, provider-neutral operations, and recovery-visible failures. It
   also retains a verified external AcroForm radio-choice preservation failure.
2. The browser proof demonstrates a PDF.js plus pdf-lib path for inspection,
   supported form operations, reviewed overlays, export, reopen, and contract
   emission against the existing corpus. Two provider-specific failures remain
   represented as failed validation outcomes.
3. The release registry still leaves OCR, independent-viewer reopen, native/web
   parity, browser export fidelity, large-document behavior, and provider choice
   open.

Therefore, “the browser can open and write a PDF” is not enough to promote OCR
or high-fidelity editing into a supported capability. The decision is about
runtime trust, distribution, licensing, recovery, and evidence burden within the
long-term platform.

## Decision invariants

Both deployment shapes must preserve these invariants:

| ID | Invariant | Consequence |
|---|---|---|
| WD-01 | The source PDF is immutable within a session | Every export is a derived copy or an explicitly authorized file-backed save; default behavior is new-copy export |
| WD-02 | Every mutation binds to a source digest and contract version | A stale inspection cannot be applied to a changed source |
| WD-03 | A native field and a static candidate are different types | Candidate detection never silently creates a native field or applies a value |
| WD-04 | Provider capability is explicit | Unsupported, unavailable, and unknown states remain visible rather than becoming generic success |
| WD-05 | Coordinates are page-space data | Viewport pixels are adapter state and cannot become persisted edit geometry |
| WD-06 | Validation is part of the operation result | Reopen, source binding, output integrity, and provider warnings are inspectable |
| WD-07 | Local processing is actually local | No source bytes, OCR images, or template content cross a network boundary without explicit user action and a separate policy |
| WD-08 | A fallback preserves semantic honesty | A browser overlay fallback is reported as an overlay, not as native form editing or arbitrary content editing |
| WD-09 | Recovery is deterministic | Failed or cancelled work leaves the source and prior validated session recoverable |
| WD-10 | The deployment shape is reversible | The browser UI and shared contracts do not depend on a particular companion provider |

## Options explored

### Option A: Browser-only first release

```text
browser UI
  -> PDF.js inspection/rendering
  -> shared contract and reviewed operation state
  -> pdf-lib bounded export
  -> browser worker and local storage boundaries
```

**Strengths**

- No installer, daemon, port, native-messaging host, or local process lifecycle.
- Source bytes can remain in browser memory or browser-local storage.
- PDF.js is an Apache-2.0 browser parsing/rendering foundation. pdf-lib is an
  MIT-licensed JavaScript writer with forms, drawing, page operations, and
  embedding capabilities.
- It is the smallest reversible experiment and directly extends the existing
  browser proof.
- It keeps the first learning slice narrow enough to test the form-completion
  wedge without defining the long-term PDF platform by the initial experiment.

**Costs and risks**

- pdf-lib does not render and does not provide APIs for editing ordinary page
  text outside form fields. It also does not support encrypted documents as a
  normal mutation path.
- Browser OCR requires a PDF-to-image rendering step, WASM execution, language
  data, memory, and accuracy evidence. It is not a free extension of text-layer
  extraction.
- Browser storage has quota, eviction, permission, and browser-compatibility
  behavior. File-backed save requires user permission where supported and needs
  a picker/download fallback.
- Large files and complex PDFs may exceed practical browser memory or expose
  provider-specific export failures.

**What it is allowed to claim:** bounded reader, supported native-field filling,
reviewed overlays, annotations, page operations, and validated new-copy export.

**What it is not allowed to claim:** general PDF editing, universal OCR, or
desktop-grade fidelity.

### Option B: Browser shell plus optional local companion

```text
browser UI
  -> shared contract and capability handshake
  -> browser provider for baseline work
  -> optional local RPC or extension bridge
       -> PDFBox / MuPDF / other provider lane
       -> OCR worker and language assets
       -> filesystem and batch processing
```

**Strengths**

- Preserves a zero-install baseline while making stronger capabilities available
  to users who explicitly install and trust the companion.
- Provides a place for OCRmyPDF/Tesseract, PDFBox, native Vision, or a MuPDF
  lane without forcing those runtime and licensing costs into every browser
  session.
- Better fit for large documents, batch queues, process isolation, cancellation,
  temporary-file control, and provider-specific validation.
- Makes capability negotiation and provenance visible in the product model.

**Costs and risks**

- Adds installer, signing/notarization, update, uninstall, support, crash,
  permissions, version skew, and platform coverage work.
- A browser-to-companion bridge becomes a security boundary. A localhost port
  or extension bridge must use origin allowlisting, authenticated sessions,
  request limits, source-digest binding, capability versioning, cancellation,
  and safe path handling. A generic “run this command” endpoint is prohibited.
- The companion can create a false sense of fidelity if it returns a PDF that
  opens but silently changes fields, annotations, signatures, structure, or
  unrelated page content. The shared validation contract remains mandatory.
- License review becomes per packaged provider and transitive dependency, not
  only per npm or Swift package.

**What it is allowed to claim:** only the capabilities supported by the installed
provider manifest and the corpus gates for that provider. Companion presence is
not itself evidence of fidelity.

### Option C: Companion-required browser architecture

This makes the browser UI a client of an installed local service and routes OCR,
high-fidelity export, or selected PDF processing through that service.

**Why it is attractive:** it can reduce browser writer limitations and make the
provider boundary more centralized.

**Why it is not recommended:** it converts a web release into a desktop
installation project, removes the lowest-friction reader path, and makes every
browser user pay the lifecycle cost before the product wedge is validated. It
also creates a larger failure surface before the companion protocol and
provider choice have corpus evidence.

### Option D: Hosted or self-hosted processing

```text
browser/native UI -> authenticated API -> PDF/OCR worker -> object store/exports
```

This is appropriate for collaboration, shared templates, batch processing,
centralized policy, and enterprise administration. It is a separate deployment
lane because it changes the source-of-truth and
privacy model. It requires explicit retention, deletion, encryption, tenant
isolation, access control, audit, egress, and incident-response decisions. It
should remain a later deployment lane rather than a hidden substitute for a
local companion.

## Capability placement

| Capability | Browser core | Optional companion | Native macOS now | Long-term product placement |
|---|---|---|---|---|
| Reader, navigation, search | Yes, PDF.js baseline | May accelerate large files | PDFKit slice | Core capability |
| Native field inspection | Supported subset, provider-gated | Stronger provider candidate | PDFKit adapter, external failure retained | Shared capability, provider-gated |
| Static blank-box detection | Product-owned reviewed candidates | OCR/layout evidence may improve suggestions | Vector detector, Vision adapter | Always review before operation |
| Text/image/checkmark overlays | pdf-lib bounded path | Provider-specific alternative | PDFKit adapter | First editing lane |
| Page operations | pdf-lib where corpus passes | PDFBox/MuPDF control lane | Native provider | Shared capability, provider-gated |
| OCR text and bounds | Bounded experiment where supported | Tesseract/OCRmyPDF/native Vision lane | Vision evidence path | Shared evidence capability, never silent field creation |
| Searchable OCR layer | Deferred | OCRmyPDF or dedicated writer | Separate native worker | Requires OCR and output validation gates |
| Existing-object semantic editing | Not owned without a cleared provider | Candidate provider experiment | Unknown beyond bounded adapter | Long-term capability, provider-gated |
| Arbitrary paragraph reflow | Long-term exploration | Long-term provider and semantic-editing lane | No | Separate architecture decision |
| Permanent redaction | No | Isolated provider/security lane | Separate lane | Later and security-gated |
| Cryptographic signatures | No claim | Dedicated signing/validation lane | Dedicated lane | Later and independently verified |
| Large/batch processing | Best-effort browser limits | Strong companion use case | Background native work | Companion differentiator |
| Recurring templates | Local reviewed design | May accelerate local batch use | Local store | Separate privacy-first contract |

## Current-source research findings

### Browser reader and writer

Mozilla describes PDF.js as a web-standards-based platform for parsing and
rendering PDF documents, distributed under Apache-2.0. Its documented layers
separate parsing, display, and viewer concerns. That makes it a strong browser
reader and inspection base, not a complete writer.

The pdf-lib project is MIT licensed and documents modification of existing PDFs,
forms, page operations, drawing, images, fonts, and metadata. Its own limitation
section says it cannot extract ordinary page text or remove/edit ordinary page
text outside form fields, and it does not support encrypted documents as a
normal load/mutation path. This directly supports the existing project choice:
PDF.js for reading and pdf-lib for bounded writes, with no claim of arbitrary
semantic editing.

Sources: [PDF.js](https://github.com/mozilla/pdf.js/), [PDF.js getting
started](https://mozilla.github.io/pdf.js/getting_started/), [pdf-lib
README](https://github.com/Hopding/pdf-lib).

### Browser storage and file access

The File System Access API requires user interaction and permission for
ordinary file reads and writes where supported. OPFS is origin-private storage
with browser quota and is available to workers; IndexedDB stores structured data
and blobs but is subject to browser-specific quota and eviction behavior. The
web product therefore needs explicit `ephemeral`, `localDraft`, and
`fileBacked` modes, a new-copy default, and a download fallback. “Local-first”
means the application does not send bytes to a service by default. It does not
mean browser storage is durable backup or that browser behavior is uniform.

Sources: [File System API](https://developer.mozilla.org/en-US/docs/Web/API/File_System_API),
[OPFS](https://developer.mozilla.org/en-US/docs/Web/API/File_System_API/Origin_private_file_system.),
[IndexedDB](https://developer.mozilla.org/en-US/docs/Web/API/IndexedDB_API).

### Browser OCR

Tesseract.js runs Tesseract through WebAssembly and workers. Its documentation
states that PDF input is not supported directly. A browser flow must render PDF
pages to images, then recognize those images, and must package or fetch worker,
WASM, and language assets. The project also documents that handwritten text is
not supported by the standard Tesseract.js model. This makes browser OCR
possible as an experiment, but not a supported browser-core promise for
scanned, multilingual, or handwriting-heavy forms without a corpus benchmark.

Sources: [Tesseract.js project scope and FAQ](https://github.com/naptha/tesseract.js/blob/master/docs/faq.md),
[Tesseract.js local installation](https://github.com/naptha/tesseract.js/blob/master/docs/local-installation.md),
[Tesseract OCR engine](https://github.com/tesseract-ocr/tesseract).

### Permissive companion candidates

Apache PDFBox is an Apache-2.0 Java library that documents existing-document
manipulation, Unicode text extraction, form filling, rendering to images,
preflight, merging/splitting, and digital signing. It is the strongest current
permissive control lane for a local process or server, but its feature list is
not proof of preservation on this corpus. It brings Java packaging and process
lifecycle decisions.

Tesseract is Apache-2.0, but OCR recognition is not document-layout semantics.
An adapter must return recognized text, bounds, language/model provenance,
confidence, and warnings. It must not create fields or edit operations directly.

Sources: [Apache PDFBox](https://pdfbox.apache.org/), [Tesseract
installation and license](https://github.com/tesseract-ocr/tessdoc/blob/main/Installation.md).

### High-fidelity and OCR companion candidates with material license or runtime boundaries

MuPDF.js is an official WebAssembly binding that documents rendering, text,
structured text, annotations, widgets, redactions, page operations, and saving.
The MuPDF project and release site state an AGPL/commercial licensing boundary
for embedding. It is technically attractive for a high-fidelity lane, but it
cannot be adopted as an unexamined permissive default.

OCRmyPDF adds a searchable OCR layer and PDF/A-oriented processing. Its current
documentation identifies Ghostscript as a required dependency and warns that
the tool is not designed to be secure against malware-bearing PDFs. The
OCRmyPDF core is MPL-2.0, while dependencies and the packaged execution path
require separate review. This is a companion/worker concern, not a browser
bundle convenience.

Sources: [MuPDF.js](https://github.com/ArtifexSoftware/mupdf.js/), [MuPDF
releases and licensing](https://mupdf.com/releases), [OCRmyPDF
introduction](https://ocrmypdf.readthedocs.io/en/stable/introduction.html),
[OCRmyPDF documentation](https://ocrmypdf.readthedocs.io/en/latest/).

### Native macOS lane

The existing native app can continue using PDFKit behind the shared adapter and
Vision for local text recognition. Apple documents Vision text recognition as
returning recognized-text observations, and Apple sandbox documentation makes
user-selected file access and security-scoped persistence explicit. This is a
strong native path for the current macOS product, but it is not evidence that a
browser release should inherit PDFKit behavior or that the web companion is
already architecturally settled.

Sources: [Apple Vision text recognition](https://developer.apple.com/documentation/vision/vnrecognizetextrequest),
[Apple macOS sandbox file access](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox).

### Companion bridge and installation

If the companion is later implemented as a browser extension plus native host,
browser native-messaging documentation shows that the native application is
installed by operating-system machinery, the extension needs a native-messaging
permission, the host manifest allowlists the extension, and messages cross a
JSON stdin/stdout boundary. A localhost RPC bridge has different mechanics but
the same product obligations: authenticated origin binding, capability
negotiation, request limits, cancellation, version skew handling, and safe
failure. The bridge must be a narrow typed operation service, not arbitrary
filesystem or shell access.

Source: [MDN native messaging](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Native_messaging).

## Privacy and security comparison

| Concern | Browser-only | Optional companion | Required control |
|---|---|---|---|
| Source bytes | In memory or browser-local state by default | Browser or companion local process | No network egress by default; visible provenance |
| File permissions | Picker/permission APIs vary by browser | OS installer and process permissions | Least privilege and new-copy export |
| Persistence | Quota and eviction are possible | Local files/temp store are controllable but must be cleaned | Explicit storage mode and recovery copy |
| OCR assets | WASM/model/language assets in browser | Local model/language files | Version and hash assets; no secret-bearing logs |
| IPC | None | Extension or local RPC boundary | Authenticated session, origin allowlist, digest binding, size/time limits |
| Provider risk | Browser dependency and bundle updates | More binaries, CVEs, sandboxing, updates | Dependency inventory, pinned versions, security response |
| Source integrity | Browser operation log and digest | Same contract plus bridge request binding | Reject stale source and unknown validation states |
| User understanding | Low installation friction | Explicit installation and capability UI | Never hide companion use or imply universal support |

The companion should be treated as a local service with an attack surface even
if it never sends data over the network. A minimum future threat model should
cover malicious PDFs, oversized inputs, decompression/resource exhaustion,
malformed IPC, origin spoofing, stale/replayed operations, temp-file leakage,
provider crashes, privilege escalation, and downgrade/version-skew behavior.

## Licensing and distribution comparison

| Component | Current source signal | Product implication |
|---|---|---|
| PDF.js | Apache-2.0 | Permissive browser baseline; preserve notices and dependency inventory |
| pdf-lib | MIT | Permissive bounded browser writer; limitations remain architectural |
| PDFBox | Apache-2.0 | Permissive companion control lane; review Java runtime packaging and dependencies |
| Tesseract | Apache-2.0 | Permissive OCR engine; models and language packs still need inventory |
| Tesseract.js | Apache-2.0 project signal | Browser WASM option; direct PDF limitation and asset/runtime cost remain |
| OCRmyPDF | MPL-2.0 core; dependency licenses vary | Isolate and review the full packaged dependency path |
| MuPDF / MuPDF.js | AGPL or commercial | Requires AGPL-compatible distribution or commercial license review |
| Ghostscript | AGPL dependency in current OCRmyPDF documentation | Material companion distribution and security review |
| PDFKit | Apple platform framework | Native macOS lane only; not a cross-platform open-source provider |

This is a research signal, not legal advice. Before shipping any companion,
the project needs an exact dependency manifest, notices, source/offer
obligations where applicable, static/dynamic/WASM packaging review, and a
commercial-license decision if MuPDF is selected.

## Proposed rollout and migration

### W0: Browser core

1. Keep the existing PDF.js/pdf-lib proof and shared contract fixture as the
   browser baseline.
2. Add native/web normalized parity comparison for the existing corpus.
3. Define the supported browser PDF classes and explicitly display unsupported
   OCR, XFA, encrypted, signature, and fidelity states.
4. Complete browser export fidelity, independent-viewer, rotated-page,
   malformed-input, and large-document gates before widening the promise.
5. Keep OCR behind an unavailable/experimental capability state.

### C0: Companion protocol design only

Define, but do not yet require, a companion capability contract containing:

- protocol and contract major/minor version;
- provider ID, provider version, license signal, and supported operation kinds;
- supported input classes, maximum bytes/pages, language/model IDs, and limits;
- local processing declaration and network-egress policy;
- source digest and operation lineage binding;
- progress, cancellation, structured errors, and validation report;
- installer/runtime health, update channel, and removal/recovery behavior.

### C1: Companion experiment

Start only after the accepted decision's admission trigger is met: a declared
workflow or corpus class cannot be served by the browser promise, and users or
the product owner accept installation friction. Compare PDFBox and one
high-fidelity candidate against the same corpus. Keep OCR as a separate worker
lane. Measure capability delta rather than accepting a broad feature list as
proof.

### Migration rule

The browser UI, template system, operation log, and validation report must not
depend on companion-specific objects. A future companion adds an adapter and an
optional capability provider. Existing browser sessions remain readable when the
companion is absent. If a provider is removed, the UI falls back to the
browser-supported operation subset and preserves the unsupported reason.

## Validation gates for the decision

### Browser-only release gate

The browser-only recommendation is viable only when all of these are true for
the declared supported corpus:

- reader and contract emission work for each fixture;
- every supported mutation is source-bound and reversible;
- output reopens in the browser and in the declared independent validator/viewer
  set;
- page geometry and coordinate transforms pass rotated/crop-box cases;
- unsupported, failed, warning, and unknown states remain distinct;
- browser memory/time limits and storage failures have visible recovery;
- no user-facing control implies OCR or arbitrary editing when those lanes are
  not enabled.

### Companion capability admission gate

An installed companion is justified only when:

- a declared capability or measured workflow has a material provider gap that
  the companion can plausibly address, or the experiment is justified by the
  long-term capability program;
- the exact provider and dependency license path is acceptable;
- a signed/notarized installation and update story exists for each supported OS;
- the bridge threat model and negative tests are complete;
- source digest binding, capability negotiation, cancellation, and recovery are
  exercised;
- the companion produces a measurable improvement on the target corpus, not just
  a larger feature list;
- the user can complete the core workflow with the companion unavailable.

### Decision falsifiers

Reopen the architecture if any of these become true:

- a target corpus is predominantly scanned or handwriting-heavy and the selected
  OCR execution plane cannot meet the defined acceptance thresholds;
- a required browser-core form class repeatedly fails browser export or
  independent-viewer preservation;
- browser memory, runtime, or storage limits make the core workflow unreliable
  on target hardware and browsers;
- the long-term product requires a capability that cannot be represented across
  the browser core and companion plane without breaking shared semantics;
- the product chooses a provider whose license or platform needs a companion;
- collaboration, central policy, or shared templates becomes the first-order
  requirement, which would trigger the separate hosted/self-hosted decision.

## Assumption ledger

| Assumption | Why needed | Current evidence | If false | Revisit trigger |
|---|---|---|---|---|
| The bounded completion wedge is valuable as the first learning slice | Keeps the initial implementation testable without limiting the long-term platform | Proposed product direction and current browser/native slice | The product needs a different primary workflow | User research shows another workflow is the durable core |
| The existing corpus is representative enough for the next experiment | Allows provider and contract evidence to advance | Current manifest and browser fixture audit | Evidence is overfit to easy fixtures | Add scanned, rotated, encrypted, malformed, large, and hybrid samples |
| Browser-local processing is valuable as the zero-install core | Preserves privacy and reduces operational burden | Local-first architecture and current proof | Some capabilities need companion or hosted execution | User research or support evidence changes deployment needs |
| A companion can be added without changing shared product truth | Preserves reversibility | Versioned shared contracts and provider boundaries | Contract redesign is required | Companion needs semantics not represented by current operations/validation |
| Permissive licensing is the default product preference | Avoids premature copyleft obligations | Existing landscape and D-002/D-006 gates | MuPDF or other provider becomes economically necessary | Owner approves a commercial or AGPL path |

## Remaining implementation questions and ownership

| Question | Owner | Required evidence |
|---|---|---|
| Which PDF classes are in the first supported promise? | Project owner plus implementation | Support policy and corpus matrix |
| Which OCR languages and document types matter first? | Project owner | Corpus inventory and OCR threshold definition |
| Is an installed companion justified for a specific workflow? | Project owner | Browser failure evidence plus observed workflow or user research |
| Is AGPL/commercial licensing acceptable? | Project owner plus legal review if needed | Exact package and distribution review |
| Which independent viewer/validator set is authoritative for release? | Implementation and reviewer | Release gate decision and reproducible runbook |
| What is the companion transport if C1 opens? | Architecture owner | Threat model and protocol prototype |

## Rejected or deferred alternatives

- **Single engine everywhere:** rejected because native PDFKit, browser PDF.js,
  and optional high-fidelity providers have different platform and license
  constraints; shared semantics are more durable than shared provider APIs.
- **MuPDF everywhere immediately:** deferred because technical breadth does not
  resolve AGPL/commercial licensing or current corpus fidelity evidence.
- **Browser OCR as automatic field creation:** rejected because OCR evidence is
  uncertain recognition output, not field semantics or user authorization.
- **OCRmyPDF in the browser bundle:** rejected because it is a process-oriented
  OCR/PDF pipeline with external dependency, security, and license boundaries.
- **Required companion on day one:** rejected because it increases release
  friction and failure surface before the browser core and companion protocol
  have been measured.
- **Hosted processing as a silent fallback:** rejected because it changes the
  privacy, retention, and source-of-truth model.

## Completeness statement

### Established current state

The native slice, shared contracts, browser fixture, existing corpus, provider
benchmarks, release registry, and current open-source landscape were inspected.
The project has browser evidence for a bounded PDF.js/pdf-lib path, not full
web/native fidelity. Native PDFKit still has a verified imported-radio-choice
preservation failure. OCR, large-document behavior, independent-viewer reopen,
and native/web parity remain open gates.

### Accepted long-term state

The long-term web architecture is a browser-first local core plus an explicitly
installed optional companion capability plane. OCR and high-fidelity editing
belong in that plane when their provider, security, licensing, packaging, and
validation gates close. The companion remains optional to install and is not a
hidden dependency. This document records the architecture, protocol obligations,
rollout, and falsifiers. It does not implement or approve the companion.

### Migration confidence

Migration confidence is high for the shared intent and validation layer because
the versioned contracts and operation lineage already exist. Migration
confidence is low for provider fidelity until the same corpus passes the native,
browser, and any future companion lanes with independent validation.

### Remaining gates, not unresolved deployment decisions

The deployment shape is decided. The support corpus, OCR languages, target
browsers, companion transport, provider choice, licensing posture, installer,
and beta admission thresholds still need explicit values. These are
implementation and release gates, not reasons to collapse the long-term
browser-core and companion architecture.

### Known blind spots

This pass did not run a new OCR accuracy benchmark, package a companion, test
Windows/Linux companion installation, measure browser memory across target
hardware, obtain legal advice, or conduct fresh user research. It also did not
claim that MuPDF, PDFBox, OCRmyPDF, or Tesseract preserves this project’s corpus.

## Source ledger

The current-source facts in this document were checked on 2026-08-24. Primary
sources are linked inline above. Project-local evidence is linked here:

- [`docs/browser-pdf-proof.md`](browser-pdf-proof.md)
- [`docs/audits/browser-contract-fixture-evidence-2026-08-24.md`](audits/browser-contract-fixture-evidence-2026-08-24.md)
- [`docs/audits/contract-negative-test-evidence-2026-08-24.md`](audits/contract-negative-test-evidence-2026-08-24.md)
- [`docs/shared-contracts.md`](shared-contracts.md)
- [`docs/native-web-platform-matrix.md`](native-web-platform-matrix.md)
- [`docs/open-source-landscape.md`](open-source-landscape.md)
- [`docs/release-gates.md`](release-gates.md)
- [`docs/decisions.md`](decisions.md)
- [`findings.md`](../findings.md)

**Revisit trigger:** the long-term capability map changes, a new provider is
selected, a license review changes the viable set, the support corpus changes,
or a browser/companion experiment falsifies the architecture.
