# Reviewed Template Native and Browser Semantic Parity Evidence

Date: 2026-08-24  
Status: Passed bounded benchmark; live PDF-derived fingerprint parity remains open  
Evidence tier: Tier 2/S1 native Swift plus Tier 3/S1 isolated Chrome browser execution

## Objective

Run the same reviewed recurring-template corpus through a native Swift adapter and
the browser adapter, then compare the semantic result rather than the provider's
PDF bytes or internal API objects.

The parity boundary is deliberately long-lived and provider-neutral. Both sides
must agree on:

- document class and benchmark policy;
- match state;
- selected template identity, when any;
- abstention behavior;
- false-positive gate outcome;
- overall score;
- candidate identity, state, score, reason, and component evidence;
- class-policy values used for the decision.

The benchmark does not claim that PDFKit and PDF.js produce identical layout
fingerprints for arbitrary source PDFs. It proves that the current native Swift
and browser implementations interpret the same reviewed contract fixtures with
the same semantics.

## Adapters

The native lane is the `PDFTemplateParityHarness` Swift executable over
`PDFEditorCore`. It decodes the canonical corpus, applies the native Swift
implementation of the class-aware matcher, and writes a value-free JSON run.
The adapter intentionally uses provider-independent benchmark values so that
the first parity gate tests shared decision semantics before adding another
source of PDFKit versus PDF.js extraction drift.

The browser lane is the existing browser contract fixture exposed by
`web/index.html`. The test opens the local web surface in an isolated headless
Chrome process and invokes `classifyTemplateIndex` with the same corpus and
calibrated class policies.

The runner is:

[`Tests/template_match_native_browser_parity_test.mjs`](../../Tests/template_match_native_browser_parity_test.mjs)

It writes one canonical corpus before invoking either adapter. This prevents the
two lanes from reading independently reconstructed fixtures.

## Corpus and expected distribution

The reviewed corpus contains 24 value-free cases across six document classes:

| Expected state | Cases | Meaning for completion |
| --- | ---: | --- |
| `exact` | 2 | Exact source identity may propose a matching revision |
| `knownVariant` | 2 | A reviewed layout variant may propose a matching revision |
| `familyMatch` | 6 | Structural family evidence may propose a reviewed candidate |
| `ambiguous` | 6 | Evidence is insufficiently separated, so the matcher abstains |
| `stale` | 1 | Source binding is stale, so replay is refused |
| `noMatch` | 7 | No supported reviewed mapping is safe to propose |

The corpus includes public AcroForm, static printed, native widget, rotated
static, rotated native widget, and scanned-document classes. Scanned documents
have exact and known-variant coverage but no family acceptance because the
reviewed corpus has no positive family evidence for that class.

## Result

Machine report:

[`benchmark/results/template-matching/2026-08-24-native-browser-semantic-parity.json`](../../benchmark/results/template-matching/2026-08-24-native-browser-semantic-parity.json)

The run passed:

```text
fixtureCount:          24
semanticMismatchCount: 0
evidenceMismatchCount: 0
native abstained:      14
browser abstained:     14
native selected:       10
browser selected:      10
browser console errors: 0
browser page errors:    0
```

The state distribution was identical on both sides:

```text
exact:        2 / 2
knownVariant: 2 / 2
familyMatch:  6 / 6
ambiguous:    6 / 6
stale:        1 / 1
noMatch:      7 / 7
```

The evidence comparison covered candidate count, candidate identity, candidate
state, candidate reason, candidate score, page-count, geometry, native-field,
anchor, and region components, plus class policy. Every evidence comparison
passed. The report preserves each case's native and browser state, selection,
abstention flag, and mismatch list for later audit.

The native run is retained separately:

[`benchmark/results/template-matching/2026-08-24-native-run.json`](../../benchmark/results/template-matching/2026-08-24-native-run.json)

The canonical input corpus is retained separately:

[`benchmark/results/template-matching/2026-08-24-reviewed-corpus.json`](../../benchmark/results/template-matching/2026-08-24-reviewed-corpus.json)

## Serialization defects caught by the gate

The first comparison attempt did not pass. The matcher decisions agreed, but the
serialized representations exposed two harness defects:

1. Native JSON omitted `null` selected-template identities while the browser
   projection represented an abstention as `null`.
2. Native and browser policy objects contained the same fields but were compared
   by raw JSON key order.

The runner now normalizes optional selection identities and compares an explicit
policy projection. The corrected run passed without weakening the decision
rules, dropping evidence fields, or ignoring mismatches. This failure history is
important because a parity harness must detect representation defects without
misclassifying them as provider-semantic differences.

## What this clears

- The native Swift and browser matcher implementations currently agree on all
  reviewed state transitions in the shared benchmark corpus.
- Abstention is semantically aligned for ambiguous, stale, and false-positive
  cases.
- Candidate evidence and calibrated class-policy projections are aligned for
  the same value-free fixture input.
- The browser adapter can be exercised in isolated Chrome as a real page surface,
  with no console or page errors during this run.
- The Swift target builds and executes through Swift Package Manager, rather
  than being validated only by source inspection.

## What this does not clear

- It is not byte-for-byte PDF parity, renderer parity, or outside-region
  preservation evidence.
- It is not live PDFKit-versus-PDF.js fingerprint parity. Both lanes consume the
  canonical reviewed benchmark representation in this first semantic gate.
- It does not establish recall or precision on arbitrary recurring versions.
- The corpus is reviewer-labeled but single-curator. Independent reviewer
  agreement is still unmeasured.
- It does not enable silent autofill. A family result remains a reviewed proposal,
  and values remain outside the template record.
- The production Swift completion matcher remains intentionally narrower than
  this calibration harness. This benchmark supports calibration and parity
  evidence; it does not silently promote family or ambiguous matching into
  production completion behavior.

## Reproduction

From the project root, with the local web surface available at the default test
address:

```bash
swift build --product PDFTemplateParityHarness
node Tests/template_match_native_browser_parity_test.mjs
```

The browser runner uses `PDF_PROOF_BASE_URL` when a different local web route is
needed. It exits non-zero on any state, selection, abstention, policy, score, or
candidate-evidence mismatch.

Supporting benchmark checks remain:

```bash
node Tests/web_template_match_benchmark_test.mjs
node Tests/web_template_match_benchmark_browser_test.mjs
```

## Next evidence gate

The next parity unit is to derive the Swift and browser fingerprints independently
from the same real PDF corpus, then compare the resulting normalized geometry,
field sequence, anchor, and region evidence before classification. That work must
preserve this value-free semantic benchmark as a conformance gate. A failure in
real extraction should be classified as an adapter or provider mismatch, not
resolved by broadening normalization or copying one provider's output into the
other lane.

