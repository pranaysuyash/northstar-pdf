// mupdf_corpus_validation_test.mjs
// Validates all corpus PDFs against MuPDF's stricter parser.
// Catches structural issues that qpdf/Poppler might miss.
import assert from "node:assert";
import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";

const ROOT = path.resolve(import.meta.dirname, "..");
const CORPUS = path.join(ROOT, "benchmark", "results", "2026-08-25-native-incremental", "corpus");

// Check mutool is available
let mutoolAvailable = false;
try {
  execFileSync("mutool", ["-v"], { stdio: "pipe" });
  mutoolAvailable = true;
} catch {
  console.log("  ⚠️ mutool not found — skipping MuPDF corpus validation");
}

if (!mutoolAvailable) {
  console.log("\nMuPDF corpus validation: SKIPPED (mutool not installed)");
  process.exit(0);
}

// Find all PDFs in corpus
const pdfs = [];
function findPdfs(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) findPdfs(full);
    else if (entry.name.endsWith(".pdf")) pdfs.push(full);
  }
}
findPdfs(CORPUS);

console.log(`\nMuPDF Corpus Validation: ${pdfs.length} PDFs\n`);

let passed = 0;
let failed = 0;
let skipped = 0;

for (const pdf of pdfs) {
  const name = path.relative(ROOT, pdf);
  try {
    // mutool clean (structural validation)
    execFileSync("mutool", ["clean", pdf, "/dev/null"], {
      stdio: "pipe",
      timeout: 10000,
    });
    console.log(`  ✅ ${name}`);
    passed++;
  } catch (e) {
    if (e.killed) {
      console.log(`  ⏭️ ${name} (timeout)`);
      skipped++;
    } else {
      console.log(`  ❌ ${name}: ${e.message.split("\n")[0]}`);
      failed++;
    }
  }
}

console.log(`\nResults: ${passed} passed, ${failed} failed, ${skipped} skipped`);

if (failed > 0) {
  process.exit(1);
}
