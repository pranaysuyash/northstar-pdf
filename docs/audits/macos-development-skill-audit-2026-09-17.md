# macOS Development Skill Audit — 2026-09-17

Auditor: ZCode (Pranay's agent), using the `macos-development` skill
(`/Users/pranay/.zcode/skills/macos-development/SKILL.md` — modules: `modern-concurrency`,
`sandboxing`, `code-organization`).

Scope and relationship to prior audits: this is a **delta + developer-quality pass**, not a
re-audit of design citizenship. The design surface was already audited 2026-09-11
(`docs/audits/macos-app-design-skill-audit-2026-09-11.md`, MAD-001..018) and today's council
session verified the epistemics set
(`docs/audits/chatgpt-feedback-council-review-2026-09-17.md`). This audit (a) re-verifies the MAD
criticals against the current working tree, and (b) applies the lenses the earlier audits did
**not** cover: concurrency hygiene, sandbox/entitlements, and code organization. New findings use
the `MDEV-` prefix. All evidence is from the current uncommitted working tree (parallel codex lane
active — re-verify line numbers before editing).

Build ground truth: `swift build` clean (incremental 0.37s) at audit time.

---

## 1. Skill usefulness verdict

**Keep as an implementation-phase reference; it is not the right primary audit lens for this repo,
and it duplicates nothing currently in the workflow.**

| Module | Value for Northstar | Why |
|---|---|---|
| `coding-best-practices/modern-concurrency.md` | **High** | Direct rubric for this audit; the pattern reference for MAD-I4 (moving document open off the main actor) |
| `macos-capabilities/sandboxing.md` | **High** | The app has zero entitlements (MDEV-001); this module is the entitlements-plan checklist |
| `coding-best-practices/code-organization.md` | Medium | Repo already exceeds its multi-module guidance (13 SPM targets); useful for the decomposition lens (MDEV-003) |
| `macos-tahoe-apis/` | Medium | Relevant to MAD-R3 (Liquid Glass migration plan) once min OS moves to 26 |
| `architecture-patterns/` | Low–Med | Generic SOLID/patterns; modularity already strong |
| `appkit-swiftui-bridge/` | Low | Only two bridge points exist (`InlineEditorTextFieldHost`, the print `NSView`) |
| `swiftdata-architecture/` | Not applicable | Zero SwiftData/CoreData usage — persistence is custom stores + Keychain, which fits the document model |
| `ui-review-tahoe/` | Thin stub | SKILL.md only, no reference files; the `macos-app-design` skill is strictly better for design review |
| `app-planner/existing-app-analysis.md` | Loose rubric | Generic 10-section template; partially applied here |

Bottom line: the skill's marginal value here is the **concurrency and sandboxing checklists** plus
a **Swift 6 migration reference** (the package is already on `swift-tools-version: 6.0`, i.e.
strict concurrency is the default language mode — the skill's "enable strict concurrency" box is
already checked). Its SwiftData and UI-review modules are dead weight for this repo.

---

## 2. Delta verification against the MAD ledger (2026-09-11)

| MAD item | Status now | Evidence |
|---|---|---|
| MAD-001 App Intents are success-stubbed | **RESOLVED** (commit `aa7e2da`) | All three intents call the real pipelines: `SanitizePDFIntent` → `PDFSanitizer` (`PDFEditorAppIntents.swift:32-41`), `ExtractTableCSVIntent` → `ImprovedTextExtractor`+`TableExporter` (`:73-85`), `ComparePDFVersionsIntent` → `PDFKitProvider.inspect` + `DocumentDiffBuilder` (`:119-129`) |
| MAD-002 Print stub prints an empty view | **STILL OPEN** | `PublishPipeline.swift:232` still `NSPrintOperation(view: NSView(), …)`; parsed `pdfDocument` is unused for printing; **no Print menu command exists** (`AppCommands.swift` has no print entry) |
| MAD-003 No icon / no file association | **PARTIAL** | `CFBundleDocumentTypes` landed in `tools/native-preview-Info.plist:33-51` (`com.adobe.pdf`, Editor role) and is wired into the bundle script (`build-native-preview-app.sh:26`). Still no `.icns`/app icon anywhere (`CFBundleTypeIconFile` is an empty string), no `LSApplicationCategoryType`, no copyright. `dist/Northstar.app` on disk is **stale** — its Info.plist still carries the old "no file associations yet" comment; a rebuild publishes the new association |
| MAD-004 Main-actor document parse on open | **STILL OPEN** | `open(url:)` remains `@MainActor` (class annotation `AppModel.swift:66`) and calls `provider.openDocument(url:)` synchronously (load + parse + inspect inline, `AppModel.swift:1783`). New since the audit: a correctly-paired security-scope wrapper (`:1774-1779`). Preflight and companion negotiation remain properly detached with session-ID staleness guards (`:1818`, `:1845`) |
| MAD-I8 reduce-motion gates in remaining files | **NOT DONE** | `accessibilityReduceMotion` still appears in only 2 files (`ContentView.swift`, `DocumentCanvasView.swift`); `ContextualInspectorView`, `DocumentSplitView`, `FreezePaneDragHandle`, `PageThumbnailRailView` remain un-gated |

Residual on the resolved MAD-001 (new, small):
- **Failures are returned as success strings.** `SanitizePDFIntent.perform` returns
  `.result(value: "Sanitization failed: …")` on error (`PDFEditorAppIntents.swift:43`) — same
  pattern in the other two intents. Shortcuts will show a green success carrying a failure
  message. `AppIntent.perform` is `throws`; failures should propagate so the intent visibly fails.
- **Write-next-to-source will break under a future sandbox**: every intent writes output next to
  the input file (`:38`, `:82`). Un-sandboxed this is fine; under user-selected read-only scope it
  is a guaranteed failure (see MDEV-001).

---

## 3. New findings (skill lenses)

### MDEV-001 (High): The app ships with zero entitlements — unsandboxed, with no plan
No `.entitlements` file exists anywhere in the repo, `tools/` and `scripts/` contain no
`com.apple.security` references, and the bundle script codesigns without `--entitlements`
(`tools/build-native-preview-app.sh:32`). The app therefore runs fully unsandboxed.

Why this matters *for this app specifically*: the core product story is on-device processing with
no network egress. App Sandbox is the **platform-enforced version of that story** — it turns a
claim the code makes into a guarantee the OS makes. It is also a GA/distribution blocker for any
notarized/MAS path, and several in-flight features have known entitlement requirements once it
lands: print needs `com.apple.security.print` (MAD-002), App Intents' write-next-to-source needs
`user-selected.read-write` plus folder grants, and the existing `startAccessingSecurityScopedResource`
calls (4/4 correctly paired with `defer`, `AppModel.swift:1774,2198,2238,3001`) are the right
prep and currently no-ops.

Path (per the skill's sandboxing module): enable sandbox early rather than retrofitting — an
entitlements plan doc + flags in `build-native-preview-app.sh` is a small, testable change; the
risk is in the file-access audit (recents, autosave, recovery stores, exports), which should ride
the same evidence-doc pattern as the privacy audits.

### MDEV-002 (Medium): 25 `@unchecked Sendable` + 16 `NSLock` + 1 `nonisolated(unsafe)` sites carry no documented invariants
Swift 6 strict concurrency is already the default (tools-version 6.0) — genuinely strong for a
codebase this size. What remains unaudited is the bypass surface: `@unchecked Sendable`
concentrates in `CompanionTransport.swift` (4), `EncryptedTemplatePersistence.swift` (3),
`PerformanceTelemetry.swift` (2), and one each in the payload/session/recovery stores, plus one
`nonisolated(unsafe)`. This audit did **not** deep-verify each site (time-bounded); the finding is
that no comment or doc states *why* each unchecked site is safe (what the lock protects, what the
invariant is). Cheap hardening: a one-line invariant comment per site, plus a `tools/` check that
fails review when a new `@unchecked Sendable` appears without one. This matches the skill's Swift
6 checklist item "audit `@unchecked Sendable` usage".

### MDEV-003 (Medium): AppModel is a 6,527-line `@MainActor` god-object — the larger decomposition debt
The council adopted ContentView decomposition under NM-T06's gate, but the actual contention point
is bigger: `AppModel.swift` is 6,527 lines, every UI state lives on one actor, so any synchronous
work in it contends with the main thread — MAD-004 is one instance of a structural property.
MAD-I4 (async open) will force some decomposition anyway; it should be planned as an AppModel
surgery with a test-backed seam, not a one-method fix. Opinion: AppModel decomposition belongs in
the ledger as first-class, coordinated with NM-T06 and the A1/R1 shell decision, not derived from
ContentView work.

### MDEV-004 (Low): Intent result contract (folded into MAD-001 residual above)
Throw on failure instead of returning failure-shaped success strings; also consider returning
structured values (output URL, counts) rather than prose, since Shortcuts can chain values.

### MDEV-005 (Info): Data layer mapping — no SwiftData finding, and that's fine
Persistence is custom (session/recovery payload stores, Keychain-backed `RecoveryPayloadKeyStore`,
debounced content autosave with the flush-before-switch fix landed today). The skill's SwiftData
modules are inapplicable; its persistence guidance (don't lose the debounce window, durable
stores) is already satisfied. Recorded so nobody "modernizes" this to SwiftData without a reason.

---

## 4. What the app does right under these lenses (preserve)

- **Swift Testing at scale**: ~1,700 `@Test` cases (1,622 in `PDFEditorCoreTests` across 142 files,
  74 in AppRecovery, 2 legacy XCTest in InlineEditor) — the concurrency refactor MAD-I4 has a real
  safety net.
- **13-target SPM modularization** (`Package.swift`) matches the skill's multi-module
  recommendation; build is fast (0.37s incremental) because boundaries are clean.
- **Correct stale-result discipline** on detached work: session-ID guards before publishing
  preflight/companion results (`AppModel.swift:1826`, `:1850`) — exactly the pattern the
  concurrency module prescribes.
- **One-load-one-parse** on open (`:1780-1785`) — the double-parse was already removed; only the
  sync-on-main part remains.
- **Security-scope hygiene** is already correct (paired start/stop with `defer`, checked truthiness)
  even though the app is unsandboxed.

---

## 5. Task ledger additions

| ID | Task | Finds | Size |
|----|------|-------|------|
| MDEV-I1 | Entitlements plan doc + sandbox flags in `build-native-preview-app.sh`; audit file-access paths (recents/autosave/recovery/exports) against container rules | MDEV-001 | M |
| MDEV-I2 | Per-site invariant comments for every `@unchecked Sendable`/`NSLock`/`nonisolated(unsafe)` + a tools check enforcing the comment | MDEV-002 | S |
| MDEV-I3 | Ledger AppModel decomposition as first-class (coordinate NM-T06 + MAD-I4) | MDEV-003 | L |
| MDEV-I4 | Make App Intent failures `throw` (part of MAD-001 residual) | MDEV-004 | S |
| MDEV-I5 | Rebuild `dist/Northstar.app` so the landed `CFBundleDocumentTypes` actually reaches the packaged app | MAD-003 partial | S |

Standing MAD items re-confirmed open: MAD-002 (real print + ⌘P), MAD-003 icon pass, MAD-004
(async open), MAD-I5 (Help), MAD-I8 (reduce-motion gates), and the rest of the MAD-I6+ queue.

---

## 6. Method note

Single-session direct evidence collection (targeted greps + file reads); no sub-agent dispatches.
`swift build` run as ground truth. The parallel codex lane had uncommitted changes across the same
files (git status at audit time); every citation above reflects the tree as of 2026-09-17 and line
numbers may drift.
