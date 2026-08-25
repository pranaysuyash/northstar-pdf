/* Browser-side vector and text geometry detector.
 *
 * PDF.js exposes the page operator list but not a semantic form-field detector.
 * This module intentionally emits suggestions and evidence only. It never
 * creates an AcroForm field and never promotes a shape to a confirmed edit.
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

function transformPoint(matrix, x, y) {
  return {
    x: matrix[0] * x + matrix[2] * y + matrix[4],
    y: matrix[1] * x + matrix[3] * y + matrix[5]
  };
}

function multiplyMatrix(left, right) {
  return [
    left[0] * right[0] + left[2] * right[1],
    left[1] * right[0] + left[3] * right[1],
    left[0] * right[2] + left[2] * right[3],
    left[1] * right[2] + left[3] * right[3],
    left[0] * right[4] + left[2] * right[5] + left[4],
    left[1] * right[4] + left[3] * right[5] + left[5]
  ];
}

function transformedRect(matrix, x, y, width, height) {
  const points = [
    transformPoint(matrix, x, y),
    transformPoint(matrix, x + width, y),
    transformPoint(matrix, x, y + height),
    transformPoint(matrix, x + width, y + height)
  ];
  return normalizeRect([
    Math.min(...points.map((point) => point.x)),
    Math.min(...points.map((point) => point.y)),
    Math.max(...points.map((point) => point.x)),
    Math.max(...points.map((point) => point.y))
  ]);
}

function lineRect(start, end) {
  const rect = normalizeRect([start.x, start.y, end.x, end.y]);
  return {
    ...rect,
    width: Math.max(1, rect.width),
    height: Math.max(1, rect.height)
  };
}

function rectIntersects(a, b, tolerance = 0) {
  return a.x < b.x + b.width + tolerance
    && a.x + a.width > b.x - tolerance
    && a.y < b.y + b.height + tolerance
    && a.y + a.height > b.y - tolerance;
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

function uniqueRects(rects) {
  const seen = new Set();
  return rects.filter((rect) => {
    const key = [rect.x, rect.y, rect.width, rect.height].map((value) => Number(value.toFixed(3))).join(":");
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function unionRects(rects) {
  const x1 = Math.min(...rects.map((rect) => rect.x));
  const y1 = Math.min(...rects.map((rect) => rect.y));
  const x2 = Math.max(...rects.map((rect) => rect.x + rect.width));
  const y2 = Math.max(...rects.map((rect) => rect.y + rect.height));
  return normalizeRect([x1, y1, x2, y2]);
}

function clipRectToPage(rect, pageBounds) {
  const x1 = Math.max(pageBounds.x, Math.min(pageBounds.x + pageBounds.width, rect.x));
  const y1 = Math.max(pageBounds.y, Math.min(pageBounds.y + pageBounds.height, rect.y));
  const x2 = Math.max(x1, Math.min(pageBounds.x + pageBounds.width, rect.x + rect.width));
  const y2 = Math.max(y1, Math.min(pageBounds.y + pageBounds.height, rect.y + rect.height));
  return normalizeRect([x1, y1, x2, y2]);
}

function median(values) {
  if (!values.length) return 0;
  const sorted = [...values].sort((left, right) => left - right);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid];
}

import { fuseCandidateEvidence } from "./pdf-evidence-fusion.mjs";

/**
 * Group vector cell rectangles into character-grid candidate groups.
 *
 * First-principles rule for a character-grid entry region:
 *   - The cells must share the page-space row band (identical top/bottom
 *     baseline within a sub-pixel tolerance). Cells with a different
 *     baseline are from a different row.
 *   - The cells must share cell-size signature (width AND height within a
 *     tight tolerance). Cells with a different cell size are from a
 *     sibling field at the same y position — joining them silently
 *     expands the candidate bounds past the user's intended field.
 *   - Within a row, inter-cell gaps must remain "regular": a large gap
 *     that diverges sharply from the within-run median is a field
 *     boundary, even if absolute distance is small.
 *
 * Tolerance notes:
 *   - The 0.5 pt top/bottom tolerance is chosen so cells drawn by the same
 *     PDF rasterization line up but a different row drawn slightly higher
 *     is recognized as different.
 *   - The 0.7 pt width / height tolerance is chosen so the natural
 *     sub-pixel rounding of vector cells does NOT split a real grid, but
 *     a sibling field drawn with a different cell width IS split out.
 *     This is the mechanism the user asked for: "it could have noticed
 *     missing lines on top and bottom" — we infer "missing lines" from
 *     cell-size signature mismatch rather than expecting the original
 *     PDF to author an explicit horizontal stroke per row.
 */
function adjacentGroups(rects) {
  if (!rects.length) return [];
  // Stage 1: bucket by shared baseline. Cells sharing top/bottom/height
  // within tolerance form a row band. Width is NOT used as a bucket key
  // yet so that signature outliers do not orphan themselves; Stage 2
  // splits within a band by cell-size signature.
  const BANDS = { top: 0.5, bottom: 0.5, height: 0.7 };
  const bands = [];
  for (const cell of rects) {
    const representative = bands.find((band) => band.cells.some((other) =>
      Math.abs(cell.y - other.y) <= BANDS.top
      && Math.abs((cell.y + cell.height) - (other.y + other.height)) <= BANDS.bottom
      && Math.abs(cell.height - other.height) <= BANDS.height
    ));
    if (representative) representative.cells.push(cell);
    else bands.push({ cells: [cell] });
  }

  // Stage 2: per band, walk cells left-to-right and split where the
  // cell-size signature changes OR where a gap is markedly larger than
  // the within-band median.
  const WIDTH_TOL = 0.7;
  const groups = [];
  for (const band of bands) {
    const sorted = [...band.cells].sort((left, right) => left.x - right.x);
    // Identify maximal width-signature runs. A width-signature run is a
    // maximal connected span of cells where each cell's width is within
    // WIDTH_TOL of the prior cell AND each step's gap is below an
    // absolute "obviously not adjacent" threshold.
    const signatureRuns = [];
    let current = [sorted[0]];
    let currentWidth = sorted[0].width;
    for (let index = 1; index < sorted.length; index += 1) {
      const prev = current.at(-1);
      const cell = sorted[index];
      const gap = cell.x - (prev.x + prev.width);
      const widthDelta = Math.abs(cell.width - currentWidth);
      const fitsWidth = widthDelta <= WIDTH_TOL;
      const fitsHeight = Math.abs(cell.height - prev.height) <= BANDS.height;
      // Two cells share a width-signature when their widths are close AND
      // they sit on adjacent pitch. A wide gap is a strong break signal
      // even when widths match (different fields).
      const continues = fitsWidth && fitsHeight && gap <= Math.max(8, prev.width * 0.6);
      if (continues) current.push(cell);
      else {
        signatureRuns.push(current);
        current = [cell];
        currentWidth = cell.width;
      }
    }
    signatureRuns.push(current);

    // Stage 3: per width-signature run, sub-divide by gap pattern. A run
    // contains one or more field-runs separated by gaps that diverge
    // sharply from the median gap. Width-signature kept, the candidate
    // really is in one row — the gap test only excludes outliers.
    for (const signatureRun of signatureRuns) {
      const sortedRun = [...signatureRun].sort((a, b) => a.x - b.x);
      const fieldRuns = [];
      let run = [sortedRun[0]];
      let runGaps = [];
      for (let index = 1; index < sortedRun.length; index += 1) {
        const prev = run.at(-1);
        const cell = sortedRun[index];
        const gap = cell.x - (prev.x + prev.width);
        if (run.length === 1) {
          // First pair — adopt a small absolute heuristic so the seed is
          // not classified as an outlier by the empty median.
          const tight = gap >= -1 && gap <= Math.max(8, prev.width * 0.5);
          if (tight) {
            run.push(cell);
            runGaps.push(gap);
          } else {
            fieldRuns.push(run);
            run = [cell];
            runGaps = [];
          }
          continue;
        }
        const medianGap = median(runGaps);
        // The threshold is the larger of (a) 4× the median within-run gap
        // — generous enough to absorb occasional segment gaps inside a
        // real character entry — and (b) the same absolute token as the
        // first-pair check.
        const threshold = Math.max(medianGap * 4, 8, prev.width * 0.5);
        if (gap >= -1 && gap <= threshold) {
          run.push(cell);
          runGaps.push(gap);
        } else {
          fieldRuns.push(run);
          run = [cell];
          runGaps = [];
        }
      }
      fieldRuns.push(run);
      for (const fieldRun of fieldRuns) {
        if (fieldRun.length >= 3) groups.push(fieldRun);
      }
    }
  }
  return groups;
}

function nearestLabel(region, lines, maxDistance) {
  let best = null;
  let bestDistance = maxDistance;
  for (const line of lines) {
    const text = line.text.trim();
    if (text.length < 2 || !isLikelyFieldLabel(text)) continue;
    const left = line.rect;
    const isLeft = left.x + left.width <= region.x + 15
      && Math.abs(left.y + left.height / 2 - (region.y + region.height / 2)) < Math.max(region.height, 20);
    const isAbove = left.y >= region.y + region.height - 5
      && Math.abs(left.x - region.x) < Math.max(region.width, 100)
      && left.y - (region.y + region.height) < maxDistance;
    if (isLeft) {
      const distance = region.x - (left.x + left.width);
      if (distance >= 0 && distance < bestDistance) {
        best = line;
        bestDistance = distance;
      }
    } else if (isAbove) {
      const distance = left.y - (region.y + region.height);
      if (distance >= 0 && distance < bestDistance) {
        best = line;
        bestDistance = distance;
      }
    }
  }
  return best;
}

function inferFieldType(text) {
  const value = String(text || "").toLowerCase();
  if (/(sign|signature)/.test(value)) return "signature";
  if (/(date|dob|birth|dd\/mm|yyyy)/.test(value)) return "date";
  if (/(amount|number|count|zip|postal|phone|tel|ssn)/.test(value)) return "number";
  if (/(select one|one of|gender|relationship|relative type|proof choice)/.test(value)) return "radio";
  if (/(yes|no|agree|check|mark|male|female|select|tick)/.test(value)) return "checkbox";
  return "text";
}

// Proximity alone is not label semantics. Generic layout text such as
// "Section:" and "Note:" is retained as document text but is a hard negative
// for field-candidate association.
function isLikelyFieldLabel(text) {
  const normalized = String(text || "")
    .toLowerCase()
    .replaceAll("_", " ")
    .replaceAll(".", " ")
    .replaceAll(":", " ");
  return [
    "name", "address", "email", "phone", "tel", "date", "dob", "birth",
    "signature", "sign", "ssn", "zip", "postal", "amount", "number",
    "account", "agree", "check", "select", "choice", "gender", "relationship",
    "city", "state", "country", "company", "employer", "license", "policy",
    "claim", "reference", "id"
  ].some((token) => new RegExp(`\\b${token}\\b`).test(normalized));
}

function entryMode(fieldType, grouped = false) {
  if (fieldType === "checkbox") return "checkbox";
  if (fieldType === "radio") return "radioGroup";
  if (fieldType === "signature") return "signature";
  return grouped ? "characterGrid" : "singleText";
}

function candidate({ pageIndex, pageRotation, bounds, kind, score, status = "suggested", fieldType = "text", mode, labelText = null, evidenceItems, evidence, sourceDigest, groupMemberCount = 1, memberBounds = [] }) {
  const coordinate = {
    pageIndex,
    rect: bounds,
    coordinateSpace: { unit: "points", origin: "lowerLeft", pageBox: "crop", rotationDegrees: ((pageRotation % 360) + 360) % 360 }
  };
  const normalizedEvidenceItems = evidenceItems.map((item) => ({ ...item, id: item.id || `evidence-${crypto.randomUUID()}` }));
  return {
    id: `candidate-${crypto.randomUUID()}`,
    pageIndex,
    bounds,
    kind,
    status,
    score,
    evidence,
    nativeFieldID: null,
    coordinate,
    suggestedFieldType: fieldType,
    entryMode: mode || entryMode(fieldType),
    labelText,
    groupMemberCount,
    memberBounds,
    evidenceItems: normalizedEvidenceItems,
    fusion: fuseCandidateEvidence({
      signals: normalizedEvidenceItems.map((item) => ({
        id: item.id,
        kind: item.kind,
        origin: item.origin,
        providerID: item.provider?.id || null,
        score: item.score ?? score,
        region: item.region?.rect || null
      }))
    }),
    sourceDigest
  };
}

function labelAssociationEvidence({ label, pageIndex, pageRotation }) {
  if (!label) return [];
  const coordinateSpace = { unit: "points", origin: "lowerLeft", pageBox: "crop", rotationDegrees: pageRotation };
  return [
    {
      kind: "textLabel",
      origin: "textExtraction",
      summary: `Label text associated by page-space proximity: "${label.text}"`,
      region: { pageIndex, rect: label.rect, coordinateSpace },
      text: label.text,
      score: 0.72
    },
    {
      kind: "spatialRelationship",
      origin: "textExtraction",
      summary: "The label is positioned to the left of or above the candidate region",
      region: { pageIndex, rect: label.rect, coordinateSpace },
      text: label.text,
      score: 0.72
    }
  ];
}

function parsePathGeometry(pdfjsLib, operatorList) {
  const OPS = pdfjsLib.OPS;
  const identity = [1, 0, 0, 1, 0, 0];
  let matrix = identity;
  const matrixStack = [];
  let currentPath = [];
  let currentPoint = null;
  let rectangles = [];
  let lines = [];

  const addLine = (start, end) => {
    if (start && end) lines.push(lineRect(start, end));
  };
  const moveTo = (x, y) => {
    currentPoint = transformPoint(matrix, x, y);
    currentPath = [currentPoint];
  };
  const lineTo = (x, y) => {
    const next = transformPoint(matrix, x, y);
    addLine(currentPoint, next);
    currentPath.push(next);
    currentPoint = next;
  };

  const consumeConstructedPath = (args) => {
    const [pathOps, pathArgs] = args;
    let offset = 0;
    for (const pathOp of pathOps || []) {
      if (pathOp === OPS.rectangle) {
        const [x, y, width, height] = pathArgs.slice(offset, offset + 4);
        offset += 4;
        rectangles.push(transformedRect(matrix, x, y, width, height));
      } else if (pathOp === OPS.moveTo) {
        moveTo(pathArgs[offset], pathArgs[offset + 1]);
        offset += 2;
      } else if (pathOp === OPS.lineTo) {
        lineTo(pathArgs[offset], pathArgs[offset + 1]);
        offset += 2;
      } else if (pathOp === OPS.closePath) {
        if (currentPath.length > 1) addLine(currentPath.at(-1), currentPath[0]);
        currentPoint = currentPath.at(-1) || currentPoint;
      } else if (pathOp === OPS.curveTo) {
        offset += 6;
      } else if (pathOp === OPS.curveTo2 || pathOp === OPS.curveTo3) {
        offset += 4;
      }
    }
  };

  for (let index = 0; index < operatorList.fnArray.length; index += 1) {
    const op = operatorList.fnArray[index];
    const args = operatorList.argsArray[index] || [];
    if (op === OPS.save) matrixStack.push(matrix);
    else if (op === OPS.restore) matrix = matrixStack.pop() || identity;
    else if (op === OPS.transform) matrix = multiplyMatrix(matrix, args);
    else if (op === OPS.rectangle) rectangles.push(transformedRect(matrix, args[0], args[1], args[2], args[3]));
    else if (op === OPS.moveTo) moveTo(args[0], args[1]);
    else if (op === OPS.lineTo) lineTo(args[0], args[1]);
    else if (op === OPS.closePath && currentPath.length > 1) addLine(currentPath.at(-1), currentPath[0]);
    else if (op === OPS.constructPath) consumeConstructedPath(args);
  }
  return { rectangles: uniqueRects(rectangles), lines: uniqueRects(lines) };
}

function geometryForPage(pdfjsLib, operatorList) {
  return parsePathGeometry(pdfjsLib, operatorList);
}

export async function detectGeometryCandidates({ pdfjsLib, page, pageIndex, pageRotation = 0, sourceDigest }) {
  const viewport = page.getViewport({ scale: 1, rotation: 0 });
  const content = await page.getTextContent();
  const lines = content.items
    .filter((item) => (item.str || "").trim())
    .map((item) => ({ text: item.str.trim(), rect: textItemRect(pdfjsLib, viewport, item) }));
  const operatorList = await page.getOperatorList();
  const geometry = geometryForPage(pdfjsLib, operatorList);
  const pageBounds = normalizeRect(page.view || [0, 0, viewport.width, viewport.height]);
  const pageArea = Math.max(1, pageBounds.width * pageBounds.height);
  const boundedRectangles = geometry.rectangles.map((rect) => clipRectToPage(rect, pageBounds));
  const cleanRects = boundedRectangles.filter((rect) => {
    const area = rect.width * rect.height;
    return area <= pageArea * 0.95 && rect.width >= 3 && rect.height >= 3;
  });
  const squareRects = cleanRects.filter((rect) => {
    const square = Math.abs(rect.width - rect.height) <= Math.max(rect.width * 0.25, 3);
    return square && rect.width >= 8 && rect.width <= 32;
  });
  const inputRects = cleanRects.filter((rect) => {
    const square = Math.abs(rect.width - rect.height) <= Math.max(rect.width * 0.25, 3);
    return !square && rect.height >= 12 && rect.height <= 300 && rect.width >= 24 && rect.width <= pageBounds.width * 0.92;
  });
  const horizontalLines = geometry.lines
    .map((rect) => clipRectToPage(rect, pageBounds))
    .filter((rect) => rect.width >= 24 && rect.height <= 4);
  const found = [];
  const claimed = [];
  const isClaimed = (rect) => claimed.some((claimedRect) => rectIntersects(claimedRect, rect, 0.5));
  const claim = (rect) => claimed.push(rect);

  for (const group of adjacentGroups(squareRects)) {
    const bounds = unionRects(group);
    const label = nearestLabel(bounds, lines, 160);
    if (!label) continue;
    const labelText = label?.text || null;
    const fieldType = inferFieldType(labelText);
    found.push(candidate({
      pageIndex,
      pageRotation,
      bounds,
      kind: "vectorRegion",
      score: 0.90,
      status: fieldType === "checkbox" ? "unknown" : "suggested",
      fieldType,
      mode: entryMode(fieldType, true),
      labelText,
      groupMemberCount: group.length,
      memberBounds: group,
      evidence: [
        `Grouped ${group.length} adjacent vector cells into one entry region.`,
        `Associated label: "${labelText}"`
      ],
      evidenceItems: [
        { kind: "repeatedPattern", origin: "geometryExtraction", summary: `${group.length} adjacent vector cells grouped into one region`, region: { pageIndex, rect: bounds, coordinateSpace: { unit: "points", origin: "lowerLeft", pageBox: "crop", rotationDegrees: pageRotation } }, text: labelText, score: label ? 0.90 : 0.62 },
        ...labelAssociationEvidence({ label, pageIndex, pageRotation })
      ],
      sourceDigest
    }));
    group.forEach(claim);
    claim(bounds);
  }

  for (const rect of squareRects) {
    if (isClaimed(rect)) continue;
    const label = nearestLabel(rect, lines, 120);
    // An isolated square without label or grouping evidence is ambiguous
    // page decoration. Do not promote it to an actionable checkbox review.
    if (!label) continue;
    if (rect.height < 8) continue;
    const labelText = label?.text || null;
    found.push(candidate({
      pageIndex,
      pageRotation,
      bounds: rect,
      kind: "vectorRegion",
      score: 0.85,
      status: "suggested",
      fieldType: "checkbox",
      mode: "checkbox",
      labelText,
      groupMemberCount: 1,
      memberBounds: [rect],
      evidence: [
        `Vector checkbox-shaped rectangle detected (${Math.round(rect.width)}x${Math.round(rect.height)}pt).`,
        `Associated label: "${labelText}"`
      ],
      evidenceItems: [
        { kind: "vectorRectangle", origin: "geometryExtraction", summary: `Checkbox-shaped vector square path at (${Math.round(rect.x)}, ${Math.round(rect.y)})`, region: { pageIndex, rect, coordinateSpace: { unit: "points", origin: "lowerLeft", pageBox: "crop", rotationDegrees: pageRotation } }, score: 0.85 },
        ...labelAssociationEvidence({ label, pageIndex, pageRotation })
      ],
      sourceDigest
    }));
    claim(rect);
  }

  for (const rect of inputRects) {
    if (isClaimed(rect)) continue;
    const label = nearestLabel(rect, lines, 160);
    // A large rectangle without any associated label is still ambiguous
    // document geometry (for example a table cell or decorative panel). Keep
    // it as raw provider evidence, but do not promote it to an editable
    // suggestion without a semantic anchor.
    if (!label) continue;
    const labelText = label?.text || null;
    const fieldType = inferFieldType(labelText);
    found.push(candidate({
      pageIndex,
      pageRotation,
      bounds: rect,
      kind: "vectorRegion",
      score: 0.80,
      fieldType,
      mode: entryMode(fieldType),
      labelText,
      evidence: [
        `Vector input rectangle detected (${Math.round(rect.width)}x${Math.round(rect.height)}pt).`,
        `Associated label: "${labelText}"`
      ],
      evidenceItems: [
        { kind: "vectorRectangle", origin: "geometryExtraction", summary: `Vector rectangle at (${Math.round(rect.x)}, ${Math.round(rect.y)})`, region: { pageIndex, rect, coordinateSpace: { unit: "points", origin: "lowerLeft", pageBox: "crop", rotationDegrees: pageRotation } }, score: 0.80 },
        ...labelAssociationEvidence({ label, pageIndex, pageRotation })
      ],
      sourceDigest
    }));
    claim(rect);
  }

  for (const line of horizontalLines) {
    if (isClaimed(line)) continue;
    const region = { x: line.x, y: line.y, width: line.width, height: 18 };
    const label = nearestLabel(region, lines, 120);
    // A bare horizontal rule is ambiguous: it may be a page border, table
    // rule, or decoration. Without text association it is not sufficient
    // evidence for an editable entry region.
    if (!label) continue;
    const labelText = label?.text || null;
    const fieldType = inferFieldType(labelText);
    found.push(candidate({
      pageIndex,
      pageRotation,
      bounds: region,
      kind: "vectorRegion",
      score: 0.75,
      fieldType,
      mode: entryMode(fieldType),
      labelText,
      evidence: [
        `Vector underline stroke detected (${Math.round(line.width)}pt).`,
        `Associated label: "${labelText}"`
      ],
      evidenceItems: [
        { kind: "underline", origin: "geometryExtraction", summary: `Vector horizontal line at y=${Math.round(line.y)}`, region: { pageIndex, rect: line, coordinateSpace: { unit: "points", origin: "lowerLeft", pageBox: "crop", rotationDegrees: pageRotation } }, score: 0.75 },
        ...labelAssociationEvidence({ label, pageIndex, pageRotation })
      ],
      sourceDigest
    }));
    claim(region);
  }

  for (const line of lines) {
    if (!/[:：]$/.test(line.text) && !/_{3,}|\.{3,}$/.test(line.text)) continue;
    if (!isLikelyFieldLabel(line.text)) continue;
    if (claimed.some((rect) => rectIntersects(rect, line.rect, 2))) continue;
    const whitespace = clipRectToPage({
      x: line.rect.x + line.rect.width + 8,
      y: line.rect.y,
      width: Math.max(72, Math.min(220, pageBounds.x + pageBounds.width - line.rect.x - line.rect.width - 20)),
      height: Math.max(14, line.rect.height + 5)
    }, pageBounds);
    const fieldType = inferFieldType(line.text);
    found.push(candidate({
      pageIndex,
      pageRotation,
      bounds: whitespace,
      kind: "textAnchored",
      score: /_{3,}|\.{3,}$/.test(line.text) ? 0.45 : 0.58,
      fieldType,
      mode: entryMode(fieldType),
      labelText: line.text,
      evidence: [
        `Whitespace entry region inferred after the text label "${line.text}".`,
        "No vector geometry overlapped the suggested area."
      ],
      evidenceItems: [
        { kind: "whitespace", origin: "textExtraction", summary: "Whitespace adjacent to a label was promoted to a reviewable candidate", region: { pageIndex, rect: whitespace, coordinateSpace: { unit: "points", origin: "lowerLeft", pageBox: "crop", rotationDegrees: pageRotation } }, text: line.text, score: 0.58 },
        { kind: "textLabel", origin: "textExtraction", summary: "Label text anchors the whitespace candidate", region: { pageIndex, rect: line.rect, coordinateSpace: { unit: "points", origin: "lowerLeft", pageBox: "crop", rotationDegrees: pageRotation } }, text: line.text },
        { kind: "spatialRelationship", origin: "textExtraction", summary: "Whitespace is positioned after the label text", region: { pageIndex, rect: line.rect, coordinateSpace: { unit: "points", origin: "lowerLeft", pageBox: "crop", rotationDegrees: pageRotation } }, text: line.text, score: 0.58 }
      ],
      sourceDigest
    }));
    claim(whitespace);
  }
  return found.slice(0, 200);
}
