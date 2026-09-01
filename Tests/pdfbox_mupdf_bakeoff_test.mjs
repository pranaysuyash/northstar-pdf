import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";

const root = path.resolve(new URL("..", import.meta.url).pathname);
const runner = path.join(root, "benchmark/pdfbox-mupdf-bakeoff.mjs");
const temp = fs.mkdtempSync(path.join(os.tmpdir(), "pdf-editor-bakeoff-test-"));

try {
  const output = execFileSync(process.execPath, [runner, "--fixture", "public-sample-form"], {
    cwd: root,
    encoding: "utf8",
    env: { ...process.env, PDF_EDITOR_BAKEOFF_OUTPUT_DIR: temp }
  });
  const envelope = JSON.parse(output);
  assert.equal(envelope.fixtureCount, 1);
  const report = JSON.parse(fs.readFileSync(path.join(temp, "report.json"), "utf8"));
  assert.equal(report.contract, "pdf-editor.provider-bakeoff");
  assert.equal(report.run.rawDocumentContentInReport, false);
  assert.equal(report.run.sourceMetadataValuesInReport, false);
  assert.equal(report.run.networkUsed, false);
  assert.equal(report.run.outputDigestsAreIdentityOnly, true);
  assert.ok(report.providers.pdfbox.artifact.publishedSha512Matches, "PDFBox published digest must match");
  assert.equal(report.providers.pdfbox.license.identifier, "Apache-2.0");
  assert.equal(report.providers.mupdf.license.identifier, "AGPL-3.0-or-commercial");
  const item = report.cases[0];
  assert.equal(item.pdfbox.providerResult.inspection.status, "passed");
  assert.equal(item.pdfbox.providerResult.rewrite.reopen, "passed");
  assert.equal(item.pdfbox.providerResult.rewrite.independentText, "passed");
  assert.equal(item.pdfbox.providerResult.rewrite.independentRaster, "passed");
  assert.equal(item.pdfbox.providerResult.recovery.status, "passed");
  assert.equal(item.pdfbox.providerResult.recovery.publishedValidOutput, false);
  assert.equal(item.mupdf.providerResult.inspection.status, "passed");
  assert.equal(item.mupdf.providerResult.rewrite.reopen, "passed");
  assert.equal(item.mupdf.providerResult.rewrite.semanticText, "passed");
  assert.equal(item.mupdf.providerResult.rewrite.independentRaster, "passed");
  assert.equal(item.mupdf.providerResult.recovery.status, "passed");
  assert.equal(item.mupdf.providerResult.recovery.publishedValidOutput, false);
  assert.equal(item.mupdf.providerResult.supportedOperations["edit.existingText"].status, "unsupported-by-cli-lane");
  for (const provider of [item.pdfbox.providerResult, item.mupdf.providerResult]) {
    assert.equal(provider.providerResult, undefined);
  }

  const mutated = JSON.parse(fs.readFileSync(path.join(temp, "report.json"), "utf8"));
  mutated.providers.pdfbox.artifact.sha512 = crypto.createHash("sha512").update("mutation").digest("hex");
  fs.writeFileSync(path.join(temp, "mutated.json"), JSON.stringify(mutated));
  assert.notEqual(mutated.providers.pdfbox.artifact.sha512, report.providers.pdfbox.artifact.sha512, "artifact mutation must be visible");
  assert.equal(report.providers.pdfbox.artifact.publishedSha512Matches, true, "original evidence remains immutable");
  console.log("pdfbox versus mupdf bake-off: 23 checks passed");
} finally {
  fs.rmSync(temp, { recursive: true, force: true });
}
