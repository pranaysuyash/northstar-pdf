/**
 * Framework-neutral reversible operation history.
 *
 * Every confirmed mutation enters this history before any byte is written.
 * Like product-modes.mjs, this module contains no DOM and no provider code:
 * the browser entry, the React surface, and headless tests consume the same
 * immutable transitions. Undo is a pure projection: it never rewrites
 * history, it appends an undo record so lineage stays complete.
 */

export const OPERATION_KINDS = Object.freeze([
  "nativeFieldValue",
  "synthesizeNativeField",
  "overlayText"
]);

export function createOperationHistory() {
  return {
    operations: [],
    undoneValues: []
  };
}

export function isOperationKind(kind) {
  return OPERATION_KINDS.includes(kind);
}

function assertOperation(operation) {
  if (!operation || typeof operation !== "object") {
    throw new TypeError("Operation must be an object.");
  }
  if (!isOperationKind(operation.kind)) {
    throw new RangeError(`Unknown operation kind: ${operation.kind}`);
  }
  if (typeof operation.targetID !== "string" || !operation.targetID) {
    throw new RangeError("Operation requires a non-empty targetID.");
  }
}

/**
 * Records a confirmed operation. `previousValue` captures the observed source
 * value at confirmation time so undo can restore exactly what was there — not
 * a guessed default.
 */
export function recordOperation(history, operation) {
  assertOperation(operation);
  if (typeof operation.previousValue === "undefined") {
    throw new RangeError("Operation requires previousValue to remain reversible.");
  }
  const entry = Object.freeze({
    ...operation,
    sequence: history.operations.length + 1,
    confirmedAt: new Date().toISOString()
  });
  return {
    ...history,
    operations: [...history.operations, entry]
  };
}

/**
 * Appends an undo record for the last reversible operation. The undone entry
 * itself stays in the log with `undoneBy` set; the value restoration is the
 * caller's provider concern.
 */
export function undoLastOperation(history) {
  for (let i = history.operations.length - 1; i >= 0; i--) {
    const candidate = history.operations[i];
    if (candidate.undoneBy) continue;
    // An undo record is a lineage marker, not an editable mutation; it can
    // never become the target of another undo.
    if (candidate.undoes) continue;
    const undoEntry = Object.freeze({
      kind: candidate.kind,
      targetID: candidate.targetID,
      pageIndex: candidate.pageIndex,
      value: candidate.previousValue,
      previousValue: candidate.value,
      sequence: history.operations.length + 1,
      confirmedAt: new Date().toISOString(),
      undoes: candidate.sequence
    });
    const marked = { ...candidate, undoneBy: undoEntry.sequence };
    const operations = [...history.operations];
    operations[i] = marked;
    operations.push(undoEntry);
    return {
      history: { ...history, operations },
      undoEntry,
      undoneTarget: marked
    };
  }
  return null;
}

/** Pending (non-undo) operations in confirmation order — the export input. */
export function pendingOperations(history) {
  return history.operations.filter((operation) => !operation.undoneBy && !operation.undoes);
}
