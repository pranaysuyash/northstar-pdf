import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  chooseBrowserResourcePolicy,
  normalizeResourceDocument,
  validateBrowserResourcePolicy
} from "../web/browser-resource-policy.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const fixture = JSON.parse(fs.readFileSync(path.join(root, "Tests/fixtures/browser_resource_policy_benchmark.json"), "utf8"));
const outputDirectory = path.join(root, "benchmark/results/browser-resource-policy");
const outputPath = path.join(outputDirectory, "2026-08-25-device-adaptive.json");
const digest = "a".repeat(64);
const startedAt = new Date().toISOString();
const rows = [];

for (const device of fixture.deviceProfiles) {
  for (const document of fixture.documentClasses) {
    const start = performance.now();
    const policy = chooseBrowserResourcePolicy({
      environment: device,
      document: normalizeResourceDocument(document),
      request: { renderMode: "reader", ocrRequested: true, batchRequested: true, highDPIRequested: true },
      sourceDigest: digest,
      provider: { providerID: "browser-resource-policy-benchmark", runtimeKind: "node-replay" }
    });
    validateBrowserResourcePolicy(policy, { expectedSourceDigest: digest });
    const elapsedMs = Math.round((performance.now() - start) * 1000) / 1000;
    rows.push({
      deviceProfileID: device.id,
      documentClassID: document.id,
      policy,
      elapsedMs,
      decisionStates: Object.fromEntries(policy.payload.decisions.map((decision) => [decision.capability, decision.state])),
      render: {
        maxDevicePixelRatio: policy.payload.budgets.render.maxDevicePixelRatio,
        maxCanvasPixels: policy.payload.budgets.render.maxCanvasPixels,
        maxConcurrentPages: policy.payload.budgets.render.maxConcurrentPages,
        workerCount: policy.payload.budgets.render.workerCount,
        allowHighDPI: policy.payload.budgets.render.allowHighDPI,
        reasons: policy.payload.budgets.render.reasons
      },
      ocr: {
        state: policy.payload.budgets.ocr.state,
        maxConcurrentJobs: policy.payload.budgets.ocr.maxConcurrentJobs,
        maxPixelsPerPage: policy.payload.budgets.ocr.maxPixelsPerPage,
        maxPagesPerBatch: policy.payload.budgets.ocr.maxPagesPerBatch,
        reasons: policy.payload.budgets.ocr.reasons
      },
      batch: {
        state: policy.payload.budgets.batch.state,
        maxDocuments: policy.payload.budgets.batch.maxDocuments,
        maxTotalBytes: policy.payload.budgets.batch.maxTotalBytes,
        maxTotalPages: policy.payload.budgets.batch.maxTotalPages,
        maxConcurrentDocuments: policy.payload.budgets.batch.maxConcurrentDocuments,
        checkpointEveryDocuments: policy.payload.budgets.batch.checkpointEveryDocuments,
        checkpointEveryPages: policy.payload.budgets.batch.checkpointEveryPages,
        reasons: policy.payload.budgets.batch.reasons
      },
      recovery: {
        checkpointRequired: policy.payload.budgets.recovery.checkpointRequired,
        retryCount: policy.payload.budgets.recovery.retryCount,
        cancellationSupported: policy.payload.budgets.recovery.cancellationSupported,
        partialOutputAllowed: policy.payload.budgets.recovery.partialOutputAllowed,
        reasons: policy.payload.budgets.recovery.reasons
      },
      safety: policy.payload.safety
    });
  }
}

const summary = {
  contract: "pdf-editor.browser-resource-policy-benchmark-result",
  version: { major: 1, minor: 0 },
  generatedAt: startedAt,
  source: {
    fixture: "Tests/fixtures/browser_resource_policy_benchmark.json",
    sourceDigest: digest,
    contentLogged: false
  },
  execution: {
    runtime: "node-replay",
    networkAccessAttempted: false,
    rows: rows.length,
    boundedRows: rows.every((row) => row.render.maxConcurrentPages > 0 && row.batch.maxTotalBytes > 0 && row.batch.maxTotalPages > 0),
    noPartialOutputPromotion: rows.every((row) => row.recovery.partialOutputAllowed === false),
    ocrExplicitlyRequestedInBenchmark: true
  },
  rows
};
fs.mkdirSync(outputDirectory, { recursive: true });
fs.writeFileSync(outputPath, `${JSON.stringify(summary, null, 2)}\n`);
console.log(`browser resource policy benchmark: ${rows.length} cases written to ${path.relative(root, outputPath)}`);
