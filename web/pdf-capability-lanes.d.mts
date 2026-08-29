/** Type declarations for the canonical PDF capability-lane vocabulary. */
export declare const PDF_CAPABILITY_LANES: readonly string[];
export declare const PDF_CAPABILITY_OUTCOMES: readonly string[];

export declare function createPDFCapabilityRequest(options: {
  lane: string;
  source: { byteCount: number; pageCount: number };
  sourceDigest: string;
  operationKinds?: string[];
  policy: Record<string, unknown>;
}): Record<string, unknown>;
