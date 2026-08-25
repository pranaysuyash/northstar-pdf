import crypto from "node:crypto";
import fs from "node:fs";
import { spawnSync } from "node:child_process";

export const PDF_UA_VALIDATION_CONTRACT = Object.freeze({
  name: "pdf-editor.pdf-ua-validation",
  version: { major: 1, minor: 0 },
  validator: "veraPDF",
  profile: "ua1",
  heuristicReadingOrderIsNotConformance: true,
  rawDocumentContentInReport: false,
  statuses: ["passed", "failed", "unknown", "unavailable"]
});

function digestFile(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

function executable() {
  return process.env.VERAPDF_BIN || `${process.cwd()}/tools/verapdf`;
}

function normalizedFailure(code, sourceDigest, diagnostic) {
  return {
    contract: PDF_UA_VALIDATION_CONTRACT,
    status: "unknown",
    errorCode: code,
    sourceDigest,
    diagnostic,
    rawDocumentContentInReport: false
  };
}

export function validatePdfUA(filePath, { password = null } = {}) {
  if (!fs.existsSync(filePath)) return normalizedFailure("missing-input", null, "PDF/UA input does not exist.");
  const sourceDigest = digestFile(filePath);
  const args = ["--format", "json", "--flavour", "ua1"];
  if (password) args.push("--password", password);
  args.push(filePath);
  const processResult = spawnSync(executable(), args, {
    encoding: "utf8",
    maxBuffer: 32 * 1024 * 1024
  });
  let parsed;
  try {
    parsed = JSON.parse(processResult.stdout || "");
  } catch {
    return normalizedFailure("validator-unavailable-or-failed", sourceDigest, "veraPDF did not emit a parseable validation report.");
  }
  const job = parsed?.report?.jobs?.[0];
  const result = job?.validationResult?.[0];
  if (!result) return normalizedFailure("validation-result-missing", sourceDigest, "veraPDF report did not contain a validation result.");
  const details = result.details || {};
  return {
    contract: PDF_UA_VALIDATION_CONTRACT,
    status: result.compliant === true ? "passed" : result.compliant === false ? "failed" : "unknown",
    sourceDigest,
    profile: result.profileName || "PDF/UA-1 validation profile",
    jobEndStatus: result.jobEndStatus || null,
    compliant: result.compliant === true,
    passedRules: Number(details.passedRules) || 0,
    failedRules: Number(details.failedRules) || 0,
    passedChecks: Number(details.passedChecks) || 0,
    failedChecks: Number(details.failedChecks) || 0,
    failedClauses: [...new Set((details.ruleSummaries || [])
      .filter((rule) => rule?.status === "failed")
      .map((rule) => rule.clause)
      .filter(Boolean))].sort(),
    evidence: {
      validatorVersion: "veraPDF 1.30.2",
      profile: "PDF/UA-1",
      sourceBytesRemainLocal: true,
      heuristicReadingOrderUsedAsConformance: false
    },
    rawDocumentContentInReport: false
  };
}
