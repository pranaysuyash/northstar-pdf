#!/usr/bin/env node
// Static web deployment packager.
//
// The web surface is a zero-build ES-module app (docs/web-deployment-decision.md,
// D-009): deploying it means shipping exactly the browser import closure of
// web/index.html. This tool computes that closure by walking real import
// specifiers and asset literals from the entry HTML — not a hand-maintained
// allowlist — so it cannot drift as modules are added or removed.
//
// It exists to enforce the deployment boundary structurally:
//   - Node-only modules that live under web/ (provider-companion-host.mjs,
//     pdf-sanitize.mjs, pdf-signature-guard.mjs, ...) are NOT part of the
//     browser closure and are never staged, because nothing in the browser
//     graph imports them.
//   - If a browser-graph module ever imports a Node builtin, staging FAILS,
//     surfacing the contamination instead of shipping a broken page.
//
// Usage:
//   node tools/deploy-web.mjs                    # stage browser closure to dist/web
//   node tools/deploy-web.mjs /path/to/target    # stage, then rsync into target dir
//   node tools/deploy-web.mjs --list             # print closure without staging
//
// Output: dist/web/<files> plus dist/web/MANIFEST.sha256. Exit 0 on success,
// 1 on verification failure, 2 on usage/IO error.

import { spawnSync } from "node:child_process";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const webDir = path.join(repoRoot, "web");
const distDir = path.join(repoRoot, "dist", "web");

const args = process.argv.slice(2);
const listOnly = args.includes("--list");
const targetArg = args.find((argument) => !argument.startsWith("--"));

function fail(message, code = 2) {
  console.error(`deploy-web: ${message}`);
  process.exit(code);
}

function readLocalRefsFromHtml(html) {
  const refs = new Set();
  const pattern = /(?:src|href)="(\.\/[^"]+)"/g;
  let match;
  while ((match = pattern.exec(html)) !== null) refs.add(match[1]);
  return [...refs];
}

function moduleRefs(source) {
  const refs = new Set();
  // Static and dynamic import specifiers must resolve — these are hard edges.
  const importPattern = /(?:from\s*|import\s*\(\s*|import\s+)["'](\.[^"']+)["']/g;
  let match;
  while ((match = importPattern.exec(source)) !== null) refs.add(match[1]);
  // Asset-like string literals (e.g. the PDF.js worker URL) are staged only if
  // they exist on disk, so prose strings can never break the build.
  const literalPattern = /["'](\.\/[A-Za-z0-9_\-./]+\.(?:mjs|js|css|woff2?))["']/g;
  while ((match = literalPattern.exec(source)) !== null) refs.add(match[1]);
  return [...refs];
}

function resolveRef(fromFile, ref) {
  const base = path.dirname(fromFile);
  const candidates = [ref, `${ref}.mjs`, `${ref}.js`, path.join(ref, "index.mjs")];
  for (const candidate of candidates) {
    const resolved = path.resolve(base, candidate);
    if (fs.existsSync(resolved) && fs.statSync(resolved).isFile()) return resolved;
  }
  return null;
}

function isScript(file) {
  return /\.(mjs|js)$/.test(file);
}

function walkClosure() {
  const htmlPath = path.join(webDir, "index.html");
  if (!fs.existsSync(htmlPath)) fail("web/index.html not found");
  const html = fs.readFileSync(htmlPath, "utf8");

  const queue = readLocalRefsFromHtml(html).map((ref) => path.resolve(webDir, ref));
  const closure = new Set([htmlPath]);
  const missing = [];

  while (queue.length > 0) {
    const file = queue.shift();
    if (closure.has(file)) continue;
    closure.add(file);
    if (!isScript(file)) continue;
    const source = fs.readFileSync(file, "utf8");
    // Vendored third-party builds (e.g. PDF.js) carry internal default-path
    // strings like "./pdf.worker.mjs" that the app overrides at runtime
    // (GlobalWorkerOptions.workerSrc). Their internal refs are staged only if
    // present; only first-party files owe us resolvable import edges.
    const fromVendor = file.includes(`${path.sep}vendor${path.sep}`);
    for (const ref of moduleRefs(source)) {
      const resolved = resolveRef(file, ref);
      if (resolved) {
        if (!closure.has(resolved)) queue.push(resolved);
      } else if (/\.mjs?$/.test(ref) && !fromVendor) {
        // A declared import edge that does not resolve is a real break.
        missing.push(`${path.relative(webDir, file)} -> ${ref}`);
      }
    }
  }

  // Vendor license notices ship with the code they cover (decision doc:
  // "preserve notices and dependency inventory").
  for (const file of [...closure]) {
    if (!file.includes(`${path.sep}vendor${path.sep}`)) continue;
    for (const entry of fs.readdirSync(path.dirname(file))) {
      if (/^LICENSE(\..+)?$/i.test(entry)) closure.add(path.join(path.dirname(file), entry));
    }
  }

  return { closure: [...closure].sort(), missing };
}

function verifyNoNodeBuiltins(closure) {
  const offenders = [];
  for (const file of closure) {
    if (!isScript(file)) continue;
    const source = fs.readFileSync(file, "utf8");
    if (/(?:from\s*["']|import\s*["']|require\(["'])node:/.test(source)) {
      offenders.push(path.relative(webDir, file));
    }
  }
  return offenders;
}

function stage(closure) {
  fs.rmSync(distDir, { recursive: true, force: true });
  const manifest = [];
  for (const file of closure) {
    const relative = path.relative(webDir, file);
    const destination = path.join(distDir, relative);
    fs.mkdirSync(path.dirname(destination), { recursive: true });
    fs.copyFileSync(file, destination);
    const bytes = fs.readFileSync(destination);
    manifest.push(`${crypto.createHash("sha256").update(bytes).digest("hex")}  ${relative}  ${bytes.length}`);
  }
  manifest.sort();
  const manifestPath = path.join(distDir, "MANIFEST.sha256");
  fs.writeFileSync(manifestPath, `${manifest.join("\n")}\n`);
  return { count: closure.length, manifestPath };
}

function rsyncTo(target) {
  const absolute = path.resolve(target);
  if (!fs.existsSync(absolute)) fail(`target directory does not exist: ${absolute}`);
  const result = spawnSync("rsync", ["-a", "--delete", `${distDir}/`, `${absolute}/`], { stdio: "inherit" });
  if (result.status !== 0) fail(`rsync exited ${result.status}`, 1);
  console.log(`Deployed dist/web/ -> ${absolute}`);
}

function main() {
  const { closure, missing } = walkClosure();
  if (missing.length > 0) {
    console.error("deploy-web: unresolved import edges in browser graph:");
    for (const edge of missing) console.error(`  ${edge}`);
    process.exit(1);
  }
  const nodeOffenders = verifyNoNodeBuiltins(closure);
  if (nodeOffenders.length > 0) {
    console.error("deploy-web: browser closure contains Node-builtin imports (must stay server-side):");
    for (const offender of nodeOffenders) console.error(`  ${offender}`);
    process.exit(1);
  }

  const totalBytes = closure.reduce((sum, file) => sum + fs.statSync(file).size, 0);
  if (listOnly) {
    for (const file of closure) console.log(path.relative(webDir, file));
    console.log(`\n${closure.length} file(s), ${(totalBytes / 1024).toFixed(1)} KiB`);
    return;
  }

  const { count, manifestPath } = stage(closure);
  console.log(`Staged ${count} file(s), ${(totalBytes / 1024).toFixed(1)} KiB -> dist/web`);
  console.log(`Manifest: ${path.relative(repoRoot, manifestPath)}`);
  const excluded = fs.readdirSync(webDir).filter((entry) => {
    const full = path.join(webDir, entry);
    return fs.statSync(full).isFile() && isScript(full) && !closure.includes(full);
  });
  if (excluded.length > 0) {
    console.log(`Server-plane modules excluded from static deploy (${excluded.length}): ${excluded.join(", ")}`);
  }
  if (targetArg) rsyncTo(targetArg);
}

main();
