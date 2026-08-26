import pdfLibUrl from "../../../vendor/pdf-lib/pdf-lib.min.js?url";

/**
 * Loads the vendored UMD pdf-lib bundle once, same-origin only. The writer
 * stays behind PdfController; this module only guarantees window.PDFLib.
 */
let loaded = false;

export function ensurePdfLib(): void {
  if (loaded || window.PDFLib) {
    loaded = true;
    return;
  }
  const script = document.createElement("script");
  script.src = pdfLibUrl;
  script.async = true;
  document.head.appendChild(script);
  loaded = true;
}
