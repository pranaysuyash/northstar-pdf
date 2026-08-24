import assert from "node:assert/strict";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "/Users/pranay/.agents/skills/testing/playwright-skill/node_modules/playwright/index.mjs";

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const baseURL = process.env.PDF_PROOF_BASE_URL || "http://127.0.0.1:4173/web/index.html";

const browser = await chromium.launch({ channel: "chrome", headless: true });
const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
const consoleErrors = [];
const pageErrors = [];
page.on("console", (message) => {
  if (message.type() === "error") { consoleErrors.push(message.text()); }
});
page.on("pageerror", (error) => pageErrors.push(error.message));

try {
  await page.goto(baseURL, { waitUntil: "networkidle" });
  await page.waitForFunction(() => Boolean(window.pdfjsLib && window.PDFLib));

  assert.equal(await page.locator("main#viewerMain").count(), 1);
  assert.equal(await page.locator('aside[aria-label="Page thumbnails"]').count(), 1);
  assert.equal(await page.locator('aside[aria-label="Reading and navigation tools"]').count(), 1);
  assert.equal(await page.locator('[role="status"][aria-live="polite"]').count() >= 1, true);

  await page.locator(".skip-link").focus();
  await page.keyboard.press("Enter");
  await page.waitForFunction(() => document.activeElement?.id === "viewerMain");

  const sample = path.join(projectRoot, "benchmark/results/public-sample-form.pdf");
  await page.locator("#fileInput").setInputFiles(sample);
  await page.waitForFunction(() => /SHA-256/.test(document.querySelector("#completionSource")?.textContent || ""));
  const spans = page.locator(".text-layer span[tabindex='0'][aria-label]");
  await page.waitForFunction(
    () => document.querySelectorAll(".text-layer span[tabindex='0'][aria-label]").length > 0,
    undefined,
    { timeout: 30_000 }
  );
  assert.ok(await spans.count() > 0, "rendered text must expose keyboard-focusable accessible spans");
  await spans.first().focus();
  assert.equal(await page.evaluate(() => document.activeElement?.tagName), "SPAN");

  const encrypted = path.join(projectRoot, "benchmark/results/security-corpus/encrypted-reader.pdf");
  await page.locator("#fileInput").setInputFiles(encrypted);
  const dialog = page.getByRole("dialog");
  await dialog.waitFor({ state: "visible" });
  assert.equal(await dialog.getAttribute("aria-modal"), "true");
  assert.equal(await page.locator('label[for="passwordInput"]').textContent(), "PDF password");
  assert.equal(await page.locator("#passwordInput").getAttribute("autocomplete"), "current-password");

  assert.deepEqual(consoleErrors, [], `browser console errors: ${consoleErrors.join(" | ")}`);
  assert.deepEqual(pageErrors, [], `browser page errors: ${pageErrors.join(" | ")}`);
  console.log("web accessibility gate: landmarks, skip-link focus, text-layer keyboard access, password dialog, and error-free runtime passed");
} finally {
  await browser.close();
}
