/**
 * useEditorState — encapsulates all editor state, effects, and derived values.
 * Extracted from App to keep App under the react-doctor 300-line limit.
 */
import { useCallback, useEffect, useMemo, useReducer, useRef, useState } from "react";
import {
  productSurfaceReducer,
  type CapabilityState
} from "./productSurface";
import {
  createEditorSessionState,
  editorSessionReducer,
  type AutofillUpdate
} from "./editorSession";
import { undoLastOperation } from "../../../operation-history.mjs";
import { pdfController } from "../pdf/PdfController";
import type {
  ExportReport,
  GeometryCandidate,
  NativeField,
  PdfEditOperation,
  Rect
} from "../pdf/PdfController";
import { usePdfSnapshot } from "../pdf/usePdfSnapshot";
import type { CommandItem } from "../shell/AgentCommandHUD";

const SAMPLE_PROFILE: Record<string, string> = {
  name: "Jane Doe",
  email: "jane.doe@example.com",
  phone: "555-0199",
  address: "123 Market St, San Francisco, CA"
};

export function useEditorState() {
  const [surface, dispatch] = useReducer(productSurfaceReducer, undefined, () =>
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
  // Ref synced after every commit so handlers can read the latest placement
  // without a stale closure and without calling dispatchSession inside an updater.
  const pendingPlacementRef = useRef(pendingPlacement);
  useEffect(() => {
    pendingPlacementRef.current = pendingPlacement;
  });

  // Load fields when a document opens; reset when it closes.
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
  const analysisModeActive =
    surface.activeMode === "understand" || surface.activeMode === "complete";
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
      setRegionRects(found.map((c) => c.bounds));
    });
    return () => { cancelled = true; };
  }, [documentOpen, currentPage]);

  // Load candidate evidence only where a review surface actually needs it.
  useEffect(() => {
    if (!analysisModeActive || !documentOpen || currentPage < 1) return;
    let token = true;
    setCandidatesLoading(true);
    void pdfController
      .listCandidates(currentPage)
      .then((found) => { if (token) setCandidates(found); })
      .catch(() => { if (token) setCandidates([]); })
      .finally(() => { if (token) setCandidatesLoading(false); });
    return () => { token = false; };
  }, [analysisModeActive, documentOpen, currentPage]);

  // Global ⌘K shortcut.
  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key === "k") {
        e.preventDefault();
        setIsCommandHUDOpen((prev) => !prev);
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, []);

  // ── Handlers ──────────────────────────────────────────────────────────────

  const handleDocumentOpened = useCallback(() => {
    dispatch({ type: "set-capability", modeID: "reader", capability: "loading" });
  }, []);

  const handleConfirmEdit = useCallback((field: NativeField, value: string) => {
    // Operations are bound to the inspected source digest and the page's
    // effective crop-space rotation at creation time — the mutation gate
    // proves that binding at export.
    void (async () => {
      const rotationDegrees = await pdfController.getEffectiveRotation(field.pageIndex + 1);
      dispatchSession({
        type: "edit-field",
        fieldID: field.id,
        pageIndex: field.pageIndex,
        value,
        previousValue: field.value,
        sourceDigest: pdfController.sourceDigest,
        rect: field.rect,
        rotationDegrees
      });
    })();
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
          previousValue: op.previousValue,
          sourceDigest: op.sourceDigest as string,
          bounds: op.bounds as Rect,
          coordinate: op.coordinate as PdfEditOperation["coordinate"]
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
    void (async () => {
      const updates: AutofillUpdate[] = [];
      for (const field of session.fields) {
        const lower = field.name.toLowerCase();
        for (const [key, value] of Object.entries(SAMPLE_PROFILE)) {
          if (lower.includes(key) && field.value !== value) {
            updates.push({
              targetID: field.id,
              pageIndex: field.pageIndex,
              previousValue: field.value,
              value,
              sourceDigest: pdfController.sourceDigest,
              rect: field.rect,
              rotationDegrees: await pdfController.getEffectiveRotation(field.pageIndex + 1)
            });
            break;
          }
        }
      }
      dispatchSession({ type: "autofill-applied", updates });
    })();
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
      // Read from ref (always current, no stale closure), clear state, then
      // dispatch the side effect outside the state updater — pure updaters only.
      const current = pendingPlacementRef.current;
      if (!current) return;
      setPendingPlacement(null);
      // Overlay operations are bound to digest + effective rotation like
      // field edits, so the mutation gate can verify them at export.
      void (async () => {
        const rotationDegrees = await pdfController.getEffectiveRotation(current.pageIndex + 1);
        dispatchSession({
          type: "placement-confirmed",
          targetID: `overlay-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
          pageIndex: current.pageIndex,
          value,
          rect: current.rect,
          sourceDigest: pdfController.sourceDigest,
          rotationDegrees
        });
      })();
    },
    []
  );

  const handleDismissCandidate = useCallback((id: string) => {
    setDismissedIDs((current) => new Set([...current, id]));
  }, []);

  const handleSelectField = useCallback(
    (fieldID: string) => dispatchSession({ type: "select-field", fieldID }),
    []
  );

  // ── Derived values ────────────────────────────────────────────────────────

  const readerCapability: CapabilityState =
    snapshot.status === "ready"
      ? "available"
      : snapshot.status === "loading" || snapshot.status === "password"
        ? "loading"
        : snapshot.status === "failed"
          ? "failed"
          : surface.capabilities.reader;

  const capabilities = { ...surface.capabilities, reader: readerCapability };

  const pendingFieldOps = useMemo(
    () => history.operations.filter((op) => !op.undoneBy && !op.undoes && op.kind === "nativeFieldValue"),
    [history.operations]
  );

  const canUndo = useMemo(
    () => history.operations.some((op) => !op.undoneBy && !op.undoes),
    [history.operations]
  );

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

  return {
    // Surface
    surface,
    dispatch,
    capabilities,
    // Session
    session,
    history,
    pendingFieldOps,
    canUndo,
    // Snapshot
    snapshot,
    documentOpen,
    // UI state
    isCommandHUDOpen,
    setIsCommandHUDOpen,
    candidates,
    candidatesLoading,
    dismissedIDs,
    pendingPlacement,
    setPendingPlacement,
    allRegionRects,
    commands,
    // Handlers
    handleDocumentOpened,
    handleConfirmEdit,
    handleUndo,
    handleExport,
    handleAutofillProfile,
    handleRunOCR,
    handleSelectPage,
    handleCanvasClick,
    handleConfirmPlacement,
    handleDismissCandidate,
    handleSelectField
  };
}
