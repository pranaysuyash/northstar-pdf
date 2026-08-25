# Browser preservation metrics review surface

**Date:** 2026-08-25  
**Evidence tier:** Tier 2/S1 static and focused test, Tier 3/S1 isolated
browser runtime  
**Scope:** Browser review/export panel for PDF.js outside-region validation

## Outcome

The browser review/export panel now exposes value-minimized outside-region text
and raster metrics after every export attempt. The metrics are shown for both
successful and failed validation states.

The panel reports:

- text validation status;
- text pages compared;
- text pages changed outside authorized regions;
- authorized operation count;
- raster validation status;
- raster pages compared;
- raster pages changed outside authorized regions;
- changed pixels and compared pixels;
- outside-pixel ratio;
- maximum channel delta;
- render scale and channel tolerance;
- evidence basis, such as `source-digest-equality` or
  `pdfjs-raster-outside-region`.

The panel does not render the extracted `sourceOutside` or `outputOutside`
strings. This keeps the review surface useful for preservation decisions while
avoiding a content-bearing validation log.

## Implementation

- [`web/index.html`](../../web/index.html) adds the accessible `impactMetrics`
  review section and renders metrics from the existing `ValidationCheck`
  records.
- `validationCheck` accepts an optional value-minimized `metrics` payload. The
  shared check identity, status, message, region, and operation lineage remain
  unchanged.
- No-op exports identify their basis as source-digest equality and do not claim
  that a raster loop ran.
- Reviewed operation exports use the real PDF.js text and raster validator
  outputs, including page-level and pixel-level measurements.
- Unknown and failed checks remain visible and are styled accordingly.

## Runtime evidence

The focused no-op browser run used the public sample form:

```text
Last export: validated
Text status: passed
Text source pages: 1
Text pages compared: 0
Text pages changed outside region: 0
Raster status: passed
Raster source pages: 1
Raster pages compared: 0
Changed pixels / compared: 0 / 0
Outside-pixel ratio: 0.0000%
Evidence basis: source-digest-equality / source-digest-equality
```

The focused failed reviewed-overlay run used the static Form 6 fixture:

```text
Last export: failed
Text status: failed
Text pages compared: 2
Text pages changed outside region: 1
Raster status: failed
Raster pages compared: 2
Pages changed outside region: 1
Changed pixels / compared: 385 / 2,317,088
Outside-pixel ratio: 0.0166%
Maximum channel delta: 240
Render scale / tolerance: 1.5x / 8
Evidence basis: pdfjs-text-outside-region / pdfjs-raster-outside-region
```

The failed static overlay is an important retained result. The browser export
was withheld because the current operation region did not contain all changed
content. The new panel exposes the exact reason instead of presenting only a
generic export failure.

## Tests

- [`Tests/web_reader_contract_test.mjs`](../../Tests/web_reader_contract_test.mjs)
  passes 51 source-contract checks, including the metrics panel, renderer, and
  value-minimized fields.
- [`Tests/web_pdf_proof_playwright_test.mjs`](../../Tests/web_pdf_proof_playwright_test.mjs)
  now asserts that successful browser exports expose the metrics panel and do
  not expose raw outside-region text.
- [`Tests/web_preservation_metrics_browser_test.mjs`](../../Tests/web_preservation_metrics_browser_test.mjs)
  is the focused passing/failed-state browser regression test. It verifies the
  no-op metrics, the failed static-overlay metrics, and export withholding.
- An isolated Chrome no-op run passed the metrics assertions with no console or
  page errors.
- An isolated Chrome failed-export run passed the failure-state metrics
  assertions with no console or page errors.
- The existing complete browser proof remains a preserved failure on the static
  Form 6 overlay path because the underlying outside-region validator reports
  changed text and raster content. This change does not weaken that gate.

## Long-term boundary

This surface is presentation of existing browser validation evidence. It does
not turn PDF.js validation into independent-viewer proof, byte identity, PDF/UA
conformance, universal semantic editing, redaction, signature validity, XFA
support, or production fidelity. The independent Poppler comparison remains a
separate report and provider boundary.

## Reproduction

```sh
node Tests/web_reader_contract_test.mjs
PDF_PROOF_BASE_URL=http://127.0.0.1:4174/web/index.html \
  node Tests/web_preservation_metrics_browser_test.mjs
PDF_PROOF_BASE_URL=http://127.0.0.1:4174/web/index.html \
  node Tests/web_pdf_proof_playwright_test.mjs
```

The second command requires a local server started from the project root:

```sh
python3 -m http.server 4174 --bind 127.0.0.1
```

The server and browser process are test-only and must be stopped after the
run. No PDF bytes leave the local browser surface.
