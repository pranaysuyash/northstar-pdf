/**
 * Type declarations for the framework-neutral reversible operation history
 * (operation-history.mjs).
 */
export type OperationKind =
  | "nativeFieldValue"
  | "synthesizeNativeField"
  | "overlayText";

export declare const OPERATION_KINDS: readonly OperationKind[];

export interface OperationHistory {
  operations: HistoryOperation[];
  undoneValues: never[];
}

export interface HistoryOperation {
  readonly kind: OperationKind;
  readonly targetID: string;
  readonly pageIndex: number;
  readonly value: string;
  readonly previousValue: string;
  readonly sequence: number;
  readonly confirmedAt: string;
  readonly undoneBy?: number;
  readonly undoes?: number;
  /** Provider-shaped authorization rectangle for coordinate-bearing operations. */
  readonly coordinate?: {
    pageIndex: number;
    rect: { x: number; y: number; width: number; height: number };
    coordinateSpace?: { unit?: string; origin?: string; pageBox?: string };
  };
}

export declare function createOperationHistory(): OperationHistory;

export declare function isOperationKind(kind: string): kind is OperationKind;

export declare function recordOperation(
  history: OperationHistory,
  operation: Omit<HistoryOperation, "sequence" | "confirmedAt" | "undoneBy" | "undoes">
): OperationHistory;

export declare function undoLastOperation(history: OperationHistory):
  | {
      history: OperationHistory;
      undoEntry: HistoryOperation;
      undoneTarget: HistoryOperation;
    }
  | null;

export declare function pendingOperations(history: OperationHistory): HistoryOperation[];
