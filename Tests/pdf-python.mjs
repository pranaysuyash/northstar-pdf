/**
 * Test-side Python resolver — thin re-export shim.
 *
 * The canonical resolver lives in `web/pdf-python.mjs` so that companion
 * runtime modules (pdf-sanitize, pdf-action-neutralize, pdf-object-inspect)
 * and tests share ONE resolution rule. This shim keeps the historical
 * `import { pdfPython } from "./pdf-python.mjs"` sites working and preserves
 * the documented rule ("Tests must never hardcode python3 for pikepdf work").
 */
export { pdfPython } from "../web/pdf-python.mjs";
