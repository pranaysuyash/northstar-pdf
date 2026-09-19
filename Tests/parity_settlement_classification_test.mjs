import assert from "node:assert/strict";
import { classifyFixture, summarize } from "../tools/parity-settlement-classify.mjs";

// Synthetic fixtures covering every classification class (S1: passes on the
// correct implementation; the classes are mutually exclusive and total).

const base = {
  parityCaseID: "PARITY-000",
  sourcePath: "benchmark/results/x.pdf",
  nativeStatus: "inspected",
  webStatus: "inspected",
  normalization: {
    semanticProjectionDigest: {
      native: "aaa",
      browser: "aaa",
      exactDigestEquality: false,
      comparatorEquivalent: true,
    },
  },
  mismatches: [],
  unexpectedMismatches: [],
  expectedFailure: false,
};

// exact-agree: zero mismatches, comparator equivalence
assert.equal(classifyFixture(base).class, "exact-agree");

// exact-agree via exact digest equality
assert.equal(
  classifyFixture({ ...base, normalization: { semanticProjectionDigest: { native: "a", browser: "a", exactDigestEquality: true, comparatorEquivalent: false } } }).class,
  "exact-agree"
);

// classified-variance: mismatches present but all allowed (unexpected empty)
assert.deepEqual(
  classifyFixture({
    ...base,
    mismatches: [{ kind: "candidate.count" }, { kind: "coordinates" }],
  }),
  { class: "classified-variance", reason: "2 mismatch(es), all within the fixture's allowed/kinds classification", kinds: ["candidate.count", "coordinates"] }
);

// dispute: any unexpected mismatch dominates
const dispute = classifyFixture({
  ...base,
  mismatches: [{ kind: "candidate.count" }],
  unexpectedMismatches: [{ kind: "page.geometry-or-text" }],
});
assert.equal(dispute.class, "dispute");
assert.deepEqual(dispute.kinds, ["page.geometry-or-text"]);

// malformed-agree: both lanes failed, digests match
assert.equal(
  classifyFixture({
    ...base,
    nativeStatus: "inspectionFailed",
    webStatus: "inspectionFailed",
    normalization: { semanticProjectionDigest: { native: "a", browser: "a", exactDigestEquality: true, comparatorEquivalent: true } },
  }).class,
  "malformed-agree"
);

// unclassified: both failed, digests differ
assert.equal(
  classifyFixture({
    ...base,
    nativeStatus: "inspectionFailed",
    webStatus: "inspectionFailed",
    normalization: { semanticProjectionDigest: { native: "a", browser: "b", exactDigestEquality: false, comparatorEquivalent: false } },
  }).class,
  "unclassified"
);

// unclassified: zero mismatches but neither predicate holds
assert.equal(
  classifyFixture({
    ...base,
    normalization: { semanticProjectionDigest: { native: "a", browser: "b", exactDigestEquality: false, comparatorEquivalent: false } },
  }).class,
  "unclassified"
);

// never-run: non-terminal statuses
assert.equal(classifyFixture({ ...base, nativeStatus: "pending" }).class, "never-run");
assert.equal(classifyFixture({ ...base, webStatus: null }).class, "never-run");

// summarize: empty dispute set → reducer NOT recommended (the measured reality)
const noDispute = summarize([base, { ...base, parityCaseID: "PARITY-002" }]);
assert.equal(noDispute.disputeCount, 0);
assert.equal(noDispute.verdict.reducerBuildRecommended, false);
assert.ok(noDispute.verdict.statement.includes("EMPTY"));

// summarize: disputes present → reducer recommended, residual = dispute set
const withDispute = summarize([
  base,
  { ...base, parityCaseID: "PARITY-002", unexpectedMismatches: [{ kind: "field.type" }] },
]);
assert.equal(withDispute.disputeCount, 1);
assert.equal(withDispute.verdict.reducerBuildRecommended, true);

// never-run counted distinctly
const withNeverRun = summarize([{ ...base, nativeStatus: "queued" }]);
assert.equal(withNeverRun.neverRunCount, 1);

console.log("parity_settlement_classification_test: all assertions passed (S1)");
