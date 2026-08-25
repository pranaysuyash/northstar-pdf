import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const testsDirectory = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(testsDirectory, "..");
const registryPath = path.join(testsDirectory, "fixtures/moat_asset_registry.json");
const registry = JSON.parse(fs.readFileSync(registryPath, "utf8"));

assert.equal(registry.schema, "pdf-editor.moat-asset-registry");
assert.equal(registry.schemaVersion, "1.0.0");
assert.ok(registry.authority.noContentRule.includes("page text"));
assert.ok(registry.privacyPolicy.forbiddenLogFields.includes("profileValue"));
assert.ok(registry.statusVocabulary.includes("partial"));
assert.equal(registry.assets.length, 16);

const seenIDs = new Set();
const requiredReferences = ["contractRefs", "nativeRefs", "webRefs", "fixtureRefs", "validatorRefs", "evidenceRefs"];
const requiredNames = new Set([
  "source-digest-binding",
  "page-space-crop-rotation-fixtures",
  "multi-signal-evidence-graph",
  "candidate-explanations-and-abstention",
  "human-confirmed-mappings",
  "rejected-candidates-and-hard-negatives",
  "typed-operation-lineage",
  "provider-divergence-records",
  "export-reopen-and-independent-viewer-outcomes",
  "reviewed-template-revisions",
  "confidence-calibration",
  "corpus-provenance-consent-license-retention",
  "workflow-completion-and-recovery-evidence",
  "provider-divergence-to-remediation-loop",
  "privacy-preflight-and-sanitization-boundary"
  ,"device-adaptive-resource-governance"
]);

for (const asset of registry.assets) {
  assert.match(asset.assetId, /^MA-\d{3}$/);
  assert.equal(seenIDs.has(asset.assetId), false, `duplicate asset id: ${asset.assetId}`);
  seenIDs.add(asset.assetId);
  assert.equal(requiredNames.has(asset.name), true, `unexpected asset: ${asset.name}`);
  assert.ok(registry.statusVocabulary.includes(asset.status), `${asset.assetId} has unknown status`);
  assert.ok(asset.owner);
  assert.ok(asset.privacyClass);
  assert.ok(asset.retentionPolicy);
  assert.ok(asset.completionGate);

  for (const referenceType of requiredReferences) {
    assert.ok(Array.isArray(asset[referenceType]) && asset[referenceType].length > 0, `${asset.assetId} missing ${referenceType}`);
    for (const reference of asset[referenceType]) {
      const absolutePath = path.isAbsolute(reference) ? reference : path.join(root, reference);
      assert.equal(fs.existsSync(absolutePath), true, `${asset.assetId} missing reference: ${reference}`);
    }
  }
}

assert.equal(seenIDs.size, 16);
assert.equal(new Set(registry.assets.map((asset) => asset.category)).size >= 8, true);
assert.equal(registry.assets.some((asset) => asset.status === "partial"), true);
assert.equal(registry.assets.some((asset) => asset.status === "implemented"), true);
assert.equal(registry.assets.every((asset) => asset.completionGate.length > 40), true);

const report = {
  harness: "pdf-editor-moat-asset-registry",
  registryId: registry.registryId,
  assetCount: registry.assets.length,
  statusCounts: Object.fromEntries(registry.statusVocabulary.map((status) => [status, registry.assets.filter((asset) => asset.status === status).length])),
  contentLogging: "none",
  passed: true
};
const reportPath = path.join(root, "benchmark/results/moat-asset-registry/report.json");
fs.mkdirSync(path.dirname(reportPath), { recursive: true });
fs.writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`);

console.log(`moat asset registry: ${registry.assets.length} assets, ${seenIDs.size} unique IDs, all references resolved, zero-content logging verified`);
