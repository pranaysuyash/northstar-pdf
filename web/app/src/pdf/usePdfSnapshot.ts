import { useSyncExternalStore } from "react";
import { pdfController, type PdfSnapshot } from "./PdfController";

export function usePdfSnapshot(): PdfSnapshot {
  return useSyncExternalStore(
    (listener) => pdfController.subscribe(listener),
    () => pdfController.getSnapshot()
  );
}
