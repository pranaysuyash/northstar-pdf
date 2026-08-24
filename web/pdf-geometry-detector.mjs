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

function adjacentGroups(rects) {
  const sorted = [...rects].sort((left, right) => {
    if (Math.abs(left.y - right.y) > 3) return right.y - left.y;
    return left.x - right.x;
  });
  const groups = [];
  for (const rect of sorted) {
    const last = groups.at(-1);
    const previous = last?.at(-1);
    if (!previous) {
      groups.push([rect]);
      continue;
    }
    const sameRow = Math.abs(rect.y + rect.height / 2 - (previous.y + previous.height / 2))
      <= Math.max(3, Math.min(rect.height, previous.height) * 0.5);
    const gap = rect.x - (previous.x + previous.width);
    const closeEnough = gap >= -1 && gap <= Math.max(8, Math.min(rect.width, previous.width) * 1.5);
    if (sameRow && closeEnough) last.push(rect);
    else groups.push([rect]);
  }
  return groups.filter((group) => group.length >= 3);
}

function nearestLabel(region, lines, maxDistance) {
  let best = null;
  let bestDistance = maxDistance;
  for (const line of lines) {
    const text = line.text.trim();
    if (text.length < 2) continue;
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
    evidenceItems: evidenceItems.map((item) => ({ ...item, id: item.id || `evidence-${crypto.randomUUID()}` })),
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
    const labelText = label?.text || null;
    const fieldType = inferFieldType(labelText);
    found.push(candidate({
      pageIndex,
      pageRotation,
      bounds,
      kind: "vectorRegion",
      score: label ? 0.90 : 0.62,
      status: fieldType === "checkbox" ? "unknown" : "suggested",
      fieldType,
      mode: entryMode(fieldType, true),
      labelText,
      groupMemberCount: group.length,
      memberBounds: group,
      evidence: [
        `Grouped ${group.length} adjacent vector cells into one entry region.`,
        label ? `Associated label: "${labelText}"` : "No nearby label matched; review before applying."
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
    const labelText = label?.text || null;
    found.push(candidate({
      pageIndex,
      pageRotation,
      bounds: rect,
      kind: "vectorRegion",
      score: label ? 0.85 : 0.52,
      status: label ? "suggested" : "unknown",
      fieldType: "checkbox",
      mode: "checkbox",
      labelText,
      evidence: [
        `Vector checkbox-shaped rectangle detected (${Math.round(rect.width)}x${Math.round(rect.height)}pt).`,
        label ? `Associated label: "${labelText}"` : "No nearby label matched; review before applying."
      ],
      evidenceItems: [
        { kind: "vectorRectangle", origin: "geometryExtraction", summary: `Checkbox-shaped vector square path at (${Math.round(rect.x)}, ${Math.round(rect.y)})`, region: { pageIndex, rect, coordinateSpace: { unit: "points", origin: "lowerLeft", pageBox: "crop", rotationDegrees: pageRotation } }, score: label ? 0.85 : 0.52 },
        ...labelAssociationEvidence({ label, pageIndex, pageRotation })
      ],
      sourceDigest
    }));
    claim(rect);
  }

  for (const rect of inputRects) {
    if (isClaimed(rect)) continue;
    const label = nearestLabel(rect, lines, 160);
    const labelText = label?.text || null;
    const fieldType = inferFieldType(labelText);
    found.push(candidate({
      pageIndex,
      pageRotation,
      bounds: rect,
      kind: "vectorRegion",
      score: label ? 0.80 : 0.65,
      fieldType,
      mode: entryMode(fieldType),
      labelText,
      evidence: [
        `Vector input rectangle detected (${Math.round(rect.width)}x${Math.round(rect.height)}pt).`,
        label ? `Associated label: "${labelText}"` : "No nearby label matched; review before applying."
      ],
      evidenceItems: [
        { kind: "vectorRectangle", origin: "geometryExtraction", summary: `Vector rectangle at (${Math.round(rect.x)}, ${Math.round(rect.y)})`, region: { pageIndex, rect, coordinateSpace: { unit: "points", origin: "lowerLeft", pageBox: "crop", rotationDegrees: pageRotation } }, score: label ? 0.80 : 0.65 },
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
    const labelText = label?.text || null;
    const fieldType = inferFieldType(labelText);
    found.push(candidate({
      pageIndex,
      pageRotation,
      bounds: region,
      kind: "vectorRegion",
      score: label ? 0.75 : 0.60,
      fieldType,
      mode: entryMode(fieldType),
      labelText,
      evidence: [
        `Vector underline stroke detected (${Math.round(line.width)}pt).`,
        label ? `Associated label: "${labelText}"` : "No nearby label matched; review before applying."
      ],
      evidenceItems: [
        { kind: "vectorLine", origin: "geometryExtraction", summary: `Vector horizontal line at y=${Math.round(line.y)}`, region: { pageIndex, rect: line, coordinateSpace: { unit: "points", origin: "lowerLeft", pageBox: "crop", rotationDegrees: pageRotation } }, score: label ? 0.75 : 0.60 },
        ...labelAssociationEvidence({ label, pageIndex, pageRotation })
      ],
      sourceDigest
    }));
    claim(region);
  }

  for (const line of lines) {
    if (!/[:：]$/.test(line.text) && !/_{3,}|\.{3,}$/.test(line.text)) continue;
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
