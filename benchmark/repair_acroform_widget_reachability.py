#!/usr/bin/env python3
"""Repair PDFKit's missing /AcroForm /Fields reachability for widget annotations.

The repair is intentionally structural only: it reuses existing widget objects
already present in page /Annots arrays and never changes field values, names,
appearance streams, or non-widget annotations.
"""
from pathlib import Path
import os
import sys
import tempfile

from pypdf import PdfReader, PdfWriter


def reference_key(value):
    if hasattr(value, "idnum"):
        return (value.idnum, getattr(value, "generation", 0))
    return None


def repair(input_path: Path, output_path: Path) -> int:
    reader = PdfReader(str(input_path), strict=False)
    writer = PdfWriter()
    writer.clone_document_from_reader(reader)

    root = writer._root_object
    acro_form = root.get("/AcroForm")
    if acro_form is None:
        return 0
    acro_form = acro_form.get_object()
    fields = acro_form.get("/Fields")
    if fields is None:
        fields = writer._add_object([])
        acro_form["/Fields"] = fields
    fields = fields.get_object()
    existing = {reference_key(entry) for entry in fields}
    added = 0

    for page in writer.pages:
        annotations = page.get("/Annots")
        if annotations is None:
            continue
        for annotation_ref in annotations:
            annotation = annotation_ref.get_object()
            if annotation.get("/Subtype") != "/Widget":
                continue
            key = reference_key(annotation_ref)
            if key in existing:
                continue
            fields.append(annotation_ref)
            existing.add(key)
            added += 1

    output_path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix="pdf-editor-acroform-", suffix=".pdf", dir=output_path.parent)
    os.close(fd)
    temporary_path = Path(temporary)
    try:
        with temporary_path.open("wb") as handle:
            writer.write(handle)
        temporary_path.replace(output_path)
    finally:
        temporary_path.unlink(missing_ok=True)
    return added


if len(sys.argv) not in (2, 3):
    raise SystemExit("usage: repair_acroform_widget_reachability.py <input.pdf> [output.pdf]")

source = Path(sys.argv[1])
destination = Path(sys.argv[2]) if len(sys.argv) == 3 else source
print(f"repaired_widgets={repair(source, destination)} output={destination}")
