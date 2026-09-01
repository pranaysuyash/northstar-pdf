#!/usr/bin/env node

import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const toolPath = fileURLToPath(import.meta.url);
const root = path.resolve(path.dirname(toolPath), "..");
const defaultFiles = [
  "Package.swift",
  "Sources/PDFEditorApp/ContentView.swift",
  "Sources/PDFEditorApp/AdaptiveDocumentContextMenu.swift",
  "Sources/PDFEditorApp/AdaptiveCommandContext.swift",
  "Sources/PDFEditorApp/AppCommands.swift",
  "Sources/PDFEditorApp/PDFEditorApp.swift",
  "Sources/PDFEditorApp/DocumentCanvasView.swift",
  "Sources/PDFEditorApp/PageThumbnailRailView.swift",
  "Sources/PDFEditorApp/ContextualInspectorView.swift",
  "Sources/PDFEditorRecovery/AppModel.swift",
  "Sources/PDFEditorCore/AdaptiveCommandPolicy.swift",
  "Sources/PDFEditorCore/AdaptiveCommandHistory.swift",
  "Sources/PDFEditorCore/DocumentSessionContracts.swift",
  "docs/audits/native-macos-product-audit-per-0926-2026-08-31.md",
  "docs/explorations/native-macos-visual-grammar-2026-09-01.md",
  "docs/decisions/adaptive-contextual-command-doctrine-2026-08-31.md",
  "docs/roadmaps/native-macos-modernization-plan-2026-08-31.md"
];

function usage() {
  console.log([
    "Usage: node tools/native-audit-snapshot.mjs [options]",
    "",
    "Options:",
    "  --output <path>  Write JSON to a workspace-relative or absolute path",
    "  --file <path>    Add a relied-on file; may be repeated",
    "  --help           Show this message"
  ].join("\n"));
}

function parseArguments(argv) {
  let outputPath;
  const files = [];
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === "--help") {
      usage();
      process.exit(0);
    }
    if (argument === "--output" || argument === "--file") {
      const value = argv[index + 1];
      if (!value) throw new Error(`${argument} requires a path`);
      if (argument === "--output") outputPath = value;
      else files.push(value);
      index += 1;
      continue;
    }
    throw new Error(`Unknown argument: ${argument}`);
  }
  return { outputPath, files: files.length > 0 ? files : defaultFiles };
}

function run(command, args) {
  try {
    return {
      status: "observed",
      value: execFileSync(command, args, {
        cwd: root,
        encoding: "utf8",
        stdio: ["ignore", "pipe", "pipe"]
      }).trim()
    };
  } catch (error) {
    return {
      status: "unavailable",
      reason: error?.message ?? String(error)
    };
  }
}

function relativePath(filePath) {
  return path.relative(root, path.resolve(root, filePath));
}

function fileEvidence(filePath) {
  const relative = relativePath(filePath);
  const absolute = path.resolve(root, filePath);
  try {
    const stats = fs.statSync(absolute);
    const bytes = fs.readFileSync(absolute);
    return {
      path: relative,
      status: "present",
      bytes: stats.size,
      modifiedAt: stats.mtime.toISOString(),
      sha256: crypto.createHash("sha256").update(bytes).digest("hex")
    };
  } catch (error) {
    return {
      path: relative,
      status: "unavailable",
      reason: error?.message ?? String(error)
    };
  }
}

function gitEvidence() {
  const branch = run("git", ["branch", "--show-current"]);
  const head = run("git", ["rev-parse", "HEAD"]);
  const status = run("git", ["status", "--short", "--branch"]);
  const untracked = run("git", ["ls-files", "--others", "--exclude-standard"]);
  return {
    branch,
    head,
    status,
    untrackedPaths: untracked.status === "observed"
      ? untracked.value.split("\n").filter(Boolean)
      : untracked
  };
}

function processEvidence() {
  const result = run("ps", ["-axo", "pid=,comm="]);
  if (result.status !== "observed") return result;
  const processes = result.value
    .split("\n")
    .map((line) => line.trim().split(/\s+/, 2))
    .filter(([pid, command]) => pid && command)
    .filter(([, command]) => /PDFEditor|swift|xcodebuild|native-audit/i.test(command))
    .map(([pid, command]) => ({ pid, command }));
  return { status: "observed", processes };
}

function lockEvidence() {
  const candidates = [
    ".git/index.lock",
    ".git/shallow.lock",
    ".build/.lock",
    ".build/arm64-apple-macosx/debug/.build-lock"
  ];
  return candidates.map((candidate) => ({
    path: candidate,
    present: fs.existsSync(path.resolve(root, candidate))
  }));
}

function buildManifest(files) {
  return {
    schema: "pdf-editor.native-audit-snapshot",
    schemaVersion: 1,
    capturedAt: new Date().toISOString(),
    host: {
      platform: process.platform,
      architecture: process.arch,
      release: os.release()
    },
    repository: gitEvidence(),
    reliedOnFiles: files.map(fileEvidence),
    commandVersions: {
      git: run("git", ["--version"]),
      swift: run("swift", ["--version"]),
      node: run(process.execPath, ["--version"]),
      xcodebuild: run("xcodebuild", ["-version"])
    },
    runtime: {
      processInspection: processEvidence(),
      lockCandidates: lockEvidence()
    },
    provenance: {
      tool: relativePath(toolPath),
      invocation: process.argv.slice(2),
      note: "Hashes cover only explicitly named relied-on files; no document content is collected."
    }
  };
}

try {
  const { outputPath, files } = parseArguments(process.argv.slice(2));
  const manifest = `${JSON.stringify(buildManifest(files), null, 2)}\n`;
  if (outputPath) {
    const absoluteOutput = path.resolve(root, outputPath);
    fs.mkdirSync(path.dirname(absoluteOutput), { recursive: true });
    fs.writeFileSync(absoluteOutput, manifest, "utf8");
    console.log(relativePath(absoluteOutput));
  } else {
    process.stdout.write(manifest);
  }
} catch (error) {
  console.error(error?.message ?? String(error));
  process.exitCode = 1;
}
