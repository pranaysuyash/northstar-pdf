# Sandbox Entitlements Plan — 2026-09-17 (MDEV-I1 research + staging)

**Finding:** the app ships with zero entitlements — `tools/build-native-preview-app.sh` codesigns
without `--entitlements` and no entitlements file existed. For a product whose core story is
on-device, zero-egress processing, App Sandbox is the platform-enforced version of that story.

**Doctrine fit:** sandboxing converts the zero-egress *claim* into an OS-enforced *guarantee*
(the OS refuses network APIs the entitlements don't grant). This is the strongest possible
evidence tier for the privacy story that prose and tests can only approximate.

## Staged entitlements (now checked in: `tools/native-preview.entitlements`)

| Entitlement | Justification | Already-shipped capability it serves |
|---|---|---|
| `com.apple.security.app-sandbox` | The point | All of it |
| `files.user-selected.read-write` | Open/save panels; App Intent output written beside the source PDF | ⌘O / fileImporter; all three App Intents |
| `files.bookmarks.app-scope` | Recent-document identity across launches | Bookmark-backed recents (EOR-01/EOR-02 source path exists) |
| `com.apple.security.print` | Print lane | ⌘P → PublishPipeline (landed 2026-09-17) |
| *(none)* network client/server | Deliberate — a network grant would contradict the product | — |

## File-access audit (current state, verified 2026-09-17)

- Application Support via `FileManager.urls(for: .applicationSupportDirectory, …)` — resolves into
  the sandbox container automatically. Users: `SessionRecoveryStore`, `SessionStore`,
  `EncryptedTemplatePersistence` (×2), `ProfileStore`, `VersionCompareView`. **No hardcoded paths found.**
- Keychain: `RecoveryPayloadKeyStore` — works under sandbox (keychain-access-groups not required
  for app-private items).
- Temp: `PublishPipeline.prepareForEmail` uses `temporaryDirectory` — container-scoped, safe.
- Security-scoped resources: `AppModel` start/stop pairs with `defer` at 4 sites (1774, 2198,
  2238, 3001) — correct under sandbox, currently no-ops.
- UserDefaults: session/layout/study keys — container-scoped, safe.

## Open research items before default-on

1. **Companion child processes**: `LocalCompanionTransport` spawns local companion `Process`es +
   pipes. Under sandbox, child processes need `com.apple.security.inherit` (they inherit the
   sandbox) or a redesign toward XPC/App-Group handshake. This is the one lane with real
   architectural exposure — resolve before flipping default-on.
2. **Recents bookmark round-trip**: verify saved bookmarks survive a container-identity change
   (app update) — T2/T4 cases already specified in the NM ledger (moved/revoked/reselected).
3. **Apple-event reopen**: odoc events are delivered to sandboxed apps by LaunchServices without
   an extra entitlement — verify the external-open router still receives them (T4).

## Rollout (wired 2026-09-17)

- `PDF_EDITOR_CODESIGN_IDENTITY=<id> PDF_EDITOR_ENABLE_SANDBOX=1 tools/build-native-preview-app.sh`
  signs the preview bundle with the staged entitlements. Default build remains unsandboxed until
  the T4 matrix below passes end to end.
- Gate to default-on: open/save/recents/autosave/recovery/vault/print/App-Intents matrix green in
  a sandbox-signed build (evidence doc per `docs/audits/*-evidence-*` convention).
- **Decision needed:** default-on timing interacts with NM-T32 (signing/notarization credentials —
  owner gate). See decision list in the 2026-09-17 audit.
