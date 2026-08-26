import pdfLibUrl from "../../../vendor/pdf-lib/pdf-lib.min.js?url";

/**
 * Loads the vendored UMD pdf-lib bundle on demand, same-origin only.
 * The loader is idempotent and returns a cached promise so callers
 * can await readiness reliably without race conditions.
 */
let loadPromise: Promise<PdfLibGlobal> | null = null;

export function ensurePdfLib(): Promise<PdfLibGlobal> {
  if (window.PDFLib) {
    return Promise.resolve(window.PDFLib);
  }
  if (loadPromise) {
    return loadPromise;
  }

  loadPromise = new Promise<PdfLibGlobal>((resolve, reject) => {
    const existing = document.querySelector<HTMLScriptElement>(`script[src="${pdfLibUrl}"]`);
    if (existing) {
      if (window.PDFLib) {
        resolve(window.PDFLib);
        return;
      }
      existing.addEventListener("load", () => {
        if (window.PDFLib) resolve(window.PDFLib);
        else reject(new Error("pdf-lib loaded but window.PDFLib was not defined"));
      });
      existing.addEventListener("error", () => reject(new Error("Failed to load pdf-lib script")));
      return;
    }

    const script = document.createElement("script");
    script.src = pdfLibUrl;
    script.async = true;
    script.onload = () => {
      if (window.PDFLib) {
        resolve(window.PDFLib);
      } else {
        reject(new Error("pdf-lib loaded but window.PDFLib was not defined"));
      }
    };
    script.onerror = () => reject(new Error("Failed to load pdf-lib script"));
    document.head.appendChild(script);
  });

  return loadPromise;
}

