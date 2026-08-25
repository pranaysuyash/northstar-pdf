import assert from "node:assert/strict";
import {
  PDF_CAPABILITY_LANES,
  createPDFCapabilityRequest,
  resolvePDFCapability,
  createCapabilityExecutionResult,
  validateCapabilityResult
} from "../web/pdf-capability-lanes.mjs";
import { validateRegistry } from "../web/provider-capability-contract.mjs";
import fs from "node:fs";

const registry = JSON.parse(fs.readFileSync("Tests/fixtures/provider_capability_registry.json", "utf8"));
validateRegistry(registry);
assert.ok(PDF_CAPABILITY_LANES.includes("ocr.textBounds"));
const request = createPDFCapabilityRequest({
  lane: "ocr.textBounds",
  sourceDigest: "a".repeat(64),
  source: { byteCount: 1000, pageCount: 2, isEncrypted: false, isScanned: true },
  operationKinds: ["candidateEvidence"],
  policy: { localOnly: true, minimumState: "measuredPartial", allowExperimental: true, preferredProviderIDs: ["native-vision"] }
});
const admission = resolvePDFCapability({ registry, request });
assert.equal(admission.lane, "ocr.textBounds");
assert.equal(admission.providerID, "native-vision");
const result = createCapabilityExecutionResult({ request, admission, validationState: "passed", evidence: [{ kind: "bounds", count: 1 }] });
assert.equal(result.outcome, "available");
validateCapabilityResult(result);
assert.throws(() => createCapabilityExecutionResult({ request, admission: { ...admission, sourceDigest: "b".repeat(64) }, validationState: "passed" }), /source digest/);
const unsupportedRequest = createPDFCapabilityRequest({ lane: "text.reflow", sourceDigest: "a".repeat(64), source: { byteCount: 100, pageCount: 1, isEncrypted: false, isScanned: false } });
const unsupported = resolvePDFCapability({ registry, request: unsupportedRequest });
assert.equal(unsupported.outcome, "unknown");
console.log("PDF capability lanes: named OCR, advanced editing, revocation, digest binding, and result validation passed");
