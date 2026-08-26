import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { validateTextRedaction } from "../benchmark/redaction-completeness-validator.mjs";
import { pdfPython } from "./pdf-python.mjs";

const root = path.resolve(new URL("..", import.meta.url).pathname);
const sourcePath = path.join(root, "benchmark/results/corpus-sweep-2026-08-25/plain-text.pdf");
const tempDirectory = fs.mkdtempSync(path.join(os.tmpdir(), "pdf-editor-redaction-"));
const unsafePath = path.join(tempDirectory, "unsafe-whiteout.pdf");
const safePath = path.join(tempDirectory, "content-removed.pdf");
const region = [{ pageIndex: 1, rect: { x: 68, y: 687, width: 320, height: 18 } }];

try {
  execFileSync(pdfPython, ["-c", [
    "import pikepdf, sys",
    "src, unsafe, safe = sys.argv[1], sys.argv[2], sys.argv[3]",
    "p = pikepdf.open(src)",
    "page = p.pages[1]",
    "contents = page.Contents if isinstance(page.Contents, pikepdf.Array) else pikepdf.Array([page.Contents])",
    "whiteout = p.make_stream(b'q 1 1 1 rg 68 687 320 18 re f Q\\n')",
    "page.Contents = pikepdf.Array(list(contents) + [whiteout])",
    "p.save(unsafe)",
    "p = pikepdf.open(src)",
    "page = p.pages[1]",
    "contents = page.Contents if isinstance(page.Contents, pikepdf.Array) else pikepdf.Array([page.Contents])",
    "kept = []",
    "for stream in contents:",
    "    data = bytes(stream.read_bytes())",
    "    data = data.replace(b'(First paragraph of body copy spanning several words and lines.) Tj T*', b'() Tj T*')",
    "    kept.append(p.make_stream(data))",
    "page.Contents = pikepdf.Array(kept)",
    "p.save(safe)"
  ].join("\n"), sourcePath, unsafePath, safePath], { encoding: "utf8" });

  const unsafe = validateTextRedaction({ sourcePath, outputPath: unsafePath, regions: region });
  assert.equal(unsafe.status, "failed");
  assert.equal(unsafe.reasonCode, "targetTextSurvivesOrOutsideChanged");
  console.log("PASS whiteout mutation is rejected because source text survives");

  const safe = validateTextRedaction({ sourcePath, outputPath: safePath, regions: region });
  assert.equal(safe.status, "passed");
  assert.equal(safe.visualStatus, "unknown");
  assert.equal(safe.claims.imageAndVectorRemoval, "unknown");
  console.log("PASS content-removal fixture proves text removal with stable outside text");
} finally {
  fs.rmSync(tempDirectory, { recursive: true, force: true });
}

console.log("RG-redaction-completeness text lane PASS; visual/image/vector and cryptographic erasure remain explicit unknowns");
