import { useCallback, useEffect, useReducer, useState } from "react";
import {
  productSurfaceReducer,
  type CapabilityState
} from "./state/productSurface";
import {
  createOperationHistory,
  pendingOperations,
  recordOperation,
  undoLastOperation,
  type HistoryOperation
} from "../../operation-history.mjs";
import { pdfController } from "./pdf/PdfController";
import type { ExportReport, NativeField } from "./pdf/PdfController";
import { usePdfSnapshot } from "./pdf/usePdfSnapshot";
import { ensurePdfLib } from "./pdf/ensurePdfLib";
import { Toolbar } from "./shell/Toolbar";
import { ModeRail } from "./shell/ModeRail";
import { ReaderStage } from "./modes/ReaderStage";
import {
  CompletePanel,
  OrganizePanel,
  ReviewPanel,
  UnderstandPanel
} from "./modes/ModePanels";
import { CompleteWorkbench } from "./modes/CompleteWorkbench";
import { ReviewWorkbench } from "./modes/ReviewWorkbench";

export function App() {
  ensurePdfLib();

  const [surface, dispatch] = useReducer(productSurfaceReducer, undefined, () =>
    // Lazy init keeps the reducer's contract module as the single state source.
    productSurfaceReducer(undefined, { type: "select-mode", modeID: "reader" })
  );
  const snapshot = usePdfSnapshot();
  const documentOpen = snapshot.status === "ready";

  const [fields, setFields] = useState<NativeField[]>([]);
  const [history, setHistory] = useState(createOperationHistory);
  const [exporting, setExporting] = useState(false);
  const [exportReport, setExportReport] = useState<ExportReport | null>(null);
  const [exportError, setExportError] = useState<string | null>(null);

  useEffect(() => {
    if (!documentOpen) {
      setFields([]);
      setHistory(createOperationHistory());
      setExportReport(null);
      setExportError(null);
      return;
    }
    void pdfController.listNativeFields().then(setFields);
    // Field enumeration is tied to the open document identity, not render churn.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [snapshot.status]);

  const handleDocumentOpened = useCallback(() => {
    dispatch({ type: "set-capability", modeID: "reader", capability: "loading" });
  }, []);

  const handleConfirmEdit = useCallback((field: NativeField, value: string) => {
    setFields((current) =>
      current.map((candidate) => (candidate.id === field.id ? { ...candidate, value } : candidate))
    );
    setHistory((current) =>
      recordOperation(current, {
        kind: "nativeFieldValue",
        targetID: field.id,
        pageIndex: field.pageIndex,
        value,
        previousValue: field.value
      })
    );
  }, []);

  const handleUndo = useCallback(() => {
    setHistory((current) => {
      const result = undoLastOperation(current);
      if (!result) return current;
      const restore = result.undoEntry.value;
      setFields((currentFields) =>
        currentFields.map((field) =>
          field.id === result.undoneTarget.targetID ? { ...field, value: restore } : field
        )
      );
      return result.history;
    });
  }, []);

  const handleExport = useCallback(() => {
    if (exporting) return;
    setExporting(true);
    setExportError(null);
    void pdfController
      .exportCopy(
        pendingOperations(history)
          .filter((op) => op.kind === "nativeFieldValue")
          .map((op) => ({
            kind: "nativeFieldValue" as const,
            targetID: op.targetID,
            pageIndex: op.pageIndex,
            value: op.value
          }))
      )
      .then((report) => {
        setExportReport(report);
        if (report.passed) {
          dispatch({ type: "set-capability", modeID: "review", capability: "validated" });
        }
      })
      .catch((error: unknown) => {
        setExportError(error instanceof Error ? error.message : String(error));
      })
      .finally(() => setExporting(false));
  }, [exporting, history]);

  const readerCapability: CapabilityState =
    snapshot.status === "ready"
      ? "available"
      : snapshot.status === "loading" || snapshot.status === "password"
        ? "loading"
        : snapshot.status === "failed"
          ? "failed"
          : surface.capabilities.reader;

  const capabilities = { ...surface.capabilities, reader: readerCapability };
  const pendingOps: HistoryOperation[] = pendingOperations(history);

  return (
    <>
      <a className="skip-link" href="#viewerMain">
        Skip to document viewer
      </a>
      <Toolbar snapshot={snapshot} onDocumentOpened={handleDocumentOpened} />
      <div className="workspace">
        <aside className="panel" aria-label="Product modes">
          <ModeRail
            activeMode={surface.activeMode}
            capabilities={capabilities}
            onSelect={(modeID) => dispatch({ type: "select-mode", modeID })}
          />
        </aside>

        <main id="viewerMain" className="panel" tabIndex={-1} aria-label="PDF document viewer">
          <ReaderStage snapshot={snapshot} />
        </main>

        <aside className="panel" aria-label="Session detail">
          {surface.activeMode === "understand" && (
            <UnderstandPanel hasDocument={documentOpen} />
          )}
          {surface.activeMode === "complete" && (
            <>
              <CompletePanel hasDocument={documentOpen} />
              <CompleteWorkbench
                fields={fields}
                onConfirmEdit={handleConfirmEdit}
                canUndo={history.operations.some((op) => !op.undoneBy && !op.undoes)}
                onUndo={handleUndo}
              />
            </>
          )}
          {surface.activeMode === "organize" && (
            <OrganizePanel hasDocument={documentOpen} />
          )}
          {surface.activeMode === "review" && (
            <>
              <ReviewPanel hasDocument={documentOpen} pageCount={snapshot.pageCount} />
              <ReviewWorkbench
                pendingOps={pendingOps}
                totalEntries={history.operations.length}
                exporting={exporting}
                report={exportReport}
                error={exportError}
                onExport={handleExport}
              />
            </>
          )}
          {surface.activeMode === "reader" && (
            <>
              <div className="list-title">Metadata</div>
              <div className="small muted">
                {Object.keys(snapshot.metadata).length
                  ? Object.entries(snapshot.metadata)
                      .slice(0, 6)
                      .map(([key, value]) => (
                        <div key={key}>
                          {key}: {String(value)}
                        </div>
                      ))
                  : "No document open."}
              </div>
              <div className="list-title">Search matches</div>
              <div className="small">
                {snapshot.matches.length === 0 ? (
                  <span className="muted">
                    {snapshot.searchQuery
                      ? `No matches for “${snapshot.searchQuery}”.`
                      : "Run a search to list page-indexed matches."}
                  </span>
                ) : (
                  snapshot.matches.slice(0, 50).map((match, i) => (
                    <button
                      key={`${match.page}-${match.index}`}
                      type="button"
                      className={`item${i === snapshot.activeMatchIndex ? " is-active-match" : ""}`}
                      onClick={() => pdfController.setPage(match.page)}
                      style={{ display: "block", width: "100%", textAlign: "start" }}
                    >
                      Page {match.page}: {match.excerpt}
                    </button>
                  ))
                )}
                {!snapshot.searchComplete && <span aria-live="polite">Searching…</span>}
              </div>
            </>
          )}
        </aside>
      </div>
    </>
  );
}
