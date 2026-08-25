import assert from "node:assert/strict";
import fs from "node:fs";
import { fuseCandidateEvidence } from "../web/pdf-evidence-fusion.mjs";

const fixture = JSON.parse(fs.readFileSync(new URL("./fixtures/evidence_fusion_cases.json", import.meta.url), "utf8"));
for (const testCase of fixture.cases) {
  const result = fuseCandidateEvidence({ signals: testCase.signals });
  assert.equal(result.state, testCase.expected.state, testCase.id);
  assert.deepEqual(result.reasonCodes, [...testCase.expected.reasonCodes].sort(), testCase.id);
  assert.deepEqual(result.evidenceIDs, testCase.signals.map((signal) => signal.id).sort(), testCase.id);
  assert.ok(result.score >= 0 && result.score <= 1, testCase.id);
}
console.log(`evidence fusion: ${fixture.cases.length} deterministic cases passed`);
