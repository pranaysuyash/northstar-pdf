// pdf-xfa-guard.mjs
//
// RG-015: XFA behavior. Detect, classify, and safely reject form editing
// without false AcroForm claims.
//
// An XFA form's field model is defined by XML packets, not the PDF /Fields
// array; treating an XFA document as a plain AcroForm produces silently wrong
// edits. When XFA is present, native-field edit operations are refused with
// an explicit unsupported reason. Detection reports the raw facts (kind:
// stream vs packet array, packet names, dynamic hint) without overclaiming
// full static/dynamic classification.

import { inspectPdfWithPikepdf } from "./pdf-object-inspect.mjs";

const DETECT_SNIPPET = `
RESULT = {"acroFormPresent": False, "xfaPresent": False,
          "xfaKind": None, "packetNames": [], "dynamicHint": False}
af = p.Root.get('/AcroForm')
if af is not None:
    RESULT["acroFormPresent"] = True
    x = af.get('/XFA')
    if x is not None:
        RESULT["xfaPresent"] = True
        if isinstance(x, pikepdf.Array):
            RESULT["xfaKind"] = "array"
            names = []
            for i in range(0, len(x) - 1, 2):
                try:
                    if isinstance(x[i], pikepdf.String):
                        names.append(str(x[i]))
                except Exception:
                    pass
            RESULT["packetNames"] = names
        else:
            RESULT["xfaKind"] = "stream"
        def xfa_text(o):
            try:
                return o.read_bytes().decode("latin-1", "ignore")
            except Exception:
                return str(o)
        blob = ""
        try:
            if isinstance(x, pikepdf.Array):
                for i in range(1, len(x), 2):
                    blob += xfa_text(x[i])
            else:
                blob += xfa_text(x)
        except Exception:
            pass
        RESULT["dynamicHint"] = bool("config" in blob or "dynamicRender" in blob)
`;

export function detectXfa(srcBuf) {
  return inspectPdfWithPikepdf(srcBuf, DETECT_SNIPPET);
}

export class XfaEditBlockError extends Error {
  constructor(facts, operationIDs) {
    super(
      `Document carries an XFA form (${facts.xfaKind || "unknown"} kind). The interactive ` +
      "model lives in XML packets, not the PDF field tree; native-field edits would make " +
      "false AcroForm claims and are refused."
    );
    this.name = "XfaEditBlockError";
    this.facts = facts;
    this.operationIDs = operationIDs;
  }
}

const FORM_EDIT_KINDS = new Set(["nativeFieldValue", "synthesizeNativeField"]);

export function assertNoXfaFormEdits(xfaFacts, operations = []) {
  if (!xfaFacts || typeof xfaFacts.xfaPresent !== "boolean") {
    throw new TypeError(
      "assertNoXfaFormEdits requires detection facts with a boolean 'xfaPresent' field."
    );
  }
  if (!xfaFacts.xfaPresent) return { ok: true };
  const ops = Array.isArray(operations) ? operations : [];
  const offending = ops.filter((op) => FORM_EDIT_KINDS.has(op?.kind)).map((op) => op?.id || "<unknown>");
  if (offending.length > 0) throw new XfaEditBlockError(xfaFacts, offending);
  return { ok: true, refusedOperationIDs: [] };
}
