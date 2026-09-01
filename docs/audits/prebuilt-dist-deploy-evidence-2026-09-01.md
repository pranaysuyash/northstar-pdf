# Prebuilt-dist deployment mode evidence — 2026-09-01

**Scope:** `tools/deploy-web.mjs` `--prebuilt` mode and `tools/smoke-dist.mjs`
boot smoke, closing task A-15 / decision G4 (deployment integrity) from
[`docs/task-inventory-2026-08-25.md`](../task-inventory-2026-08-25.md) and
[`docs/decisions.md`](../decisions.md) (React migration gates).

## What was implemented

1. `tools/deploy-web.mjs --prebuilt` stages the built React app
   (`web/app/dist`, produced by `npm run build` = `tsc -b && vite build`) to
   `dist/web-app` by walking the **built** `index.html`: Vite root-relative
   hashed chunk edges (`/assets/<hash>.js`) are followed as hard edges,
   runtime-loaded asset literals are staged, and the closure is verified free
   of Node-builtin imports. A documented exception list covers vendor-internal
   default strings (`./pdf.worker.mjs`) that the app always overrides via
   `GlobalWorkerOptions.workerSrc`; every other unresolvable edge fails
   staging.
2. `tools/smoke-dist.mjs` serves any staged dist on a free port and loads the
   entry in headless Chrome, failing on entry non-200, uncaught page errors,
   failed subresource requests, or an unmounted body.
3. Legacy mode (source closure of `web/index.html`) is unchanged and
   re-verified after the week's `web/` drift.

## Observed results (T2/T3)

| Step | Result |
|---|---|
| `web/app` production build | `tsc -b && vite build` passed; 9 emitted files incl. hashed `pdf.worker.min-B7-rSTV-.mjs` (1,339,625 B) and `pdf-lib.min-DcPAtE2F.js` (525,099 B) |
| `deploy-web.mjs --prebuilt` | Staged 9 files, 2,437.7 KiB → `dist/web-app` + `MANIFEST.sha256`; **manifest covers the runtime-loaded PDF.js worker and pdf-lib asset** (the G4 requirement) |
| `smoke-dist.mjs dist/web-app` | OK — entry 200, zero page errors, zero failed subresource requests, app mounted |
| `deploy-web.mjs` (legacy) | Staged 31 files, 2,793.9 KiB → `dist/web`; 22 Node-only server/companion modules structurally excluded |
| `smoke-dist.mjs dist/web` | OK — legacy module app boots cleanly |

Production CSP parity was confirmed at configuration level: the Vite
`productionCsp` plugin emits the same air-gap policy as the legacy entry
(`script-src 'self'; connect-src 'none'; worker-src 'self' blob:`).

## Limits and remaining work

- The behavioral-test retarget portion of G4 ("repoint RT-004 test +
  `run-web-e2e`") is intentionally **not** done here: retargeting the evidence
  chain belongs to the G2/G3 migration sequencing, not the deployer. The
  deployer and smoke tool are ready for it.
- A defect introduced and fixed during this session is recorded for honesty:
  the first refactor of the HTML-ref regex captured only the `./`/`/` prefix
  (closure collapsed to 2 files); caught immediately by `--list` re-verification
  and fixed before any use.
- `dist/` is gitignored; manifests are reproducible from source by rerunning
  the tools.

## Reproduction

```bash
(cd web/app && npm run build)
node tools/deploy-web.mjs --prebuilt
node tools/smoke-dist.mjs dist/web-app
node tools/deploy-web.mjs && node tools/smoke-dist.mjs dist/web
```
