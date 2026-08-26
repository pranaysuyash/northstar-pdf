import { useRef, useState } from "react";
import { pdfController, type FitMode } from "../pdf/PdfController";
import type { PdfSnapshot } from "../pdf/PdfController";
import {
  SCRATCH_PAGE_SIZES,
  createBlankPdfBytes,
  createPdfFromImageFiles,
  resolvePageSize
} from "../pdf/createDocument";

interface ToolbarProps {
  snapshot: PdfSnapshot;
  onDocumentOpened: () => void;
}

export function Toolbar({ snapshot, onDocumentOpened }: ToolbarProps) {
  const fileInput = useRef<HTMLInputElement>(null);
  const pageInput = useRef<HTMLInputElement>(null);
  const searchInput = useRef<HTMLInputElement>(null);
  const pageSizeSelect = useRef<HTMLSelectElement>(null);
  const [creating, setCreating] = useState(false);
  const [createError, setCreateError] = useState<string | null>(null);

  const handleFile = async (file: File | undefined) => {
    if (!file) return;
    await pdfController.open(await file.arrayBuffer());
    onDocumentOpened();
  };

  const handleCreateBlank = async () => {
    if (creating) return;
    setCreating(true);
    setCreateError(null);
    try {
      const pageSize = resolvePageSize(pageSizeSelect.current?.value);
      const bytes = await createBlankPdfBytes(pageSize);
      await pdfController.open(bytes.buffer as ArrayBuffer);
      onDocumentOpened();
    } catch (error: unknown) {
      setCreateError(error instanceof Error ? error.message : String(error));
    } finally {
      setCreating(false);
    }
  };

  const handleCreateFromImages = async (files: File[]) => {
    if (creating || files.length === 0) return;
    setCreating(true);
    setCreateError(null);
    try {
      const bytes = await createPdfFromImageFiles(files);
      await pdfController.open(bytes.buffer as ArrayBuffer);
      onDocumentOpened();
    } catch (error: unknown) {
      setCreateError(error instanceof Error ? error.message : String(error));
    } finally {
      setCreating(false);
    }
  };

  return (
    <div className="toolbar">
      <div className="toolbar-title" aria-label="PDF Editor">
        <strong>PDF Editor</strong>
        <span>Local document workspace</span>
      </div>

      <div className="control-row">
        <label htmlFor="fileInput">PDF</label>
        <input
          id="fileInput"
          ref={fileInput}
          type="file"
          accept=".pdf,application/pdf"
          onChange={(event) => {
            void handleFile(event.target.files?.[0]);
            event.target.value = "";
          }}
        />
      </div>

      <div className="control-row">
        <label htmlFor="newPageSize">New</label>
        <select id="newPageSize" ref={pageSizeSelect} defaultValue="Letter">
          {SCRATCH_PAGE_SIZES.map((size) => (
            <option key={size.id} value={size.id}>
              {size.id}
            </option>
          ))}
        </select>
        <button
          type="button"
          onClick={() => void handleCreateBlank()}
          disabled={creating}
          aria-label="Create a new blank PDF in the selected page size"
        >
          Blank PDF
        </button>
        <input
          id="newImagesInput"
          type="file"
          accept="image/png,image/jpeg"
          multiple
          aria-label="Create a new PDF with one page per selected image"
          onChange={(event) => {
            void handleCreateFromImages(Array.from(event.target.files ?? []));
            event.target.value = "";
          }}
        />
      </div>

      <div className="control-row">
        <label htmlFor="fitMode">Fit</label>
        <select
          id="fitMode"
          value={snapshot.fitMode}
          onChange={(event) => pdfController.setFitMode(event.target.value as FitMode)}
        >
          <option value="fitWidth">Width</option>
          <option value="fitPage">Page</option>
          <option value="zoom">Zoom</option>
        </select>
        <button
          type="button"
          onClick={() => pdfController.rotate(-90)}
          aria-label="Rotate counter-clockwise 90 degrees"
        >
          Rotate -90
        </button>
        <button
          type="button"
          onClick={() => pdfController.rotate(90)}
          aria-label="Rotate clockwise 90 degrees"
        >
          Rotate +90
        </button>
        <label htmlFor="zoomSlider">Zoom</label>
        <input
          id="zoomSlider"
          type="range"
          min={25}
          max={400}
          value={snapshot.zoomPercent}
          aria-label="Zoom level"
          onChange={(event) => pdfController.setZoom(Number(event.target.value))}
        />
        <span className="small" aria-label="zoom level">
          {snapshot.zoomPercent}%
        </span>
      </div>

      <div className="control-row">
        <label htmlFor="pageInput">Page</label>
        <input
          id="pageInput"
          ref={pageInput}
          type="number"
          min={1}
          max={snapshot.pageCount || undefined}
          placeholder="Page"
          style={{ width: 72 }}
          aria-label="Target page number"
          onKeyDown={(event) => {
            if (event.key === "Enter") pdfController.setPage(Number(pageInput.current?.value));
          }}
        />
        <button type="button" onClick={() => pdfController.setPage(Number(pageInput.current?.value))}>
          Go
        </button>
        <span className="small">
          {snapshot.status === "ready" ? `${snapshot.currentPage} / ${snapshot.pageCount}` : "—"}
        </span>
      </div>

      <div className="control-row">
        <label htmlFor="searchInput">Search</label>
        <input
          id="searchInput"
          ref={searchInput}
          type="text"
          placeholder="Search..."
          style={{ width: 200 }}
          aria-label="Search document text"
          onKeyDown={(event) => {
            if (event.key === "Enter") void pdfController.search(searchInput.current?.value ?? "");
          }}
        />
        <button
          type="button"
          onClick={() => void pdfController.search(searchInput.current?.value ?? "")}
          aria-label="Find occurrences in document"
        >
          Find
        </button>
        <button type="button" onClick={() => pdfController.gotoMatch(-1)} aria-label="Previous search occurrence">
          Prev
        </button>
        <button type="button" onClick={() => pdfController.gotoMatch(1)} aria-label="Next search occurrence">
          Next
        </button>
        <span className="small" aria-label="search result count">
          {snapshot.matches.length}
        </span>
      </div>

      <span id="status" className="status" role="status" aria-live="polite" aria-atomic="true">
        {createError ??
          snapshot.error ??
          (snapshot.status === "loading"
            ? "Reading source… nothing leaves this device."
            : creating
              ? "Creating document…"
              : "")}
      </span>
    </div>
  );
}
