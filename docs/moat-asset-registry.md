# PDF Editor Compounding Asset Registry

**Status:** Versioned registry implemented; capability lanes remain active until
their named completion gates close  
**Registry:** `pdf-editor-compounding-assets-2026-08-25`  
**Canonical machine artifact:** [`Tests/fixtures/moat_asset_registry.json`](../Tests/fixtures/moat_asset_registry.json)  
**Validation:** [`Tests/moat_asset_registry_test.mjs`](../Tests/moat_asset_registry_test.mjs)

## Purpose

The PDF Editor moat is implemented as durable, privacy-governed infrastructure.
It is not defined by the number of PDF engines or OCR libraries. The compounding
assets are the records and controls that make provider replacement possible while
preserving user trust:

- immutable source identity and digest binding;
- page-space, crop-box, and rotation fixtures;
- text, vector, widget, visual, and OCR evidence;
- candidate explanations and explicit abstention;
- human-confirmed mappings;
- rejected candidates and hard negatives;
- typed operation lineage;
- provider-divergence records;
- export reopen and independent-viewer outcomes;
- reviewed template revisions;
- confidence calibration;
- corpus provenance, consent, license, and retention metadata;
- workflow-level completion and recovery evidence.

The registry gives each asset a stable ID, owner, native path, browser path,
contract references, fixture references, validator references, evidence report,
privacy class, retention policy, and completion gate. This makes the moat
operationally addressable for planning, implementation, regression testing, and
future provider admission.

## Registry rules

The registry is an accountability layer above the shared PDF contracts. It does
not change the meaning of document, coordinate, candidate, operation, template,
provider, or validation payloads.

Every asset must have:

- at least one shared-contract reference;
- a native implementation or adapter reference;
- a browser implementation or adapter reference;
- a governed fixture or corpus reference;
- a validator or mutation-test reference;
- a retained evidence report or machine result;
- a privacy class and retention policy;
- a completion gate that says what “implemented” means.

The registry may point to a partial or open lane. That is intentional. A missing
provider, weak benchmark, unresolved license, or unmeasured recovery path keeps
the asset visible and creates work; it does not remove the capability from the
long-term program.

## Privacy and provenance

Registry and diagnostic records are value-free by default. Permitted records are
asset IDs, fixture IDs, source digests, provider IDs, statuses, counters, timing,
error codes, and report digests. Page text, OCR text, ground truth, profile
values, passwords, image pixels, source bytes, and signature assets are forbidden
from registry logs.

The registry does not authorize source copying or silent learning. Reviewed
corrections can create pending learning events only through the template and
review contracts. A template revision never becomes permission to mutate a new
source PDF without a current source match, mapping review, value review, typed
operation, and export validation.

## Asset status

The current registry intentionally reports both implemented and partial assets.
The important distinction is:

| Status | Meaning |
| --- | --- |
| `implemented` | The asset has a native/web contract path, governed references, executable validation, and a current retained report. |
| `partial` | The core shape exists and is tested, but one or more provider, class, recovery, calibration, or independent-validation gates remain open. |
| `open` | The asset is named and routed, but its implementation or executable evidence has not closed the first gate. |
| `blocked` | A named external, legal, security, or provider condition currently prevents execution. The lane remains active. |
| `quarantined` | The source, provider, or artifact may not enter the trusted runtime until provenance or license review closes. |

Run the registry test with:

```text
node Tests/moat_asset_registry_test.mjs
```

The test verifies all 16 assets, unique IDs, required privacy fields, all
native/web/contract/fixture/validator/evidence references, status vocabulary,
and zero-content logging rules. It writes a value-free report under
`benchmark/results/moat-asset-registry/report.json`.

## Long-term completion rule

The moat is complete only when each asset has current evidence across the
relevant native, browser, companion, hosted, and independent-validator lanes.
Provider divergence, abstention, failed recovery, and hard negatives remain
valuable retained evidence. A future implementation may resolve a mismatch or
promote a provider, but it must not delete the original observation or weaken a
negative case to improve an aggregate score.
