import assert from "node:assert/strict";
import {
  compareNormalizedContractBundles,
  normalizeContractBundle,
  PARITY_CONTRACT,
  representationFacts
} from "../web/pdf-contract-parity.mjs";

const sourceDigest = "a".repeat(64);
const baseBundle = () => ({
  document: {
    payload: {
      source: { sha256: sourceDigest, fileName: "fixture.pdf", byteCount: 100 },
      pages: [{ pageIndex: 0, bounds: { x: 0, y: 0, width: 612, height: 792 }, rotation: 0, characterCount: 20, annotationCount: 0, hasSelectableText: true }],
      fields: [{ pageIndex: 0, name: "name", kind: "text", bounds: { x: 10, y: 20, width: 100, height: 20 }, value: "", choices: [] }],
      candidates: [{
        pageIndex: 0,
        kind: "vectorRegion",
        suggestedFieldType: "text",
        entryMode: "singleText",
        groupMemberCount: 1,
        bounds: { x: 10, y: 20, width: 100, height: 20 },
        coordinate: { pageIndex: 0, rect: { x: 10, y: 20, width: 100, height: 20 }, coordinateSpace: { unit: "points", origin: "lowerLeft", pageBox: "crop", rotationDegrees: 0 } },
        evidenceItems: [{ kind: "vectorRectangle" }],
        labelText: "Name"
      }],
      links: [],
      outlines: [],
      attachments: [],
      accessibility: { hasTaggedContent: false, hasReadingOrder: false },
      security: { isEncrypted: false, isLocked: false, requiresPassword: false }
    }
  },
  coordinates: { pages: [{ pageIndex: 0, region: { pageIndex: 0, rect: { x: 0, y: 0, width: 612, height: 792 }, coordinateSpace: { unit: "points", origin: "lowerLeft", pageBox: "crop", rotationDegrees: 0 } } }] },
  editSession: { operations: [] },
  validation: { status: "passed", sourceUnchanged: true, outputReopenable: true, checks: [{ kind: "outputReopen", status: "passed" }] }
});

assert.deepEqual(compareNormalizedContractBundles(baseBundle(), baseBundle()), []);
assert.equal(PARITY_CONTRACT.name, "pdf-editor.native-web-semantic-parity");
assert.equal(PARITY_CONTRACT.version.minor, 1);
assert.equal(PARITY_CONTRACT.normalizationPolicy.outputDigestComparison, "never-semantic-equality");
assert.equal(normalizeContractBundle(baseBundle()).document.source.sha256, sourceDigest);

const coordinateMutation = baseBundle();
coordinateMutation.document.payload.pages[0].bounds.width = 613;
assert.ok(compareNormalizedContractBundles(baseBundle(), coordinateMutation).some((mismatch) => mismatch.kind === "page.geometry-or-text"));

const fieldMutation = baseBundle();
fieldMutation.document.payload.fields[0].kind = "checkbox";
assert.ok(compareNormalizedContractBundles(baseBundle(), fieldMutation).some((mismatch) => mismatch.kind === "native-fields"));

const evidenceMutation = baseBundle();
evidenceMutation.document.payload.candidates[0].evidenceItems[0].kind = "whitespace";
assert.ok(compareNormalizedContractBundles(baseBundle(), evidenceMutation).some((mismatch) => mismatch.kind === "candidate-semantic-set"));

const validationMutation = baseBundle();
validationMutation.validation.status = "unknown";
assert.ok(compareNormalizedContractBundles(baseBundle(), validationMutation).some((mismatch) => mismatch.kind === "validation.status"));

const sourceMutation = baseBundle();
sourceMutation.document.payload.source.sha256 = "b".repeat(64);
assert.ok(compareNormalizedContractBundles(baseBundle(), sourceMutation).some((mismatch) => mismatch.kind === "source.digest"));

const representationMutation = baseBundle();
representationMutation.document.header = {
  provider: { id: "different", version: "different", platform: "different" },
  generatedAt: "different",
  randomIDs: ["different"]
};
representationMutation.document.payload.fields[0].id = "field-different";
representationMutation.document.payload.candidates[0].id = "candidate-different";
representationMutation.document.payload.candidates[0].evidenceItems[0].id = "evidence-different";
representationMutation.validation.checks[0].id = "check-different";
representationMutation.validation.outputDigest = "digest-different";
representationMutation.validation.messages = ["provider-specific prose changed"];
assert.deepEqual(compareNormalizedContractBundles(baseBundle(), representationMutation), []);
assert.deepEqual(representationFacts(representationMutation), {
  providerIdentityPresent: true,
  providerVersionPresent: true,
  generatedAtPresent: true,
  outputDigestPresent: true,
  outputDigestCompared: false
});

console.log("normalized parity comparator: 10 checks passed");
