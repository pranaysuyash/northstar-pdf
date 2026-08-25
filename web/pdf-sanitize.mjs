// pdf-sanitize.mjs
//
// RG-097 partial: source-bound sanitization using the already-installed qpdf
// (Apache-2.0, in-environment, no network egress). Strips document metadata,
// embedded-file attachments, thumbnails, and unreferenced resources.
//
// Scope boundary (per docs/explorations/provider-custom-oss-exploration-2026-08-25.md,
// bucket 3): qpdf does NOT neutralize JavaScript / OpenAction / Launch actions
// or image EXIF. Those remain a CUSTOM sanitization pass and are out of scope
// here; this module is the safe, dependency-free baseline.
//
// Runs in the local companion (Node), not the browser. Local-first: no egress.

import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

export function sanitizePdf(srcBuf, opts = {}) {
  const removeMetadata = opts.removeMetadata !== false;
  const removeAttachments = opts.removeAttachments !== false;
  const removeThumbnails = opts.removeThumbnails === true;
  const removeUnreferenced = opts.removeUnreferenced !== false;

  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "pdfsan-"));
  const inP = path.join(dir, "in.pdf");
  const outP = path.join(dir, "out.pdf");
  fs.writeFileSync(inP, srcBuf);

  const args = [];
  if (removeMetadata) args.push("--remove-metadata");
  if (removeAttachments) {
    // qpdf has no "remove all"; enumerate names then remove each.
    const list = execFileSync("qpdf", ["--list-attachments", inP], { encoding: "utf8" });
    for (const line of list.split("\n")) {
      const name = line.trim();
      if (name && !/embedded files|has no|no embedded|attachment/i.test(name) && name !== "listed") {
        args.push(`--remove-attachment=${name}`);
      }
    }
  }
  if (removeUnreferenced) args.push("--remove-unreferenced-resources=yes");
  args.push(inP, outP);

  try {
    execFileSync("qpdf", args, { stdio: "pipe" });
    let finalP = outP;
    if (removeMetadata) {
      // qpdf --remove-metadata clears XMP but leaves the trailer /Info dict;
      // pikepdf (qpdf-backed, already in the companion) strips both reliably.
      const metaP = path.join(dir, "meta.pdf");
      const py = [
        "import pikepdf,sys",
        "p=pikepdf.open(sys.argv[1])",
        "if '/Info' in p.trailer: del p.trailer['/Info']",
        "if '/Metadata' in p.Root: del p.Root['/Metadata']",
        "p.save(sys.argv[2])",
      ].join("\n");
      execFileSync("python3", ["-c", py, outP, metaP], { stdio: "pipe" });
      finalP = metaP;
    }
    return fs.readFileSync(finalP);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}
