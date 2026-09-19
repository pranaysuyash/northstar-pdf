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

## `airgap-watch.mjs` — runtime network-boundary capture

Privacy-forensics harness for persona sims (audit §10.12 / NS-P5): spawns a
command or attaches to a running pid, samples `lsof -i` on an interval,
allowlists loopback (plus explicit `--allow host[:port]`), records every socket
as value-free metadata, and exits non-zero on any violation so a sim run can
gate on it.

```bash
node tools/airgap-watch.mjs --exec .build/debug/PDFEditor --out tmp/airgap.json
node tools/airgap-watch.mjs --pid 1234 --duration 30
node tools/airgap-watch.mjs --exec ./app --allow api.example.com:443
```

Verdict is in the JSON report (`verdict: PASS|FAIL`); exit code mirrors it.

## `parity-settlement-classify.mjs` — netting-feasibility measurement

Round-3 (R3-15) measurement instrument over native/web semantic-parity
reports. Classifies every fixture into settlement classes (exact-agree,
classified-variance, dispute, malformed-agree, never-run, unclassified) and
answers whether the parity state is a dispute backlog (netting pays off) or
open measurement scope (netting settles an empty set). Measurement only — no
gate authority (D-055). Run before any ParitySettlementReport reducer build.

```bash
node tools/parity-settlement-classify.mjs \
  --report benchmark/results/preflight-parity-2026-08-25/parity-report.json \
  --out benchmark/results/parity-settlement/classification-2026-09-17.json
```

Unit tests: `Tests/parity_settlement_classification_test.mjs` (pure functions,
synthetic fixtures).

## `export-form-class-ledger.mjs` — public form-class ledger generator

Round-3 presale branch (R3-29/R3-25 step 1): renders gate evidence as the
public ledger page — corpus-fixture human-visual status plus the certified
form-class section (honestly empty until a D-055 decision, cohort fixtures,
and human review exist). Every row carries source-report path + SHA-256 so
the page is traceable to the reports it renders. Disclosure only.

```bash
node tools/export-form-class-ledger.mjs \
  --human-report benchmark/results/human-visual-confirmation/human-review-gate-report.json
# writes docs/public/form_class_ledger.json + docs/public/ledger.html
```

## `register-lifecycle-check.mjs` — exploration-pool register validator

Closes the adhd skill's persistence step 8: validates the pool ledger's
register lifecycle — unique IDs per round, status vocabulary, explicit
promote/revisit conditions on every parked-conditional row, pointers on
graduated rows, header coverage vs. actual round sections. Run before
claiming any divergent-round work done.

```bash
node tools/register-lifecycle-check.mjs
# exit 0 = register clean; 1 = violations listed; 2 = usage/input error
```

## `png-pixel-diff.mjs` — dependency-free PNG perceptual pixel diff

Node-side visual regression support (landed 2026-09-18 for the toolbar
flaky-register fix): decodes 8-bit non-interlaced PNG (RGB/RGBA) with
node:zlib — no pixelmatch/pngjs dependency, air-gap friendly — and compares
actual pixels with a per-channel tolerance instead of PNG byte equality,
which Chrome updates flip to false 100% diffs. Reports
`identical | dimension-mismatch | undecodable | diffPercent` (fraction of
pixels exceeding tolerance) so tests can assert against a human-meaningful
tolerance (e.g. 2%).

```js
import { pixelDiff } from "../tools/png-pixel-diff.mjs";
const { diffPercent, detail } = pixelDiff(baselineBytes, currentBytes);
```

Consumed by `Tests/toolbar_visual_regression_test.mjs` (baselines refresh
with `UPDATE_BASELINES=1` after an intentional toolbar change, never to mask
a regression). Reuse it for any new screenshot-regression test instead of
`Buffer.equals` on PNG bytes.
