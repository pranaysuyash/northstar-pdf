import { test } from "node:test";
import assert from "node:assert/strict";

const {
  OPERATION_KINDS,
  createOperationHistory,
  isOperationKind,
  pendingOperations,
  recordOperation,
  undoLastOperation
} = await import("../web/operation-history.mjs");

test("operation history starts empty and exposes the kind vocabulary", () => {
  const history = createOperationHistory();
  assert.deepEqual(history.operations, []);
  assert.deepEqual([...OPERATION_KINDS], [
    "nativeFieldValue",
    "synthesizeNativeField",
    "overlayText"
  ]);
  assert.equal(isOperationKind("nativeFieldValue"), true);
  assert.equal(isOperationKind("deletePage"), false);
});

test("recordOperation requires previousValue so every entry stays reversible", () => {
  const history = createOperationHistory();
  assert.throws(
    () => recordOperation(history, { kind: "nativeFieldValue", targetID: "name", pageIndex: 0, value: "Ada" }),
    /previousValue/
  );
  assert.throws(
    () => recordOperation(history, { kind: "deletePages", targetID: "x", pageIndex: 0, value: "", previousValue: "" }),
    /Unknown operation kind/
  );
});

test("recorded operations get monotonic sequence numbers and immutable entries", () => {
  let history = createOperationHistory();
  history = recordOperation(history, {
    kind: "nativeFieldValue", targetID: "name", pageIndex: 0, value: "Ada", previousValue: ""
  });
  history = recordOperation(history, {
    kind: "overlayText", targetID: "overlay-1", pageIndex: 1, value: "Signed", previousValue: ""
  });
  assert.equal(history.operations.length, 2);
  assert.deepEqual(history.operations.map((op) => op.sequence), [1, 2]);
  assert.throws(() => { "use strict"; delete history.operations[0].kind; }, TypeError);
});

test("undoLastOperation restores previousValue as a new lineage entry", () => {
  let history = createOperationHistory();
  history = recordOperation(history, {
    kind: "nativeFieldValue", targetID: "name", pageIndex: 0, value: "Ada", previousValue: "Grace"
  });
  const result = undoLastOperation(history);
  assert.ok(result);
  assert.equal(result.undoEntry.value, "Grace");
  assert.equal(result.undoEntry.previousValue, "Ada");
  assert.equal(result.undoEntry.undoes, 1);
  // The original entry stays in the log, marked as undone — no rewriting.
  assert.equal(result.history.operations.length, 2);
  assert.equal(result.history.operations[0].undoneBy, result.undoEntry.sequence);

  const again = undoLastOperation(result.history);
  assert.equal(again, null, "undo must not repeat an already-undone operation");
});

test("pendingOperations excludes undone and undo entries from export input", () => {
  let history = createOperationHistory();
  history = recordOperation(history, {
    kind: "nativeFieldValue", targetID: "a", pageIndex: 0, value: "1", previousValue: ""
  });
  history = recordOperation(history, {
    kind: "nativeFieldValue", targetID: "b", pageIndex: 0, value: "2", previousValue: ""
  });
  const undone = undoLastOperation(history);
  const pending = pendingOperations(undone.history);
  // Undo removed the last confirmed operation ("b"); "a" remains pending.
  assert.deepEqual(pending.map((op) => op.targetID), ["a"]);
  assert.equal(undone.undoEntry.targetID, "b");
});
