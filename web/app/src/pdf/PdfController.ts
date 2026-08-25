import * as pdfjs from "../../../vendor/pdfjs/pdf.min.mjs";

pdfjs.GlobalWorkerOptions.workerSrc = new URL(
  "../../../vendor/pdfjs/pdf.worker.min.mjs",
  import.meta.url
).href;

export type PdfControllerStatus = "idle" | "loading" | "ready" | "password" | "failed";

export type FitMode = "fitWidth" | "fitPage" | "zoom";

export interface PdfSearchMatch {
  page: number;
  index: number;
  excerpt: string;
}

export interface NativeField {
  id: string;
  name: string;
  kind: "text" | "checkbox" | "radio" | "choice" | "other";
  pageIndex: number;
  value: string;
  choices: string[];
}

export interface MatchRect {
  left: number;
  top: number;
  width: number;
  height: number;
}

export interface ValidationCheck {
  id: string;
  status: "passed" | "failed" | "skipped";
  detail: string;
}

export interface ExportReport {
  checks: ValidationCheck[];
  passed: boolean;
}

/** Minimal shape of the pending native-field edit operations at export time. */
export interface FieldEditOperation {
  kind: "nativeFieldValue";
  targetID: string;
  pageIndex: number;
  value: string;
}

export interface PdfSnapshot {
  status: PdfControllerStatus;
  pageCount: number;
  currentPage: number;
  zoomPercent: number;
  fitMode: FitMode;
  rotation: number;
  searchQuery: string;
  matches: PdfSearchMatch[];
  activeMatchIndex: number;
  searchComplete: boolean;
  metadata: Record<string, unknown>;
  error: string | null;
}

const INITIAL_SNAPSHOT: PdfSnapshot = {
  status: "idle",
  pageCount: 0,
  currentPage: 0,
  zoomPercent: 100,
  fitMode: "fitWidth",
  rotation: 0,
  searchQuery: "",
  matches: [],
  activeMatchIndex: -1,
  searchComplete: true,
  metadata: {},
  error: null
};

type Listener = () => void;

function excerptAround(text: string, at: number, span = 48): string {
  const start = Math.max(0, at - span);
  const end = Math.min(text.length, at + span);
  return (start > 0 ? "…" : "") + text.slice(start, end).trim() + (end < text.length ? "…" : "");
}

/**
 * Controller boundary for the Reader surface. This class owns the pdf.js
 * runtime — worker lifecycle, document loading, page rendering, text search,
 * and cancellation. React components subscribe to immutable snapshots and
 * never import pdf.js themselves.
 */
export class PdfController {
  #snapshot: PdfSnapshot = INITIAL_SNAPSHOT;
  #listeners = new Set<Listener>();
  #doc: import("../../../vendor/pdfjs/pdf.min.mjs").PdfDocumentProxy | null = null;
  #loadingTask: { destroy(): Promise<void> } | null = null;
  #renderToken = 0;
  #searchToken = 0;
  #sourceBytes: Uint8Array | null = null;
  #lastRenderGeometry: { scale: number; rotation: number } | null = null;

  getSnapshot(): PdfSnapshot {
    return this.#snapshot;
  }

  subscribe(listener: Listener): () => void {
    this.#listeners.add(listener);
    return () => this.#listeners.delete(listener);
  }

  #patch(patch: Partial<PdfSnapshot>): void {
    this.#snapshot = { ...this.#snapshot, ...patch };
    for (const listener of this.#listeners) listener();
  }

  async open(data: ArrayBuffer): Promise<void> {
    await this.close();
    this.#patch({ status: "loading", error: null });
    try {
      const bytes = new Uint8Array(data);
      this.#sourceBytes = bytes.slice();
      const task = pdfjs.getDocument({ data: bytes.slice() });
      task.onPassword = (callback) => {
        this.#pendingPassword = callback;
        this.#patch({ status: "password" });
      };
      this.#loadingTask = task;
      const doc = await task.promise;
      this.#doc = doc;
      let metadata: Record<string, unknown> = {};
      try {
        metadata = (await doc.getMetadata()).info ?? {};
      } catch {
        metadata = {};
      }
      this.#patch({
        status: "ready",
        pageCount: doc.numPages,
        currentPage: 1,
        metadata
      });
    } catch (error) {
      if ((error as { name?: string }).name === "PasswordException") {
        this.#patch({ status: "failed", error: "Password protected document." });
        return;
      }
      this.#patch({
        status: "failed",
        error: error instanceof Error ? error.message : String(error)
      });
    }
  }

  #pendingPassword: ((password: string) => void) | null = null;

  submitPassword(password: string): boolean {
    const resolve = this.#pendingPassword;
    if (!resolve) return false;
    this.#pendingPassword = null;
    resolve(password);
    return true;
  }

  cancelPassword(): void {
    this.#pendingPassword = null;
    void this.#loadingTask?.destroy();
    this.#loadingTask = null;
    this.#patch({ status: "idle" });
  }

  async close(): Promise<void> {
    this.#renderToken += 1;
    this.#searchToken += 1;
    await this.#doc?.destroy();
    this.#doc = null;
    this.#sourceBytes = null;
    this.#lastRenderGeometry = null;
    this.#snapshot = INITIAL_SNAPSHOT;
    for (const listener of this.#listeners) listener();
  }

  setPage(page: number): void {
    if (!this.#doc || page < 1 || page > this.#doc.numPages) return;
    this.#patch({ currentPage: page });
  }

  nextPage(): void {
    this.setPage(this.#snapshot.currentPage + 1);
  }

  previousPage(): void {
    this.setPage(this.#snapshot.currentPage - 1);
  }

  setFitMode(fitMode: FitMode): void {
    this.#patch({ fitMode });
  }

  setZoom(zoomPercent: number): void {
    this.#patch({ zoomPercent: Math.min(400, Math.max(25, zoomPercent)) });
  }

  rotate(delta: number): void {
    const next = (((this.#snapshot.rotation + delta) % 360) + 360) % 360;
    this.#patch({ rotation: next });
  }

  /**
   * Renders the current page into a canvas element. Cancellation is token
   * based: any newer call invalidates in-flight renders, and unmounting the
   * host element aborts through the returned cleanup.
   */
  renderInto(canvas: HTMLCanvasElement, signal?: AbortSignal): () => void {
    const token = ++this.#renderToken;
    const snapshot = this.#snapshot;
    const doc = this.#doc;
    if (!doc || snapshot.status !== "ready") return () => undefined;

    const run = async (): Promise<void> => {
      const page = await doc.getPage(snapshot.currentPage);
      if (token !== this.#renderToken) return;

      const baseViewport = page.getViewport({ scale: 1 });
      const containerWidth = canvas.parentElement?.clientWidth ?? baseViewport.width;
      let scale = snapshot.zoomPercent / 100;
      if (snapshot.fitMode === "fitWidth") {
        scale = containerWidth / baseViewport.width;
      } else if (snapshot.fitMode === "fitPage") {
        const containerHeight = canvas.parentElement?.clientHeight ?? baseViewport.height;
        scale = Math.min(
          containerWidth / baseViewport.width,
          containerHeight / baseViewport.height
        );
      }

      const viewport = page.getViewport({
        scale,
        rotation: (page.rotate + snapshot.rotation) % 360
      });
      this.#lastRenderGeometry = { scale, rotation: viewport.rotation };
      const context = canvas.getContext("2d");
      if (!context) return;
      canvas.width = Math.floor(viewport.width);
      canvas.height = Math.floor(viewport.height);
      const renderTask = page.render({ canvasContext: context, viewport });
      signal?.addEventListener("abort", () => renderTask.cancel(), { once: true });
      await renderTask.promise.catch(() => undefined);
    };

    void run().catch((error) => {
      if (token === this.#renderToken) {
        this.#patch({ error: error instanceof Error ? error.message : String(error) });
      }
    });

    return () => {
      this.#renderToken += 1;
    };
  }

  async search(query: string): Promise<void> {
    const doc = this.#doc;
    const token = ++this.#searchToken;
    const needle = query.trim().toLowerCase();
    if (!needle || !doc || this.#snapshot.status !== "ready") {
      this.#patch({ searchQuery: "", matches: [], activeMatchIndex: -1, searchComplete: true });
      return;
    }
    this.#patch({ searchQuery: query, searchComplete: false, matches: [], activeMatchIndex: -1 });

    const matches: PdfSearchMatch[] = [];
    const pages = doc.numPages;
    for (let pageNumber = 1; pageNumber <= pages; pageNumber++) {
      if (!this.#snapshot.searchQuery) break;
      const page = await doc.getPage(pageNumber);
      const content = await page.getTextContent();
      if (token !== this.#searchToken) return;
      const text = content.items.map((item) => item.str ?? "").join(" ");
      let cursor = 0;
      let index = 0;
      while ((cursor = text.toLowerCase().indexOf(needle, cursor)) !== -1) {
        matches.push({ page: pageNumber, index: index++, excerpt: excerptAround(text, cursor) });
        cursor += needle.length;
      }
      if (matches.length && pageNumber % 8 === 0) {
        this.#patch({ matches: [...matches], activeMatchIndex: 0 });
      }
    }
    if (token !== this.#searchToken) return;
    this.#patch({ matches, activeMatchIndex: matches.length ? 0 : -1, searchComplete: true });
  }

  gotoMatch(step: 1 | -1): void {
    const { matches, activeMatchIndex } = this.#snapshot;
    if (!matches.length) return;
    const next = (activeMatchIndex + step + matches.length) % matches.length;
    this.#patch({ activeMatchIndex: next, currentPage: matches[next].page });
  }
}

export const pdfController = new PdfController();
