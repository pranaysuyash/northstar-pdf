/*
 * Provider-neutral impact checks for the browser adapter.
 *
 * PDF.js remains the reader/evidence provider. pdf-lib is not imported here on
 * purpose: this module compares an inspected source document with a materialized
 * output document and reports what can be proven outside the user-authorized
 * operation regions.
 */

function normalizeRect(rect) {
  const [x1, y1, x2, y2] = rect;
  return {
    x: Math.min(x1, x2),
    y: Math.min(y1, y2),
    width: Math.abs(x2 - x1),
    height: Math.abs(y2 - y1)
  };
}

function rectIntersects(a, b, tolerance = 0) {
  return a.x < b.x + b.width + tolerance
    && a.x + a.width > b.x - tolerance
    && a.y < b.y + b.height + tolerance
    && a.y + a.height > b.y - tolerance;
}

function rectContainsPoint(rect, x, y) {
  return x >= rect.x && x <= rect.x + rect.width
    && y >= rect.y && y <= rect.y + rect.height;
}

function operationRegions(operations, pageViews) {
  const list = Array.isArray(operations) ? operations : [];
  const pageCount = Array.isArray(pageViews) ? pageViews.length : Number(pageViews || 0);
  const regions = [];
  const issues = [];
  for (const operation of list) {
    const coordinate = operation?.coordinate;
    const rect = coordinate?.rect;
    const validRect = rect
      && ["x", "y", "width", "height"].every((key) => Number.isFinite(rect[key]))
      && rect.width > 0
      && rect.height > 0;
    if (!operation?.id || !Number.isInteger(operation.pageIndex) || operation.pageIndex < 0 || operation.pageIndex >= pageCount) {
      issues.push(`Operation ${operation?.id || "<unknown>"} has an invalid page index.`);
    } else if (!coordinate || coordinate.pageIndex !== operation.pageIndex) {
      issues.push(`Operation ${operation.id} has a coordinate page mismatch.`);
    } else if (!validRect) {
      issues.push(`Operation ${operation.id} has no usable page-space coordinate rectangle.`);
    } else {
      // PDF widget appearances can antialias a few pixels beyond their nominal
      // rectangle. Keep the operation geometry exact, but authorize that small
      // provider-rendering envelope for synthesized fields during impact proof.
      const margin = operation.kind === "synthesizeNativeField" ? 3 : 0;
      const pageView = Array.isArray(pageViews) ? pageViews[operation.pageIndex] : null;
      const cropOrigin = operation.coordinate?.coordinateSpace?.pageBox === "crop" && pageView
        ? { x: Number(pageView[0]) || 0, y: Number(pageView[1]) || 0 }
        : { x: 0, y: 0 };
      regions.push({
        operationID: operation.id,
        pageIndex: operation.pageIndex,
        rect: {
          x: rect.x + cropOrigin.x - margin,
          y: rect.y + cropOrigin.y - margin,
          width: rect.width + (margin * 2),
          height: rect.height + (margin * 2)
        }
      });
    }
  }
  return { regions, issues };
}

function operationRegionFailure(issues, operations) {
  if (!issues.length) return null;
  const operationIDs = (Array.isArray(operations) ? operations : [])
    .map((operation) => operation?.id)
    .filter(Boolean);
  return {
    status: "unknown",
    message: `Outside-region validation could not authorize operation regions: ${issues.join(" ")}`,
    pages: [],
    operationIDs
  };
}

function textItemRect(pdfjsLib, viewport, item) {
  const transform = pdfjsLib.Util.transform(viewport.transform, item.transform);
  const fontSize = Math.max(1, Math.hypot(transform[0], transform[1]));
  const x = transform[4];
  const yTop = transform[5] - fontSize;
  const topLeft = viewport.convertToPdfPoint(x, yTop);
  const bottomRight = viewport.convertToPdfPoint(x + Math.max(1, item.width || 0), yTop + fontSize);
  return normalizeRect([topLeft[0], topLeft[1], bottomRight[0], bottomRight[1]]);
}

async function textItemsForPage(pdfjsLib, page) {
  const viewport = page.getViewport({ scale: 1, rotation: 0 });
  const content = await page.getTextContent();
  return content.items
    .map((item) => ({
      text: item.str || "",
      rect: textItemRect(pdfjsLib, viewport, item)
    }))
    .filter((item) => item.text.length > 0);
}

function normalizeText(text) {
  return String(text || "").replace(/\s+/g, " ").trim();
}

function outsideText(items, regions) {
  return normalizeText(items
    .filter((item) => !regions.some((region) => rectIntersects(item.rect, region.rect, 0.5)))
    .map((item) => item.text)
    .join(" "));
}

/**
 * Compare extracted text outside operation regions. This is intentionally an
 * outside-region check, not a general semantic PDF text editor proof.
 */
export async function compareOutsideRegionText({ pdfjsLib, sourceDocument, outputDocument, operations }) {
  if (!sourceDocument || !outputDocument) {
    return {
      status: "unknown",
      message: "Outside-region text comparison requires both source and output documents.",
      pages: []
    };
  }
  if (sourceDocument.numPages !== outputDocument.numPages) {
    return {
      status: "failed",
      message: "Outside-region text comparison could not align documents with different page counts.",
      pages: []
    };
  }
  const pageViews = [];
  for (let pageNum = 1; pageNum <= sourceDocument.numPages; pageNum += 1) {
    const page = await sourceDocument.getPage(pageNum);
    pageViews.push(Array.from(page.view || []));
  }
  const regionState = operationRegions(operations, pageViews);
  const regionFailure = operationRegionFailure(regionState.issues, operations);
  if (regionFailure) return regionFailure;

  const pages = [];
  for (let pageNum = 1; pageNum <= sourceDocument.numPages; pageNum += 1) {
    const sourcePage = await sourceDocument.getPage(pageNum);
    const outputPage = await outputDocument.getPage(pageNum);
    const regions = regionState.regions.filter((region) => region.pageIndex === pageNum - 1);
    const sourceItems = await textItemsForPage(pdfjsLib, sourcePage);
    const outputItems = await textItemsForPage(pdfjsLib, outputPage);
    const sourceOutside = outsideText(sourceItems, regions);
    const outputOutside = outsideText(outputItems, regions);
    pages.push({
      pageIndex: pageNum - 1,
      operationIDs: regions.map((region) => region.operationID),
      sourceOutside,
      outputOutside,
      equal: sourceOutside === outputOutside
    });
  }

  const mismatches = pages.filter((page) => !page.equal);
  return {
    status: mismatches.length ? "failed" : "passed",
    message: mismatches.length
      ? `${mismatches.length} page(s) changed outside the authorized operation regions.`
      : "Extracted text outside the authorized operation regions is unchanged.",
    pages
  };
}

async function renderPageToCanvas(pdfDocument, pageNum, scale) {
  const page = await pdfDocument.getPage(pageNum);
  const viewport = page.getViewport({ scale, rotation: 0 });
  const canvas = globalThis.document.createElement("canvas");
  canvas.width = Math.max(1, Math.ceil(viewport.width));
  canvas.height = Math.max(1, Math.ceil(viewport.height));
  const context = canvas.getContext("2d", { willReadFrequently: true });
  if (!context) {
    throw new Error("Canvas 2D context is unavailable for raster validation.");
  }
  context.save();
  context.fillStyle = "#ffffff";
  context.fillRect(0, 0, canvas.width, canvas.height);
  context.restore();
  await page.render({ canvasContext: context, viewport }).promise;
  return { canvas, context, viewport };
}

function viewportRect(viewport, rect) {
  return normalizeRect(viewport.convertToViewportRectangle([
    rect.x,
    rect.y,
    rect.x + rect.width,
    rect.y + rect.height
  ]));
}

function pixelIsOutsideRegions(x, y, regions, viewport) {
  if (!regions.length) {
    return true;
  }
  return !regions.some((region) => rectContainsPoint(viewportRect(viewport, region.rect), x, y));
}

/**
 * Render source and output with the same PDF.js viewport and compare pixels
 * outside the user-authorized regions. The result is a metric, not a claim of
 * byte-identical or independent-viewer parity.
 */
export async function compareOutsideRegionRaster({
  pdfjsLib,
  sourceDocument,
  outputDocument,
  operations,
  scale = 1.5,
  channelTolerance = 8,
  maxAllowedOutsidePixelRatio = 0
}) {
  if (!sourceDocument || !outputDocument) {
    return {
      status: "unknown",
      message: "Raster comparison requires both source and output documents.",
      pages: []
    };
  }
  if (sourceDocument.numPages !== outputDocument.numPages) {
    return {
      status: "failed",
      message: "Raster comparison could not align documents with different page counts.",
      pages: []
    };
  }
  const pageViews = [];
  for (let pageNum = 1; pageNum <= sourceDocument.numPages; pageNum += 1) {
    const page = await sourceDocument.getPage(pageNum);
    pageViews.push(Array.from(page.view || []));
  }
  const regionState = operationRegions(operations, pageViews);
  const regionFailure = operationRegionFailure(regionState.issues, operations);
  if (regionFailure) return regionFailure;

  const pages = [];
  for (let pageNum = 1; pageNum <= sourceDocument.numPages; pageNum += 1) {
    const sourceRendered = await renderPageToCanvas(sourceDocument, pageNum, scale);
    const outputRendered = await renderPageToCanvas(outputDocument, pageNum, scale);
    const sourceImage = sourceRendered.context.getImageData(
      0,
      0,
      sourceRendered.canvas.width,
      sourceRendered.canvas.height
    );
    const outputImage = outputRendered.context.getImageData(
      0,
      0,
      outputRendered.canvas.width,
      outputRendered.canvas.height
    );
    const sameSize = sourceImage.width === outputImage.width && sourceImage.height === outputImage.height;
    if (!sameSize) {
      pages.push({ pageIndex: pageNum - 1, status: "failed", message: "Rendered page dimensions changed." });
      continue;
    }

    const regions = regionState.regions.filter((region) => region.pageIndex === pageNum - 1);
    let outsidePixelCount = 0;
    let changedPixelCount = 0;
    let maxChannelDelta = 0;
    for (let y = 0; y < sourceImage.height; y += 1) {
      for (let x = 0; x < sourceImage.width; x += 1) {
        if (!pixelIsOutsideRegions(x + 0.5, y + 0.5, regions, sourceRendered.viewport)) {
          continue;
        }
        outsidePixelCount += 1;
        const offset = (y * sourceImage.width + x) * 4;
        let changed = false;
        for (let channel = 0; channel < 4; channel += 1) {
          const delta = Math.abs(sourceImage.data[offset + channel] - outputImage.data[offset + channel]);
          maxChannelDelta = Math.max(maxChannelDelta, delta);
          if (delta > channelTolerance) {
            changed = true;
          }
        }
        if (changed) {
          changedPixelCount += 1;
        }
      }
    }
    const outsidePixelRatio = outsidePixelCount ? changedPixelCount / outsidePixelCount : 0;
    pages.push({
      pageIndex: pageNum - 1,
      status: outsidePixelRatio <= maxAllowedOutsidePixelRatio ? "passed" : "failed",
      outsidePixelCount,
      changedPixelCount,
      outsidePixelRatio,
      maxChannelDelta,
      operationIDs: regions.map((region) => region.operationID)
    });
  }

  const failed = pages.filter((page) => page.status === "failed");
  return {
    status: failed.length ? "failed" : "passed",
    message: failed.length
      ? `${failed.length} page(s) changed outside the authorized raster regions.`
      : "Raster output is unchanged outside the authorized operation regions.",
    scale,
    channelTolerance,
    maxAllowedOutsidePixelRatio,
    pages
  };
}

export async function compareOutsideRegions(options) {
  const text = await compareOutsideRegionText(options);
  let raster;
  try {
    raster = await compareOutsideRegionRaster(options);
  } catch (error) {
    raster = {
      status: "unknown",
      message: `Raster comparison could not run: ${error.message}`,
      pages: []
    };
  }
  return { text, raster };
}
