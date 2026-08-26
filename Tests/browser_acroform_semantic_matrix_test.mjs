import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { chromium } from "playwright";

const root = path.resolve(new URL("..", import.meta.url).pathname);
const fixture = path.join(root, "benchmark/results/public-sample-form.pdf");
const reportDirectory = path.join(root, "benchmark/results/acroform-matrix-2026-08-25");
const baseURL = process.env.PDF_EDITOR_BASE_URL || "http://127.0.0.1:4184/web/index.html";

function valueForField(field) {
  if (field.kind === "choice") return field.choices[0] || "Other";
  if (field.kind === "button" && field.choices.length > 1) return field.choices[0];
  if (field.kind === "button") return "true";
  return field.fieldFlags === 4096 ? "Multiline browser matrix" : "Text browser matrix";
}

const browser = await chromium.launch({ channel: "chrome", headless: true });
const results = [];
try {
  const seedPage = await browser.newPage({ acceptDownloads: true });
  const seedURL = new URL(baseURL);
  seedURL.searchParams.set("proof", `acroform-matrix-${Date.now()}`);
  await seedPage.goto(seedURL.toString(), { waitUntil: "networkidle" });
  await seedPage.waitForFunction(() => Boolean(window.pdfjsLib && window.PDFLib && window.__pdfEditorContractFixture?.snapshot));
  await seedPage.locator("#fileInput").setInputFiles(fixture);
  await seedPage.waitForFunction(() => Boolean(window.__pdfEditorContractFixture?.snapshot?.()?.document));
  const fields = await seedPage.evaluate(() => window.__pdfEditorContractFixture.snapshot().document.payload.fields);
  await seedPage.close();

  const selected = [];
  for (const field of fields) {
    if (!selected.some((candidate) => candidate.kind === field.kind && candidate.name === field.name)) selected.push(field);
  }
  assert.deepEqual(new Set(selected.map((field) => field.kind)), new Set(["text", "button", "choice"]));
  assert.ok(selected.some((field) => field.name === "applicant.contact" && field.choices.length > 1), "radio group must be represented");
  assert.ok(selected.some((field) => field.name === "applicant.subscribe" && field.choices.length === 0), "checkbox must be represented");

  for (const field of selected) {
    const page = await browser.newPage({ acceptDownloads: true });
    const url = new URL(baseURL);
    url.searchParams.set("proof", `acroform-${field.kind}-${Date.now()}-${Math.random()}`);
    await page.goto(url.toString(), { waitUntil: "networkidle" });
    await page.waitForFunction(() => Boolean(window.pdfjsLib && window.PDFLib && window.__pdfEditorContractFixture?.snapshot));
    await page.locator("#fileInput").setInputFiles(fixture);
    await page.waitForFunction(() => Boolean(window.__pdfEditorContractFixture?.snapshot?.()?.document));
    const currentFields = await page.evaluate(() => window.__pdfEditorContractFixture.snapshot().document.payload.fields);
    const fieldIndex = currentFields.findIndex((candidate) => candidate.name === field.name && candidate.kind === field.kind);
    assert.ok(fieldIndex >= 0, `${field.kind} field ${field.name} should be selectable`);
    await page.locator("#fieldList .completion-item").nth(fieldIndex).locator("button").first().click();
    const value = valueForField(field);
    if (field.kind === "button" && field.choices.length > 1) {
      await page.locator("#fieldControl select").selectOption(value);
    } else {
      await page.locator("#completionValue").fill(value);
    }
    await page.locator("#applyFieldButton").click();
    const operation = await page.evaluate(() => window.__pdfEditorContractFixture.snapshot().editSession.operations[0]);
    assert.equal(operation.kind, "nativeFieldValue");
    assert.equal(operation.targetID, field.name);
    const downloadPromise = page.waitForEvent("download", { timeout: 15_000 }).catch(() => null);
    await page.locator("#exportButton").click();
    await page.waitForTimeout(1_000);
    const download = await downloadPromise;
    const snapshot = await page.evaluate(() => window.__pdfEditorContractFixture.snapshot());
    results.push({
      kind: field.kind,
      fieldName: field.name,
      hierarchical: field.name.includes("."),
      radioOrChoice: field.choices.length > 1,
      operationKind: operation.kind,
      exportStatus: snapshot.validation?.status || "unknown",
      downloaded: Boolean(download),
      validationKinds: (snapshot.validation?.checks || []).map((check) => `${check.kind}:${check.status}`),
      failureCodes: (snapshot.validation?.messages || []).filter((message) => /unsupported|failed|not found|error/i.test(message)).map((message) => message.slice(0, 160))
    });
    await page.close();
  }
} finally {
  await browser.close();
}

assert.ok(results.length >= 3);
assert.ok(results.every((result) => result.operationKind === "nativeFieldValue"));
fs.mkdirSync(reportDirectory, { recursive: true });
const report = {
  contract: "pdf-editor.acroform-semantic-matrix",
  version: { major: 1, minor: 0 },
  source: "benchmark/results/public-sample-form.pdf",
  provider: "pdfjs-pdflib",
  status: "measured",
  results,
  rawValuesInReport: false,
  interpretation: "Operation creation parity is proven separately from provider export round-trip. A failed or unsupported class remains an explicit provider result."
};
fs.writeFileSync(path.join(reportDirectory, "report.json"), `${JSON.stringify(report, null, 2)}\n`);
console.log(JSON.stringify(report, null, 2));
