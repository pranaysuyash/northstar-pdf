/**
 * Companion-lane Python resolver (canonical, web/).
 *
 * Resolves a Python interpreter that has the project's PDF utilities
 * (pikepdf, pypdf, pdfplumber) available. This is the canonical resolver for
 * ALL companion-runtime (Node) code that shells out to Python — web modules
 * and Tests alike. Before 2026-09-18, web/pdf-sanitize.mjs,
 * web/pdf-action-neutralize.mjs, and web/pdf-object-inspect.mjs spawned
 * "python3" directly, which violates the project rule ("Tests must never
 * hardcode python3 for pikepdf work") and fails on any machine where the
 * system Python lacks pikepdf — including CI runners, where the shared
 * environment is provided via $PDF_PYTHON.
 *
 * Preference order:
 *   1. $PDF_PYTHON (CI / explicit override)
 *   2. `python3` on PATH if it can import pikepdf
 *   3. The project's documented pdf-utils environment
 *      (docs/pdf-shared-util-venv-2026-08-25.md; derived from $HOME —
 *      runner-portable, never a hardcoded /Users/... path)
 *   4. `python3` as a last resort (calls will fail with a clear traceback)
 */
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const PDF_UTILS_ENV = path.join(
  os.homedir(),
  ".workbuddy-ai/binaries/python/envs/pdf-utils/bin/python"
);

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
