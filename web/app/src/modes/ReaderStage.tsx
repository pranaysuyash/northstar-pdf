import { useEffect, useRef, useState } from "react";
import { pdfController } from "../pdf/PdfController";
import type { PdfSnapshot } from "../pdf/PdfController";
import { CapabilityNotice } from "./ModePanels";

export function ReaderStage({ snapshot }: { snapshot: PdfSnapshot }) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [password, setPassword] = useState("");
  const passwordOpen = snapshot.status === "password";

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
              ? `Page ${snapshot.currentPage} of ${snapshot.pageCount} — nothing leaves this device.`
              : "Open a PDF to begin — nothing leaves this device."}
          </span>
          <CapabilityNotice state={snapshot.status === "loading" ? "loading" : "available"} />
        </section>
      </div>

      <div className="pdf-stage" id="viewerCanvasWrap">
        {snapshot.status === "ready" ? (
          <canvas ref={canvasRef} aria-label="PDF page rendering" />
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

      <div className={`password-card${passwordOpen ? " show" : ""}`} hidden={!passwordOpen} role="dialog" aria-modal="true" aria-labelledby="passwordTitle-react">
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
      </div>
    </>
  );
}
