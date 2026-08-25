# Independent Poppler comparison for browser exports

**Date:** 2026-08-25  
**Evidence tier:** Tier 3 integration, S1 passing corpus run, S3 focused
divergence and missing-gate mutations  
**Scope:** Browser PDF.js/pdf-lib no-op exports from the current governed corpus

## Outcome

The browser export lane now has a separate, machine-readable comparison between
the PDF.js validation gate and an independently rendered Poppler result.

The independent path is:

```text
browser export
  -> Poppler pdfinfo       page facts and reopen
  -> Poppler pdftotext     outside-region text extraction
  -> Poppler pdftoppm      outside-region raster rendering
  -> qpdf                  separate structural control
```

The browser path remains:

```text
PDF.js inspection and text evidence
  -> pdf-lib only when an operation requires a writer
  -> browser ValidationReport
  -> outsideRegionText and visualDiff checks
```

The two paths do not share a renderer. The new report joins their verdicts but
does not rewrite either provider's evidence.

## Implementation

- [`benchmark/browser-export-independent-viewer-validator.mjs`](../../benchmark/browser-export-independent-viewer-validator.mjs)
  defines the `pdf-editor.browser-export-independent-viewer` 1.1 report,
  discovers retained browser bundles and exports, invokes the existing Poppler
  preservation validator, and compares the text and raster verdicts with the
  corresponding PDF.js checks.
- [`benchmark/independent-preservation-validator.mjs`](../../benchmark/independent-preservation-validator.mjs)
  remains the low-level independent measurement. It uses Poppler bounding-box
  extraction and PPM rendering with page rotation and operation-region handling.
- [`Tests/pdf_contract_parity_test.mjs`](../../Tests/pdf_contract_parity_test.mjs)
  now emits `independent-browser-viewer-report.json` beside the existing
  independent-preservation and semantic-parity reports.
- [`Tests/browser_export_independent_viewer_validator_test.mjs`](../../Tests/browser_export_independent_viewer_validator_test.mjs)
  covers baseline agreement, an intentionally mutated PDF.js raster verdict,
  missing PDF.js checks, normalized metric comparability, valid operation
  binding, and coordinate-mismatch abstention.

The report preserves source digest, browser export digest, page geometry,
outside-region evidence, provider statuses, and disagreement. It ignores only
provider-specific check IDs, provider versions, generated times, and byte
digests when determining text/raster verdict agreement.

## Current corpus result

Machine report:

[`benchmark/results/semantic-parity/2026-08-25/independent-browser-viewer-report.json`](../../benchmark/results/semantic-parity/2026-08-25/independent-browser-viewer-report.json)

| Measurement | Result |
|---|---:|
| Corpus entries | 18 |
| Readable browser exports | 16 |
| Declared malformed expected failures | 2 |
| Poppler independent readable results | 16/16 passed |
| Source digest matches | 16/16 readable |
| Text agreement, readable | 16/16 |
| Raster agreement, readable | 16/16 |
| Unexpected text/raster divergences | 0 |
| Output reopen, readable | 16/16 passed |
| Malformed text/raster state | `unknown` with `expectedFailure`, not pass |

Installed tool versions in this run:

- Poppler `pdfinfo`, `pdftotext`, and `pdftoppm`: `26.08.0`
- qpdf structural control: `12.4.0`

The two malformed fixtures are intentionally not converted into a false
failure or false pass. They have no browser export, Poppler cannot reopen the
source, and the report records `expectedFailure` with `unknown` text and raster
agreement.

## Mutation evidence

The focused test starts from a retained public sample browser export:

- Baseline: Poppler text `passed`, Poppler raster `passed`, PDF.js text and
  raster checks `passed`, agreement `agree`, overall `passed`.
- Mutated PDF.js `visualDiff`: Poppler remains `passed`, PDF.js becomes
  `failed`, raster agreement becomes `divergence`, and the overall report
  becomes `failed`.
- Removed PDF.js text and raster checks: both agreements become `unknown` and
  the overall report becomes `unknown`.

This is S3 evidence that the comparison cannot silently replace a missing or
disagreeing browser gate with an independent renderer's pass.

## What this proves

- Browser exports can be reopened and measured through an independent Poppler
  text and raster path on the current readable corpus.
- The current PDF.js and Poppler outside-region preservation verdicts agree for
  all 16 readable no-op browser exports.
- Rotated, encrypted, scanned, synthetic-handwriting-like, hybrid, large, and
  form fixtures are included in the measured set.
- Source digest mismatches, missing output, provider failures, and provider
  disagreement remain visible states.

## What remains unknown

- This run uses retained no-op browser exports. It does not establish
  arbitrary semantic text replacement, redaction, sanitization, signatures,
  XFA, PDF/UA, or broad page-operation fidelity.
- The current independent renderer is Poppler. MuPDF is already present as a
  separate local reopen/render control in the older corpus sweep, but this
  report does not merge MuPDF output into the Poppler verdict or claim
  three-way renderer agreement.
- A Poppler result is not independent GUI-viewer evidence. Acrobat, Preview,
  Evince, and other viewers may still expose different behavior.
- Raster agreement is outside-region agreement at the validator's configured
  scale and channel tolerance. It is not byte identity and is not a universal
  visual equivalence proof.
- PDF.js text and Poppler text use different extraction representations. The
  report compares the typed gate verdicts and retains each provider's evidence;
  it does not pretend that provider-specific word/run hashes are byte-identical.

## Reproduction

### 2026-08-25 normalization addendum

The comparison envelope now carries normalized provider measurements in
addition to the pass/fail verdict. Poppler metrics include compared and changed
pages, changed/compared pixels, outside-pixel ratio, maximum channel delta, and
operation IDs. PDF.js metrics are read from the value-minimized
`ValidationCheck.metrics` fields when the browser bundle contains them.

The report distinguishes three cases:

- `comparable`: both providers rendered comparable pages and normalized
  measurements are retained side by side;
- `notComparable`: one provider used a source-digest or no-op shortcut, so the
  verdicts may agree without pretending that equivalent raster loops ran;
- `notMeasured`: one provider did not emit normalized metrics.

The browser bundle's serialized `editSession.operations` are now passed into
the Poppler validator. A non-empty validation operation lineage with missing
serialized operations is `unknown`, and a coordinate/page mismatch is also
`unknown`; neither condition is silently treated as an empty authorization
region. This is required before edited browser exports can use the independent
gate.

The current retained 18-fixture report predates the browser metrics fields, so
its readable no-op entries correctly report `notMeasured` for measurement
comparability while retaining the verified `agree` verdicts. The focused test
adds synthetic normalized metrics and proves `comparable`, valid operation
binding, and coordinate-mismatch abstention.

Run the focused contract test:

```sh
node Tests/browser_export_independent_viewer_validator_test.mjs
```

Regenerate the report from retained PDF.js bundles and browser exports:

```sh
node benchmark/browser-export-independent-viewer-validator.mjs \
  --result-root benchmark/results/semantic-parity/2026-08-25 \
  --report benchmark/results/semantic-parity/2026-08-25/independent-browser-viewer-report.json
```

The complete native/browser parity runner emits the same report as part of its
normal output:

```sh
node Tests/pdf_contract_parity_test.mjs
```

No Git mutation, external upload, or source-PDF mutation is part of these
commands.
