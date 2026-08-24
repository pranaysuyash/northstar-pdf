# Native/Web Contract Parity Evidence

**Date:** 2026-08-24
**Harness:** [`Tests/pdf_contract_parity_test.mjs`](../../Tests/pdf_contract_parity_test.mjs)
**Native emitter:** [`Sources/PDFContractHarness/main.swift`](../../Sources/PDFContractHarness/main.swift)
**Corpus:** [`../fixtures/manifest.md`](../fixtures/manifest.md)
**Evidence status:** Baseline refreshed with rotation fixtures and independent preservation evidence. Source identity and expected malformed-input behavior align; semantic mismatches remain open.

## Claim and boundary

The native PDFKit adapter and browser PDF.js/pdf-lib adapter should serialize
the same shared user intent and safety contracts for the same PDF corpus. They
do not need to produce byte-identical PDFs, provider-identical diagnostics, or
identical internal IDs.

This harness therefore compares normalized semantic projections of:

- document source identity and page facts;
- native field kind, name, geometry, value presence, and choices;
- candidate kind, suggested type, entry mode, geometry, coordinate, evidence
  families, group count, and label presence;
- page-space coordinate envelopes;
- edit-session operation lineage;
- validation status, reopen/source checks, and check kinds/statuses;
- accessibility and security summaries.

The comparator deliberately ignores provider IDs and versions, timestamps,
random IDs, validation prose, output digests, and browser-only field metadata.
It preserves the native and web serialized bundles unchanged under
`benchmark/results/contract-parity-2026-08-24/{native,web}/` and writes the
full normalized mismatch report to
`benchmark/results/contract-parity-2026-08-24/parity-report.json`.

## Reproduction

The native executable is part of the Swift package:

```bash
swift build --product PDFContractHarness
swift run PDFContractHarness \
  --manifest docs/fixtures/manifest.md \
  --output-dir benchmark/results/contract-parity-2026-08-24/native
```

The full parity run invokes that native emitter, opens every browser fixture in
isolated Chrome, supplies the documented reader password where required,
performs a no-operation export so both lanes emit validation contracts, writes
both serialized sides, and produces the report:

```bash
node Tests/pdf_contract_parity_test.mjs
```

This is a local macOS plus isolated Chrome result. It is not independent GUI
viewer parity, cross-browser proof, production proof, or evidence that a
provider can preserve every PDF object class. Independent Poppler/qpdf
preservation evidence is recorded separately below.

## Corpus result

| Fixture | Source digest | Native | Web | Raw normalized mismatches |
|---|---|---|---|---:|
| `public-sample-form.pdf` | Match | inspected | inspected | 10 |
| `pdfkit-widgets/fixture.pdf` | Match | inspected | inspected | 7 |
| `public-acroform/noop.pdf` | Match | inspected | inspected | 10 |
| `Form 6/noop.pdf` | Match | inspected | inspected | 11 |
| `encrypted-reader.pdf` | Match | inspected | inspected | 8 |
| `truncated-128-bytes.pdf` | No document on either side, expected failure | inspectionFailed | inspectionFailed | 0 |
| `repeated-20-pages.pdf` | Match | inspected | inspected | 7 |
| `printed-scan.pdf` | Match | inspected | inspected | 4 |
| `rotation-corpus/rotated-widget-90.pdf` | Match | inspected | inspected | 7 |
| `rotation-corpus/rotated-form6-mixed.pdf` | Match | inspected | inspected | 11 |

Historical baseline total: **75 normalized mismatches across 10 fixtures**. The count is a
diagnostic baseline, not an accuracy score. It includes intentionally
provider-specific contract differences that still need either an explicit
compatibility rule or an implementation decision.

The same run now retains validated native and browser no-op output bytes and
writes an independent Poppler/qpdf preservation report to
[`benchmark/results/contract-parity-2026-08-24/independent-preservation-report.json`](../../benchmark/results/contract-parity-2026-08-24/independent-preservation-report.json).
Valid source Poppler reopen passed 9/9; native no-op outputs passed independent
reopen/text/raster 9/9; browser no-op outputs passed 9/9, including the
byte-preserved encrypted export. The malformed source failed as expected.

## First mismatches

### 1. PDF.js page boxes are rounded on three fixtures

The public sample and its no-op output serialize page 1 as:

```text
native PDFKit: 595.28 x 841.89
web PDF.js:    595    x 841
```

Form 6 serializes page height as `841.68` in PDFKit and `841` in PDF.js. The
OCR raster fixture and synthetic 612 x 792 widget fixture agree exactly. The
rotated Form 6 fixture repeats the inherited page-box precision variance while
preserving explicit 90/180 degree rotation facts in both bundles.

This is a shared coordinate risk, not merely cosmetic metadata. The current
operations use PDF points and page-space coordinates. Before the contract can
claim native/web geometry parity, the project must decide whether page boxes
are compared at source precision, with a documented provider tolerance, or
through a canonical decimal extraction path. Operations must not silently use a
rounded page box when the target region is near a boundary.

### 2. Text character counts differ on four page groups

PDFKit and PDF.js count text differently on the public sample and Form 6:

```text
public sample page 1: 163 native, 157 web
Form 6 page 1:       2321 native, 2268 web
Form 6 page 2:       3571 native, 3523 web
```

The parity model currently records these as provider counts. They should not
drive template identity or candidate matching without a normalization policy.
The rotated Form 6 pages repeat the same provider count divergence under page
rotation. The count is useful diagnostic evidence, not a cross-provider
semantic text oracle.

### 3. Public AcroForm button metadata differs during inspection

The public sample has six native fields. The normalized field set differs only
in button metadata: PDFKit reports the two `applicant.contact` radio widgets
with choices `email` and `phone` and reports button value presence, while PDF.js
reports no choices and no value presence for those widgets. The text and choice
field geometry, names, and choices otherwise align.

This is the first direct native/web semantic form mismatch. It reinforces the
existing PDFKit external-AcroForm warning. The product must not advertise
native/web field parity until button/radio state and choice semantics are
resolved or represented as explicit provider capability gaps.

### 4. Browser geometry detection emits candidates where native emits none

The browser emits vector-region candidates on the public sample, synthetic
widget fixture, public no-op output, encrypted fixture, and repeated-page
fixture. Native emits no static candidates on those same inputs. Form 6 also
differs materially, with 29 native candidates and 97 browser candidates.

This is expected to be a detector parity gap, not proof that either detector is
correct. The existing browser geometry evidence is intentionally review-only.
The next detector work must compare candidate evidence classes, false positives,
and reviewed region ground truth rather than forcing counts to match.

### 5. Validation check sets differ by provider

Native validation emits:

```text
sourceDigest, outputReopen, pageGeometry, nativeFields,
outsideRegionText, visualDiff, appliedOperations
```

Browser validation emits those checks plus `providerCapability`, while native
marks `nativeFields` as passed for a no-op and browser marks it skipped because
no native field operation was requested. This is a contract alignment issue in
check applicability and provider capability reporting, not necessarily a PDF
fidelity failure.

### 6. Encrypted export behavior diverges

Both adapters inspect the password-protected fixture and agree on source
identity. PDFKit and the browser both complete a byte-preserving no-op export
validation path. The browser does not invoke pdf-lib for this case and records
the provider capability as a source-preserving download; this is not evidence
of encrypted browser editing support.

This remains a real editing capability mismatch. The browser reader and
byte-preserving no-op export support the password-protected PDF through PDF.js,
but the browser writer lane cannot claim encrypted-PDF editing support. The
correct product behavior is an explicit read-only state for queued edits, not
silent decryption or a generic edit-export success message.

### 7. Accessibility summaries are provider-scoped

PDFKit derives `hasReadingOrder` for the public sample and emits provider notes
about extracted reading order. The browser contract explicitly marks tagged
content and reading order as outside the current proof. Nine fixtures differ
only in this summary.

The shared contract shape is present, but the semantics are not yet parity
cleared. Neither side establishes PDF/UA conformance.

## Mismatch inventory

| Mismatch class | Count | Current interpretation |
|---|---:|---|
| `page.geometry-or-text` | 6 | PDF.js page-box precision and rounding difference |
| `page.provider-count` | 6 | Text extraction counting difference |
| `native-fields` | 6 | Native/web field metadata and provider-specific field representation differences |
| `candidate-semantic-set` | 8 | Native/browser detector evidence disagreement |
| `candidate.count` | 8 | Same detector disagreement, summarized as count |
| `coordinates` | 4 | Page-box precision difference after key-order normalization |
| `validation.check-kinds` | 9 | Provider capability and no-op applicability differences |
| `validation.check-status` | 18 | Native-field skipped/passed and provider capability differences after encrypted no-op preservation |
| `document.accessibility` | 9 | Native derived reading-order evidence versus browser not-run state |
| `document.security` | 1 | PDFKit is unlocked after inspection password; browser retains locked-state metadata |

## Evidence and sensitivity

- Native emitter compilation and corpus run: Tier 2/S1, with live macOS PDFKit
  execution.
- Browser corpus serialization and no-op export: Tier 3/S1 plus Tier 4 browser
  observation.
- Independent Poppler/qpdf preservation report: Tier 3/S1 corpus evidence;
  `Tests/pdf_independent_preservation_test.mjs` adds Tier 3/S3 mutation
  sensitivity because an unauthorized region fails and the recorded region
  passes.
- Source digest equality and malformed-input agreement: S1 in this run.
- Comparator key-order/null corrections: S2-style harness defect checks from
  the first run, then a reduced baseline after correction.
- This baseline is not S3 parity evidence yet. The next mutation should alter a
  native or browser emitted page coordinate, field kind, candidate evidence
  family, or validation status and require the report to detect it.

## Not established

- Native and web candidate recall or precision.
- Exact text extraction parity.
- Exact page-box precision parity.
- External AcroForm radio/choice semantic parity.
- Encrypted browser export.
- PDF/UA or accessibility conformance.
- Independent GUI-viewer parity. Poppler parser/renderer reopen and
  outside-region text/raster evidence are now present, but are not GUI or
  byte-level proof.
- Byte-for-byte serialization parity.
- Native template matcher runtime parity.

The report is intentionally retained as a baseline. Future changes should
classify each mismatch as accepted provider variance, contract bug, provider
bug, detector-quality issue, or open capability gap. They should not simply
delete a mismatch from the comparator to make the count smaller.
