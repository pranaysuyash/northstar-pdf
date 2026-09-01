#!/usr/bin/env node
// Runtime boot smoke for a staged static deployment.
//
// Serves a dist directory on a free local port, loads the entry page in
// headless Chrome via Playwright, and fails on any of:
//   - a non-200 entry response;
//   - a page error (uncaught exception);
//   - a failed subresource request (any 4xx/5xx — catches missing hashed
//     chunks, workers, and runtime-loaded assets that a source-level check
//     cannot see);
//   - an empty document body (app never mounted).
//
// Usage:
//   node tools/smoke-dist.mjs                    # defaults: dist/web, entry /index.html
//   node tools/smoke-dist.mjs dist/web-app       # prebuilt React app
//   node tools/smoke-dist.mjs dist/web "#app"    # optional required CSS selector
//
// Complements tools/deploy-web.mjs: the deployer proves the staged closure is
// complete at the file level; this proves it actually boots. Exit 0 on a
// clean boot, 1 on any violation, 2 on usage/IO errors.

import http from "node:http";
import fs from "node:fs";
import net from "node:net";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const distArg = process.argv[2] || path.join(repoRoot, "dist", "web");
const selectorArg = process.argv[3] || null;
const distDir = path.resolve(distArg);
const entryPath = "/index.html";

if (!fs.existsSync(path.join(distDir, "index.html"))) {
  console.error(`smoke-dist: no index.html in ${distDir}`);
  process.exit(2);
}

const MIME = {
  ".html": "text/html",
  ".js": "text/javascript",
  ".mjs": "text/javascript",
  ".css": "text/css",
  ".json": "application/json",
  ".pdf": "application/pdf",
  ".svg": "image/svg+xml",
  ".woff2": "font/woff2",
  ".wasm": "application/wasm",
};

function freePort() {
  return new Promise((resolve, reject) => {
    const server = net.createServer();
    server.listen(0, "127.0.0.1", () => {
      const port = server.address().port;
      server.close(() => resolve(port));
    });
    server.on("error", reject);
  });
}

function startServer(port) {
  const server = http.createServer((request, response) => {
    const url = new URL(request.url, "http://localhost");
    const filePath = path.join(distDir, url.pathname === "/" ? entryPath.slice(1) : url.pathname);
    fs.readFile(filePath, (error, data) => {
      if (error) {
        response.writeHead(404);
        response.end("Not found");
        return;
      }
      response.writeHead(200, { "Content-Type": MIME[path.extname(filePath)] || "application/octet-stream" });
      response.end(data);
    });
  });
  return new Promise((resolve) => server.listen(port, "127.0.0.1", () => resolve(server)));
}

async function main() {
  const port = await freePort();
  const server = await startServer(port);
  const baseURL = `http://127.0.0.1:${port}${entryPath}`;
  const browser = await chromium.launch({ channel: "chrome", headless: true });
  const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
  const pageErrors = [];
  const failedRequests = [];
  page.on("pageerror", (error) => pageErrors.push(error.message));
  page.on("response", (response) => {
    if (response.status() >= 400) failedRequests.push(`${response.status()} ${response.url()}`);
  });

  let violations = [];
  try {
    const response = await page.goto(baseURL, { waitUntil: "networkidle", timeout: 30_000 });
    if (!response || response.status() !== 200) {
      violations.push(`entry response ${response ? response.status() : "missing"}`);
    }
    if (pageErrors.length > 0) violations.push(`page errors: ${pageErrors.join(" | ")}`);
    if (failedRequests.length > 0) violations.push(`failed requests: ${failedRequests.join(" | ")}`);
    const bodyChildCount = await page.evaluate(() => document.body?.children.length ?? 0);
    if (bodyChildCount === 0) violations.push("document body is empty — app never mounted");
    if (selectorArg) {
      const found = await page.locator(selectorArg).count();
      if (found === 0) violations.push(`required selector not found: ${selectorArg}`);
    }
  } catch (error) {
    violations.push(`load failure: ${error.message}`);
  } finally {
    await browser.close();
    server.close();
  }

  if (violations.length > 0) {
    console.error(`smoke-dist: FAILED for ${path.relative(repoRoot, distDir)}`);
    for (const violation of violations) console.error(`  - ${violation}`);
    process.exit(1);
  }
  console.log(`smoke-dist: OK — ${path.relative(repoRoot, distDir)} boots cleanly at ${entryPath}`);
  process.exit(0);
}

main().catch((error) => {
  console.error(`smoke-dist: ${error.message}`);
  process.exit(2);
});
