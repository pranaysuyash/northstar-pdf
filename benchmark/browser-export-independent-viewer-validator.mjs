import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { compareIndependentPreservation, independentViewerReopen } from "./independent-preservation-validator.mjs";

/**
 * Cross-renderer report for a browser export.
 *
 * PDF.js remains the browser inspection and validation authority. Poppler is
 * deliberately invoked through the independent preservation validator so the
 * browser gate and the outside-process render do not share a rendering path.
 * This module only joins the two evidence streams and never promotes a
 * provider disagreement to a pass.
 */

export const INDEPENDENT_BROWSER_VIEWER_CONTRACT = {
  name: "pdf-editor.browser-export-independent-viewer",
  version: { major: 1, minor: 1 },
  engine: "poppler",
  normalization: {
    statusValues: ["passed", "failed", "unknown", "skipped", "unavailable", "expectedFailure"],
    ignoredFields: [
      "provider-specific check IDs",
      "provider versions",
      "generated timestamps",
      "source and output byte digests when comparing visual/text verdicts"
    ],
    preservedFields: [
      "sourceDigest",
      "browserExportDigest",
      "page geometry",
      "outside-region text evidence",
      "outside-region raster evidence",
      "PDF.js check status",
      "normalized provider metrics",
      "independent renderer status",
      "provider disagreement"
    ]
  }
};

function sha256File(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

function fileNameFor(relativePath, suffix = "") {
  return relativePath.replaceAll("/", "__").replace(/\.pdf$/i, `${suffix}.pdf`);
}

function statusOf(value) {
  if (["passed", "failed", "unknown", "skipped", "unavailable"].includes(value)) return value;
  return "unknown";
}

function checkFor(bundle, kind) {
  return bundle?.validation?.checks?.find((check) => check?.kind === kind) || null;
}

function finiteOrNull(value) {
  return Number.isFinite(Number(value)) ? Number(value) : null;
}

function normalizeMetrics(kind, metrics, provider) {
  if (!metrics || typeof metrics !== "object") return null;
  const normalized = {
    provider,
    basis: metrics.basis || `${provider}-${kind}`,
    sourcePageCount: finiteOrNull(metrics.sourcePageCount),
    comparedPageCount: finiteOrNull(metrics.comparedPageCount),
    changedPageCount: finiteOrNull(metrics.changedPageCount),
    operationCount: finiteOrNull(metrics.operationCount)
  };
  if (kind === "raster") {
    normalized.comparedPixelCount = finiteOrNull(metrics.comparedPixelCount);
    normalized.changedPixelCount = finiteOrNull(metrics.changedPixelCount);
    normalized.outsidePixelRatio = finiteOrNull(metrics.outsidePixelRatio);
    normalized.maximumChannelDelta = finiteOrNull(metrics.maximumChannelDelta);
    normalized.scale = finiteOrNull(metrics.scale);
    normalized.channelTolerance = finiteOrNull(metrics.channelTolerance);
    normalized.maxAllowedOutsidePixelRatio = finiteOrNull(metrics.maxAllowedOutsidePixelRatio);
  }
  return normalized;
}

function independentMetrics(kind, result) {
  const pages = Array.isArray(result?.pages) ? result.pages : [];
  const operationIDs = [...new Set(pages.flatMap((page) => Array.isArray(page?.operationIDs) ? page.operationIDs : []))];
  if (kind === "text") {
    return {
      provider: "poppler",
      basis: "poppler-text-outside-region",
      comparedPageCount: pages.length,
      changedPageCount: pages.filter((page) => page?.equal === false || page?.status === "failed").length,
      operationCount: operationIDs.length,
      operationIDs
    };
  }
  const comparedPixelCount = pages.reduce((total, page) => total + (Number(page?.comparedPixelCount) || 0), 0);
  const changedPixelCount = pages.reduce((total, page) => total + (Number(page?.changedPixelCount) || 0), 0);
  return {
    provider: "poppler",
    basis: "poppler-raster-outside-region",
    comparedPageCount: pages.length,
    changedPageCount: pages.filter((page) => page?.status === "failed").length,
    comparedPixelCount,
    changedPixelCount,
    outsidePixelRatio: comparedPixelCount ? changedPixelCount / comparedPixelCount : 0,
    maximumChannelDelta: pages.reduce((maximum, page) => Math.max(maximum, Number(page?.maximumChannelDelta) || 0), 0),
    operationCount: operationIDs.length,
    operationIDs
  };
}

function measurementComparison(kind, independent, pdfjs) {
  if (!independent || !pdfjs) {
    return { status: "notMeasured", message: "One provider did not emit normalized metrics." };
  }
  const independentlyCompared = independent.comparedPageCount > 0;
  const pdfjsCompared = pdfjs.comparedPageCount > 0;
  if (!independentlyCompared || !pdfjsCompared) {
    return {
      status: "notComparable",
      message: "At least one provider used a no-op or digest-equality shortcut instead of rendering comparable pages."
    };
  }
  const result = {
    status: "comparable",
    comparedPageCount: {
      independent: independent.comparedPageCount,
      pdfjs: pdfjs.comparedPageCount,
      equal: independent.comparedPageCount === pdfjs.comparedPageCount
    },
    changedPageCount: {
      independent: independent.changedPageCount,
      pdfjs: pdfjs.changedPageCount,
      equal: independent.changedPageCount === pdfjs.changedPageCount
    }
  };
  if (kind === "raster") {
    result.changedPixelCount = {
      independent: independent.changedPixelCount,
      pdfjs: pdfjs.changedPixelCount,
      equal: independent.changedPixelCount === pdfjs.changedPixelCount
    };
    result.outsidePixelRatio = {
      independent: independent.outsidePixelRatio,
      pdfjs: pdfjs.outsidePixelRatio,
      absoluteDelta: Math.abs((independent.outsidePixelRatio || 0) - (pdfjs.outsidePixelRatio || 0))
    };
  }
  return result;
}

function pdfjsGate(bundle, kind) {
  const check = checkFor(bundle, kind);
  if (!check) {
    return {
      provider: "pdfjs",
      status: bundle?.expectedFailure ? "expectedFailure" : "unknown",
      checkID: null,
      message: bundle?.expectedFailure
        ? "PDF.js did not produce an export gate for an expected inspection failure."
        : `PDF.js did not emit a ${kind} check.`,
      metrics: null
    };
  }
  return {
    provider: "pdfjs",
    status: statusOf(check.status),
    checkID: check.id || null,
    message: check.message || null,
    operationIDs: Array.isArray(check.operationIDs) ? check.operationIDs : [],
    metrics: normalizeMetrics(kind === "visualDiff" ? "raster" : "text", check.metrics, "pdfjs")
  };
}

function agreement(independentStatus, pdfjsStatus) {
  if (independentStatus === "unknown" || pdfjsStatus === "unknown" || independentStatus === "unavailable" || independentStatus === "skipped" || pdfjsStatus === "skipped") return "unknown";
  if (independentStatus === "expectedFailure" || pdfjsStatus === "expectedFailure") return "expectedFailure";
  if (independentStatus === pdfjsStatus) return "agree";
  return "divergence";
}

function pdfjsTextEvidence(bundle) {
  const runs = Array.isArray(bundle?.textRuns) ? bundle.textRuns : [];
  return {
    status: runs.length || bundle?.expectedFailure ? "observed" : "unknown",
    runCount: runs.length,
    characterCount: runs.reduce((total, run) => total + (Number(run?.characterCount) || 0), 0),
    pageCount: new Set(runs.map((run) => run?.pageIndex).filter(Number.isInteger)).size,
    textRunDigest: crypto.createHash("sha256").update(JSON.stringify(runs.map((run) => ({
      pageIndex: run?.pageIndex ?? null,
      sequence: run?.sequence ?? null,
      textHash: run?.textHash ?? null,
      characterCount: run?.characterCount ?? null,
      bounds: run?.bounds ?? null
    })))).digest("hex")
  };
}

function independentUnavailable(sourcePath, outputPath, message) {
  return {
    status: "unavailable",
    sourceDigest: fs.existsSync(sourcePath) ? sha256File(sourcePath) : null,
    outputDigest: fs.existsSync(outputPath) ? sha256File(outputPath) : null,
    message,
    text: { status: "unavailable", message },
    raster: { status: "unavailable", message },
    sourceReopen: { status: "unavailable", message },
    outputReopen: { status: "unavailable", message }
  };
}

function compareStatusPair(independent, pdfjs, kind) {
  const independentResult = independent?.[kind] || { status: "unknown", message: "Independent result was not emitted." };
  const independentNormalizedMetrics = independentMetrics(kind, independentResult);
  const pdfjsMetrics = pdfjs.metrics;
  return {
    independent: {
      provider: "poppler",
      status: statusOf(independentResult.status),
      message: independentResult.message || null,
      pages: Array.isArray(independentResult.pages) ? independentResult.pages : [],
      metrics: independentNormalizedMetrics
    },
    pdfjs,
    agreement: agreement(statusOf(independentResult.status), pdfjs.status),
    measurement: measurementComparison(kind, independentNormalizedMetrics, pdfjsMetrics)
  };
}

function overallStatus({ expectedFailure, independent, text, raster, sourceDigestMatches }) {
  if (expectedFailure && independent.status === "unavailable") return "expectedFailure";
  if (sourceDigestMatches === false) return "failed";
  if (text.agreement === "divergence" || raster.agreement === "divergence") return "failed";
  if (independent.status === "failed" || text.independent.status === "failed" || raster.independent.status === "failed") return "failed";
  if (text.agreement === "unknown" || raster.agreement === "unknown" || independent.status === "unknown" || independent.status === "unavailable") return "unknown";
  return "passed";
}

export function compareBrowserExportWithIndependentViewer({ sourcePath, browserExportPath, browserBundle, password = null }) {
  const expectedFailure = Boolean(browserBundle?.expectedFailure);
  const sourceDigest = fs.existsSync(sourcePath) ? sha256File(sourcePath) : null;
  const browserExportDigest = fs.existsSync(browserExportPath) ? sha256File(browserExportPath) : null;
  const pdfjsSourceDigest = browserBundle?.sourceDigest
    || browserBundle?.document?.header?.sourceDigest
    || browserBundle?.document?.payload?.source?.sha256
    || null;
  const sourceDigestMatches = sourceDigest && pdfjsSourceDigest ? sourceDigest === pdfjsSourceDigest : expectedFailure ? null : false;
  const operations = Array.isArray(browserBundle?.editSession?.operations)
    ? browserBundle.editSession.operations
    : Array.isArray(browserBundle?.operations)
      ? browserBundle.operations
      : [];
  const checkOperationIDs = [...new Set((browserBundle?.validation?.checks || [])
    .flatMap((check) => Array.isArray(check?.operationIDs) ? check.operationIDs : []))];
  const operationBinding = {
    status: checkOperationIDs.length && operations.length === 0 ? "missing" : operations.length ? "bound" : "empty",
    operationCount: operations.length,
    operationIDs: operations.map((operation) => operation?.id).filter(Boolean),
    validationOperationIDs: checkOperationIDs
  };
  const independent = fs.existsSync(sourcePath) && fs.existsSync(browserExportPath)
    ? operationBinding.status === "missing"
      ? {
        status: "unknown",
        sourceDigest,
        outputDigest: browserExportDigest,
        message: "PDF.js emitted operation lineage without serialized operation regions for independent validation.",
        text: { status: "unknown", message: "Independent operation regions are missing." },
        raster: { status: "unknown", message: "Independent operation regions are missing." },
        sourceReopen: { status: "unknown", message: "Skipped because operation regions were missing." },
        outputReopen: { status: "unknown", message: "Skipped because operation regions were missing." }
      }
      : compareIndependentPreservation({ sourcePath, outputPath: browserExportPath, password, operations })
    : independentUnavailable(sourcePath, browserExportPath, expectedFailure
      ? "Browser export is absent for an expected PDF.js inspection failure."
      : "Browser export was not retained for independent validation.");
  const text = compareStatusPair(independent, pdfjsGate(browserBundle, "outsideRegionText"), "text");
  const raster = compareStatusPair(independent, pdfjsGate(browserBundle, "visualDiff"), "raster");
  const sourceViewer = fs.existsSync(sourcePath)
    ? independentViewerReopen({ filePath: sourcePath, password })
    : { reopen: { status: "unavailable", message: "Source PDF is absent." }, toolVersions: {} };
  return {
    contract: INDEPENDENT_BROWSER_VIEWER_CONTRACT,
    sourcePath,
    browserExportPath,
    expectedFailure,
    sourceDigest,
    pdfjsSourceDigest,
    browserExportDigest,
    sourceDigestMatches,
    operationBinding,
    engine: {
      id: "poppler",
      renderer: "pdftoppm",
      textExtractor: "pdftotext",
      reopen: "pdfinfo",
      structuralControl: "qpdf",
      toolVersions: sourceViewer.toolVersions || {}
    },
    sourceReopen: sourceViewer.reopen,
    independent: {
      status: independent.status,
      sourceReopen: independent.sourceReopen || null,
      outputReopen: independent.outputReopen || null,
      outputDigest: independent.outputDigest || browserExportDigest
    },
    pdfjs: {
      validationStatus: browserBundle?.validation?.status || (expectedFailure ? "inspectionFailed" : "unknown"),
      textEvidence: pdfjsTextEvidence(browserBundle),
      checks: browserBundle?.validation?.checks || []
    },
    text,
    raster,
    status: overallStatus({ expectedFailure, independent, text, raster, sourceDigestMatches })
  };
}

function discoverBundles(resultRoot) {
  const webDirectory = path.join(resultRoot, "web");
  return fs.readdirSync(webDirectory)
    .filter((file) => file.endsWith(".json"))
    .sort()
    .map((file) => JSON.parse(fs.readFileSync(path.join(webDirectory, file), "utf8")));
}

function passwordFor(relativePath) {
  return relativePath.includes("encrypted-reader.pdf") || relativePath.includes("encrypted-") ? "reader-password" : null;
}

export function buildBrowserExportIndependentViewerReport({ projectRoot, resultRoot }) {
  const bundles = discoverBundles(resultRoot);
  const fixtures = bundles.map((bundle) => {
    const relativePath = bundle.sourcePath;
    const sourcePath = path.resolve(projectRoot, relativePath);
    const browserExportPath = path.join(resultRoot, "web-exports", fileNameFor(relativePath, "-browser-noop"));
    return compareBrowserExportWithIndependentViewer({
      sourcePath,
      browserExportPath,
      browserBundle: bundle,
      password: passwordFor(relativePath)
    });
  });
  const statusCounts = fixtures.reduce((counts, fixture) => {
    counts[fixture.status] = (counts[fixture.status] || 0) + 1;
    return counts;
  }, {});
  const agreementCounts = ["text", "raster"].reduce((result, kind) => {
    result[kind] = fixtures.reduce((counts, fixture) => {
      const value = fixture[kind]?.agreement || "unknown";
      counts[value] = (counts[value] || 0) + 1;
      return counts;
    }, {});
    return result;
  }, {});
  return {
    harness: "pdf-editor-browser-export-independent-viewer-comparison",
    contract: INDEPENDENT_BROWSER_VIEWER_CONTRACT,
    corpusManifest: "docs/fixtures/manifest.md",
    sourceOfPDFjsGate: path.relative(projectRoot, resultRoot),
    independentRenderer: "Poppler pdftotext/pdftoppm/pdfinfo with qpdf structural control",
    fixtureCount: fixtures.length,
    statusCounts,
    agreementCounts,
    unexpectedDivergenceCount: fixtures.filter((fixture) => fixture.text.agreement === "divergence" || fixture.raster.agreement === "divergence").length,
    fixtures
  };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const values = process.argv.slice(2);
  const args = Object.fromEntries(values.reduce((pairs, value, index) => {
    if (value.startsWith("--")) pairs.push([value.slice(2), values[index + 1]]);
    return pairs;
  }, []));
  const projectRoot = path.resolve(args.root || path.join(path.dirname(new URL(import.meta.url).pathname), ".."));
  if (!args["result-root"]) throw new Error("Usage: node benchmark/browser-export-independent-viewer-validator.mjs --result-root RESULT_ROOT [--root PROJECT_ROOT] [--report REPORT_PATH]");
  const resultRoot = path.resolve(projectRoot, args["result-root"]);
  const report = buildBrowserExportIndependentViewerReport({ projectRoot, resultRoot });
  const serialized = `${JSON.stringify(report, null, 2)}\n`;
  if (args.report) {
    const reportPath = path.resolve(projectRoot, args.report);
    fs.mkdirSync(path.dirname(reportPath), { recursive: true });
    fs.writeFileSync(reportPath, serialized);
  }
  process.stdout.write(serialized);
  process.exitCode = report.unexpectedDivergenceCount === 0 && (report.statusCounts.failed || 0) === 0 ? 0 : 1;
}
