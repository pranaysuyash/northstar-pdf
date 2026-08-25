# Privacy-First PDF Preflight Evidence

**Date:** 2026-08-25  
**Status:** Implemented contract and adapter slice; sanitization remains a separate long-term implementation lane  
**Scope:** Native PDFKit and browser PDF.js inspection surfaces  
**Evidence tier:** Tier 1 contract, Tier 2 native unit, Tier 3 isolated Chrome

**Contract revision:** `pdf-editor.preflight` 1.1

## Result

The project now emits a dedicated `pdf-editor.preflight` report for a loaded
PDF. It identifies metadata presence, embedded-data indicators, network
boundaries, possible active-content actions, encryption state, and the limits of
any sanitization claim. The report is source-digest bound and intentionally
value-minimizing.

This is an inspection report, not a sanitizer. It does not rewrite the source,
remove metadata, detach files, neutralize actions, validate signatures, or
certify that a PDF is clean. A future sanitizer must produce a new source-bound
copy and an independent post-sanitize report.

## Contract

The report contains:

- `header`: contract name, version, source SHA-256, generation time, and
  provider descriptor;
- `summary`: counts for findings, warnings, blocked surfaces, unknown states,
  metadata fields, embedded data, network boundaries, and possible active
  content;
- `metadata`: presence bits for title, author, subject, creator, producer,
  creation date, modification date, and keywords, with
  `rawValuesIncluded: false`;
- `embeddedData`: attachment count and possible `/EmbeddedFiles`,
  `/FileAttachment`, `/XFA`, and `/RichMedia` token counts;
- `networkBoundaries`: counts of external, safe, unsafe, internal, and unknown
  destinations, plus possible URI, remote-GoTo, and form-submit actions;
- `activeContent`: possible JavaScript, open-action, additional-action, and
  launch-action token counts, with `executionAttempted: false`;
- `security`: encryption, lock, and permissions-observed state;
- `sanitization`: `not-run`, `safeToClaimClean: false`, source unchanged,
  supported report/new-copy modes, and explicit limits;
- `findings`: typed severity, state, count, reason codes, and evidence method.

The report never carries PDF bytes, page text, OCR text, raw metadata values,
attachment names, URLs, passwords, image pixels, profile values, or active
content payloads. Bounded byte scans use the state `possible`, not `observed`,
because a token is evidence of a possible structure and not proof of
reachability or execution.

## Native and web implementation

Native macOS uses `PDFPreflightBuilder` over the existing `DocumentInspection`
and exposes `PDFKitProvider.preflight(url:password:)`. It reuses PDFKit's
metadata, link, attachment, encryption, and permission observations and adds a
bounded ASCII token scan over source bytes.

The browser imports `web/pdf-preflight.mjs` into the canonical `web/index.html`
surface. The browser fixture snapshot now emits `preflight`, exposes report
construction and validation for harnesses, and renders only aggregate counts,
sanitization state, and limits in the UI. The parallel `web/app.js` artifact is
kept contract-aligned as well.

Validation can bind a report to an expected current source digest. This is a
relational check, so a report with a valid SHA-256-shaped string can still be
rejected as stale when it does not match the current session source.

## Evidence

The value-free Node contract test passed positive reporting and mutations for:

- metadata, attachment, URL, action, encryption, and signature indicators;
- absence of raw metadata, attachment names, destinations, and source bytes in
  serialized output;
- stale source digest when an expected digest is supplied;
- false sanitization claims;
- attempted active-content execution;
- unknown finding severity and state;
- raw page-text fields;
- unsupported contract versions;
- unavailable source bytes producing explicit unknown scan states.

Native focused evidence passed three tests in
`Tests/PDFEditorCoreTests/PreflightContractTests.swift`, covering native
serialization and rejection of a false clean claim. The isolated Chrome test
opened `benchmark/results/public-sample-form.pdf`, confirmed the emitted report
and UI boundary, validated the expected source digest, and rejected a stale
digest.

Commands:

```text
node Tests/preflight_contract_test.mjs
swift test --filter PreflightContractTests
PDF_PROOF_BASE_URL=http://127.0.0.1:4174/web/index.html node Tests/web_preflight_browser_test.mjs
```

## Sanitization limits and next implementation

The following remain explicit long-term build lanes, not permanent exclusions:

- metadata and XMP removal with before/after value-free evidence;
- embedded-file and rich-media extraction/removal policy;
- JavaScript and action neutralization without accidental execution;
- incremental-revision flattening and hidden-object analysis;
- signature invalidation and cryptographic post-mutation reporting;
- XFA, annotation, form, and attachment preservation/removal matrices;
- independent qpdf, Poppler, MuPDF, and GUI-viewer post-sanitize reopening;
- adversarial PDFs, decompression/resource limits, malformed streams, and
  recovery from partial sanitizer output.

The sanitizer must not be implemented as a boolean extension of this report.
It needs a typed operation, a new output digest, a provider capability record,
an independent reopen result, and an explicit list of what was removed,
preserved, or left unknown. Until then, the only safe preflight conclusion is
that the source has been inspected under the declared evidence and remains
unchanged.

## 2026-08-25 contract extension and native/web parity

Revision 1.1 adds explicit provider-neutral surfaces for attachments,
annotations, scripts, revisions, coverage, and unknown coverage. Attachments
report counts without names or payloads. Annotations use normalized `widget`,
`link`, `fileAttachment`, `markup`, and `unknown` kinds. Scripts report action
indicators and require `executionAttempted: false`. Revisions report `%%EOF`,
`startxref`, and `/Prev` evidence, while `hiddenContentState` remains
`unknown` because bounded token scanning is not a revision parser. Each surface
has an `observed`, `partial`, `not-observed`, or `unknown` state with reason
codes, and the summary is checked against the derived unknown-coverage count.

The native adapter enumerates PDFKit annotations and the browser adapter
enumerates PDF.js annotations into the same taxonomy. Provider-specific
enumeration labels are normalized only by the parity comparator. Native token
matching observes PDF name boundaries, preventing `/AA` from being counted
inside a longer name such as `/AAAAAB+...`.

The native/browser harness emits
[`privacy-preflight-parity-report.json`](../../benchmark/results/preflight-parity-2026-08-25/privacy-preflight-parity-report.json)
alongside the broader contract report. It excludes provider identity,
timestamps, generated IDs, and output-file digests from semantic comparison,
but retains source SHA-256, counts, coverage, unknown states, action
non-execution, and sanitization invariants. The report covers all 18 manifest
entries: 16 readable inputs and 2 matching malformed failures.

Three semantic mismatches remain, all on `public-sample-form.pdf`: PDFKit and
PDF.js disagree on the `keywords` presence bit, producing the related metadata
field and metadata-finding count differences. This is retained as an open
provider-fidelity finding. No attachment, annotation, script, revision,
unknown-coverage, source-binding, or raw-content mismatch remains across the
corpus.

The negative checks cover script-execution mutation, unknown-coverage summary
tampering, stale source digests, false sanitization claims, forbidden raw
content fields, unsupported versions, and unknown finding states. The report
remains read-only: it does not execute actions, remove data, or claim
sanitization.
