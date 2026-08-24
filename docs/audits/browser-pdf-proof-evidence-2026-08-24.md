# Browser PDF proof evidence

**Date:** 2026-08-24  
**Surface:** local web companion, isolated Chrome, Playwright  
**Evidence tier:** Tier 2/S1 internal corpus evidence  
**Disposition:** bounded proof passes; production fidelity gates remain open

## Commands executed

```sh
node Tests/web_reader_contract_test.mjs
node --check /dev/stdin < <(sed -n '/<script type="module">/,/<\/script>/p' web/index.html | sed '1d;$d')
node Tests/web_pdf_proof_playwright_test.mjs
node Tests/web_pdf_impact_validator_test.mjs
```

Results:

- Source contract test: 40 checks passed.
- Extracted browser module syntax check: passed.
- Isolated Playwright corpus test: passed.
- Independent impact validator test: passed.
- Browser console observations: one expected password-input accessibility
  warning, one local HTTP 404 for an unprovided ancillary resource, and PDF.js
  `TT` warnings while parsing an existing font. No page error occurred and the
  proof completed both exports.

## Corpus observations

### Native AcroForm

Fixture: `benchmark/results/public-sample-form.pdf`

- PDF.js opened one page.
- Six native fields were detected.
- The test selected the first field and queued `nativeFieldValue` with
  `Browser native fill`.
- pdf-lib exported a derived PDF named
  `public-sample-form-web-proof.pdf`.
- PDF.js reopened the export.
- Source digest, page geometry, native field value, applied operation, and
  provider capability checks passed.
- The only warning was the explicit outside-region object-diff limitation.

### Static text-anchored form

Fixture: `benchmark/results/2026-08-23-pdfkit-form6/artifacts/noop.pdf`

- PDF.js opened two pages.
- Fifteen text-anchored candidates were detected from label and underline
  evidence.
- The test explicitly reviewed the first candidate and queued `overlayText`
  with `Browser overlay fill`.
- pdf-lib exported a derived PDF named `noop-web-proof.pdf`.
- PDF.js reopened the export.
- Source digest, page geometry, applied operation, and provider capability checks
  passed.
- The only warning was the explicit outside-region object-diff limitation.

## Failure found and fixed during browser execution

The first browser run exposed a typed-array ownership bug. Passing the original
source bytes directly to PDF.js allowed the reader to detach the buffer, so a
later pdf-lib export failed with `No PDF header found`. After preserving a
separate immutable source copy, validation exposed the same issue for output
bytes: PDF.js validation detached the buffer before download. Both provider
boundaries now receive separate `Uint8Array` copies.

This fix is covered by the passing Playwright test because the test performs the
full sequence in order: open, inspect, queue edit, export, validate, and
download.

## Outside-region validator evidence

`web/pdf-impact-validator.mjs` is deliberately separate from the pdf-lib writer.
It accepts source and materialized output documents, extracts text with PDF.js,
renders both documents with PDF.js at a fixed scale, and compares only pixels
outside operation-owned page-space regions.

The dedicated test covers:

- a no-op source-versus-source comparison that passes text and raster checks;
- an unauthorized text mutation that fails both checks;
- the same mutation inside an authorized operation region that passes both checks;
- missing operation coordinates returning `unknown` for both checks;
- mismatched operation and coordinate page indexes returning `unknown` for both
  checks.

This proves the browser writer boundary is not allowed to self-certify an
unbounded edit. It does not prove byte identity, object-level preservation, or
agreement with another PDF engine.

## Remaining evidence gaps

- No independent object-level text diff outside edit regions yet.
- No independent-viewer raster comparison for browser exports yet. The current
  raster diff is an independent validator module, but it intentionally uses the
  same PDF.js rendering stack as the browser reader.
- Checkbox, radio, choice, rotated, encrypted, scanned/OCR, signed, XFA,
  malformed, and large-document browser corpus coverage remains to be added.
- The shared Browser Daemon was not used as release evidence because concurrent
  sessions pointed it at an unrelated FieldCanvas page. The isolated Chrome
  run is the authoritative browser result for this proof.
