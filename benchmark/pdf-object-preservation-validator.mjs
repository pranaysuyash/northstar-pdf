import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync, spawnSync } from "node:child_process";

// Object-level preservation is intentionally a companion validation lane. It
// does not try to make PDF.js or pdf-lib expose object identities. qpdf is the
// independent structural reader, and the shared operation contract supplies
// the explicit authorization set for objects that may change.

export const OBJECT_PRESERVATION_CONTRACT = Object.freeze({
  name: "pdf-editor.object-preservation",
  version: { major: 1, minor: 0 },
  sourceBytes: "exact-prefix-when-edited",
  objectDigest: "sha256-of-normalized-qpdf-object-and-inline-stream-digest",
  rawContentInReport: false,
  statuses: ["passed", "failed", "unknown"]
});

const QPDF = process.env.QPDF_BIN || "qpdf";

function sha256(value) {
  return crypto.createHash("sha256").update(value).digest("hex");
}

function sourceBytes(filePath) {
  return fs.readFileSync(filePath);
}

function normalizeForDigest(value) {
  if (Array.isArray(value)) return value.map(normalizeForDigest);
  if (!value || typeof value !== "object") return value;
  const output = {};
  for (const key of Object.keys(value).sort()) {
    if (key === "data" && typeof value[key] === "string") {
      output.dataDigest = sha256(Buffer.from(value[key], "base64"));
      output.dataByteCount = Buffer.from(value[key], "base64").byteLength;
      continue;
    }
    output[key] = normalizeForDigest(value[key]);
  }
  return output;
}

function qpdfJson(filePath) {
  try {
    const text = execFileSync(QPDF, [
      "--json",
      "--json-stream-data=inline",
      filePath
    ], { encoding: "utf8", maxBuffer: 128 * 1024 * 1024 });
    return { status: "passed", value: JSON.parse(text) };
  } catch (error) {
    return {
      status: "failed",
      errorCode: "qpdf-json-failed",
      diagnostic: "Independent qpdf object inspection failed."
    };
  }
}

function qpdfCheck(filePath) {
  const result = spawnSync(QPDF, ["--check", filePath], { encoding: "utf8" });
  return {
    status: result.status === 0 ? "passed" : "failed",
    warningCount: (result.stdout || "").split("\n").filter((line) => line.startsWith("WARNING:")).length,
    errorCount: (result.stderr || "").split("\n").filter((line) => line.startsWith("ERROR:")).length
  };
}

function objectDigests(value) {
  const generationMaps = value?.qpdf && typeof value.qpdf === "object"
    ? Object.values(value.qpdf).filter((generation) => generation && typeof generation === "object")
    : [];
  const objects = {
    ...(value?.objects && typeof value.objects === "object" ? value.objects : {}),
    ...Object.assign({}, ...generationMaps)
  };
  return Object.fromEntries(Object.entries(objects).map(([objectID, objectValue]) => [
    objectID,
    sha256(JSON.stringify(normalizeForDigest(objectValue)))
  ]));
}

function sorted(values) {
  return [...values].sort((left, right) => left.localeCompare(right));
}

function compareDigestMaps(source, output) {
  const sourceIDs = new Set(Object.keys(source));
  const outputIDs = new Set(Object.keys(output));
  const commonObjectIDs = sorted([...sourceIDs].filter((id) => outputIDs.has(id)));
  const changedObjectIDs = commonObjectIDs.filter((id) => source[id] !== output[id]);
  return {
    sourceObjectCount: sourceIDs.size,
    outputObjectCount: outputIDs.size,
    commonObjectCount: commonObjectIDs.length,
    changedObjectIDs,
    addedObjectIDs: sorted([...outputIDs].filter((id) => !sourceIDs.has(id))),
    removedObjectIDs: sorted([...sourceIDs].filter((id) => !outputIDs.has(id)))
  };
}

export function compareObjectPreservation({ sourcePath, outputPath, allowedObjectIDs = [] }) {
  if (!fs.existsSync(sourcePath) || !fs.existsSync(outputPath)) {
    return {
      contract: OBJECT_PRESERVATION_CONTRACT,
      status: "unknown",
      errorCode: "missing-input",
      rawContentInReport: false
    };
  }
  const source = sourceBytes(sourcePath);
  const output = sourceBytes(outputPath);
  const sourceDigest = sha256(source);
  const outputDigest = sha256(output);
  const byteIdentical = source.equals(output);
  const sourceInspection = qpdfJson(sourcePath);
  const outputInspection = qpdfJson(outputPath);
  if (sourceInspection.status !== "passed" || outputInspection.status !== "passed") {
    return {
      contract: OBJECT_PRESERVATION_CONTRACT,
      status: "unknown",
      sourceDigest,
      outputDigest,
      byteIdentical,
      sourceInspection: sourceInspection.status,
      outputInspection: outputInspection.status,
      rawContentInReport: false
    };
  }

  const comparison = compareDigestMaps(
    objectDigests(sourceInspection.value),
    objectDigests(outputInspection.value)
  );
  if (comparison.sourceObjectCount === 0 || comparison.outputObjectCount === 0) {
    return {
      contract: OBJECT_PRESERVATION_CONTRACT,
      status: "unknown",
      sourceDigest,
      outputDigest,
      byteIdentical,
      sourcePrefixPreserved: output.length >= source.length && output.subarray(0, source.length).equals(source),
      errorCode: "empty-object-inventory",
      objects: comparison,
      rawContentInReport: false
    };
  }
  const allowed = new Set(allowedObjectIDs);
  const unauthorizedChangedObjectIDs = comparison.changedObjectIDs.filter((id) => !allowed.has(id));
  const unauthorizedRemovedObjectIDs = comparison.removedObjectIDs.filter((id) => !allowed.has(id));
  const structural = {
    source: qpdfCheck(sourcePath),
    output: qpdfCheck(outputPath)
  };
  const status = byteIdentical
    ? "passed"
    : structural.output.status === "failed"
      ? "failed"
      : unauthorizedChangedObjectIDs.length || unauthorizedRemovedObjectIDs.length
        ? "failed"
        : "passed";
  return {
    contract: OBJECT_PRESERVATION_CONTRACT,
    status,
    sourceDigest,
    outputDigest,
    byteIdentical,
    sourcePrefixPreserved: output.length >= source.length && output.subarray(0, source.length).equals(source),
    allowedObjectIDs: sorted(allowed),
    structural,
    objects: {
      ...comparison,
      unauthorizedChangedObjectIDs,
      unauthorizedRemovedObjectIDs
    },
    rawContentInReport: false
  };
}

export function changedObjectIDs(report) {
  return report?.objects?.changedObjectIDs || [];
}
