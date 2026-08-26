import { lazy, Suspense, useCallback, useEffect, useMemo, useReducer, useState } from "react";
import {
  productSurfaceReducer,
  type CapabilityState
} from "./state/productSurface";
import {
  createEditorSessionState,
  editorSessionReducer,
  type AutofillUpdate
} from "./state/editorSession";
import { undoLastOperation, type HistoryOperation } from "../../operation-history.mjs";
import { pdfController } from "./pdf/PdfController";
import type {
  ExportReport,
  GeometryCandidate,
  NativeField,
  PdfEditOperation,
  Rect
} from "./pdf/PdfController";
import { usePdfSnapshot } from "./pdf/usePdfSnapshot";
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
import type { CommandItem } from "./shell/AgentCommandHUD";
import { ContextualInspector } from "./shell/ContextualInspector";
import { PageThumbnailRail } from "./shell/PageThumbnailRail";

const AgentCommandHUD = lazy(() =>
  import("./shell/AgentCommandHUD").then((m) => ({ default: m.AgentCommandHUD }))
);

const SAMPLE_PROFILE: Record<string, string> = {
  name: "Jane Doe",
  email: "jane.doe@example.com",
  phone: "555-0199",
  address: "123 Market St, San Francisco, CA"
};

export function App() {
  const [surface, dispatch] = useReducer(productSurfaceReducer, undefined, () =>
    // Lazy init keeps the reducer's contract module as the single state source.
    productSurfaceReducer(undefined, { type: "select-mode", modeID: "reader" })
  );
  const [session, dispatchSession] = useReducer(
    editorSessionReducer,
    undefined,
    createEditorSessionState
  );
  const snapshot = usePdfSnapshot();
  const documentOpen = snapshot.status === "ready";
  const { history } = session;

  const [isCommandHUDOpen, setIsCommandHUDOpen] = useState(false);
  const [regionRects, setRegionRects] = useState<Rect[]>([]);
  const [candidates, setCandidates] = useState<GeometryCandidate[]>([]);
  const [candidatesLoading, setCandidatesLoading] = useState(false);
  const [dismissedIDs, setDismissedIDs] = useState<ReadonlySet<string>>(new Set());
  const [pendingPlacement, setPendingPlacement] = useState<{ pageIndex: number; rect: Rect } | null>(null);

  useEffect(() => {
    if (!documentOpen) {
      dispatchSession({ type: "reset-session" });
      setRegionRects([]);
      return;
    }
    void pdfController.listNativeFields().then((f) => {
      dispatchSession({ type: "fields-loaded", fields: f });
    });
  }, [documentOpen]);

  // Geometry-detected candidate regions for the currently rendered page.
  const currentPage = snapshot.currentPage;
  const analysisModeActive = surface.activeMode === "understand" || surface.activeMode === "complete";
  useEffect(() => {
    if (!documentOpen || currentPage < 1) {
      setRegionRects([]);
      setCandidates([]);
      return;
    }
    let cancelled = false;
    void pdfController.listCandidates(currentPage).then((found) => {
      if (cancelled) return;
      setCandidates(found);
      setRegionRects(found.map((candidate) => candidate.bounds));
    });
    return () => {
      cancelled = true;
    };
  }, [documentOpen, currentPage]);

  // Load candidate evidence only where a review surface actually needs it.
  useEffect(() => {
    if (!analysisModeActive || !documentOpen || currentPage < 1) return;
    let token = true;
    setCandidatesLoading(true);
    void pdfController
      .listCandidates(currentPage)
      .then((found) => {
        if (token) setCandidates(found);
      })
      .catch(() => {
        if (token) setCandidates([]);
      })
      .finally(() => {
        if (token) setCandidatesLoading(false);
      });
    return () => {
      token = false;
    };
  }, [analysisModeActive, documentOpen, currentPage]);

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
    dispatchSession({
      type: "edit-field",
      fieldID: field.id,
      pageIndex: field.pageIndex,
      value,
      previousValue: field.value
    });
  }, []);

  const handleUndo = useCallback(() => {
    const outcome = undoLastOperation(history);
    if (!outcome) return;
    dispatchSession({ type: "undo-applied", outcome });
  }, [history]);

  const handleExport = useCallback(() => {
    if (session.exporting) return;
    const operations: PdfEditOperation[] = [];
    for (const op of history.operations) {
      if (!op.undoneBy && !op.undoes && (op.kind === "nativeFieldValue" || op.kind === "overlayText")) {
        operations.push({
          id: `op-${op.sequence}`,
          kind: op.kind,
          targetID: op.targetID,
          pageIndex: op.pageIndex,
          value: op.value,
          previousValue: op.previousValue
        });
      }
    }
    dispatchSession({ type: "export-started" });
    void pdfController
      .exportCopy(operations)
      .then((report: ExportReport) => {
        dispatchSession({ type: "export-succeeded", report });
        if (report.passed) {
          dispatch({ type: "set-capability", modeID: "review", capability: "validated" });
        }
      })
      .catch((error: unknown) => {
        dispatchSession({
          type: "export-failed",
          message: error instanceof Error ? error.message : String(error)
        });
      });
  }, [dispatch, session.exporting, history]);

  const handleAutofillProfile = useCallback(() => {
    const updates: AutofillUpdate[] = [];
    for (const field of session.fields) {
      const lower = field.name.toLowerCase();
      for (const [key, value] of Object.entries(SAMPLE_PROFILE)) {
        if (lower.includes(key) && field.value !== value) {
          updates.push({
            targetID: field.id,
            pageIndex: field.pageIndex,
            previousValue: field.value,
            value
          });
          break;
        }
      }
    }
    dispatchSession({ type: "autofill-applied", updates });
  }, [session.fields]);

  const handleRunOCR = useCallback(() => {
    dispatch({ type: "select-mode", modeID: "understand" });
  }, []);

  const handleSelectPage = useCallback((p: number) => {
    pdfController.setPage(p + 1);
  }, []);

  const handleCanvasClick = useCallback(
    (deviceX: number, deviceY: number) => {
      void pdfController
        .proposePlacement(snapshot.currentPage, deviceX, deviceY)
        .then((placement) => {
          if (!placement) return;
          setPendingPlacement(placement);
          dispatch({ type: "select-mode", modeID: "complete" });
        });
    },
    [snapshot.currentPage]
  );

  const handleConfirmPlacement = useCallback(
    (value: string) => {
      setPendingPlacement((current) => {
        if (!current) return null;
        dispatchSession({
          type: "placement-confirmed",
          targetID: `overlay-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
          pageIndex: current.pageIndex,
          value,
          rect: current.rect
        });
        return null;
      });
    },
    []
  );

  const handleDismissCandidate = useCallback((id: string) => {
    setDismissedIDs((current) => new Set([...current, id]));
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
  const pendingFieldOps: HistoryOperation[] = [];
  for (const op of history.operations) {
    if (!op.undoneBy && !op.undoes && op.kind === "nativeFieldValue") {
      pendingFieldOps.push(op);
    }
  }

  // Authorized regions visible on the current page: detector candidates, the
  // pending placement, and every confirmed overlay awaiting export.
  const allRegionRects: Rect[] = useMemo(() => {
    const rects: Rect[] = [...regionRects];
    if (pendingPlacement && pendingPlacement.pageIndex === currentPage - 1) {
      rects.push(pendingPlacement.rect);
    }
    for (const op of history.operations) {
      if (!op.undoneBy && !op.undoes && op.kind === "overlayText" && op.coordinate?.pageIndex === currentPage - 1) {
        rects.push(op.coordinate.rect);
      }
    }
    return rects;
  }, [regionRects, pendingPlacement, history.operations, currentPage]);

  // Command Palette Items (memoized to avoid full tree re-render on ticks)
  const commands: CommandItem[] = useMemo(
    () => [
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
    ],
    [handleAutofillProfile, handleRunOCR, handleExport, handleUndo]
  );

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

        {documentOpen ? (
          <PageThumbnailRail
            pageCount={snapshot.pageCount}
            currentPageIndex={snapshot.currentPage - 1}
            onSelectPage={handleSelectPage}
          />
        ) : null}

        <main id="viewerMain" className="panel" tabIndex={-1} aria-label="PDF document viewer">
          <ReaderStage
            snapshot={snapshot}
            regionRects={allRegionRects}
            onCanvasClick={handleCanvasClick}
          />
        </main>

        <aside className="panel" aria-label="Session detail">
          {surface.activeMode === "understand" && (
            <UnderstandPanel
              hasDocument={documentOpen}
              candidates={candidates.filter((candidate) => !dismissedIDs.has(candidate.id))}
              loading={candidatesLoading}
            />
          )}
          {surface.activeMode === "complete" && (
            <>
              <CompletePanel hasDocument={documentOpen} />
              <CompleteWorkbench
                fields={session.fields}
                onConfirmEdit={handleConfirmEdit}
                canUndo={history.operations.some((op) => !op.undoneBy && !op.undoes)}
                onUndo={handleUndo}
                candidates={candidates.filter((candidate) => !dismissedIDs.has(candidate.id))}
                candidatesLoading={candidatesLoading}
                dismissedIDs={dismissedIDs}
                onDismissCandidate={handleDismissCandidate}
                pendingPlacement={pendingPlacement}
                onConfirmPlacement={handleConfirmPlacement}
                onCancelPlacement={() => setPendingPlacement(null)}
                onProposePlacement={setPendingPlacement}
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
                pendingOps={pendingFieldOps}
                totalEntries={history.operations.length}
                exporting={session.exporting}
                report={session.exportReport}
                error={session.exportError}
                onExport={handleExport}
              />
            </>
          )}
          {surface.activeMode === "reader" && (
            <ContextualInspector
              fields={session.fields}
              selectedFieldId={session.selectedFieldId}
              onSelectField={(fieldID) => dispatchSession({ type: "select-field", fieldID })}
              onUpdateFieldValue={handleConfirmEdit}
              onRunOCR={handleRunOCR}
              onAutofillProfile={handleAutofillProfile}
            />
          )}
        </aside>
      </div>

      {isCommandHUDOpen ? (
        <Suspense fallback={null}>
          <AgentCommandHUD
            isOpen={isCommandHUDOpen}
            onClose={() => setIsCommandHUDOpen(false)}
            commands={commands}
          />
        </Suspense>
      ) : null}
    </>
  );
}
