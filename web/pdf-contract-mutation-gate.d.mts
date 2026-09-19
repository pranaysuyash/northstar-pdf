/**
 * Type declarations for the canonical browser export mutation gate
 * (pdf-contract-mutation-gate.mjs). The gate is the only admitted pre-write
 * seam for the browser export lane: it validates the operation contract and
 * privacy preflight before any writer callback runs.
 */

export interface GateIssue {
  code: string;
  message: string;
  operationIDs?: string[];
}

export interface ExportableContractInput {
  currentSourceDigest: string;
  operations: readonly unknown[];
  pageCoordinates?: readonly unknown[];
  validation?: unknown;
  sourcePreflight?: unknown;
  expectedPreflightTransitions?: Readonly<Record<string, string>> | null;
  outputPreflight?: unknown;
  allowedChangedSurfaces?: readonly string[];
}

export declare class ContractMutationError extends Error {
  constructor(issues: GateIssue[] | GateIssue);
  readonly name: "ContractMutationError";
  code: string;
  issues: GateIssue[];
  operationIDs: string[];
  readerCode: string;
}

export declare function collectExportContractViolations(
  options?: ExportableContractInput
): GateIssue[];

export declare function assertExportableContract(
  options?: ExportableContractInput
): { ok: true; operationIDs: string[] };

export declare function guardedPdfLibExport(
  options: ExportableContractInput & { writer: () => unknown }
): Promise<unknown>;

export declare const WRITER_LANES: readonly ["pdf-lib", "incremental-form-writer"];

export declare function selectWriterLane(
  operations?: readonly unknown[]
): "pdf-lib" | "incremental-form-writer";

export declare function guardedSourcePreservingExport(
  options: ExportableContractInput & { writer: () => unknown }
): Promise<unknown>;
