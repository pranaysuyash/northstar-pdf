import fs from "node:fs";
import http from "node:http";
import path from "node:path";
import { chromium } from "/Users/pranay/.agents/skills/testing/playwright-skill/node_modules/playwright/index.mjs";

function normalize(value) {
  return String(value || "")
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, " ")
    .trim()
    .replace(/\s+/g, " ");
}

function matchAnchors(output, anchors) {
  const observed = output.split(/\r?\n/).map(normalize).filter(Boolean);
  return anchors.filter((anchor) => observed.some((candidate) =>
    candidate.includes(anchor) || anchor.includes(candidate)
  )).length;
}

function unionBounds(boxes) {
  if (!boxes.length) return null;
  return boxes.slice(1).reduce((current, box) => ({
    x: Math.min(current.x, box.x),
    y: Math.min(current.y, box.y),
    width: Math.max(current.x + current.width, box.x + box.width) - Math.min(current.x, box.x),
    height: Math.max(current.y + current.height, box.y + box.height) - Math.min(current.y, box.y)
  }), boxes[0]);
}

function normalizeBounds(words, width, height) {
  const normalized = words.map((word) => {
    const bbox = word.bbox || {};
    const x0 = Number(bbox.x0);
    const y0 = Number(bbox.y0);
    const x1 = Number(bbox.x1);
    const y1 = Number(bbox.y1);
    if (![x0, y0, x1, y1].every(Number.isFinite) || x1 <= x0 || y1 <= y0) return null;
    const box = {
      x: x0 / width,
      // Tesseract.js image coordinates use a top-left origin. The shared OCR
      // contract uses normalized lower-left coordinates.
      y: (height - y1) / height,
      width: (x1 - x0) / width,
      height: (y1 - y0) / height
    };
    if (box.x < 0 || box.y < 0 || box.x + box.width > 1.0001 || box.y + box.height > 1.0001) return null;
    return box;
  }).filter(Boolean);
  return { boxes: normalized, union: unionBounds(normalized) };
}

function contentType(filePath) {
  if (filePath.endsWith(".js")) return "application/javascript";
  if (filePath.endsWith(".wasm")) return "application/wasm";
  if (filePath.endsWith(".gz")) return "application/gzip";
  if (filePath.endsWith(".png")) return "image/png";
  return "application/octet-stream";
}

function safeAsset(root, relativePath) {
  const candidate = path.resolve(root, relativePath);
  if (!candidate.startsWith(`${path.resolve(root)}${path.sep}`)) return null;
  return candidate;
}

async function startServer({ wasmRoot, languageRoot, images }) {
  const tesseractRoot = path.join(wasmRoot, "node_modules/tesseract.js");
  const coreRoot = path.join(wasmRoot, "node_modules/tesseract.js-core");
  const html = `<!doctype html><html><body><script src="/tesseract/tesseract.min.js"></script><script>
    window.runOCR = async (imagePath) => {
      const worker = await Tesseract.createWorker("eng", 1, {
        workerPath: "/tesseract/worker.min.js",
        corePath: "/core/tesseract-core-simd-lstm.wasm.js",
        langPath: "/lang",
        logger: () => {}
      });
      const image = await new Promise((resolve, reject) => {
        const element = new Image();
        element.onload = () => resolve(element);
        element.onerror = reject;
        element.src = imagePath;
      });
      const started = performance.now();
      const result = await worker.recognize(image);
      const elapsed = performance.now() - started;
      const data = result.data || {};
      const words = (data.words || []).map((word) => ({
        text: word.text || "",
        // Tesseract.js reports percentages. The shared OCR contract uses
        // calibrated confidence in the closed interval [0, 1].
        confidence: Number(word.confidence) / 100,
        bbox: word.bbox || null
      }));
      const lines = (data.lines || []).map((line) => line.text || "");
      await worker.terminate();
      return { width: image.naturalWidth, height: image.naturalHeight, elapsed, words, lines };
    };
  </script></body></html>`;
  const server = http.createServer((request, response) => {
    const requestPath = new URL(request.url, "http://127.0.0.1").pathname;
    let filePath = null;
    if (requestPath === "/") {
      response.writeHead(200, { "content-type": "text/html; charset=utf-8" });
      response.end(html);
      return;
    }
    if (requestPath.startsWith("/tesseract/")) filePath = safeAsset(tesseractRoot, `dist/${requestPath.slice("/tesseract/".length)}`);
    else if (requestPath.startsWith("/core/")) filePath = safeAsset(coreRoot, requestPath.slice("/core/".length));
    else if (requestPath.startsWith("/lang/")) filePath = safeAsset(languageRoot, requestPath.slice("/lang/".length));
    else if (requestPath.startsWith("/image/")) filePath = images.get(requestPath.slice("/image/".length)) || null;
    if (!filePath || !fs.existsSync(filePath)) {
      response.writeHead(404);
      response.end();
      return;
    }
    response.writeHead(200, { "content-type": contentType(filePath), "cache-control": "no-store" });
    fs.createReadStream(filePath).pipe(response);
  });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const address = server.address();
  return { server, baseURL: `http://127.0.0.1:${address.port}` };
}

function blockedRecords(entries, errorCode) {
  return entries.map((entry) => ({
    fixtureId: entry.fixtureId,
    providerId: "browser-wasm-tesseract",
    status: "blocked",
    observationCount: 0,
    requiredAnchorCount: 0,
    matchedAnchorCount: 0,
    anchorRecall: 0,
    latencyMilliseconds: null,
    confidenceMean: null,
    confidenceMinimum: null,
    confidenceMaximum: null,
    coordinateSpace: null,
    boundsValidCount: 0,
    boundsUnion: null,
    alignmentStatus: "unknown",
    errorCode
  }));
}

export async function measureBrowserWasm(entries, prepared, { wasmRoot, languageRoot, readAnchors }) {
  if (!wasmRoot || !languageRoot) return blockedRecords(entries, "browser-wasm-assets-not-configured");
  const workerScript = path.join(wasmRoot, "node_modules/tesseract.js/dist/worker.min.js");
  const coreScript = path.join(wasmRoot, "node_modules/tesseract.js-core/tesseract-core-simd-lstm.wasm.js");
  const coreWasm = path.join(wasmRoot, "node_modules/tesseract.js-core/tesseract-core-simd-lstm.wasm");
  const languageData = path.join(languageRoot, "eng.traineddata.gz");
  if (![workerScript, coreScript, coreWasm, languageData].every((filePath) => fs.existsSync(filePath))) {
    return blockedRecords(entries, "browser-wasm-assets-incomplete");
  }
  const images = new Map(entries.map((entry) => [`${entry.fixtureId}.png`, prepared.get(entry.fixtureId).imagePath]));
  const { server, baseURL } = await startServer({ wasmRoot, languageRoot, images });
  const browser = await chromium.launch({ channel: "chrome", headless: true });
  const page = await browser.newPage();
  const externalRequests = new Set();
  page.on("request", (request) => {
    if (new URL(request.url()).origin !== new URL(baseURL).origin) externalRequests.add(new URL(request.url()).origin);
  });
  const records = [];
  try {
    await page.goto(baseURL, { waitUntil: "load" });
    await page.waitForFunction(() => Boolean(window.Tesseract?.createWorker), undefined, { timeout: 30_000 });
    for (const entry of entries) {
      const anchors = readAnchors(entry.groundTruthPath);
      try {
        const raw = await page.evaluate((fixtureId) => window.runOCR(`/image/${encodeURIComponent(fixtureId)}.png`), entry.fixtureId);
        const lineText = raw.lines.length ? raw.lines.join("\n") : raw.words.map((word) => word.text).join(" ");
        const bounds = normalizeBounds(raw.words, raw.width, raw.height);
        const confidences = raw.words.map((word) => word.confidence).filter(Number.isFinite);
        records.push({
          fixtureId: entry.fixtureId,
          providerId: "browser-wasm-tesseract",
          status: "measured",
          observationCount: raw.words.length,
          requiredAnchorCount: anchors.length,
          matchedAnchorCount: matchAnchors(lineText, anchors),
          anchorRecall: anchors.length ? matchAnchors(lineText, anchors) / anchors.length : 0,
          latencyMilliseconds: raw.elapsed,
          confidenceMean: confidences.length ? confidences.reduce((sum, value) => sum + value, 0) / confidences.length : null,
          confidenceMinimum: confidences.length ? Math.min(...confidences) : null,
          confidenceMaximum: confidences.length ? Math.max(...confidences) : null,
          coordinateSpace: "normalizedLowerLeft",
          boundsValidCount: bounds.boxes.length,
          boundsUnion: bounds.union,
          alignmentStatus: bounds.boxes.length ? "measured-in-image-bounds" : "unknown",
          errorCode: null
        });
      } catch {
        records.push({ ...blockedRecords([entry], "browser-wasm-recognition-failed")[0], requiredAnchorCount: anchors.length });
      }
    }
  } finally {
    await browser.close();
    await new Promise((resolve) => server.close(resolve));
  }
  measureBrowserWasm.lastNetwork = { externalRequests: [...externalRequests], localOnly: externalRequests.size === 0 };
  return records;
}
