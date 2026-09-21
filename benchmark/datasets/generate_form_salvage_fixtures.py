#!/usr/bin/env python3
"""
Generate fixtures for the Fieldroom salvage verification pass
(docs/research/form-field-lab-salvage-assessment-2026-09-21.md):

  1. zero-target: prose + wide table rules (hard negatives). The detector
     must abstain; the app shows the explicit "No suggestions detected"
     abstention state.
  2. signature-block: two signer blocks near the page bottom, ink scribbled
     into one slot. The signature occupancy audit must report the occupied
     slot PRESENT and the empty slot MISSING (review-only document evidence).

Usage:
  benchmark/datasets/.venv/bin/python benchmark/datasets/generate_form_salvage_fixtures.py \
      --out benchmark/results/2026-09-21-form-lab-salvage
"""

import argparse
import os

from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle


def build_zero_target(out_path):
    """Prose + a gridded table; no field labels, no blanks, no role words."""
    styles = getSampleStyleSheet()
    doc = SimpleDocTemplate(out_path, pagesize=letter)
    story = []
    for index in range(6):
        story.append(
            Paragraph(
                "The quarterly review summarized operating results across every "
                f"region and confirmed that the variance remained within the "
                f"published tolerance band for period {index + 1}.",
                styles["BodyText"],
            )
        )
        story.append(Spacer(1, 10))

    rows = [["Region", "Revenue", "Variance", "Notes"]]
    for index in range(8):
        rows.append([f"Region {index + 1}", f"{1200 + index * 137}", f"{-11 + index}", "Within band"])
    table = Table(rows, colWidths=[110, 90, 80, 120])
    table.setStyle(
        TableStyle(
            [
                ("GRID", (0, 0), (-1, -1), 0.7, (0.55, 0.55, 0.55)),
                ("BACKGROUND", (0, 0), (-1, 0), (0.9, 0.9, 0.9)),
            ]
        )
    )
    story.append(table)
    story.append(Spacer(1, 12))
    story.append(
        Paragraph(
            "Prepared by the reporting team for internal circulation and retained "
            "in the archive until the next scheduled review cycle concludes.",
            styles["BodyText"],
        )
    )
    doc.build(story)


def build_signature_block(out_path):
    """Two role blocks near the bottom; ink over the Secretary slot only."""
    from reportlab.pdfgen import canvas as pdfcanvas

    width, height = letter
    overlay = pdfcanvas.Canvas(out_path, pagesize=letter)
    overlay.setFont("Helvetica", 11)
    overlay.drawString(60, 720, "Board Resolution — the undersigned certify the minutes above are true.")

    overlay.drawString(80, 250, "John Doe")
    overlay.drawString(80, 220, "Director:")
    overlay.drawString(80, 130, "Jane Roe")
    overlay.drawString(80, 100, "Secretary:")

    # Ink scribble inside the Secretary slot band (Jane Roe top ~142.5,
    # so the 38pt writable band spans ~144.5-182.5pt from the bottom).
    overlay.setLineWidth(2)
    overlay.setStrokeGray(0.15)
    p = overlay.beginPath()
    p.moveTo(84, 152)
    p.curveTo(105, 178, 140, 148, 170, 160)
    p.curveTo(155, 164, 142, 172, 130, 168)
    overlay.drawPath(p, stroke=1, fill=0)
    overlay.save()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, help="output directory")
    args = parser.parse_args()
    os.makedirs(args.out, exist_ok=True)

    zero = os.path.join(args.out, "salvage-zero-target.pdf")
    signature = os.path.join(args.out, "salvage-signature-block.pdf")
    build_zero_target(zero)
    build_signature_block(signature)
    print(f"wrote {zero}")
    print(f"wrote {signature}")


if __name__ == "__main__":
    main()
