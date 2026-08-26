// pdf-source-preserving-lane_test.mjs
// Integration (Tier 2/3): the mutation gate routes external-AcroForm field
// writes through the RG-002 incremental writer, enforces preflight BEFORE any
// writer execution, and hard-guards the RG-017/RG-018 prefix invariant on the
// output before it can be persisted.
import assert from "node:assert";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import crypto from "node:crypto";
import { execFileSync } from "node:child_process";
import {
  selectWriterLane,
  guardedSourcePreservingExport,
  ContractMutationError
} from "../web/pdf-contract-mutation-gate.mjs";
import { incrementalFieldUpdate } from "../web/pdf-incremental-form-writer.mjs";
import { pdfPython } from "./pdf-python.mjs";

const SRC = "/Users/pranay/Projects/pdf_editor/benchmark/results/public-sample-form.pdf";
const srcBuf = new Uint8Array(fs.readFileSync(SRC));
const digest = crypto.createHash("sha256").update(srcBuf).digest("hex");

const RECT = { x: 10, y: 10, width: 100, height: 20 };
const SPACE = { unit: "points", origin: "lowerLeft", pageBox: "crop", rotationDegrees: 0 };
const PAGE_FACTS = [{ pageIndex: 0, rotation: 0 }];

const RADIO_1_EDITS = [
  { objNum: 24, pairs: [{ k: "/V", v: "/1" }] },
  { objNum: 30, pairs: [{ k: "/AS", v: "/1" }] },
  { objNum: 25, pairs: [{ k: "/AS", v: "/Off" }] }
];

function radioOperation(over = {}) {
  return {
    id: "op-contact-1",
    kind: "nativeFieldValue",
    sourceDigest: digest,
    pageIndex: 0,
    reversible: true,
    coordinate: { pageIndex: 0, rect: RECT, coordinateSpace: SPACE },
    bounds: RECT,
    incrementalEdits: RADIO_1_EDITS,
    ...over
  };
}

// --- Lane selection -------------------------------------------------------
assert.equal(selectWriterLane([]), "pdf-lib");
assert.equal(selectWriterLane([radioOperation()]), "incremental-form-writer");
assert.equal(
  selectWriterLane([radioOperation({ kind: "overlayText" })]),
  "pdf-lib",
  "overlayText must not qualify for the incremental lane"
);
assert.equal(
  selectWriterLane([radioOperation({ incrementalEdits: [{ objNum: 24 }] })]),
  "pdf-lib",
  "incomplete edit plans must fall back"
);
console.log("PASS lane selection");

// --- Preflight runs BEFORE the writer -------------------------------------
let writerCalled = false;
await assert.rejects(
  () => guardedSourcePreservingExport({
    currentSourceDigest: "stale".padEnd(64, "0"),
    operations: [radioOperation()],
    pageCoordinates: PAGE_FACTS,
    sourceBytes: srcBuf,
    writeIncremental: () => { writerCalled = true; return srcBuf; }
  }),
  (err) => err instanceof ContractMutationError && err.code === "staleSourceDigest"
);
assert.equal(writerCalled, false, "writer executed despite failed preflight");
console.log("PASS stale digest rejected before writer executes");

await assert.rejects(
  () => guardedSourcePreservingExport({
    currentSourceDigest: digest,
    operations: [radioOperation({ kind: "overlayText" })],
    pageCoordinates: PAGE_FACTS,
    sourceBytes: srcBuf,
    writeIncremental: () => { writerCalled = true; return srcBuf; }
  }),
  (err) => err instanceof ContractMutationError && err.code === "unsupportedOperation"
);
assert.equal(writerCalled, false);
console.log("PASS non-qualifying lane refused before writer executes");

// --- Happy path: real incremental write through the gate ------------------
const result = await guardedSourcePreservingExport({
  currentSourceDigest: digest,
  operations: [radioOperation()],
  pageCoordinates: PAGE_FACTS,
  sourceBytes: srcBuf,
  writeIncremental: (source, edits) => incrementalFieldUpdate(Buffer.from(source), edits)
});
assert.equal(result.ok, true);
assert.equal(result.provider, "incremental-form-writer");
assert.equal(result.lane, "incremental-form-writer");
assert.equal(result.preservedPrefixLength, srcBuf.length);
assert.ok(Buffer.from(result.bytes.slice(0, srcBuf.length)).equals(Buffer.from(srcBuf)));
console.log("PASS gate export: provider=incremental-form-writer, prefix preserved end-to-end");

// Independent reopen: radio choice survived.
const tmpPdf = path.join(os.tmpdir(), `lane-out-${Date.now()}.pdf`);
fs.writeFileSync(tmpPdf, result.bytes);
const res = JSON.parse(execFileSync(
  pdfPython,
  ["-c",
    "import pikepdf,sys,json;p=pikepdf.open(sys.argv[1]);f={str(x.get('/T')):x for x in p.Root.AcroForm.Fields[0].Kids};k=f.get('contact');kids=list(k.Kids);print(json.dumps({'v':str(k.V),'as':[str(x.AS) for x in kids]}))",
    tmpPdf],
  { encoding: "utf8" }
).trim());
assert.equal(res.v, "/1", "radio /V did not survive independent reopen");
assert.deepEqual(res.as, ["/Off", "/1"], "kid /AS states did not survive reopen");
fs.rmSync(tmpPdf, { force: true });
console.log("PASS independent reopen: contact=/1, kid AS=[/Off,/1]");

// --- Invariant guard: tampered writer cannot leak a rewrite ---------------
await assert.rejects(
  () => guardedSourcePreservingExport({
    currentSourceDigest: digest,
    operations: [radioOperation()],
    pageCoordinates: PAGE_FACTS,
    sourceBytes: srcBuf,
    writeIncremental: () => {
      const forged = new Uint8Array(srcBuf.length + 16);
      forged.set(srcBuf.subarray(1), 1); // diverges at byte 0
      return forged;
    }
  }),
  (err) => err instanceof ContractMutationError && err.code === "writerInvariantViolation"
);

await assert.rejects(
  () => guardedSourcePreservingExport({
    currentSourceDigest: digest,
    operations: [radioOperation()],
    pageCoordinates: PAGE_FACTS,
    sourceBytes: srcBuf,
    writeIncremental: () => new Uint8Array(8)
  }),
  (err) => err instanceof ContractMutationError && err.code === "writerInvariantViolation"
);
console.log("PASS invariant guard: rewritten/truncated output cannot escape the gate");

console.log("\nRG-002 integration gates PASS (gate -> incremental writer -> prefix guard)");
