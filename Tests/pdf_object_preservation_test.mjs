import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { compareObjectPreservation, changedObjectIDs } from "../benchmark/pdf-object-preservation-validator.mjs";

const root = path.resolve(new URL("..", import.meta.url).pathname);
const sourcePath = path.join(root, "benchmark/results/public-sample-form.pdf");
const editedPath = path.join(root, "benchmark/results/2026-08-23-public-acroform/mutated.pdf");
const tempDirectory = fs.mkdtempSync(path.join(os.tmpdir(), "pdf-editor-object-preservation-"));
const noOpPath = path.join(tempDirectory, "noop.pdf");
fs.copyFileSync(sourcePath, noOpPath);

try {
  const noOp = compareObjectPreservation({ sourcePath, outputPath: noOpPath });
  assert.equal(noOp.status, "passed");
  assert.equal(noOp.byteIdentical, true);
  assert.equal(noOp.rawContentInReport, false);
  console.log("PASS byte-identical no-op object preservation");

  const edited = compareObjectPreservation({ sourcePath, outputPath: editedPath });
  assert.equal(edited.byteIdentical, false);
  assert.equal(edited.sourcePrefixPreserved, false, "rewritten benchmark output must not claim prefix preservation");
  assert.equal(edited.status, "failed", "unscoped object changes must fail closed");
  assert.ok(changedObjectIDs(edited).length > 0, "edited output must expose changed object IDs without content");
  assert.equal(edited.rawContentInReport, false);
  assert.equal(Object.values(edited.objects).some((value) => typeof value === "string" && value.length > 128), false, "object report must not expose raw content");
  console.log(`PASS unauthorized object mutation rejected (${changedObjectIDs(edited).length} changed objects)`);

  const scoped = compareObjectPreservation({
    sourcePath,
    outputPath: editedPath,
    allowedObjectIDs: changedObjectIDs(edited)
  });
  assert.equal(scoped.status, "passed", "explicitly authorized object changes may pass structural preservation");
  console.log("PASS explicit object authorization separates edited targets from preservation failures");

  const bypass = compareObjectPreservation({
    sourcePath,
    outputPath: editedPath,
    allowedObjectIDs: changedObjectIDs(edited).slice(1)
  });
  assert.equal(bypass.status, "failed", "removing one authorized object must kill the preservation bypass");
  console.log("PASS mutation: missing one authorized object kills preservation bypass");
} finally {
  fs.rmSync(tempDirectory, { recursive: true, force: true });
}

console.log("RG-object-preservation checks PASS");
