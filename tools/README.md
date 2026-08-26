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
node tools/deploy-web.mjs --list          # print the closure without staging
node tools/deploy-web.mjs /srv/pdfeditor  # stage, then rsync into an existing target dir
```

`dist/` is gitignored. The manifest lists `sha256  relative-path  bytes` per
staged file so any static host can verify deployment integrity.

## Maintenance notes

- Both tools are scanner-based rather than list-based: new tests under `Tests/`
  and new modules under `web/` are picked up without editing the tools.
- `deploy-web.mjs` intentionally has no host/provider assumptions (no CDN,
  no upload credentials); pointing it at a concrete host is a release-gate
  decision, not a tooling default.
