/**
 * Minimal structural typings for the vendored pdf.js ESM runtime
 * (web/vendor/pdfjs/pdf.min.mjs). Only the surface the controller boundary
 * actually uses is declared; the full API stays behind the adapter.
 */
declare module "*/vendor/pdfjs/pdf.min.mjs" {
  export interface PdfViewport {
    width: number;
    height: number;
    rotation: number;
    readonly transform: number[];
    convertToPdfPoint(x: number, y: number): [number, number];
    convertToViewportPoint(x: number, y: number): [number, number];
  }

  export interface PdfTextItem {
    str: string;
    transform: number[];
    width: number;
    height: number;
  }

  export interface PdfTextContent {
    items: Array<PdfTextItem | { str?: undefined }>;
  }

  export interface PdfPageProxy {
    readonly pageNumber: number;
    readonly view: number[];
    rotate: number;
    getViewport(options: { scale: number; rotation?: number }): PdfViewport;
    render(options: {
      canvasContext: CanvasRenderingContext2D;
      viewport: PdfViewport;
    }): { promise: Promise<void>; cancel(): void };
    getTextContent(): Promise<PdfTextContent>;
    cleanup(): void;
    getAnnotations(options?: { intent?: string }): Promise<Array<Record<string, any>>>;
    getOperatorList(): Promise<{ fnArray: number[]; argsArray: unknown[] }>;
  }

  export interface PdfDocumentProxy {
    readonly numPages: number;
    getPage(pageNumber: number): Promise<PdfPageProxy>;
    destroy(): Promise<void>;
    getMetadata(): Promise<{ info: Record<string, unknown> }>;
    getFieldObjects?(): Promise<Record<string, unknown> | null>;
  }

  export interface PdfLoadingTask {
    promise: Promise<PdfDocumentProxy>;
    destroy(): Promise<void>;
    onPassword?: (callback: (password: string) => void, reason: number) => void;
  }

  export const GlobalWorkerOptions: { workerSrc: string };
  export const PasswordResponses: { NEED_PASSWORD: 1; INCORRECT_PASSWORD: 2 };
  export const Util: { transform(m1: number[], m2: number[]): number[] };
  export function getDocument(options: {
    data: Uint8Array | ArrayBuffer;
    password?: string;
  }): PdfLoadingTask;
}
