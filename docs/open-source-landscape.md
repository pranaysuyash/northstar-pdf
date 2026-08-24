# Open-Source PDF Landscape and Selection Guide

**Status:** Discovery artifact; license review is not legal advice
**Date:** 2026-08-24

This is a capability and integration map, not an approval to add dependencies. License obligations, transitive dependencies, platform packaging, security posture, and current maintenance must be rechecked before adoption.

## Shortlist

| Component | License signal | Strengths | Gaps or risks | Best role |
|---|---|---|---|---|
| PDF.js | Apache-2.0 | Browser parsing/rendering, text, annotations, form display, worker-based loading, viewer foundation | Not a general PDF writer/editor; annotation storage is not the same as exporting a new PDF | Web display and inspection |
| pdf-lib | MIT | Browser/Node/React Native PDF creation/modification, forms, page operations, fonts, images, drawing | Not a renderer; existing-object semantic editing and complex-form fidelity are not established | Web bounded writer and overlay exporter |
| Apache PDFBox | Apache-2.0 | Java rendering, text extraction, forms, creation, split/merge, preflight, signing | JVM boundary; still needs corpus evidence for preservation and semantic edits | Companion/server control lane |
| qpdf | Apache-2.0 | Structural parsing, normalization, encryption, linearization, JSON inspection, transformations | Not a viewer or semantic content editor | Structural inspection and safe utility layer |
| pikepdf | MPL-2.0 | Python access to qpdf objects, pages, saving, form structures | Not a browser renderer or complete interactive editor | Local/server experiments and utility workers |
| MuPDF / MuPDF.js | AGPL-3.0 or commercial | Broad native and WebAssembly reading, rendering, annotations, widgets, writing, conversion | AGPL/commercial gate; integration and distribution terms need dedicated review | High-fidelity lane only after legal/product decision |
| Poppler | Component-dependent, including GPL surfaces | Mature rendering, forms, annotations, text, signatures | License matrix and writer limitations need review; not a straightforward permissive default | Independent renderer/verification lane |
| PoDoFo | LGPL-2.0-or-later or MPL-2.0 source expressions | Native parsing/creation, pages, annotations/forms, incremental updates | Not a complete viewer; runtime quality and ecosystem need testing | Native writer experiment |
| OCRmyPDF | MPL-2.0 core; dependencies vary | Searchable OCR layer, PDF/A paths, sidecar text, tolerant scanned-PDF workflow | External binaries, dependency licenses, untrusted-PDF warning, batch-oriented | Isolated OCR worker |
| Tesseract | Apache-2.0 | Local OCR engine with language packs and output options | OCR is recognition, not document semantics or layout-safe editing | OCR engine under a worker/adapter |
| Stirling PDF | Open-core product; inspect its current repository/license by component | Feature reference for a broad local/self-hosted PDF workspace, pipelines, annotations, redaction, OCR, compare, API | Product dependency would bring scope and license/architecture coupling; use as reference, not copy | Market and feature benchmark |

## Recommended composition by product boundary

### Permissive, local-first baseline

```text
Native macOS: PDFKit + Swift core + Vision/local OCR
Web: PDF.js + pdf-lib + Web Workers + IndexedDB/OPFS
Optional utility: qpdf/pikepdf or PDFBox in a separately isolated lane
```

This composition is enough to prove reading, native form inspection/fill for supported fields, reviewed static overlays, annotations, page operations, and export validation. It does not prove arbitrary semantic editing.

### High-fidelity native/web lane

```text
Native/web: MuPDF or MuPDF.js
OCR: Tesseract/OCRmyPDF or another isolated worker
UI: native shell and web shell over a shared operation model
```

This may reduce provider fragmentation, but it introduces a major AGPL/commercial licensing decision. It should be evaluated only with a fixed corpus and a distribution scenario in hand.

### JVM companion lane

```text
Web/native UI: local or remote client
Companion: PDFBox + qpdf utilities + OCR worker
```

This is attractive for forms, batch work, preflight, signing, and server automation. It is less attractive if the product requirement is a tiny native app with no runtime installation.

## What “best” means for this project

There is no single best PDF library because the product asks for four different jobs:

1. render a page accurately and interactively;
2. understand text, geometry, fields, and annotations;
3. write a new PDF while preserving unrelated content;
4. infer user intent from static visual forms.

The first three can be composed from existing providers. The fourth is product-owned detection and review logic. Selecting a library because it has the longest feature list would hide this distinction and make false-positive behavior harder to control.

## License and distribution gates

Before adding any dependency, record:

- direct and transitive licenses;
- static versus dynamic linking implications;
- source-disclosure or notice obligations;
- whether a WebAssembly binary changes the license boundary;
- whether a network service triggers a different obligation;
- platform signing/notarization and embedded-binary implications;
- security update and CVE process;
- version pinning and reproducible build path;
- fallback if the provider is removed, unmaintained, or fails a corpus gate.

The existing project should keep provider-specific code behind adapters so a license decision does not force a UI rewrite.

## Evidence gates for provider adoption

### Reader gate

- page count, page boxes, rotation, annotations, outlines, links, attachments, and permissions are inspected;
- representative pages render in native and browser surfaces;
- malformed, encrypted, huge, rotated, scanned, and mixed-content PDFs fail visibly and recoverably;
- cancellation and memory limits are observable.

### Form gate

- external AcroForm fields are inventoried without mutation;
- text, checkbox, radio, combo, list, and signature widget semantics round-trip;
- appearance streams and Unicode text survive save/reopen;
- output opens in at least two independent viewers or validators;
- no-op save is tested because a no-op can still destroy metadata.

### Static-region gate

- candidates are compared against reviewed ground truth;
- false positives on table cells, decorative boxes, and signatures are measured;
- low-confidence cases abstain;
- label association and coordinate transforms are validated across rotation/crop boxes;
- auto-application remains disabled until the user confirms.

### Editing gate

- original source digest remains unchanged;
- each operation replays deterministically;
- undo removes only the selected operation;
- overlay placement remains stable after reopen;
- unrelated text extraction and page geometry are preserved;
- raster or visual comparison is run on representative pages.

### Security gate

- JavaScript/actions do not execute by default;
- untrusted documents are processed in an isolated worker/process where required;
- passwords and document bytes do not enter logs;
- redaction is independently verified before a permanence claim;
- digital signature validation distinguishes integrity, trust, and unknown states.

## Current recommendation

Adopt no new provider solely from this document. Continue the existing PDFKit native benchmark, then build a small browser proof using PDF.js plus pdf-lib against the same fixtures. Keep MuPDF/MuPDF.js and PDFBox as controlled alternatives. Decide only after the corpus shows whether the permissive split provider lane is sufficient for the target user workflow.

## Primary sources consulted

- [PDF.js getting started](https://mozilla.github.io/pdf.js/getting_started/)
- [PDF.js API](https://mozilla.github.io/pdf.js/api/draft/module-pdfjsLib.html)
- [pdf-lib repository and form capabilities](https://github.com/Hopding/pdf-lib)
- [pdf-lib MIT license](https://github.com/Hopding/pdf-lib/blob/master/LICENSE.md)
- [Apache PDFBox feature page](https://pdfbox.apache.org/)
- [qpdf overview](https://qpdf.readthedocs.io/en/stable/overview.html)
- [pikepdf API](https://pikepdf.readthedocs.io/en/latest/api/main.html)
- [MuPDF.js repository and license](https://github.com/ArtifexSoftware/mupdf.js/)
- [MuPDF write options](https://mupdf.readthedocs.io/en/latest/reference/common/pdf-write-options.html)
- [Stirling PDF functionality](https://docs.stirlingpdf.com/functionality/)
- [Stirling PDF developer guide](https://github.com/Stirling-Tools/Stirling-PDF/blob/main/DeveloperGuide.md)
- [OCRmyPDF repository and license](https://github.com/ocrmypdf/OCRmyPDF)
- [OCRmyPDF introduction](https://ocrmypdf.readthedocs.io/en/latest/introduction.html)
