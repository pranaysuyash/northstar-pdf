/**
 * React surface end-to-end smoke (map steps 2-8 bridge).
 *
 * Verifies the canonical web/app entry against a real Chromium: five-mode
 * rail from the contract module, document open through the controller
 * boundary, search highlights, native-field enumeration, reversible
 * operation history, and export with independent reopen validation.
 *
 * Prerequisites:
 *   cd web/app && npm install && npm run build
 *   npx vite preview --port 4181   (from web/app)
 *   node benchmark/react-surface-smoke.mjs [port]
 */
import { chromium } from "playwright";
import path from "node:path";
import process from "node:process";

const PORT = process.argv[2] ?? "4181";
const APP = `http://localhost:${PORT}/`;
const FIXTURE = path.resolve("benchmark/results/browser-corpus/hybrid-text-raster-form.pdf");
const EXECUTABLE =
  process.env.CHROMIUM_EXECUTABLE ??
  `${process.env.HOME}/Library/Caches/ms-playwright/chromium-1234/chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing`;

function fail(message) {
  console.error(`FAIL: ${message}`);
  process.exit(1);
}

const browser = await chromium.launch({ executablePath: EXECUTABLE });
const context = await browser.newContext({
  viewport: { width: 1440, height: 900 },
  acceptDownloads: true
});
const page = await context.newPage();
const errors = [];
page.on("pageerror", (error) => errors.push(String(error)));
page.on("console", (message) => {
  if (message.type() === "error") errors.push(message.text());
});

await page.goto(APP, { waitUntil: "networkidle" });

const tabs = await page.locator("[role=tab]").count();
if (tabs !== 5) fail(`expected 5 mode tabs, got ${tabs}`);

await page.setInputFiles("#fileInput", FIXTURE);
await page.waitForFunction(
  () => document.querySelector(".mode-context-line")?.textContent?.includes("Page 1 of"),
  null,
  { timeout: 15000 }
);

// Reader: search produces page-indexed matches and on-canvas highlights.
await page.fill("#searchInput", "form");
await page.click('[aria-label="Find occurrences in document"]');
await page.waitForFunction(
  () => document.querySelectorAll(".match-highlight").length > 0,
  null,
  { timeout: 10000 }
);
console.log("reader highlights:", await page.locator(".match-highlight").count());

// Complete: contract adapter enumerates AcroForm widgets; confirm enters history.
await page.click("#mode-tab-complete");
await page.waitForSelector("input.field-input", { timeout: 10000 });
const fieldCount = await page.locator(".field-row").count();
if (!fieldCount) fail("native fields were not enumerated");
const firstField = page.locator("input.field-input").first();
await firstField.fill("Smoke value");
await page.getByRole("button", { name: "Confirm changes" }).click();

// Review: pending operation visible; export validates and downloads.
await page.click("#mode-tab-review");
await page.waitForFunction(() => document.querySelectorAll(".op-log li").length === 1, null, {
  timeout: 5000
});
const downloadPromise = page.waitForEvent("download", { timeout: 20000 });
await page.getByRole("button", { name: /Export new copy/ }).click();
const download = await downloadPromise;
const report = await page.locator(".validation-report li").allTextContents();
const allPassed = report.every((line) => !line.startsWith("[failed]"));
if (!allPassed) fail(`validation reported failures: ${report.join(" | ")}`);
console.log("export downloaded:", download.suggestedFilename());

// Reversibility: undo restores the observed source value.
await page.click("#mode-tab-complete");
await page.getByRole("button", { name: "Undo last" }).click();
await page.waitForFunction(() => {
  const input = document.querySelector("input.field-input");
  return input && input.value === "";
}, null, { timeout: 5000 });
console.log("undo restored source value");

if (errors.length) fail(`page errors: ${errors.join(" | ")}`);
console.log("PASS: react surface smoke complete");
await browser.close();
