// pdf-object-inspect.mjs
//
// Shared companion-lane inspection helper: runs a bounded pikepdf snippet
// against source bytes in a temp directory and parses the emitted JSON fact
// record. Used by the security guards (signature, XFA, attachment) that need
// real object-graph access rather than byte heuristics.
//
// Contract: the snippet must set a Python variable `RESULT` (JSON-serializable).
// Failures inside the snippet must be caught BY THE SNIPPET; an uncaught error
// propagates and the caller treats the document as unresolved.
//
// Local-first: temp files only, no egress. Companion (Node) placement — the
// browser lane uses its own PDF.js-based preflight surface (separate gate).

import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

export function inspectPdfWithPikepdf(srcBuf, pySnippet) {
  if (!(srcBuf instanceof Uint8Array) || srcBuf.length === 0) {
    throw new TypeError("inspectPdfWithPikepdf requires non-empty source bytes");
  }
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "pdfinsp-"));
  const inP = path.join(dir, "in.pdf");
  fs.writeFileSync(inP, srcBuf);
  const py =
    "import pikepdf, sys, json\n" +
    "p = pikepdf.open(sys.argv[1])\n" +
    pySnippet + "\n" +
    "print(json.dumps(RESULT))";
  try {
    const out = execFileSync("python3", ["-c", py, inP], {
      encoding: "utf8",
      maxBuffer: 64 * 1024 * 1024
    });
    return JSON.parse(out.trim());
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}
