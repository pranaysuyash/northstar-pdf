import {
  createOperationHistory,
  recordOperation,
  type HistoryOperation,
  type OperationHistory
} from "../../../operation-history.mjs";
import type { ExportReport, NativeField } from "../pdf/PdfController";

/**
 * Single source of truth for everything tied to the currently open document.
 * Consolidated into one reducer so related mutations stay atomic and every
 * updater remains pure (React may invoke reducers more than once).
 */
export interface EditorSessionState {
  fields: NativeField[];
  selectedFieldId: string | null;
  history: OperationHistory;
  exporting: boolean;
  exportReport: ExportReport | null;
  exportError: string | null;
}

export interface AutofillUpdate {
  readonly targetID: string;
  readonly pageIndex: number;
  readonly previousValue: string;
  readonly value: string;
}

/** Result payload produced by the pure `undoLastOperation` helper. */
export interface UndoOutcome {
  history: OperationHistory;
  undoEntry: HistoryOperation;
  undoneTarget: HistoryOperation;
}

export type EditorSessionAction =
  | { type: "reset-session" }
  | { type: "fields-loaded"; fields: NativeField[] }
  | { type: "select-field"; fieldID: string | null }
  | {
      type: "edit-field";
      fieldID: string;
      pageIndex: number;
      value: string;
      previousValue: string;
    }
  | { type: "undo-applied"; outcome: UndoOutcome }
  | { type: "autofill-applied"; updates: readonly AutofillUpdate[] }
  | { type: "export-started" }
  | { type: "export-succeeded"; report: ExportReport }
  | { type: "export-failed"; message: string }
  | {
      type: "placement-confirmed";
      targetID: string;
      pageIndex: number;
      value: string;
      rect: { x: number; y: number; width: number; height: number };
    };

export function createEditorSessionState(): EditorSessionState {
  return {
    fields: [],
    selectedFieldId: null,
    history: createOperationHistory(),
    exporting: false,
    exportReport: null,
    exportError: null
  };
}

export function editorSessionReducer(
  state: EditorSessionState,
  action: EditorSessionAction
): EditorSessionState {
  switch (action.type) {
    case "reset-session":
      return createEditorSessionState();
    case "fields-loaded":
      return {
        ...state,
        fields: action.fields,
        selectedFieldId: action.fields.length > 0 ? action.fields[0].id : null
      };
    case "select-field":
      return { ...state, selectedFieldId: action.fieldID };
    case "edit-field": {
      return {
        ...state,
        fields: state.fields.map((field) =>
          field.id === action.fieldID ? { ...field, value: action.value } : field
        ),
        history: recordOperation(state.history, {
          kind: "nativeFieldValue",
          targetID: action.fieldID,
          pageIndex: action.pageIndex,
          value: action.value,
          previousValue: action.previousValue
        })
      };
    }
    case "undo-applied":
      return {
        ...state,
        history: action.outcome.history,
        fields: state.fields.map((field) =>
          field.id === action.outcome.undoneTarget.targetID
            ? { ...field, value: action.outcome.undoEntry.value }
            : field
        )
      };
    case "autofill-applied": {
      let history = state.history;
      for (const update of action.updates) {
        history = recordOperation(history, {
          kind: "nativeFieldValue",
          targetID: update.targetID,
          pageIndex: update.pageIndex,
          value: update.value,
          previousValue: update.previousValue
        });
      }
      return {
        ...state,
        fields: state.fields.map((field) => {
          const update = action.updates.find((u) => u.targetID === field.id);
          return update ? { ...field, value: update.value } : field;
        }),
        history
      };
    }
    case "export-started":
      return { ...state, exporting: true, exportError: null };
    case "export-succeeded":
      return { ...state, exporting: false, exportReport: action.report };
    case "export-failed":
      return { ...state, exporting: false, exportError: action.message };
    case "placement-confirmed":
      return {
        ...state,
        history: recordOperation(state.history, {
          kind: "overlayText",
          targetID: action.targetID,
          pageIndex: action.pageIndex,
          value: action.value,
          previousValue: "",
          coordinate: {
            pageIndex: action.pageIndex,
            rect: action.rect,
            coordinateSpace: { unit: "points", origin: "lowerLeft", pageBox: "crop" }
          }
        })
      };
  }
}
