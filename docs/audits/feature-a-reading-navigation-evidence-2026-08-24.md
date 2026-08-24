# Feature A Reading and Navigation Evidence

**Date:** 2026-08-24
**Scope:** A1-A11, native macOS lane and local web companion
**Evidence tier:** Tier 2 source/build/provider evidence, plus isolated browser interaction evidence; independent conformance and assistive-technology validation remain open

**Release disposition:** NO-GO for an unrestricted release. GO for continued bounded Feature A development and internal review. The no-go decision is caused by provider fidelity and independent accessibility evidence gates, not by a failing core reader smoke path.

## Acceptance lenses used

The local persona archive was used as a review lens, not as runtime content:

- `PER-0328 - Accessibility UX Designer`: page language, landmarks, visible focus, keyboard operation, live status, and honest assistive-technology claims.
- `PER-0090 - Control Surface Architect`: every reading action has an explicit control, predictable state, and provider-owned capability boundary.
- `PER-1138 - Full-Stack Dev`: shared contract between native and web adapters, deterministic local tests, and no hidden remote dependency for document bytes.
- `PER-PDEV-0436 - Product Owner_ Backlog Ownership`: each feature is classified as implemented, provider-conditional, or blocked by missing evidence rather than being left as an unbounded promise.

## Implemented contract

### Native macOS

- PDFKit opens/imports local PDFs through `DocumentSource` and enforces input/page limits.
- Single-page, continuous, two-page, fit-width, fit-page, zoom, rotate, pan, page jump, thumbnails, and page labels are represented in reader state.
- PDFKit search results are navigable and the selected match is applied to `PDFView.currentSelection`.
- Native text copy uses the system pasteboard and reports success/failure through status state.
- Links, internal destinations, named destinations, outlines, attachments, metadata, permissions, page boxes, encryption state, and password retry are inspected through the provider.
- Accessibility evidence distinguishes extracted reading-order evidence from authored PDF tag-tree preservation.

### Web companion

- PDF.js provides local file import, encrypted-document password callback, page rendering, view modes, scale modes, rotation, page jump, thumbnails, page labels, metadata, permissions, attachments, outlines, and safe external-link confirmation.
- A DOM text layer is synchronized with canvas rendering. It supports text selection, copy, keyboard focus, page-level accessible labels, and search-match marks.
- The shell provides `lang="en"`, a skip link, labeled controls, a viewer `main` landmark, navigation landmarks, visible focus styling, a polite live status region, and a password dialog contract.
- The web lane does not claim that PDF.js preserved an authored structure tree or that the source PDF is PDF/UA conformant.
- The web runtime is pinned to PDF.js `4.2.67` with unpkg and jsDelivr module fallbacks. If neither runtime loads, controls are disabled and the status region explains the recovery path instead of throwing during startup.
- Metadata and permission provider calls are normalized through null-safe fallbacks, so ordinary PDFs without declared metadata or permission dictionaries still open successfully.
- PDF.js, its worker, and pdf-lib are now locally vendored under `web/vendor/`, license files are present, and an isolated browser run observed all three local assets loading with `200 OK`.

## Executed checks

| Check | Result | Notes |
|---|---|---|
| `node Tests/web_reader_contract_test.mjs` | Pass | 42 source contract checks passed, plus selectable text-layer assertion |
| `node Tests/provenance_contract_test.mjs` | Pass | Vendored runtimes, licenses, and ten canonical fixture assets match recorded SHA-256 digests (13 total assets, including the two rotation fixtures) |
| Extracted web module `node --check` | Pass | Browser module parses successfully without executing it |
| `swift test` | Pass | 36 tests passed across the native test suites |
| `swift build -c release` | Pass | Native executable linked successfully |
| `curl -I http://127.0.0.1:8765/web/index.html` | Pass | Local HTTP server returned `200 OK` |
| Pinned PDF.js runtime probe | Pass for fallback | unpkg module returned `200 OK`; the previous cdnjs URL returned `404` |
| Local vendored runtime browser load | Pass | Local pdf-lib, PDF.js module, and PDF.js worker loaded with `200 OK` and the fixture rendered without page/console errors |
| `bash benchmark/test_qpdf_structure.sh` | Pass for source fixtures | qpdf `12.4.0` reports no syntax or stream errors for the public sample and synthetic widget source |
| `bash benchmark/test_qpdf_outputs.sh` | Fail, classified | Generated exports, including parity exports, are checked with qpdf; 6 Form 6 offset-warning artifacts are classified as recoverable warnings, while 8 artifacts still fail for hard AcroForm widget-reachability diagnostics |
| `bash benchmark/test_independent_viewer.sh` | Pass for reopenability | Poppler `pdfinfo`/`pdftotext` and MuPDF `mutool info` independently reopened 38 eligible source and derived corpus PDFs, including the navigation fixture and encrypted native and browser parity outputs with their password; this does not clear qpdf or fidelity failures |
| qpdf rewrite remediation probe | Partial, not sufficient | Rewriting repaired Form 6 offset warnings but did not repair AcroForm widget reachability; qpdf is not a semantic form-provider replacement |
| Consolidated release gate runner | Mixed, preserved | Native tests/build, bounded benchmarks, web contract, provenance, and source qpdf passed; public AcroForm benchmark and generated-output qpdf remain release-blocking failures |
| Public AcroForm benchmark | Fail, preserved | Exit `1`; PDFKit no-op export changes widget state and emits an independent structural warning |
| Browser daemon navigation | Invalid evidence | Competing shared daemon installations returned unrelated FieldCanvas state and were not used for release evidence |
| Isolated Playwright browser run | Pass | Public sample form and Form 6 corpus opened, canvas/text layer rendered, search marks appeared, metadata populated, view/fit/rotate/page-jump controls worked, skip-link focus worked, and the harness asserted zero console/page errors |
| `node Tests/web_accessibility_gate_test.mjs` | Pass for runtime surface | Live browser gate asserted landmarks, skip-link focus, keyboard-focusable text spans, password-dialog labeling, and zero console/page errors; screen-reader observation remains separate |

## Regression coverage added

- Provider inspection test for page geometry, crop-box optionality, security state, and conditional PDF/UA messaging.
- Native export transaction test proves a provider validation rejection preserves an existing destination and removes staging material.
- Native no-op export test proves the provider copies an unchanged public AcroForm byte-for-byte instead of invoking PDFKit serialization; edited AcroForm export remains a preserved failure.
- Browser encrypted no-op fixture proof downloads the password-protected source byte-for-byte, while a queued encrypted edit is rejected without a download.
- Web source contract test for accessibility landmarks, keyboard surface, text layer, search marks, safe links, metadata, permissions, and clipboard fallback.
- Release build coverage catches unavailable PDFKit APIs and Swift SDK drift before completion claims.

## Remaining gates

- Repeat the isolated browser run on the full reviewed fixture corpus, including a scanned page where the expected result is an explicit OCR fallback state.
- Test VoiceOver navigation on the native application and browser text-layer navigation with a screen reader.
- Add encrypted, scanned/OCR, rotated, outlined, attachment-bearing, tagged, signed, XFA, malformed, and large-document fixtures.
- Attach a PDF/UA or structure-tree validator before any conformance claim.
- Measure native/web parity against a reviewed fixture corpus before changing provider-conditional statuses to unconditional guarantees.
