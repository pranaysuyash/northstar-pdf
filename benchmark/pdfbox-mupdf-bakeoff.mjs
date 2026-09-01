#!/usr/bin/env node

/**
 * PDFBox versus MuPDF provider bake-off.
 *
 * This is an evidence runner, not a shipping selector. It keeps provider
 * output behind a normalized envelope so that version-specific object IDs,
 * timestamps, and output digests cannot masquerade as semantic parity.
 *
 * Usage:
 *   node benchmark/pdfbox-mupdf-bakeoff.mjs
 *   node benchmark/pdfbox-mupdf-bakeoff.mjs --fixture public-sample-form
 *   node benchmark/pdfbox-mupdf-bakeoff.mjs --output-dir /tmp/report
 */

import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync, spawnSync } from "node:child_process";

const ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
const MANIFEST_PATH = path.join(ROOT, "Tests/fixtures/pdf_corpus_governance_manifest.json");
const PDFBOX_JAR = path.join(ROOT, "benchmark/pdfbox-lane/pdfbox-app-3.0.8.jar");
const PDFBOX_SHA512 = `${PDFBOX_JAR}.sha512`;
const OUTPUT_DIR = (() => {
  const index = process.argv.indexOf("--output-dir");
  return process.env.PDF_EDITOR_BAKEOFF_OUTPUT_DIR
    || (index >= 0 ? path.resolve(process.argv[index + 1]) : null)
    || path.join(ROOT, "benchmark/results/pdfbox-mupdf-bakeoff-2026-08-31");
})();
const JAVA = process.env.JAVA_BIN || "java";
const MUTOOL = process.env.MUTOOL_BIN || "mutool";
const TIMEOUT_MS = Number(process.env.PDF_EDITOR_BAKEOFF_TIMEOUT_MS || 120_000);
const CONTRACT = "pdf-editor.provider-bakeoff";
const VERSION = { major: 1, minor: 0 };

function sha256(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

function sha512(filePath) {
  return crypto.createHash("sha512").update(fs.readFileSync(filePath)).digest("hex");
}

function commandVersion(command, args) {
  const result = spawnSync(command, args, { encoding: "utf8", timeout: 15_000 });
  if (result.error) return { state: "unknown", reasonCode: "versionCommandFailed" };
  const text = `${result.stdout || ""}\n${result.stderr || ""}`.trim();
  return { state: result.status === 0 ? "observed" : "unknown", text: text.slice(0, 240) };
}

function run(command, args, options = {}) {
  const result = spawnSync(command, args, {
    cwd: ROOT,
    encoding: "utf8",
    timeout: options.timeout ?? TIMEOUT_MS,
    maxBuffer: 64 * 1024 * 1024,
    stdio: ["ignore", "pipe", "pipe"]
  });
  return {
    status: result.error?.code === "ETIMEDOUT" ? "timedOut" : result.status === 0 ? "passed" : "failed",
    exitCode: result.status,
    stdout: (result.stdout || "").slice(0, 20_000),
    stderr: (result.stderr || "").slice(0, 20_000),
    error: result.error ? String(result.error.message || result.error).slice(0, 300) : undefined
  };
}

function safeRemove(directory) {
  fs.rmSync(directory, { recursive: true, force: true });
}

function safeJson(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch {
    return null;
  }
}

function normalizePdfInfo(text) {
  const facts = {};
  const allowed = new Set(["pages", "pagesize", "encrypted", "pdf_version", "page_rot", "optimized", "tagged", "form"]);
  for (const line of text.split(/\r?\n/)) {
    const match = line.match(/^([^:]+):\s*(.*)$/);
    if (!match) continue;
    const key = match[1].trim().toLowerCase().replace(/\s+/g, "_");
    const value = match[2].trim();
    if (!allowed.has(key)) continue;
    facts[key] = value;
  }
  return facts;
}

function normalizeText(text) {
  return text.replace(/\r/g, "").replace(/\s+/g, " ").trim();
}

function pdfInfo(filePath) {
  const result = run("pdfinfo", [filePath]);
  if (result.status !== "passed") return { status: "unknown", errorCode: "pdfinfoFailed" };
  const facts = normalizePdfInfo(result.stdout);
  return {
    status: "passed",
    pageCount: Number(facts.pages) || null,
    pageSize: facts.pagesize || null,
    encrypted: facts.encrypted === "yes",
    pdfVersion: facts.pdf_version || null,
    normalized: facts
  };
}

function qpdfCheck(filePath) {
  const result = run("qpdf", ["--check", filePath]);
  return { status: result.status === "passed" ? "passed" : "failed", detail: result.stderr || result.stdout };
}

function popplerText(filePath) {
  const result = run("pdftotext", ["-enc", "UTF-8", filePath, "-"]);
  return result.status === "passed"
    ? { status: "passed", digest: crypto.createHash("sha256").update(normalizeText(result.stdout)).digest("hex"), characterCount: normalizeText(result.stdout).length }
    : { status: "unknown", reasonCode: "textExtractionFailed" };
}

function renderWithPoppler(filePath, directory, prefix) {
  const result = run("pdftoppm", ["-r", "72", "-png", "-singlefile", filePath, path.join(directory, prefix)]);
  if (result.status !== "passed") return { status: "unknown", reasonCode: "rasterRenderFailed" };
  const output = path.join(directory, `${prefix}.png`);
  return fs.existsSync(output)
    ? { status: "passed", digest: sha256(output), byteCount: fs.statSync(output).size }
    : { status: "unknown", reasonCode: "rasterArtifactMissing" };
}

function providerMetadata() {
  const jarDigest = fs.existsSync(PDFBOX_JAR) ? sha256(PDFBOX_JAR) : null;
  const jarSha512 = fs.existsSync(PDFBOX_JAR) ? sha512(PDFBOX_JAR) : null;
  const expectedSha512 = fs.existsSync(PDFBOX_SHA512)
    ? fs.readFileSync(PDFBOX_SHA512, "utf8").replace(/\s/g, "").toLowerCase()
    : null;
  const mupdfVersion = commandVersion(MUTOOL, ["-v"]);
  const javaVersion = commandVersion(JAVA, ["-version"]);
  return {
    pdfbox: {
      providerID: "companion-pdfbox",
      engineFamily: "apache-pdfbox",
      version: "3.0.8",
      runtimeKind: "installed-companion-java",
      license: { identifier: "Apache-2.0", status: "observed-in-local-artifact-and-official-release" },
      artifact: {
        path: path.relative(ROOT, PDFBOX_JAR),
        sha256: jarDigest,
        sha512: jarSha512,
        publishedSha512Matches: Boolean(expectedSha512 && expectedSha512 === jarSha512),
        sizeBytes: fs.existsSync(PDFBOX_JAR) ? fs.statSync(PDFBOX_JAR).size : null
      },
      packaging: {
        shape: "fat-jar-plus-jvm",
        offline: true,
        nativeLibraries: false,
        runtimeObserved: javaVersion,
        dependencyNoticeReview: "required"
      }
    },
    mupdf: {
      providerID: "companion-mupdf",
      engineFamily: "mupdf",
      version: "1.28.2",
      runtimeKind: "installed-companion-native-cli",
      license: { identifier: "AGPL-3.0-or-commercial", status: "observed-in-local-binary-and-official-license" },
      artifact: {
        path: process.env.MUTOOL_BIN || "mutool",
        sha256: (() => { try { return sha256(process.env.MUTOOL_BIN || "/opt/homebrew/bin/mutool"); } catch { return null; } })(),
        sizeBytes: (() => { try { return fs.statSync(process.env.MUTOOL_BIN || "/opt/homebrew/bin/mutool").size; } catch { return null; } })()
      },
      packaging: {
        shape: "native-cli-plus-runtime-libraries",
        offline: true,
        nativeLibraries: true,
        runtimeObserved: mupdfVersion,
        commercialLicenseDecision: "open"
      }
    }
  };
}

function baseCase(fixture, sourcePath, sourceFacts) {
  return {
    fixtureID: fixture.fixtureId,
    source: {
      relativePath: fixture.relativePath,
      sha256: sha256(sourcePath),
      byteCount: fs.statSync(sourcePath).size,
      classes: fixture.documentClasses,
      privacyClass: fixture.privacyClass,
      sourceKind: fixture.sourceKind
    },
    input: {
      qpdfCheck: qpdfCheck(sourcePath),
      pdfInfo: sourceFacts,
      malformedExpected: fixture.expectedInspection === "inspection-failed-safe"
    },
    normalization: {
      ignoredProviderFields: ["objectIDs", "xrefOffsets", "creationDate", "modDate", "outputDigest", "runtimeTimestamps"],
      textComparison: "normalized-whitespace-sha256",
      rasterComparison: "independent-Poppler-page-1-sha256",
      statusVocabulary: ["passed", "failed", "unsupported", "unknown", "diverged"]
    }
  };
}

function runPdfBox(fixture, sourcePath, workDir, sourceFacts, provider) {
  const caseBase = baseCase(fixture, sourcePath, sourceFacts);
  const result = {
    provider,
    inspection: { status: "unknown" },
    rewrite: { status: "unknown" },
    recovery: { status: "unknown" }
  };
  if (!fs.existsSync(PDFBOX_JAR)) {
    result.inspection = { status: "unknown", reasonCode: "pdfboxArtifactMissing" };
    return { ...caseBase, providerResult: result };
  }
  const classesDir = fs.mkdtempSync(path.join(os.tmpdir(), "pdf-editor-pdfbox-classes-"));
  const compile = run("javac", ["-cp", PDFBOX_JAR, "-d", classesDir, path.join(ROOT, "benchmark/pdfbox-lane/RadioProbe.java")]);
  if (compile.status !== "passed") {
    safeRemove(classesDir);
    result.inspection = { status: "unknown", reasonCode: "pdfboxCompileFailed" };
    return { ...caseBase, providerResult: result };
  }
  const outputDir = path.join(workDir, "pdfbox");
  fs.mkdirSync(outputDir, { recursive: true });
  // The existing probe's Java2D raster phase is measured separately in the
  // native PDFBox lane. It can hang on this host for this corpus, so the
  // provider comparison uses the same independent Poppler oracle for both
  // providers and keeps the Java2D observation in recovery/runtime metadata.
  const flags = fixture.expectedInspection === "inspection-failed-safe" || fixture.documentClasses.includes("encrypted")
    ? ["--no-mutate"] : [];
  const probe = run(JAVA, ["-Djava.awt.headless=true", `-Dpdfbox.jar.sha512=${provider.artifact.sha512 || ""}`, "-cp", `${PDFBOX_JAR}:${classesDir}`, "RadioProbe", ...flags, sourcePath, outputDir]);
  const rawReportPath = path.join(outputDir, "result.json");
  if (probe.stdout.trim().startsWith("{")) fs.writeFileSync(rawReportPath, `${probe.stdout.trim()}\n`);
  const raw = safeJson(rawReportPath);
  if (probe.status === "passed" && raw) {
    result.inspection = {
      status: raw.encryptedUnsupported ? "unsupported" : raw.pages == null ? "unknown"
        : caseBase.input.malformedExpected ? "recovered-with-warning" : "passed",
      pageCount: raw.pages,
      fieldCount: raw.fieldCount,
      fieldTypes: [...(raw.fieldTypes || [])].sort(),
      failureMode: raw.failureMode || null
    };
    const noopPath = path.join(outputDir, "noop.pdf");
    const sourceText = popplerText(sourcePath);
    const outputText = fs.existsSync(noopPath) ? popplerText(noopPath) : { status: "unknown" };
    const sourceRaster = renderWithPoppler(sourcePath, workDir, "pdfbox-source");
    const outputRaster = fs.existsSync(noopPath) ? renderWithPoppler(noopPath, workDir, "pdfbox-output") : { status: "unknown" };
    const semanticRewriteStatus = raw.encryptedUnsupported ? "unsupported" : caseBase.input.malformedExpected
      ? "recovered-with-warning" : raw.noOpReopen ? "passed" : raw.pages == null ? "unknown"
        : (sourceText.status === "passed" && outputText.status === "passed"
          && sourceText.digest === outputText.digest
          && sourceRaster.status === "passed" && outputRaster.status === "passed"
          && sourceRaster.digest === outputRaster.digest) ? "passed" : "diverged";
    result.rewrite = {
      status: semanticRewriteStatus,
      reopen: raw.noOpReopen ? "passed" : caseBase.input.malformedExpected ? "recovered-with-warning" : "notProven",
      semanticFieldState: raw.widgetStateEquivalent ? "passed" : raw.fieldCount > 0 ? "diverged" : "notApplicable",
      independentText: sourceText.status === "passed" && outputText.status === "passed"
        ? sourceText.digest === outputText.digest ? "passed" : "diverged"
        : "unknown",
      independentRaster: sourceRaster.status === "passed" && outputRaster.status === "passed"
        ? sourceRaster.digest === outputRaster.digest ? "passed" : "diverged"
        : "unknown",
      providerRasterAE: "not-run-java2d-phase",
      outputDigest: fs.existsSync(path.join(outputDir, "noop.pdf")) ? sha256(path.join(outputDir, "noop.pdf")) : null,
      outputByteCount: fs.existsSync(path.join(outputDir, "noop.pdf")) ? fs.statSync(path.join(outputDir, "noop.pdf")).size : null
    };
  } else {
    result.inspection = { status: sourceFacts.encrypted ? "unsupported" : "unknown", reasonCode: sourceFacts.encrypted ? "encryptedNoPassword" : "pdfboxProbeFailed" };
    result.rewrite = { status: "unknown", reasonCode: probe.status === "timedOut" ? "providerTimeout" : "providerProcessFailed" };
  }
  const malformedCopy = path.join(outputDir, "recovery-truncated.pdf");
  fs.writeFileSync(malformedCopy, fs.readFileSync(sourcePath).subarray(0, Math.min(128, fs.statSync(sourcePath).size)));
  const recoveryProbe = run(JAVA, ["-Djava.awt.headless=true", "-cp", `${PDFBOX_JAR}:${classesDir}`, "RadioProbe", "--no-mutate", malformedCopy, path.join(outputDir, "recovery")]);
  const recoveryPath = path.join(outputDir, "recovery", "noop.pdf");
  const recoveryProducedArtifact = fs.existsSync(recoveryPath);
  const recoveryPublishedValidOutput = recoveryProducedArtifact && qpdfCheck(recoveryPath).status === "passed";
  result.recovery = {
    status: recoveryPublishedValidOutput ? "failed" : recoveryProducedArtifact ? "passed-with-invalid-staged-artifact" : "passed",
    expectation: "malformed-input-does-not-publish-a-valid-output",
    providerExit: recoveryProbe.status,
    providerProducedArtifact: recoveryProducedArtifact,
    publishedValidOutput: recoveryPublishedValidOutput
  };
  safeRemove(classesDir);
  return { ...caseBase, providerResult: result };
}

function runMuPdf(fixture, sourcePath, workDir, sourceFacts, provider) {
  const caseBase = baseCase(fixture, sourcePath, sourceFacts);
  fs.mkdirSync(workDir, { recursive: true });
  const result = {
    provider,
    inspection: { status: "unknown" },
    rewrite: { status: "unknown" },
    supportedOperations: {},
    recovery: { status: "unknown" }
  };
  const info = run(MUTOOL, ["info", sourcePath]);
  const text = run(MUTOOL, ["draw", "-q", "-F", "stext.json", "-o", "-", sourcePath]);
  result.inspection = {
    status: info.status === "passed" ? "passed" : sourceFacts.encrypted ? "unsupported" : "unknown",
    infoExit: info.status,
    text: text.status === "passed" ? { status: "passed", normalizedDigest: sha256FromText(text.stdout) } : { status: "unknown", reasonCode: "mupdfTextExtractionFailed" }
  };
  const cleanOutput = path.join(workDir, "mupdf-noop.pdf");
  const clean = run(MUTOOL, ["clean", "-gg", sourcePath, cleanOutput]);
  if (clean.status === "passed" && fs.existsSync(cleanOutput)) {
    const reopened = run(MUTOOL, ["info", cleanOutput]);
    const popplerSourceText = popplerText(sourcePath);
    const popplerOutputText = popplerText(cleanOutput);
    const sourceRaster = renderWithPoppler(sourcePath, workDir, "source");
    const outputRaster = renderWithPoppler(cleanOutput, workDir, "mupdf-output");
    result.rewrite = {
      status: reopened.status === "passed" ? "passed" : "failed",
      reopen: reopened.status === "passed" ? "passed" : "failed",
      outputDigest: sha256(cleanOutput),
      outputByteCount: fs.statSync(cleanOutput).size,
      semanticText: popplerSourceText.status === "passed" && popplerOutputText.status === "passed"
        ? popplerSourceText.digest === popplerOutputText.digest ? "passed" : "diverged"
        : "unknown",
      independentRaster: sourceRaster.status === "passed" && outputRaster.status === "passed"
        ? sourceRaster.digest === outputRaster.digest ? "passed" : "diverged"
        : "unknown"
    };
  } else {
    result.rewrite = { status: sourceFacts.encrypted ? "unsupported" : "unknown", reasonCode: sourceFacts.encrypted ? "encryptedNoPassword" : "mupdfCleanFailed" };
  }
  result.supportedOperations = {
    "reader.render": { status: info.status === "passed" ? "passed" : "unknown" },
    "reader.textExtraction": { status: text.status === "passed" ? "passed" : "unknown" },
    "edit.nativeFormBake": { status: "available-command-not-equivalent-to-field-fill", command: "mutool bake" },
    "edit.existingText": { status: "unsupported-by-cli-lane", reasonCode: "no-typed-text-replacement-operation" },
    "edit.redaction": { status: "available-command-not-yet-admitted", command: "mutool clean -s", requires: "separate-redaction-completeness-gate" }
  };
  const malformedCopy = path.join(workDir, "recovery-truncated.pdf");
  fs.writeFileSync(malformedCopy, fs.readFileSync(sourcePath).subarray(0, Math.min(128, fs.statSync(sourcePath).size)));
  const recoveryOutput = path.join(workDir, "recovery-output.pdf");
  const recovery = run(MUTOOL, ["clean", malformedCopy, recoveryOutput]);
  const producedArtifact = fs.existsSync(recoveryOutput);
  const publishedValidOutput = producedArtifact && qpdfCheck(recoveryOutput).status === "passed";
  result.recovery = {
    status: publishedValidOutput ? "failed" : producedArtifact ? "passed-with-invalid-staged-artifact" : "passed",
    expectation: "malformed-input-does-not-publish-a-valid-output",
    providerExit: recovery.status,
    providerProducedArtifact: producedArtifact,
    publishedValidOutput
  };
  return { ...caseBase, providerResult: result };
}

function sha256FromText(text) {
  return crypto.createHash("sha256").update(normalizeText(text)).digest("hex");
}

function selectedFixtures() {
  const manifest = JSON.parse(fs.readFileSync(MANIFEST_PATH, "utf8"));
  const selected = new Set(process.argv.slice(2).flatMap((value, index, args) => value === "--fixture" ? [args[index + 1]] : []));
  const fixtures = manifest.fixtures.filter((fixture) => {
    if (selected.size && !selected.has(fixture.fixtureId)) return false;
    return fs.existsSync(path.join(ROOT, fixture.relativePath));
  });
  return {
    manifest,
    fixtures,
    skipped: manifest.fixtures.filter((fixture) => !fixtures.some((candidate) => candidate.fixtureId === fixture.fixtureId)).map((fixture) => fixture.fixtureId)
  };
}

function main() {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  const startedAt = new Date().toISOString();
  const selection = selectedFixtures();
  const fixtures = selection.fixtures;
  const providers = providerMetadata();
  const cases = [];
  for (const fixture of fixtures) {
    const sourcePath = path.join(ROOT, fixture.relativePath);
    const sourceFacts = pdfInfo(sourcePath);
    const caseDir = fs.mkdtempSync(path.join(os.tmpdir(), "pdf-editor-bakeoff-case-"));
    try {
      cases.push({ fixture: fixture.fixtureId, pdfbox: runPdfBox(fixture, sourcePath, path.join(caseDir, "pdfbox"), sourceFacts, providers.pdfbox), mupdf: runMuPdf(fixture, sourcePath, path.join(caseDir, "mupdf"), sourceFacts, providers.mupdf) });
    } finally {
      safeRemove(caseDir);
    }
  }
  const report = {
    contract: CONTRACT,
    version: VERSION,
    run: {
      startedAt,
      completedAt: new Date().toISOString(),
      workspace: ROOT,
      corpusManifest: path.relative(ROOT, MANIFEST_PATH),
      corpusManifestFixtureCount: selection.manifest.fixtures.length,
      corpusFixtureCount: cases.length,
      skippedManifestFixtures: selection.skipped,
    rawDocumentContentInReport: false,
    sourceMetadataValuesInReport: false,
      networkUsed: false,
      outputDigestsAreIdentityOnly: true
    },
    providers,
    cases,
    summary: {
      pdfbox: summarize(cases.map((item) => item.pdfbox.providerResult)),
      mupdf: summarize(cases.map((item) => item.mupdf.providerResult)),
      comparison: compare(cases)
    },
    evidence: {
      tier: "Tier 3 local integration",
      sensitivity: "S1 with recovery and mutation-sensitive checks delegated to bakeoff test",
      claims: [
        "Provider capability and preservation are reported independently.",
        "Output digests, timestamps, object IDs, and xref details are not semantic parity fields.",
        "A successful provider process is not sufficient: independent qpdf, Poppler, reopen, and recovery observations are recorded.",
        "License observations are provenance evidence and not legal approval to ship."
      ]
    }
  };
  const reportPath = path.join(OUTPUT_DIR, "report.json");
  fs.writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`);
  process.stdout.write(`${JSON.stringify({ reportPath, fixtureCount: cases.length, summary: report.summary }, null, 2)}\n`);
  if (!cases.length) process.exitCode = 2;
}

function summarize(results) {
  const counts = {};
  for (const result of results) {
    for (const phase of ["inspection", "rewrite", "recovery"]) {
      const state = result[phase]?.status || "unknown";
      counts[`${phase}.${state}`] = (counts[`${phase}.${state}`] || 0) + 1;
    }
  }
  return counts;
}

function compare(cases) {
  return cases.map(({ fixture, pdfbox, mupdf }) => ({
    fixture,
    inspection: classify(pdfbox.providerResult.inspection.status, mupdf.providerResult.inspection.status),
    rewrite: classify(pdfbox.providerResult.rewrite.status, mupdf.providerResult.rewrite.status),
    recovery: classify(pdfbox.providerResult.recovery.status, mupdf.providerResult.recovery.status),
    semantic: {
      pdfbox: pdfbox.providerResult.rewrite.independentText || "notMeasured",
      mupdf: mupdf.providerResult.rewrite.semanticText || "notMeasured",
      independentRaster: mupdf.providerResult.rewrite.independentRaster || "notMeasured"
    }
  }));
}

function classify(left, right) {
  if (left === right) return { status: "aligned", state: left };
  if ([left, right].includes("unknown")) return { status: "unknown", left, right };
  return { status: "diverged", left, right };
}

main();
