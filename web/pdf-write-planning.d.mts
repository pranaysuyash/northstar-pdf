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
