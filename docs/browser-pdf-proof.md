# Browser PDF.js + pdf-lib proof

**Date:** 2026-08-24  
**Surface:** browser local web surface at [`web/index.html`](../web/index.html)
**Runtime:** PDF.js 4.2.67 for reading/inspection and pdf-lib 1.17.1 for bounded export  
**Status:** lower-layer proof implemented and exercised against the existing
corpus; the complete browser capability program remains active above this proof

## What this proves

This is an implementation and evidence slice, not a product capability limit.
The browser, native, companion, and hosted lanes must continue to project their
results into the shared contracts as additional capability families are built.

The browser web surface now runs this local-first path without uploading document
bytes:

1. Open a local PDF through the file picker.
2. Keep an immutable source byte copy and compute a SHA-256 source digest.
3. Use PDF.js to inspect page geometry, selectable text, annotations, metadata,
   permissions, outlines, links, and attachments.
4. Inventory AcroForm widgets as native fields, including page-space bounds,
   field kind, current value, and choices.
5. Detect conservative static candidates from text labels ending in a colon or
   underline-like text. Each candidate carries a lower-left PDF coordinate,
   suggested type, confidence, provider, and evidence item.
6. Require a user selection before queuing either a native field fill or a text
   overlay. Pending edits are displayed as previews and remain undoable.
7. Use pdf-lib only at export time to set supported native fields and draw text
   overlays in the recorded PDF user-space region.
8. Reopen the derived bytes with a separate PDF.js byte copy and validate source
   digest, output reopenability, page count and page boxes, native field
   round-trips, overlay text extraction, and provider capability.
9. Download only a validated or warning-qualified derived PDF. The original
   source bytes are never replaced in memory.

## Shared contract mapping

The browser objects intentionally mirror the native contract in
[`docs/shared-contracts.md`](shared-contracts.md):

| Shared concept | Browser representation |
|---|---|
| Contract header | `documentContract.header` with `pdf-editor.document`, version `1.0`, source digest, and `pdfjs-pdflib` provider descriptor |
| Document source | `payload.source` with file name, byte count, and SHA-256 |
| Page snapshot | `payload.pages`, using page index, bounds, crop box, rotation, character count, and annotation count |
| Native field | `payload.fields`, using field name, kind, page index, bounds, current value, and choices |
| Candidate evidence | `candidates[].evidenceItems[]`, with `textExtraction` origin, `textLabel` or `underline` kind, region, score, and provider |
| Candidate review | `reviews[]`, created only when a static candidate is explicitly selected for overlay |
| Edit operation | `operations[]`, with `nativeFieldValue` or `overlayText`, source digest, coordinate, previous value where applicable, payload, and reversible flag |
| Validation contract | `lastValidation`, with `passed`, `warning`, `failed`, and `skipped` checks plus source/output digests and operation IDs |

The browser proof keeps `pageIndex` zero-based in contracts and uses PDF points,
lower-left origin, crop-box-relative coordinates. PDF.js viewport coordinates
are converted at the inspection/render boundary and are not persisted as edit
geometry.

## Contract fixture emission

The reader exposes a fixture-only snapshot boundary at
`window.__pdfEditorContractFixture.snapshot()`. It does not expose source PDF
bytes. After a local PDF is opened, the snapshot emits:

- the `pdf-editor.document` envelope;
- explicit page coordinate regions using the shared points/lower-left/crop
  convention;
- the candidate records and their typed evidence items;
- the `pdf-editor.edit-session` envelope with reviews and typed operations;
- the current validation report, including failed or warning-qualified provider
  outcomes.

`Tests/web_pdf_contract_fixture_test.mjs` reads the canonical fixture paths from
[`docs/fixtures/manifest.md`](fixtures/manifest.md), drives the existing browser
reader, chooses a supported native field or reviewed static candidate when one
is available, exports, and prints a JSON bundle to stdout. Optional per-fixture
JSON files can be written by setting
`PDF_CONTRACT_FIXTURE_OUTPUT_DIR=/path/to/output`.

This fixture is an emission and contract-shape proof. It is not a native/web
parity comparison and does not turn a failed provider export into a pass.

## Corpus evidence

The isolated Playwright test in
[`Tests/web_pdf_proof_playwright_test.mjs`](../Tests/web_pdf_proof_playwright_test.mjs)
uses two existing files:

| Corpus file | Observed result |
|---|---|
| `benchmark/results/public-sample-form.pdf` | Opened as a one-page AcroForm; 6 native fields detected; one text field filled through pdf-lib; export reopened; field value round-tripped; page geometry stayed unchanged |
| `benchmark/results/2026-08-23-pdfkit-form6/artifacts/noop.pdf` | Opened as a two-page static PDF; 15 text-anchored candidates detected; one candidate reviewed and overlaid; export reopened; page geometry stayed unchanged; overlay represented in PDF.js text extraction |

Both exports currently report `validatedWithWarnings` when an edit exists.
The warning is intentional: the proof does not yet implement an independent
object-level diff that proves every original text object outside the selected
region is unchanged. Source digest, page geometry, reopenability, field values,
and extracted overlay text are still checked.

## Run locally

From the project root, serve the directory so browser module and worker loading
use an HTTP origin:

```sh
python3 -m http.server 4173 --bind 127.0.0.1
```

Open `http://127.0.0.1:4173/web/index.html`, choose one of the corpus PDFs, and
use the **Completion proof** panel on the right. The browser requires network
access for the pinned PDF.js and pdf-lib CDN bundles in this proof. A production
web app should vendor or bundle those dependencies and set a worker CSP.

Source and browser checks:

```sh
node Tests/web_reader_contract_test.mjs
node --check /dev/stdin < <(sed -n '/<script type="module">/,/<\/script>/p' web/index.html | sed '1d;$d')
node Tests/web_pdf_proof_playwright_test.mjs
node Tests/web_pdf_contract_fixture_test.mjs
```

The Playwright test assumes the local server is already running. It uses a
fresh isolated Chrome instance because a shared browser daemon can be pointed
at another project by a concurrent session.

## Deliberate boundaries

- Candidate detection is conservative text evidence, not OCR, computer vision,
  or a claim that every visible box is fillable.
- Candidate selection is explicit. No heuristic candidate is auto-applied.
- pdf-lib handles bounded form setters and new text drawing. It is not being
  presented as a general semantic editor for arbitrary existing PDF text,
  XFA, signed documents, or complex appearance streams.
- A visible overlay is not redaction. Redaction, sanitization, digital
  signature validation, XFA, OCR, and PDF/UA conformance remain separate gates.
- The export warning is part of the proof contract, not a release failure. A
  browser-local outside-region text and raster validator now compares the source
  and reopened output outside operation-owned regions, fails unauthorized
  mutations, and returns unknown when operation coordinates are missing or
  inconsistent. The next hardening step is an independent-viewer and
  object-level comparison, followed by a reviewed rotated, encrypted, scanned,
  signed, malformed-object, and larger-resource corpus. The current bounded
  expansion of scanned, rotated, encrypted, malformed-truncation, hybrid, and
  40-page fixtures is recorded in
  [`docs/audits/browser-corpus-fidelity-evidence-2026-08-25.md`](audits/browser-corpus-fidelity-evidence-2026-08-25.md).
