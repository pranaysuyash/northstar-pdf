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
import { AgentCommandHUD, type CommandItem } from "./shell/AgentCommandHUD";
import { ContextualInspector } from "./shell/ContextualInspector";
import { PageThumbnailRail } from "./shell/PageThumbnailRail";

export function App() {
  ensurePdfLib();

  const [surface, dispatch] = useReducer(productSurfaceReducer, undefined, () =>
    // Lazy init keeps the reducer's contract module as the single state source.
    productSurfaceReducer(undefined, { type: "select-mode", modeID: "reader" })
  );
  const snapshot = usePdfSnapshot();
  const documentOpen = snapshot.status === "ready";

  const [fields, setFields] = useState<NativeField[]>([]);
  const [selectedFieldId, setSelectedFieldId] = useState<string | null>(null);
  const [history, setHistory] = useState(createOperationHistory);
  const [exporting, setExporting] = useState(false);
  const [exportReport, setExportReport] = useState<ExportReport | null>(null);
  const [exportError, setExportError] = useState<string | null>(null);
  const [isCommandHUDOpen, setIsCommandHUDOpen] = useState(false);

  useEffect(() => {
    if (!documentOpen) {
      setFields([]);
      setSelectedFieldId(null);
      setHistory(createOperationHistory());
      setExportReport(null);
      setExportError(null);
      return;
    }
    void pdfController.listNativeFields().then((f) => {
      setFields(f);
      if (f.length > 0) setSelectedFieldId(f[0].id);
    });
  }, [snapshot.status]);

  // Global ⌘K Shortcut Listener
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key === "k") {
        e.preventDefault();
        setIsCommandHUDOpen((prev) => !prev);
      }
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, []);

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

  const handleAutofillProfile = useCallback(() => {
    // Fill standard demo profile fields
    const sampleProfile: Record<string, string> = {
      name: "Jane Doe",
      email: "jane.doe@example.com",
      phone: "555-0199",
      address: "123 Market St, San Francisco, CA"
    };

    setFields((current) =>
      current.map((f) => {
        const lower = f.name.toLowerCase();
        for (const [k, v] of Object.entries(sampleProfile)) {
          if (lower.includes(k)) {
            handleConfirmEdit(f, v);
            return { ...f, value: v };
          }
        }
        return f;
      })
    );
  }, [handleConfirmEdit]);

  const handleRunOCR = useCallback(() => {
    dispatch({ type: "select-mode", modeID: "understand" });
  }, []);

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

  // Command Palette Items
  const commands: CommandItem[] = [
    {
      id: "autofill",
      title: "Autofill Document Profile",
      subtitle: "Apply verified local identity profile to matched fields",
      category: "autofill",
      shortcut: "⌥⌘A",
      icon: "⚡",
      action: handleAutofillProfile
    },
    {
      id: "ocr",
      title: "Run On-Device OCR Analysis",
      subtitle: "Detect text lines and form boxes using local vision models",
      category: "analysis",
      shortcut: "⇧⌘O",
      icon: "🔍",
      action: handleRunOCR
    },
    {
      id: "export",
      title: "Export Validated Copy",
      subtitle: "Write incremental AcroForm changes with structural validation",
      category: "export",
      shortcut: "⌘E",
      icon: "💾",
      action: handleExport
    },
    {
      id: "undo",
      title: "Undo Last Action",
      subtitle: "Revert latest field value or candidate edit non-destructively",
      category: "tools",
      shortcut: "⌘Z",
      icon: "↩",
      action: handleUndo
    }
  ];

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

        {documentOpen && (
          <PageThumbnailRail
            pageCount={snapshot.pageCount}
            currentPageIndex={snapshot.currentPage - 1}
            onSelectPage={(p) => pdfController.setPage(p + 1)}
          />
        )}

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
            <ContextualInspector
              fields={fields}
              selectedFieldId={selectedFieldId}
              onSelectField={setSelectedFieldId}
              onUpdateFieldValue={handleConfirmEdit}
              onRunOCR={handleRunOCR}
              onAutofillProfile={handleAutofillProfile}
            />
          )}
        </aside>
      </div>

      <AgentCommandHUD
        isOpen={isCommandHUDOpen}
        onClose={() => setIsCommandHUDOpen(false)}
        commands={commands}
      />
    </>
  );
}
