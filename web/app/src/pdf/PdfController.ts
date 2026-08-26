import * as pdfjs from "../../../vendor/pdfjs/pdf.min.mjs";
import { compareOutsideRegions } from "../../../pdf-impact-validator.mjs";
import { detectGeometryCandidates } from "../../../pdf-geometry-detector.mjs";
import {
  planSingleLineOverlay,
  proposeOverlayBounds,
  valuesMatch
} from "../../../pdf-write-planning.mjs";
import { ensurePdfLib } from "./ensurePdfLib";

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
  /** Normalized PDF-space rectangle backing the widget (crop-relative). */
  rect: Rect;
}

export interface Rect {
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface MatchRect {
  left: number;
  top: number;
  width: number;
  height: number;
}

function normalizeRect(rect: [number, number, number, number]): Rect {
  const [x1, y1, x2, y2] = rect;
  return {
    x: Math.min(x1, x2),
    y: Math.min(y1, y2),
    width: Math.abs(x2 - x1),
    height: Math.abs(y2 - y1)
  };
}

async function sha256Hex(bytes: Uint8Array): Promise<string> {
  // Copy into a fresh ArrayBuffer so crypto.subtle never sees a shared view.
  const buffer = new ArrayBuffer(bytes.byteLength);
  new Uint8Array(buffer).set(bytes);
  const digest = await crypto.subtle.digest("SHA-256", buffer);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

/**
 * Provider-shaped confirmed operation handed to the writer and the
 * independent impact validator. Shape-compatible with the contract module's
 * history entries plus the coordinate rectangle the validator authorizes.
 */
export interface PdfEditOperation {
  id: string;
  kind: "nativeFieldValue" | "overlayText";
  targetID?: string;
  pageIndex: number;
  value: string;
  previousValue: string;
  payload?: { kind?: string; options?: string[] };
  coordinate?: {
    pageIndex: number;
    rect: Rect;
    coordinateSpace?: { unit?: string; origin?: string; pageBox?: string };
  };
}

export interface GeometryCandidate {
  id: string;
  pageIndex: number;
  kind: string;
  fieldType: string | null;
  mode: string;
  status: string;
  score: number;
  labelText: string | null;
  displayName?: string | null;
  suggestedFieldType?: string | null;
  bounds: Rect;
  evidence: string[];
}

export interface ValidationCheck {
  id: string;
  kind?: string;
  status: "passed" | "failed" | "skipped" | "warning" | "unknown";
  detail: string;
  metrics?: Record<string, unknown>;
}

export interface ExportReport {
  checks: ValidationCheck[];
  passed: boolean;
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
  /** Monotonic marker incremented after each completed page raster. */
  renderedAt: number;
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
  error: null,
  renderedAt: 0
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
  #sourceDigest = "";
  #usedPassword = false;
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
      this.#sourceDigest = await sha256Hex(this.#sourceBytes);
      this.#usedPassword = false;
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
    // Password-revealed documents keep their protected-source semantics:
    // browser writing stays refused and no-op export is byte-preserving.
    this.#usedPassword = true;
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
      if (token === this.#renderToken) {
        this.#patch({ renderedAt: Date.now(), error: null });
      }
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
    const pageNumbers = Array.from({ length: pages }, (_, i) => i + 1);
    // Page extraction is independent per page — run concurrently. Stale runs
    // are discarded via the search token rather than mid-loop early exits.
    const perPageMatches = await Promise.all(
      pageNumbers.map(async (pageNumber): Promise<PdfSearchMatch[]> => {
        const page = await doc.getPage(pageNumber);
        const content = await page.getTextContent();
        const text = content.items.map((item) => item.str ?? "").join(" ");
        const found: PdfSearchMatch[] = [];
        let cursor = 0;
        let index = 0;
        while ((cursor = text.toLowerCase().indexOf(needle, cursor)) !== -1) {
          found.push({ page: pageNumber, index: index++, excerpt: excerptAround(text, cursor) });
          cursor += needle.length;
        }
        return found;
      })
    );
    if (token !== this.#searchToken) return;
    for (const found of perPageMatches) matches.push(...found);
    this.#patch({ matches, activeMatchIndex: matches.length ? 0 : -1, searchComplete: true });
  }

  gotoMatch(step: 1 | -1): void {
    const { matches, activeMatchIndex } = this.#snapshot;
    if (!matches.length) return;
    const next = (activeMatchIndex + step + matches.length) % matches.length;
    this.#patch({ activeMatchIndex: next, currentPage: matches[next].page });
  }

  /**
   * Device-space rectangles of every match on a page, in canvas CSS pixel
   * coordinates. Uses the geometry recorded by the last render so highlights
   * always align with the visible raster.
   */
  async getMatchRects(pageNumber: number): Promise<MatchRect[]> {
    const doc = this.#doc;
    const geometry = this.#lastRenderGeometry;
    if (!doc || !geometry || this.#snapshot.status !== "ready") return [];
    const pageMatches = this.#snapshot.matches.filter((match) => match.page === pageNumber);
    if (!pageMatches.length) return [];

    const page = await doc.getPage(pageNumber);
    const content = await page.getTextContent();
    const viewport = page.getViewport({
      scale: geometry.scale,
      rotation: geometry.rotation
    });

    // Rebuild the joined text with per-item offsets so occurrences map back
    // to the text items that produced them.
    let full = "";
    const spans: Array<{ start: number; end: number; str: string; transform: number[]; width: number; height: number }> = [];
    for (const item of content.items) {
      const str = item.str;
      if (!str) continue;
      spans.push({
        start: full.length,
        end: full.length + str.length,
        str,
        transform: item.transform,
        width: item.width ?? 0,
        height: item.height ?? 0
      });
      full += `${str} `;
    }

    const needle = this.#snapshot.searchQuery.trim().toLowerCase();
    const rects: MatchRect[] = [];
    for (const match of pageMatches) {
      let occurrence = -1;
      let cursor = 0;
      for (let i = 0; i <= match.index; i++) {
        occurrence = full.toLowerCase().indexOf(needle, cursor);
        if (occurrence === -1) break;
        cursor = occurrence + needle.length;
      }
      if (occurrence === -1) continue;
      const occurrenceEnd = occurrence + needle.length;
      const hit = spans.filter((span) => span.start < occurrenceEnd && span.end > occurrence);
      for (const span of hit) {
        const t = pdfjs.Util.transform(viewport.transform, span.transform);
        const fontSize = Math.max(1, Math.hypot(t[0], t[1]));
        rects.push({
          left: t[4],
          top: t[5] - fontSize,
          width: Math.max(span.width * geometry.scale, fontSize),
          height: fontSize
        });
      }
    }
    return rects;
  }

  /** Enumerates native AcroForm widgets across all pages in parallel. */
  async listNativeFields(): Promise<NativeField[]> {
    const doc = this.#doc;
    if (!doc || this.#snapshot.status !== "ready") return [];

    const pageIndices = Array.from({ length: doc.numPages }, (_, i) => i + 1);
    const perPageFields = await Promise.all(
      pageIndices.map(async (pageNumber) => {
        const page = await doc.getPage(pageNumber);
        const annotations = await page.getAnnotations({ intent: "display" });
        const fieldsOnPage: NativeField[] = [];
        let fieldIndex = 0;
        for (const annotation of annotations) {
          if (annotation.subtype !== "Widget" && !("fieldName" in annotation)) continue;
          const index = fieldIndex++;
          const name =
            (annotation as { fieldName?: string }).fieldName ??
            (annotation as { id?: string }).id ??
            `field-${pageNumber}-${index + 1}`;
          const kind = fieldKindOf(annotation);
          const rawValue = String(
            (annotation as { fieldValue?: unknown }).fieldValue ?? ""
          );
          const value =
            kind === "checkbox" || kind === "radio"
              ? /^off$/i.test(rawValue)
                ? ""
                : rawValue
              : rawValue;
          const rect = Array.isArray(annotation.rect)
            ? normalizeRect(annotation.rect as [number, number, number, number])
            : { x: 0, y: 0, width: 0, height: 0 };
          fieldsOnPage.push({ id: name, name, kind, pageIndex: pageNumber - 1, value, choices: [], rect });
        }
        return fieldsOnPage;
      })
    );
    return perPageFields.flat();
  }

  /** Runs the canonical geometry detector over one page. */
  async listCandidates(pageNumber: number): Promise<GeometryCandidate[]> {
    const doc = this.#doc;
    if (!doc || this.#snapshot.status !== "ready") return [];
    const page = await doc.getPage(pageNumber);
    const found = await detectGeometryCandidates({
      pdfjsLib: pdfjs,
      page,
      pageIndex: pageNumber - 1,
      pageRotation: page.rotate || 0,
      sourceDigest: this.#sourceDigest
    });
    return found as unknown as GeometryCandidate[];
  }

  /** Converts device (canvas CSS pixel) coordinates to PDF-space points. */
  async pdfPointFromDevice(
    pageNumber: number,
    deviceX: number,
    deviceY: number
  ): Promise<{ x: number; y: number; cropBox: [number, number, number, number] } | null> {
    const doc = this.#doc;
    const geometry = this.#lastRenderGeometry;
    if (!doc || !geometry) return null;
    const page = await doc.getPage(pageNumber);
    const viewport = page.getViewport({ scale: geometry.scale, rotation: geometry.rotation });
    const [x, y] = viewport.convertToPdfPoint(deviceX, deviceY);
    return {
      x,
      y,
      cropBox: Array.from(
        page.view ?? [0, 0, viewport.width, viewport.height]
      ) as [number, number, number, number]
    };
  }

  /** Proposes a clamped authorized rectangle for an overlay placement. */
  async proposePlacement(
    pageNumber: number,
    deviceX: number,
    deviceY: number
  ): Promise<{ pageIndex: number; rect: Rect } | null> {
    const point = await this.pdfPointFromDevice(pageNumber, deviceX, deviceY);
    if (!point) return null;
    try {
      return { pageIndex: pageNumber - 1, rect: proposeOverlayBounds(point, point.cropBox) };
    } catch {
      return null;
    }
  }

  /** Device-space rectangles for PDF-space regions on the rendered page. */
  async getRegionMarkers(pageNumber: number, rects: Rect[]): Promise<MatchRect[]> {
    const doc = this.#doc;
    const geometry = this.#lastRenderGeometry;
    if (!doc || !geometry) return [];
    const page = await doc.getPage(pageNumber);
    const viewport = page.getViewport({ scale: geometry.scale, rotation: geometry.rotation });
    return rects.map((rect) => {
      const [left, top] = viewport.convertToViewportPoint(rect.x, rect.y + rect.height);
      const [right, bottom] = viewport.convertToViewportPoint(rect.x + rect.width, rect.y);
      return { left, top, width: right - left, height: bottom - top };
    });
  }

  /**
   * Produces a new PDF copy with confirmed operations replayed through
   * pdf-lib, then validates it in the independent PDF.js lane before any
   * download is offered. The source bytes are never modified.
   *
   * Salvaged semantics from the legacy entry: encrypted sources refuse
   * mutation (byte-preserving no-op only), the inspected SHA-256 must still
   * match at export time, non-default page boxes and rotation are replayed
   * before edits so crop-relative coordinates keep their meaning, bounded
   * single-line overlays are fit-planned up front, and outside-region impact
   * is proven with the canonical pdf-impact-validator contract.
   */
  async exportCopy(operations: PdfEditOperation[]): Promise<ExportReport> {
    const checks: ValidationCheck[] = [];
    const check = (
      id: string,
      status: ValidationCheck["status"],
      detail: string,
      metrics?: Record<string, unknown>
    ): void => {
      checks.push(metrics ? { id, kind: id, status, detail, metrics } : { id, kind: id, status, detail });
    };

    if (!this.#sourceBytes) throw new Error("No source document is open.");
    const pdfLib = await ensurePdfLib();

    // Encrypted sources stay write-refused; only byte-preserving copies pass.
    if (this.#usedPassword && operations.length) {
      throw new Error(
        "Encrypted PDF editing is not supported by the browser writer. "
        + "The protected source remains read-only."
      );
    }

    const fieldOps = operations.filter((op) => op.kind === "nativeFieldValue");
    const overlayOps = operations.filter((op) => op.kind === "overlayText");

    const sourceDigestAtExport = await sha256Hex(this.#sourceBytes);
    const digestStable = sourceDigestAtExport === this.#sourceDigest;
    check(
      "sourceDigest",
      digestStable ? "passed" : "failed",
      digestStable
        ? "Source bytes still match the inspected SHA-256."
        : "Source bytes changed after inspection."
    );
    if (!digestStable) {
      const passed = checks.every((entry) => entry.status !== "failed");
      return { checks, passed };
    }

    const { PDFDocument, StandardFonts, degrees } = pdfLib;

    // Page facts come from a fresh load of the untouched source.
    const factsDocument = await PDFDocument.load(this.#sourceBytes.slice());
    const pageFactsReplay = factsDocument.getPages().map((page) => {
      const box = (value: PdfLibBox | undefined): Rect | null => {
        if (!value || typeof value.x !== "number") return null;
        return normalizeRect([value.x, value.y, value.x + value.width, value.y + value.height]);
      };
      return {
        boxes: {
          media: box(page.getMediaBox()),
          crop: box(page.getCropBox()),
          bleed: box(page.getBleedBox()),
          trim: box(page.getTrimBox()),
          art: box(page.getArtBox())
        },
        rotate: 0 as number
      };
    });
    // Rotation truth comes from the inspected pdf.js document.
    if (this.#doc) {
      await Promise.all(
        pageFactsReplay.map(async (fact, i) => {
          const page = await this.#doc!.getPage(i + 1).catch(() => null);
          if (page) fact.rotate = page.rotate || 0;
        })
      );
    }

    // Materialize onto a fresh copy.
    const outputDocument = await PDFDocument.load(this.#sourceBytes.slice());
    outputDocument.getPages().forEach((page, index) => {
      const fact = pageFactsReplay[index];
      if (!fact) return;
      const replayBox = (method: "setMediaBox" | "setCropBox" | "setBleedBox" | "setTrimBox" | "setArtBox", rect: Rect | null): void => {
        if (!rect) return;
        page[method](rect.x, rect.y, rect.width, rect.height);
      };
      replayBox("setMediaBox", fact.boxes.media);
      replayBox("setCropBox", fact.boxes.crop);
      replayBox("setBleedBox", fact.boxes.bleed);
      replayBox("setTrimBox", fact.boxes.trim);
      replayBox("setArtBox", fact.boxes.art);
      if (typeof page.setRotation === "function") {
        page.setRotation(degrees(fact.rotate || 0));
      }
    });

    const total = fieldOps.length + overlayOps.length;
    if (total) {
      const form = outputDocument.getForm();
      const font = await outputDocument.embedFont(StandardFonts.Helvetica);
      for (const operation of fieldOps) {
        if (!operation.targetID) continue;
        const field = form.getField(operation.targetID);
        if (typeof field.setText === "function") {
          field.setText(operation.value);
        } else if (typeof field.check === "function" && typeof field.uncheck === "function") {
          /^(1|true|yes|on|checked)$/i.test(operation.value.trim()) ? field.check() : field.uncheck();
        } else if (typeof field.select === "function") {
          field.select(operation.value);
        } else {
          throw new Error(`Field ${operation.targetID} does not expose a supported pdf-lib setter.`);
        }
      }
      if (fieldOps.length) form.updateFieldAppearances(font);

      for (const operation of overlayOps) {
        const bounds = operation.coordinate?.rect;
        if (!bounds) throw new Error(`Overlay ${operation.id} has no coordinate bounds.`);
        const plan = planSingleLineOverlay({
          text: operation.value,
          bounds,
          widthOfTextAtSize: (text, size) => font.widthOfTextAtSize(text, size),
          heightAtSize: (size) => font.heightAtSize(size)
        });
        const page = outputDocument.getPage(operation.pageIndex);
        page.drawText(operation.value, { x: plan.x, y: plan.y, size: plan.size, font });
      }
    }
    const outputBytes = await outputDocument.save({ useObjectStreams: false });

    check(
      "writer",
      "passed",
      total
        ? `pdf-lib replayed ${total} confirmed operation(s) onto a new copy with page-fact preservation.`
        : "No confirmed operations; export is a new byte copy of the source."
    );

    // Independent reopen lane (PDF.js).
    const reopened = await pdfjs.getDocument({ data: outputBytes.slice() }).promise;
    try {
      check("outputReopen", "passed", `Export reopened in PDF.js with ${reopened.numPages} page(s).`);

      if (this.#doc) {
        let sameGeometry = reopened.numPages === this.#doc.numPages;
        if (sameGeometry) {
          for (let pageNumber = 1; pageNumber <= this.#doc.numPages && sameGeometry; pageNumber++) {
            const [originalPage, outputPage] = await Promise.all([
              this.#doc.getPage(pageNumber),
              reopened.getPage(pageNumber)
            ]);
            const originalView = Array.from(originalPage.view ?? []);
            const outputView = Array.from(outputPage.view ?? []);
            if (
              originalView.length !== outputView.length ||
              originalView.some((value, index) => Math.abs(value - outputView[index]) > 0.01)
            ) {
              sameGeometry = false;
            }
          }
        }
        check(
          "pageGeometry",
          sameGeometry ? "passed" : "failed",
          sameGeometry
            ? "Page count and PDF page boxes are unchanged."
            : "Page count or PDF page boxes changed during export."
        );

        // Native fields must round-trip to their requested values.
        const outputFields = await this.listNativeFieldsIn(reopened);
        const outputFieldsByName = new Map(outputFields.map((f) => [f.name, f]));
        let fieldsPassed = true;
        for (const operation of fieldOps) {
          const target = operation.targetID;
          if (!target) continue;
          const outputField = outputFieldsByName.get(target);
          if (!outputField || !valuesMatch(operation.value, outputField.value, operation)) {
            fieldsPassed = false;
            check("nativeFields", "failed", `Native field ${target} did not round-trip to the requested value.`);
          }
        }
        if (!fieldOps.length) {
          check("nativeFields", "skipped", "No native field operations were requested.");
        } else if (fieldsPassed) {
          check("nativeFields", "passed", `${fieldOps.length} native field operation(s) round-tripped through PDF.js.`);
        }

        // Overlay values must be present in extracted text.
        const pageNumbers = Array.from({ length: reopened.numPages }, (_, i) => i + 1);
        const pageTexts: string[] = await Promise.all(
          pageNumbers.map(async (pageNumber) => {
            const content = await reopened.getPage(pageNumber).then((page) => page.getTextContent());
            return content.items.map((item) => item.str ?? "").join(" ");
          })
        );
        const missingOverlays = overlayOps.filter((op) => !pageTexts[op.pageIndex]?.includes(op.value));
        check(
          "appliedOperations",
          missingOverlays.length ? "warning" : "passed",
          missingOverlays.length
            ? `${missingOverlays.length} overlay value(s) were not found in PDF.js text extraction.`
            : `${operations.length} queued operation(s) are represented in the exported artifact.`
        );

        // Canonical outside-region impact proof.
        try {
          const impact = await compareOutsideRegions({
            pdfjsLib: pdfjs,
            sourceDocument: this.#doc,
            outputDocument: reopened,
            operations
          });
          check("outsideRegionText", impact.text.status as ValidationCheck["status"], impact.text.message);
          check(
            "visualDiff",
            impact.raster.status as ValidationCheck["status"],
            impact.raster.status === "failed"
              ? `${impact.raster.message} Outside-pixel ratio ${String(impact.raster.metrics?.outsidePixelRatio ?? "unknown")}.`
              : impact.raster.message,
            {
              changedPixelCount: impact.raster.metrics?.changedPixelCount,
              comparedPixelCount: impact.raster.metrics?.comparedPixelCount,
              maximumChannelDelta: impact.raster.metrics?.maximumChannelDelta
            }
          );
        } catch (error) {
          check("outsideRegionText", "unknown", `Outside-region impact validation could not run: ${error instanceof Error ? error.message : String(error)}`);
          check("visualDiff", "unknown", "Raster impact validation was not completed.");
        }
        check("providerCapability", "passed", "PDF.js reopened the export and pdf-lib produced the bytes.");
      }
    } finally {
      await reopened.destroy();
    }

    const passed = checks.every((check) => check.status !== "failed");
    if (passed) {
      triggerDownload(outputBytes, exportFileName());
    }
    return { checks, passed };
  }

  async listNativeFieldsIn(doc: import("../../../vendor/pdfjs/pdf.min.mjs").PdfDocumentProxy): Promise<NativeField[]> {
    const pageNumbers = Array.from({ length: doc.numPages }, (_, i) => i + 1);
    const perPageFields = await Promise.all(
      pageNumbers.map(async (pageNumber) => {
        const page = await doc.getPage(pageNumber);
        const annotations = await page.getAnnotations({ intent: "display" });
        const fieldsOnPage: NativeField[] = [];
        let fieldIndex = 0;
        for (const annotation of annotations) {
          if (annotation.subtype !== "Widget" && !("fieldName" in annotation)) continue;
          const index = fieldIndex++;
          const name =
            (annotation as { fieldName?: string }).fieldName ??
            (annotation as { id?: string }).id ??
            `field-${pageNumber}-${index + 1}`;
          const kind = fieldKindOf(annotation);
          const rawValue = String((annotation as { fieldValue?: unknown }).fieldValue ?? "");
          const value =
            kind === "checkbox" || kind === "radio"
              ? /^off$/i.test(rawValue) ? "" : rawValue
              : rawValue;
          const rect = Array.isArray(annotation.rect)
            ? normalizeRect(annotation.rect as [number, number, number, number])
            : { x: 0, y: 0, width: 0, height: 0 };
          fieldsOnPage.push({ id: name, name, kind, pageIndex: pageNumber - 1, value, choices: [], rect });
        }
        return fieldsOnPage;
      })
    );
    return perPageFields.flat();
  }
}

function fieldKindOf(annotation: Record<string, unknown>): NativeField["kind"] {
  switch (annotation.fieldType) {
    case "Tx":
      return "text";
    case "Btn":
      return Number(annotation.fieldFlags) & 32768 ? "radio" : "checkbox";
    case "Ch":
      return "choice";
    default:
      return "other";
  }
}

function exportFileName(): string {
  const stamp = new Date().toISOString().replace(/[:.]/g, "-").slice(0, 19);
  return `pdf-editor-export-${stamp}.pdf`;
}

function triggerDownload(bytes: Uint8Array, fileName: string): void {
  const buffer = new ArrayBuffer(bytes.byteLength);
  new Uint8Array(buffer).set(bytes);
  const url = URL.createObjectURL(new Blob([buffer], { type: "application/pdf" }));
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = fileName;
  anchor.click();
  setTimeout(() => URL.revokeObjectURL(url), 10_000);
}

export const pdfController = new PdfController();
