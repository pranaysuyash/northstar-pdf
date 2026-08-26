import { useEffect, useRef, useState } from "react";
import { pdfController } from "../pdf/PdfController";
import type { MatchRect, PdfSnapshot, Rect } from "../pdf/PdfController";
import { CapabilityNotice } from "./ModePanels";

interface ReaderStageProps {
  snapshot: PdfSnapshot;
  regionRects: Rect[];
  onCanvasClick?(deviceX: number, deviceY: number): void;
}

export function ReaderStage({ snapshot, regionRects, onCanvasClick }: ReaderStageProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [password, setPassword] = useState("");
  const [matchRects, setMatchRects] = useState<MatchRect[]>([]);
  const [markers, setMarkers] = useState<MatchRect[]>([]);
  const passwordOpen = snapshot.status === "password";

  useEffect(() => {
    if (snapshot.status !== "ready" || !snapshot.renderedAt || !regionRects.length) {
      setMarkers([]);
      return;
    }
    let cancelled = false;
    void pdfController.getRegionMarkers(snapshot.currentPage, regionRects).then((rects) => {
      if (!cancelled) setMarkers(rects);
    });
    return () => {
      cancelled = true;
    };
  }, [snapshot.status, snapshot.renderedAt, snapshot.currentPage, regionRects]);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas || snapshot.status !== "ready") return;
    const abort = new AbortController();
    const cancelRender = pdfController.renderInto(canvas, abort.signal);
    return () => {
      abort.abort();
      cancelRender();
    };
  }, [
    snapshot.status,
    snapshot.currentPage,
    snapshot.zoomPercent,
    snapshot.fitMode,
    snapshot.rotation
  ]);

  useEffect(() => {
    if (snapshot.status !== "ready" || !snapshot.renderedAt) return;
    let cancelled = false;
    void pdfController.getMatchRects(snapshot.currentPage).then((rects) => {
      if (!cancelled) setMatchRects(rects);
    });
    return () => {
      cancelled = true;
    };
  }, [snapshot.status, snapshot.renderedAt, snapshot.currentPage, snapshot.matches, snapshot.searchQuery]);

  const firstMatchOnPage = snapshot.matches.findIndex((match) => match.page === snapshot.currentPage);

  return (
    <>
      <div className="mode-stage">
        <section
          id="mode-panel-reader"
          className="mode-panel mode-panel-reader"
          role="tabpanel"
          aria-labelledby="mode-tab-reader"
        >
          <span className="mode-context-line">
            {snapshot.status === "ready"
              ? `Page ${snapshot.currentPage} of ${snapshot.pageCount}. Nothing leaves this device.`
              : "Open a PDF to begin. Nothing leaves this device."}
          </span>
          <CapabilityNotice state={snapshot.status === "loading" ? "loading" : "available"} />
        </section>
      </div>

      <div className="pdf-stage" id="viewerCanvasWrap">
        {snapshot.status === "ready" ? (
          <div className="pdf-page-wrap">
            {/* react-doctor-disable-next-line react-doctor/click-events-have-key-events */}{/* Canvas coordinate picking has no keyboard analog; keyboard users select regions via the thumbnail rail and inspector field list. */}
            <canvas
              ref={canvasRef}
              aria-label="PDF page rendering"
              style={onCanvasClick ? { cursor: "crosshair" } : undefined}
              onClick={(event) => {
                if (!onCanvasClick) return;
                const bounds = event.currentTarget.getBoundingClientRect();
                onCanvasClick(event.clientX - bounds.left, event.clientY - bounds.top);
              }}
            />
            <div className="match-highlight-layer" aria-hidden="true">
              {markers.map((rect, i) => (
                <span
                  key={`marker-${i}`}
                  className="region-marker"
                  style={{
                    left: rect.left,
                    top: rect.top,
                    width: rect.width,
                    height: rect.height
                  }}
                />
              ))}
              {matchRects.map((rect, i) => (
                <span
                  key={i}
                  className={`match-highlight${
                    firstMatchOnPage + i === snapshot.activeMatchIndex ? " is-active" : ""
                  }`}
                  style={{
                    left: rect.left,
                    top: rect.top,
                    width: rect.width,
                    height: rect.height
                  }}
                />
              ))}
            </div>
          </div>
        ) : (
          <p className="pdf-stage-empty small muted">
            {snapshot.status === "failed"
              ? (snapshot.error ?? "The document could not be opened.")
              : snapshot.status === "password"
                ? "Password required to open this document."
                : "No document open. Choose a PDF above."}
          </p>
        )}
      </div>

      {/* Native <dialog> gives focus handling and Esc semantics for free;
          visibility stays CSS-driven via the `show` class. */}
      <dialog
        open
        className={`password-card${passwordOpen ? " show" : ""}`}
        hidden={!passwordOpen}
        aria-labelledby="passwordTitle-react"
        style={{ border: "none", padding: 0, background: "none" }}
      >
        <form
          id="passwordForm"
          className="password-panel"
          onSubmit={(event) => {
            event.preventDefault();
            if (!pdfController.submitPassword(password)) setPassword("");
          }}
        >
          <div className="list-title">Password required</div>
          <div className="small">Enter the PDF password to continue.</div>
          <label htmlFor="reactPasswordInput" className="small" style={{ display: "block", marginTop: 10 }}>
            PDF password
          </label>
          <input
            id="reactPasswordInput"
            type="password"
            autoComplete="current-password"
            style={{ width: 240, marginTop: 10 }}
            value={password}
            onChange={(event) => setPassword(event.target.value)}
          />
          <div className="control-row" style={{ justifyContent: "flex-end", marginTop: 10 }}>
            <button
              type="button"
              onClick={() => {
                pdfController.cancelPassword();
                setPassword("");
              }}
            >
              Cancel
            </button>
            <button type="submit">Open</button>
          </div>
        </form>
      </dialog>
    </>
  );
}
