// pdf-signature-guard.mjs
//
// RG-014: signed-document behavior. Detection + explicit edit-invalidation.
//
// Detects signature-bearing structures: AcroForm /SigFields, /SigFlags, and
// standalone signature dictionaries (/ByteRange + /Contents). Editing any
// byte of a signed document invalidates its signatures; the guard therefore
// blocks edit sessions unless the caller explicitly acknowledges invalidation
// (the product surface must present that acknowledgment to a human).
//
// Scope boundary (recorded): this detects and gates. It does NOT verify
// signature cryptographic validity — that remains an open RG-014 sub-gate.

import { inspectPdfWithPikepdf } from "./pdf-object-inspect.mjs";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";

const DETECT_SNIPPET = `
RESULT = {"hasAcroForm": False, "sigFlags": None, "sigFieldCount": 0,
          "signatureDictionaries": 0, "detected": False}
af = p.Root.get('/AcroForm')
if af is not None:
    RESULT["hasAcroForm"] = True
    sf = af.get('/SigFlags')
    if sf is not None:
        RESULT["sigFlags"] = int(sf)
    for f in (af.get('/Fields') or []):
        try:
            if str(f.get('/FT')) == '/Sig':
                RESULT["sigFieldCount"] += 1
        except Exception:
            pass
sig_dicts = 0
for obj in p.objects:
    try:
        if isinstance(obj, pikepdf.Dictionary) and '/ByteRange' in obj and '/Contents' in obj:
            sig_dicts += 1
    except Exception:
        pass
RESULT["signatureDictionaries"] = sig_dicts
RESULT["detected"] = bool(
    RESULT["sigFieldCount"] > 0
    or RESULT["signatureDictionaries"] > 0
    or (RESULT["sigFlags"] or 0) != 0
)
`;

const VALIDATION_SNIPPET = `
RESULT = {"signatures": []}
for obj in p.objects:
    try:
        if '/ByteRange' not in obj or '/Contents' not in obj:
            continue
        byte_range = [int(value) for value in obj['/ByteRange']]
        contents = bytes(obj['/Contents'])
        RESULT["signatures"].append({
            "byteRange": byte_range,
            "contentsByteCount": len(contents),
            "contentsHex": contents.hex()
        })
    except Exception:
        pass
`;

export function detectSignatures(srcBuf) {
  const facts = inspectPdfWithPikepdf(srcBuf, DETECT_SNIPPET);
  return {
    ...facts,
    scope: "detection-only; cryptographic validity NOT verified (open sub-gate)"
  };
}

function validByteRange(byteRange, byteCount, fileSize) {
  if (!Array.isArray(byteRange) || byteRange.length !== 4 || !byteRange.every(Number.isInteger)) return false;
  const [start, firstLength, secondStart, secondLength] = byteRange;
  return start === 0
    && firstLength >= 0
    && secondStart >= firstLength
    && secondLength >= 0
    && secondStart + secondLength <= fileSize
    && secondStart >= firstLength
    && secondStart - firstLength > 0
    && byteCount > 0;
}

function opensslAvailable() {
  try {
    execFileSync(process.env.OPENSSL_BIN || "openssl", ["version"], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] });
    return true;
  } catch {
    return false;
  }
}

/**
 * Validate signature byte ranges and, when a structurally valid CMS object is
 * available, ask OpenSSL to verify the detached CMS bytes. Certificate trust
 * is deliberately not evaluated here. A successful CMS check is not a legal
 * identity or trust claim.
 */
export function validateSignatureIntegrity(srcBuf) {
  const detected = detectSignatures(srcBuf);
  if (!detected.detected) {
    return {
      contract: "pdf-editor.signature-validation",
      version: { major: 1, minor: 0 },
      status: "unsigned",
      structuralStatus: "notApplicable",
      cryptographicStatus: "notApplicable",
      trustStatus: "notApplicable",
      signatureCount: 0,
      sourceByteCount: srcBuf.byteLength,
      rawContentInReport: false
    };
  }
  let inspected;
  try {
    inspected = inspectPdfWithPikepdf(srcBuf, VALIDATION_SNIPPET);
  } catch (error) {
    return {
      contract: "pdf-editor.signature-validation",
      version: { major: 1, minor: 0 },
      status: "unknown",
      structuralStatus: "unknown",
      cryptographicStatus: "unknown",
      trustStatus: "notEvaluated",
      signatureCount: detected.signatureDictionaries,
      sourceByteCount: srcBuf.byteLength,
      reasonCode: "inspectionFailed",
      diagnostic: String(error.message || error).slice(0, 240),
      rawContentInReport: false
    };
  }
  const signatures = Array.isArray(inspected.signatures) ? inspected.signatures : [];
  const structural = signatures.map((signature) => ({
    valid: validByteRange(signature.byteRange, signature.contentsByteCount, srcBuf.byteLength),
    byteRange: signature.byteRange,
    contentsByteCount: signature.contentsByteCount
  }));
  if (!structural.length || structural.some((entry) => !entry.valid)) {
    return {
      contract: "pdf-editor.signature-validation",
      version: { major: 1, minor: 0 },
      status: "failed",
      structuralStatus: "invalid",
      cryptographicStatus: "notAttempted",
      trustStatus: "notEvaluated",
      signatureCount: detected.signatureDictionaries,
      structural,
      sourceByteCount: srcBuf.byteLength,
      reasonCode: "invalidByteRange",
      rawContentInReport: false
    };
  }
  if (!opensslAvailable()) {
    return {
      contract: "pdf-editor.signature-validation",
      version: { major: 1, minor: 0 },
      status: "unknown",
      structuralStatus: "valid",
      cryptographicStatus: "unavailable",
      trustStatus: "notEvaluated",
      signatureCount: detected.signatureDictionaries,
      structural,
      sourceByteCount: srcBuf.byteLength,
      reasonCode: "opensslUnavailable",
      rawContentInReport: false
    };
  }
  const tempDirectory = fs.mkdtempSync(path.join(os.tmpdir(), "pdf-editor-signature-"));
  try {
    const results = structural.map((entry, index) => {
      const signature = signatures[index];
      const [firstStart, firstLength, secondStart, secondLength] = signature.byteRange;
      const signedBytes = Buffer.concat([srcBuf.subarray(firstStart, firstStart + firstLength), srcBuf.subarray(secondStart, secondStart + secondLength)]);
      const contentPath = path.join(tempDirectory, `content-${index}.bin`);
      const signaturePath = path.join(tempDirectory, `signature-${index}.der`);
      fs.writeFileSync(contentPath, signedBytes);
      fs.writeFileSync(signaturePath, Buffer.from(signature.contentsHex, "hex"));
      try {
        execFileSync(process.env.OPENSSL_BIN || "openssl", ["cms", "-verify", "-binary", "-inform", "DER", "-in", signaturePath, "-content", contentPath, "-noverify", "-out", "/dev/null"], { stdio: ["ignore", "pipe", "pipe"] });
        return "passed";
      } catch {
        return "failed";
      }
    });
    const cryptographicStatus = results.every((result) => result === "passed") ? "passed" : "failed";
    return {
      contract: "pdf-editor.signature-validation",
      version: { major: 1, minor: 0 },
      status: cryptographicStatus === "passed" ? "passed" : "failed",
      structuralStatus: "valid",
      cryptographicStatus,
      trustStatus: "notEvaluated",
      signatureCount: detected.signatureDictionaries,
      structural,
      sourceByteCount: srcBuf.byteLength,
      reasonCode: cryptographicStatus === "passed" ? "cmsVerifiedWithoutTrustEvaluation" : "cmsVerificationFailed",
      rawContentInReport: false
    };
  } finally {
    fs.rmSync(tempDirectory, { recursive: true, force: true });
  }
}

export class SignatureEditBlockError extends Error {
  constructor(facts) {
    super(
      `Document carries ${Math.max(facts.sigFieldCount, facts.signatureDictionaries)} signature ` +
      "structure(s); editing invalidates them. Re-run with signatureAcknowledged=true after " +
      "the user explicitly accepts invalidation."
    );
    this.name = "SignatureEditBlockError";
    this.facts = facts;
  }
}

export function planSignatureImpact(detection, { signatureAcknowledged = false } = {}) {
  if (!detection || typeof detection.detected !== "boolean") {
    throw new TypeError(
      "planSignatureImpact requires detection facts with a boolean 'detected' field."
    );
  }
  if (!detection.detected) {
    return { detected: false, willInvalidate: false, blocked: false };
  }
  if (!signatureAcknowledged) {
    return {
      detected: true,
      willInvalidate: true,
      blocked: true,
      reason: "Signature invalidation requires explicit human acknowledgment."
    };
  }
  return { detected: true, willInvalidate: true, blocked: false };
}

export function assertSignaturesEditable(detection, opts = {}) {
  const plan = planSignatureImpact(detection, opts);
  if (plan.blocked) throw new SignatureEditBlockError(detection);
  return plan;
}
