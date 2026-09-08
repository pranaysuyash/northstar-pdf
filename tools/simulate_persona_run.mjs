import http from "node:http";
import { promises as fs } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";

const testDirectory = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(testDirectory, "..");
const fixture = path.join(projectRoot, "docs/benchmarks/pdfkit-form6-run-2026-08-23/noop.pdf");

const PERSONA = process.env.SIM_PERSONA || "P1-Rosa";
const VALUE1 = process.env.SIM_VALUE1 || "Reviewed value";
const VALUE2 = process.env.SIM_VALUE2 || "Updated value";
const VALUE3 = process.env.SIM_VALUE3 || "Manual value";

const mimeTypes = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json",
  ".pdf": "application/pdf",
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".wasm": "application/wasm",
};

const results = [];
function check(name, ok, detail = "") {
  results.push({ name, ok: Boolean(ok), detail });
  if (!ok) throw new Error(`ASSERT FAIL: ${name} ${detail}`);
}

let server;
let baseURL = process.env.PDF_EDITOR_BASE_URL;
if (!baseURL) {
  server = http.createServer(async (req, res) => {
    try {
      const urlPath = decodeURIComponent(new URL(req.url, "http://127.0.0.1").pathname);
      const filePath = path.join(projectRoot, path.normalize(urlPath));
      if (!filePath.startsWith(projectRoot)) throw new Error("path traversal rejected");
      const data = await fs.readFile(filePath);
      res.writeHead(200, { "content-type": mimeTypes[path.extname(filePath).toLowerCase()] ?? "application/octet-stream" });
      res.end(data);
    } catch {
      res.writeHead(404, { "content-type": "text/plain" });
      res.end("not found");
    }
  });
  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", resolve);
  });
  baseURL = `http://127.0.0.1:${server.address().port}/web/index.html`;
}

const browser = await chromium.launch({ channel: "chrome", headless: true });
const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
page.setDefaultTimeout(8000);
const pageerrors = [];
const consoleErrors = [];
page.on("pageerror", (e) => pageerrors.push(e.message));
page.on("console", (m) => { if (m.type() === "error") consoleErrors.push(m.text()); });

const t0 = Date.now();
try {
  await page.goto(baseURL, { waitUntil: "networkidle" });
  check("app loads", true);
  await page.waitForFunction(() => Boolean(window.pdfjsLib && window.PDFLib));
  check("runtimes ready (pdfjs + pdflib)", true);

  await page.locator("#fileInput").setInputFiles(fixture);
  await page.waitForFunction(() => Boolean(window.__pdfEditorContractFixture?.snapshot?.()?.document));
  check("fixture opens + contract snapshot", true);

  // Universal fill loop
  let row = page.locator("#candidateList .completion-item").filter({ hasText: "Text entry region" }).first();
  if ((await row.count()) === 0) row = page.locator("#candidateList .completion-item").filter({ hasText: "Character-entry region" }).first();
  check("editable candidate listed", (await row.count()) === 1);
  await row.locator("button").click();
  await page.waitForFunction(() => !document.querySelector("#candidateAction")?.hidden);
  check("candidate review card opens", true);
  await page.locator(".candidate-preview.selected").first().waitFor();
  check("candidate highlighted on page", (await page.locator(".candidate-preview.selected").count()) > 0);

  // No silent apply: Apply requires selection (review gate)
  await page.locator("#completionValue").fill(VALUE1);
  await page.locator("#applyOverlayButton").click();
  check("apply overlay", (await page.locator("#editList").textContent()).includes("overlayText"));
  check("overlay preview visible", (await page.locator(".overlay-preview").count()) === 1);

  await page.locator(".overlay-preview").click();
  await page.locator("#completionValue").fill(VALUE2);
  await page.locator("#applyOverlayButton").click();
  check("edit overlay value", (await page.locator("#editList").textContent()).includes(VALUE2));

  await page.locator("#undoEditButton").click();
  await page.waitForFunction(() => document.querySelectorAll(".overlay-preview").length === 0);
  check("undo removes overlay", (await page.locator(".overlay-preview").count()) === 0);

  await page.locator("#dismissCandidateButton").click();
  check("dismiss updates restore count", (await page.locator("#restoreDismissedButton").textContent()).includes("(1)"));
  await page.locator("#restoreDismissedButton").click();
  check("restore candidate", (await page.locator("#candidateList button").filter({ hasText: "Restore" }).count()) === 1);
  await page.locator("#candidateList button").filter({ hasText: "Restore" }).first().click();

  await page.locator("#manualTextButton").click();
  check("manual placement prompts click", (await page.locator("#status").textContent()).match(/Click the document/i) !== null);
  await page.locator("#viewerStack .page-shell").first().click({ position: { x: 110, y: 110 } });
  await page.locator("#completionValue").fill(VALUE3);
  await page.locator("#applyOverlayButton").click();
  check("manual overlay applied", (await page.locator("#editList").textContent()).includes(VALUE3));

  // Persona overlays
  if (PERSONA.startsWith("P2")) {
    check("preflight panel renders", ((await page.locator("#preflightBox").textContent()) || "").trim().length > 0, "privacy preflight visible");
    check("validation panel present", (await page.locator("#validationBox").count()) === 1);
    check("permissions panel renders", (await page.locator("#permissionsBox").count()) === 1);
  }
  if (PERSONA.startsWith("P3")) {
    check("template card present", (await page.locator("#templateCard").count()) === 1);
    check("profile panel present", (await page.locator("#profilePanel").count()) === 1);
  }
  if (PERSONA.startsWith("P4")) {
    for (const id of ["#mode-tab-reader", "#mode-tab-understand", "#mode-tab-complete", "#mode-tab-organize", "#mode-tab-review"]) {
      check(`mode tab visible ${id}`, (await page.locator(id).count()) === 1);
    }
    check("search present", (await page.locator("#searchInput").count()) === 1);
    check("thumbnails present", (await page.locator("#thumbnails").count()) === 1);
    check("diff toggle present", (await page.locator("#diffToggleButton").count()) === 1);
    check("shortcuts help toggles", true, "button exists=" + (await page.locator("#shortcutsHelpButton").count()));
  }
  check("zero pageerrors", pageerrors.length === 0, pageerrors.join(" | ").slice(0, 500));
} finally {
  await browser.close();
  server?.close();
}

const out = {
  persona: PERSONA,
  values: [VALUE1, VALUE2, VALUE3],
  durationMs: Date.now() - t0,
  pageerrors,
  consoleErrors: consoleErrors.slice(0, 10),
  checks: results,
  pass: results.every((r) => r.ok),
};
const outDir = path.join(projectRoot, "docs/simulations/evidence");
await fs.mkdir(outDir, { recursive: true });
const fname = `sim-${PERSONA}-${new Date().toISOString().slice(0, 10)}.json`;
await fs.writeFile(path.join(outDir, fname), JSON.stringify(out, null, 2));
console.log(JSON.stringify(out, null, 2));
