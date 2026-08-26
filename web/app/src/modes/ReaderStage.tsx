import { useCallback, useEffect, useRef, useState } from "react";
import { pdfController } from "../pdf/PdfController";
import type { MatchRect, PdfSnapshot, Rect } from "../pdf/PdfController";
import { CapabilityNotice } from "./ModePanels";

interface ReaderStageProps {
  snapshot: PdfSnapshot;
  regionRects: Rect[];
  onCanvasClick?(deviceX: number, deviceY: number): void;
}

interface PageOverlay {
  markers: MatchRect[];
  highlights: MatchRect[];
  activeHighlight: number;
}

export function ReaderStage({ snapshot, regionRects, onCanvasClick }: ReaderStageProps) {
  const passwordOpen = snapshot.status === "password";

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
          snapshot.viewMode === "continuous" && snapshot.pageSizes.length > 0 ? (
            <ContinuousScroll
              snapshot={snapshot}
              regionRects={regionRects}
              onCanvasClick={onCanvasClick}
            />
          ) : (
            <SinglePageView snapshot={snapshot} regionRects={regionRects} onCanvasClick={onCanvasClick} />
          )
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

      <PasswordDialog open={passwordOpen} />
    </>
  );
}

function SinglePageView({
  snapshot,
  regionRects,
  onCanvasClick
}: ReaderStageProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [matchRects, setMatchRects] = useState<MatchRect[]>([]);
  const [markers, setMarkers] = useState<MatchRect[]>([]);

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
    <div className="pdf-page-wrap">
      {/* Canvas coordinate picking has no keyboard analog; keyboard users select regions via the thumbnail rail and inspector field list. */}
      <canvas
        ref={canvasRef}
        aria-label={`PDF page ${snapshot.currentPage} rendering`}
        style={onCanvasClick ? { cursor: "crosshair" } : undefined}
        onClick={(event) => {
          if (!onCanvasClick) return;
          const bounds = event.currentTarget.getBoundingClientRect();
          onCanvasClick(event.clientX - bounds.left, event.clientY - bounds.top);
        }}
      />
      <div className="match-highlight-layer" aria-hidden="true">
        {markers.map((rect, i) => (
          <span key={`marker-${i}`} className="region-marker" style={rectStyle(rect)} />
        ))}
        {matchRects.map((rect, i) => (
          <span
            key={i}
            className={`match-highlight${firstMatchOnPage + i === snapshot.activeMatchIndex ? " is-active" : ""}`}
            style={rectStyle(rect)}
          />
        ))}
      </div>
    </div>
  );
}

function ContinuousScroll({
  snapshot,
  regionRects,
  onCanvasClick
}: ReaderStageProps) {
  const scrollRef = useRef<HTMLDivElement>(null);
  const suppressScrollSync = useRef(false);
  const lastSyncedExternalPage = useRef(snapshot.currentPage);
  const [visiblePages, setVisiblePages] = useState<Set<number>>(() => new Set([1]));

  // External page changes (toolbar, rail, search) scroll the stack.
  useEffect(() => {
    if (snapshot.currentPage === lastSyncedExternalPage.current) return;
    lastSyncedExternalPage.current = snapshot.currentPage;
    const wrapper = scrollRef.current?.querySelector<HTMLElement>(
      `[data-page-number="${snapshot.currentPage}"]`
    );
    if (wrapper) {
      suppressScrollSync.current = true;
      wrapper.scrollIntoView({ block: "start" });
      window.setTimeout(() => {
        suppressScrollSync.current = false;
      }, 120);
    }
  }, [snapshot.currentPage]);

  // Track which page wrappers intersect the viewport.
  useEffect(() => {
    const root = scrollRef.current;
    if (!root) return;
    const observer = new IntersectionObserver(
      (entries) => {
        setVisiblePages((current) => {
          const next = new Set(current);
          for (const entry of entries) {
            const pageNumber = Number((entry.target as HTMLElement).dataset.pageNumber);
            if (!pageNumber) continue;
            if (entry.isIntersecting) next.add(pageNumber);
            else next.delete(pageNumber);
          }
          return next;
        });
      },
      { root, rootMargin: "300px 0px", threshold: 0.01 }
    );
    for (const wrapper of Array.from(root.querySelectorAll("[data-page-number]"))) {
      observer.observe(wrapper);
    }
    return () => observer.disconnect();
  }, [snapshot.pageSizes.length, snapshot.viewMode]);

  // Scroll position drives the active page for the rest of the shell.
  const handleScroll = useCallback(() => {
    if (suppressScrollSync.current) return;
    const root = scrollRef.current;
    if (!root) return;
    const rootCenter = root.scrollTop + root.clientHeight / 2;
    let best = 1;
    for (const wrapper of Array.from(root.querySelectorAll<HTMLElement>("[data-page-number]"))) {
      const top = wrapper.offsetTop - root.offsetTop;
      if (top <= rootCenter) best = Number(wrapper.dataset.pageNumber) || best;
      else break;
    }
    if (best !== snapshot.currentPage) {
      lastSyncedExternalPage.current = best;
      pdfController.setPage(best);
    }
  }, [snapshot.currentPage]);

  return (
    <div className="pdf-continuous" ref={scrollRef} onScroll={handleScroll}>
      {snapshot.pageSizes.map((size, index) => (
        <div
          key={index}
          data-page-number={index + 1}
          className="pdf-page-wrap pdf-page-placeholder"
          style={{ aspectRatio: `${size.width} / ${size.height}` }}
        >
          {visiblePages.has(index + 1) ? (
            <ContinuousPage
              key={`${index + 1}-${snapshot.zoomPercent}-${snapshot.fitMode}-${snapshot.rotation}-${snapshot.renderedAt}`}
              pageNumber={index + 1}
              label={`PDF page ${index + 1} rendering`}
              regionRects={regionRects}
              matches={snapshot.matches.filter((match) => match.page === index + 1)}
              activeGlobalIndex={
                snapshot.matches.findIndex((match) => match.page === index + 1)
              }
              activeMatchIndex={snapshot.activeMatchIndex}
              renderedAt={snapshot.renderedAt}
              onCanvasClick={onCanvasClick}
            />
          ) : null}
        </div>
      ))}
    </div>
  );
}

interface ContinuousPageProps {
  pageNumber: number;
  label: string;
  regionRects: Rect[];
  matches: PdfSnapshot["matches"];
  activeGlobalIndex: number;
  activeMatchIndex: number;
  renderedAt: number;
  onCanvasClick?(deviceX: number, deviceY: number): void;
}

function ContinuousPage({
  pageNumber,
  label,
  regionRects,
  matches,
  activeGlobalIndex,
  activeMatchIndex,
  renderedAt,
  onCanvasClick
}: ContinuousPageProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [overlay, setOverlay] = useState<PageOverlay>({ markers: [], highlights: [], activeHighlight: -1 });

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const abort = new AbortController();
    const cancelRender = pdfController.renderPageInto(canvas, pageNumber, abort.signal);
    return () => {
      abort.abort();
      cancelRender();
    };
  }, [pageNumber, renderedAt]);

  useEffect(() => {
    let cancelled = false;
    void Promise.all([
      pdfController.getMatchRects(pageNumber),
      regionRects.length ? pdfController.getRegionMarkers(pageNumber, regionRects) : Promise.resolve([])
    ]).then(([highlights, markers]) => {
      if (cancelled) return;
      setOverlay({
        highlights,
        markers,
        activeHighlight: matches.findIndex(
          (_, i) => activeGlobalIndex + i === activeMatchIndex
        )
      });
    });
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [pageNumber, regionRects, renderedAt, matches, activeMatchIndex]);

  return (
    <>
      <canvas
        ref={canvasRef}
        aria-label={label}
        style={onCanvasClick ? { cursor: "crosshair" } : undefined}
        onClick={(event) => {
          if (!onCanvasClick) return;
          const bounds = event.currentTarget.getBoundingClientRect();
          onCanvasClick(event.clientX - bounds.left, event.clientY - bounds.top);
        }}
      />
      <div className="match-highlight-layer" aria-hidden="true">
        {overlay.markers.map((rect, i) => (
          <span key={`marker-${i}`} className="region-marker" style={rectStyle(rect)} />
        ))}
        {overlay.highlights.map((rect, i) => (
          <span
            key={i}
            className={`match-highlight${i === overlay.activeHighlight ? " is-active" : ""}`}
            style={rectStyle(rect)}
          />
        ))}
      </div>
    </>
  );
}

function PasswordDialog({ open }: { open: boolean }) {
  const [password, setPassword] = useState("");
  return (
    <dialog
      open
      className={`password-card${open ? " show" : ""}`}
      hidden={!open}
      aria-labelledby="passwordTitle-react"
      style={{ border: "none", padding: 0, background: "none" }}
    >
      <form
        id="passwordForm"
        className="password-panel"
        onSubmit={(event) => {
          event.preventDefault();
          if (pdfController.submitPassword(password)) setPassword("");
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
  );
}

function rectStyle(rect: MatchRect): React.CSSProperties {
  return { left: rect.left, top: rect.top, width: rect.width, height: rect.height };
}
