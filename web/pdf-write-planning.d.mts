/**
 * Type declarations for the pure write-planning contracts
 * (pdf-write-planning.mjs).
 */
export interface Rect {
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface FontMetrics {
  widthOfTextAtSize(text: string, size: number): number;
  heightAtSize(size: number): number;
}

export declare function valuesMatch(
  expected: string,
  actual: string,
  operation?: { payload?: { kind?: string; options?: string[] } }
): boolean;

export declare function planSingleLineOverlay(options: {
  text: string;
  bounds: Rect;
  widthOfTextAtSize(text: string, size: number): number;
  heightAtSize(size: number): number;
}): { x: number; y: number; size: number };

export declare const OVERLAY_PROPOSAL: Readonly<{
  widthPt: number;
  heightPt: number;
  paddingPt: number;
  minimumSizePt: number;
}>;

export declare function proposeOverlayBounds(
  point: { x: number; y: number },
  cropBox: [number, number, number, number],
  proposal?: typeof OVERLAY_PROPOSAL
): Rect;

export declare function assertWritable(options: {
  encrypted: boolean;
  operationCount: number;
}): void;

export interface PageFact {
  boxes: {
    media: Rect | null;
    crop: Rect | null;
    bleed: Rect | null;
    trim: Rect | null;
    art: Rect | null;
  };
  rotate: number;
}

/** Minimal structural shape of a loaded pdf-lib document (any binding). */
export interface PdfLibLikeDocument {
  getPages(): Array<{
    getMediaBox(): { x: number; y: number; width: number; height: number };
    getCropBox(): { x: number; y: number; width: number; height: number };
    getBleedBox(): { x: number; y: number; width: number; height: number };
    getTrimBox(): { x: number; y: number; width: number; height: number };
    getArtBox(): { x: number; y: number; width: number; height: number };
    setMediaBox(x: number, y: number, width: number, height: number): void;
    setCropBox(x: number, y: number, width: number, height: number): void;
    setBleedBox(x: number, y: number, width: number, height: number): void;
    setTrimBox(x: number, y: number, width: number, height: number): void;
    setArtBox(x: number, y: number, width: number, height: number): void;
    setRotation(rotation: { angle: number }): void;
  }>;
}

export declare function planPageFactReplay(
  sourceDocument: PdfLibLikeDocument,
  rotationOf?: (pageIndex: number) => number
): PageFact[];

export declare function applyPageFacts(
  outputDocument: PdfLibLikeDocument,
  facts: PageFact[],
  degrees: (angle: number) => { angle: number }
): void;
