import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";

const mutool = process.env.MUTOOL_BIN || "mutool";

function run(args) {
  return execFileSync(mutool, args, { encoding: "utf8", maxBuffer: 64 * 1024 * 1024, stdio: ["ignore", "pipe", "pipe"] });
}

function digest(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

function textFacts(filePath) {
  const report = JSON.parse(run(["draw", "-q", "-F", "stext.json", "-o", "-", filePath]));
  const pages = (report.pages || []).map((page) => ({
    width: page.width,
    height: page.height,
    text: (page.blocks || [])
      .filter((block) => block.type === "text")
      .flatMap((block) => block.lines || [])
      .map((line) => line.text || "")
      .join(" ")
      .replace(/\s+/g, " ")
      .trim()
  }));
  return pages;
}

function renderFacts(filePath) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "pdf-editor-mupdf-render-"));
  try {
    run(["draw", "-q", "-F", "pam", "-r", "108", "-o", path.join(directory, "page-%d.pam"), filePath]);
    return fs.readdirSync(directory).filter((name) => name.endsWith(".pam")).sort().map((name) => ({
      name,
      digest: crypto.createHash("sha256").update(fs.readFileSync(path.join(directory, name))).digest("hex"),
      byteCount: fs.statSync(path.join(directory, name)).size
    }));
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
}

export function compareMupdfReopen({ sourcePath, outputPath }) {
  try {
    const sourceText = textFacts(sourcePath);
    const outputText = textFacts(outputPath);
    const sourceRaster = renderFacts(sourcePath);
    const outputRaster = renderFacts(outputPath);
    const textEqual = JSON.stringify(sourceText) === JSON.stringify(outputText);
    const rasterEqual = JSON.stringify(sourceRaster.map(({ digest, byteCount }) => ({ digest, byteCount })))
      === JSON.stringify(outputRaster.map(({ digest, byteCount }) => ({ digest, byteCount })));
    return {
      contract: "pdf-editor.mupdf-independent-reopen",
      version: { major: 1, minor: 0 },
      status: textEqual && rasterEqual ? "passed" : "failed",
      provider: "mupdf",
      sourceDigest: digest(sourcePath),
      outputDigest: digest(outputPath),
      text: { status: textEqual ? "passed" : "failed", sourcePageCount: sourceText.length, outputPageCount: outputText.length },
      raster: { status: rasterEqual ? "passed" : "failed", sourcePageCount: sourceRaster.length, outputPageCount: outputRaster.length },
      reopen: "passed",
      rawContentInReport: false,
      editedOperationRegions: "notMeasured"
    };
  } catch (error) {
    return {
      contract: "pdf-editor.mupdf-independent-reopen",
      version: { major: 1, minor: 0 },
      status: "unknown",
      provider: "mupdf",
      reasonCode: "mupdfUnavailableOrCouldNotReopen",
      diagnostic: String(error.message || error).slice(0, 240),
      rawContentInReport: false,
      editedOperationRegions: "notMeasured"
    };
  }
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const args = Object.fromEntries(process.argv.slice(2).reduce((pairs, value, index, values) => {
    if (value.startsWith("--")) pairs.push([value.slice(2), values[index + 1]]);
    return pairs;
  }, []));
  if (!args.source || !args.output) throw new Error("Usage: node benchmark/mupdf-independent-validator.mjs --source SOURCE --output OUTPUT");
  const report = compareMupdfReopen({ sourcePath: args.source, outputPath: args.output });
  process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
  process.exitCode = report.status === "passed" ? 0 : 1;
}
