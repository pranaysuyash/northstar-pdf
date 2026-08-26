/** Type declarations for the canonical geometry candidate detector. */
export interface CandidateRect {
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface GeometryCandidate {
  id: string;
  pageIndex: number;
  bounds: CandidateRect;
  kind: string;
  status: string;
  score: number;
  evidence: string[];
  nativeFieldID: string | null;
  coordinate: {
    pageIndex: number;
    rect: CandidateRect;
    coordinateSpace: { unit: string; origin: string; pageBox: string; rotationDegrees: number };
  };
  suggestedFieldType: string | null;
  entryMode: string;
  labelText: string | null;
  displayName: string | null;
  groupMemberCount: number;
  memberBounds: CandidateRect[];
  memberLabels: string[];
  evidenceItems: Array<Record<string, unknown>>;
  fusion: Record<string, unknown>;
  sourceDigest: string;
}

export declare function detectGeometryCandidates(options: {
  pdfjsLib: unknown;
  page: unknown;
  pageIndex: number;
  pageRotation?: number;
  sourceDigest: string;
}): Promise<GeometryCandidate[]>;

export declare function canonicalizeLabelText(raw: string): { displayName?: string } | null;
