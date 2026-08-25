import assert from "node:assert/strict";
import { compareCandidateBundles } from "../web/candidate-parity.mjs";

const baseCandidate = {
  id: "provider-id",
  pageIndex: 0,
  bounds: { x: 10, y: 20, width: 100, height: 20 },
  coordinate: {
    pageIndex: 0,
    rect: { x: 10, y: 20, width: 100, height: 20 },
    coordinateSpace: { unit: "points", origin: "lowerLeft", pageBox: "crop", rotationDegrees: 0 }
  },
  kind: "vectorRegion",
  suggestedFieldType: "text",
  entryMode: "singleText",
  groupMemberCount: 1,
  status: "suggested",
  labelText: "Private label omitted from report",
  score: 0.9,
  evidenceItems: [{ id: "evidence-id", kind: "vectorRectangle", origin: "geometryExtraction", text: "private evidence" }]
};

function bundle(candidate) {
  return {
    sourceDigest: "digest",
    status: "inspected",
    document: { payload: { source: { sha256: "digest" }, candidates: [candidate] } }
  };
}

const baseline = compareCandidateBundles(bundle(baseCandidate), bundle({ ...baseCandidate, id: "other-id" }), { sourceDigest: "digest" });
assert.equal(baseline.metrics.matchedCount, 1);
assert.equal(baseline.metrics.equivalentPairCount, 1, "provider IDs must not affect semantic candidate parity");

const timestampAndProseMutation = compareCandidateBundles(
  bundle(baseCandidate),
  bundle({ ...baseCandidate, id: "new-id", labelText: "different prose", score: 0.1, evidenceItems: [{ ...baseCandidate.evidenceItems[0], id: "new-evidence", text: "new prose" }] }),
  { sourceDigest: "digest" }
);
assert.equal(timestampAndProseMutation.metrics.equivalentPairCount, 1, "representation mutations must remain equivalent");

const kindMutation = compareCandidateBundles(bundle(baseCandidate), bundle({ ...baseCandidate, kind: "textAnchored" }), { sourceDigest: "digest" });
assert.equal(kindMutation.matchedWithDifferencesCount, 1);
assert.equal(kindMutation.mismatchCounts.candidateKind, 1);

const evidenceMutation = compareCandidateBundles(
  bundle(baseCandidate),
  bundle({ ...baseCandidate, evidenceItems: [{ ...baseCandidate.evidenceItems[0], kind: "textLabel" }] }),
  { sourceDigest: "digest" }
);
assert.equal(evidenceMutation.mismatchCounts.evidenceKinds, 1);

const coordinateMutation = compareCandidateBundles(
  bundle(baseCandidate),
  bundle({ ...baseCandidate, bounds: { ...baseCandidate.bounds, x: 35 } }),
  { sourceDigest: "digest" }
);
assert.equal(coordinateMutation.metrics.matchedCount, 0, "large coordinate drift must break pairing");
assert.equal(coordinateMutation.metrics.nativeOnlyCount, 1);
assert.equal(coordinateMutation.metrics.browserOnlyCount, 1);

console.log("candidate parity mutation checks: 5 passed");
