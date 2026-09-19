# Sendability Invariant Ledger — 2026-09-17

**Task:** MDEV-I2 (from [`audits/macos-development-skill-audit-2026-09-17.md`](../audits/macos-development-skill-audit-2026-09-17.md))
**Method:** Full read-only sweep of `Sources/` (all 13 targets) for `@unchecked Sendable`,
`NSLock`/`OSAllocatedUnfairLock`, `nonisolated(unsafe)`, and `DispatchQueue` uses. Verified:
zero `.sync(` calls exist anywhere in Sources; every `DispatchQueue` use is `async`/`asyncAfter`
except the semaphore pair in `OCRConfirmLane.withTimeout` (ordered, see below).

**Why a ledger:** the package is on Swift 6 (strict concurrency is the default language mode), so
these sites are the *only* remaining concurrency trust surface. This file is the single source of
truth for why each site exists; `tools/check-unchecked-concurrency.mjs` fails CI when a new site
appears without a ledger entry.

**Status vocabulary:** `ok` (invariant verified by the sweep) · `fixed` (race found and fixed
2026-09-17) · `unsafe` (known race, marked at the site, remediation = MDEV-I6) · `unverifiable`
(stated lifetime premise with no enforcement mechanism).

## `@unchecked Sendable` sites (25)

| File:line | Symbol | Status | Invariant / concern |
|---|---|---|---|
| CompanionNegotiator.swift:92 | `CompanionNegotiator` | **fixed** | Invoked from detached tasks; all three mutable properties are now lock-backed accessors. The sweep found `NSLock` declared but **never acquired** — a real race on `lastResult`/`activeCapabilities`/`onNegotiationComplete`. |
| RenderingPipeline.swift:138 | `RenderingPipeline` | **unsafe** | Mixed discipline: some accessors lock `documentData`/`documentModel`/`readingPositions`; `loadDocument`, render, and text-extraction paths touch the same fields unguarded; `currentState` mixes MainActor writes with a locked reader. Marked at site. |
| CompanionTransport.swift:189 | `HTTPCompanionTransport` | **unsafe** | `connected` read/written across async paths with no synchronization. Marked at site. |
| CompanionTransport.swift:414 | `LocalCompanionTransport` | **unsafe** | `connected` + pipe/handle/process optionals torn between `disconnect()` and `send`. Marked at site. |
| CompanionTransport.swift:343 | `HTTPTransportDelegate` | ok | Immutable after init (`let trustedFingerprints`). |
| CompanionTransport.swift:624 | `MockCompanionTransport` | ok | All state behind `OSAllocatedUnfairLock` via `withLock` closures. |
| SessionRecoveryStore.swift:146 | `SessionRecoveryStore` | ok | All file I/O under `lock` with `defer`. |
| SessionStore.swift:134 | `FileSessionStore` | ok | All accessors lock with `defer`. |
| SessionPayloadStore.swift:140 | `SessionPayloadStore` | ok | save/load/helpers lock with `defer`. |
| RecoveryPairStore.swift:74 | `RecoveryPairStore` | ok | save/load/delete/GC lock with `defer`. |
| RecoveryPayloadKeyStore.swift:27 | `RecoveryPayloadKeyStore` | ok | Keychain create-or-read critical section under `lock`; handles `errSecDuplicateItem` re-read. |
| EncryptedTemplatePersistence.swift:226 | `EncryptedRevisionFileStore<Value>` | ok | Every method locks with `defer`. Minor: `deleteAllRecords` releases/reacquires per record (benign). |
| EncryptedTemplatePersistence.swift:519 | `EncryptedPDFTemplateStore` | ok* | Delegates to locked sub-stores; `append` is load→modify→save across three lock acquisitions — lost-update window under concurrent appends. Single-writer in practice; re-verify if append gains concurrent callers. |
| EncryptedTemplatePersistence.swift:741 | `EncryptedPDFProfileVault` | ok* | Same `append` read-modify-write shape as :519. |
| ProfileStore.swift:253 | `EncryptedProfileStore` | ok | save/load/listAll lock with `defer`. |
| ProgressiveRenderer.swift:69 | `ProgressiveRenderer` | ok | Cache reads/writes lock (manual pairing in non-throwing spans, `defer` elsewhere). |
| TileBasedDisplay.swift:74 | `TileBasedDisplay` | ok | Cache + LRU order + counters under `lock`; benign check-then-act (duplicate tile render possible, state stays consistent). |
| DocumentCacheManager.swift:103 | `DocumentCacheManager` | ok | LRU entries + counters under `lock` with `defer`; helpers only called while locked. |
| PerformanceTelemetry.swift:93 | `PerformanceTelemetry` | ok | Ring buffer + index under `lock` with `defer`; `enabled`/`capacity` init-only. |
| PerformanceTelemetry.swift:266 | `PerformanceMeasurement` | ok | `didEnd` once-flag; correct early-return unlock before callback. |
| StudyLoop.swift:644 | `StudyLoopManager` | **unsafe** | `@Published` dictionary mutated via unlocked read-modify-write; safety = undocumented main-thread-only convention. Marked at site. |
| FreezePaneLayout.swift:177 | `FreezePaneState` | **unsafe** | Methods lock, but `public @Published var`s are bound directly by SwiftUI, bypassing the lock. Marked at site. |
| PDFVectorStreamParser.swift:26 | `PDFVectorStreamParser` | ok | Stateless; `ScannerContext` is per-call local. |
| AppModel.swift:4003 | `AppModel.OCRPageBox` | unverifiable | Stated invariant ("main actor never mutates the live document while recognition reads it") has no enforcement — no snapshot, lock, or generation check across a recognition window that can run ~45s (watchdog bounds). |
| DocumentCanvasView.swift:607 | `PDFPresentationHighlight` | unverifiable | `let`-only value wrapper around a non-Sendable `PDFPage`; safety depends on the same unenforced document-lifetime premise as the OCR handoff. |

## `nonisolated(unsafe)` (1 site)

| File:line | What it marks | Status |
|---|---|---|
| AppModel.swift:3961 | `let page = livePage` captured into detached recognition closures | **unverifiable** — same unenforced "document not mutated during recognition" premise as `OCRPageBox` above. Proper fix belongs to MAD-I4 (async open) / A-9 ownership work, where the document mutation boundary gets a real mechanism. |

## Semaphore-ordered path (not a bypass, recorded for completeness)

`OCRConfirmLane.withTimeout` (:303): the shared `var result: T?` is safe *by semaphore ordering*
(background closure is sole writer; caller reads only after `wait` succeeds; timeout path returns
nil without reading). The 2026-09-07 crash-fix comment previously claimed a "lock-guarded box"
that does not exist; the comment was reconciled to the actual mechanism on 2026-09-17.

## Remediation

- **MDEV-I6 (new, ledgered in `docs/task-inventory.md`)**: fix the five `unsafe` sites
  (RenderingPipeline mixed discipline; both CompanionTransports; StudyLoopManager;
  FreezePaneState property-bypass) and give the PDFPage handoff a real enforcement mechanism.
- Inline conversion: each `ok` site gains its one-line invariant comment the next time its file is
  touched for other reasons (avoided a 15-file comment sweep during active parallel-lane drift);
  this ledger is the authoritative record until then.
- `tools/check-unchecked-concurrency.mjs` compares the live grep surface against this ledger and
  fails on new unledgered sites.
