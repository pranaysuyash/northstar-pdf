# Browser pre-export privacy transition evidence

Date: 2026-08-31  
Evidence owner: PDF editor browser and validation lanes  
Sensitivity: S1 synthetic/local corpus; the report is value-minimized

## Purpose

The browser editor already had a source-bound mutation gate and a read-only
privacy preflight. This slice closes the missing boundary between those two
systems. A browser writer must now declare its expected protected-surface
transitions before it runs, and a staged output must be compared with the
source preflight before the output is offered for download.

The goal is not to certify a PDF as clean. The goal is to prevent a supported
operation from silently changing a privacy-sensitive structure that the
operation did not authorize.

## Implemented contract

`web/pdf-preflight.mjs` now emits value-minimized structural observations for:

- metadata field presence;
- attachment counts and possible embedded-file/file-attachment indicators;
- embedded action indicators for JavaScript, open, additional, launch,
  submit-form, remote-go-to, and URI actions;
- encryption marker and permission state;
- annotation counts by normalized kind;
- native form field and populated-value counts by kind;
- revision markers and incremental-update estimates; and
- an aggregate privacy-sensitive content count surface.

Raw metadata values, attachment names and bytes, URLs, scripts, form values,
page text, OCR text, screenshots, and PDF bytes are excluded. The preflight
remains report-only: sanitization status is `not-run`, `sourceUnchanged` is
true, and `safeToClaimClean` is false.

`web/pdf-contract-mutation-gate.mjs` now validates:

1. the source preflight against the freshly hashed source digest;
2. declared transition names and states;
3. privacy-sensitive operation declarations and unsupported sensitive operation
   kinds before `PDFDocument.load()`; and
4. optional source/output transition results before publication.

The protected surface state vocabulary is `unchanged`, `changed`, `added`,
`removed`, `unknown`, and `unsupported`. The current browser writer admits no
metadata, attachment, embedded-action, encryption, annotation, revision,
sanitization, redaction, repair, or arbitrary privacy-surface mutation. A
supported native-field write may change the form-value presence summary, but
only with a corresponding typed field operation and explicit output allowance.

## Output validation path

`web/app.js` now builds a second preflight report from the reopened PDF.js
output. The output report uses the output digest as its report identity while
the session and operation ledger remain bound to the immutable source digest.
The following check is added to the existing validation ledger:

```text
privacyPreflight: passed | failed | unknown
```

The browser review panel also exposes attachment inventory, embedded-action
token count, encryption state, and privacy-sensitive form-value presence. A
failed or unknown privacy transition is included in the validation report and
is a publication failure. `validateExport()` promotes either state to the
overall failed result, so `exportAndValidate()` cannot download an artifact
when the protected-surface comparison is uncertain.

## Mutation evidence

The following tests passed locally:

- `node Tests/preflight_contract_test.mjs`
- `node Tests/web_preexport_privacy_gate_test.mjs`
- `node Tests/run-web-e2e.mjs web_pdf_contract_mutation`
- `node Tests/run-web-e2e.mjs preflight`
- `node Tests/run-web-e2e.mjs web_pdf_proof`

The focused contract assertions prove that:

| Mutation or bypass | Result | Evidence |
|---|---|---|
| metadata declared as changed before export | rejected | `privacySensitiveChange`; writer not called |
| operation marked privacy-sensitive | rejected | `privacySensitiveChange`; writer not called |
| embedded-action transition declared unknown | rejected | `unknownPreflightState`; writer not called |
| output encryption state changes | failed | `unauthorizedSurfaces: encryption` |
| output attachment inventory changes | failed | transition comparison identifies `attachments` |
| output metadata presence changes | failed | transition comparison identifies `metadata` |
| output privacy aggregate changes without approval | failed | `privacySensitiveContent` remains unauthorized |
| reviewed form-value presence changes | passed only when explicitly allowed | form surfaces are the only current exception |
| output protected surface is unavailable | rejected before publication | `unknownPreflightState`; no writer/download path |

The browser export proof on `public-sample-form.pdf` and the static two-page
fixture both produced `privacyPreflight: passed` alongside source-digest,
reopen, geometry, outside-region text, and raster checks. This is local
browser evidence, not independent-viewer, production, legal, or all-provider
proof.

## Failure and recovery behavior

- The source bytes remain immutable and are never replaced in place.
- A writer callback is not reached for invalid source binding, unknown
  transition declarations, sensitive operation declarations, or unsupported
  sensitive kinds.
- A staged output that reopens but changes an unauthorized protected surface is
  not downloaded.
- Unknown coverage is preserved as `unknown`; it is not normalized to pass.
- The preflight report remains safe to store in a value-free diagnostics or
  validation ledger, but it is not a sanitization certificate.

## Remaining evidence gates

The browser path currently compares PDF.js-observable structural facts and a
bounded token scan. It does not yet prove byte-for-byte object preservation,
complete hidden-revision absence, cryptographic signature validity, XFA
preservation, permanent redaction, or semantic equality in every independent
viewer. Those are additional provider lanes under the same transition gate,
not reasons to weaken this gate.
