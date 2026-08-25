import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  chooseBrowserResourcePolicy,
  createResourceCheckpoint,
  normalizeResourceDocument,
  runAdaptiveBatches,
  summarizeResourceEvent,
  validateBrowserResourcePolicy,
  validateResourceCheckpoint
} from "../web/browser-resource-policy.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const fixture = JSON.parse(fs.readFileSync(path.join(root, "Tests/fixtures/browser_resource_policy_benchmark.json"), "utf8"));
const digest = "a".repeat(64);
let checks = 0;
const check = (condition, message) => { assert.ok(condition, message); checks += 1; };

for (const device of fixture.deviceProfiles) {
  for (const document of fixture.documentClasses) {
    const policy = chooseBrowserResourcePolicy({
      environment: device,
      document: normalizeResourceDocument(document),
      request: { ocrRequested: false, batchRequested: false },
      sourceDigest: digest,
      provider: { providerID: "test-browser", runtimeKind: "browser" }
    });
    validateBrowserResourcePolicy(policy, { expectedSourceDigest: digest });
    check(policy.payload.budgets.render.maxConcurrentPages >= 1, `${device.id}/${document.id} render concurrency`);
    check(policy.payload.budgets.batch.maxTotalBytes > 0, `${device.id}/${document.id} byte budget`);
    check(policy.payload.budgets.batch.maxTotalPages > 0, `${device.id}/${document.id} page budget`);
    check(policy.payload.budgets.safety === undefined, "safety stays at top-level payload contract");
    check(policy.payload.safety.contentLogged === false, `${device.id}/${document.id} zero-content policy`);
    check(policy.payload.safety.networkAccessAttempted === false, `${device.id}/${document.id} no network policy`);
    check(policy.payload.budgets.recovery.partialOutputAllowed === false, `${device.id}/${document.id} no partial promotion`);
    if (document.id === "tiny-text-form") check(policy.payload.budgets.ocr.state === "deferred", "OCR must be explicit");
    if (document.id === "large-hybrid-40-pages") check(policy.payload.budgets.recovery.checkpointRequired, "large work checkpoints");
    if (device.id === "unknown-signals") check(policy.payload.decisions.some((item) => item.reasonCode === "unknownMemoryPressure"), "unknown memory is visible");
  }
}

const ocrPolicy = chooseBrowserResourcePolicy({
  environment: fixture.deviceProfiles[2],
  document: fixture.documentClasses[2],
  request: { ocrRequested: true, batchRequested: true },
  sourceDigest: digest
});
check(ocrPolicy.payload.budgets.ocr.enabled, "explicit OCR is admitted as a bounded operation");
check(ocrPolicy.payload.budgets.ocr.requiresUserConfirmation, "OCR requires review confirmation");
check(ocrPolicy.payload.budgets.batch.enabled, "explicit batch is admitted as bounded work");

assert.throws(() => validateBrowserResourcePolicy(ocrPolicy, { expectedSourceDigest: "b".repeat(64) }), /digest mismatch/); checks += 1;
const unknownState = structuredClone(ocrPolicy); unknownState.payload.decisions[0].state = "unbounded";
assert.throws(() => validateBrowserResourcePolicy(unknownState), /decision state is unknown/); checks += 1;
const unsafe = structuredClone(ocrPolicy); unsafe.payload.safety.contentLogged = true;
assert.throws(() => validateBrowserResourcePolicy(unsafe), /safety invariant/); checks += 1;
const checkpoint = createResourceCheckpoint({ sourceDigest: digest, operationID: "op-resource-1", batchIndex: 1, completedCount: 5 });
check(validateResourceCheckpoint(checkpoint, { sourceDigest: digest, operationID: "op-resource-1" }), "checkpoint validates");
assert.throws(() => validateResourceCheckpoint(checkpoint, { sourceDigest: "c".repeat(64), operationID: "op-resource-1" }), /stale/); checks += 1;
assert.throws(() => validateResourceCheckpoint(checkpoint, { sourceDigest: digest, operationID: "op-resource-2" }), /operation mismatch/); checks += 1;
check(summarizeResourceEvent({ eventType: "ocr-finished", sourceDigest: digest, pageCount: 2, elapsedMs: 3, text: "must not be logged" }).contentLogged === false, "event summary is value-free");

const processed = [];
const saved = [];
const controller = new AbortController();
const cancelledRun = await runAdaptiveBatches({
  items: [1, 2, 3],
  policy: chooseBrowserResourcePolicy({ environment: fixture.deviceProfiles[0], document: fixture.documentClasses[3], request: { batchRequested: true }, sourceDigest: digest }),
  sourceDigest: digest,
  operationID: "op-cancel-1",
  signal: controller.signal,
  processItem: async (item) => { processed.push(item); if (item === 1) controller.abort(); return item; },
  saveCheckpoint: async (value) => saved.push(value)
});
check(cancelledRun.status === "cancelled", "cancellation stops adaptive work");
check(cancelledRun.partialOutputPromoted === false, "cancellation cannot promote partial output");
check(saved.length === 1 && saved[0].partialOutputPromoted === false, "cancellation preserves only a non-promoted checkpoint");

const recoveryPolicy = chooseBrowserResourcePolicy({ environment: fixture.deviceProfiles[3], document: fixture.documentClasses[3], request: { batchRequested: true }, sourceDigest: digest });
const recovery = await runAdaptiveBatches({
  items: ["a", "b", "c"],
  policy: recoveryPolicy,
  sourceDigest: digest,
  operationID: "op-recover-1",
  startCheckpoint: createResourceCheckpoint({ sourceDigest: digest, operationID: "op-recover-1", completedCount: 1 }),
  processItem: async (item) => item,
  saveCheckpoint: async (value) => saved.push(value)
});
check(recovery.recovered, "matching digest resumes from checkpoint");
check(recovery.completedCount === 3, "recovery reports total completed count");
check(processed.join("") === "1", "cancelled run did not process beyond the abort boundary");

console.log(`browser resource policy contract: ${checks} checks passed across ${fixture.deviceProfiles.length} device profiles and ${fixture.documentClasses.length} document classes`);
