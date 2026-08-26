import crypto from "node:crypto";
import fs from "node:fs";
import { execFileSync } from "node:child_process";

function runText(filePath) {
  return execFileSync(process.env.PDFTOTEXT_BIN || "pdftotext", ["-bbox-layout", filePath, "-"], { encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
}

function parseWords(xml) {
  const pages = [];
  const pagePattern = /<page\s+width="([\d.]+)"\s+height="([\d.]+)">([\s\S]*?)<\/page>/g;
  let pageMatch;
  while ((pageMatch = pagePattern.exec(xml)) !== null) {
    const words = [];
    const wordPattern = /<word\s+xMin="([\d.-]+)"\s+yMin="([\d.-]+)"\s+xMax="([\d.-]+)"\s+yMax="([\d.-]+)">([\s\S]*?)<\/word>/g;
    let wordMatch;
    while ((wordMatch = wordPattern.exec(pageMatch[3])) !== null) {
      const x = Number(wordMatch[1]);
      const yMinTop = Number(wordMatch[2]);
      const xMax = Number(wordMatch[3]);
      const yMaxTop = Number(wordMatch[4]);
      const height = Number(pageMatch[2]);
      words.push({
        text: wordMatch[5].replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">"),
        rect: { x, y: height - yMaxTop, width: xMax - x, height: yMaxTop - yMinTop }
      });
    }
    pages.push({ width: Number(pageMatch[1]), height: Number(pageMatch[2]), words });
  }
  return pages;
}

function intersects(a, b, tolerance = 0) {
  return a.x < b.x + b.width + tolerance
    && a.x + a.width > b.x - tolerance
    && a.y < b.y + b.height + tolerance
    && a.y + a.height > b.y - tolerance;
}

function hashWords(words) {
  const text = words.map((word) => word.text).join(" ").replace(/\s+/g, " ").trim();
  return { wordCount: words.length, textHash: crypto.createHash("sha256").update(text).digest("hex") };
}

/**
 * Proves only text-removal completeness. It does not claim image/vector
 * redaction, cryptographic erasure, or viewer-independent sanitization.
 */
export function validateTextRedaction({ sourcePath, outputPath, regions }) {
  let sourcePages;
  let outputPages;
  try {
    sourcePages = parseWords(runText(sourcePath));
    outputPages = parseWords(runText(outputPath));
  } catch (error) {
    return {
      contract: "pdf-editor.redaction-completeness",
      version: { major: 1, minor: 0 },
      status: "unknown",
      textStatus: "unknown",
      reasonCode: "textExtractionUnavailable",
      diagnostic: String(error.message || error).slice(0, 240),
      rawContentInReport: false
    };
  }
  if (sourcePages.length !== outputPages.length) {
    return { contract: "pdf-editor.redaction-completeness", version: { major: 1, minor: 0 }, status: "failed", textStatus: "failed", reasonCode: "pageCountChanged", rawContentInReport: false };
  }
  const pageResults = sourcePages.map((sourcePage, pageIndex) => {
    const outputPage = outputPages[pageIndex];
    const pageRegions = (regions || []).filter((region) => region.pageIndex === pageIndex).map((region) => region.rect);
    const sourceTarget = sourcePage.words.filter((word) => pageRegions.some((region) => intersects(word.rect, region, 0.5)));
    const outputTarget = outputPage.words.filter((word) => pageRegions.some((region) => intersects(word.rect, region, 0.5)));
    const sourceOutside = sourcePage.words.filter((word) => !pageRegions.some((region) => intersects(word.rect, region, 0.5)));
    const outputOutside = outputPage.words.filter((word) => !pageRegions.some((region) => intersects(word.rect, region, 0.5)));
    return {
      pageIndex,
      sourceTarget: hashWords(sourceTarget),
      outputTarget: hashWords(outputTarget),
      sourceOutside: hashWords(sourceOutside),
      outputOutside: hashWords(outputOutside),
      targetRemoved: sourceTarget.length > 0 && outputTarget.length === 0,
      outsideUnchanged: JSON.stringify(hashWords(sourceOutside)) === JSON.stringify(hashWords(outputOutside))
    };
  });
  const targetPages = pageResults.filter((page) => page.sourceTarget.wordCount > 0);
  const targetRemoved = targetPages.length > 0 && targetPages.every((page) => page.targetRemoved);
  const outsideUnchanged = pageResults.every((page) => page.outsideUnchanged);
  const status = !targetPages.length ? "unknown" : targetRemoved && outsideUnchanged ? "passed" : "failed";
  return {
    contract: "pdf-editor.redaction-completeness",
    version: { major: 1, minor: 0 },
    status,
    textStatus: status,
    visualStatus: "unknown",
    reasonCode: !targetPages.length ? "noInspectableTargetText" : targetRemoved ? "targetTextRemovedOutsideTextStable" : "targetTextSurvivesOrOutsideChanged",
    pages: pageResults,
    rawContentInReport: false,
    claims: { textRemovalOnly: true, imageAndVectorRemoval: "unknown", cryptographicErasure: "notEvaluated" }
  };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const args = Object.fromEntries(process.argv.slice(2).reduce((pairs, value, index, values) => {
    if (value.startsWith("--")) pairs.push([value.slice(2), values[index + 1]]);
    return pairs;
  }, []));
  if (!args.source || !args.output || !args.regions) throw new Error("Usage: node benchmark/redaction-completeness-validator.mjs --source SOURCE --output OUTPUT --regions JSON");
  const report = validateTextRedaction({ sourcePath: args.source, outputPath: args.output, regions: JSON.parse(fs.readFileSync(args.regions, "utf8")) });
  process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
  process.exitCode = report.status === "passed" ? 0 : 1;
}
