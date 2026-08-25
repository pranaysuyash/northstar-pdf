# Capability-Negotiated Local Provider System

**Status:** Proposed long-term architecture, with contract fixture and pure
negotiation checks implemented
**Date:** 2026-08-25
**Scope:** Native macOS app, browser app, explicitly installed local companion,
OCR providers, high-fidelity PDF engines, measurement, revocation, and shared
contract preservation
**Decision owner:** Project owner
**Related decisions:** D-009, D-022

## Executive decision

Use a provider admission plane beside the shared PDF contract plane.

The admission plane decides whether a local engine may attempt a named
capability for a particular source and policy. It does not redefine documents,
coordinates, candidates, edit operations, or validation reports.

```text
immutable PDF source
        |
        v
shared PDF contracts
document | coordinates | candidates | operations | validation
        |
        +------------------------------+
        |                              |
        v                              v
browser/native adapter          provider admission plane
                                install -> verify -> measure
                                -> enable -> route -> revoke
                                      |
                                      v
                              provider execution adapter
                                      |
                                      v
                         same shared PDF contracts and validators
```

The browser core, native macOS app, and companion may use different engines.
They must produce the same user-intent and safety semantics even when their PDF
bytes, object models, or provider-specific facts differ.

## Why a separate admission plane is necessary

An installed binary is not a supported provider. A provider that can open a PDF
is not necessarily safe for OCR, form filling, text replacement, redaction, or
signature work. A benchmark result for one version is not permanent permission
for every future version.

The system therefore separates:

| Question | Authoritative record | Example outcome |
|---|---|---|
| Is the engine present? | Installation record | `installed` |
| Can the process start safely? | Runtime probe and health record | `healthy` or `quarantined` |
| Was this exact build measured? | Immutable measurement record | `measured` |
| Did it pass the capability gates? | Capability state and gate results | `enabled`, `partial`, or `abstained` |
| May it be used now? | Revocation, license, security, and policy evaluation | `selected` or `revoked` |
| What did it actually do? | Existing provider descriptor and validation report | `pdf-editor.document` and `ValidationReport` |

No one field may answer all six questions.

## Contract boundary

The provider admission envelope is a separate contract:

```text
pdf-editor.provider-capability
```

It is versioned independently from:

```text
pdf-editor.document
pdf-editor.coordinates
pdf-editor.edit-session
pdf-editor.validation
```

The existing shared PDF contracts remain unchanged. Their `PDFProviderDescriptor`
continues to record the provider that actually emitted a document or validation
result. The admission plane records why that provider was eligible, what exact
build was measured, and whether the current policy allowed the route.

The provider system must never add engine-specific PDF object IDs, parser trees,
OCR text, source bytes, profile values, or executable paths to the shared PDF
contracts. If a provider needs those internally, the adapter owns them and
returns only the existing provider-neutral evidence.

## Domain model

### Provider installation

An installation is an explicit local artifact, not an npm package presence
check or a discovered executable on `PATH`.

Required facts:

- stable `providerID` and `engineFamily`;
- exact provider version and build identity;
- platform and runtime kind;
- package/artifact SHA-256;
- license identity and review state;
- install lifecycle state;
- capabilities declared by the provider, not yet trusted as measured support;
- privacy boundary and network policy;
- measurement references for the exact artifact.

The manifest stores an artifact digest and a non-secret installation reference.
It does not store credentials, source bytes, OCR output, profile values, or
unbounded command strings.

### Capability state

Provider lifecycle and capability lifecycle are different state machines.

Provider installation states:

```text
discovered -> installing -> installed -> probing -> measured -> enabled
                                      \-> quarantined
enabled -> revoked -> removed
enabled -> quarantined -> probing or revoked
```

Capability states:

| State | Meaning | May be selected? |
|---|---|---:|
| `declared` | Provider claims the capability; no local evidence | No |
| `unavailable` | Provider cannot expose the capability | No |
| `installedUnmeasured` | Capability is present in an installed build | Only for explicit experiment mode |
| `measuredPartial` | Some required gates passed, others remain open | Only when request explicitly allows partial evidence |
| `enabled` | Required measurement, license, security, and policy gates passed | Yes |
| `revoked` | Previously eligible, now blocked by policy, regression, license, or security event | No |
| `quarantined` | Runtime or input safety failure requires isolation | No |
| `expired` | Measurement or approval is outside its review window | No |

The default product path selects only `enabled`. Experimental routing must be
visible, opt-in, and must emit a warning-qualified validation result.

### Measurement record

A measurement is immutable and bound to:

- the provider artifact digest;
- the capability ID and operation family;
- the corpus manifest digest and fixture IDs;
- the contract version;
- declared gates and their results;
- runtime facts such as OS, architecture, engine build, wall time, peak memory,
  output size, and timeout state;
- independent reopen and outside-region results where applicable;
- the report digest and evidence tier/sensitivity;
- the reviewer or automation identity that produced the record.

Measurement records contain counters, hashes, codes, and bounded metrics. They
do not contain PDF bytes, extracted text, OCR transcripts, signatures, field
values, screenshots, or user document paths.

An exact artifact digest is mandatory. A provider version string alone cannot
activate a capability.

### Revocation record

Revocation is append-only and scoped. A revocation may target:

- one capability of one artifact;
- all capabilities of one artifact;
- an engine family range;
- a license or distribution state;
- a security issue;
- a corpus regression;
- a runtime crash or resource-exhaustion condition.

Required facts:

- revocation ID;
- target provider and optional capability;
- reason code;
- effective time;
- issuer and local audit reference;
- replacement provider or remeasurement requirement;
- whether existing outputs remain readable;
- whether active sessions must stop before another export.

Revocation blocks new routing. It does not rewrite prior operation logs or erase
existing derived outputs. A prior output remains a historical artifact whose
provider and validation evidence are preserved. Reopening it after revocation
may produce a warning if the revoked provider is required for interpretation.

## Negotiation protocol

The browser or native UI sends a capability request, not an engine preference.

```json
{
  "contract": "pdf-editor.provider-capability-request",
  "version": { "major": 1, "minor": 0 },
  "capability": "ocr.textBounds",
  "operationKinds": ["inspect", "candidateEvidence"],
  "source": {
    "byteCount": 1800000,
    "pageCount": 4,
    "isEncrypted": false,
    "isScanned": true
  },
  "policy": {
    "localOnly": true,
    "minimumState": "enabled",
    "requireIndependentViewer": false,
    "allowExperimental": false,
    "preferredProviderIDs": []
  }
}
```

The admission plane returns a decision:

```json
{
  "contract": "pdf-editor.provider-capability-decision",
  "version": { "major": 1, "minor": 0 },
  "decision": "selected",
  "providerID": "companion-tesseract",
  "capability": "ocr.textBounds",
  "measurementID": "measurement-ocr-001",
  "fallbackProviderIDs": ["native-vision"],
  "reasonCodes": ["exactArtifactMeasured", "localOnly", "sourceWithinLimits"],
  "expiresAt": null
}
```

If no provider qualifies, the decision is explicit:

```json
{
  "decision": "abstained",
  "providerID": null,
  "reasonCodes": ["capabilityUnmeasured", "noEligibleLocalProvider"]
}
```

Abstention is a valid product result. It must not silently fall back from OCR
evidence to field creation, from high-fidelity editing to a destructive overlay,
or from a revoked companion to an unmeasured engine.

### Deterministic selection order

1. Reject revoked, quarantined, removed, or unhealthy providers.
2. Require exact artifact digest and compatible admission-contract version.
3. Require the requested capability state and license state.
4. Check source limits, encryption support, scan support, and operation family.
5. Check required independent-viewer or outside-region gates.
6. Apply explicit user or product policy, including local-only routing.
7. Prefer the requested provider IDs, then the highest measured evidence level,
   then stable provider ID order.
8. Return the selected provider, measurement, fallbacks, and reason codes.

There is no “best available” route without an explainable reason. If two
providers tie, stable provider ID ordering prevents routing drift.

## Native, browser, and companion topology

### Native macOS

```text
SwiftUI/AppKit
  -> provider admission registry
  -> PDFKit adapter or local OCR adapter
  -> shared PDF contracts
  -> native and independent validators
```

PDFKit and Vision can be built-in providers with separately measured
capabilities. A companion provider is still selected through the same registry;
the native app must not bypass admission merely because it can launch a local
binary.

### Browser

```text
browser UI
  -> browser admission registry
  -> PDF.js/pdf-lib baseline adapter
  -> optional authenticated companion bridge
  -> shared PDF contracts
```

The browser baseline is always available only for the capabilities its own
artifact has passed. The companion is optional. If the bridge is absent,
unhealthy, revoked, or incompatible, the browser remains usable and presents a
capability-specific abstention.

### Explicit local companion

The companion is a provider host, not a generic shell endpoint. The bridge must:

- bind each request to a browser-origin session and random per-session nonce;
- authenticate the browser using a local handshake token stored outside PDF
  content and never written to diagnostics;
- allowlist the requesting origin and protocol version;
- accept capability requests and source metadata, not arbitrary commands or
  executable paths;
- require source digest and byte count before reading source bytes;
- enforce maximum request bytes, page count, wall time, memory, and concurrency;
- support cancellation and deterministic timeout states;
- keep source bytes and OCR images local unless a separate explicit policy says
  otherwise;
- return provider-neutral contracts plus provider/admission evidence;
- make temporary files private, bounded, and recoverable;
- stop or quarantine the worker after parser crashes, repeated timeouts, or
  resource exhaustion.

The first companion transport may be localhost RPC or a native-messaging host.
The transport is an implementation detail. The capability request and decision
records are the stable boundary.

## Installation lifecycle

Installation is a user-visible, reversible flow:

1. Discover an available package through a trusted local or explicitly approved
   source.
2. Show provider name, exact version, artifact digest, license, capabilities,
   permissions, disk size, network behavior, and uninstall path.
3. Verify package integrity and signature where available.
4. Install into an app-owned location with least privilege.
5. Run a harmless runtime probe with no user PDF.
6. Register as `installed` or `quarantined`.
7. Run the named corpus measurement before enabling any product capability.
8. Enable only the capability states that passed their gates.
9. Expose measurement age, provider version, and revoke/uninstall controls.

Uninstall removes future routing and provider binaries. It does not delete
source PDFs, operation history, templates, validation reports, or prior output
artifacts. Those records retain provider IDs and artifact digests.

## Measurement lifecycle

Measurement is a local, repeatable bake-off, not a one-time installer smoke
test.

```text
installed
  -> runtime probe
  -> corpus inspection
  -> capability-specific operation run
  -> reopen and independent validation
  -> report digest
  -> enable, partial, or quarantine
```

Capability-specific examples:

| Capability | Required evidence before `enabled` |
|---|---|
| `ocr.textBounds` | OCR anchors, bounds, confidence calibration, scanned/noisy/rotated corpus, language policy, source-image unchanged |
| `ocr.searchableLayer` | Text-layer alignment, output reopen, independent text extraction, source raster preservation, PDF/UA status |
| `edit.existingText` | Reviewed text-run corpus, font/glyph/RTL/ligature checks, outside-region text/raster checks, independent viewer reopen |
| `edit.redaction` | Search/object/image/annotation residual scan, permanent removal proof, independent reopen, new-copy and rollback checks |
| `forms.externalAcroForm` | Field inventory, choices/radio semantics, appearance preservation, encrypted and rotated fixtures, independent viewer reopen |
| `reader.largeDocument` | Page/byte/image limits, timeout, peak memory, cancellation, partial recovery, output validation |

The same source corpus can support several capability measurements, but each
measurement has its own gate list and result. A provider cannot inherit OCR
approval from a passing reader benchmark.

## Revocation and recovery behavior

| Event | New routing | Active session | Historical output |
|---|---|---|---|
| User disables provider | Blocked | Finish only if policy permits and source/session remain valid | Retained and readable with provider provenance |
| Artifact digest changes | Blocked | Stop before next provider call | Retained as historical evidence |
| Security revocation | Blocked immediately | Cancel before export; preserve operation log | Retained, marked provider-revoked if reopened |
| License review expires | Blocked for distribution-sensitive capabilities | No new export under expired policy | Retained locally, not repackaged |
| Measurement expires | Blocked unless explicit experiment mode | Current validated session may finish if policy allows | Retained with old measurement reference |
| Provider crash/timeout | Quarantine | Cancel or recover through an approved fallback | No partial output is published |
| Companion unavailable | Browser/native fallback or abstention | No silent capability substitution | Existing output unaffected |

The source PDF and edit session are never destroyed as part of provider
revocation. Recovery may select a different provider only from the original
source-bound operation intent, not by replaying an untrusted provider output as
new source truth.

## Privacy and zero-content logging

The provider admission plane may log:

- provider ID, artifact digest, capability ID, measurement ID;
- source byte count, page count, encryption/scanned booleans;
- duration bucket, peak-memory bucket, timeout/crash code;
- reason codes, gate states, revocation IDs, and report digests.

It must not log by default:

- source paths, PDF bytes, page text, OCR text, screenshots, field values,
  signatures, template labels, profile values, or passwords;
- full command lines or environment variables;
- localhost auth tokens or package URLs containing credentials.

Diagnostics are local and value-free by default. A user-exported diagnostic
bundle is an explicit action and must redact paths and content unless the user
chooses a source-bound support artifact.

## License and supply-chain boundary

License status is an admission fact, not an annotation in a README. A provider
cannot reach `enabled` for distribution-sensitive use when its exact version,
transitive notices, linkage model, and distribution mode are unresolved.

The current project research suggests these roles, subject to exact-version
review:

- PDF.js and pdf-lib: browser baseline, permissive license signals;
- PDFKit: native macOS system provider, platform terms rather than open-source
  redistribution;
- PDFBox, qpdf, Tesseract-family tooling: permissive control or companion lanes
  subject to package and dependency review;
- pikepdf and PoDoFo: version and copyleft/linkage review required;
- Poppler: GPL boundary requires explicit distribution review;
- MuPDF/MuPDF.js: AGPL or commercial decision required before packaging.

This is not legal approval. The registry must retain `reviewRequired` until the
exact package and distribution model are cleared.

## Falsifiers and stop conditions

The design is falsified or must stop promotion when:

- a provider can be selected without an exact artifact digest;
- an unmeasured or revoked capability is routed in default mode;
- a browser request can invoke an arbitrary companion command;
- source bytes leave the local boundary without explicit policy evidence;
- a capability result cannot be tied to a corpus and report digest;
- a provider crash or timeout publishes a partial output;
- revocation deletes or rewrites historical operation evidence;
- native and browser adapters need different user-intent contracts to use the
  same capability;
- a license state is inferred from a package name or engine family alone.

## Implementation sequence

1. **P0:** Land the provider capability schema, registry fixture, deterministic
   negotiation, and native/web round-trip checks. Do not change shared PDF
   contract payloads.
2. **P1:** Add a read-only local registry UI showing installed, measured,
  enabled, partial, revoked, and quarantined states.
3. **P2:** Add the companion handshake with authentication, source-digest
  binding, limits, cancellation, and zero-content diagnostics. The typed
  message contract and native/browser fixture parity are now implemented;
  authenticated transport, origin enforcement, and process isolation remain
  the next runtime layers.
4. **P3:** Measure native Vision, a permissive OCR companion, PDFBox control
   operations, and a high-fidelity candidate provider against class-specific
   corpus gates.
5. **P4:** Enable one capability at a time, with a provider-specific release
   claim and rollback path. Never enable an engine family globally because one
   operation passed.
6. **P5:** Add update, downgrade, revocation-feed, uninstall, and measurement
   expiry recovery only after local lifecycle behavior is stable.

The first safe implementation units are the registry, negotiation contract,
and typed companion protocol. They give the project a stable admission and
transport boundary while the executable supply-chain, sandbox, OCR, and
high-fidelity runtime layers are built and measured rather than silently
assumed.

## First shared-corpus provider comparison

The first executable OCR/provider bake-off is recorded in
[`docs/audits/ocr-provider-comparison-evidence-2026-08-25.md`](audits/ocr-provider-comparison-evidence-2026-08-25.md).
It runs native Vision and installed Tesseract against the governed scanned,
noisy, simulated-handwriting-like, rotated, encrypted, and large-document
inputs. It records accuracy as value-free anchor recall, latency as a bounded
request measurement, privacy counters, license/admission state, and recovery
outcomes. Optional OCRmyPDF, PDFBox, and MuPDF lanes are represented as
uninstalled, unmeasured, or quarantined rather than receiving synthetic scores.

The result is deliberately partial: Vision passes the controlled class gate,
Tesseract fails the noisy-scan gate, and no provider is promoted until exact
artifact, license, searchable-layer/fidelity, cancellation, companion-crash,
and partial-output recovery evidence exists. The shared PDF contracts remain
unchanged, and OCR output remains candidate evidence rather than silent field
creation.
