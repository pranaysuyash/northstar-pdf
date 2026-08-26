// pdf-sanitize-audited_test.mjs
// RG-097 integration (Tier 3): audited sanitization must refuse to destroy
// hidden-revision evidence by default, allow it under explicit acknowledgment,
// and prove the output's revision chain actually collapsed.
import assert from "node:assert";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { sanitizePdfAudited, SanitizeAuditError } from "../web/pdf-sanitize-audited.mjs";
import { incrementalFieldUpdate, readSourceXref } from "../web/pdf-incremental-form-writer.mjs";
import { pdfPython } from "./pdf-python.mjs";

const SRC = "/Users/pranay/Projects/pdf_editor/benchmark/results/public-sample-form.pdf";
const srcBuf = fs.readFileSync(SRC);

// --- Clean source: sanitize passes without ceremony ------------------------
const cleanRun = sanitizePdfAudited(srcBuf, {});
assert.equal(cleanRun.before.revisionCount, 1);
assert.ok(cleanRun.bytes.length > 0);
console.log("PASS clean source sanitizes with default refuse policy");

// --- Dirty source: JS in a shadowed revision ------------------------------
const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "sa-"));
const dirtyPath = path.join(tmpDir, "dirty.pdf");
execFileSync(
  pdfPython,
  ["-c",
    "import pikepdf,sys\np=pikepdf.open(sys.argv[1])\np.Root['/OpenAction']=pikepdf.Dictionary(JS=pikepdf.String('app.alert(1)'))\np.save(sys.argv[2])",
    SRC, dirtyPath],
  { encoding: "utf8" }
);
const dirtyBuf = fs.readFileSync(dirtyPath);
const catalogObjNum = parseInt(String(readSourceXref(dirtyBuf).trailer["/Root"]).trim().split(/\s+/)[0], 10);

// Incrementally neutralize: current revision clean, /JS remains as a remnant.
const cleanedCurrent = incrementalFieldUpdate(dirtyBuf, [
  { objNum: catalogObjNum, pairs: [{ k: "/OpenAction", v: "null" }] }]
);

// Default policy must REFUSE.
assert.throws(
  () => sanitizePdfAudited(cleanedCurrent, {}),
  (err) => err instanceof SanitizeAuditError && err.remnants.length > 0,
  "default policy must refuse when remnants exist"
);
console.log("PASS refuse-by-default when shadowed /JS remnants exist");

// Acknowledged path proceeds and collapses history.
const ack = sanitizePdfAudited(cleanedCurrent, { remnantPolicy: "acknowledge" });
assert.equal(ack.policy, "acknowledge");
assert.equal(ack.remnantsAcknowledgedDestroyed >= 1, true);
assert.equal(ack.after.revisionCount, 1, `output should be single-revision, got ${ack.after.revisionCount}`);
assert.equal(ack.after.totalShadowedObjects, 0);
assert.equal(ack.historyCollapsed, true);
assert.deepEqual(ack.after.activeContentRemnants, [], "collapsed output must carry zero remnants");
fs.rmSync(tmpDir, { recursive: true, force: true });
console.log("PASS acknowledged sanitize destroys exactly the flagged evidence and collapses the chain");

console.log("\nRG-097 audited-sanitization integration gates PASS");
