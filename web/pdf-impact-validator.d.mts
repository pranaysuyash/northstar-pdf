/** Type declarations for the provider-neutral outside-region impact validator. */
export interface ImpactRect {
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface ImpactOperation {
  id: string;
  kind?: string;
  pageIndex?: number;
  coordinate?: {
    pageIndex?: number;
    rect?: ImpactRect;
    coordinateSpace?: { pageBox?: string };
  };
}

export interface TextImpactResult {
  status: string;
  message: string;
  metrics: Record<string, unknown>;
}

export interface RasterImpactResult {
  status: string;
  message: string;
  scale: number | null;
  metrics: Record<string, unknown>;
}

export declare function compareOutsideRegionText(options: {
  pdfjsLib: unknown;
  sourceDocument: unknown;
  outputDocument: unknown;
  operations: ImpactOperation[];
}): Promise<TextImpactResult>;

export declare function compareOutsideRegionRaster(options: {
  pdfjsLib: unknown;
  sourceDocument: unknown;
  outputDocument: unknown;
  operations: ImpactOperation[];
}): Promise<RasterImpactResult>;

export declare function compareOutsideRegions(options: {
  pdfjsLib: unknown;
  sourceDocument: unknown;
  outputDocument: unknown;
  operations: ImpactOperation[];
}): Promise<{ text: TextImpactResult; raster: RasterImpactResult }>;
