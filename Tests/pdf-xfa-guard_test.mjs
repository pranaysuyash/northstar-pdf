// pdf-xfa-guard_test.mjs
// RG-015 (Tier 3): XFA detection/classification on a real non-XFA AcroForm
// fixture and a synthetic XFA fixture, plus safe rejection of form edits.
import assert from "node:assert";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { detectXfa, assertNoXfaFormEdits, XfaEditBlockError } from "../web/pdf-xfa-guard.mjs";
import { pdfPython } from "./pdf-python.mjs";

const SRC = "/Users/pranay/Projects/pdf_editor/benchmark/results/public-sample-form.pdf";
const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "xfa-"));
const xfaPath = path.join(tmpDir, "xfa.pdf");

execFileSync(
  pdfPython,
  ["-c",
    [
      "import pikepdf, sys",
      "src, out = sys.argv[1], sys.argv[2]",
      "p = pikepdf.open(src)",
      "xdp = (",
      "  '<?xdp version=\"2.6\"?>'",
      "  '<?xfa generator=\"SyntheticFixture\"?>'",
      "  '<template xmlns=\"http://www.xfa.org/schema/xfa-template/2.6/\"/>'",
      "  '<config xmlns=\"http://www.xfa.org/schema/xci/2.6/\"/>'",
      ")",
      "stream = pikepdf.Stream(p, xdp.encode())",
      "af = p.make_indirect(pikepdf.Dictionary(XFA=p.make_indirect(stream)))",
      "p.Root.AcroForm = af",
      "p.save(out)",
    ].join("\n"),
    SRC, xfaPath],
  { encoding: "utf8" }
);

// Real AcroForm fixture must NOT claim XFA.
const plain = detectXfa(fs.readFileSync(SRC));
assert.equal(plain.acroFormPresent, true);
assert.equal(plain.xfaPresent, false);
console.log("PASS public AcroForm fixture: no false XFA claim");

// Synthetic XFA is detected and classified.
const facts = detectXfa(fs.readFileSync(xfaPath));
assert.equal(facts.xfaPresent, true);
assert.equal(facts.xfaKind, "stream");
assert.equal(facts.dynamicHint, true, "config packet should set the dynamic hint");
console.log(`PASS synthetic XFA detected: kind=${facts.xfaKind}, dynamicHint=${facts.dynamicHint}`);

// Form edits refused; overlayText unaffected; clean facts pass through.
const ops = [
  { id: "op-xfa-field", kind: "nativeFieldValue" },
  { id: "op-overlay", kind: "overlayText" }
];
assert.throws(
  () => assertNoXfaFormEdits(facts, ops),
  (err) => err instanceof XfaEditBlockError && err.operationIDs.includes("op-xfa-field")
);
const okOverlay = assertNoXfaFormEdits({ ...facts }, [ops[1]]);
assert.equal(okOverlay.ok, true);
const okPlain = assertNoXfaFormEdits(plain, ops);
assert.equal(okPlain.ok, true);
console.log("PASS safe rejection: field edits refused with explicit reason; overlay/plain pass");

// Falsifier: malformed detection facts are rejected, never treated as clean.
assert.throws(() => assertNoXfaFormEdits(null, []), TypeError);
assert.throws(() => assertNoXfaFormEdits({}, []), TypeError);
assert.throws(() => assertNoXfaFormEdits({ acroFormPresent: true }, []), TypeError);
console.log("PASS falsifier: detection facts without boolean 'xfaPresent' are rejected");

fs.rmSync(tmpDir, { recursive: true, force: true });
console.log("\nRG-015 detect + safe-reject gates PASS (full static/dynamic taxonomy remains open)");
