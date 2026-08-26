#!/usr/bin/env node
// Aggregate contract-test runner for Tests/*_test.mjs.
//
// The repository has two test classes that were previously invoked one-by-one
// per docs/runbooks/release-gates.md:
//   1. Node contract tests — plain `node Tests/x_test.mjs`, no environment.
//   2. Browser tests — Playwright (channel "chrome") against a static server
//      rooted at the repository root, base URL http://127.0.0.1:4173/web/index.html
//      (PDF_PROOF_BASE_URL overrides).
//
// This runner discovers, classifies, executes, and aggregates both classes so a
// single command produces a package-wide pass/fail signal. It exits non-zero if
// any test fails. Classification is by source scan, not a hand-maintained list,
// so new tests are picked up automatically.
//
// Usage:
//   node tools/run-contract-tests.mjs                 # all tests (starts server for browser tests)
//   node tools/run-contract-tests.mjs --no-browser    # Node-only subset
//   node tools/run-contract-tests.mjs --filter template
//   node tools/run-contract-tests.mjs --list
//   node tools/run-contract-tests.mjs --json out.json # machine-readable report
//
// Exit codes: 0 = all selected tests passed; 1 = one or more failures; 2 = runner error.

import { spawn, spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const testsDir = path.join(repoRoot, "Tests");

const args = process.argv.slice(2);
function argValue(flag) {
  const index = args.indexOf(flag);
  return index !== -1 && index + 1 < args.length ? args[index + 1] : null;
}
const listOnly = args.includes("--list");
const skipBrowser = args.includes("--no-browser");
const filterArg = argValue("--filter");
const retryFailedPath = argValue("--retry-failed");
const jsonPath = argValue("--json");
const perTestTimeoutMs = (Number(argValue("--timeout")) || 180) * 1000;

const filter = filterArg ? new RegExp(filterArg) : null;
const retryFailed = retryFailedPath
  ? new Set(
      JSON.parse(fs.readFileSync(retryFailedPath, "utf8"))
        .results.filter((result) => !result.passed)
        .map((result) => path.resolve(repoRoot, result.file))
    )
  : null;

function discover() {
  return fs
    .readdirSync(testsDir)
    .filter((name) => name.endsWith("_test.mjs"))
    .sort()
    .map((name) => path.join(testsDir, name));
}

function isBrowserTest(file) {
  const source = fs.readFileSync(file, "utf8");
  return /playwright|chromium\.launch|PDF_PROOF_BASE_URL/.test(source);
}

async function startServer() {
  // Canonical pattern from README: repo-root static server on 4173 so the
  // browser tests can load /web/index.html. Reuses Python's http.server
  // instead of adding a second server implementation.
  const child = spawn("python3", ["-m", "http.server", "4173", "--bind", "127.0.0.1"], {
    cwd: repoRoot,
    stdio: "ignore",
    detached: true,
  });
  const deadline = Date.now() + 15000;
  while (Date.now() < deadline) {
    try {
      const response = await fetch("http://127.0.0.1:4173/web/index.html", { method: "HEAD" });
      if (response.ok) return child;
    } catch {
      // not ready yet
    }
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  throw new Error("static server on 127.0.0.1:4173 did not become ready within 15s");
}

function runTest(file) {
  return new Promise((resolve) => {
    const child = spawn("node", [file], {
      cwd: repoRoot,
      // Browser tests resolve their page via PDF_EDITOR_BASE_URL (some default
      // to ports 4174/4184 when run standalone). Always point them at THIS
      // runner's canonical server so the aggregate suite is deterministic.
      env: { ...process.env, PDF_EDITOR_BASE_URL: "http://127.0.0.1:4173/web/index.html" },
      stdio: ["ignore", "pipe", "pipe"],
    });
    let stdout = "";
    let stderr = "";
    let timedOut = false;
    const timer = setTimeout(() => {
      timedOut = true;
      child.kill("SIGKILL");
    }, perTestTimeoutMs);
    child.stdout.on("data", (chunk) => {
      stdout += chunk;
      if (stdout.length > 200_000) stdout = stdout.slice(-100_000);
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk;
      if (stderr.length > 200_000) stderr = stderr.slice(-100_000);
    });
    child.on("close", (code) => {
      clearTimeout(timer);
      resolve({
        file: path.relative(repoRoot, file),
        passed: code === 0 && !timedOut,
        code,
        timedOut,
        durationMs: 0,
        tail: (timedOut ? "[TIMEOUT]\n" : "") + (stderr || stdout).split("\n").slice(-15).join("\n").trim(),
      });
    });
    child.on("error", (error) => {
      clearTimeout(timer);
      resolve({ file: path.relative(repoRoot, file), passed: false, code: -1, timedOut: false, durationMs: 0, tail: String(error) });
    });
  });
}

async function main() {
  const all = discover();
  let selected = all.filter((file) => !filter || filter.test(path.basename(file)));
  if (retryFailed) selected = selected.filter((file) => retryFailed.has(file));
  const browserTests = skipBrowser ? [] : selected.filter(isBrowserTest);
  const nodeTests = selected.filter((file) => !browserTests.includes(file));

  if (listOnly) {
    for (const file of selected) {
      const kind = isBrowserTest(file) ? "browser" : "node";
      console.log(`${kind.padEnd(7)} ${path.relative(repoRoot, file)}`);
    }
    console.log(`\n${selected.length} test(s): ${nodeTests.length} node, ${browserTests.length} browser`);
    return;
  }

  console.log(`Running ${selected.length} test(s): ${nodeTests.length} node, ${browserTests.length} browser (timeout ${perTestTimeoutMs / 1000}s each)`);

  let server = null;
  const results = [];
  try {
    if (browserTests.length > 0) {
      server = await startServer();
      console.log("Static server ready on http://127.0.0.1:4173");
    }
    for (const file of nodeTests.concat(browserTests)) {
      const start = Date.now();
      process.stdout.write(`- ${path.relative(repoRoot, file)} ... `);
      const result = await runTest(file);
      result.durationMs = Date.now() - start;
      results.push(result);
      console.log(result.passed ? `PASS (${(result.durationMs / 1000).toFixed(1)}s)` : `FAIL (code ${result.code}${result.timedOut ? " timeout" : ""})`);
      if (!result.passed) {
        const tail = result.tail.split("\n").slice(-8).join("\n");
        if (tail) console.log(tail.split("\n").map((line) => `    ${line}`).join("\n"));
      }
    }
  } finally {
    if (server) {
      try {
        process.kill(-server.pid, "SIGTERM");
      } catch {
        try {
          server.kill("SIGTERM");
        } catch {
          // already gone
        }
      }
    }
  }

  const failed = results.filter((result) => !result.passed);
  const summary = {
    timestamp: new Date().toISOString(),
    total: results.length,
    passed: results.length - failed.length,
    failed: failed.length,
    browserCount: browserTests.length,
    failures: failed.map(({ file, code, timedOut }) => ({ file, code, timedOut })),
  };
  console.log(`\n${summary.passed}/${summary.total} passed, ${summary.failed} failed.`);
  if (jsonPath) {
    fs.mkdirSync(path.dirname(path.resolve(jsonPath)), { recursive: true });
    fs.writeFileSync(jsonPath, JSON.stringify({ summary, results }, null, 2));
    console.log(`JSON report: ${jsonPath}`);
  }
  process.exit(failed.length > 0 ? 1 : 0);
}

main().catch((error) => {
  console.error(`Runner error: ${error.message}`);
  process.exit(2);
});
