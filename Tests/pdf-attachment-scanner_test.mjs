// pdf-attachment-scanner_test.mjs
// RG-024 / RG-049 / RG-067 (Tier 3): synthetic attachment corpus covering
// safe names, traversal, absolute paths, drive letters, control characters,
// oversized names, executable extensions, and duplicates — plus the
// inventory/security verdict at the inspection boundary.
import assert from "node:assert";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { scanAttachments, assertAttachmentsSafe } from "../web/pdf-attachment-scanner.mjs";
import { pdfPython } from "./pdf-python.mjs";

const SRC = "/Users/pranay/Projects/pdf_editor/benchmark/results/public-sample-form.pdf";
const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "att-"));
const corpusPath = path.join(tmpDir, "attachment-corpus.pdf");

const LONG_NAME = `x`.repeat(300) + ".txt";

execFileSync(
  pdfPython,
  ["-c",
    [
      "import pikepdf, sys",
      "src, out = sys.argv[1], sys.argv[2]",
      "p = pikepdf.open(src)",
      "def filespec(name, data=b'payload'):",
      "    stream = p.make_indirect(pikepdf.Stream(p, data))",
      "    return p.make_indirect(pikepdf.Dictionary(",
      "        F=pikepdf.String(name),",
      "        UF=pikepdf.String(name),",
      "        EF=pikepdf.Dictionary(F=stream, UF=stream),",
      "    ))",
      "entries = []",
      "def add(name, data=b'payload'):",
      "    entries.extend([pikepdf.String(name), filespec(name, data)])",
      "add('report.txt')",
      "add('../../evil.sh')",
      "add('/abs/path/x.exe')",
      "add('C:\\\\win\\\\evil.bat')",
      "add('bad\\x01ctrl.txt')",
      "add('" + LONG_NAME + "')",
      "add('dup.bin'); add('dup.bin')",
      "names_tree = p.make_indirect(pikepdf.Dictionary(Names=pikepdf.Array(entries)))",
      "p.Root.Names = p.make_indirect(pikepdf.Dictionary(EmbeddedFiles=names_tree))",
      "p.save(out)",
    ].join("\n"),
    SRC, corpusPath],
  { encoding: "utf8" }
);

// Clean fixture has no attachments.
const clean = scanAttachments(fs.readFileSync(SRC));
assert.equal(clean.count, 0);
assert.equal(clean.nameTreePresent, false);
console.log("PASS public fixture: no attachments reported");

const scan = scanAttachments(fs.readFileSync(corpusPath));
assert.equal(scan.count, 8, `expected 8 entries, got ${scan.count}`);
assert.ok(scan.nameTreePresent);

const byName = new Map(scan.attachments.map((a) => [a.name, a]));
assert.deepEqual(byName.get("report.txt").suspiciousReasons, []);

const evil = byName.get("../../evil.sh");
assert.ok(evil.suspiciousReasons.includes("traversalSegment"), JSON.stringify(evil));
assert.ok(evil.suspiciousReasons.includes("executableExtension:.sh"));

const abs = byName.get("/abs/path/x.exe");
assert.ok(abs.suspiciousReasons.includes("absolutePath"));
assert.ok(abs.suspiciousReasons.includes("executableExtension:.exe"));

const drive = byName.get("C:\\win\\evil.bat");
assert.ok(drive.suspiciousReasons.includes("driveLetter"));
assert.ok(drive.suspiciousReasons.includes("executableExtension:.bat"));

const ctrl = byName.get("bad\x01ctrl.txt");
assert.ok(ctrl.suspiciousReasons.includes("controlCharacters"));

const long = byName.get(LONG_NAME);
assert.ok(long.suspiciousReasons.includes("oversizedName"));

assert.deepEqual(scan.duplicates, ["dup.bin"], JSON.stringify(scan.duplicates));
assert.equal(scan.unsafe.length, 5);
console.log(`PASS security scan: ${scan.unsafe.length}/8 flagged with exact reasons; duplicate "dup.bin" detected`);

const verdict = assertAttachmentsSafe(scan);
assert.equal(verdict.ok, false);
assert.equal(verdict.blocked, true);
assert.ok(/\.\.\/\.\.\/evil\.sh/.test(verdict.reason));

const okVerdict = assertAttachmentsSafe(clean);
assert.equal(okVerdict.blocked, false);
console.log("PASS boundary verdict: unsafe corpus blocked; empty inventory passes");

// Falsifier: malformed scan facts are rejected.
assert.throws(() => assertAttachmentsSafe(null), TypeError);
assert.throws(() => assertAttachmentsSafe({}), TypeError);
console.log("PASS falsifier: scan facts without a numeric count are rejected");

fs.rmSync(tmpDir, { recursive: true, force: true });
console.log("\nRG-024/RG-049/RG-067 attachment gates PASS (execution sandboxing remains open)");
