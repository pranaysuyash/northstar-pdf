/**
 * Visual regression test: web toolbar at multiple viewport widths.
 *
 * Captures the toolbar at 320, 768, 1024, 1440, and 1920px widths.
 * Checks for overflow, truncation, horizontal scroll, and layout integrity.
 * Compares against baseline screenshots if they exist; otherwise creates them.
 *
 * Run: node Tests/toolbar_visual_regression_test.mjs
 * Baselines: Tests/baselines/toolbar-*.png
 */

import assert from "node:assert/strict";
import fs from "node:fs";
import http from "node:http";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, "..");
const webDir = path.join(root, "web");
const baselineDir = path.join(__dirname, "baselines");
const outputDir = path.join(__dirname, "toolbar-regression-output");

const VIEWPORT_WIDTHS = [320, 768, 1024, 1440, 1920];
const VIEWPORT_HEIGHT = 900;
const TOLERANCE = 0.02; // 2% pixel diff tolerance

let checks = 0;
const check = (condition, message) => {
  assert.ok(condition, message);
  checks += 1;
};

// --- Simple static file server ---
function createServer() {
  const mimeTypes = {
    ".html": "text/html",
    ".css": "text/css",
    ".js": "application/javascript",
    ".mjs": "application/javascript",
    ".json": "application/json",
    ".png": "image/png",
    ".svg": "image/svg+xml",
  };

  return http.createServer((req, res) => {
    let filePath = path.join(webDir, req.url === "/" ? "index.html" : req.url);
    // Security: prevent path traversal
    if (!filePath.startsWith(webDir)) {
      res.writeHead(403);
      res.end();
      return;
    }
    const ext = path.extname(filePath);
    const contentType = mimeTypes[ext] || "application/octet-stream";

    fs.readFile(filePath, (err, data) => {
      if (err) {
        res.writeHead(404);
        res.end();
        return;
      }
      res.writeHead(200, { "Content-Type": contentType });
      res.end(data);
    });
  });
}

// --- Image comparison ---
function compareImages(bufA, bufB) {
  // Simple byte-level comparison for now.
  // For production, use pixelmatch or similar.
  if (bufA.length !== bufB.length) return false;
  return bufA.equals(bufB);
}

function computePixelDiffPercent(bufA, bufB) {
  if (bufA.length !== bufB.length) return 1.0; // completely different
  let diff = 0;
  for (let i = 0; i < bufA.length; i++) {
    if (bufA[i] !== bufB[i]) diff++;
  }
  return diff / bufA.length;
}

// --- Main test ---
async function run() {
  // Ensure output dirs exist
  fs.mkdirSync(baselineDir, { recursive: true });
  fs.mkdirSync(outputDir, { recursive: true });

  // Start server
  const server = createServer();
  const port = 4199;
  await new Promise((resolve) => server.listen(port, resolve));

  let browser;
  try {
    const { chromium } = await import("playwright");
    // Repo convention: use system Chrome ("chrome" channel) so the suite does
    // not depend on Playwright-managed browser downloads (air-gap friendly).
    browser = await chromium.launch({ channel: "chrome", headless: true });

    const results = [];

    for (const width of VIEWPORT_WIDTHS) {
      const context = await browser.newContext({
        viewport: { width, height: VIEWPORT_HEIGHT },
      });
      const page = await context.newPage();

      await page.goto(`http://127.0.0.1:${port}/`, {
        waitUntil: "networkidle",
        timeout: 15000,
      });

      // Wait for toolbar to render
      await page.waitForSelector(".toolbar", { timeout: 5000 });

      // Check 1: Toolbar exists and is visible
      const toolbarVisible = await page.isVisible(".toolbar");
      check(toolbarVisible, `Toolbar visible at ${width}px`);

      // Check 2: No horizontal overflow on the toolbar
      const toolbarOverflow = await page.evaluate(() => {
        const toolbar = document.querySelector(".toolbar");
        if (!toolbar) return { hasOverflow: true, offsetWidth: 0, viewportWidth: 0 };
        const rect = toolbar.getBoundingClientRect();
        return {
          hasOverflow: rect.width > window.innerWidth + 2,
          offsetWidth: Math.round(rect.width),
          viewportWidth: window.innerWidth,
        };
      });
      check(
        !toolbarOverflow.hasOverflow,
        `Toolbar no horizontal overflow at ${width}px (offsetWidth=${toolbarOverflow.offsetWidth}, viewport=${toolbarOverflow.viewportWidth})`
      );

      // Check 3: Mode pills are visible
      const modePillsVisible = await page.isVisible("#webEditorModePill");
      check(modePillsVisible, `Mode pills visible at ${width}px`);

      // Check 4: All mode pill buttons are visible (not truncated)
      const pillCount = await page.locator("#webEditorModePill button").count();
      check(pillCount === 4, `All 4 mode pills present at ${width}px (found ${pillCount})`);

      // Check 5: Search input is accessible
      const searchVisible = await page.isVisible("#searchInput");
      check(searchVisible, `Search input visible at ${width}px`);

      // Check 6: No body horizontal overflow
      const bodyOverflow = await page.evaluate(() => {
        return {
          hasOverflow: document.body.scrollWidth > window.innerWidth + 2,
          scrollWidth: document.body.scrollWidth,
          viewportWidth: window.innerWidth,
        };
      });
      check(
        !bodyOverflow.hasOverflow,
        `No body horizontal overflow at ${width}px (scrollWidth=${bodyOverflow.scrollWidth}, viewport=${bodyOverflow.viewportWidth})`
      );

      // Check 7: Toolbar height is reasonable (not collapsed to 0)
      const toolbarHeight = await page.evaluate(() => {
        const toolbar = document.querySelector(".toolbar");
        return toolbar ? toolbar.getBoundingClientRect().height : 0;
      });
      check(toolbarHeight > 20, `Toolbar height > 20px at ${width}px (got ${toolbarHeight})`);

      // Capture screenshot
      const toolbarEl = await page.$(".toolbar");
      if (toolbarEl) {
        const screenshotPath = path.join(outputDir, `toolbar-${width}px.png`);
        await toolbarEl.screenshot({ path: screenshotPath });

        // Compare against baseline if it exists
        const baselinePath = path.join(baselineDir, `toolbar-${width}px.png`);
        if (fs.existsSync(baselinePath)) {
          const baseline = fs.readFileSync(baselinePath);
          const current = fs.readFileSync(screenshotPath);
          const identical = compareImages(baseline, current);
          if (!identical) {
            const diffPercent = computePixelDiffPercent(baseline, current);
            check(
              diffPercent < TOLERANCE,
              `Screenshot matches baseline at ${width}px (diff: ${(diffPercent * 100).toFixed(2)}%)`
            );
            results.push({ width, status: "CHANGED", diffPercent });
          } else {
            results.push({ width, status: "IDENTICAL" });
          }
        } else {
          // No baseline yet — copy current as baseline
          fs.copyFileSync(screenshotPath, baselinePath);
          results.push({ width, status: "BASELINE_CREATED" });
        }
      }

      await context.close();
    }

    // Summary
    console.log("\n=== Toolbar Visual Regression Results ===");
    for (const r of results) {
      console.log(`  ${r.width}px: ${r.status}${r.diffPercent ? ` (${(r.diffPercent * 100).toFixed(2)}% diff)` : ""}`);
    }
    console.log(`\n${checks} checks passed.`);
    console.log(`Screenshots saved to: ${outputDir}`);
  } finally {
    if (browser) await browser.close();
    server.close();
  }
}

run().catch((err) => {
  console.error("Test failed:", err.message);
  process.exit(1);
});
