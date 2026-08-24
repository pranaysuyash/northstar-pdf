#!/usr/bin/env python3
"""Add structures PDFKit cannot author reliably, with explicit provenance."""
from pathlib import Path
import sys
from pypdf import PdfReader, PdfWriter
from pypdf.constants import PageLabelStyle

if len(sys.argv) != 3:
    raise SystemExit("usage: add_navigation_metadata.py <input.pdf> <output.pdf>")

source = Path(sys.argv[1])
output = Path(sys.argv[2])
reader = PdfReader(str(source))
writer = PdfWriter()
writer.clone_document_from_reader(reader)
writer.set_page_label(0, 0, PageLabelStyle.UPPERCASE_ROMAN, prefix="Front matter ", start=1)
writer.set_page_label(1, 1, PageLabelStyle.LOWERCASE_LETTER, prefix="Section ", start=1)
writer.set_page_label(2, 2, PageLabelStyle.DECIMAL, prefix="Appendix ", start=7)
writer.add_attachment("fixture-note.txt", b"Attachment payload for PDF reader metadata coverage.\n")
with output.open("wb") as handle:
    writer.write(handle)
