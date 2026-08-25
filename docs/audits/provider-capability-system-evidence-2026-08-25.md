# Capability-Negotiated Local Provider Evidence

**Date:** 2026-08-25
**Status:** Contract, policy, and reference companion-host slice implemented;
installer, authenticated transport, and real provider runtimes remain open
**Scope:** Native macOS, browser core, optional local companion, OCR, and
high-fidelity provider admission
**Evidence tier:** Tier 1/S1 design and fixture validation plus Tier 2/S1
native and browser contract tests

## Result

The project now has a separate provider admission contract and deterministic
registry model. It does not change the existing PDF document, coordinate,
candidate, edit-session, or validation contracts.

Implemented artifacts:

- [`docs/provider-capability-system-design.md`](../provider-capability-system-design.md)
  owns the long-term architecture, state machines, bridge boundary, privacy
  rules, installation lifecycle, measurement gates, revocation behavior, and
  rollback.
- [`Sources/PDFEditorCore/ProviderCapabilityContracts.swift`](../../Sources/PDFEditorCore/ProviderCapabilityContracts.swift)
  defines the native Codable admission records and deterministic negotiator.
- [`web/provider-capability-contract.mjs`](../../web/provider-capability-contract.mjs)
  defines the browser validation and negotiation projection.
- [`Tests/fixtures/provider_capability_registry.json`](../../Tests/fixtures/provider_capability_registry.json)
  is a value-free registry fixture for the browser baseline, native Vision,
  installed-but-unmeasured PDFBox, and quarantined MuPDF.
- [`Tests/provider_capability_contract_test.mjs`](../../Tests/provider_capability_contract_test.mjs)
  exercises the browser registry and negotiation policy.
- [`Tests/PDFEditorCoreTests/ProviderCapabilityContractTests.swift`](../../Tests/PDFEditorCoreTests/ProviderCapabilityContractTests.swift)
  exercises native round-trip, exact artifact binding, duplicate rejection, and
  native negotiation.
- [`web/provider-companion-host.mjs`](../../web/provider-companion-host.mjs)
  implements the narrow local reference host around the typed protocol. It
  validates the hello/nonces and capability context, verifies source bytes and
  digests, enforces output limits and timeouts, supports cancellation, returns
  abstention when a capability handler is unavailable, and emits only
  allowlisted zero-content diagnostics.
- [`Tests/provider_companion_host_test.mjs`](../../Tests/provider_companion_host_test.mjs)
  covers handshake, source binding, provider abstention, output limits,
  cancellation, and zero-content logging.

## Registry cases

| Provider | State | Capability evidence | Intended meaning |
|---|---|---|---|
| `browser-pdfjs-pdflib` | `enabled` | Reader measurement passed | Browser baseline may route reader inspection |
| `native-vision` | `enabled` | OCR text bounds are `measuredPartial` | OCR may route only in explicit experimental or partial-evidence mode |
| `companion-pdfbox` | `installed` | Existing-text editing is `installedUnmeasured` and license review is open | Installation is not product support |
| `companion-mupdf` | `quarantined` | Capability quarantined and license review unresolved | Must not be selected or used as an implicit fallback |

## Verification

Browser contract test:

```text
node Tests/provider_capability_contract_test.mjs
provider capability registry and negotiation: 12 checks passed
```

Native contract test:

```text
swift test --filter ProviderCapabilityContractTests
7 tests in 1 suite passed

Reference host test:

```text
node Tests/provider_companion_host_test.mjs
companion host: handshake, source binding, output limits, and zero-content logging passed
```
```

The native package build also completed successfully while compiling the new
contract and its tests. The checks are Tier 2/S1 contract evidence. The
invalid-measurement, duplicate-provider, and unmeasured-capability cases are
negative checks, but this slice has not yet run a mutation harness against the
admission implementation, so it is not yet S3 evidence.

## Safety properties established

- An enabled capability must reference at least one measurement.
- Every referenced measurement must bind to the exact provider artifact digest
  and capability ID.
- Provider IDs must be unique within a registry.
- A provider with unresolved license status cannot be selected.
- An installed but unmeasured capability is rejected in default mode.
- A partial capability is rejected when the request requires `enabled`.
- Source byte/page limits and encrypted/scanned support are checked before
  selection.
- Revoked or quarantined providers are excluded from routing.
- Selection is deterministic by preferred provider order, then provider ID.
- An abstention includes reason codes rather than silently switching semantics.

## Companion protocol evidence

The typed companion adapter boundary is now implemented independently of the
provider registry:

- [`web/provider-companion-protocol.mjs`](../../web/provider-companion-protocol.mjs)
  validates hello, hello response, capability request, capability response,
  and cancellation messages.
- [`Sources/PDFEditorCore/ProviderCompanionProtocol.swift`](../../Sources/PDFEditorCore/ProviderCompanionProtocol.swift)
  provides the native Codable mirror and validation methods.
- [`Tests/fixtures/provider_companion_protocol_fixture.json`](../../Tests/fixtures/provider_companion_protocol_fixture.json)
  is the shared value-free wire fixture.
- [`Tests/provider_companion_protocol_test.mjs`](../../Tests/provider_companion_protocol_test.mjs)
  passed 11 browser checks.
- [`Tests/PDFEditorCoreTests/ProviderCompanionProtocolTests.swift`](../../Tests/PDFEditorCoreTests/ProviderCompanionProtocolTests.swift)
  passed 4 native tests, including decoding and validating the browser fixture.

The protocol binds a request to a session, client nonce, server nonce, source
SHA-256 digest, operation IDs, byte/page limits, timeout, and explicit local
input mode. It supports `source-bytes` and opaque `file-token` modes, requires
the matching payload for each mode, and rejects the other payload. Responses carry typed state, provider identity,
optional output digest, and reason codes. Cancellation must match request
identity and both nonces. No shell command, arbitrary path, or secret-bearing
content is part of the contract.

This evidence is Tier 2/S1 contract and semantic-parity evidence. It does not
claim cryptographic transport authentication, process sandboxing, installer
integrity, live OCR, high-fidelity editing, or a packaged companion. The
reference host enforces typed session binding, origin allowlisting, source and
output limits, cancellation, and timeout behavior inside its process, but it is
not yet an installed or independently sandboxed system service. Those remain
active implementation gates under the full-capability implementation amendment
recorded in D-024 and RG-092.
- The provider contract contains no PDF bytes, text, OCR output, field values,
  screenshots, secrets, or executable command strings.

## What this does not prove

This evidence does not prove:

- a companion installer, update system, or uninstaller;
- a live localhost or native-messaging bridge;
- package signature verification or sandbox enforcement;
- OCR quality, multilingual accuracy, or searchable-layer fidelity;
- PDFBox or MuPDF runtime behavior;
- high-fidelity existing-text editing;
- license clearance for any packaged provider;
- crash, timeout, memory, cancellation, or partial-output recovery;
- revocation-feed delivery or active-session cancellation;
- native/browser parity of a real provider execution result.

The next implementation must add authenticated transport around this typed
handshake and a provider-specific measurement runner, not bypass these records
by invoking a companion command directly from the UI.
