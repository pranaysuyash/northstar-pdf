/**
 * Resolves a Python interpreter that has the project's PDF utilities
 * (pikepdf, pypdf, pdfplumber) available.
 *
 * Preference order:
 *   1. $PDF_PYTHON (CI / explicit override)
 *   2. `python3` on PATH if it can import pikepdf
 *   3. The project's documented pdf-utils environment
 *   4. `python3` as a last resort (tests will fail with a clear traceback)
 *
 * Tests must never hardcode "python3" for pikepdf work — the system Python
 * frequently lacks the project's declared PDF tooling.
 */
import { execFileSync } from "node:child_process";
import fs from "node:fs";

const PDF_UTILS_ENV = "/Users/pranay/.workbuddy-ai/binaries/python/envs/pdf-utils/bin/python";

function canImportPikepdf(python) {
  try {
    execFileSync(python, ["-c", "import pikepdf"], { stdio: "ignore", timeout: 10_000 });
    return true;
  } catch {
    return false;
  }
}

function resolve() {
  const explicit = process.env.PDF_PYTHON;
  if (explicit) return explicit;
  if (canImportPikepdf("python3")) return "python3";
  if (fs.existsSync(PDF_UTILS_ENV) && canImportPikepdf(PDF_UTILS_ENV)) return PDF_UTILS_ENV;
  return "python3";
}

export const pdfPython = resolve();