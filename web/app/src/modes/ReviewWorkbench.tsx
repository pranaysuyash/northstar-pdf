import type { ExportReport } from "../pdf/PdfController";
import type { HistoryOperation } from "../../../operation-history.mjs";

interface ReviewWorkbenchProps {
  pendingOps: HistoryOperation[];
  totalEntries: number;
  exporting: boolean;
  report: ExportReport | null;
  error: string | null;
  onExport(): void;
}

export function ReviewWorkbench({
  pendingOps,
  totalEntries,
  exporting,
  report,
  error,
  onExport
}: ReviewWorkbenchProps) {
  return (
    <>
      <div className="review-card">
        <h3>Operation log</h3>
        {totalEntries === 0 ? (
          <p>No confirmed operations yet. Every confirmed mutation appears here with lineage.</p>
        ) : (
          <ol className="small op-log">
            {pendingOps.map((op) => (
              <li key={op.sequence}>
                <span className="muted">#{op.sequence}</span> {op.kind} ·{" "}
                <code>{op.targetID}</code> → “{op.value || "∅"}”
              </li>
            ))}
          </ol>
        )}
        <p className="small muted">
          {totalEntries - pendingOps.length} lineage entr
          {totalEntries - pendingOps.length === 1 ? "y" : "ies"} (undo records) excluded from
          export input.
        </p>
      </div>

      <div className="review-card">
        <h3>Export + validate</h3>
        <p className="small muted">
          Export always produces a new copy; the source file is never modified. The output is
          reopened in an independent PDF.js validation lane before download.
        </p>
        <button type="button" className="primary" disabled={exporting} onClick={onExport}>
          {exporting ? "Validating…" : "Export new copy"}
        </button>
        {error && (
          <p className="small danger" role="alert">
            {error}
          </p>
        )}
        {report && (
          <ul className="small validation-report" role="status" aria-live="polite">
            {report.checks.map((check) => (
              <li key={check.id} data-status={check.status}>
                [{check.status}] {check.detail}
                {check.metrics && "outsidePixelRatio" in (check.metrics as Record<string, unknown>) && (
                  <span className="muted">
                    {" "}· changed/compared pixels: {String(check.metrics.changedPixelCount ?? "?")}/
                    {String(check.metrics.comparedPixelCount ?? "?")} · max channel delta:{" "}
                    {String(check.metrics.maximumChannelDelta ?? "?")}
                  </span>
                )}
              </li>
            ))}
            <li data-status={report.passed ? "passed" : "failed"}>
              {report.passed
                ? "All guardrails passed; the new copy has been downloaded."
                : "Validation failed; no download was offered."}
            </li>
          </ul>
        )}
      </div>
    </>
  );
}
