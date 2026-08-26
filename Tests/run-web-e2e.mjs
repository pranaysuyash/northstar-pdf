#!/usr/bin/env node
/**
 * Canonical web E2E test runner.
 *
 * Starts the static web server on a free port, runs every Playwright-based
 * web test with PDF_EDITOR_BASE_URL pointing at it, then shuts the server
 * down. Avoids port collisions with other dev servers (the old default of
 * 4173 was frequently hijacked by unrelated Vite apps).
 *
 * Usage:
 *   node Tests/run-web-e2e.mjs                # all web Playwright tests
 *   node Tests/run-web-e2e.mjs web_editor_e2e # only matching test files
 *
 * Exit code: 0 when every test exits 0, 1 otherwise.
 */
import { spawn } from "node:child_process";
import fs from "node:fs";
import net from "node:net";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(__dirname, "..");
const webDir = path.join(projectRoot, "web");
// Tests load modules from /Tests/..., /benchmark/..., /web/... relative to
// the server, so the server must serve the whole project root — not just web/.
const serveRoot = projectRoot;

const MIME = {
  ".html": "text/html",
  ".js": "text/javascript",
  ".css": "text/css",
  ".mjs": "text/javascript",
  ".json": "application/json",
  ".pdf": "application/pdf",
  ".svg": "image/svg+xml",
};

// --- Pick a free port ---
function freePort() {
  return new Promise((resolve, reject) => {
    const srv = net.createServer();
    srv.listen(0, "127.0.0.1", () => {
      const port = srv.address().port;
      srv.close(() => resolve(port));
    });
    srv.on("error", reject);
  });
}

// --- Static server (mirrors Tests/serve-web.mjs, serves web/ at root) ---
async function startServer(port) {
  const http = await import("node:http");
  const server = http.createServer((req, res) => {
    const url = new URL(req.url, "http://localhost");
    // Map / to the app entry so both /web/index.html and /index.html work.
    let relative = url.pathname === "/" ? "/web/index.html" : url.pathname;
    let filePath = path.join(serveRoot, relative);
    if (!filePath.startsWith(serveRoot)) {
      res.writeHead(403);
      res.end();
      return;
    }
    const ext = path.extname(filePath);
    fs.readFile(filePath, (err, data) => {
      if (err) {
        res.writeHead(404);
        res.end("Not found: " + url.pathname);
        return;
      }
      res.writeHead(200, { "Content-Type": MIME[ext] || "application/octet-stream" });
      res.end(data);
    });
  });
  await new Promise((resolve) => server.listen(port, "127.0.0.1", resolve));
  return server;
}

// --- Select test files --------------------------------------------------
function selectTestFiles(filter) {
  const all = fs
    .readdirSync(__dirname)
    .filter((f) => f.endsWith("_test.mjs"))
    .filter((f) => {
      const src = fs.readFileSync(path.join(__dirname, f), "utf8");
      // Only files that actually launch a browser via Playwright.
      return src.includes('from "playwright"') || src.includes("require('playwright')");
    })
    .sort();
  if (!filter) return all;
  return all.filter((f) => f.includes(filter));
}

async function main() {
  const filter = process.argv[2];
  const files = selectTestFiles(filter);
  if (files.length === 0) {
    console.error(`No web Playwright tests matched${filter ? `: ${filter}` : ""}`);
    process.exit(1);
  }

  const port = await freePort();
  // Match the /web/index.html convention used by the test files' fallbacks.
  const baseURL = `http://127.0.0.1:${port}/web/index.html`;
  const server = await startServer(port);
  console.log(`Web E2E runner: server on http://127.0.0.1:${port} (${files.length} test files)`);
  console.log(`Base URL: ${baseURL}\n`);

  let failed = 0;
  for (const file of files) {
    console.log(`\n=== ${file} ===`);
    const result = await new Promise((resolve) => {
      const child = spawn(
        process.execPath,
        [path.join(__dirname, file)],
        {
          cwd: projectRoot,
          env: { ...process.env, PDF_EDITOR_BASE_URL: baseURL },
          stdio: "inherit",
        }
      );
      child.on("exit", (code) => resolve(code ?? 1));
    });
    if (result !== 0) failed += 1;
  }

  server.close();
  console.log(`\n${failed === 0 ? "ALL WEB E2E TESTS PASSED" : `${failed} test file(s) failed`}`);
  process.exit(failed === 0 ? 0 : 1);
}

main().catch((err) => {
  console.error("Runner failed:", err.message);
  process.exit(1);
});