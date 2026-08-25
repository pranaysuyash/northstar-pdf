// pdf-signature-guard_test.mjs
// RG-014 (Tier 3): signature structure detection on a real unsigned fixture
// and a synthetic signed-structure fixture, plus explicit edit-invalidation
// gating. Detection only — cryptographic validity is NOT claimed.
import assert from "node:assert";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";
import {
  detectSignatures,
  planSignatureImpact,
  assertSignaturesEditable,
  SignatureEditBlockError
} from "../web/pdf-signature-guard.mjs";

const SRC = "/Users/pranay/Projects/pdf_editor/benchmark/results/public-sample-form.pdf";
const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "sig-"));
const signedPath = path.join(tmpDir, "signed.pdf");

execFileSync(
  "python3",
  ["-c",
    [
      "import pikepdf, sys",
      "src, out = sys.argv[1], sys.argv[2]",
      "p = pikepdf.open(src)",
      "sigdict = p.make_indirect(pikepdf.Dictionary(",
      "    ByteRange=pikepdf.Array([0, 8, 64, 8]),",
      "    Contents=pikepdf.String('/' + '0'*40),",
      "    Filter=pikepdf.Name('/Adobe.PPKLite'),",
      "))",
      "sigfield = p.make_indirect(pikepdf.Dictionary(",
      "    FT=pikepdf.Name('/Sig'),",
      "    T=pikepdf.String('Signature1'),",
      "    V=sigdict,",
      "))",
      "af = p.make_indirect(pikepdf.Dictionary(",
      "    SigFlags=int(1),",
      "    Fields=pikepdf.Array([sigfield]),",
      "))",
      "p.Root.AcroForm = af",
      "p.save(out)",
    ].join("\n"),
    SRC, signedPath],
  { encoding: "utf8" }
);

// Real fixture must be clean.
const clean = detectSignatures(fs.readFileSync(SRC));
assert.equal(clean.detected, false, `public fixture unexpectedly flagged: ${JSON.stringify(clean)}`);
assert.ok(typeof clean.detected === "boolean");
console.log("PASS unsigned public fixture: not flagged");

// Synthetic signed structures must be caught three ways.
const dirty = detectSignatures(fs.readFileSync(signedPath));
assert.equal(dirty.hasAcroForm, true);
assert.equal(dirty.sigFlags, 1);
assert.ok(dirty.sigFieldCount >= 1, `sig fields: ${dirty.sigFieldCount}`);
assert.ok(dirty.signatureDictionaries >= 1, `sig dicts: ${dirty.signatureDictionaries}`);
assert.equal(dirty.detected, true);
console.log(`PASS synthetic signed fixture: flags=1, sigFields=${dirty.sigFieldCount}, sigDicts=${dirty.signatureDictionaries}`);

// Guard: edits blocked until explicitly acknowledged.
assert.throws(
  () => assertSignaturesEditable(dirty),
  (err) => err instanceof SignatureEditBlockError
);
let plan = planSignatureImpact(dirty);
assert.equal(plan.blocked, true);
assert.equal(plan.willInvalidate, true);
plan = planSignatureImpact(dirty, { signatureAcknowledged: true });
assert.equal(plan.blocked, false);
assert.equal(plan.willInvalidate, true, "acknowledged edits still invalidate signatures");
console.log("PASS edit invalidation is explicit: blocked by default, allowed only with acknowledgment");

// Falsifier: malformed detection facts can never pass silently.
assert.throws(() => planSignatureImpact(null), TypeError);
assert.throws(() => planSignatureImpact({}), TypeError);
assert.throws(() => planSignatureImpact({ sigFieldCount: 0 }), TypeError);
console.log("PASS falsifier: detection facts without boolean 'detected' are rejected");

fs.rmSync(tmpDir, { recursive: true, force: true });
console.log("\nRG-014 detection + invalidation gates PASS (validity verification remains open)");
