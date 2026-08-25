// pdf-action-neutralize.mjs
//
// RG-097 remaining active gate: neutralize auto-executing / active content that
// qpdf cannot strip. qpdf removes metadata/attachments but NOT JavaScript,
// OpenAction, or Launch actions (see docs/explorations/provider-custom-oss-...md).
//
// This custom pass walks the document with pikepdf (qpdf-backed, already in the
// companion) and deletes auto-executing keys: /OpenAction, /AA, /JS, /JavaScript
// on the catalog, page tree, and annotations, plus /A and auto /Launch,
// /SubmitForm on annotations.
//
// Deliberately leaves /URI link annotations (user-initiated navigation, not
// auto-exec) intact. Local-first: no egress. Runs in the companion (Node).

import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

export function neutralizeActions(srcBuf, opts = {}) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "pdfan-"));
  const inP = path.join(dir, "in.pdf");
  const outP = path.join(dir, "out.pdf");
  fs.writeFileSync(inP, srcBuf);

  const py = [
    "import pikepdf, sys",
    "src, out = sys.argv[1], sys.argv[2]",
    "pdf = pikepdf.open(src)",
    "CAT = ['/OpenAction', '/AA', '/JS', '/JavaScript']",
    "ANN = ['/A', '/AA', '/JS', '/JavaScript']",
    "for k in CAT:",
    "    if k in pdf.Root: del pdf.Root[k]",
    "def walk(p):",
    "    if not hasattr(p, 'keys'): return",
    "    for k in ['/AA', '/JS', '/JavaScript']:",
    "        if k in p: del p[k]",
    "    if '/Kids' in p:",
    "        for kid in p.Kids: walk(kid)",
    "if '/Pages' in pdf.Root: walk(pdf.Root.Pages)",
    "for page in pdf.pages:",
    "    if '/Annots' in page:",
    "        for a in page.Annots:",
    "            if not hasattr(a, 'keys'): continue",
    "            for k in ANN:",
    "                if k in a: del a[k]",
    "            if a.get('/Subtype') in ('/Launch', '/SubmitForm'):",
    "                if '/S' in a: del a['/S']",
    "pdf.save(out)",
  ].join("\n");

  try {
    execFileSync("python3", ["-c", py, inP, outP], { stdio: "pipe" });
    return fs.readFileSync(outP);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}
