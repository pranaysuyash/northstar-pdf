import type { ReactNode } from "react";
import type { CapabilityState, ProductModeID } from "../state/productSurface";
import { PDF_CAPABILITY_LANES } from "../../../pdf-capability-lanes.mjs";

/**
 * Every non-Reader surface renders from the capability vocabulary only. A
 * surface never pretends to succeed: unconnected work shows its true state
 * (partial / blocked / reader_only) with the evidence required next.
 */
interface ModePanelProps {
  mode: ProductModeID;
  title: string;
  body: ReactNode;
}

function PanelFrame({ mode, title, body }: ModePanelProps) {
  return (
    <section
      id={`mode-panel-${mode}`}
      className="mode-panel"
      role="tabpanel"
      aria-labelledby={`mode-tab-${mode}`}
      tabIndex={-1}
    >
      <header className="mode-panel-head">
        <span className="mode-panel-kicker">{title.split(".")[0]}</span>
        <h2 className="mode-panel-title">{title}</h2>
        <button type="button" className="mode-return-button" data-mode-return="reader">
          Back to document
        </button>
      </header>
      <div className="mode-panel-body">{body}</div>
    </section>
  );
}

export function UnderstandPanel({
  hasDocument,
  candidates = [],
  loading = false
}: {
  hasDocument: boolean;
  candidates?: import("../pdf/PdfController").GeometryCandidate[];
  loading?: boolean;
}) {
  return (
    <PanelFrame
      mode="understand"
      title="Understand — build a mental model before you edit."
      body={
        !hasDocument ? (
          <p className="understand-block">Open a PDF to map its structure and evidence.</p>
        ) : (
          <>
            <div className="understand-block">
              <h3>Source identity</h3>
              <p>
                The source file is read-only in this session; analysis never modifies it. Page
                structure is available from the Reader surface.
              </p>
            </div>
            <div className="understand-block">
              <h3>Evidence origins</h3>
              {loading && <p className="small muted">Reading page geometry…</p>}
              {!loading && candidates.length === 0 && (
                <p className="small muted">
                  No geometry-detected findings on this page. Findings appear here with
                  page-indexed coordinates and provenance before any confirmation.
                </p>
              )}
              {candidates.slice(0, 8).map((candidate) => (
                <div key={candidate.id} className="review-card" style={{ marginTop: 6 }}>
                  <strong>{candidate.displayName || candidate.labelText || "Unlabeled region"}</strong>{" "}
                  <span className="muted">
                    · {candidate.suggestedFieldType ?? "region"} · score{" "}
                    {candidate.score.toFixed(2)} · p{candidate.pageIndex + 1}
                  </span>
                  {candidate.evidence.slice(0, 2).map((line, i) => (
                    <p key={`${candidate.id}-evidence-${i}`} className="small muted" style={{ margin: "4px 0 0" }}>
                      {line}
                    </p>
                  ))}
                </div>
              ))}
            </div>
          </>
        )
      }
    />
  );
}

export function CompletePanel({ hasDocument }: { hasDocument: boolean }) {
  return (
    <PanelFrame
      mode="complete"
      title="Complete — finish the reviewed fields."
      body={
        <p className="understand-block">
          {!hasDocument
            ? "Open a PDF to inspect native fields and candidate regions."
            : "Native-field editing and the review queue connect through the typed adapter slice. Nothing is auto-applied: every confirmed mutation will enter the reversible operation history."}
        </p>
      }
    />
  );
}

export function OrganizePanel({ hasDocument }: { hasDocument: boolean }) {
  // Lane vocabulary comes from the canonical contract module; outcomes stay
  // "unknown" until a provider manifest negotiates real capability evidence.
  const lanes = PDF_CAPABILITY_LANES;
  return (
    <PanelFrame
      mode="organize"
      title="Organize — shape the document before you send it."
      body={
        <>
          <p className="understand-block">
            {!hasDocument
              ? "Page operations require an open document."
              : "This lane stays reader-only until the page provider exposes verified insert/delete/reorder/rotate/extract operations with reopen validation. Unsupported operations stay explicit rather than silently hidden."}
          </p>
          {hasDocument && (
            <div className="understand-block">
              <h3>Capability lanes</h3>
              <ul className="small lane-list">
                {lanes.map((lane) => (
                  <li key={lane}>
                    <code>{lane}</code>{" "}
                    <span className="muted">· outcome: unknown (no provider manifest in this entry point)</span>
                  </li>
                ))}
              </ul>
            </div>
          )}
        </>
      }
    />
  );
}

export function ReviewPanel({
  hasDocument,
  pageCount
}: {
  hasDocument: boolean;
  pageCount: number;
}) {
  return (
    <PanelFrame
      mode="review"
      title="Review — know exactly what will leave the session."
      body={
        !hasDocument ? (
          <p className="understand-block">Export guardrails activate once a document is open.</p>
        ) : (
          <>
            <div className="review-card">
              <h3>Operation log</h3>
              <p>No confirmed operations yet. Every confirmed mutation appears here with lineage.</p>
            </div>
            <div className="review-card">
              <h3>Session scope</h3>
              <p>
                {pageCount} page{pageCount === 1 ? "" : "s"} read locally. Export always creates a
                new copy and runs independent reopen validation; the source is never modified.
              </p>
            </div>
          </>
        )
      }
    />
  );
}

export function CapabilityNotice({ state }: { state: CapabilityState }) {
  if (state === "available") return null;
  return (
    <span className={`analysis-pill capability-${state}`}>
      {state === "loading" ? "Reading source…" : `Surface state: ${state.replace("_", " ")}`}
    </span>
  );
}
