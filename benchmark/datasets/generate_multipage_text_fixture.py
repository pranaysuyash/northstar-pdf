#!/usr/bin/env python3
"""
Generate a multi-page text/table fixture for performance regression work
(PERF-S14 snappiness captures, pipeline-mode scroll tests).

Uses reportlab (layout engine, independent producer) to emit N pages, each
with a heading, body paragraphs, and a small grid table — the shape the
freeze-pane table matcher and text extractors consume.

Usage:
  benchmark/datasets/.venv/bin/python benchmark/datasets/generate_multipage_text_fixture.py \
    --pages 120 --out benchmark/results/<dir>/perf-fixture-120p.pdf
"""

import argparse

from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import (
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Table,
    TableStyle,
)


def build(pages: int, out_path: str) -> None:
    styles = getSampleStyleSheet()
    doc = SimpleDocTemplate(out_path, pagesize=letter)
    flow = []

    for page_index in range(pages):
        flow.append(Paragraph(f"Section {page_index + 1} — Quarterly Ledger", styles["Heading1"]))
        flow.append(
            Paragraph(
                "This synthetic fixture page exercises text extraction, table "
                "detection, and thumbnail rendering with deterministic content. "
                "Rows below repeat with small index-derived variations so every "
                "page carries a distinct but regular table grid.",
                styles["BodyText"],
            )
        )
        rows = [["Line item", "Count", "Amount (USD)"]]
        for row in range(12):
            rows.append(
                [
                    f"Item {page_index + 1}.{row + 1} — service line",
                    str((page_index * 12 + row) % 97 + 1),
                    f"{((page_index * 31 + row * 7) % 5000) / 100:.2f}",
                ]
            )
        table = Table(rows, colWidths=[3.2 * inch, 1.2 * inch, 1.6 * inch])
        table.setStyle(
            TableStyle(
                [
                    ("GRID", (0, 0), (-1, -1), 0.5, "grey"),
                    ("BACKGROUND", (0, 0), (-1, 0), "lightgrey"),
                ]
            )
        )
        flow.append(table)
        flow.append(PageBreak())

    doc.build(flow)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pages", type=int, default=120)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    build(args.pages, args.out)
    print(f"wrote {args.pages} pages -> {args.out}")


if __name__ == "__main__":
    main()
