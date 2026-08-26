import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { compareMupdfReopen } from "../benchmark/mupdf-independent-validator.mjs";

const root = path.resolve(new URL("..", import.meta.url).pathname);
const sourcePath = path.join(root, "benchmark/results/public-sample-form.pdf");
const outputPath = path.join(root, "benchmark/results/semantic-parity/2026-08-25/web-exports/benchmark__results__public-sample-form-browser-noop.pdf");
const report = compareMupdfReopen({ sourcePath, outputPath });
assert.equal(report.status, "passed");
assert.equal(report.text.status, "passed");
assert.equal(report.raster.status, "passed");
assert.equal(report.editedOperationRegions, "notMeasured");
fs.mkdirSync(path.join(root, "benchmark/results/mupdf-independent-2026-08-25"), { recursive: true });
fs.writeFileSync(path.join(root, "benchmark/results/mupdf-independent-2026-08-25/report.json"), `${JSON.stringify(report, null, 2)}\n`);
console.log("MuPDF independent no-op text/raster/reopen: PASS; edited operation regions remain an explicit next measurement");
