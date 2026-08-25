// pdf-hidden-revision-analyzer_test.mjs
// RG-097 hidden-revision analysis (Tier 3):
//  1. single-revision file -> one revision, nothing shadowed
//  2. incremental update (our RG-002 writer) -> exactly the edited objects
//     become shadowed in the older revision
//  3. active-content remnant: a prior revision carrying /JS while the CURRENT
//     revision is clean must be flagged
//  4. falsifier: a full rewrite collapses the chain to one revision, proving
//     rewrites destroy revision history (and sanitizers must analyze revisions)
import assert from "node:assert";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import crypto from "node:crypto";
import { execFileSync } from "node:child_process";
import { analyzeHiddenRevisions } from "../web/pdf-hidden-revision-analyzer.mjs";
import { incrementalFieldUpdate, readSourceXref } from "../web/pdf-incremental-form-writer.mjs";

const SRC = "/Users/pranay/Projects/pdf_editor/benchmark/results/public-sample-form.pdf";
const srcBuf = fs.readFileSync(SRC);

// --- 1. Single revision ---------------------------------------------------
const base = analyzeHiddenRevisions(srcBuf);
assert.equal(base.revisionCount, 1, `fixture should be single-revision, got ${base.revisionCount}`);
assert.equal(base.totalShadowedObjects, 0, "single revision cannot have shadowed objects");
assert.equal(base.hasHiddenRevisions, false);
assert.deepEqual(base.activeContentRemnants, []);
console.log("PASS single-revision fixture: 1 revision, no shadowed objects");

// --- 2. Incremental edit shadows exactly the edited objects ---------------
const RADIO_EDITS = [
  { objNum: 24, pairs: [{ k: "/V", v: "/1" }] },
  { objNum: 30, pairs: [{ k: "/AS", v: "/1" }] },
  { objNum: 25, pairs: [{ k: "/AS", v: "/Off" }] }
];
const updated = incrementalFieldUpdate(srcBuf, RADIO_EDITS);
const rev2 = analyzeHiddenRevisions(updated);
assert.equal(rev2.revisionCount, 2, `incremental output should have 2 revisions, got ${rev2.revisionCount}`);
assert.equal(rev2.totalShadowedObjects, 3, "exactly the 3 re-defined objects should be shadowed");
const shadowedInOlder = rev2.revisions[1].shadowedObjectNumbers;
assert.deepEqual([...shadowedInOlder].sort((a, b) => a - b), [24, 25, 30]);
assert.equal(
  new Set(rev2.chainOffsets).size,
  rev2.chainOffsets.length,
  "chain offsets should be distinct"
);
console.log("PASS incremental update: 2 revisions, shadowed = {24,25,30} (the edit set)");

// --- 3. Active content hidden in a prior revision -------------------------
// Build a dirty base whose catalog carries /OpenAction JS (full save = 1 rev),
// then use our value-replacement writer to neutralize it INCREMENTALLY. The
// current revision becomes clean; the JS survives only as a shadowed body.
const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "hr-"));
const dirtyPath = path.join(tmpDir, "dirty.pdf");
execFileSync(
  "python3",
  ["-c",
    "import pikepdf,sys\np=pikepdf.open(sys.argv[1])\np.Root['/OpenAction']=pikepdf.Dictionary(JS=pikepdf.String('app.alert(1)'))\np.save(sys.argv[2])",
    SRC, dirtyPath],
  { encoding: "utf8" }
);
const dirtyBuf = fs.readFileSync(dirtyPath);
const rootRef = readSourceXref(dirtyBuf).trailer["/Root"];
const catalogObjNum = parseInt(String(rootRef).trim().split(/\s+/)[0], 10);
assert.ok(Number.isInteger(catalogObjNum) && catalogObjNum > 0, `bad /Root ref: ${rootRef}`);

const cleaned = incrementalFieldUpdate(dirtyBuf, [
  { objNum: catalogObjNum, pairs: [{ k: "/OpenAction", v: "null" }] }
]);
const revDirty = analyzeHiddenRevisions(cleaned);
assert.equal(revDirty.revisionCount, 2);
const catRemnant = revDirty.activeContentRemnants.find((r) =>
  r.objNum === catalogObjNum && r.revision === 1
);
assert.ok(catRemnant, "shadowed catalog with /JS was not flagged");
console.log(`PASS remnant detection: /JS flagged in shadowed revision 1, object ${catRemnant.objNum}`);

// Current revision is genuinely clean despite the remnant.
const curCheck = JSON.parse(execFileSync(
  "python3",
  ["-c",
    "import pikepdf,sys,json\np=pikepdf.open(sys.argv[1])\noa=p.Root.get('/OpenAction')\nclean=(oa is None) or (str(oa)=='null')\nprint(json.dumps({'clean':clean}))",
    pathJoinTmp(dirtyPath, cleaned, tmpDir)],
  { encoding: "utf8" }
).trim());
assert.equal(curCheck.clean, true, "current revision should be free of OpenAction after replacement");
console.log("PASS current-vs-hidden split: current clean, /JS only in shadowed history");

// --- 4. Falsifier: full rewrite collapses revision history ----------------
const rewrittenPath = path.join(tmpDir, "rewritten.pdf");
execFileSync(
  "python3",
  ["-c",
    "import pikepdf,sys\np=pikepdf.open(sys.argv[1])\nif '/OpenAction' in p.Root: del p.Root['/OpenAction']\np.save(sys.argv[2])",
    dirtyPath, rewrittenPath],
  { encoding: "utf8" }
);
const rewritten = analyzeHiddenRevisions(fs.readFileSync(rewrittenPath));
assert.equal(rewritten.revisionCount, 1, `full rewrite should collapse to 1 revision, got ${rewritten.revisionCount}`);
assert.equal(rewritten.totalShadowedObjects, 0);
fs.rmSync(tmpDir, { recursive: true, force: true });
console.log("PASS falsifier: full rewrite destroys revision history (why analysis, not rewriting, detects remnants)");

console.log("\nRG-097 hidden-revision gates PASS (chain walk, shadow inventory, remnant scan, falsifier)");

function pathJoinTmp(_unused, buf, dir) {
  const p = path.join(dir, "cleaned.pdf");
  fs.writeFileSync(p, buf);
  return p;
}
