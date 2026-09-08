import { lazy, Suspense } from "react";
import { useEditorState } from "./state/useEditorState";
import { Toolbar } from "./shell/Toolbar";
import { ModeRail } from "./shell/ModeRail";
import { ReaderStage } from "./modes/ReaderStage";
import { SessionSidePanel } from "./modes/SessionSidePanel";
import { PageThumbnailRail } from "./shell/PageThumbnailRail";

const AgentCommandHUD = lazy(() =>
  import("./shell/AgentCommandHUD").then((m) => ({ default: m.AgentCommandHUD }))
);

export function App() {
  const {
    surface,
    dispatch,
    capabilities,
    session,
    history,
    pendingFieldOps,
    canUndo,
    snapshot,
    documentOpen,
    isCommandHUDOpen,
    setIsCommandHUDOpen,
    candidates,
    candidatesLoading,
    dismissedIDs,
    pendingPlacement,
    setPendingPlacement,
    allRegionRects,
    commands,
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
  } = useEditorState();

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

        <SessionSidePanel
          activeMode={surface.activeMode}
          hasDocument={documentOpen}
          pageCount={snapshot.pageCount}
          fields={session.fields}
          selectedFieldId={session.selectedFieldId}
          candidates={candidates}
          candidatesLoading={candidatesLoading}
          dismissedIDs={dismissedIDs}
          pendingPlacement={pendingPlacement}
          pendingFieldOps={pendingFieldOps}
          historyLength={history.operations.length}
          canUndo={canUndo}
          exporting={session.exporting}
          exportReport={session.exportReport}
          exportError={session.exportError}
          onConfirmEdit={handleConfirmEdit}
          onUndo={handleUndo}
          onExport={handleExport}
          onDismissCandidate={handleDismissCandidate}
          onConfirmPlacement={handleConfirmPlacement}
          onCancelPlacement={() => setPendingPlacement(null)}
          onProposePlacement={setPendingPlacement}
          onSelectField={handleSelectField}
          onRunOCR={handleRunOCR}
          onAutofillProfile={handleAutofillProfile}
        />
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
