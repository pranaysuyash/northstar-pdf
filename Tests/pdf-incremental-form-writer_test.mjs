import assert from "node:assert";
import fs from "node:fs";
import crypto from "node:crypto";
import { execFileSync, spawnSync } from "node:child_process";
import { incrementalFieldUpdate } from "../web/pdf-incremental-form-writer.mjs";
import { pdfPython } from "./pdf-python.mjs";

function spawnSyncSafe(cmd, args) {
  const r = spawnSync(cmd, args, { encoding: "utf8" });
  return { stdout: r.stdout || "", stderr: r.stderr || "" };
}

const SRC = "/Users/pranay/Projects/pdf_editor/benchmark/results/public-sample-form.pdf";
const TMP = "/Users/pranay/Projects/pdf_editor/tmp";
fs.mkdirSync(TMP, { recursive: true });
const incPath = `${TMP}/inc-update-out.pdf`;
const rewPath = `${TMP}/full-rewrite-out.pdf`;

const srcBuf = fs.readFileSync(SRC);
const srcDigest = crypto.createHash("sha256").update(srcBuf).digest("hex");

// Set radio "contact" to option /1: parent /V, selected kid /AS, other /Off.
const out = incrementalFieldUpdate(srcBuf, [
  { objNum: 24, pairs: [{ k: "/V", v: "/1" }] },
  { objNum: 30, pairs: [{ k: "/AS", v: "/1" }] },
  { objNum: 25, pairs: [{ k: "/AS", v: "/Off" }] },
]);
fs.writeFileSync(incPath, out);

// 1. Prefix invariance: original bytes are an unchanged prefix of the output.
assert.ok(out.length > srcBuf.length, "incremental output must be longer");
assert.ok(out.subarray(0, srcBuf.length).equals(srcBuf), "RG-017 violation: original prefix bytes changed");
const outPrefixDigest = crypto.createHash("sha256").update(out.subarray(0, srcBuf.length)).digest("hex");
assert.equal(outPrefixDigest, srcDigest, "RG-017 violation: prefix digest changed");
console.log("PASS prefix-invariance: original bytes byte-identical, digest preserved");

// 2. Structural validity via independent qpdf check (not the writer's own claim).
const checkRes = spawnSyncSafe("qpdf", ["--check", incPath]);
const check = checkRes.stdout + checkRes.stderr;
assert.ok(/No syntax or stream encoding errors/.test(check), `qpdf reported errors:\n${check}`);
assert.ok(!/ERROR/.test(check), `qpdf ERROR in output:\n${check}`);
console.log("PASS qpdf --check: independent structural validity");

// 3. Independent re-read: the radio choice survives an independent open.
// contact is a NESTED kid of applicant, so walk /Kids recursively.
const py = `
import pikepdf, sys, json
pdf = pikepdf.open(sys.argv[1])
acro = pdf.Root.get('/AcroForm')
res = {'V': None, 'kids': []}
def walk(f):
    t = f.get('/T')
    if str(t) == 'contact':
        res['V'] = str(f.get('/V'))
        for k in f.get('/Kids'):
            res['kids'].append(str(k.get('/AS')))
    for k in (f.get('/Kids') or []):
        if '/T' in k or '/Kids' in k:
            walk(k)
for f in acro.get('/Fields'):
    walk(f)
print(json.dumps(res))
`;
const readback = JSON.parse(execFileSync(pdfPython, ["-c", py, incPath], { encoding: "utf8" }).trim());
assert.equal(readback.V, "/1", `radio parent /V not preserved (got ${readback.V})`);
assert.deepEqual(readback.kids.sort(), ["/1", "/Off"].sort(), `kid /AS not preserved: ${readback.kids}`);
console.log("PASS independent re-read: contact=/1, kid AS=[/1,/Off]");

// 4. Falsifier: a full rewrite (pdf-lib/PDFKit-style) MUST break the prefix
//    invariant. If it did NOT, our RG-017 claim would be falsified.
execFileSync(pdfPython, ["-c", "import pikepdf,sys; pikepdf.open(sys.argv[1]).save(sys.argv[2])", SRC, rewPath]);
const rewBuf = fs.readFileSync(rewPath);
const samePrefix = rewBuf.length >= srcBuf.length && rewBuf.subarray(0, srcBuf.length).equals(srcBuf);
assert.ok(!samePrefix, "FALSIFIER FAILED: full rewrite kept original prefix (would falsify RG-017)");
console.log("PASS falsifier: full rewrite changes original prefix (proves incremental update is required)");

console.log("\nALL RG-002 incremental-writer gates PASS");
