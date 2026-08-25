import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { validatePdfUA } from "../benchmark/pdf-ua-validator.mjs";

const root = path.resolve(new URL("..", import.meta.url).pathname);
const files = [
  "benchmark/results/public-sample-form.pdf",
  "benchmark/results/corpus-sweep-2026-08-25/geometry.pdf",
  "benchmark/results/corpus-sweep-2026-08-25/navigation.pdf",
  "benchmark/results/corpus-sweep-2026-08-25/metadata-complete.pdf"
];

const reports = files.map((relativePath) => {
  const report = validatePdfUA(path.join(root, relativePath));
  assert.ok(["passed", "failed", "unknown", "unavailable"].includes(report.status));
  assert.equal(report.rawDocumentContentInReport, false);
  assert.match(report.sourceDigest, /^[a-f0-9]{64}$/);
  assert.equal(report.evidence.heuristicReadingOrderUsedAsConformance, false);
  return { relativePath, status: report.status, failedRules: report.failedRules, failedClauses: report.failedClauses };
});

assert.ok(reports.some((report) => report.status === "failed"), "the corpus should retain nonconformant PDF/UA evidence");
assert.ok(reports.every((report) => report.status !== "unknown" && report.status !== "unavailable"), "the vendored validator must execute for the governed corpus");
console.log(JSON.stringify({ test: "pdf_ua_validator", profile: "PDF/UA-1", reports }, null, 2));
