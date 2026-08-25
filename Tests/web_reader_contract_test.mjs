import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const testDirectory = path.dirname(fileURLToPath(import.meta.url));
const webDir = path.join(testDirectory, "..", "web");

// RT-004: JavaScript was extracted from inline <script> to app.js.
// Read both files and concatenate so all contract patterns remain verifiable.
const htmlSource = fs.readFileSync(path.join(webDir, "index.html"), "utf8");
const appSource = fs.readFileSync(path.join(webDir, "app.js"), "utf8");
const source = htmlSource + "\n" + appSource;

const requiredContracts = [
  ["document language", /<html lang="en">/],
  ["skip link", /class="skip-link" href="#viewerMain"/],
  ["viewer landmark", /<main id="viewerMain"/],
  ["live status", /role="status" aria-live="polite"/],
  ["password dialog", /role="dialog" aria-modal="true"/],
  ["semantic text layer", /async function buildTextLayer\(/],
  ["keyboard text spans", /span\.tabIndex = 0/],
  ["search match marks", /document\.createElement\("mark"\)/],
  ["safe external policy", /safeExternal\(/],
  ["metadata provider", /getMetadata\(/],
  ["permissions provider", /getPermissions\(/],
  ["clipboard fallback", /document\.execCommand\("copy"\)/],
  ["local pdf-lib runtime", /\.\/vendor\/pdf-lib\/pdf-lib\.min\.js/],
  ["source digest", /async function sha256Hex\(/],
  ["document contract", /contractName: "pdf-editor\.document"/],
  ["native field inspection", /async function inspectNativeFields\(/],
  ["static candidate detection", /async function detectStaticCandidates\(/],
  ["candidate page highlights", /function renderCandidatePreviews\(/],
  ["manual placement mode", /manualPlacementMode/],
  ["candidate dismissal", /function dismissSelectedCandidate\(/],
  ["candidate restoration", /showDismissedCandidates/],
  ["overlay edit selection", /selectedOperation/],
  ["coordinate conversion", /function coordinateFor\(/],
  ["operation ledger", /function makeOperation\(/],
  ["browser mutation gate import", /pdf-contract-mutation-gate\.mjs/],
  ["pre-export mutation gate", /assertExportableContract\([\s\S]*PDFDocument\.load\(/],
  ["pdf-lib materialization", /async function materializeOperations\(/],
  ["export validation", /async function validateExport\(/],
  ["browser contract fixture API", /window\.__pdfEditorContractFixture/],
  ["text-run projection", /normalizePdfJsTextItems/],
  ["OCR alignment comparison", /compareOCRLayerAlignment/],
  ["replacement abstention probe", /buildTextRunReplacementProbe/],
  ["page coordinate fixture projection", /contractName: "pdf-editor\.coordinates"/],
  ["outside-region text validator", /compareOutsideRegions/],
  ["raster impact validator", /visualDiff/],
  ["fail-closed operation regions", /fail-closed for missing or mismatched operation regions/],
  ["geometry detector adapter", /detectGeometryCandidates/],
  ["template fingerprint adapter", /createTemplateFingerprint/],
  ["template matching adapter", /matchTemplate/],
  ["completion export control", /id="exportButton"/],
  ["preservation metrics panel", /id="impactMetrics"/],
  ["preservation metrics renderer", /function renderImpactMetrics\(/],
  ["value-minimized text metrics", /changedPageCount/],
  ["raster pixel metrics", /changedPixelCount/],
  ["pinned PDF.js runtime", /PDFJS_PINNED_VERSION = "4\.2\.67"/],
  ["local PDF.js runtime", /\.\/vendor\/pdfjs\/pdf\.min\.mjs/],
  ["runtime failure state", /PDF\.js runtime unavailable/],
  ["stable web error codes", /WEB_ERROR_CODES[\s\S]*password-required[\s\S]*runtime-unavailable[\s\S]*export-failed[\s\S]*invalid-operation/],
  ["web error normalization", /function normalizeReaderError\(error, fallbackCode/]
  , ["null-safe metadata", /metadata = md\?\.info \|\| \{\}/]
  , ["null-safe permissions", /permissions = \(await pdfDoc\.getPermissions\(\)\) \|\| \{\}/]
];

for (const [name, pattern] of requiredContracts) {
  assert.match(source, pattern, `Missing web reader contract: ${name}`);
}

assert.match(source, /Selectable text for page \$\{pageNum\}/);

// Boot-smoke gate (audit A-4, 2026-08-25): the source-contract regexes above
// passed while a duplicate-import SyntaxError made the inline module unbootable.
// Parsing the real application module closes that gap at Tier 2 without a browser.
import os from "node:os";
import { spawnSync } from "node:child_process";
assert.match(
  htmlSource,
  /<script type="module" src="\.\/app\.js">/,
  "RT-004 regression: index.html must load the application from ./app.js"
);
const bootCheckCopy = path.join(os.tmpdir(), `pdf-editor-app-boot-check-${process.pid}.mjs`);
fs.writeFileSync(bootCheckCopy, appSource);
try {
  const bootCheck = spawnSync(process.execPath, ["--check", bootCheckCopy], { encoding: "utf8" });
  assert.equal(
    bootCheck.status,
    0,
    `Application module must parse (boot smoke): ${bootCheck.stderr?.slice(0, 400) ?? ""}`
  );
} finally {
  fs.rmSync(bootCheckCopy, { force: true });
}

console.log(`web reader and completion contract: ${requiredContracts.length} checks passed (+ boot smoke)`);
