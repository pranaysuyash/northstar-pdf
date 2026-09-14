import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { validatePdfUA } from "../benchmark/pdf-ua-validator.mjs";

const root = path.resolve(new URL("..", import.meta.url).pathname);
// tools/verapdf is a tracked wrapper, but it execs the vendored
// verapdf-cli distribution (gitignored) through java — both must exist for
// the validator to actually run. The wrapper merely existing is not enough.
const validatorBin = process.env.VERAPDF_BIN || path.join(root, "tools", "verapdf");
const vendoredDist = path.join(root, "tools", "verapdf-cli-1.30.2");
const javaCheck = process.env.VERAPDF_BIN
  ? { status: 0 }
  : spawnSync("java", ["-version"], { encoding: "utf8" });
if (
  !fs.existsSync(validatorBin) ||
  (!process.env.VERAPDF_BIN && !fs.existsSync(vendoredDist)) ||
  javaCheck.error ||
  javaCheck.status !== 0
) {
  console.log(JSON.stringify({
    test: "pdf_ua_validator",
    status: "not_ran",
    reason: "vendored veraPDF distribution or java runtime absent (gitignored toolchain); absence = not_ran provenance",
    profile: "PDF/UA-1"
  }, null, 2));
  process.exit(0);
}
const files = [
  "benchmark/results/public-sample-form.pdf",
  "benchmark/results/corpus-sweep-2026-08-25/geometry.pdf",
  "benchmark/results/corpus-sweep-2026-08-25/navigation.pdf",
  "benchmark/results/corpus-sweep-2026-08-25/metadata-complete.pdf"
];

// The vendored veraPDF distribution is deliberately gitignored, so checkouts
// without it (e.g. CI) cannot execute the validator. Absence is recorded as
// not_ran provenance instead of a crash — the same convention the OCR WER
// heavy gate uses. Where the validator IS present, the strict assertions
// below still fully apply.
if (!fs.existsSync(validatorBin)) {
  console.log(JSON.stringify({
    test: "pdf_ua_validator",
    status: "not_ran",
    reason: "vendored veraPDF distribution absent (gitignored); absence = not_ran provenance",
    profile: "PDF/UA-1"
  }, null, 2));
  process.exit(0);
}

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
