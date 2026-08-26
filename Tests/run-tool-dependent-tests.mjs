#!/usr/bin/env node
/**
 * CI runner for external-tool-dependent node tests.
 *
 * Detects which tools are available (qpdf, poppler, pikepdf, verapdf, python3)
 * and runs only the tests whose dependencies are satisfied. Skipped tests are
 * reported with a clear diagnostic, not treated as failures.
 *
 * Usage:
 *   node Tests/run-tool-dependent-tests.mjs          # run all available
 *   node Tests/run-tool-dependent-tests.mjs --dry-run # list what would run
 *
 * Exit code: 0 when every *run* test passes, 1 on any failure.
 * Skipped tests do NOT affect the exit code.
 */
import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(__dirname, "..");
const dryRun = process.argv.includes("--dry-run");

// ── Tool detection ──────────────────────────────────────────────────────

function has(cmd) {
  try {
    const r = spawnSync("which", [cmd], { encoding: "utf8", stdio: "pipe" });
    return r.status === 0;
  } catch {
    return false;
  }
}

function hasPythonModule(mod) {
  try {
    const r = spawnSync(
      "python3",
      ["-c", `import ${mod}`],
      { encoding: "utf8", stdio: "pipe" }
    );
    return r.status === 0;
  } catch {
    return false;
  }
}

const tools = {
  qpdf: has("qpdf"),
  poppler: has("pdftotext") && has("pdftoppm"),
  pikepdf: hasPythonModule("pikepdf"),
  python3: has("python3"),
  verapdf: existsSync(path.join(projectRoot, "tools", "verapdf")),
};

// ── Test registry ───────────────────────────────────────────────────────
// Each entry: { file, needs: [tool1, tool2, ...] }
// A test runs only when ALL its needed tools are present.

const registry = [
  // qpdf-only
  { file: "Tests/encrypted_companion_export_test.mjs", needs: ["qpdf", "pikepdf"] },
  { file: "Tests/pdf_corpus_governance_test.mjs", needs: ["qpdf"] },

  // poppler-only
  { file: "Tests/text_run_simple_provider_test.mjs", needs: ["qpdf", "poppler"] },

  // pikepdf-only
  { file: "Tests/pdf-attachment-scanner_test.mjs", needs: ["pikepdf"] },
  { file: "Tests/pdf-hidden-revision-analyzer_test.mjs", needs: ["pikepdf"] },
  { file: "Tests/pdf-sanitize-audited_test.mjs", needs: ["pikepdf"] },
  { file: "Tests/pdf-signature-guard_test.mjs", needs: ["pikepdf"] },
  { file: "Tests/pdf-source-preserving-lane_test.mjs", needs: ["pikepdf"] },
  { file: "Tests/pdf-xfa-guard_test.mjs", needs: ["pikepdf"] },
  { file: "Tests/rotated_operation_replay_test.mjs", needs: ["pikepdf"] },

  // qpdf + pikepdf
  { file: "Tests/pdf-action-neutralize_test.mjs", needs: ["qpdf", "pikepdf"] },
  { file: "Tests/pdf-incremental-form-writer_test.mjs", needs: ["qpdf", "pikepdf"] },
  { file: "Tests/pdf-sanitize_test.mjs", needs: ["qpdf", "pikepdf"] },

  // pikepdf + poppler
  { file: "Tests/redaction_completeness_validator_test.mjs", needs: ["pikepdf"] },

  // full suite
  { file: "Tests/fixture-corpus-sweep_test.mjs", needs: ["qpdf", "poppler", "pikepdf"] },

  // Note: cross_project_evidence_ledger_parity_test.mjs and
  // perf-continuous-view_test.mjs need Playwright (not listed here;
  // handled by run-web-e2e.mjs instead).
];

// ── Runner ──────────────────────────────────────────────────────────────

const available = [];
const skipped = [];

for (const entry of registry) {
  const missing = entry.needs.filter((t) => !tools[t]);
  if (missing.length === 0) {
    available.push(entry);
  } else {
    skipped.push({ ...entry, missing });
  }
}

console.log("Tool detection:");
for (const [name, present] of Object.entries(tools)) {
  console.log(`  ${name}: ${present ? "✓" : "✗ MISSING"}`);
}
console.log(`\nTests: ${available.length} available, ${skipped.length} skipped`);

if (skipped.length > 0) {
  console.log("\nSkipped (missing dependencies):");
  for (const s of skipped) {
    console.log(`  ${path.basename(s.file)} — needs: ${s.missing.join(", ")}`);
  }
}

if (dryRun) {
  console.log("\nWould run:");
  for (const a of available) {
    console.log(`  ${path.basename(a.file)}`);
  }
  process.exit(0);
}

// ── Execute ─────────────────────────────────────────────────────────────

let passed = 0;
let failed = 0;
const errors = [];

for (const entry of available) {
  const filePath = path.join(projectRoot, entry.file);
  if (!existsSync(filePath)) {
    console.log(`\nSKIP ${path.basename(entry.file)} (file not found)`);
    continue;
  }

  console.log(`\n=== ${path.basename(entry.file)} ===`);
  const result = spawnSync(process.execPath, [filePath], {
    cwd: projectRoot,
    encoding: "utf8",
    stdio: "inherit",
    timeout: 120_000,
  });

  if (result.status === 0) {
    passed++;
  } else {
    failed++;
    errors.push(path.basename(entry.file));
  }
}

console.log(`\n${"─".repeat(60)}`);
console.log(`Tool-dependent gate: ${passed} passed, ${failed} failed, ${skipped.length} skipped`);

if (failed > 0) {
  console.log(`Failures: ${errors.join(", ")}`);
  process.exit(1);
}
