#!/usr/bin/env python3
"""Column-aware reading-order post-processing for OCR line boxes.

Fixes the multi-column reading-order confusion measured for PaddleOCR on the
ocr-corpus multi-column fixture (WER 0.73 in the 2026-09-03 baseline): the
engine returns recognized lines in detection order, which interleaves
side-by-side columns. Text recognition is fine — the *ordering* is wrong.

Model (first principles):
  A page is a vertical sequence of *bands*. A band is either single-column
  (its lines are ordered top-to-bottom, then left-to-right) or multi-column
  (its lines are grouped into columns ordered left-to-right, lines inside a
  column ordered top-to-bottom). Bands are ordered top-to-bottom.

  Single-column detection: if the line boxes in a band can be partitioned
  into two or more horizontally disjoint clusters whose vertical extents
  overlap strongly, the band is multi-column. Otherwise single-column.
  This is the newspaper rule: columns share vertical space; stacked blocks
  do not.

The function is engine-agnostic: it takes plain (text, x, y, w, h) boxes and
returns text in reading order. PaddleOCR PP-OCRv6 predict() output (dict with
rec_texts / rec_boxes / rec_scores, or rec_polys) is normalized upstream.

Deterministic: no randomness, stable sorts with explicit tiebreakers.
"""

from __future__ import annotations

import sys
from typing import Dict, List, Sequence, Tuple

Box = Tuple[str, float, float, float, float]  # text, x, y, w, h


def _overlap(a: Tuple[float, float], b: Tuple[float, float]) -> float:
    """Fraction of the smaller vertical extent covered by the intersection."""
    lo = max(a[0], b[0])
    hi = min(a[1], b[1])
    if hi <= lo:
        return 0.0
    smaller = min(a[1] - a[0], b[1] - b[0])
    if smaller <= 0:
        return 0.0
    return (hi - lo) / smaller


def _cluster_columns(boxes: List[Box], gap_factor: float) -> List[List[Box]]:
    """Greedy left-to-right column clustering by horizontal span.

    Sorts by x. A box joins a column when its x-range lies within the
    column's horizontal span extended by gap_factor x box height on either
    side (covers left-aligned columns and indents). Otherwise it starts a
    new column. Membership is purely horizontal — a side-by-side column
    shares no x-range with its neighbor by definition.
    """
    ordered = sorted(boxes, key=lambda b: (b[1], b[2]))
    columns: List[List[Box]] = []
    for box in ordered:
        placed = False
        for col in columns:
            left = min(b[1] for b in col)
            right = max(b[1] + b[3] for b in col)
            gap = gap_factor * max(box[4], 1.0)
            if box[1] <= right + gap and box[1] + box[3] >= left - gap:
                col.append(box)
                placed = True
                break
        if not placed:
            columns.append([box])
    # Order columns by their left edge.
    columns.sort(key=lambda col: min(b[1] for b in col))
    for col in columns:
        col.sort(key=lambda b: (b[2], b[1]))
    return columns


def _x_ranges(columns: List[Box]) -> List[Tuple[float, float]]:
    return [(min(b[1] for b in col), max(b[1] + b[3] for b in col)) for col in columns]


def _columns_disjoint(columns: List[Box], tolerance: float = 2.0) -> bool:
    """True when the clustered columns have pairwise disjoint x-extents.

    True side-by-side columns never share horizontal space; stacked blocks
    (full-width lines) do, so a cluster that overlaps itself is not a real
    column split and must be read single-column instead.
    """
    ranges = sorted(_x_ranges(columns))
    for i in range(len(ranges) - 1):
        if ranges[i][1] > ranges[i + 1][0] + tolerance:
            return False
    return True


def order_ocr_boxes(
    boxes: Sequence[Box],
    band_height_frac: float = 1.6,
    gap_factor: float = 1.5,
) -> List[str]:
    """Return box texts in document reading order.

    band_height_frac: a band accumulates lines whose top edge lies within
      this multiple of the median line height below the band's bottom.
    gap_factor: horizontal gap (x median line height) at which separate
      boxes join the same column during clustering.

    A band is read column-wise only when clustering yields 2+ columns with
    pairwise disjoint x-extents; otherwise (stacked or indented content)
    the band is read top-to-bottom, left-to-right.
    """
    if not boxes:
        return []
    heights = sorted(b[4] for b in boxes)
    median_h = max(heights[len(heights) // 2], 1.0)

    remaining = sorted(boxes, key=lambda b: (b[2], b[1]))  # top-to-bottom
    output: List[str] = []

    while remaining:
        # Start a band from the topmost line.
        band = [remaining.pop(0)]
        band_bottom = band[0][2] + band[0][4]
        changed = True
        while remaining and changed:
            changed = False
            for i, box in enumerate(remaining):
                if box[2] <= band_bottom + band_height_frac * median_h:
                    band.append(box)
                    del remaining[i]
                    band_bottom = max(band_bottom, box[2] + box[4])
                    changed = True
                    break

        columns = _cluster_columns(band, gap_factor)
        if len(columns) >= 2 and _columns_disjoint(columns):
            # Multi-column band: left-to-right columns, top-to-bottom inside.
            for col in columns:
                output.extend(b[0] for b in col)
        else:
            # Single-column band.
            for b in sorted(band, key=lambda b: (b[2], b[1])):
                output.append(b[0])

    return output


def normalize_paddle_result(page_result) -> Tuple[List[str], List[Box], List[float]]:
    """Extract (texts, boxes, scores) from a PP-OCRv6 predict() page entry.

    Handles both dict results and result objects, rec_boxes (xywh) and
    rec_polys (4-point). Missing box data yields empty boxes — callers then
    keep engine order honestly rather than guessing geometry.
    """
    def get(obj, key, default=None):
        if isinstance(obj, dict):
            return obj.get(key, default)
        return getattr(obj, key, default)

    texts = list(get(page_result, "rec_texts", []) or [])
    scores = list(get(page_result, "rec_scores", []) or [])
    raw_boxes = get(page_result, "rec_boxes", None)
    polys = get(page_result, "rec_polys", None)

    boxes: List[Box] = []
    if raw_boxes is not None and len(raw_boxes) == len(texts):
        for i, raw in enumerate(raw_boxes):
            try:
                x, y, w, h = float(raw[0]), float(raw[1]), float(raw[2]), float(raw[3])
            except (TypeError, ValueError, IndexError):
                continue
            boxes.append((str(texts[i]), x, y, w, h))
    elif polys is not None and len(polys) == len(texts):
        for i, poly in enumerate(polys):
            try:
                xs = [float(p[0]) for p in poly]
                ys = [float(p[1]) for p in poly]
            except (TypeError, ValueError, IndexError):
                continue
            boxes.append((str(texts[i]), min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys)))

    return texts, boxes, scores


def _self_test() -> int:
    """Deterministic geometry checks — no OCR engine involved."""
    failures: List[str] = []

    def check(name: str, got: List[str], want: List[str]) -> None:
        if got != want:
            failures.append(f"{name}: got {got}, want {want}")

    # Two side-by-side columns, detection order interleaved (L1, R1, L2, R2...).
    interleaved = [
        ("L1", 50, 100, 200, 20), ("R1", 350, 100, 200, 20),
        ("L2", 50, 130, 200, 20), ("R2", 350, 130, 200, 20),
        ("L3", 50, 160, 200, 20), ("R3", 350, 160, 200, 20),
    ]
    check("two-column", order_ocr_boxes(interleaved),
          ["L1", "L2", "L3", "R1", "R2", "R3"])

    # Stacked full-width blocks must stay in top-to-bottom order.
    stacked = [
        ("B3", 50, 300, 500, 20), ("B1", 50, 100, 500, 20), ("B2", 50, 200, 500, 20),
    ]
    check("stacked", order_ocr_boxes(stacked), ["B1", "B2", "B3"])

    # Single column with indents (second line indented right) stays one column.
    indented = [
        ("P1", 50, 100, 300, 20), ("P2", 90, 130, 260, 20), ("P3", 50, 160, 300, 20),
    ]
    check("indents", order_ocr_boxes(indented), ["P1", "P2", "P3"])

    # Header spanning full width, then two columns below: header first,
    # then column-wise. The header overlaps neither column vertically.
    mixed = [
        ("HDR", 50, 50, 500, 24),
        ("L1", 50, 150, 200, 20), ("R1", 350, 150, 200, 20),
        ("L2", 50, 180, 200, 20), ("R2", 350, 180, 200, 20),
    ]
    check("header+columns", order_ocr_boxes(mixed),
          ["HDR", "L1", "L2", "R1", "R2"])

    # Empty input is empty output.
    check("empty", order_ocr_boxes([]), [])

    if failures:
        for f in failures:
            print(f"SELF-TEST FAIL: {f}", file=sys.stderr)
        return 1
    print("ocr_reading_order self-test: 5/5 geometry checks pass")
    return 0


if __name__ == "__main__":
    sys.exit(_self_test())
