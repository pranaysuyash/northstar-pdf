import { memo } from "react";
import type { NativeField, GeometryCandidate, Rect } from "../pdf/PdfController";
import type { HistoryOperation } from "../../../operation-history.mjs";
import type { EditorSessionState } from "../state/editorSession";
import {
  CompletePanel,
  OrganizePanel,
  ReviewPanel,
  UnderstandPanel
} from "./ModePanels";
import { CompleteWorkbench } from "./CompleteWorkbench";
import { ReviewWorkbench } from "./ReviewWorkbench";
import { ContextualInspector } from "../shell/ContextualInspector";

interface SessionSidePanelProps {
  activeMode: string;
  hasDocument: boolean;
  pageCount: number;
  fields: NativeField[];
  selectedFieldId: string | null;
  candidates: GeometryCandidate[];
  candidatesLoading: boolean;
  dismissedIDs: ReadonlySet<string>;
  pendingPlacement: { pageIndex: number; rect: Rect } | null;
  pendingFieldOps: HistoryOperation[];
  historyLength: number;
  canUndo: boolean;
  exporting: boolean;
  exportReport: EditorSessionState["exportReport"];
  exportError: EditorSessionState["exportError"];
  onConfirmEdit: (field: NativeField, value: string) => void;
  onUndo: () => void;
  onExport: () => void;
  onDismissCandidate: (id: string) => void;
  onConfirmPlacement: (value: string) => void;
  onCancelPlacement: () => void;
  onProposePlacement: (p: { pageIndex: number; rect: Rect } | null) => void;
  onSelectField: (fieldID: string) => void;
  onRunOCR: () => void;
  onAutofillProfile: () => void;
}

export const SessionSidePanel = memo(function SessionSidePanel({
  activeMode,
  hasDocument,
  pageCount,
  fields,
  selectedFieldId,
  candidates,
  candidatesLoading,
  dismissedIDs,
  pendingPlacement,
  pendingFieldOps,
  historyLength,
  canUndo,
  exporting,
  exportReport,
  exportError,
  onConfirmEdit,
  onUndo,
  onExport,
  onDismissCandidate,
  onConfirmPlacement,
  onCancelPlacement,
  onProposePlacement,
  onSelectField,
  onRunOCR,
  onAutofillProfile
}: SessionSidePanelProps) {
  const visibleCandidates = candidates.filter((c) => !dismissedIDs.has(c.id));

  return (
    <aside className="panel" aria-label="Session detail">
      {activeMode === "understand" && (
        <UnderstandPanel
          hasDocument={hasDocument}
          candidates={visibleCandidates}
          loading={candidatesLoading}
        />
      )}
      {activeMode === "complete" && (
        <>
          <CompletePanel hasDocument={hasDocument} />
          <CompleteWorkbench
            fields={fields}
            onConfirmEdit={onConfirmEdit}
            canUndo={canUndo}
            onUndo={onUndo}
            candidates={visibleCandidates}
            candidatesLoading={candidatesLoading}
            dismissedIDs={dismissedIDs}
            onDismissCandidate={onDismissCandidate}
            pendingPlacement={pendingPlacement}
            onConfirmPlacement={onConfirmPlacement}
            onCancelPlacement={onCancelPlacement}
            onProposePlacement={onProposePlacement}
          />
        </>
      )}
      {activeMode === "organize" && (
        <OrganizePanel hasDocument={hasDocument} />
      )}
      {activeMode === "review" && (
        <>
          <ReviewPanel hasDocument={hasDocument} pageCount={pageCount} />
          <ReviewWorkbench
            pendingOps={pendingFieldOps}
            totalEntries={historyLength}
            exporting={exporting}
            report={exportReport}
            error={exportError}
            onExport={onExport}
          />
        </>
      )}
      {activeMode === "reader" && (
        <ContextualInspector
          fields={fields}
          selectedFieldId={selectedFieldId}
          onSelectField={onSelectField}
          onUpdateFieldValue={onConfirmEdit}
          onRunOCR={onRunOCR}
          onAutofillProfile={onAutofillProfile}
        />
      )}
    </aside>
  );
});
