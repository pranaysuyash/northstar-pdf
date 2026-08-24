# Native and Web Platform Matrix

**Status:** Proposed platform map for discovery review
**Date:** 2026-08-24

This document translates the feature frontier into implementation boundaries. “Shared” means the intent, data contract, and safety invariant can be shared. It does not mean the same PDF library or byte-level output is used on every platform.

## Capability legend

- **Core:** suitable for the first cross-platform product contract.
- **Conditional:** useful, but provider/corpus evidence is required before promising it.
- **Adapter:** platform-specific implementation behind a shared contract.
- **Later:** valuable but not required to prove the product wedge.
- **Reject for now:** likely to expand risk or scope beyond the current promise.

## Matrix

| Capability family | Shared model | Native macOS | Web local-first | Web companion/server | First decision |
|---|---|---|---|---|---|
| Page rendering | Page, viewport, render intent | PDFKit now; alternate provider later | PDF.js | PDFBox/MuPDF/PDFium lane if needed | Core in both; pixels are provider-specific |
| Text extraction | Text spans and bounds | PDFKit/PDFKit adapter; Vision fallback | PDF.js text layer | PDFBox or OCR worker | Core, with recognized/extracted provenance |
| Native form inventory | Field ID, type, bounds, options | PDFKit adapter | PDF.js annotations plus pdf-lib form inspection | PDFBox control lane | Core, but imported-form preservation is gated |
| Native form filling | Typed field operation | PDFKit adapter | pdf-lib form writer | PDFBox/MuPDF adapter | Core for supported types; radio/XFA gated |
| Static region detection | Evidence and candidate schema | Swift detector + Vision/OCR adapter | TypeScript geometry/text detector | OCR/layout worker | Core product feature; no auto-apply |
| Overlay text/image/stamp | Operation log and page-space bounds | PDFKit annotations/drawing | pdf-lib draw operations | PDFBox/MuPDF fallback | First editing lane |
| Existing object editing | Target/object identity and mutation result | Provider-specific | Provider-specific or companion | PDFBox/MuPDF/native service | Conditional, no broad promise |
| Annotation/review | Annotation operation | PDFKit | PDF.js display + writer adapter | Provider adapter | Core, flattening is explicit |
| Redaction | Mark and applied-redaction reports | Separate provider/security lane | Separate provider/security lane | Strong candidate for isolated service | Later/gated |
| Visual signature | Signature appearance | Native drawing/image | Browser drawing/image | Optional server composition | Core utility, not legal signature claim |
| Cryptographic signature | Byte-range/signature validation report | Native or dedicated crypto lane | Browser/companion lane | Dedicated service/provider | Gated; independent verifier required |
| OCR/searchable layer | Recognition layer, confidence | Vision/OCRmyPDF/Tesseract adapter | Tesseract.js or companion worker | OCRmyPDF/Tesseract/PaddleOCR lane | Separate later OCR experiment |
| Page organizer | Page operation types | PDFKit/provider adapter | pdf-lib page operations | PDFBox/qpdf | Core |
| Compare revisions | Text/geometry/render diff report | Native render and extract | Browser render/extract | Server batch lane | Core after export validation |
| Recurring templates | Template family, revision, keyed layout fingerprint, mapping, review policy | Encrypted local app store | Opt-in encrypted IndexedDB/OPFS; no default sync | Future client-encrypted sync lane | Design next; never store profile values in template |
| Draft persistence | Session ID, source fingerprint, operation log | File-backed session/store | IndexedDB/OPFS plus explicit export | Database/object store if collaboration exists | Core local mode; server later |
| File access | Source handle/bookmark metadata | Security-scoped URL/bookmark | File System Access API where supported; picker/download fallback | Upload/download API only when opted in | Native and web use different permissions |
| Large-file processing | Job/progress/cancellation | Background task | Worker, streaming/range loading, OPFS | Queue/worker | Add cancellation from the beginning |
| Collaboration | Revision/operation provenance | Later | Later | Server authority required | Do not mix into local-first core |

## Recommended deployment shapes

### Shape A: Shared local-first core with native and browser adapters

```text
                 shared intent/contracts
       ┌────────────────────┴────────────────────┐
       │                                         │
 native adapter + SwiftUI/AppKit       browser adapter + TypeScript
       │                                         │
 PDFKit / Vision / local workers      PDF.js / pdf-lib / Web Workers
       │                                         │
  macOS files and exports              picker + OPFS/IndexedDB + download
```

This remains the recommended first shape, now with a decision record in
[`docs/web-deployment-decision.md`](web-deployment-decision.md). It keeps the
user’s document local for the core workflow, supports native quality on macOS,
and makes the web app useful without requiring a server. The shared layer should
contain contracts, operation semantics, coordinate transforms, candidate
evidence, validation reports, and corpus fixtures. It should not contain a
forced lowest-common-denominator PDF implementation.

### Shape B: Browser shell plus local companion

```text
 browser UI ── local RPC ── companion process
    │                         ├─ high-fidelity PDF provider
    │                         ├─ OCR/layout workers
    │                         └─ filesystem access
    └─ PDF.js preview and interaction state
```

This shape is attractive when browser-only writing or OCR fails the corpus gates. It adds installation, lifecycle, versioning, port/security, and update burden. It should be an explicit capability upgrade, not a hidden dependency.

### Shape C: Hosted/self-hosted processing service

```text
 browser/native client ── authenticated API ── worker queue ── PDF/OCR engines
```

This is appropriate for collaboration, batch processing, shared templates, and enterprise controls, but it changes the privacy and data-governance product. It should be a later lane with retention, encryption, deletion, audit, and tenant-isolation contracts.

## Browser storage plan

The web application should support three explicit storage modes:

1. **Ephemeral:** document bytes stay in memory until export/download.
2. **Local draft:** source copy, thumbnails, and operation log are stored in IndexedDB or OPFS. The UI states that browser storage is a recoverable draft cache, not a backup.
3. **File-backed:** when supported and granted by the user, a File System Access handle is used to read and save. A new-copy default remains safer than overwriting the source.

The File System API is restricted to secure contexts and requires user permission for ordinary file-system access. OPFS is private to the page origin and optimized for local storage, while IndexedDB is suitable for structured data and blobs. These are platform capabilities, not guarantees: the web app needs a picker/download fallback and must detect quota, permission, browser, and eviction failures. [MDN File System API](https://developer.mozilla.org/en-US/docs/Web/API/File_System_API), [MDN IndexedDB API](https://developer.mozilla.org/en-US/docs/Web/API/IndexedDB_API)

## Web worker boundaries

The main UI thread should own interaction state only. Rendering, text extraction, candidate detection, OCR, thumbnails, and export preparation should run in workers where the chosen provider supports it. Every worker job needs:

- input document fingerprint and page range;
- progress and cancellation;
- memory/time limits;
- structured errors;
- no secret-bearing logs;
- a result that can be discarded and recomputed from immutable source plus operations.

## Native adapter boundaries

The current Swift project already has a `PDFEditorCore` contract and a PDFKit provider. Extend that boundary rather than letting SwiftUI views become the source of PDF semantics. The AppKit/PDFKit shell should own file access and presentation; the core should own inspection results, operation intent, validation reports, and recovery-visible errors.

Do not make the web app depend on Swift behavior. If parity is important, encode the contract in a versioned neutral representation and test native and web adapters against the same fixtures and operation scenarios.

## Recommended order

1. Freeze the shared contract and coordinate system.
2. Finish the native macOS reader/completion/export proof already in progress.
3. Add a web reader with PDF.js and a browser-only overlay/form-fill experiment using pdf-lib.
4. Run the same corpus and preservation gates against native and web exports.
5. Add OCR as a worker/companion capability with explicit provenance.
6. If a measured browser failure triggers the companion gate, evaluate whether
   high-fidelity editing justifies MuPDF licensing or a PDFBox/local-companion
   boundary.
7. Only then consider collaboration, server storage, and arbitrary object editing.

## Open decisions

| Decision | Why it matters | Falsifier |
|---|---|---|
| Is browser-only export sufficient for the browser core? | Resolved in D-009: browser core plus companion capability plane; determines which operations are owned by which provider | A required long-term capability cannot be represented or safely validated across the browser and companion planes |
| Is macOS-only native the first supported desktop? | Determines provider and packaging scope | User requires Windows/Linux/iOS before macOS proof is complete |
| Is a permissive license mandatory? | Removes MuPDF/Poppler paths unless separately licensed | Legal review approves AGPL/commercial distribution path |
| Is “normal editing” bounded object editing or arbitrary reflow? | Changes product architecture and validation cost | User explicitly requires paragraph reflow/layout reconstruction |
| Is collaboration a first-class requirement? | Changes source of truth from local bytes to server revisions | Shared multi-user workflow becomes primary target |
