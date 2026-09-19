import {
  createOperationHistory,
  recordOperation,
  type HistoryOperation,
  type OperationHistory
} from "../../../operation-history.mjs";
import type {
  ExportReport,
  NativeField,
  OperationCoordinateSpace,
  Rect
} from "../pdf/PdfController";

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
  /** Digest binding + crop-space proof required by the mutation gate. */
  readonly sourceDigest: string;
  readonly rect: Rect;
  readonly rotationDegrees: number;
}

/** Coordinate evidence carried by every recorded operation. */
export interface OperationCoordinate {
  pageIndex: number;
  rect: Rect;
  bounds: Rect;
  coordinateSpace: OperationCoordinateSpace;
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
      sourceDigest: string;
      rect: Rect;
      rotationDegrees: number;
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
      sourceDigest: string;
      rotationDegrees: number;
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
      const coordinate: OperationCoordinate = {
        pageIndex: action.pageIndex,
        rect: action.rect,
        bounds: action.rect,
        coordinateSpace: {
          unit: "points",
          origin: "lowerLeft",
          pageBox: "crop",
          rotationDegrees: action.rotationDegrees
        }
      };
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
          previousValue: action.previousValue,
          sourceDigest: action.sourceDigest,
          bounds: action.rect,
          coordinate
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
          previousValue: update.previousValue,
          sourceDigest: update.sourceDigest,
          bounds: update.rect,
          coordinate: {
            pageIndex: update.pageIndex,
            rect: update.rect,
            coordinateSpace: {
              unit: "points",
              origin: "lowerLeft",
              pageBox: "crop",
              rotationDegrees: update.rotationDegrees
            }
          }
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
          sourceDigest: action.sourceDigest,
          bounds: action.rect,
          coordinate: {
            pageIndex: action.pageIndex,
            rect: action.rect,
            coordinateSpace: {
              unit: "points",
              origin: "lowerLeft",
              pageBox: "crop",
              rotationDegrees: action.rotationDegrees
            }
          }
        })
      };
  }
}
