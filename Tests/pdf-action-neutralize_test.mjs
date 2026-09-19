// pdf-action-neutralize_test.mjs
// RG-097 active-content neutralization (Tier 3): synthesize a PDF carrying an
// /OpenAction JavaScript and an annotation /A Launch, neutralize, and assert
// both are gone while the file still reopens and keeps its page count.
import assert from "node:assert";
import fs from "node:fs";
import path from "node:path";
import { spawnSync, execFileSync } from "node:child_process";
import { neutralizeActions } from "../web/pdf-action-neutralize.mjs";
import { pdfPython } from "./pdf-python.mjs";

// Paths derived from this file's location — runner-portable (a hardcoded
// /Users/... path only ever resolved on the owner's machine).
const projectRoot = path.resolve(new URL("..", import.meta.url).pathname);
const projectTmp = path.join(projectRoot, "tmp");
const dirtyPath = path.join(projectTmp, "dirty.pdf");
const neutralizedPath = path.join(projectTmp, "neutralized.pdf");
const SRC = path.join(projectRoot, "benchmark/results/public-sample-form.pdf");
const srcBuf = fs.readFileSync(SRC);
fs.mkdirSync(projectTmp, { recursive: true });

// Build a malicious-ish fixture locally (auto-executing JS + Launch annotation).
const dirty = execFileSync(
  pdfPython,
  [
    "-c",
    [
      "import pikepdf, sys",
      "src, out = sys.argv[1], sys.argv[2]",
      "pdf = pikepdf.open(src)",
      "pdf.Root['/OpenAction'] = pikepdf.Dictionary(JS=pikepdf.String('app.alert(1)'))",
      "pdf.Root['/AA'] = pikepdf.Dictionary()",
      "page = pdf.pages[0]",
      "if '/Annots' not in page: page['/Annots'] = pikepdf.Array([])",
      "launch = pikepdf.Dictionary(Subtype=pikepdf.Name('/Launch'), S=pikepdf.Name('/Launch'), F=pikepdf.String('/bin/sh'))",
      "page.Annots.append(launch)",
      "pdf.save(out)",
    ].join("\n"),
    SRC,
    dirtyPath,
  ],
  { encoding: "utf8" }
);
void dirty;

const dirtyBuf = fs.readFileSync(dirtyPath);
const out = neutralizeActions(dirtyBuf);
assert.ok(out.length > 0, "neutralized output is non-empty");

const check = (() => {
  const r = spawnSync("qpdf", ["--check", neutralizedPath], {
    encoding: "utf8",
  });
  fs.writeFileSync(neutralizedPath, out);
  const r2 = spawnSync("qpdf", ["--check", neutralizedPath], {
    encoding: "utf8",
  });
  return (r2.stdout || "") + (r2.stderr || "");
})();
assert.ok(/No syntax or stream encoding errors/.test(check), `qpdf errors:\n${check}`);
assert.ok(!/ERROR/.test(check), `qpdf ERROR:\n${check}`);
console.log("PASS qpdf --check: neutralized file is structurally valid");

const res = JSON.parse(
  execFileSync(
    pdfPython,
    [
      "-c",
      "import pikepdf,sys,json; p=pikepdf.open(sys.argv[1]); root=p.Root; anns=[]\nfor pg in p.pages:\n  if '/Annots' in pg:\n    for a in pg.Annots:\n      if hasattr(a,'keys'): anns.append({'subtype':str(a.get('/Subtype')),'hasA':'/A' in a,'hasS':'/S' in a})\nprint(json.dumps({'openAction':'/OpenAction' in root,'aa':'/AA' in root,'pages':len(p.pages),'ann':anns}))",
      neutralizedPath,
    ],
    { encoding: "utf8" }
  ).trim()
);
assert.equal(res.openAction, false, "/OpenAction survived neutralization");
assert.equal(res.aa, false, "/AA survived neutralization");
assert.equal(res.pages, 1, "page count changed (regression)");
const launch = res.ann.find((a) => a.subtype === "/Launch");
assert.ok(!launch || (!launch.hasA && !launch.hasS), "Launch annotation action not neutralized");
console.log("PASS neutralize: /OpenAction + /AA removed, Launch action stripped, pages preserved");

console.log("\nRG-097 active-content neutralization gates PASS (custom pikepdf pass)");
