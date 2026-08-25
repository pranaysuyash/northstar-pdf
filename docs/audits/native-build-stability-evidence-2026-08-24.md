# Native Build Stability Evidence

**Date:** 2026-08-24
**Scope:** Current macOS native verification attempt for the PDF reader/editor
**Status:** Environment-blocked, not a product-pass claim

## Observation

The native Swift package could not complete a current build because SwiftPM
reported that source inputs changed during compilation. The affected files
were different across attempts:

- `Sources/PDFEditorApp/SessionPayloadStore.swift`
- `Sources/PDFEditorApp/AppModel.swift`

The agent did not edit either file during these attempts. A process check found
an Xcode/Swift compiler or indexing process during the first failure. After it
exited, a targeted retry still reproduced the `AppModel.swift` mutation error.

## Attempts

```text
swift test
error: input file 'Sources/PDFEditorApp/SessionPayloadStore.swift' was modified during the build
error: fatalError
```

```text
swift test --filter PDFReaderGateTests
error: input file 'Sources/PDFEditorApp/AppModel.swift' was modified during the build
error: fatalError
```

The failure occurs before test execution and is therefore not evidence of a
native reader or provider behavior failure. It is also not evidence of a
current native green gate. The previously recorded native test pass remains
historical until a stable checkout produces a fresh result.

## Release treatment

This condition keeps the native verification gate open. Browser contract,
accessibility, impact, proof, independent-viewer, and qpdf gates are reported
separately and must not be used to infer native completion. No unrestricted
release claim is made while native verification is stale or build inputs are
being changed externally.

## Recovery action

After external Xcode/indexing activity has stopped modifying the checkout,
rerun `swift test`, then rerun `swift test --filter PDFReaderGateTests` and
record fresh output here. Do not alter PDF validation policy or suppress the
SwiftPM source-mutation diagnostic to make the gate green.
