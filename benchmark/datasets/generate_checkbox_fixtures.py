#!/usr/bin/env python3
"""
Generate 12 diverse checkbox-bearing AcroForm fixtures with pikepdf.

pikepdf (qpdf-backed) is a genuinely independent PDF producer with no shared
code with PDFKit — the same producer-independence the radio fixtures used.
These fixtures exercise the checkbox round-trip surface the RG-134/parity
experiment measures:

  vocabulary   export "checked" name      producer remark
  ----------   -----------------------    ---------------------------------
   Yes/Off     Yes                        most common (Adobe default)
   On/Off      On                         used by many form generators
   True/False  True                       boolean literal vocabulary
   1/Off       1                          numeric export
   Y/N         Y                          short-token form
   Checked      (empty)                   checked = empty export (PDF 32000-1
                                          permits "" as the on state)
   hierarchical names (a.b.c)             dotted field names
   multiple boxes per page                several independent boxes on one page
   pre-checked vs pre-unchecked           both start states

Each generated PDF is self-contained (no external fonts beyond Helvetica
Type1 base-14, no NeedAppearances requirement: each widget carries its own
/AP /N and /AP /D streams per PDF 32000-1 §12.7.4.3).

Usage:
  benchmark/datasets/.venv/bin/python benchmark/datasets/generate_checkbox_fixtures.py
"""

import os
import sys
import pikepdf

OUTPUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "checkbox-fixtures")


def _appearance_stream(pdf, checked: bool):
    """Self-contained Appearance stream: a filled square when checked,
    an empty square otherwise. Uses only built-in operators (no font)."""
    if checked:
        content = (
            b"0.0 0.0 0.0 rg\n"
            b"2 2 20 20 re\n"
            b"f\n"
        )
    else:
        content = (
            b"0.0 0.0 0.0 RG\n"
            b"2 2 20 20 re\n"
            b"S\n"
        )
    return pikepdf.Stream(pdf, content, {
        "/Type": pikepdf.Name("/XObject"),
        "/Subtype": pikepdf.Name("/Form"),
        "/FormType": pikepdf.Integer(1),
        "/BBox": pikepdf.Array([0, 0, 24, 24]),
        "/Resources": pikepdf.Dictionary({}),
    })


def _make_checkbox(pdf, page, name, checked_name, is_checked, x, y):
    """Add one checkbox widget kid (leaf /Btn with /T, /V optional, /AP).

    Returns the field node object (for /V)."""
    # Appearance states: the on-state export name and Off.
    states = [checked_name if checked_name else "", "Off"]
    on_state = checked_name if checked_name else ""
    apn = pikepdf.Dictionary()
    apd = pikepdf.Dictionary()
    for state in states:
        ind = pdf.make_indirect(_appearance_stream(pdf, state == on_state))
        apn[pikepdf.Name("/" + state)] = ind
        ind2 = pdf.make_indirect(_appearance_stream(pdf, False))
        apd[pikepdf.Name("/" + state)] = ind2

    # On-state appearance name: the export value (or the empty name when the
    # checkbox declares an empty export). Off is the reserved unselected name.
    as_on = on_state if is_checked else "Off"
    as_name = pikepdf.Name("/" + as_on)
    v = pikepdf.Name("/" + on_state) if (is_checked and on_state) else pikepdf.Name("/Off")
    widget = pdf.make_indirect(pikepdf.Dictionary({
        "/Type": pikepdf.Name("/Annot"),
        "/Subtype": pikepdf.Name("/Widget"),
        "/Rect": pikepdf.Array([x, y, x + 24, y + 24]),
        "/FT": pikepdf.Name("/Btn"),
        "/Ff": pikepdf.Integer(0),  # checkbox bit not set → default checkbox
        "/T": pikepdf.String(name),
        "/AP": pikepdf.Dictionary({
            "/N": apn,
            "/D": apd,
        }),
        "/AS": as_name,
        "/V": v,
    }))
    page["/Annots"].append(widget)
    return widget


def _new_page(pdf):
    page = pikepdf.Page(pdf.make_indirect(
        pikepdf.Dictionary({
            "/Type": pikepdf.Name("/Page"),
            "/MediaBox": pikepdf.Array([0, 0, 612, 792]),
            "/Annots": pikepdf.Array([]),
        })
    ))
    pdf.pages.append(page)
    return page


def _finalize(pdf):
    # /AcroForm with the root fields list.
    fields = []
    # Collect every widget that is a leaf /Btn.
    for p in pdf.pages:
        for a in p["/Annots"]:
            if a.get("/Subtype", None) == pikepdf.Name("/Widget") and a.get("/FT", None) == pikepdf.Name("/Btn"):
                fields.append(a)
    if not fields:
        return
    acroform = pdf.make_indirect(pikepdf.Dictionary({
        "/Type": pikepdf.Name("/AcroForm"),
        "/Fields": pikepdf.Array(fields),
        "/NeedAppearances": pikepdf.Boolean(False),
    }))
    pdf.Root["/AcroForm"] = acroform


FIXTURES = [
    # (filename, list of (name, checked_export, is_checked, x, y))
    ("yes_off_unchecked_basic.pdf", [
        ("consent", "Yes", False, 72, 700),
    ]),
    ("yes_off_checked_basic.pdf", [
        ("consent", "Yes", True, 72, 700),
    ]),
    ("on_off_unchecked.pdf", [
        ("termsAccepted", "On", False, 72, 700),
    ]),
    ("on_off_checked.pdf", [
        ("termsAccepted", "On", True, 72, 700),
    ]),
    ("true_false_unchecked.pdf", [
        ("acknowledgment", "True", False, 72, 700),
    ]),
    ("one_off_unchecked.pdf", [
        ("signatureRequired", "1", False, 72, 700),
    ]),
    ("y_n_unchecked.pdf", [
        ("optIn", "Y", False, 72, 700),
    ]),
    ("checked_off_unchecked.pdf", [
        ("submitAlso", "Checked", False, 72, 700),
    ]),
    ("checked_off_checked.pdf", [
        ("submitAlso", "Checked", True, 72, 700),
    ]),
    ("hierarchical_names.pdf", [
        ("applicant.consent", "Yes", True, 72, 700),
        ("applicant.preferences.updates", "Yes", False, 72, 660),
        ("applicant.preferences.newsletter", "On", True, 72, 620),
    ]),
    ("multibox_same_page.pdf", [
        ("box1", "Yes", False, 72, 700),
        ("box2", "Yes", True, 72, 660),
        ("box3", "Yes", False, 72, 620),
        ("box4", "Yes", True, 72, 580),
    ]),
    ("prechecked_hierarchical.pdf", [
        ("profile.personal.newsletter", "Yes", True, 72, 700),
        ("profile.business.updates", "Yes", False, 72, 660),
    ]),
    ("mixed_export_same_page.pdf", [
        ("agree1", "Yes", True, 72, 700),
        ("agree2", "On", False, 72, 660),
        ("agree3", "1", True, 72, 620),
        ("agree4", "Y", False, 72, 580),
    ]),
]


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    generated = []
    for filename, boxes in FIXTURES:
        pdf = pikepdf.Pdf.new()
        page = _new_page(pdf)
        for name, checked_name, is_checked, x, y in boxes:
            _make_checkbox(pdf, page, name, checked_name, is_checked, x, y)
        _finalize(pdf)
        path = os.path.join(OUTPUT_DIR, filename)
        pdf.save(path)
        generated.append((filename, len(boxes)))
        print(f"wrote {filename} ({len(boxes)} checkbox(es))")
    print(f"generated {len(generated)} fixtures in {OUTPUT_DIR}")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"error: {e}", file=sys.stderr)
        sys.exit(1)