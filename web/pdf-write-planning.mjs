/**
 * Pure write-planning contracts shared by browser export writers.
 *
 * Salvaged from the legacy browser entry (web/app.js materializeOperations /
 * validateExport) so the React surface replays identical semantics instead of
 * growing a second implementation. No DOM, no provider imports: font metrics
 * are injected, so Node tests can exercise the exact fit rules.
 */

/**
 * Value comparison used by independent reopen validation. Radio operations may
 * legitimately round-trip as widget-state indices; boolean operations compare
 * truthiness rather than spelling. Salvaged from validateExport/valuesMatch.
 */
export function valuesMatch(expected, actual, operation) {
  const payload = operation?.payload || {};
  if (payload.kind === "radio") {
    const options = Array.isArray(payload.options) ? payload.options : [];
    const expectedIndex = options.indexOf(expected);
    if (expectedIndex >= 0 && String(expectedIndex) === String(actual || "").trim()) {
      return true;
    }
    return (expected || "").trim() === (actual || "").trim();
  }
  if (payload.kind === "boolean") {
    const expectedTruthy = /^(1|true|yes|on|checked)$/i.test((expected || "").trim());
    const actualTruthy = !/^(off|false|no|0|)$/i.test((actual || "").trim());
    return expectedTruthy === actualTruthy;
  }
  return (expected || "").trim() === (actual || "").trim();
}

const BOUNDED_TEXT_MINIMUM_SIZE = 6;
const BOUNDED_TEXT_PADDING = 2;

/**
 * Plans a single-line overlay draw inside an authorized rectangle.
 *
 * pdf-lib's maxWidth option can wrap text; wrapping would escape the declared
 * authorization region, so this planner measures first and refuses any text
 * that cannot fit at a legible size. Returns device-space draw coordinates
 * (baseline box) for the caller's drawText call.
 *
 * @param {object} options
 * @param {string} options.text - the confirmed overlay value
 * @param {{x:number,y:number,width:number,height:number}} options.bounds - authorized PDF-space rectangle
 * @param {(text:string,size:number)=>number} options.widthOfTextAtSize
 * @param {(size:number)=>number} options.heightAtSize
 * @returns {{x:number,y:number,size:number}}
 */
export function planSingleLineOverlay({ text, bounds, widthOfTextAtSize, heightAtSize }) {
  if (!bounds || ![bounds.x, bounds.y, bounds.width, bounds.height].every(Number.isFinite)) {
    throw new Error("Overlay operation has no usable coordinate bounds.");
  }
  const value = String(text ?? "");
  const availableWidth = bounds.width - BOUNDED_TEXT_PADDING * 2;
  const availableHeight = bounds.height - BOUNDED_TEXT_PADDING * 2;
  const preferredSize = Math.max(8, Math.min(14, bounds.height * 0.72));
  const preferredWidth = widthOfTextAtSize(value, preferredSize);
  const preferredHeight = heightAtSize(preferredSize);
  const widthSize = preferredWidth > 0 ? (preferredSize * availableWidth) / preferredWidth : preferredSize;
  const heightSize = preferredHeight > 0 ? (preferredSize * availableHeight) / preferredHeight : preferredSize;
  const size = Math.min(preferredSize, widthSize, heightSize);
  if (!Number.isFinite(size) || size < BOUNDED_TEXT_MINIMUM_SIZE) {
    throw new Error(
      `Bounded single-line text cannot fit inside its declared region `
      + `(${bounds.width.toFixed(2)} x ${bounds.height.toFixed(2)}pt) `
      + `at the supported minimum font size of ${BOUNDED_TEXT_MINIMUM_SIZE}pt. `
      + "Choose a larger region or explicitly request multiline text."
    );
  }
  const measuredWidth = widthOfTextAtSize(value, size);
  const measuredHeight = heightAtSize(size);
  if (measuredWidth > availableWidth + 0.01 || measuredHeight > availableHeight + 0.01) {
    throw new Error(
      "Bounded single-line text cannot fit its measured text footprint "
      + "inside the declared operation region. Choose a larger region or "
      + "explicitly request multiline text."
    );
  }
  return {
    x: bounds.x + BOUNDED_TEXT_PADDING,
    y: bounds.y + BOUNDED_TEXT_PADDING + Math.max(0, (availableHeight - measuredHeight) / 2),
    size
  };
}

/** Default proposal geometry for a click-initiated overlay region. */
export const OVERLAY_PROPOSAL = Object.freeze({
  widthPt: 180,
  heightPt: 24,
  paddingPt: 6,
  minimumSizePt: 36
});

const ENCRYPTED_WRITE_MESSAGE =
  "Encrypted PDF editing is not supported by the browser writer. "
  + "The protected source remains read-only; unchanged export is byte-preserving.";

/**
 * Export authorization gate. Encrypted sources refuse any mutation; only a
 * zero-operation byte-preserving copy may proceed. Salvaged from the legacy
 * entry's materializeOperations guard.
 */
export function assertWritable({ encrypted, operationCount }) {
  if (!encrypted) return;
  if (operationCount > 0) {
    throw new Error(ENCRYPTED_WRITE_MESSAGE);
  }
}

function normalizeRectTuple(rect) {
  const [x1, y1, x2, y2] = rect;
  return { x: Math.min(x1, x2), y: Math.min(y1, y2), width: Math.abs(x2 - x1), height: Math.abs(y2 - y1) };
}

/**
 * Reads page facts from an untouched pdf-lib source document so they can be
 * replayed onto the output before edits: pdf-lib can normalize non-default
 * page boxes while loading/saving, which would silently change the meaning of
 * crop-relative operation bounds. `rotationOf(pageIndex)` supplies rotation
 * truth from the inspected reader document (pdf.js).
 */
export function planPageFactReplay(sourceDocument, rotationOf = () => 0) {
  const box = (value) =>
    value && Number.isFinite(value.x)
      ? normalizeRectTuple([value.x, value.y, value.x + value.width, value.y + value.height])
      : null;
  return sourceDocument.getPages().map((page, index) => ({
    boxes: {
      media: box(page.getMediaBox()),
      crop: box(page.getCropBox()),
      bleed: box(page.getBleedBox()),
      trim: box(page.getTrimBox()),
      art: box(page.getArtBox())
    },
    rotate: ((Number(rotationOf(index)) % 360) + 360) % 360
  }));
}

/**
 * Replays inspected page facts onto the output document. Must run before any
 * edit is applied.
 */
export function applyPageFacts(outputDocument, facts, degrees) {
  outputDocument.getPages().forEach((page, index) => {
    const fact = facts[index];
    if (!fact) return;
    const replay = (method, rect) => {
      if (!rect) return;
      page[method](rect.x, rect.y, rect.width, rect.height);
    };
    replay("setMediaBox", fact.boxes.media);
    replay("setCropBox", fact.boxes.crop);
    replay("setBleedBox", fact.boxes.bleed);
    replay("setTrimBox", fact.boxes.trim);
    replay("setArtBox", fact.boxes.art);
    if (typeof page.setRotation === "function") {
      page.setRotation(degrees(fact.rotate || 0));
    }
  });
}

/**
 * Proposes an authorized rectangle around a PDF-space point, clamped into the
 * page crop box so a placement near an edge can never authorize an
 * out-of-page region.
 */
export function proposeOverlayBounds(point, cropBox, proposal = OVERLAY_PROPOSAL) {
  const [x1, y1, x2, y2] = cropBox;
  const left = Math.min(x1, x2);
  const bottom = Math.min(y1, y2);
  const right = Math.max(x1, x2);
  const top = Math.max(y1, y2);
  const pageWidth = Math.max(0, right - left);
  const pageHeight = Math.max(0, top - bottom);
  // The minimum guards page capacity, not the proposal: a short 24pt entry
  // line is a valid authorized region on any normally sized page.
  if (pageWidth < proposal.minimumSizePt || pageHeight < proposal.minimumSizePt) {
    throw new RangeError("Page crop box is too small to host an overlay region.");
  }
  const width = Math.min(proposal.widthPt, pageWidth);
  const height = Math.min(proposal.heightPt, pageHeight);
  const x = Math.min(Math.max(point.x - width / 2, left + proposal.paddingPt), right - proposal.paddingPt - width);
  const y = Math.min(Math.max(point.y - height / 2, bottom + proposal.paddingPt), top - proposal.paddingPt - height);
  return { x, y, width, height };
}
