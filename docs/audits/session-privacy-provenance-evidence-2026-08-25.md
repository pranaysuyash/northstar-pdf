# PDF session privacy and provenance evidence

**Date:** 2026-08-25  
**Status:** Implemented and measured  
**Contract:** `pdf-editor.session-provenance` 1.0  
**Corpus:** `docs/fixtures/manifest.md`, 18 entries  
**Evidence tier:** Native Swift contract/runtime plus isolated Chrome PDF.js runtime

## Purpose

The existing `pdf-editor.preflight` contract describes observed source-document
risk surfaces. This companion contract describes what happened during one PDF
session: where processing occurred, whether OCR ran, how the source was retained,
and what export artifact and validation report resulted.

The contract is attached to native `DocumentSession` recovery envelopes and to
the native/browser corpus fixture bundles. It is not a replacement for the
document, edit-session, validation, or preflight contracts.

## Privacy invariants

Every record contains explicit false flags for source bytes, document text, OCR
text, field values, filenames, and URLs. It contains no PDF bytes, text values,
OCR words, profile values, screenshots, attachment names, or source paths.

The record may contain source and output SHA-256 digests because those are the
provenance binding already required by the shared contracts. A digest identifies
an artifact but does not reveal its content; consumers must still treat it as
sensitive metadata and avoid unnecessary telemetry export.

## Contract fields

| Area | Recorded facts | Explicit non-claims |
|---|---|---|
| Processing | local device/browser/companion/remote/mixed/unknown, source input class, data egress class, bounded network and companion request counts | no claim that runtime dependency fetches are document upload |
| OCR | not used or provider locality, provider IDs, processed page count, whether recognized text/bounds were retained | no recognized text, confidence values, or field authorization |
| Source retention | in-memory, local draft, persistent local, external, not retained, or unknown; session-end retention, deletion state, bounded copy count | no source bytes copied into the provenance record |
| Export | not attempted/succeeded/failed/unknown; source/output digests, storage class, validation state, reopen result, operation count, exporter/validator IDs | no claim that a successful download is valid without validation and reopen evidence |

The six states that matter for privacy review are not collapsed into one badge:
`none`, `runtime-only`, `source-bytes`, `derived-content`, `mixed`, and
`unknown` for egress; and `not-used`, local, companion, remote, mixed, and
unknown for OCR. Unknown remains unknown and does not become local by default.

## Corpus result

The refreshed corpus bundles are retained under
[`benchmark/results/semantic-parity/2026-08-25`](../../benchmark/results/semantic-parity/2026-08-25):

| Measure | Native | Browser |
|---|---:|---:|
| Manifest entries | 18 | 18 |
| Successful PDF sessions with provenance | 16 | 16 |
| Declared malformed/open failures without a session | 2 | 2 |
| Processing locality | `local-device` | `local-browser` |
| OCR state in current fixture run | `not-used` | `not-used` |
| Successful exported artifacts | 16 | 16 |
| Successful exports with output digest and reopen evidence | 16 | 16 |

Malformed fixtures are deliberately represented by `inspectionFailed` bundles
with a null session provenance record. A failed open is not a PDF session and
must not receive fabricated locality, retention, OCR, or export claims.

The browser fixture test uses the bundled local PDF.js runtime and reports
`dataEgress: none`. If the browser falls back to a remote runtime, the adapter
records `runtime-only` and keeps document source egress separate.

## Verification

```text
node Tests/session_privacy_provenance_test.mjs
swift test --filter SessionPrivacyProvenanceTests
node Tests/preflight_contract_test.mjs
PDF_PROOF_BASE_URL=http://127.0.0.1:4174/web/index.html node Tests/web_preflight_browser_test.mjs
PDF_PROOF_BASE_URL=http://127.0.0.1:4174/web/index.html PDF_PARITY_RESULT_ROOT=benchmark/results/semantic-parity/2026-08-25 node Tests/pdf_contract_parity_test.mjs
```

Observed results:

- Browser session provenance unit and mutation checks passed.
- Swift session provenance and recovery-envelope round-trip tests passed,
  including stale digest, privacy-flag, OCR-state, and export-state rejection.
- Existing read-only preflight contract checks passed.
- Live browser provenance emission, source binding, zero-content serialization,
  and privacy mutation rejection passed.
- The full native/browser parity run refreshed 18 bundles. Its pre-existing
  whole-document result remains 6 declared mismatches and 0 unexpected
  mismatches; those are document/candidate/coordinate provider differences,
  not provenance-contract failures.

## Remaining build lanes

This contract is now the session-level spine for future OCR and companion
providers. The next providers must emit their actual locality, egress, source
retention, OCR retention, cancellation/recovery, licensing, and export facts.
They cannot inherit the current local-browser or local-device values by copying
the no-OCR defaults. Companion IPC, browser persistence eviction, OCR output
retention, source deletion confirmation, and remote-service disclosure still
need provider-specific runtime evidence.
