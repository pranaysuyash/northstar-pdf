import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  negotiateCapability,
  validateProviderManifest,
  validateRegistry
} from "../web/provider-capability-contract.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const registry = JSON.parse(fs.readFileSync(path.join(root, "Tests/fixtures/provider_capability_registry.json"), "utf8"));

validateRegistry(registry);
assert.equal(registry.providers.length, 4);

const readerDecision = negotiateCapability(registry, {
  contract: "pdf-editor.provider-capability-request",
  version: { major: 1, minor: 0 },
  capability: "reader.render",
  operationKinds: ["inspect"],
  source: { byteCount: 1000, pageCount: 2, isEncrypted: false, isScanned: false },
  policy: { localOnly: true, minimumState: "enabled", allowExperimental: false, preferredProviderIDs: [] }
});
assert.equal(readerDecision.decision, "selected");
assert.equal(readerDecision.providerID, "browser-pdfjs-pdflib");
assert.equal(readerDecision.measurementID, "measurement-browser-reader-001");

const partialOcrDecision = negotiateCapability(registry, {
  contract: "pdf-editor.provider-capability-request",
  version: { major: 1, minor: 0 },
  capability: "ocr.textBounds",
  operationKinds: ["inspect", "candidateEvidence"],
  source: { byteCount: 1000, pageCount: 2, isEncrypted: false, isScanned: true },
  policy: { localOnly: true, minimumState: "enabled", allowExperimental: false, preferredProviderIDs: [] }
});
assert.equal(partialOcrDecision.decision, "abstained");
assert.ok(partialOcrDecision.reasonCodes.includes("capabilityBelowMinimumState"));

const experimentalOcrDecision = negotiateCapability(registry, {
  contract: "pdf-editor.provider-capability-request",
  version: { major: 1, minor: 0 },
  capability: "ocr.textBounds",
  operationKinds: ["inspect"],
  source: { byteCount: 1000, pageCount: 2, isEncrypted: false, isScanned: true },
  policy: { localOnly: true, minimumState: "measuredPartial", allowExperimental: true, preferredProviderIDs: ["native-vision"] }
});
assert.equal(experimentalOcrDecision.decision, "selected");
assert.equal(experimentalOcrDecision.providerID, "native-vision");

const staleSourceDecision = negotiateCapability(registry, {
  contract: "pdf-editor.provider-capability-request",
  version: { major: 1, minor: 0 },
  capability: "reader.render",
  operationKinds: ["inspect"],
  source: { byteCount: 100000001, pageCount: 2, isEncrypted: false, isScanned: false },
  policy: { localOnly: true, minimumState: "enabled", allowExperimental: false, preferredProviderIDs: [] }
});
assert.equal(staleSourceDecision.decision, "abstained");
assert.ok(staleSourceDecision.reasonCodes.includes("sourceOutsideProviderLimits"));

const revoked = registry.providers.find((provider) => provider.providerID === "companion-mupdf");
assert.throws(() => validateProviderManifest({ ...revoked, artifactDigest: "bad" }), /64-character hex digest/);
const invalidEnabled = structuredClone(registry.providers[0]);
invalidEnabled.capabilities[0].measurementIDs = [];
assert.throws(() => validateProviderManifest(invalidEnabled), /enabled capability requires a measurement reference/);
const invalidBinding = structuredClone(registry.providers[0]);
invalidBinding.measurements[0].artifactDigest = "9999999999999999999999999999999999999999999999999999999999999999";
assert.throws(() => validateProviderManifest(invalidBinding), /mismatched measurement binding/);
const duplicatePreferred = { ...registry, providers: registry.providers.slice(0, 1) };
assert.throws(() => negotiateCapability(duplicatePreferred, {
  contract: "pdf-editor.provider-capability-request",
  version: { major: 1, minor: 0 },
  capability: "reader.render",
  operationKinds: ["inspect"],
  source: { byteCount: 1000, pageCount: 1, isEncrypted: false, isScanned: false },
  policy: { localOnly: true, minimumState: "enabled", allowExperimental: false, preferredProviderIDs: ["browser-pdfjs-pdflib", "browser-pdfjs-pdflib"] }
}), /duplicate browser-pdfjs-pdflib/);
const duplicateMeasurement = structuredClone(registry.providers[0]);
duplicateMeasurement.measurements.push(structuredClone(duplicateMeasurement.measurements[0]));
assert.throws(() => validateProviderManifest(duplicateMeasurement), /duplicate measurement/);

console.log("provider capability registry and negotiation: 12 checks passed");
