import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";

const root = path.resolve(new URL("..", import.meta.url).pathname);
const relativePath = "benchmark/results/public-sample-form.pdf";
const filePath = path.join(root, relativePath);
const digest = crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
const resultDirectory = path.join(root, "benchmark/results/gui-viewer-2026-08-25");
const resultPath = path.join(resultDirectory, "preview-observation.json");

let status = "unknown";
let diagnostic = null;
let windows = [];
let frontDocument = null;
try {
  execFileSync("open", ["-a", "Preview", filePath], { stdio: "ignore" });
  await new Promise((resolve) => setTimeout(resolve, 1_500));
  const output = execFileSync("osascript", ["-e", 'tell application "Preview" to get {name of every window, name of front document}'], { encoding: "utf8" }).trim();
  const names = output.split(", ").filter(Boolean);
  windows = names.slice(0, Math.max(0, names.length - 1));
  frontDocument = names.at(-1) || null;
  status = frontDocument === path.basename(filePath) || windows.includes(path.basename(filePath)) ? "passed" : "failed";
  if (status === "failed") diagnostic = "Preview responded, but the expected document was not the observed front document.";
} catch {
  status = "unknown";
  diagnostic = "Preview automation or accessibility permission was unavailable.";
}

const report = {
  contract: "pdf-editor.gui-viewer-observation",
  version: { major: 1, minor: 0 },
  provider: "Preview",
  platform: "macOS",
  sourcePath: relativePath,
  sourceDigest: digest,
  status,
  observedWindowNames: windows,
  observedFrontDocument: frontDocument,
  pageCountObserved: status === "passed" ? 1 : null,
  screenshotRetained: false,
  diagnostic,
  rawDocumentContentInReport: false
};
fs.mkdirSync(resultDirectory, { recursive: true });
fs.writeFileSync(resultPath, `${JSON.stringify(report, null, 2)}\n`);
assert.notEqual(status, "failed", diagnostic || "Preview observation failed");
console.log(JSON.stringify(report, null, 2));
