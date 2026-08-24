import assert from "node:assert/strict";
import { chromium } from "/Users/pranay/.agents/skills/testing/playwright-skill/node_modules/playwright/index.mjs";

const baseURL = process.env.PDF_EDITOR_BASE_URL || "http://127.0.0.1:4173/web/index.html";
const browser = await chromium.launch({ channel: "chrome", headless: true });
const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
page.setDefaultTimeout(10_000);

try {
  await page.goto(baseURL, { waitUntil: "networkidle" });
  await page.waitForFunction(() => Boolean(window.pdfjsLib && window.PDFLib));
  const fixtureBytes = await page.evaluate(async () => {
    const document = await window.PDFLib.PDFDocument.create();
    const page = document.addPage([612, 792]);
    const form = document.getForm();
    const checkbox = form.createCheckBox("consent");
    checkbox.addToPage(page, { x: 72, y: 700, width: 20, height: 20 });
    const radio = form.createRadioGroup("status");
    radio.addOptionToPage("yes", page, { x: 72, y: 650, width: 20, height: 20 });
    radio.addOptionToPage("no", page, { x: 108, y: 650, width: 20, height: 20 });
    return [...await document.save()];
  });
  await page.locator("#fileInput").setInputFiles({
    name: "browser-native-choice-fixture.pdf",
    mimeType: "application/pdf",
    buffer: Buffer.from(fixtureBytes)
  });
  await page.waitForFunction(() => Boolean(window.__pdfEditorContractFixture?.snapshot?.()?.document));
  const snapshot = await page.evaluate(() => window.__pdfEditorContractFixture.snapshot());
  const buttonFields = snapshot.document.payload.fields.filter((field) => field.kind === "button");
  assert.ok(buttonFields.length > 0);

  const consentRow = page.locator("#fieldList .completion-item").filter({ hasText: buttonFields[0].name }).first();
  await consentRow.locator("button").click();
  await page.waitForFunction(() => document.querySelector("#fieldControl input[type=checkbox]") !== null);
  const consent = page.locator("#fieldControl input[type=checkbox]");
  await consent.evaluate((element) => {
    element.checked = true;
    element.dispatchEvent(new Event("change", { bubbles: true }));
  });
  await page.locator("#applyFieldButton").click();

  const radioField = buttonFields.find((field) => buttonFields.filter((candidate) => candidate.name === field.name).length > 1) || buttonFields[0];
  const statusRow = page.locator("#fieldList .completion-item").filter({ hasText: radioField.name }).last();
  await statusRow.locator("button").click();
  await page.waitForFunction(() => document.querySelector("#fieldControl select") !== null);
  const radioSelect = page.locator("#fieldControl select");
  assert.ok((await radioSelect.locator("option").count()) >= 2, "radio group should expose its export options");
  await radioSelect.selectOption({ index: 1 });
  await page.locator("#applyFieldButton").click();
  assert.match(await page.locator("#editList").textContent(), /nativeFieldValue/);

  const downloadPromise = page.waitForEvent("download", { timeout: 15_000 }).catch(() => null);
  await page.locator("#exportButton").click();
  const download = await downloadPromise;
  assert.ok(download, `browser export did not download: ${await page.locator("#status").textContent()}`);
  const validation = await page.locator("#validationBox").textContent();
  assert.match(validation, /Last export: validated/);
  assert.match(validation, /nativeFields/);
  assert.ok((await download.suggestedFilename()).includes("web"));
  console.log("web native choice workflow: checkbox control, radio-group control, export, and reopen validation passed");
} finally {
  await browser.close();
}
