# Native and browser structural fingerprint parity evidence

Date: 2026-08-25

Status: implemented fixture and comparator; structural divergence remains
explicitly measured

Evidence tier: Tier 2/S1 Node fixture and mutation evidence, consuming the
existing Tier 2 native and Tier 3 isolated-Chrome emitted bundles

## Outcome

The project now has a dedicated native-versus-browser structural fingerprint
fixture. It consumes the same emitted PDFKit and PDF.js/pdf-lib bundles used by
the existing semantic parity runner and compares a value-minimized structural
projection rather than provider bytes or identifiers.

The fixture covers all 18 current manifest entries:

- 14 readable ordinary/security/navigation/form/raster/hybrid cases;
- 2 static Form 6 candidate-bearing cases;
- 2 malformed expected-failure cases.

The generated artifacts are:

- [`Tests/fixtures/pdf_fingerprint_parity_fixture.json`](../../Tests/fixtures/pdf_fingerprint_parity_fixture.json)
- [`benchmark/results/semantic-parity/2026-08-25/fingerprint-parity-report.json`](../../benchmark/results/semantic-parity/2026-08-25/fingerprint-parity-report.json)

The reusable implementation is:

- [`web/pdf-fingerprint-parity.mjs`](../../web/pdf-fingerprint-parity.mjs)
- [`benchmark/generate_fingerprint_parity.mjs`](../../benchmark/generate_fingerprint_parity.mjs)
- [`Tests/native_browser_fingerprint_parity_test.mjs`](../../Tests/native_browser_fingerprint_parity_test.mjs)

## Fingerprint boundary

The fingerprint retains structural facts that affect document understanding or
review safety:

- page count, page boxes, crop geometry, and rotation;
- selectable-text presence and character-count shape;
- native field population, field kinds, choice cardinality, and geometry;
- candidate population, candidate kinds, suggested field types, entry modes,
  group sizes, evidence kinds, evidence origins, label-association shape,
  candidate geometry, and coordinate-space metadata;
- annotation totals and annotation taxonomy;
- link and outline shape plus attachment counts;
- permissions, security state, accessibility facts, and warning counts.

The fixture does not retain raw labels, evidence prose, provider IDs, evidence
IDs, timestamps, output digests, or PDF bytes. Source SHA-256 and byte count are
retained only as source-binding identity. A structural fingerprint is therefore
not a second source document or a content archive.

## Current aggregate result

| Result | Count | Meaning |
|---|---:|---|
| Equal | 2 | The two malformed fixtures fail in the same expected state; no readable fixture is incorrectly counted as equal by hiding its provider gaps |
| Semantic divergence only | 8 | Provider observations differ in a product-relevant structural feature, without an additional tolerated text representation difference |
| Mixed divergence | 8 | A readable fixture has both product-relevant divergence and a tolerated text-count representation difference |
| Representation-only divergence | 0 | No fixture has only a character-count difference without another current provider difference |

The 16 readable fixtures therefore have at least one recorded provider
divergence. The report does not convert those divergences into a release pass or
silently normalize them away.

## Structural divergence clusters

### Permission observability: 16 of 18 fixtures

Native PDFKit reports `canPrint`, `canCopy`, `canModify`, and
`canAddAnnotations` as true on 16 readable fixtures. The browser bundle emits
false for those same values while retaining `isReadOnly: false`.

This is not treated as harmless serialization noise. It is a provider
observability divergence: the browser adapter currently lacks equivalent
permission evidence or is applying a conservative fallback. The safe product
behavior is preferable to an optimistic permission claim, but parity remains
open until the browser lane distinguishes `observed-false` from
`not-observed` and can bind the result to actual PDF permission flags.

### Text character counts: 8 of 18 fixtures

PDFKit and PDF.js segment or count selectable text differently on eight readable
fixtures. The existing parity tolerance accepts these as representation-level
differences when the page count and text-presence state agree.

Observed examples include:

- public/native AcroForm pages: native 163 versus browser 157 characters;
- the 40-page hybrid stress input: native 3,260 versus browser 3,140;
- the static Form 6 pages: native 5,892 versus browser 5,791.

These differences do not currently become semantic failures by themselves, but
they are retained as evidence because text-run replacement, label association,
OCR alignment, and reading order cannot assume identical provider segmentation.

### Static Form 6 candidate population: 2 of 18 fixtures

Both candidate-bearing fixtures report 103 native candidates and 70 browser
candidates. The divergence is not one scalar count only:

| Feature | Native | Browser |
|---|---:|---:|
| Candidate count | 103 | 70 |
| Checkbox suggestions | 10 | 16 |
| Date suggestions | 12 | 8 |
| Radio suggestions | 12 | 7 |
| Text suggestions | 63 | 33 |
| Single-text regions | 71 | 36 |
| Radio groups | 12 | 7 |
| Vector-rectangle evidence items | 93 | 57 |
| Whitespace evidence items | 0 | 4 |
| Underline evidence items | 1 | 0 |
| Label-associated candidates | 103 | 70 |

The shared detector vocabulary is therefore present in both lanes, but the
providers differ in geometry extraction, grouping, field-type inference, and
evidence attribution. This is the highest-priority fingerprint cluster because
it changes which regions the user is asked to review.

### Candidate coordinate-space metadata: 2 of 18 fixtures

The rotated Form 6 source exposes a coordinate-space mismatch. Native
candidates report `rotationDegrees: 0` in the candidate coordinate metadata,
while the browser candidate population reports `rotationDegrees: 90` and
`180` groups for the rotated source. A second Form 6 output has both lanes at
zero rotation but still differs in candidate population and grouping.

This confirms that page rotation and candidate-region rotation are currently
not normalized at one canonical adapter boundary for every source class.
Candidate operations must remain review-only until this is reconciled or the
coordinate mismatch is represented as an explicit abstention reason.

### Encrypted-hybrid page geometry: 1 of 18 fixtures

On `encrypted-hybrid.pdf`, native reports the first page as 595.28 by 841.89
points while PDF.js reports 595 by 841 points. The second page agrees. This is a
small but real page-box precision difference in an encrypted hybrid source and
is retained as a semantic geometry divergence because page-space coordinates
and outside-region validation depend on it.

## Failure controls

The fixture includes deliberate mutations for:

- page rotation;
- permission values;
- stale source digest;
- candidate population count;
- candidate coordinate-space rotation;
- tolerated text-count representation drift.

The mutation test verifies that each change is classified at the intended
feature path and that source digest drift is reported through the source-binding
gate. It also verifies that the fixture cases do not carry raw labels,
timestamps, provider identifiers, output digests, or PDF bytes.

## Interpretation and next engineering gates

The current parity state is not “native and web disagree” in one undifferentiated
sense. It is four separate engineering programs:

1. Permission normalization must distinguish observed source permissions from
   conservative provider fallback and unknown coverage.
2. Text extraction needs run-level and OCR alignment fixtures that tolerate
   segmentation noise without hiding changed reading order or text identity.
3. Static candidate detection needs shared rotation normalization, detector
   configuration parity, grouping reconciliation, and reviewed split/merge
   adjudication.
4. Page geometry needs precision policy for encrypted and mixed-content sources,
   including coordinate mismatch abstention before any edit is materialized.

The fixture is a measurement surface, not a new semantic authority. The shared
document, coordinate, candidate-evidence, operation, and validation contracts
remain authoritative; the fingerprint records where native and browser adapters
currently fail to emit equivalent observations.

## Reproduction

```bash
node benchmark/generate_fingerprint_parity.mjs
node Tests/native_browser_fingerprint_parity_test.mjs
```

The generator reads the retained native and browser bundles under
`benchmark/results/semantic-parity/2026-08-25/`. It does not re-open external
documents, send content to a service, or retain raw document text in the
fingerprint fixture.

## Remaining evidence boundary

This is Tier 2/S1 fixture and mutation evidence over existing native/browser
bundle outputs. It is not a new native runtime run, a new browser runtime run,
an independent viewer proof, a production accuracy claim, or proof of arbitrary
PDF semantic editing. The source bundles retain their own native and browser
evidence tiers. The next parity promotion requires fresh native and isolated
browser regeneration after the permission, rotation, and candidate-adapter
changes are made.
