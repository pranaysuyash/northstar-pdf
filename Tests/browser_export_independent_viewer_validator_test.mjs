import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { compareBrowserExportWithIndependentViewer } from "../benchmark/browser-export-independent-viewer-validator.mjs";

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const resultRoot = path.join(projectRoot, "benchmark/results/semantic-parity/2026-08-25");
const sourcePath = path.join(projectRoot, "benchmark/results/public-sample-form.pdf");
const browserExportPath = path.join(resultRoot, "web-exports/benchmark__results__public-sample-form-browser-noop.pdf");
const bundlePath = path.join(resultRoot, "web/benchmark__results__public-sample-form.json");

assert.equal(fs.existsSync(sourcePath), true, "source corpus fixture must exist");
assert.equal(fs.existsSync(browserExportPath), true, "browser export corpus fixture must exist");
assert.equal(fs.existsSync(bundlePath), true, "PDF.js bundle must exist");

const bundle = JSON.parse(fs.readFileSync(bundlePath, "utf8"));
const report = compareBrowserExportWithIndependentViewer({ sourcePath, browserExportPath, browserBundle: bundle });
assert.equal(report.engine.id, "poppler");
assert.equal(report.independent.status, "passed");
assert.equal(report.text.independent.status, "passed");
assert.equal(report.raster.independent.status, "passed");
assert.equal(report.text.pdfjs.status, "passed");
assert.equal(report.raster.pdfjs.status, "passed");
assert.equal(report.text.agreement, "agree");
assert.equal(report.raster.agreement, "agree");
assert.equal(report.text.independent.metrics.provider, "poppler");
assert.equal(report.raster.independent.metrics.comparedPageCount, 1);
assert.equal(report.text.measurement.status, "notMeasured", "legacy bundle without PDF.js metrics must remain explicit");
assert.equal(report.status, "passed");

const measuredBundle = {
  ...bundle,
  validation: {
    ...bundle.validation,
    checks: bundle.validation.checks.map((check) => {
      if (check.kind === "outsideRegionText") {
        return { ...check, metrics: { basis: "pdfjs-text-outside-region", comparedPageCount: 1, changedPageCount: 0, operationCount: 0 } };
      }
      if (check.kind === "visualDiff") {
        return { ...check, metrics: { basis: "pdfjs-raster-outside-region", comparedPageCount: 1, changedPageCount: 0, comparedPixelCount: 1090584, changedPixelCount: 0, outsidePixelRatio: 0, maximumChannelDelta: 0 } };
      }
      return check;
    })
  }
};
const measured = compareBrowserExportWithIndependentViewer({ sourcePath, browserExportPath, browserBundle: measuredBundle });
assert.equal(measured.text.measurement.status, "comparable");
assert.equal(measured.text.measurement.changedPageCount.equal, true);
assert.equal(measured.raster.measurement.status, "comparable");
assert.equal(measured.raster.measurement.changedPixelCount.equal, true);

const divergent = compareBrowserExportWithIndependentViewer({
  sourcePath,
  browserExportPath,
  browserBundle: {
    ...bundle,
    validation: {
      ...bundle.validation,
      checks: bundle.validation.checks.map((check) => check.kind === "visualDiff" ? { ...check, status: "failed" } : check)
    }
  }
});
assert.equal(divergent.raster.agreement, "divergence", "a PDF.js raster disagreement must remain visible");
assert.equal(divergent.status, "failed", "provider disagreement must fail the comparison report");

const missingGate = compareBrowserExportWithIndependentViewer({
  sourcePath,
  browserExportPath,
  browserBundle: { ...bundle, validation: { ...bundle.validation, checks: [] } }
});
assert.equal(missingGate.text.agreement, "unknown");
assert.equal(missingGate.raster.agreement, "unknown");
assert.equal(missingGate.status, "unknown");

const skippedGate = compareBrowserExportWithIndependentViewer({
  sourcePath,
  browserExportPath,
  browserBundle: {
    ...bundle,
    validation: {
      ...bundle.validation,
      checks: bundle.validation.checks.map((check) => check.kind === "visualDiff" ? { ...check, status: "skipped" } : check)
    }
  }
});
assert.equal(skippedGate.raster.pdfjs.status, "skipped");
assert.equal(skippedGate.raster.agreement, "unknown", "a skipped PDF.js gate must remain unknown");
assert.equal(skippedGate.status, "unknown");

const validOperation = {
  id: "operation-independent-test",
  pageIndex: 0,
  coordinate: {
    pageIndex: 0,
    rect: { x: 0, y: 0, width: 1, height: 1 }
  }
};
const boundOperation = compareBrowserExportWithIndependentViewer({
  sourcePath,
  browserExportPath,
  browserBundle: {
    ...bundle,
    editSession: { ...bundle.editSession, operations: [validOperation] }
  }
});
assert.equal(boundOperation.operationBinding.status, "bound");
assert.equal(boundOperation.independent.status, "passed");

const mismatchedOperation = compareBrowserExportWithIndependentViewer({
  sourcePath,
  browserExportPath,
  browserBundle: {
    ...bundle,
    validation: {
      ...bundle.validation,
      checks: bundle.validation.checks.map((check) => check.kind === "visualDiff"
        ? { ...check, operationIDs: ["operation-coordinate-mismatch"] }
        : check)
    },
    editSession: {
      ...bundle.editSession,
      operations: [{
        ...validOperation,
        id: "operation-coordinate-mismatch",
        coordinate: { ...validOperation.coordinate, pageIndex: 1 }
      }]
    }
  }
});
assert.equal(mismatchedOperation.operationBinding.status, "bound");
assert.equal(mismatchedOperation.independent.status, "unknown", "coordinate mismatch must not become an independent pass");

console.log(JSON.stringify({
  test: "browser_export_independent_viewer_validator",
  provider: report.engine.id,
  baseline: { status: report.status, text: report.text.agreement, raster: report.raster.agreement },
  divergenceMutation: { status: divergent.status, raster: divergent.raster.agreement },
  missingGate: { status: missingGate.status, text: missingGate.text.agreement, raster: missingGate.raster.agreement },
  skippedGate: { status: skippedGate.status, raster: skippedGate.raster.agreement },
  measuredMetrics: { text: measured.text.measurement.status, raster: measured.raster.measurement.status },
  operationBinding: { valid: boundOperation.operationBinding.status, mismatch: mismatchedOperation.independent.status }
}, null, 2));
