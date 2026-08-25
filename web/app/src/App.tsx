import { useCallback, useReducer } from "react";
import {
  productSurfaceReducer,
  type CapabilityState
} from "./state/productSurface";
import { pdfController } from "./pdf/PdfController";
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

export function App() {
  const [surface, dispatch] = useReducer(productSurfaceReducer, undefined, () =>
    // Lazy init keeps the reducer's contract module as the single state source.
    productSurfaceReducer(undefined, { type: "select-mode", modeID: "reader" })
  );
  const snapshot = usePdfSnapshot();

  const handleDocumentOpened = useCallback(() => {
    dispatch({ type: "set-capability", modeID: "reader", capability: "loading" });
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
            <UnderstandPanel hasDocument={snapshot.status === "ready"} />
          )}
          {surface.activeMode === "complete" && (
            <CompletePanel hasDocument={snapshot.status === "ready"} />
          )}
          {surface.activeMode === "organize" && (
            <OrganizePanel hasDocument={snapshot.status === "ready"} />
          )}
          {surface.activeMode === "review" && (
            <ReviewPanel
              hasDocument={snapshot.status === "ready"}
              pageCount={snapshot.pageCount}
            />
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
