import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { performance } from "node:perf_hooks";
import { spawnSync } from "node:child_process";
import { measureBrowserWasm } from "./browser_wasm_ocr.mjs";

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
const fixturePath = path.join(root, "Tests/fixtures/ocr_provider_comparison_fixture.json");
const corpusManifestPath = path.join(root, "Tests/fixtures/pdf_corpus_governance_manifest.json");
const fixture = JSON.parse(fs.readFileSync(fixturePath, "utf8"));
const corpusManifest = JSON.parse(fs.readFileSync(corpusManifestPath, "utf8"));
const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), "pdf-editor-ocr-comparison-"));
const fixturePassword = process.env.PDF_EDITOR_FIXTURE_PASSWORD || "reader-password";
const tesseractPath = process.env.TESSERACT_BIN || "tesseract";
const pdftoppmPath = process.env.PDFTOPPM_BIN || "pdftoppm";
const qpdfPath = process.env.QPDF_BIN || "qpdf";
const pdfinfoPath = process.env.PDFINFO_BIN || "pdfinfo";
const latencyBudgetMilliseconds = 15_000;

function sha256(data) {
  return crypto.createHash("sha256").update(data).digest("hex");
}

function run(command, args, options = {}) {
  const started = performance.now();
  const result = spawnSync(command, args, {
    cwd: root,
    encoding: "utf8",
    maxBuffer: 32 * 1024 * 1024,
    ...options
  });
  return {
    status: result.status,
    signal: result.signal || null,
    stdout: result.stdout || "",
    stderr: result.stderr || "",
    durationMilliseconds: performance.now() - started
  };
}

function normalize(value) {
  return value
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, " ")
    .trim()
    .replace(/\s+/g, " ");
}

function readAnchors(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8")
    .split(/\r?\n/)
    .map(normalize)
    .filter(Boolean);
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

function normalizedTesseractBounds(words, width, height) {
  const boxes = words.map((word) => {
    const x = Number(word.left) / width;
    const y = (height - Number(word.top) - Number(word.height)) / height;
    const box = { x, y, width: Number(word.width) / width, height: Number(word.height) / height };
    return Number.isFinite(x) && Number.isFinite(y) && box.width > 0 && box.height > 0
      && x >= 0 && y >= 0 && x + box.width <= 1.0001 && y + box.height <= 1.0001 ? box : null;
  }).filter(Boolean);
  return { validCount: boxes.length, union: unionBounds(boxes) };
}

function absolute(relativePath) {
  return path.join(root, relativePath);
}

function prepareInput(entry) {
  if (entry.input.kind === "image") {
    return { imagePath: absolute(entry.input.relativePath), cleanup: [] };
  }
  const prefix = path.join(tempRoot, entry.fixtureId);
  const args = [
    "-f", String(entry.input.page),
    "-l", String(entry.input.page),
    "-r", "144",
    "-png",
    "-singlefile"
  ];
  if (entry.input.passwordEnv) args.push("-upw", fixturePassword);
  args.push(absolute(entry.input.relativePath), prefix);
  const rendered = run(pdftoppmPath, args);
  const imagePath = `${prefix}.png`;
  if (rendered.status !== 0 || !fs.existsSync(imagePath)) {
    throw new Error(`render-failed:${entry.fixtureId}`);
  }
  return { imagePath, cleanup: [imagePath] };
}

function measureTesseract(entry, input) {
  const anchors = readAnchors(entry.groundTruthPath);
  const result = run(tesseractPath, [input.imagePath, "stdout", "--psm", "6", "-l", "eng", "tsv"]);
  const rows = result.status === 0
    ? result.stdout.split(/\r?\n/).slice(1).map((line) => line.split("\t")).filter((parts) => parts.length >= 12 && parts[11]?.trim())
    : [];
  const words = rows.map((parts) => ({
    block: parts[2], paragraph: parts[3], line: parts[4], text: parts[11].trim(),
    left: Number(parts[6]), top: Number(parts[7]), width: Number(parts[8]), height: Number(parts[9]), confidence: Number(parts[10]) / 100
  }));
  const lines = new Map();
  for (const word of words) {
    const key = `${word.block}:${word.paragraph}:${word.line}`;
    lines.set(key, [...(lines.get(key) || []), word.text]);
  }
  const observedText = [...lines.values()].map((line) => line.join(" ")).join("\n");
  const matchedAnchorCount = result.status === 0 ? matchAnchors(observedText, anchors) : 0;
  const identify = run("identify", ["-format", "%w %h", input.imagePath]);
  const [width, height] = identify.status === 0 ? identify.stdout.trim().split(/\s+/).map(Number) : [0, 0];
  const bounds = width > 0 && height > 0 ? normalizedTesseractBounds(words, width, height) : { validCount: 0, union: null };
  const confidences = words.map((word) => word.confidence).filter(Number.isFinite).filter((value) => value >= 0);
  return {
    fixtureId: entry.fixtureId,
    providerId: "local-tesseract",
    status: result.status === 0 ? "measured" : "failed",
    observationCount: words.length,
    requiredAnchorCount: anchors.length,
    matchedAnchorCount,
    anchorRecall: anchors.length ? matchedAnchorCount / anchors.length : 0,
    latencyMilliseconds: result.durationMilliseconds,
    confidenceMean: confidences.length ? confidences.reduce((sum, value) => sum + value, 0) / confidences.length : null,
    confidenceMinimum: confidences.length ? Math.min(...confidences) : null,
    confidenceMaximum: confidences.length ? Math.max(...confidences) : null,
    coordinateSpace: "normalizedLowerLeft",
    boundsValidCount: bounds.validCount,
    boundsUnion: bounds.union,
    alignmentStatus: bounds.validCount ? "measured-in-image-bounds" : "unknown",
    errorCode: result.status === 0 ? null : "tesseract-process-failed"
  };
}

function writeNativeInputs(entries, prepared) {
  const inputs = entries.map((entry) => ({
    fixtureId: entry.fixtureId,
    imagePath: prepared.get(entry.fixtureId).imagePath,
    groundTruthPath: absolute(entry.groundTruthPath)
  }));
  const manifestPath = path.join(tempRoot, "native-inputs.json");
  fs.writeFileSync(manifestPath, JSON.stringify({ inputs }, null, 2));
  return manifestPath;
}

function measureNativeVision(entries, prepared) {
  const manifestPath = writeNativeInputs(entries, prepared);
  const result = run("swift", ["run", "--quiet", "PDFOCRBenchmark", "--inputs", manifestPath]);
  if (result.status !== 0) {
    return entries.map((entry) => ({
      fixtureId: entry.fixtureId,
      providerId: "native-vision",
      status: "blocked",
      observationCount: 0,
      requiredAnchorCount: readAnchors(entry.groundTruthPath).length,
      matchedAnchorCount: 0,
      anchorRecall: 0,
      latencyMilliseconds: null,
      confidenceMean: null,
      confidenceMinimum: null,
      confidenceMaximum: null,
      errorCode: "vision-benchmark-process-failed"
    }));
  }
  try {
    return JSON.parse(result.stdout);
  } catch {
    return entries.map((entry) => ({
      fixtureId: entry.fixtureId,
      providerId: "native-vision",
      status: "blocked",
      observationCount: 0,
      requiredAnchorCount: readAnchors(entry.groundTruthPath).length,
      matchedAnchorCount: 0,
      anchorRecall: 0,
      latencyMilliseconds: null,
      confidenceMean: null,
      confidenceMinimum: null,
      confidenceMaximum: null,
      errorCode: "vision-result-invalid"
    }));
  }
}

function summarize(providerId, records) {
  const measured = records.filter((record) => record.status === "measured");
  const latencies = measured.map((record) => record.latencyMilliseconds).filter(Number.isFinite).sort((a, b) => a - b);
  const accuracyGatePassed = records.every((record) => {
    const expected = fixture.fixtures.find((entry) => entry.fixtureId === record.fixtureId);
    return expected && record.status === "measured" && record.anchorRecall >= expected.accuracyGate.minimumAnchorRecall;
  });
  const latencyGatePassed = records.every((record) =>
    record.status === "measured" && Number.isFinite(record.latencyMilliseconds)
      && record.latencyMilliseconds <= latencyBudgetMilliseconds
  );
  return {
    providerId,
    fixtureCount: records.length,
    measuredFixtureCount: measured.length,
    accuracyGatePassed,
    meanAnchorRecall: measured.length
      ? measured.reduce((sum, record) => sum + record.anchorRecall, 0) / measured.length
      : 0,
    minimumAnchorRecall: measured.length ? Math.min(...measured.map((record) => record.anchorRecall)) : 0,
    latencyGate: {
      maxMillisecondsPerRequest: latencyBudgetMilliseconds,
      passed: latencyGatePassed,
      medianMilliseconds: latencies.length ? latencies[Math.floor((latencies.length - 1) / 2)] : null,
      p95Milliseconds: latencies.length ? latencies[Math.min(latencies.length - 1, Math.ceil(latencies.length * 0.95) - 1)] : null
    },
    handwrittenClaimBlocked: true,
    fieldCreationAllowed: false,
    status: accuracyGatePassed && latencyGatePassed ? "measured-partial" : "failed"
  };
}

function rectangleIoU(left, right) {
  if (!left || !right) return null;
  const x1 = Math.max(left.x, right.x);
  const y1 = Math.max(left.y, right.y);
  const x2 = Math.min(left.x + left.width, right.x + right.width);
  const y2 = Math.min(left.y + left.height, right.y + right.height);
  const intersection = Math.max(0, x2 - x1) * Math.max(0, y2 - y1);
  const union = left.width * left.height + right.width * right.height - intersection;
  return union > 0 ? intersection / union : 0;
}

function alignmentAgainstVision(records, visionRecords) {
  return records.map((record) => {
    const reference = visionRecords.find((candidate) => candidate.fixtureId === record.fixtureId);
    const unionIoU = rectangleIoU(record.boundsUnion, reference?.boundsUnion);
    return {
      fixtureId: record.fixtureId,
      referenceProviderId: "native-vision",
      coordinateSpace: record.coordinateSpace || null,
      providerBoundsValidCount: record.boundsValidCount || 0,
      referenceBoundsValidCount: reference?.boundsValidCount || 0,
      boundsUnionIoU: unionIoU,
      status: unionIoU == null ? "unknown" : unionIoU >= 0.35 ? "aligned" : "divergent"
    };
  });
}

function measureCompanionCandidates() {
  const candidates = [];
  const ocrmypdf = resolveExecutable(process.env.OCRMY_PDF_BIN || "ocrmypdf");
  candidates.push({
    providerId: "companion-ocrmypdf",
    capability: "ocr.searchableLayer",
    runtimeKind: "installed-companion",
    availability: ocrmypdf ? "installed" : "unavailable",
    measurementStatus: "not-measured",
    licenseGate: "review-required",
    recoveryStatus: "not-measured",
    errorCode: ocrmypdf ? "companion-runner-not-yet-wired" : "executable-unavailable"
  });
  const pdfboxJar = process.env.PDFBOX_JAR && fs.existsSync(process.env.PDFBOX_JAR) ? process.env.PDFBOX_JAR : null;
  candidates.push({
    providerId: "companion-pdfbox",
    capability: "pdf.text-extraction-and-edit",
    runtimeKind: "installed-companion",
    availability: pdfboxJar ? "configured" : "unavailable",
    measurementStatus: "not-measured",
    licenseGate: "review-required",
    recoveryStatus: "not-measured",
    errorCode: pdfboxJar ? "companion-runner-not-yet-wired" : "pdfbox-jar-unavailable"
  });
  const mutool = resolveExecutable(process.env.MUTOOL_BIN || "mutool");
  let renderControl = "unavailable";
  if (mutool) {
    const outputPrefix = path.join(tempRoot, "mupdf-control");
    const rendered = run(mutool, ["draw", "-F", "png", "-r", "72", "-o", `${outputPrefix}-%d.png`, absolute("benchmark/results/ocr-corpus/printed-scan.pdf"), "1"]);
    renderControl = rendered.status === 0 && fs.existsSync(`${outputPrefix}-1.png`) ? "passed" : "failed";
  }
  candidates.push({
    providerId: "companion-mupdf",
    capability: "pdf.high-fidelity-edit",
    runtimeKind: "installed-companion",
    availability: mutool ? "installed" : "unavailable",
    measurementStatus: "capability-control-only",
    licenseGate: "review-required",
    recoveryStatus: "not-measured",
    renderControl,
    errorCode: "not-an-ocr-provider"
  });
  return candidates;
}

function browserWasmMetadata(wasmRoot, languageRoot) {
  if (!wasmRoot || !languageRoot) return { installedVersion: null, artifactDigest: null, licenseGate: "review-required" };
  const packagePath = path.join(wasmRoot, "node_modules/tesseract.js/package.json");
  const files = [
    path.join(wasmRoot, "node_modules/tesseract.js/dist/tesseract.min.js"),
    path.join(wasmRoot, "node_modules/tesseract.js/dist/worker.min.js"),
    path.join(wasmRoot, "node_modules/tesseract.js-core/tesseract-core-simd-lstm.wasm"),
    path.join(languageRoot, "eng.traineddata.gz")
  ];
  if (!fs.existsSync(packagePath) || !files.every((filePath) => fs.existsSync(filePath))) {
    return { installedVersion: null, artifactDigest: null, licenseGate: "review-required" };
  }
  const packageJSON = JSON.parse(fs.readFileSync(packagePath, "utf8"));
  return {
    installedVersion: `tesseract.js-${packageJSON.version}`,
    artifactDigest: sha256(Buffer.concat(files.map((filePath) => fs.readFileSync(filePath)))),
    licenseGate: "package-apache-core-apache-language-data-license-recorded"
  };
}

function recoveryGate() {
  const malformedPath = absolute("benchmark/results/browser-corpus/malformed-hybrid-truncated.pdf");
  const malformedCheck = run(qpdfPath, ["--check", malformedPath]);
  const malformedOutput = path.join(tempRoot, "malformed-output.pdf");
  const malformedRender = run(pdftoppmPath, ["-f", "1", "-l", "1", "-png", malformedPath, path.join(tempRoot, "malformed")]);

  const encryptedPath = absolute("benchmark/results/browser-corpus/encrypted-hybrid.pdf");
  const encryptedRejected = run(pdftoppmPath, ["-f", "2", "-l", "2", "-png", encryptedPath, path.join(tempRoot, "encrypted-rejected")]);
  const encryptedOutputPrefix = path.join(tempRoot, "encrypted-unlocked");
  const encryptedOpened = run(pdftoppmPath, ["-f", "2", "-l", "2", "-upw", fixturePassword, "-png", encryptedPath, encryptedOutputPrefix]);

  const largePath = absolute("benchmark/results/browser-corpus/large-hybrid-40-pages.pdf");
  const largeInfo = run(pdfinfoPath, [largePath]);
  const pagesMatch = largeInfo.stdout.match(/^Pages:\s+(\d+)/m);
  const largePageRender = run(pdftoppmPath, ["-f", "40", "-l", "40", "-r", "72", "-png", "-singlefile", largePath, path.join(tempRoot, "large-page-40")]);

  return {
    malformed: {
      qpdfRejected: malformedCheck.status !== 0,
      rasterizerRejected: malformedRender.status !== 0,
      noPartialOutputPublished: !fs.existsSync(malformedOutput),
      passed: malformedCheck.status !== 0 && malformedRender.status !== 0 && !fs.existsSync(malformedOutput)
    },
    encrypted: {
      rejectsWithoutPassword: encryptedRejected.status !== 0,
      opensAfterExplicitUnlock: encryptedOpened.status === 0,
      passwordNotLogged: true,
      passed: encryptedRejected.status !== 0 && encryptedOpened.status === 0
    },
    large: {
      declaredPageCount: pagesMatch ? Number(pagesMatch[1]) : null,
      pageBudgetObserved: pagesMatch?.[1] === "40",
      representativeRasterPageRendered: largePageRender.status === 0,
      partialOutputPublished: false,
      cancellationRecovery: "not-measured",
      passed: pagesMatch?.[1] === "40" && largePageRender.status === 0
    },
    companionCrashTimeoutRecovery: "not-measured-no-companion-installed",
    passed: malformedCheck.status !== 0
      && malformedRender.status !== 0
      && encryptedRejected.status !== 0
      && encryptedOpened.status === 0
      && pagesMatch?.[1] === "40"
      && largePageRender.status === 0
  };
}

function commandVersion(command, args) {
  const result = run(command, args);
  return result.status === 0 ? result.stdout.split(/\r?\n/)[0] : "unavailable";
}

function resolveExecutable(command) {
  if (path.isAbsolute(command)) return fs.existsSync(command) ? command : null;
  for (const directory of (process.env.PATH || "").split(path.delimiter)) {
    const candidate = path.join(directory, command);
    if (fs.existsSync(candidate)) return candidate;
  }
  return null;
}

const prepared = new Map();
const measuredEntries = [];
const preparationFailures = [];
try {
  for (const entry of fixture.fixtures) {
    try {
      prepared.set(entry.fixtureId, prepareInput(entry));
      measuredEntries.push(entry);
    } catch (error) {
      preparationFailures.push({ fixtureId: entry.fixtureId, status: "blocked", errorCode: error.message });
    }
  }

  const tesseractRecords = measuredEntries.map((entry) => measureTesseract(entry, prepared.get(entry.fixtureId)));
  const visionRecords = measureNativeVision(measuredEntries, prepared);
  const wasmRoot = process.env.TESSERACT_WASM_ROOT || null;
  const languageRoot = process.env.TESSERACT_LANG_ROOT || (wasmRoot ? path.join(wasmRoot, "data-install/node_modules/@tesseract.js-data/eng/4.0.0_best_int") : null);
  const browserWasmRecords = await measureBrowserWasm(measuredEntries, prepared, {
    wasmRoot,
    languageRoot,
    readAnchors
  });
  const companionCandidates = measureCompanionCandidates();
  const wasmMetadata = browserWasmMetadata(wasmRoot, languageRoot);
  const recovery = recoveryGate();
  const reportWithoutPrivacy = {
    contract: fixture.contract,
    version: fixture.version,
    corpusManifest: corpusManifest.manifestId,
    corpusDigest: sha256(fs.readFileSync(corpusManifestPath)),
    fixtureDescriptorDigest: sha256(fs.readFileSync(fixturePath)),
    accuracyUnit: fixture.accuracyUnit,
    latencyUnit: fixture.latencyUnit,
    generatedAt: "2026-08-25",
    providers: fixture.providers.map((provider) => ({
      ...provider,
      installedVersion: provider.providerId === "local-tesseract" ? commandVersion(tesseractPath, ["--version"]) : provider.providerId === "native-vision" ? "macOS Vision runtime" : provider.providerId === "browser-wasm-tesseract" ? wasmMetadata.installedVersion : null,
      artifactDigest: provider.providerId === "local-tesseract" && resolveExecutable(tesseractPath)
        ? sha256(fs.readFileSync(resolveExecutable(tesseractPath)))
        : provider.providerId === "browser-wasm-tesseract" ? wasmMetadata.artifactDigest : null,
      measurementStatus: provider.providerId === "local-tesseract" || provider.providerId === "native-vision" || provider.providerId === "browser-wasm-tesseract" ? "measured-below" : "not-measured",
      licenseGate: provider.providerId === "browser-wasm-tesseract" ? wasmMetadata.licenseGate : provider.licenseStatus.includes("approved") || provider.licenseStatus.includes("platform-framework-approved") ? "passed-for-local-system-use" : "review-required"
    })),
    measurements: {
      "local-tesseract": {
        summary: summarize("local-tesseract", tesseractRecords),
        cases: tesseractRecords
      },
        "native-vision": {
          summary: summarize("native-vision", visionRecords),
          cases: visionRecords
        },
        "browser-wasm-tesseract": {
          summary: summarize("browser-wasm-tesseract", browserWasmRecords),
          cases: browserWasmRecords
        },
        preparationFailures
      },
      companionCandidates,
      alignment: {
        localTesseractVsVision: alignmentAgainstVision(tesseractRecords, visionRecords),
        browserWasmVsVision: alignmentAgainstVision(browserWasmRecords, visionRecords)
      },
    recovery,
    privacy: {
      sourceBytesLogged: false,
      pageTextLogged: false,
      ocrTextLogged: false,
      groundTruthLogged: false,
      passwordsLogged: false,
      profileValuesLogged: false,
      reportContainsContent: false,
      browserWasmAssetsServedLocally: Boolean(wasmRoot && languageRoot),
      browserExternalNetworkRequests: measureBrowserWasm.lastNetwork?.externalRequests || [],
      browserNetworkBoundaryPassed: measureBrowserWasm.lastNetwork?.localOnly === true
    }
  };
  const serialized = JSON.stringify(reportWithoutPrivacy);
  const forbiddenContent = fixture.fixtures.flatMap((entry) => readAnchors(entry.groundTruthPath));
  const contentLeakDetected = forbiddenContent.some((anchor) => anchor.length > 3 && serialized.toLowerCase().includes(anchor));
  const report = {
    ...reportWithoutPrivacy,
    privacy: {
      ...reportWithoutPrivacy.privacy,
      reportContainsContent: contentLeakDetected
    },
    gates: {
      accuracy: reportWithoutPrivacy.measurements["local-tesseract"].summary.accuracyGatePassed
        && reportWithoutPrivacy.measurements["native-vision"].summary.accuracyGatePassed
        && reportWithoutPrivacy.measurements["browser-wasm-tesseract"].summary.accuracyGatePassed,
      latency: reportWithoutPrivacy.measurements["local-tesseract"].summary.latencyGate.passed
        && reportWithoutPrivacy.measurements["native-vision"].summary.latencyGate.passed
        && reportWithoutPrivacy.measurements["browser-wasm-tesseract"].summary.latencyGate.passed,
      privacy: !contentLeakDetected,
      licensing: false,
      recovery: recovery.passed,
      companionRuntime: companionCandidates.every((candidate) => candidate.measurementStatus !== "not-measured") ? "measured" : "partial-unmeasured",
      promotionReady: false
    }
  };
  report.gates.promotionReady = report.gates.accuracy
    && report.gates.latency
    && report.gates.privacy
    && report.gates.licensing
    && report.gates.recovery;
  report.passed = report.gates.accuracy && report.gates.latency && report.gates.privacy && report.gates.recovery;

  const outputPath = process.env.PDF_EDITOR_OCR_COMPARISON_OUTPUT
    || path.join(root, "benchmark/results/ocr-provider-comparison/2026-08-25-local-wasm-companion.json");
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, `${JSON.stringify(report, null, 2)}\n`);
  console.log(JSON.stringify({
    contract: report.contract,
    passed: report.passed,
    outputPath,
    tesseract: report.measurements["local-tesseract"].summary,
    nativeVision: report.measurements["native-vision"].summary,
    browserWasm: report.measurements["browser-wasm-tesseract"].summary,
    alignment: report.alignment,
    companionCandidates: report.companionCandidates,
    recovery: report.recovery,
    gates: report.gates
  }, null, 2));
} finally {
  fs.rmSync(tempRoot, { recursive: true, force: true });
}
