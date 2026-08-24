# ihatepdf.cv Exploration

**Date:** 2026-08-24  
**Status:** Current-source competitor and architecture exploration  
**Scope:** Product surface, browser architecture, privacy claims, feature
opportunities, safety boundaries, and implications for this PDF editor  
**Evidence level:** Tier 1 current web/static inspection unless explicitly
marked as a proposed experiment or an unverified site claim

## Executive summary

[ihatepdf.cv](https://www.ihatepdf.cv/) is a broad, zero-friction, browser-first
PDF toolkit positioned around four promises:

1. no watermark;
2. no sign-up;
3. local/browser processing for ordinary PDF workflows;
4. a large free tool catalog.

The home page currently advertises 46 tools covering PDF reading and editing,
page operations, conversion, OCR, encryption, password removal, redaction,
flattening, privacy scanning, AI chat and summarization, repair, scanning, P2P
sharing, collaboration, and business utilities. The site positions all of this
as free, local, offline-capable, and without a file-size or file-count limit on
the main product surface.

The public [technical blog](https://www.ihatepdf.cv/technical-blog) describes a
composition based on PDF.js 3.11.174, pdf-lib 1.17.1, WebAssembly, Web Workers,
IndexedDB, localStorage for metadata, volatile RAM for active processing,
device-adaptive limits, batch processing, and explicit canvas memory release.
The public PWA manifest and service worker reinforce an installable browser
surface and cache-based library loading.

The strongest lesson for this project is architectural composition, not feature
count. ihatepdf.cv demonstrates how a local PDF engine can become a product
surface with many small tools. Our differentiator should remain the safer
completion workflow: identify native fields and reviewed static candidates,
make the evidence visible, bind operations to the source digest, preserve
unrelated content where the corpus supports the claim, and validate every
export.

## Source and observation register

| Source | What it establishes | Status |
| --- | --- | --- |
| [Home and tool catalog](https://www.ihatepdf.cv/) | Advertised tool breadth, no-watermark/no-sign-up/local-processing positioning, and product categories | Observed current page |
| [Text editor](https://www.ihatepdf.cv/edit-pdf-text) | In-place text editing, font matching claims, OCR fallback, text/image/signature/whiteout/annotation tools | Observed claims; implementation quality unverified |
| [OCR PDF](https://www.ihatepdf.cv/ocr-pdf) | Tesseract.js/WebAssembly OCR, language selection, searchable invisible text layer, local processing claims | Observed claims; OCR accuracy and output fidelity unverified |
| [Technical blog](https://www.ihatepdf.cv/technical-blog) | Described libraries, storage tiers, memory model, device adaptation, batching, compression, AI text flow, service worker, and privacy model | Public technical explanation; not independent runtime proof |
| [Compare PDFs](https://www.ihatepdf.cv/compare-pdfs) | Side-by-side synchronized scrolling comparison workflow | Observed product description |
| [Repair PDF](https://www.ihatepdf.cv/repair-pdf) | Five-strategy local repair concept and partial-recovery behavior | Observed claims; recovery quality unverified |
| [Privacy scanner](https://www.ihatepdf.cv/privacy-scanner) | Metadata/hidden-data scan, sensitivity report, strip-and-download workflow | Observed claims; category coverage unverified |
| [P2P share](https://www.ihatepdf.cv/p2p-share) | WebRTC browser-to-browser transfer, STUN discovery, optional AES-256-GCM layer, share-code workflow | Observed claims; network/security behavior unverified |
| [Public PWA manifest](https://www.ihatepdf.cv/manifest.json) | Standalone display, scope, share target, icons, productivity categories | Static asset inspection |
| [Public service worker](https://www.ihatepdf.cv/sw.js) | Cache version, precache, runtime library caching, offline fallback, external library URLs | Static asset inspection |
| Public bundle `/assets/index-AX28eR3E.js` | React/vendor bundle references, service-worker registration, Microsoft Clarity project initialization, PDF.js and external library URLs | Static asset inspection on 2026-08-24 |
| [Listed GitHub link](https://github.com/pranavcode2442/ihatepdf-tools) | A source link surfaced in the public home page | Direct open returned 404 during this pass; source ownership and license are not established |

### Retrieval fingerprints

These fingerprints identify the public assets inspected during this pass. They
are not claims about the full application source or a permanent release
identity:

| Asset | SHA-256 observed 2026-08-24 |
| --- | --- |
| `/assets/index-AX28eR3E.js` | `6343a5f1977bffa81a96ef310ecceb130ad9147bd9ee59291b59d5c181b18108` |
| `/sw.js` | `e3e9f9ffd62a205c4085589a6bdfab59dc00f1f91d40427d674c09dd0f06365e` |
| `/manifest.json` | `ffe4ed702ccceb77a09699dac8bb9da3fcecb02b04e02d42bf82af7265469472` |

The website can change after this record. Re-run the asset retrieval and update
the fingerprint table before making a current implementation or privacy claim.

## Product surface map

### Core PDF operations

The home page lists:

- merge;
- compress;
- split and extract pages;
- PDF to JPG/PNG;
- Word to PDF;
- PDF to Word;
- images to PDF;
- text extraction;
- page organization;
- rotation;
- crop and resize;
- watermarking;
- page numbers;
- headers and footers.

This is a highly discoverable utility layer. Each tool has a narrow landing
page and an immediately understandable promise. The product is optimized for
task entry rather than forcing the user into a large editor workspace.

### Editing and completion

The text-editor page advertises:

- click-to-edit text runs;
- same-font, same-size, same-color replacement;
- text boxes;
- images;
- drawn, typed, or photographed signatures;
- automatic background removal for signature photographs;
- whiteout blocks;
- highlights, underlines, strike-through, and freehand drawing.

The site explicitly contrasts its method with covering existing text in white
and stamping Helvetica over it. It claims to inspect the original text run's
font, point size, weight, color, and position, then re-render replacement text.
For standard fonts it claims one-to-one matching, with metric-compatible
fallbacks for unusual embedded fonts.

This is an important competitor claim because it targets the exact user desire
behind “edit normal PDFs without touching other text.” It is also a high-risk
claim. A PDF text run is not the same thing as a semantic paragraph. Font
substitution, glyph coverage, clipping, kerning, writing mode, ligatures,
right-to-left text, transparency, clipping paths, and overlapping objects can
make “same place” or “layout stays intact” fail.

**Implication for this project:** treat text-run replacement as a separate
operation family with explicit evidence and preservation gates. Do not collapse
it into the same operation as a reviewed blank-field overlay.

### OCR and scanned documents

The OCR page advertises:

- Tesseract.js compiled to WebAssembly;
- language selection;
- an invisible searchable text layer;
- local processing;
- preservation of the visible scan;
- browser-offline behavior after assets are available.

The editor page further claims that image-only pages automatically enter an OCR
path, that recognized words become editable items, and that low-confidence words
are highlighted for verification.

The useful product idea is the transition from OCR output to a reviewable text
layer. The unsafe shortcut would be treating OCR output as exact page truth or
silently allowing OCR-derived edits to overwrite the source image.

**Adopt in principle:** OCR evidence with text bounds, confidence, language,
model/provider, and review state. Preserve the original scan and keep OCR as a
separate text layer or evidence artifact until the user confirms an operation.

**Require proof:** page-level OCR quality, word-level confidence calibration,
coordinate accuracy, multilingual behavior, handwriting abstention, searchable
layer alignment, and output reopening in independent viewers.

### Security and privacy tools

The site advertises:

- AES-256 password protection;
- password removal;
- permanent redaction;
- flattening of form fields, annotations, and interactive scripts;
- a privacy scanner for hidden metadata and personal information.

The privacy scanner page describes checks for author names, company names, GPS
coordinates from embedded images, comments, tracked changes, software-version
fingerprints, creation history, printer information, and other metadata. It
offers a report followed by strip-and-download.

This is a compelling product direction because privacy is made operational. A
user can ask not only “did you avoid upload?” but also “what will my exported
PDF reveal?”

**Adopt in principle:** a preflight privacy report before sharing, with finding
category, location, severity, action, and whether the action is reversible.

**Keep separate:** metadata sanitization, permanent redaction, flattening,
password removal, and cryptographic-signature changes are different mutation
classes. Each requires its own source-preservation and recovery gates.

### Conversion and document generation

The catalog expands beyond PDF editing into:

- Markdown to PDF;
- HTML to PDF;
- Excel to PDF;
- CSV to PDF;
- PowerPoint to PDF;
- PDF to PowerPoint;
- PDF to Excel;
- PDF to HTML;
- PDF to EPUB;
- PDF to audio;
- ebook to PDF;
- audio to PDF transcript;
- PDF to ZIP;
- rich-text PDF creation;
- color inversion.

This is a deliberate utility-suite strategy. It creates search coverage and
repeat visits, but it also multiplies dependency, format-fidelity, accessibility,
and support obligations.

**Implication for this project:** maintain a capability marketplace in the
architecture, but do not make every converter a first-release commitment. Add a
converter only when the input/output contract and validation oracle are clear.

### AI tools

The site advertises Chat with PDF and an AI summarizer. The public technical blog
describes a privacy boundary where PDF parsing and text extraction happen
locally, then extracted text is sent to the Google Gemini API using a user-supplied
key. It says the raw PDF binary is not sent.

This is a useful pattern, but “local PDF processing” does not mean “no document
content leaves the device.” Text content can itself contain confidential data,
and the Gemini API becomes a distinct external processing boundary.

**Adopt in principle:** make AI capability modes explicit:

- fully local structured extraction;
- local parsing plus external text transmission;
- local companion model;
- hosted processing.

Show the user exactly what leaves the device, which provider receives it, how
long it is retained if known, and whether the action can be disabled.

**Do not copy:** “private” or “offline” labels on a workflow that sends extracted
text, OCR output, thumbnails, or metadata to an external API.

### Compare, repair, scan, share, collaborate

The additional tools are strategically interesting:

- **Compare PDFs:** two-panel synchronized scrolling for manual revision review.
- **Repair PDF:** five sequential recovery strategies for broken xref/trailer,
  missing EOF, bad stream lengths, and damaged page trees, with partial recovery
  acknowledged.
- **Scan to PDF:** camera/webcam capture with auto-crop and deskew.
- **P2P Share:** WebRTC direct transfer using a share code, STUN discovery, and
  optional client-side password encryption.
- **Collaborative Whiteboard:** real-time drawing collaboration without an
  account.
- **Business tools:** GST invoice generation, POS billing, and invisible PDF
  fingerprinting.

For our product, Compare and Repair are closer to the PDF-editor core than the
business tools. P2P sharing is an optional workflow boundary, not a document
editing primitive. Collaboration changes identity, authorization, conflict,
retention, and audit requirements and should not be inferred from a whiteboard
demo.

## Public technical architecture

### Engine composition

The technical blog describes two primary WebAssembly-powered PDF engines:

- PDF.js 3.11.174 for parsing, rendering, canvas previews, and high-DPI export;
- pdf-lib 1.17.1 for PDF manipulation, forms, annotations, merge/split, page
  copying, and saving.

The site claims that PDF.js work is worker-backed and that pdf-lib operates at
the PDF structure level. This closely matches the current PDF editor direction:
PDF.js for browser reading and evidence, pdf-lib for bounded writing, and shared
contracts between provider-specific behavior.

### Storage tiers

The public blog describes three tiers:

| Tier | Intended contents | Product lesson |
| --- | --- | --- |
| RAM | Active PDF and processing buffers | Volatile and fast; must be released or replaced after heavy operations |
| IndexedDB | Large binary files and resumable buffers | Use binary storage instead of string serialization; make retention and clear actions visible |
| localStorage | Filenames, timestamps, sizes, and non-sensitive metadata | Never use it for source PDF bytes or sensitive profile values |

The blog explicitly warns that converting ArrayBuffers to strings increases
memory use and that localStorage is too small for large binary files. This is
directly relevant to the browser fixture and future template system.

### Device-adaptive limits

The public example adapts file size, DPI, and batch page limits based on mobile
status and `navigator.deviceMemory`. The stated example limits are:

| Device class | Example max file | Example max DPI | Example batch |
| --- | ---: | ---: | ---: |
| Smartphone | 50 MB | 300 | 10 pages |
| Tablet | 75 MB | 450 | 25 pages |
| Desktop | 150 MB | 600 | 50 pages |

The site also describes memory estimation using page count, render scale,
format multiplier, and a safety margin. It clamps canvas dimensions and reduces
or batches work when a job threatens available memory.

**Adopt:** capability negotiation and transparent preflight warnings. A browser
operation should say “unsupported,” “reduced quality,” “batched,” or “continue
with risk” instead of simply freezing or failing.

**Do not adopt blindly:** the exact numeric thresholds. They are product/site
claims, not device-independent guarantees. Our limits must come from corpus
benchmarks across Safari, Chromium, Firefox, native macOS, and representative
mobile memory profiles.

### Batch processing and memory release

The blog describes processing pages in batches, freeing canvas width and height
after each page, and inserting pauses between batches. It emphasizes that canvas
memory includes both RAM and GPU/shared memory.

This is a strong low-level lesson for PDF to image export, OCR, thumbnails, and
visual-diff generation. It is less relevant to small text-only form overlays,
which should avoid rendering entire documents when structural evidence is enough.

### PWA and offline shell

The public manifest declares standalone display, root scope, icons, and a PDF
share target. The public service worker:

- precaches the app shell and manifest;
- runtime-caches external PDF libraries;
- falls back to cached `index.html` for navigation failures;
- caches scripts, styles, images, fonts, and runtime responses;
- exposes a `SKIP_WAITING` message;
- declares a background-sync handler, though the observed handler only logs the
  event.

The service worker's public library list includes external URLs for pdf-lib,
download.js, PDF.js, and the PDF.js worker. This means “works offline after the
first load” depends on successful initial retrieval and cacheability of those
assets. An air-gapped deployment would need vendored assets and a different
verification path.

### External network and privacy nuance

Static inspection of the public bundle found:

- a Microsoft Clarity initialization with a public project identifier;
- external library CDN URLs;
- a Gemini API flow described in the technical blog;
- WebRTC/STUN behavior described on the P2P page;
- Razorpay marketing/payment reference in the bundle.

The public site also says normal PDF processing happens locally. These facts are
not necessarily contradictory if the claims are scoped to PDF bytes during
ordinary local tools, but they are contradictory to an unqualified “no network”
or “no external service” interpretation.

**Product lesson:** privacy is a data-flow matrix, not a badge. For each tool,
record whether it sends source bytes, extracted text, OCR text, thumbnails,
telemetry, analytics events, signaling metadata, payment metadata, or nothing.

## Claim and evidence audit

| Site claim | What is supported by this pass | What remains unknown or risky |
| --- | --- | --- |
| Files never leave the device | Claimed on home, editor, OCR, repair, privacy, and P2P pages; local code paths are described for ordinary processing | Public analytics, CDN, AI, payment, and STUN paths exist; normal-tool PDF-byte behavior was not independently packet-tested |
| Works offline | Service worker and cache code are publicly observable; app shell and libraries have a cache path | First-load network is required; some tools may need external APIs, signaling, or uncached assets |
| No file-size limits | Marketing claim appears on home/P2P surface | Technical blog states device-adaptive limits and 150 MB desktop / lower mobile examples; practical memory remains a limit |
| Edit in same font and place | Detailed implementation claim is documented on editor page | No corpus render comparison, text-run edge-case report, or independent viewer proof was obtained |
| OCR is 95-99% for clean typed scans | Site FAQ claim | Dataset, metric definition, language breakdown, calibration, and confidence behavior are not supplied |
| Permanent redaction | Feature is advertised | Redaction completeness, hidden object removal, searchability, image pixels, annotations, and reopen validation were not independently verified |
| AES-256 encryption | Feature is advertised | Exact mode, KDF, password policy, interoperability, and metadata leakage were not checked |
| Privacy scanner detects 15+ categories | Feature page describes categories and report workflow | Exact implementation coverage and false-negative behavior are unknown |
| Repair uses five strategies | Feature page describes sequential recovery and partial results | Recovery correctness, data loss reporting, and independent viewer behavior are unknown |
| AI sends only extracted text | Technical blog explicitly describes local extraction then Gemini API text transmission | Provider retention, prompt privacy, model configuration, and user-key storage behavior need separate review |
| P2P has no server in the middle | Page describes direct WebRTC transfer | STUN signaling and connection metadata still involve network infrastructure; availability and authentication behavior need runtime testing |
| Digital signature is valid in most jurisdictions | Editor page makes a legal-sounding statement | This is not a cryptographic signature validation or legal-compliance proof; the PDF editor should avoid reproducing it |

## Feature decisions for our native and web apps

### Adopt or adapt soon

| Feature/pattern | Native app | Web app | Why |
| --- | --- | --- | --- |
| Task-oriented tool entry | Native command palette and focused workflows | Route-based tools with one primary action | Reduces cognitive load and supports a broad future surface without one overloaded editor |
| Privacy/data-flow center | Show local provider, file location, network state, and export status | Show browser-only, companion, or external-API mode per operation | Turns privacy into an observable product behavior |
| Device/resource preflight | Native memory and file-size checks | Browser memory estimate, page batching, DPI limits, and explicit warnings | Prevents silent crashes and preserves user work |
| Compare PDFs | Native synchronized page view and semantic diff | Browser two-panel synchronized reader | Valuable review primitive and strong complement to validation reports |
| Privacy scanner | Native metadata/object preflight | Browser metadata and embedded-object report | Supports safe sharing and differentiates beyond “no upload” |
| Repair intake | Native structural repair companion lane | Browser bounded repair or explicit unsupported result | Makes malformed PDFs diagnosable instead of mysterious |
| PWA/share-target behavior | Native file open/share integration | Installable PWA and PDF share target | Improves entry friction without changing document semantics |
| Local storage tiers | App-managed session/recovery store | RAM, IndexedDB, local metadata, and explicit clear controls | Supports resumability while preserving source/template separation |

### Adapt only behind evidence gates

- text-run in-place editing with font reuse;
- automatic OCR-to-editable-text conversion;
- permanent redaction;
- password removal and encryption;
- high-DPI conversion and compression;
- PDF to Word/PowerPoint/Excel;
- browser P2P document handoff;
- local PDF chat or summarization;
- signature image background removal;
- forensic repair.

Each of these should be a typed operation or capability provider with a source
digest, provider version, evidence, resource estimate, output validation, and
explicit failure state.

### Defer or reject for the first differentiated product

- generic GST/POS business tools;
- a real-time whiteboard as a product direction;
- an invisible document fingerprint without a clear user-authority and privacy
  model;
- unreviewed AI modification of PDF content;
- silent OCR overwrite of source imagery;
- broad legal claims about signature validity or GDPR compliance;
- “no network” language that ignores telemetry, external assets, AI, or P2P
  signaling;
- arbitrary paragraph reflow before a preservation oracle exists.

## Competitive interpretation

### What ihatepdf.cv does well as a product strategy

1. **Immediate utility:** no account, no trial, no setup, and a direct upload
   action.
2. **Clear promise:** no watermark and local processing are easy to understand.
3. **Surface breadth:** a user who arrives for merge can discover OCR, repair,
   compare, metadata scanning, or conversion.
4. **SEO/product pairing:** each tool has a narrow landing page, how-to flow,
   FAQ, and related-tool graph.
5. **Local-first economics:** moving processing into the browser reduces server
   processing cost and makes privacy a product differentiator.
6. **Progressive resource behavior:** the technical story acknowledges browser
   memory limits instead of pretending WebAssembly removes them.

### Where our product should be different

ihatepdf.cv is optimized for broad utility and rapid task completion. The PDF
editor is optimized for difficult, repeated, high-consequence form completion.
Our differentiators should be:

- native-field versus static-candidate distinction;
- evidence shown beside every suggestion;
- abstention and human review rather than silent autofill;
- source digest and operation lineage;
- “what changed” and “what was not checked” reports;
- native/web semantic parity;
- privacy-first recurring templates without source content or profile values;
- correction and hard-negative learning under explicit consent;
- provider-independent validation and recovery;
- local adjacent OCR/parser research converted into durable, versioned evidence.

The lesson is not to compete on 46 versus 50 tools. It is to offer fewer
high-trust capabilities with stronger proof, then grow the utility surface from
the same validated contracts.

## Proposed corpus experiments inspired by the site

The following experiments should be added to the PDF editor corpus, but are not
implemented by this document:

### E-001: Text-run replacement preservation

Use digital PDFs containing embedded fonts, standard fonts, ligatures, Unicode,
right-to-left text, tables, columns, clipping, transparency, and overlapping
objects. Replace one run at a time. Validate:

- text outside the run remains semantically unchanged;
- render difference is bounded to an expected region;
- font fallback is reported;
- output reopens in PDF.js, PDFKit, and an independent viewer;
- operation records the original run evidence and replacement bounds.

### E-002: OCR layer alignment

Use scanned forms with typed text, handwriting, skew, low DPI, mixed languages,
stamps, and signatures. Measure word-level bounds, confidence calibration,
searchability, screen-reader extraction, and whether OCR suggestions increase
false candidate creation.

### E-003: Privacy preflight and sanitization

Create fixtures containing document metadata, embedded images with EXIF, comments,
annotations, form values, JavaScript, attachments, signatures, and incremental
revisions. Report what can be detected, what can be removed, what cannot be
verified, and whether sanitization is reversible.

### E-004: Repair and recovery

Generate or obtain consented fixtures with broken xrefs, missing trailers,
truncated streams, missing EOF markers, malformed page trees, encryption, and
partial content loss. A repair result must include recovered pages/objects,
unrecovered content, source digest, and a warning that it is a new recovered copy.

### E-005: Device-adaptive browser limits

Run the browser lane on Safari, Chromium, Firefox, low-memory mobile, desktop,
large page sizes, high DPI, and 100-plus-page corpora. Measure peak memory,
canvas/GPU behavior, worker responsiveness, batching, cancellation, recovery,
and output correctness.

### E-006: Compare and operation impact map

Compare original and edited outputs semantically and visually. Highlight:

- intentional operations;
- unexpected text/object changes;
- page geometry changes;
- metadata changes;
- unsupported or unknown checks.

This becomes the product-level proof behind “without touching other text.”

## Decisions and boundaries for the PDF editor

- ihatepdf.cv is a strong product and architecture reference, not a source of
  truth for our provider selection.
- PDF.js plus pdf-lib remains a reasonable browser composition, but the site
  does not establish that this composition can safely support arbitrary text
  editing, redaction, repair, conversion, or OCR for our corpus.
- We should adopt task-oriented entry, PWA/share-target behavior, resource
  preflight, storage tiers, compare, privacy scanning, and explicit local versus
  external data-flow states as research-backed product candidates.
- We should keep the differentiated core centered on reviewed form completion,
  candidate evidence, source-bound operations, templates, and validation.
- We should not copy the site's broad legal, privacy, accuracy, or “no network”
  claims without independent runtime and policy evidence.
- The public GitHub source link was unavailable during this pass. No source,
  license, dependency manifest, or code should be adopted from that link until
  the repository is reachable and provenance is confirmed.

## Exact next step

Add the site-inspired cases to the existing cross-project evidence ledger and
semantic parity plan, in this order:

1. text-run replacement preservation;
2. OCR layer alignment;
3. privacy preflight and sanitization;
4. repair and recovery;
5. device-adaptive browser limits;
6. semantic/visual compare impact maps.

The next implementation should still be the cross-project evidence ledger plus
native/web parity fixture. This competitor exploration expands the test corpus
and product opportunity map; it does not authorize adding Ghostscript,
Tesseract.js, Gemini, P2P signaling, a service worker, or a converter suite to
the product yet.

## Verification limits

This exploration used current public HTML pages, public manifest/service-worker
assets, public bundle string inspection, and the linked public technical blog.
It did not:

- upload or process a user document on the site;
- inspect browser network traffic during a real operation;
- verify output bytes, render fidelity, OCR accuracy, or repair recovery;
- audit the site's server, analytics configuration, payment behavior, or data
  retention policy;
- establish the licensing or ownership of the unavailable GitHub link;
- treat marketing copy as runtime or legal proof.

The next live verification, if this competitor is important enough to justify
it, is a controlled browser test with a non-sensitive fixture and DevTools
network capture, followed by output reopen and independent-viewer checks. That
would be external competitor observation, not a PDF-editor production gate.

