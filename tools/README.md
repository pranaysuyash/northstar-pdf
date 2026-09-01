# Reusable project tools

Small, dependency-free Node CLI tools that are broadly useful across the PDF
Editor project. Each tool is self-contained (Node built-ins only) and follows
the repository's `.mjs` ES-module convention.

## `run-contract-tests.mjs` — aggregate test runner

Discovers every `Tests/*_test.mjs`, classifies it (plain Node contract test vs
Playwright/Chrome browser test) by scanning its source, runs the selected set
sequursively, and prints a package-wide pass/fail summary. Replaces the
one-file-at-a-time invocation list in `docs/runbooks/release-gates.md` for
local verification while leaving per-file invocation valid.

```bash
node tools/run-contract-tests.mjs               # all 76+ tests; starts repo-root server on :4173 for browser tests
node tools/run-contract-tests.mjs --no-browser  # Node-only subset, no server, no Chrome
node tools/run-contract-tests.mjs --filter template   # subset by filename regex
node tools/run-contract-tests.mjs --list        # classify without running
node tools/run-contract-tests.mjs --json tmp/results.json   # machine-readable report
node tools/run-contract-tests.mjs --timeout 300 # per-test timeout in seconds (default 180)
```

Browser tests run against `http://127.0.0.1:4173/web/index.html`
(`PDF_PROOF_BASE_URL` overrides); the runner starts `python3 -m http.server`
at the repository root for them, matching the documented local-preview
pattern, and tears it down afterwards. Exit code is non-zero on any failure,
so the runner is CI-ready as-is.

## `verify-all.sh` — whole-system verification entry point

Single command proving both planes healthy: `swift build` → `swift test` →
contract suite. Introduced by the 2026-08-26 doctrine-alignment audit
(`docs/audits/repository-audit-per-0428-doctrine-alignment-2026-08-26.md`,
Phase P1) so that a red build or red suite cannot persist unnoticed.

```bash
tools/verify-all.sh              # all three stages
tools/verify-all.sh --quick      # build + contracts (skip swift test)
tools/verify-all.sh --contracts  # contract suite only
```

Exit code 0 only when every selected stage passes. For scheduled local runs
(air-gap compatible), see the installable launchd template
`com.owner.pdfeditor.verify.plist` in this directory.

Flaky failures are never silently ignored: record them in
`docs/flaky-register.md`.

## `deploy-web.mjs` — static web deployment packager

Packages the browser deployment surface of `web/` into `dist/web/` by walking
the real import closure from `web/index.html` (static imports, dynamic
imports, asset literals, vendored licenses). This is the deployment-boundary
enforcement for the D-009 architecture: Node-only server/companion modules
that live under `web/` (e.g. `provider-companion-host.mjs`, `pdf-sanitize.mjs`)
are structurally excluded because nothing in the browser graph imports them,
and staging fails loudly if a browser-graph module ever imports a Node
builtin.

```bash
node tools/deploy-web.mjs                 # stage closure + MANIFEST.sha256 to dist/web
node tools/deploy-web.mjs --prebuilt      # stage built React app (web/app/dist) to dist/web-app
node tools/deploy-web.mjs --list          # print the closure without staging
node tools/deploy-web.mjs /srv/pdfeditor  # stage, then rsync into an existing target dir
```

`dist/` is gitignored. The manifest lists `sha256  relative-path  bytes` per
staged file so any static host can verify deployment integrity.

The `--prebuilt` mode (decision G4 / task A-15) serves the React migration in
`web/app/`: it requires `npm run build` to have produced `web/app/dist`, then
walks the built `index.html` so Vite's hashed chunk edges are followed and
runtime-loaded assets — the PDF.js worker and pdf-lib — land in the manifest
instead of being blind-copied. Unresolvable edges fail staging, except a tiny
documented list of vendor-internal default strings (PDF.js's `./pdf.worker.mjs`
fallback, always overridden via `GlobalWorkerOptions.workerSrc`). Build both
surfaces while the legacy app remains live:

```bash
(cd web/app && npm run build) && node tools/deploy-web.mjs --prebuilt
node tools/deploy-web.mjs                 # legacy surface, unchanged
```

## `smoke-dist.mjs` — staged deployment boot smoke

Serves a staged dist directory on a free port and loads the entry page in
headless Chrome, failing on any non-200 entry, uncaught page error, failed
subresource request (catches missing hashed chunks/workers that file-level
checks cannot see), or an empty body (app never mounted). Complements
`deploy-web.mjs`: the deployer proves the closure is complete at the file
level; this proves it actually boots.

```bash
node tools/smoke-dist.mjs                 # defaults: dist/web, entry /index.html
node tools/smoke-dist.mjs dist/web-app    # prebuilt React app
node tools/smoke-dist.mjs dist/web "#app" # optional required CSS selector
```

## `native-audit-snapshot.mjs` — native evidence boundary

Captures a value-minimized JSON snapshot for the native macOS audit. It records
branch/status, hashes and mtimes for explicitly named relied-on files, tool
versions, and bounded process/lock observations. It does not read PDF contents.

```bash
node tools/native-audit-snapshot.mjs \
  --output docs/audits/native-macos-snapshot-YYYY-MM-DD.json
```

Process inspection may be recorded as unavailable when macOS privacy prevents
`ps`; that state must remain explicit in the evidence ledger.

## Maintenance notes

- Both tools are scanner-based rather than list-based: new tests under `Tests/`
  and new modules under `web/` are picked up without editing the tools.
- `deploy-web.mjs` intentionally has no host/provider assumptions (no CDN,
  no upload credentials); pointing it at a concrete host is a release-gate
  decision, not a tooling default.
