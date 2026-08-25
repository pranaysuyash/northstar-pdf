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

export function detectSignatures(srcBuf) {
  const facts = inspectPdfWithPikepdf(srcBuf, DETECT_SNIPPET);
  return {
    ...facts,
    scope: "detection-only; cryptographic validity NOT verified (open sub-gate)"
  };
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
