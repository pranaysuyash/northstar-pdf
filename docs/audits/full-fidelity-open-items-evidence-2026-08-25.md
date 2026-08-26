# Full-fidelity open-items evidence, 2026-08-25

This audit records the implementation pass for the long-term PDF capability
mandate. It does not convert a controlled fixture result into a universal PDF
claim. Each lane remains source-bound, provider-labelled, and explicit about
what the validator can and cannot observe.

## Rotated operations and non-zero crop boxes

`Tests/rotated_operation_replay_test.mjs` creates a governed derivative with:

- `/MediaBox [0 0 720 900]`;
- `/CropBox [12 18 624 810]`;
- `/BleedBox`, `/TrimBox`, and `/ArtBox` equal to the non-zero crop box;
- `/Rotate 90`;
- reachable widget structures that exercise the browser form boundary.

The browser reader emits the crop origin and rotation in the shared coordinate
contract. The writer now replays all page boxes and rotation, translates
crop-relative overlay, character-grid, and synthesized-field bounds into PDF
page coordinates, and keeps no-op export byte-preserving. Both the browser
impact validator and independent Poppler validation pass text and raster
outside-region checks with zero changed pixels. Poppler reopens the output with
the original non-zero boxes and rotation.

The same fixture records a deliberate native-field refusal because the
external widget graph is not a supported pdf-lib form target. This is a
provider result, not a silent success.

## AcroForm semantic matrix

`Tests/browser_acroform_semantic_matrix_test.mjs` exercises one reviewed
operation for each field class present in `benchmark/results/public-sample-form.pdf`:

| Field class | Example | Browser export/reopen |
| --- | --- | --- |
| text | `applicant.name` | validated |
| multiline text | `applicant.notes` | validated |
| checkbox | `applicant.subscribe` | validated |
| radio group | `applicant.contact` | validated |
| choice | `applicant.country` | validated |

All names are hierarchical. The report is value-free and records operation
kind, field class, review/export status, validation kinds, and provider
failure codes only. This is not yet parity across every native PDFKit field
graph, external widget topology, XFA form, or independent GUI viewer.

## Encrypted browser-reviewed export through a local companion

`Tests/encrypted_companion_export_test.mjs` proves the explicit companion
composition:

```text
AES-256 source
  -> qpdf password-gated decrypt into an ephemeral file
  -> PDF.js inspection and reviewed pdf-lib overlay
  -> PDF.js reopen and browser preservation validation
  -> qpdf AES-256 re-encryption
  -> Poppler/qpdf independent reopen and outside-region checks
```

The wrong password is rejected. Both source and output are AES-256 encrypted.
The operation remains bound to the decrypted-stage source digest. Independent
text, raster, and reopen checks pass. The browser-only writer still refuses
encrypted mutation, so the companion boundary is visible and capability
negotiated rather than hidden behind a misleading browser claim.

## Signature integrity

`validateSignatureIntegrity` in `web/pdf-signature-guard.mjs` now separates:

- unsigned;
- invalid `/ByteRange` structure;
- structurally valid but CMS verification failed;
- CMS verified with certificate trust unevaluated;
- unavailable or unknown.

OpenSSL verifies detached CMS integrity when a real structurally valid CMS
signature is present. Certificate chain, signer identity, revocation, legal
effect, and long-term validation are intentionally separate fields. The
current synthetic signed fixture reaches structural validation and CMS failure
as expected. A real signed corpus and a trusted-certificate observation remain
required before any cryptographic validity claim.

## Redaction completeness

`benchmark/redaction-completeness-validator.mjs` and
`Tests/redaction_completeness_validator_test.mjs` establish the critical
distinction between whiteout and removal:

- a white rectangle over source text is rejected because Poppler still extracts
  the target text;
- a controlled content-removal mutation passes the text-removal lane only when
  target text disappears and outside text remains unchanged;
- visual, image, vector, annotation, attachment, hidden-revision, and
  cryptographic erasure are reported as unknown or separate gates.

This validator is evidence for a redaction operation, not itself a universal
redaction engine. A MuPDF or companion removal adapter must provide actual
image/vector/object removal before that capability can be promoted.

## PDF/UA and independent viewers

The vendored veraPDF adapter produces per-clause PDF/UA-1 reports for the
governed corpus. Current generated outputs are untagged and fail conformance;
this is a measured baseline, not a PDF/UA claim. Preview observation is
recorded separately as a GUI control-app observation with no retained document
screenshot or raw content. Poppler is the current independent text/raster
validator. MuPDF remains an available independent provider for the next
three-way report.

## Remaining evidence, still active implementation lanes

- general semantic editing of arbitrary existing text, including fonts,
  ligatures, RTL, clipping, transparency, and compressed content;
- byte-for-byte preservation of unauthorized objects after edits;
- full AcroForm widget topology, XFA, annotations, signatures, and hierarchy;
- a real cryptographically signed corpus and trusted verification;
- permanent image/vector redaction and post-redaction forensic checks;
- compliant tagged PDF authoring and PDF/UA preservation;
- independent MuPDF three-way edited-operation comparison and GUI viewer
  observation across Preview and another control application;
- production-scale arbitrary-PDF corpus coverage, crash recovery, resource
  limits, cancellation, and release support evidence.

The MuPDF no-op control lane is implemented in
`benchmark/mupdf-independent-validator.mjs` and passes text, raster, and
reopen comparison for the public browser no-op export. Edited-operation region
mapping is explicitly `notMeasured` until the same crop/rotation authorization
contract is wired into MuPDF.

The project remains long-term and full-capability. These open states are
evidence states and provider admission gates, not permanent product exclusions.

## Reproduction

```bash
PDF_PROOF_BASE_URL=http://127.0.0.1:4184/web/index.html node Tests/rotated_operation_replay_test.mjs
PDF_PROOF_BASE_URL=http://127.0.0.1:4184/web/index.html node Tests/browser_acroform_semantic_matrix_test.mjs
PDF_PROOF_BASE_URL=http://127.0.0.1:4184/web/index.html node Tests/encrypted_companion_export_test.mjs
node Tests/pdf-signature-guard_test.mjs
node Tests/redaction_completeness_validator_test.mjs
node Tests/pdf_ua_validator_test.mjs
node Tests/gui_viewer_observation_test.mjs
```
