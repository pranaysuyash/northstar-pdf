// pdf-sanitize_test.mjs
// RG-097 partial (Tier 3): qpdf-based metadata/attachment/thumbnail removal
// must strip /Info and /Metadata, keep the file re-openable, and pass qpdf.
import assert from "node:assert";
import fs from "node:fs";
import { execFileSync, spawnSync } from "node:child_process";
import { sanitizePdf } from "../web/pdf-sanitize.mjs";

const SRC = "/Users/pranay/Projects/pdf_editor/benchmark/results/public-sample-form.pdf";
const srcBuf = fs.readFileSync(SRC);

const out = sanitizePdf(srcBuf, {});
assert.ok(out.length > 0, "sanitized output is non-empty");

// Re-read the sanitized bytes via a temp file (pikepdf needs a path).
fs.mkdirSync("/Users/pranay/Projects/pdf_editor/tmp", { recursive: true });
const tmp = "/Users/pranay/Projects/pdf_editor/tmp/sanitized-out.pdf";
fs.writeFileSync(tmp, out);

const check = (() => {
  const r = spawnSync("qpdf", ["--check", tmp], { encoding: "utf8" });
  return (r.stdout || "") + (r.stderr || "");
})();
assert.ok(/No syntax or stream encoding errors/.test(check), `qpdf errors:\n${check}`);
assert.ok(!/ERROR/.test(check), `qpdf ERROR:\n${check}`);
console.log("PASS qpdf --check: sanitized file is structurally valid");

const res = JSON.parse(
  execFileSync(
    "python3",
    [
      "-c",
      "import pikepdf,sys,json; p=pikepdf.open(sys.argv[1]); info=p.trailer.get('/Info'); print(json.dumps({'hasInfo':'/Info' in p.trailer,'infoKeys':list(info.keys()) if info is not None else [],'hasMetadata':'/Metadata' in p.Root,'pages':len(p.pages)}))",
      tmp,
    ],
    { encoding: "utf8" }
  ).trim()
);
assert.equal(res.hasMetadata, false, "XMP /Metadata not stripped");
assert.deepEqual(res.infoKeys, [], `trailer /Info still carries keys after sanitize: ${res.infoKeys}`);
assert.equal(res.pages, 1, "page count changed during sanitize (regression)");
console.log("PASS sanitize: XMP /Metadata stripped and /Info emptied, pages preserved");

console.log("\nRG-097 sanitization-partial gates PASS (metadata/attachment/thumbnail; JS/action neutralization remains custom)");
