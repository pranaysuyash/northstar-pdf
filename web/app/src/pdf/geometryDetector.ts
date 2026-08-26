/**
 * Typed gateway to the canonical browser geometry detector
 * (`web/pdf-geometry-detector.mjs`). Detection logic lives there and only
 * there; this module exists solely to give the React surface TypeScript
 * types via the upstream declaration file (pdf-geometry-detector.d.mts).
 */
import {
  detectGeometryCandidates as detectCanonical,
  type GeometryCandidate
} from "../../../pdf-geometry-detector.mjs";

export type DetectedCandidate = GeometryCandidate;

export function detectGeometryCandidates(input: {
  pdfjsLib: unknown;
  page: unknown;
  pageIndex: number;
  pageRotation?: number;
  sourceDigest: string;
}): Promise<DetectedCandidate[]> {
  return detectCanonical(input) as Promise<DetectedCandidate[]>;
}
