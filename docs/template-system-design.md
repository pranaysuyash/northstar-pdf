# Privacy-first recurring PDF template system

**Date:** 2026-08-24  
**Status:** T1 contract/runtime, immutable local capture/revisions, browser capture-review surface, and browser vault lifecycle evidence implemented; native review UI and provider adapter wiring remain pending  
**Scope:** recurring layout recognition, reviewed field mappings, local value references, and safe completion acceleration  
**Canonical base:** immutable source bytes, versioned document contracts, candidate evidence, append-only edit operations, and export validation

## Executive decision

Treat a template as a local, versioned proposal system for recognizing a
recurring PDF layout. A template is not a PDF copy, not a source-of-truth
document, not a profile database, and not permission to edit a future file.

The system has four deliberately separate layers:

```text
source PDF bytes
      |
      v
document inspection + privacy-minimized layout fingerprint
      |
      v
template revision + reviewed field mappings
      |
      v
completion session + user-approved values + EditOperation[]
      |
      v
new export + reopen/validation report
```

The source PDF remains immutable. A template match only creates candidate
proposals. A user must review the proposed mapping and value before an
operation is materialized. An export is always a new artifact. A successful
completion can create a pending learning event, but an active template revision
changes only after an explicit save or update action.

## Product promise and non-promises

The product promise is:

> Recognize layouts that the user has previously reviewed, make the next
> completion faster, show exactly what will be filled, and preserve the source
> PDF until the user exports a separate validated copy.

This design does not promise:

- silent autofill;
- automatic approval of a new or changed layout;
- storage of raw PDFs in the template store;
- storage of personal field values in a template by default;
- arbitrary semantic text reflow;
- OCR certainty for scanned forms;
- legal, cryptographic, or regulatory signature validity;
- cloud synchronization or server-side processing in the local-first lane.

## Core invariants

1. **Immutable source:** the source byte sequence and its source digest are
   never changed by learning, preview, undo, or export.
2. **Template is advisory:** a match can propose a mapping, never authorize an
   edit by itself.
3. **No value leakage:** template records contain mapping references and
   structural evidence, not personal values, unless the user explicitly opts
   into a separately protected local profile vault.
4. **Review before mutation:** every mapping has a review state, and every
   applied value produces an `EditOperation` bound to the current source digest.
5. **No silent drift:** accepted corrections become pending learning evidence;
   they do not silently rewrite an active template revision.
6. **Exact and similar are different:** byte identity, layout-family identity,
   and visual similarity are represented by different match states.
7. **Fail closed:** stale, ambiguous, conflicting, unsupported, or low-confidence
   matches produce review or abstention, not an automatic fill.
8. **Local by default:** source bytes, fingerprints, mappings, profile values,
   review decisions, and operation logs stay on the device unless the user
   explicitly enables a future sync or companion lane.
9. **No content telemetry:** diagnostics contain counters and error codes, not
   PDF bytes, extracted field values, raw labels, or screenshots.
10. **Recoverable history:** template revisions, learning events, and completion
    sessions can be disabled, reverted, or deleted independently.

## The identity model

### 1. Exact source identity

`sourceDigest` is the SHA-256 of the original PDF bytes. It answers:

> Is this byte sequence exactly the one that produced the inspection and
> candidate evidence?

It is used for operation preconditions, stale-session detection, export
validation, and audit lineage. It is not itself a template family identity.

### 2. Layout-family identity

`layoutFingerprint` identifies a recurring structure even when field values,
timestamps, names, and ordinary body text differ. It is computed from a
canonical structural descriptor, then keyed with a local workspace secret:

```text
layoutFingerprint = HMAC-SHA256(workspaceTemplateKey, canonicalLayoutDescriptor)
```

The key is scoped to one local template store. The same document opened in two
different workspaces should not produce a globally linkable identifier.

The canonical descriptor contains only minimized structural features by
default:

- page count;
- page width, height, crop-box presence, and rotation;
- native field count and normalized field kind sequence;
- normalized native field name tokens, represented as keyed tokens;
- candidate region geometry quantized to a stable precision;
- candidate kind and suggested type;
- normalized reading-order relationships;
- repeated anchor and region pattern counts;
- provider-independent layout version.

It does not contain the raw PDF, a rendered page image, or raw field values.

### 3. Anchor identity

Anchors help distinguish two regions with similar geometry. Raw anchor text can
contain names, addresses, account numbers, or other sensitive content, so the
default template stores one of these forms:

| Anchor representation | Default use |
|---|---|
| keyed normalized token | Matching and deduplication inside the same local template store |
| text shape descriptor | Matching generic labels such as date, amount, name, or signature |
| encrypted local label preview | Optional explainability in the local UI |
| raw label text | Never stored in a template by default |

Normalization removes whitespace noise, case variation, punctuation variation,
and unstable values such as dates or long digit sequences. It must not be
treated as semantic truth. Anchor matching is evidence for review, not a value
extraction authority.

### 4. Template family and variant identity

One template family can contain multiple explicitly reviewed layout variants:

- `exact`: same source digest or same canonical structural descriptor with no
  unresolved differences;
- `revision`: an intentional publisher change recorded by the user;
- `variant`: a known page or field-layout alternative that shares a semantic
  completion workflow;
- `unrelated`: retained only as a rejected match signal, never as an active
  mapping source.

The UI must show which identity was matched. “Matched template” without an
identity class is too ambiguous for a sensitive completion workflow.

## Versioned template contract

The existing `PDFContractEnvelope` is correct for one document inspection. A
template spans multiple document sources, so it needs a dedicated envelope
whose primary digest is `templateDigest`, not a misleading `sourceDigest`.

Proposed envelope:

```json
{
  "header": {
    "contractName": "pdf-editor.template",
    "version": { "major": 1, "minor": 0 },
    "templateDigest": "hmac-sha256:workspace:...",
    "generatedAt": "2026-08-24T00:00:00Z",
    "provider": {
      "id": "pdf-editor-core",
      "version": "1.0",
      "platform": "native-or-web",
      "capabilities": ["layout-fingerprint", "reviewed-mapping"]
    }
  },
  "payload": {
    "templateID": "template-uuid",
    "revisionID": "revision-uuid",
    "parentRevisionID": null,
    "displayName": "Quarterly application",
    "lifecycle": "active",
    "privacyMode": "local-minimized",
    "fingerprint": {},
    "variants": [],
    "mappings": [],
    "reviewPolicy": {},
    "learningPolicy": {},
    "audit": {}
  }
}
```

The compatibility rule follows the current shared contracts: same major
version, incoming minor version no newer than the reader supports, safe
defaults for absent additive fields, and rejection before mutation for unknown
or unsafe enum values.

### Implemented T1 contract slice

The first executable slice is now available in
`Sources/PDFEditorCore/TemplateContracts.swift` and
`web/pdf-template-contract.mjs`:

- `PDFTemplateFingerprint` and `createTemplateFingerprint` create a keyed,
  provider-neutral layout identity from page geometry, native field kinds,
  keyed field-name tokens, keyed label anchors, and normalized candidate
  regions. The default record does not contain raw labels or source bytes.
- `PDFTemplateMapping` records an approved semantic key and target selector.
  Confirmed mappings require matching page indexes and remain separate from
  profile values.
- `PDFProfileContract` and `PDFProfilePayload` version profile revisions and
  keep values in a separate device-local or user-selected-vault record.
- `PDFTemplateMatcher` and `matchTemplate` produce `exact`, `knownVariant`,
  `noMatch`, or `unsupported` proposals. They return approved mapping IDs and
  review requirements, never `EditOperation` records.
- Native and web tests cover JSON round-trip, no-raw-content assertions,
  exact/variant/no-match behavior, revoked revisions, header/payload mismatch,
  and browser fixture fingerprint creation.

This is a contract, proposal, and guarded materialization layer. It is not yet
an automatic profile resolver, a native Keychain-backed store, a native
template revision UI, or a silent completion path.

### Implemented T1 capture and immutable revision slice

`Sources/PDFEditorCore/TemplateCaptureContracts.swift` and the corresponding
functions in `web/pdf-template-contract.mjs` now implement local reviewed
capture without changing the source document model:

- `captureDraft` requires the inspected source SHA-256 and creates a value-free
  draft from native fields and directly editable static candidates.
- Static mappings carry normalized page-space coordinates and candidate/evidence
  references. Native mappings carry the keyed field-name token, never a raw
  provider field name.
- Every captured mapping begins as `proposed`. Activation requires a decision
  for every mapping, with at least one mapping confirmed. A rejected mapping is
  retained as reviewed history and is not silently discarded.
- Activation returns a new `active` child revision with a new `revisionID` and
  `parentRevisionID` pointing to the draft. The draft object remains unchanged.
- `PDFTemplateRevisionSet` and browser `appendTemplateRevision` provide an
  append-only local history with template-ID, parent, and duplicate-revision
  validation.
- Browser UI capture stores the draft as the first history entry and activation
  appends the child revision. It does not persist profile values or source bytes.

This is now backed by native Keychain/local encrypted persistence and browser
IndexedDB/OPFS encrypted stores. Native and browser review UI expose unlock,
import/export, recovery, deletion, revision diff, and learning-journal state.
Keychain-loss recovery, browser quota/eviction stress, secure deletion across
backups, and provider-specific completion evidence remain separate gates.

### Implemented runtime safety slice

`Sources/PDFEditorCore/TemplateRuntimeContracts.swift` and the additive browser
functions in `web/pdf-template-contract.mjs` now make the review boundary
executable:

- `PDFTemplateCompletionProposal` materializes only from an exact, known-variant,
  or family match. Ambiguous, stale, unsupported, and no-match states abstain.
- Mapping review and value review are independent state transitions. A profile
  value starts as `resolvedUnreviewed`; selecting a profile is not approval.
- Native mappings require adapter resolution of the current field ID. The
  template's keyed field token is never treated as a raw provider field name.
- Materialized operations carry the current source digest, page-space region,
  session ID, candidate lineage where available, typed payload, and
  `destructive: false` for this bounded completion lane.
- `PDFTemplateLearningEvent` is append-only and starts as `pending`. It can be
  promoted only after a strict validated, reopenable, source-bound export with
  no failed or unknown checks. Warnings do not teach future behavior.
- Native and browser tests exercise stale source rejection, unresolved native
  targets, unsupported values, review requirements, learning promotion, and
  operation lineage.
- The browser fixture now exposes a capture-review surface. Capture creates a
  draft history entry, activation appends an immutable active child revision
  only after every mapping is explicitly confirmed or rejected, preparation
  creates a proposal, and the final apply control remains disabled until every
  mapping and value is reviewed.

The materializer is intentionally not a general PDF writer. It creates shared
operation contracts; the native PDFKit adapter and browser pdf-lib adapter
remain responsible for provider capability checks and export behavior.

### Reviewed template-matching benchmark and class calibration

The first matching benchmark is now executable in
`web/template-match-benchmark.mjs`, with reviewed value-free fixtures in
`Tests/fixtures/template_matching_reviewed_fixtures.mjs` and assertions in
`Tests/web_template_match_benchmark_test.mjs`. It is a calibration and safety
artifact, not permission to enable automatic family matching.

The benchmark now contains 24 reviewer-labeled cases across `publicAcroForm`,
`staticPrintedForm`, `nativeWidget`, `rotatedStaticForm`, `rotatedNativeWidget`,
and `scannedDocument`. The full class calibration report, reviewer-label policy,
score separation, mutation evidence, and remaining recurring-version gates are
recorded in
[`docs/audits/recurring-template-class-calibration-evidence-2026-08-24.md`](audits/recurring-template-class-calibration-evidence-2026-08-24.md).

The fixture ledger covers the complete decision surface:

| Reviewed case | Expected result | Safety meaning |
|---|---|---|
| `exact-public-sample` | `exact` and selected | Source digest is a reviewed example, but mapping and value review still remain required |
| `known-variant-public-sample` | `knownVariant` and selected | Keyed layout agrees while the source digest differs |
| `family-form6-drift` | `familyMatch` and selected | Structure agrees with bounded page and region geometry drift |
| `ambiguous-family-choice` | `ambiguous` and no selection | Equal structural evidence must not choose a template |
| `stale-source-session` | `stale` and no selection | A changed source digest blocks replay before candidate ranking |
| `near-family-negative` | `noMatch` and no selection | Similar geometry with incompatible semantics is a false-positive gate |
| `unrelated-corpus-negative` | `noMatch` and no selection | Different page and field structure is rejected |
| class-specific family positives | `familyMatch` and selected | Reviewed bounded drift is separated from class-specific hard negatives |
| class-specific ambiguous cases | `ambiguous` and no selection | Equal evidence remains an abstention for every matchable class |
| class-specific hard negatives | `noMatch` and no selection | Nearby but incompatible evidence is rejected |
| scanned exact and known variant | `exact` or `knownVariant` | Identity behavior remains available while family inference is disabled |

The benchmark applies deterministic precedence before structural scoring. Exact
source digests and exact keyed layouts are classified first. Family candidates
then use this global fallback policy:

```text
geometry          0.20
native fields     0.25
keyed anchors     0.25
regions           0.30
family threshold  0.76
ambiguity margin  0.05
```

These values are deliberately labeled fallback benchmark policy. They are not
accuracy probabilities and are not product defaults. The class calibration now
derives separate reviewed thresholds from the same components: `0.8352` for
`publicAcroForm`, `0.8296` for `staticPrintedForm`, `0.8624` for `nativeWidget`,
`0.7772` for `rotatedStaticForm`, and `0.8621` for `rotatedNativeWidget`.
`scannedDocument` has family acceptance disabled because the corpus has no family
positive. The benchmark score exposes components so future held-out recurring
versions can determine whether the signals should be reweighted, split further,
or replaced by a provider-specific retrieval step. A family match remains
review-only even when its score is high.

The false-positive gate is mutation-sensitive. The test deliberately lowers the
family threshold to `0.10` and removes the ambiguity margin, then requires the
benchmark to fail on the near-family negative, unrelated negative, and equal-
evidence ambiguity cases. If a future change makes that weakened policy pass,
the benchmark has lost its ability to detect unsafe overmatching.

The browser companion test,
`Tests/web_template_match_benchmark_browser_test.mjs`, loads the existing
public AcroForm and Form 6 PDFs, creates fingerprints through the PDF.js
fixture, and proves exact, known-variant, family, ambiguous, stale, and Form 6
false-positive behavior against live browser extraction. The browser test is
not a claim that the two PDFs are a true real-world recurring family. The
family and ambiguity cases are controlled perturbations of real PDF.js
fingerprints so the scorer and abstention rules are exercised without inventing
document content. The browser fixture also exposes the class calibration
function, but a live browser run does not upgrade the value-free corpus into
production accuracy evidence.

The fixture records contain source paths and review decisions, but no raw labels,
profile values, PDF bytes, or screenshots. This keeps matching calibration
compatible with the template privacy boundary. The current reviewer label is
explicitly single-curator evidence with independent agreement not measured. A
future corpus must add real recurring versions, hold-out evaluation, reviewer
agreement, and per-field decisions before any batch acceptance or automatic
profile resolution is considered.

### Reviewed correction-event benefit measurement

The first correction-event measurement is recorded in
[`docs/audits/reviewed-template-correction-benefit-evidence-2026-08-24.md`](audits/reviewed-template-correction-benefit-evidence-2026-08-24.md).
It measures `reviewedTargetCoverage`, the number of reviewed mappings surfaced
in a completion proposal without resolving profile values. Five structured
source variants moved from zero surfaced targets to one after explicit
source-bound correction promotion. All 35 promoted-revision hard-negative
replays abstained, and rollback returned every case to its baseline state while
retaining the child revision in history.

This result is a controlled contract measurement, not a speed or accuracy claim.
It does not enable automatic learning. The correction must be explicitly
reviewed as same-family, pass strict validated and reopenable export checks, and
create an immutable child revision. Raw profile values, labels, screenshots,
and source bytes remain outside the correction record.

The metric contract is now implemented in
[`web/reviewed-completion-metrics.mjs`](../web/reviewed-completion-metrics.mjs)
and recorded in
[`docs/audits/reviewed-completion-metrics-evidence-2026-08-25.md`](audits/reviewed-completion-metrics-evidence-2026-08-25.md).
It separates reviewed-correction coverage lift, ambiguous/stale/no-match
abstention, hard-negative false-positive rate, and safe-completion readiness.
Safe completion means a source-bound reviewed target is ready for explicit value
review. It never means that a profile value was silently materialized.

### Implemented encrypted local record boundary

`Sources/PDFEditorCore/TemplateStoreCodec.swift` provides authenticated
AES-GCM record sealing for templates, profiles, learning events, and promotion
records. The core accepts key material but does not persist or provision it.
The native app must obtain and protect that key through its Keychain adapter.

`web/pdf-template-store.mjs` provides two explicit modes:

- `createEphemeralTemplateStore()` keeps reviewed records in memory only.
- `createEncryptedTemplateStore()` stores AES-GCM ciphertext in IndexedDB,
  deriving a store key from an explicit passphrase with PBKDF2. A dedicated
  encrypted metadata record authenticates the store before records are read or
  written. The API exposes explicit `unlock`, `lock`, `isUnlocked`, health
  inspection, record deletion, and whole-store deletion.
- Profile records are encrypted twice: the store envelope protects the record
  at rest, and a separate profile passphrase protects the profile payload. A
  profile cannot be read after store unlock until `unlockProfile` succeeds.
  `lockProfile` clears the in-memory profile key.
- `exportEncryptedBackup` exports only the metadata and encrypted record
  envelopes. `restoreEncryptedBackup` can rehydrate a store after detected
  eviction without exposing plaintext to the backup object. Restore requires
  an empty store unless replacement is explicit.
- `inspectHealth` distinguishes `uninitialized`, `locked`, `ready`, and
  `evicted`. A non-sensitive presence marker helps distinguish a browser
  eviction from first use. The marker is only a hint and is not treated as a
  backup or an authority over the encrypted database.
- `createZeroContentLogger` emits an allowlisted event, code, kind, mode, state,
  and count shape. It never accepts IDs, values, labels, PDF bytes,
  passphrases, stack traces, or arbitrary error text.

The browser lifecycle proof is still not a production credential UX. The
encrypted backup API exists and is tested, but download/import UI, backup
retention, lost-passphrase behavior, quota messaging, and user education remain
product work. Browser eviction can be detected only after the browser exposes
an empty database and the presence hint remains available. If both the database
and hint disappear, the state is indistinguishable from first use. The native
codec is similarly not proof that Keychain integration has shipped.

### Fingerprint record

```json
{
  "algorithm": "layout-v1+hmac-sha256",
  "keyScope": "workspace",
  "pageSignatures": [
    {
      "pageIndex": 0,
      "widthPoints": 595,
      "heightPoints": 842,
      "rotationDegrees": 0,
      "nativeFieldKinds": ["text", "choice"],
      "anchorTokens": ["hmac:..."],
      "regionSignatures": [
        {
          "kind": "textAnchored",
          "suggestedFieldType": "text",
          "normalizedRect": { "x": 0.18, "y": 0.72, "width": 0.42, "height": 0.025 }
        }
      ]
    }
  ],
  "layoutFingerprint": "hmac:...",
  "exactSourceDigests": ["sha256:..."],
  "featureVersion": "layout-features-1"
}
```

`exactSourceDigests` are optional, local references to known examples. They are
not required for family matching and should not be exported or synced by
default. A privacy-strict mode can omit them entirely and retain only keyed
layout signatures.

### Mapping record

Every mapping has a stable identity and a target selector. A mapping never
stores the value to insert.

```json
{
  "mappingID": "mapping-uuid",
  "semanticKey": "person.fullName",
  "target": {
    "kind": "nativeField",
    "nativeFieldNameToken": "hmac:...",
    "pageIndex": 0,
    "region": {
      "pageIndex": 0,
      "rect": { "x": 120, "y": 540, "width": 220, "height": 18 },
      "coordinateSpace": {
        "unit": "points",
        "origin": "lowerLeft",
        "pageBox": "crop",
        "rotationDegrees": 0
      }
    }
  },
  "suggestedFieldType": "text",
  "evidenceReferences": ["candidate-uuid", "evidence-uuid"],
  "status": "confirmed",
  "reviewPolicy": "always-review-value",
  "sourceVariantID": "variant-uuid",
  "createdFromSessionID": "session-uuid",
  "supersedesMappingID": null
}
```

For a static region, the target also contains a keyed anchor token, normalized
region, relative reading-order position, and candidate kind. For a native
field, the provider field name token and field kind are stronger evidence than
geometry alone. If native field names are unstable, the mapping can use a
multi-signal selector and must lower its match confidence.

### Value references and local profiles

Actual values live outside the template:

```json
{
  "profileID": "local-profile-uuid",
  "profileRevisionID": "profile-revision-uuid",
  "values": {
    "person.fullName": "encrypted-local-value",
    "person.email": "encrypted-local-value"
  },
  "scope": "device-local",
  "requiresUnlock": true
}
```

The template stores only `semanticKey: person.fullName`. A completion session
may resolve that key from a local profile after the user unlocks or explicitly
selects the profile. The resolved value is copied into the session operation
only; it is not written back into the template.

If the user does not enable profiles, the system still learns layout mappings
and presents empty fields for manual entry.

## Match and review pipeline

### Step 1: inspect locally

The native or web adapter opens the PDF and produces the existing document
contract. The adapter computes source digest, page snapshots, native fields,
candidate evidence, and provider capability facts locally.

### Step 2: retrieve local templates

The template index is queried in this order:

1. exact source digest, when local exact references are enabled;
2. exact layout fingerprint;
3. known variant fingerprint;
4. structural family candidates using page geometry, field-kind sequence, and
   keyed anchors;
5. no match.

The index never sends document bytes, raw extracted text, profile values, or
screenshots to a remote service in the local-first lane.

### Step 3: score with explainable evidence

The score is a proposal-ranking mechanism, not a truth probability. A proposed
initial weighting is:

| Signal | Weight | Why |
|---|---:|---|
| exact source digest | 0.35 | Strongest local identity, when present |
| page geometry and rotation | 0.20 | Protects coordinate compatibility |
| native field kind/name-token sequence | 0.20 | Strong semantic structure |
| keyed anchor token agreement | 0.15 | Helps distinguish nearby regions |
| region pattern and reading order | 0.10 | Supports static forms and variants |

These weights require corpus calibration. They must not be treated as a
validated accuracy metric until measured against reviewed fixtures.

### Step 4: classify the match

The UI shows the match state and reasons:

| State | Proposed behavior |
|---|---|
| `exact` | Preselect compatible mappings, still require user review before values are applied |
| `knownVariant` | Show changed pages, added/removed mappings, and require mapping review |
| `familyMatch` | Show all evidence and require field-by-field review |
| `ambiguous` | Do not preselect values; ask the user to choose a template or continue manually |
| `stale` | Refuse replay against the current source digest; offer remap from fresh candidates |
| `unsupported` | Keep the document readable but disable the affected mapping or operation |
| `noMatch` | Offer manual completion and an explicit “save as new template” action |

### Step 5: review mappings and values

The review UI has two separate approvals:

1. **Mapping review:** “This region or native field corresponds to this semantic
   key.”
2. **Value review:** “Insert this current value into this approved target.”

Accepting a mapping does not insert a value. Selecting a profile does not
approve all values silently. The user can accept safe mappings in a batch, but
the preview must list every target, value source, page, coordinate, and
operation kind before applying.

### Step 6: materialize the session

Each accepted value creates an `EditOperation` containing:

- current `sourceDigest`;
- `templateID` and `revisionID` through the edit-session metadata;
- `mappingID` and candidate evidence reference;
- target field or page-space region;
- previous value when available;
- typed payload and operation kind;
- review decision ID;
- reversible and destructive flags;
- provider and coordinate provenance.

The source remains unchanged. Undo removes or rebuilds from the source plus the
remaining operations.

### Step 7: export, validate, and learn

Export produces a new PDF. Validation must reopen it and check source identity,
page geometry, field values or overlay evidence, and any relevant visual or
independent-viewer checks. Only after a successful export and explicit user
choice can the session create a template-learning event.

## Learning policy

The default policy is **learn reviewed structure, never silently learn values**.

### What may become a learning event

- user-confirmed native field to semantic-key mapping;
- user-confirmed candidate to semantic-key mapping;
- user correction of a proposed region, type, page, or anchor;
- user rejection of a false candidate;
- user-selected variant relationship;
- successful export and validation result;
- user note such as “this is the 2026 layout revision.”

### What does not become a template fact by default

- raw profile values;
- raw extracted field contents;
- screenshots or page images;
- unreviewed detector suggestions;
- failed or unvalidated exports;
- a mapping inferred only from one ambiguous match;
- values typed into a session without an explicit mapping-save action.

### Pending learning and revision creation

```text
confirmed session
      |
      v
pending learning event, local and reversible
      |
      +-- discard
      +-- apply only to this session
      +-- save as new template revision
      +-- merge into existing revision after conflict review
```

An active revision is immutable. Updating a template creates a new revision
with a parent revision ID. Rejected mappings are retained as negative evidence
inside the local history but are not exposed as active mappings. A user can
revoke a revision, which prevents new matches while preserving past session
lineage.

## Privacy and threat model

### Assets

- original PDF bytes;
- extracted text and OCR output;
- names, addresses, identifiers, signatures, dates, and account values;
- template fingerprints and mapping relationships;
- local profile values;
- completion operation history and exported files;
- diagnostics that could accidentally contain document content.

### Threats

- accidental cloud upload through an analytics or OCR endpoint;
- raw labels or values leaking into logs, crash reports, or template exports;
- a stale template applying to a changed form;
- a malicious PDF exploiting a parser or embedded action;
- browser storage being mistaken for a backup;
- another local user accessing an unlocked profile vault;
- sync metadata linking documents across users or workspaces;
- a template update silently changing future mappings.

### Mitigations

| Threat | Mitigation |
|---|---|
| accidental upload | no network call in the local core; dependency bundles and OCR providers are explicit capabilities |
| content in logs | `createZeroContentLogger`, structured error codes and counters only; never log PDF text, values, bytes, IDs, passphrases, or screenshots |
| stale template | source digest precondition, layout revision checks, stale state, and fail-closed replay |
| malicious PDF | isolate parser/render workers, disable PDF JavaScript/actions by default, impose size/page/time limits |
| browser storage confusion | label ephemeral, local draft, and file-backed modes separately; inspect health, show eviction and backup limits, and restore only from encrypted backup envelopes |
| profile exposure | separate profile encryption, explicit unlock, in-memory key clearing, local encryption, no profile values in templates |
| sync correlation | no sync by default; future sync uses client-side encryption and scoped workspace keys |
| silent template drift | immutable revisions, pending learning events, explicit save/update, and revision history |

### Storage modes

#### Native macOS

- Ephemeral session: memory only until export.
- Local template store: encrypted records in the app support directory, with a
  per-store key protected through the macOS Keychain.
- Profile vault: separate encrypted store and unlock boundary; templates hold
  only semantic references.
- Source PDFs: never copied into the template store. If a local draft is
  enabled, source storage is explicit, separately listed, and deletable.

#### Web

- Ephemeral mode is the default.
- Opt-in local templates use IndexedDB for structured encrypted records. The
  store has explicit locked, unlocked, healthy, evicted, restored, and deleted
  states. The UI must state that browser storage can be evicted and is not a
  backup.
- A privacy-strict profile vault requires a separate profile unlock secret. The
  store key alone is insufficient to read profile values. Without profile
  unlock, the web app can retain layout mappings but not profile values.
- Encrypted backup export is the recovery path after eviction. A backup is
  ciphertext plus non-content metadata, not a plaintext JSON export.
- No cloud sync is part of this design. A future sync mode must be a separate
  capability with client-side encryption, deletion, export, and key recovery
  design before implementation.

## Native and web parity

| Concern | Native macOS | Web local-first |
|---|---|---|
| inspection | PDFKit provider contract | PDF.js document contract |
| layout features | Swift detector and optional OCR adapter | TypeScript text/geometry detector and optional worker |
| template store | encrypted local app store | opt-in encrypted IndexedDB/OPFS |
| profile values | Keychain-backed local vault | explicit local unlock, no default cloud |
| source bytes | file URL/security-scoped bookmark | file picker/File System Access/download fallback |
| preview | PDFKit view plus operation overlays | PDF.js canvas/text layer plus operation previews |
| export | PDFKit or gated provider | pdf-lib bounded writer, future provider fallback |
| validation | native reopen plus independent gates | PDF.js reopen plus future raster/object diff |
| sync | not in local-first core | not in local-first core |

Parity means the same intent, evidence, review state, operation semantics, and
validation vocabulary. It does not require identical PDF bytes or identical
provider scores.

## Failure, recovery, and deletion

### Stale or changed document

If the current source digest differs from the session or mapping precondition,
the app must not replay operations. It keeps the old session intact, re-inspects
the new PDF, and offers remapping from fresh candidates.

### Ambiguous match

The app shows the top candidates and evidence, but leaves all values unapplied.
The user can choose a known variant, map fields manually, or continue without a
template.

### Failed export or validation

The source remains available. Pending operations and validation checks remain
stored in the session so the user can retry with the same provider, change the
operation, or export through a different provider. Failed sessions cannot create
active learning revisions.

### Template deletion

Deleting a template removes future matching and active mappings. The system
should offer separate choices for deleting:

- the active template revision;
- all historical revisions;
- pending learning events;
- profile values;
- completion session history;
- source drafts and exported files.

Deletion must not silently delete exported PDFs that the user saved elsewhere.

### Template export/import

Exporting a template is a sensitive action. The default portable form contains
minimized structural descriptors and mapping references but no profile values,
raw PDF bytes, or raw labels. The UI must warn that even layout fingerprints
can reveal document-family metadata. A stricter export can omit exact source
references and use a new recipient workspace key.

## Acceptance evidence

The system should not move from design to active implementation until these
checks are represented in tests or reviewed runtime evidence:

1. Template JSON round-trips through native and web contract readers.
2. A template record contains no source bytes or raw profile values by default.
3. Different values in the same reviewed layout produce the same layout family
   fingerprint but different source digests.
4. A changed page box, rotation, native field kind, or target region produces a
   lower match or a stale/conflict state.
5. An unreviewed candidate cannot create an edit operation.
6. A selected profile value remains absent from the template record after
   completion and export.
7. An operation with the wrong source digest is rejected before PDF mutation.
8. A failed export does not create a learning revision.
9. A successful export followed by explicit “save template update” creates a
   new revision with a parent revision ID.
10. Revoking a revision prevents new matches while preserving past audit
    lineage.
11. Native and web adapters produce equivalent mapping and operation semantics
    for the same reviewed fixture corpus.
12. No network request is made by the local template, matching, profile, or
    export path unless an explicitly enabled capability says so.

The existing browser proof already covers the lower layer for source identity,
candidate evidence, reviewed operations, export, reopen, and validation. The
template system should build on that proof rather than bypass it.

## Recommended delivery slices

### Slice T1: local reviewed template capture

**Status:** contract, guarded runtime, encrypted record primitives, immutable local capture/revisions, and browser capture/review UI complete; native capture/review UI and adapter wiring pending

- template family and revision records;
- exact and structural fingerprints;
- native-field and static-region mappings;
- explicit save/update action;
- no profile values;
- native and browser JSON round-trip tests.

### Slice T2: local matching and review acceleration

**Status:** proposal matcher, completion materialization, reviewed state/false-positive benchmark, and controlled document-class calibration complete; local index, native review UI, adapter wiring, genuine recurring-version calibration, and production promotion remain pending

- local template index;
- exact/variant/family match states;
- explainable evidence panel;
- mapping diff review;
- stale and ambiguous abstention paths.
- reviewed hard negatives and a mutation-sensitive threshold gate.

### Slice T3: separate local profile vault

- semantic-key references;
- explicit profile selection and unlock;
- preview of resolved values;
- no template value persistence;
- deletion and export controls.

### Slice T4: hardening and optional storage

**Status:** encrypted record lifecycle, explicit profile unlock, ciphertext backup recovery, deletion, eviction detection, and zero-content logging complete; recovery UI, worker isolation, and deletion audit pending

- encrypted browser persistence;
- worker isolation and limits;
- template import/export;
- independent diff validation;
- revocation, recovery, and deletion audit.

### Slice T5: optional sync, only if required

- client-side encrypted sync;
- workspace key and recovery model;
- conflict merge for template revisions;
- server retention and deletion contract;
- explicit metadata leakage review.

## Open product decisions

The technical design can proceed without these decisions, but they should be
resolved before T2 or T3:

1. Should local template persistence be opt-in for the first release, or should
   the user explicitly choose “ephemeral” to disable it?
2. Should the profile vault start as manual key/value entries, or integrate
   with a broader local identity/profile system?
3. Should users be able to accept all mapping proposals for an exact reviewed
   variant in one action, provided every value still appears in a preview?
4. Is portable template export required before local matching is proven?
5. Is multi-device sync a real product requirement, or should templates remain
   device-local until the privacy and key-recovery model is independently
   validated?

## Decision summary

Adopt the local, revisioned, evidence-backed template model for the next design
and implementation slice. Keep raw documents and values outside templates,
require review before operations, bind every operation to the current source
digest, and learn only from explicitly confirmed, validated sessions. Defer
cloud sync, silent autofill, and arbitrary content editing until separate
privacy, fidelity, and recovery gates are passed.

## Implementation addendum, 2026-08-25

The formerly proposed persistence and review boundary is now implemented in
the native and browser adapters. Native uses encrypted Keychain-backed template
and profile vaults. The browser supports encrypted IndexedDB and OPFS stores,
with encrypted backup/recovery, deletion, eviction state, and zero-content
diagnostics. Both adapters expose capture, mapping approval, profile unlock,
exact value approval, source-bound operations, validated child revision
preparation, value-free transfer, learning journals, revision diffs, and
client-encrypted sync contracts.

The implementation preserves the original safety decision. Strict validation
creates a pending immutable child revision automatically in the current
session, but persistent future matching changes only after explicit reviewer
save. This is automatic audit materialization, not silent autofill or silent
template mutation. The implementation evidence and remaining runtime gates are
recorded in [`audits/template-lifecycle-evidence-2026-08-25.md`](audits/template-lifecycle-evidence-2026-08-25.md).
