# Feature A: Reading and Navigation Implementation Journal

**Date:** 2026-08-24
**Surface:** Native macOS + Web companion
**Goal:** Move A1–A11 into implemented status with explicit lane-specific behavior and remaining gates.

- Native: implemented in SwiftUI/PDFKit lane.
- Web: implemented in a local companion UI under `web/` with PDF.js.

## Native lane work completed here
1. Added explicit `ViewMode`, `ScaleMode`, link/outline/metadata/search/thumbnail state in core contracts.
2. Expanded inspection to extract:
   - safe link inventory
   - outline/bookmark hierarchy (when present)
   - page label strings
   - metadata/permissions/attachment hints
   - page-level snapshots plus search/index affordances.
3. Added app state + commands for:
   - import/open,
   - single/two-page/continuous mode,
   - zoom + rotate,
   - page jump,
   - thumbnail navigation,
   - search and match navigation,
   - safe-open password path,
   - PDFKit-backed copy/search/export status surface.
4. Added dedicated `Link` and `Search match` rendering in inspector for safe navigation instead of blind link activation.
5. Added accessibility/reading-order evidence section with explicit conditional claims instead of PDF/UA assertions.

## Web lane scaffolding and implementation completed here
1. Added browser local-first companion at `web/index.html`.
2. Implemented equivalent controls for:
   - open/import + in-memory source,
   - single page / continuous / two-up,
   - fit width / fit page,
   - zoom/rotate/page jump,
   - thumbnails,
   - search + result navigation,
   - metadata/permission/attachment view,
   - outline list,
   - links manifest with safe-open policy and explicit confirm-to-open for http(s),
   - password callback for encrypted PDFs,
   - text extraction and copy controls from selected page text.
3. Added a clear lane status panel so conditional features show `Known Limitation` instead of claiming PDF/UA.
4. Added a browser text layer synchronized with every rendered page. It provides DOM selection/copy, keyboard-focusable text spans, accessible page labels, and visual search-match marks while retaining canvas fidelity.
5. Added the bounded PDF.js + pdf-lib completion proof. It preserves source bytes, computes a document contract, inventories native fields, detects text-anchored static candidates with evidence, queues reviewed native or overlay operations, previews them, exports a derived PDF, and validates the export through a separate PDF.js byte copy.

## Remaining risk controls
- Full accessibility tree and tagged-content validator remains a post-MVP gate. Web exposes conditional evidence statement.
- Page/outline metadata extraction still provider-dependent and should be measured against a representative fixture corpus before release claims.
- Native and web automated evidence is recorded in `docs/audits/feature-a-reading-navigation-evidence-2026-08-24.md`.
- Browser interaction evidence now passes in an isolated Playwright Chromium run; the shared daemon remains ignored because it resolves to an unrelated FieldCanvas session.
- Completion proof evidence is recorded in `docs/audits/browser-pdf-proof-evidence-2026-08-24.md`; both the public AcroForm and existing Form 6 static corpus pass the bounded export/reopen path with an explicit outside-region diff warning.

## A1–A11 closeout ledger (latest)

| ID | Feature | Native status | Web status | Completion note |
|---|---|---|---|---|
| A1 | Open/import PDF | Implemented | Implemented | Password prompt path is active in both lanes with source file selection and fallback handling. |
| A2 | Continuous / single-page / two-page view | Implemented | Implemented | Both lanes expose view mode controls and page-jump actions. |
| A3 | Fit width / fit page / zoom | Implemented | Implemented | Web and native provide mode-dependent scaling, with zoom clamp in native and slider UI in web. |
| A4 | Zoom / rotate / pan / page jump | Implemented | Implemented | Pan is native PDFView gesture in macOS and canvas scroll in web companion. |
| A5 | Thumbnails + page labels | Implemented | Implemented | Label resolution is label-first when available, with index fallback. |
| A6 | Text selection and copy | Implemented | Implemented | Native PDFKit selection/copy and web DOM text-layer selection/copy are available; OCR remains a separate fallback provider for image-only pages. |
| A7 | Search + match navigation/highlight | Partial | Implemented | Search navigation exists in both lanes; web now paints match marks in the text layer, while native highlight rendering remains provider/API-gated. |
| A8 | Links, named destinations, outlines | Partial | Partial | Safe-open policy and resolved internal targets are enforced. |
| A9 | Attachments, metadata, permissions, page boxes | Partial | Partial | Metadata/permissions/attachments and page box probes now surfaced; some values remain provider-dependent. |
| A10 | Password-protected / encrypted open | Partial | Partial | Password-retry flow is in place; malformed encrypted files are still provider-gated. |
| A11 | Accessibility tree and tagged content | Conditional | Implemented with conditional source fidelity | Native exposes extracted reading-order evidence and conditional tagged-content status; web exposes a keyboard-focusable DOM text tree. Neither lane claims preservation or conformance of an authored PDF tag tree without a validator. |
