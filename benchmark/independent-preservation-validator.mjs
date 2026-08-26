import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync, spawnSync } from "node:child_process";

const DEFAULT_SCALE = 1.5;
const DEFAULT_CHANNEL_TOLERANCE = 8;

function commandPath(name, fallback = name) {
  try {
    return execFileSync("/bin/sh", ["-lc", `command -v ${name}`], { encoding: "utf8" }).trim() || fallback;
  } catch {
    return fallback;
  }
}

const tools = {
  qpdf: process.env.QPDF_BIN || commandPath("qpdf"),
  pdfinfo: process.env.PDFINFO_BIN || commandPath("pdfinfo"),
  pdftotext: process.env.PDFTOTEXT_BIN || commandPath("pdftotext"),
  pdftoppm: process.env.PDFTOPPM_BIN || commandPath("pdftoppm")
};

function runTool(tool, args, { allowFailure = false } = {}) {
  const result = spawnSync(tools[tool], args, {
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
    stdio: ["ignore", "pipe", "pipe"]
  });
  if (result.status === 0) {
    return { status: "passed", stdout: result.stdout || "", stderr: result.stderr || "" };
  }
  if (!allowFailure) {
    const error = new Error(result.error?.message || result.stderr || `Tool ${tool} failed.`);
    error.stdout = result.stdout;
    error.stderr = result.stderr;
    throw error;
  }
  {
    return {
      status: "failed",
      stdout: result.stdout || "",
      stderr: result.stderr || result.error?.message || `Tool ${tool} failed.`
    };
  }
}

function toolVersion(tool, args) {
  const result = runTool(tool, args, { allowFailure: true });
  return (result.stdout || result.stderr).split("\n").find(Boolean) || "unavailable";
}

function sha256File(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

function number(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function parsePdfInfo(text, pageCount = 0) {
  const pages = [];
  let current = null;
  for (const line of text.split("\n")) {
    let match = line.match(/^Page\s+(\d+)\s+size:\s+([\d.]+)\s+x\s+([\d.]+)/);
    if (match) {
      current = {
        pageIndex: Number(match[1]) - 1,
        width: number(match[2]),
        height: number(match[3]),
        rotation: 0,
        cropBox: null
      };
      pages.push(current);
      continue;
    }
    match = line.match(/^Page\s+(\d+)\s+rot:\s+(-?\d+)/);
    if (match) {
      const page = pages.find((candidate) => candidate.pageIndex === Number(match[1]) - 1);
      if (page) page.rotation = ((Number(match[2]) % 360) + 360) % 360;
      continue;
    }
    match = line.match(/^Page\s+(\d+)\s+CropBox:\s+([\d.-]+)\s+([\d.-]+)\s+([\d.-]+)\s+([\d.-]+)/);
    if (match) {
      const page = pages.find((candidate) => candidate.pageIndex === Number(match[1]) - 1);
      if (page) {
        page.cropBox = {
          x: number(match[2]),
          y: number(match[3]),
          width: number(match[4]) - number(match[2]),
          height: number(match[5]) - number(match[3])
        };
      }
    }
  }
  if (!pages.length && pageCount === 1) {
    const size = text.match(/^Page size:\s+([\d.]+)\s+x\s+([\d.]+)/m);
    const rotation = text.match(/^Page rot:\s+(-?\d+)/m);
    const crop = text.match(/^(?:Page\s+)?CropBox:\s+([\d.-]+)\s+([\d.-]+)\s+([\d.-]+)\s+([\d.-]+)/m);
    if (size) {
      current = {
        pageIndex: 0,
        width: number(size[1]),
        height: number(size[2]),
        rotation: rotation ? ((Number(rotation[1]) % 360) + 360) % 360 : 0,
        cropBox: crop ? {
          x: number(crop[1]),
          y: number(crop[2]),
          width: number(crop[3]) - number(crop[1]),
          height: number(crop[4]) - number(crop[2])
        } : null
      };
      pages.push(current);
    }
  }
  return pages.map((page) => ({
    ...page,
    cropBox: page.cropBox || { x: 0, y: 0, width: page.width, height: page.height }
  }));
}

function pageInfo(filePath, password) {
  const args = ["-box"];
  if (password) args.unshift("-upw", password);
  const result = runTool("pdfinfo", [...args, filePath], { allowFailure: true });
  if (result.status === "failed") {
    return { status: "failed", errorCode: "pdfinfo-reopen-failed", pages: [], diagnostic: "Poppler pdfinfo could not reopen the PDF." };
  }
  const pageCount = Number(result.stdout.match(/^Pages:\s+(\d+)/m)?.[1] || 0);
  const detailed = pageCount > 1
    ? runTool("pdfinfo", [...args, "-f", "1", "-l", String(pageCount), filePath], { allowFailure: true })
    : result;
  if (detailed.status === "failed") {
    return { status: "failed", errorCode: "pdfinfo-page-facts-failed", pages: [], diagnostic: "Poppler pdfinfo could not return per-page facts." };
  }
  const pages = parsePdfInfo(detailed.stdout, pageCount);
  if (!pageCount || pages.length !== pageCount) {
    return { status: "failed", errorCode: "pdfinfo-page-facts-incomplete", pages, diagnostic: "Poppler pdfinfo did not return complete page facts." };
  }
  return { status: "passed", pages };
}

function decodeEntities(value) {
  return value
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&#x([0-9a-f]+);/gi, (_, hex) => String.fromCodePoint(Number.parseInt(hex, 16)))
    .replace(/&#(\d+);/g, (_, code) => String.fromCodePoint(Number(code)));
}

function parseBBoxDocument(xml) {
  const pages = [];
  const pagePattern = /<page\s+width="([\d.]+)"\s+height="([\d.]+)">([\s\S]*?)<\/page>/g;
  let pageMatch;
  while ((pageMatch = pagePattern.exec(xml)) !== null) {
    const words = [];
    const wordPattern = /<word\s+xMin="([\d.-]+)"\s+yMin="([\d.-]+)"\s+xMax="([\d.-]+)"\s+yMax="([\d.-]+)">([\s\S]*?)<\/word>/g;
    let wordMatch;
    while ((wordMatch = wordPattern.exec(pageMatch[3])) !== null) {
      words.push({
        text: decodeEntities(wordMatch[5]),
        rect: {
          x: Number(wordMatch[1]),
          y: Number(wordMatch[2]),
          width: Number(wordMatch[3]) - Number(wordMatch[1]),
          height: Number(wordMatch[4]) - Number(wordMatch[2])
        }
      });
    }
    pages.push({ width: Number(pageMatch[1]), height: Number(pageMatch[2]), words });
  }
  return pages;
}

function normalizedTextHash(words) {
  const text = words.map((word) => word.text).join(" ").replace(/\s+/g, " ").trim();
  return {
    wordCount: words.length,
    textHash: crypto.createHash("sha256").update(text, "utf8").digest("hex")
  };
}

function normalizeRect(rect) {
  return {
    x: Math.min(rect.x, rect.x + rect.width),
    y: Math.min(rect.y, rect.y + rect.height),
    width: Math.abs(rect.width),
    height: Math.abs(rect.height)
  };
}

function rectIntersects(a, b, tolerance = 0) {
  return a.x < b.x + b.width + tolerance
    && a.x + a.width > b.x - tolerance
    && a.y < b.y + b.height + tolerance
    && a.y + a.height > b.y - tolerance;
}

function operationRegions(operations, pages) {
  const regions = [];
  const issues = [];
  for (const operation of Array.isArray(operations) ? operations : []) {
    const coordinate = operation?.coordinate;
    const rect = coordinate?.rect;
    if (!operation?.id || !Number.isInteger(operation.pageIndex) || !pages[operation.pageIndex]) {
      issues.push("invalid operation page");
    } else if (!coordinate || coordinate.pageIndex !== operation.pageIndex) {
      issues.push("operation coordinate page mismatch");
    } else if (!rect || !["x", "y", "width", "height"].every((key) => Number.isFinite(rect[key])) || rect.width <= 0 || rect.height <= 0) {
      issues.push("missing operation rectangle");
    } else {
      const page = pages[operation.pageIndex];
      const coordinateSpace = coordinate.coordinateSpace || {};
      const isCropRelative = coordinateSpace.pageBox === "crop";
      regions.push({
        operationID: operation.id,
        pageIndex: operation.pageIndex,
        rect: normalizeRect({
          x: rect.x + (isCropRelative ? page.cropBox.x : 0),
          y: rect.y + (isCropRelative ? page.cropBox.y : 0),
          width: rect.width,
          height: rect.height
        })
      });
    }
  }
  return { regions, issues };
}

function displayRectForPageRect(rect, page, pageWidth = page.cropBox.width, pageHeight = page.cropBox.height) {
  const local = {
    x: rect.x - page.cropBox.x,
    y: rect.y - page.cropBox.y,
    width: rect.width,
    height: rect.height
  };
  const points = [
    [local.x, local.y],
    [local.x + local.width, local.y],
    [local.x, local.y + local.height],
    [local.x + local.width, local.y + local.height]
  ].map(([x, y]) => {
    switch (page.rotation) {
      case 90: return [y, x];
      case 180: return [pageWidth - x, y];
      case 270: return [pageHeight - y, pageWidth - x];
      default: return [x, pageHeight - y];
    }
  });
  const xs = points.map(([x]) => x);
  const ys = points.map(([, y]) => y);
  return { x: Math.min(...xs), y: Math.min(...ys), width: Math.max(...xs) - Math.min(...xs), height: Math.max(...ys) - Math.min(...ys) };
}

function outsideTextWords(bboxPage, page, regions) {
  const pageRegions = regions.filter((region) => region.pageIndex === page.pageIndex)
    .map((region) => displayRectForPageRect(region.rect, page));
  return bboxPage.words.filter((word) => !pageRegions.some((region) => rectIntersects(word.rect, region, 0.5)));
}

function textComparison(sourceBBox, outputBBox, pages, regions) {
  if (sourceBBox.length !== outputBBox.length || sourceBBox.length !== pages.length) {
    return { status: "failed", message: "Poppler text pages could not be aligned.", pages: [] };
  }
  const pageResults = pages.map((page, index) => {
    const sourceOutside = outsideTextWords(sourceBBox[index], page, regions);
    const outputOutside = outsideTextWords(outputBBox[index], page, regions);
    const source = normalizedTextHash(sourceOutside);
    const output = normalizedTextHash(outputOutside);
    return {
      pageIndex: index,
      operationIDs: regions.filter((region) => region.pageIndex === index).map((region) => region.operationID),
      source,
      output,
      equal: source.textHash === output.textHash && source.wordCount === output.wordCount
    };
  });
  const failed = pageResults.filter((page) => !page.equal);
  return {
    status: failed.length ? "failed" : "passed",
    message: failed.length ? `${failed.length} page(s) changed outside authorized Poppler text regions.` : "Poppler text outside authorized regions is unchanged.",
    pages: pageResults
  };
}

function parsePPM(buffer) {
  let offset = 0;
  function token() {
    while (offset < buffer.length && /\s/.test(String.fromCharCode(buffer[offset]))) offset += 1;
    if (buffer[offset] === 35) {
      while (offset < buffer.length && buffer[offset] !== 10) offset += 1;
      return token();
    }
    const start = offset;
    while (offset < buffer.length && !/\s/.test(String.fromCharCode(buffer[offset]))) offset += 1;
    return buffer.subarray(start, offset).toString("ascii");
  }
  const magic = token();
  const width = Number(token());
  const height = Number(token());
  const max = Number(token());
  if (magic !== "P6" || !width || !height || max !== 255) throw new Error("Unsupported Poppler PPM output.");
  while (offset < buffer.length && /\s/.test(String.fromCharCode(buffer[offset]))) offset += 1;
  return { width, height, pixels: buffer.subarray(offset), channels: 3 };
}

function renderPage(filePath, pageIndex, tempDirectory, password) {
  const prefix = path.join(tempDirectory, `page-${pageIndex + 1}`);
  const args = ["-cropbox", "-r", String(DEFAULT_SCALE * 72), "-f", String(pageIndex + 1), "-l", String(pageIndex + 1), "-singlefile"];
  if (password) args.unshift("-upw", password);
  args.push(filePath, prefix);
  const result = runTool("pdftoppm", args, { allowFailure: true });
  const ppmPath = `${prefix}.ppm`;
  if (result.status === "failed" || !fs.existsSync(ppmPath)) return null;
  return parsePPM(fs.readFileSync(ppmPath));
}

function rasterComparison(sourcePath, outputPath, pages, regions, password) {
  const tempDirectory = fs.mkdtempSync(path.join(os.tmpdir(), "pdf-editor-preservation-"));
  try {
    const pageResults = pages.map((page) => {
      const source = renderPage(sourcePath, page.pageIndex, tempDirectory, password);
      const output = renderPage(outputPath, page.pageIndex, tempDirectory, password);
      if (!source || !output) return { pageIndex: page.pageIndex, status: "unknown", message: "Poppler could not render both pages." };
      if (source.width !== output.width || source.height !== output.height) {
        return { pageIndex: page.pageIndex, status: "failed", message: "Rendered page dimensions changed." };
      }
      const pageRegions = regions.filter((region) => region.pageIndex === page.pageIndex)
        .map((region) => displayRectForPageRect(region.rect, page));
      let comparedPixelCount = 0;
      let changedPixelCount = 0;
      let maximumChannelDelta = 0;
      const pixelsPerPoint = source.width / (page.rotation % 180 === 0 ? page.cropBox.width : page.cropBox.height);
      for (let y = 0; y < source.height; y += 1) {
        for (let x = 0; x < source.width; x += 1) {
          const point = { x: x + 0.5, y: y + 0.5 };
          if (pageRegions.some((region) => rectIntersects(region, { x: point.x / pixelsPerPoint, y: point.y / pixelsPerPoint, width: 0, height: 0 }, 1))) continue;
          comparedPixelCount += 1;
          const index = (y * source.width + x) * source.channels;
          let changed = false;
          for (let channel = 0; channel < source.channels; channel += 1) {
            const delta = Math.abs(source.pixels[index + channel] - output.pixels[index + channel]);
            maximumChannelDelta = Math.max(maximumChannelDelta, delta);
            if (delta > DEFAULT_CHANNEL_TOLERANCE) changed = true;
          }
          if (changed) changedPixelCount += 1;
        }
      }
      const outsidePixelRatio = comparedPixelCount ? changedPixelCount / comparedPixelCount : 0;
      return {
        pageIndex: page.pageIndex,
        status: outsidePixelRatio === 0 ? "passed" : "failed",
        comparedPixelCount,
        changedPixelCount,
        outsidePixelRatio,
        maximumChannelDelta,
        operationIDs: regions.filter((region) => region.pageIndex === page.pageIndex).map((region) => region.operationID)
      };
    });
    const failed = pageResults.filter((page) => page.status === "failed");
    const unknown = pageResults.filter((page) => page.status === "unknown");
    return {
      status: failed.length ? "failed" : unknown.length ? "unknown" : "passed",
      message: failed.length ? `${failed.length} page(s) changed outside authorized Poppler raster regions.` : unknown.length ? "Poppler raster comparison could not complete." : "Poppler raster output is unchanged outside authorized regions.",
      scale: DEFAULT_SCALE,
      channelTolerance: DEFAULT_CHANNEL_TOLERANCE,
      pages: pageResults
    };
  } finally {
    fs.rmSync(tempDirectory, { recursive: true, force: true });
  }
}

function reopenEvidence(filePath, password) {
  const facts = pageInfo(filePath, password);
  const textArgs = [];
  if (password) textArgs.push("-upw", password);
  const text = runTool("pdftotext", [...textArgs, filePath, "-"], { allowFailure: true });
  const qpdfArgs = password ? ["--password=" + password, "--check", filePath] : ["--check", filePath];
  const qpdf = runTool("qpdf", qpdfArgs, { allowFailure: true });
  return {
    status: facts.status === "passed" && text.status === "passed" ? "passed" : "failed",
    pageFacts: facts,
    textExtraction: { status: text.status },
    structuralCheck: { status: qpdf.status },
    diagnostic: facts.status === "failed" ? facts.diagnostic : text.status === "failed" ? "Poppler pdftotext could not reopen the PDF." : qpdf.status === "failed" ? "qpdf reported a structural warning or failure; Poppler reopen evidence is separate." : null
  };
}

export function compareIndependentPreservation({ sourcePath, outputPath, operations = [], password = null }) {
  const sourceInfo = pageInfo(sourcePath, password);
  const outputInfo = pageInfo(outputPath, password);
  if (sourceInfo.status !== "passed" || outputInfo.status !== "passed") {
    return { status: "failed", sourceDigest: sha256File(sourcePath), outputDigest: sha256File(outputPath), sourceReopen: sourceInfo, outputReopen: outputInfo, text: { status: "unknown" }, raster: { status: "unknown" } };
  }
  const regions = operationRegions(operations, sourceInfo.pages);
  if (regions.issues.length) {
    return { status: "unknown", sourceDigest: sha256File(sourcePath), outputDigest: sha256File(outputPath), sourceReopen: sourceInfo, outputReopen: outputInfo, text: { status: "unknown", message: "Independent preservation regions were not authorized." }, raster: { status: "unknown", message: "Independent preservation regions were not authorized." } };
  }
  if (sourceInfo.pages.length !== outputInfo.pages.length) {
    return { status: "failed", sourceDigest: sha256File(sourcePath), outputDigest: sha256File(outputPath), sourceReopen: sourceInfo, outputReopen: outputInfo, text: { status: "failed", message: "Page count changed." }, raster: { status: "failed", message: "Page count changed." } };
  }
  const sourceBBoxRun = runTool("pdftotext", ["-bbox-layout", ...(password ? ["-upw", password] : []), sourcePath, "-"], { allowFailure: true });
  const outputBBoxRun = runTool("pdftotext", ["-bbox-layout", ...(password ? ["-upw", password] : []), outputPath, "-"], { allowFailure: true });
  const text = sourceBBoxRun.status === "passed" && outputBBoxRun.status === "passed"
    ? textComparison(parseBBoxDocument(sourceBBoxRun.stdout), parseBBoxDocument(outputBBoxRun.stdout), sourceInfo.pages, regions.regions)
    : { status: "unknown", message: "Poppler bounding-box extraction could not complete.", pages: [] };
  const raster = rasterComparison(sourcePath, outputPath, sourceInfo.pages, regions.regions, password);
  return {
    status: text.status === "failed" || raster.status === "failed" ? "failed" : text.status === "unknown" || raster.status === "unknown" ? "unknown" : "passed",
    sourceDigest: sha256File(sourcePath),
    outputDigest: sha256File(outputPath),
    sourceReopen: reopenEvidence(sourcePath, password),
    outputReopen: reopenEvidence(outputPath, password),
    text,
    raster
  };
}

export function independentViewerReopen({ filePath, password = null }) {
  return {
    filePath,
    digest: sha256File(filePath),
    toolVersions: {
      pdfinfo: toolVersion("pdfinfo", ["-v"]),
      pdftotext: toolVersion("pdftotext", ["-v"]),
      pdftoppm: toolVersion("pdftoppm", ["-v"]),
      qpdf: toolVersion("qpdf", ["--version"])
    },
    reopen: reopenEvidence(filePath, password)
  };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const args = Object.fromEntries(process.argv.slice(2).reduce((pairs, value, index, values) => {
    if (!value.startsWith("--")) return pairs;
    pairs.push([value.slice(2), values[index + 1]]);
    return pairs;
  }, []));
  if (!args.source || !args.output) throw new Error("Usage: node benchmark/independent-preservation-validator.mjs --source SOURCE --output OUTPUT [--password PASSWORD] [--operations-json FILE]");
  const operations = args["operations-json"] ? JSON.parse(fs.readFileSync(args["operations-json"], "utf8")) : [];
  const report = compareIndependentPreservation({ sourcePath: args.source, outputPath: args.output, password: args.password || null, operations });
  const serialized = `${JSON.stringify(report, null, 2)}\n`;
  if (args.report) fs.writeFileSync(args.report, serialized);
  process.stdout.write(serialized);
  process.exitCode = report.status === "passed" ? 0 : 1;
}
