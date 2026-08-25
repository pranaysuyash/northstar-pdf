import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { replaceSimpleTextRun } from "../web/simple-text-run-provider.mjs";
import { compareIndependentPreservation } from "../benchmark/independent-preservation-validator.mjs";

function buildSimplePdf() {
  const stream = "BT\n/F1 12 Tf\n72 700 Td\n(Hello) Tj\n0 -24 Td\n(Outside) Tj\nET\n";
  const objects = [
    "<< /Type /Catalog /Pages 2 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>",
    "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
    `<< /Length ${stream.length} >>\nstream\n${stream}endstream`
  ];
  let output = "%PDF-1.4\n%\xE2\xE3\xCF\xD3\n";
  const offsets = [0];
  objects.forEach((object, index) => {
    offsets.push(output.length);
    output += `${index + 1} 0 obj\n${object}\nendobj\n`;
  });
  const xrefOffset = output.length;
  output += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`;
  for (let index = 1; index <= objects.length; index += 1) {
    output += `${String(offsets[index]).padStart(10, "0")} 00000 n \n`;
  }
  output += `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xrefOffset}\n%%EOF\n`;
  return Uint8Array.from(output, (character) => character.charCodeAt(0));
}

const sourceBytes = buildSimplePdf();
const sourceDigest = crypto.createHash("sha256").update(sourceBytes).digest("hex");
const originalTextHash = crypto.createHash("sha256").update("Hello").digest("hex");
const coordinate = {
  pageIndex: 0,
  rect: { x: 72, y: 700, width: 35, height: 14 },
  coordinateSpace: { unit: "points", origin: "lowerLeft", pageBox: "crop", rotationDegrees: 0 }
};

const result = await replaceSimpleTextRun({
  sourceBytes,
  sourceDigest,
  targetRunID: "0:0:hello",
  originalText: "Hello",
  replacementText: "Earth",
  coordinate,
  originalTextHash,
  fontFingerprint: "font:helvetica"
});
assert.equal(result.status, "candidateNeedsValidation");
assert.equal(result.operation.kind, "textRunReplacement");
assert.equal(result.outputBytes.length, sourceBytes.length);
assert.equal(Buffer.from(result.outputBytes).includes(Buffer.from("(Earth)")), true);
assert.equal(Buffer.from(result.outputBytes).includes(Buffer.from("(Hello)")), false);
assert.equal(Buffer.from(result.outputBytes).includes(Buffer.from("(Outside)")), true);

const tempDirectory = fs.mkdtempSync(path.join(os.tmpdir(), "pdf-editor-text-run-"));
const sourcePath = path.join(tempDirectory, "source.pdf");
const outputPath = path.join(tempDirectory, "replacement.pdf");
fs.writeFileSync(sourcePath, sourceBytes);
fs.writeFileSync(outputPath, result.outputBytes);
const qpdf = spawnSync("qpdf", ["--check", outputPath], { encoding: "utf8" });
assert.equal(qpdf.status, 0, qpdf.stderr || qpdf.stdout);
const text = spawnSync("pdftotext", [outputPath, "-"], { encoding: "utf8" });
assert.equal(text.status, 0, text.stderr || text.stdout);
assert.match(text.stdout, /Earth/);
assert.match(text.stdout, /Outside/);
assert.doesNotMatch(text.stdout, /Hello/);
const preservation = compareIndependentPreservation({
  sourcePath,
  outputPath,
  operations: [{
    id: "text-run-replacement:0:0:hello",
    pageIndex: 0,
    coordinate
  }]
});
assert.equal(preservation.status, "passed", JSON.stringify(preservation));

await assert.rejects(
  replaceSimpleTextRun({
    sourceBytes,
    sourceDigest: "f".repeat(64),
    targetRunID: "0:0:hello",
    originalText: "Hello",
    replacementText: "Earth",
    coordinate,
    originalTextHash
  }),
  /stale source digest/
);
await assert.rejects(
  replaceSimpleTextRun({
    sourceBytes,
    sourceDigest,
    targetRunID: "0:0:hello",
    originalText: "Hello",
    replacementText: "Planet",
    coordinate,
    originalTextHash
  }),
  /same-byte-length/
);

fs.rmSync(tempDirectory, { recursive: true, force: true });
console.log("simple text-run provider: 16 checks passed");
