#!/usr/bin/env python3
"""Generate radio-group fixtures with diverse export vocabularies.

Each fixture is a single-page PDF with one or more radio groups in proper
tree structure (parent holds /T, /Kids, /FT; kids hold /AS, /AP).

Fixtures:
1. yes_no.pdf           — standard Yes/No vocabulary
2. on_off.pdf           — standard On/Off vocabulary
3. email_phone.pdf      — Email/Phone/Mail vocabulary
4. hierarchical.pdf     — parent.child dotted hierarchical names
5. multi_group.pdf      — multiple radio groups on one page
6. single_option.pdf    — single-option radio (degenerate case)
7. numeric_vocabulary.pdf — numeric export values 0/1/2/3
8. off_adjacent.pdf     — off-token-adjacent export 0/1
"""

import os
import sys

try:
    import pikepdf
except ImportError:
    print("ERROR: pikepdf not installed. Run: uv pip install --python benchmark/datasets/.venv/bin/python pikepdf")
    sys.exit(1)

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "radio-fixtures")


def create_radio_pdf(
    filename: str,
    groups: list[dict],
) -> str:
    """Create a PDF with properly tree-structured radio groups.

    groups: list of {
        "name": str,           # parent field name (T key)
        "options": list[str],  # export values for each kid
        "selected": str | None # which option is currently selected
    }
    """
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    path = os.path.join(OUTPUT_DIR, filename)
    pdf = pikepdf.Pdf.new()
    page = pikepdf.Page(pdf.make_indirect(
        pikepdf.Dictionary({
            "/Type": pikepdf.Name("/Page"),
            "/MediaBox": pikepdf.Array([0, 0, 612, 792]),
            "/Annots": pikepdf.Array([]),
        })
    ))
    pdf.pages.append(page)

    # AcroForm
    fields = pikepdf.Array()
    acroform = pdf.make_indirect(pikepdf.Dictionary({
        "/Type": pikepdf.Name("/AcroForm"),
        "/Fields": fields,
        "/NeedAppearances": pikepdf.Boolean(True),
    }))
    pdf.Root["/AcroForm"] = acroform

    y = 700
    for group in groups:
        name = group["name"]
        options = group["options"]
        selected = group.get("selected")

        # Parent field node (has /T, /FT, /Kids, /V)
        kids = pikepdf.Array()
        field = pdf.make_indirect(pikepdf.Dictionary({
            "/T": pikepdf.String(name),
            "/FT": pikepdf.Name("/Btn"),
            "/Kids": kids,
            "/Ff": pikepdf.Integer(32768),  # radio
        }))
        if selected:
            field["/V"] = pikepdf.Name(f"/{selected}")
        fields.append(field)

        for oi, opt in enumerate(options):
            rect = pikepdf.Array([72, y - oi * 24, 250, y - oi * 24 + 20])

            # Appearance state sub-dict (each kid has its own AP with state→stream mapping)
            on_ap = pdf.make_indirect(pikepdf.Dictionary({
                "/BBox": pikepdf.Array([0, 0, 178, 20]),
                "/Resources": pikepdf.Dictionary({}),
                "/Stream": pdf.make_stream(b"q 0 g 0 0 178 20 re f Q"),
            }))
            off_ap = pdf.make_indirect(pikepdf.Dictionary({
                "/BBox": pikepdf.Array([0, 0, 178, 20]),
                "/Resources": pikepdf.Dictionary({}),
                "/Stream": pdf.make_stream(b"q 0.9 g 0 0 178 20 re f Q"),
            }))
            ap = pdf.make_indirect(pikepdf.Dictionary({
                "/N": pikepdf.Dictionary({
                    f"/{opt}": on_ap,
                    "/Off": off_ap,
                }),
            }))

            # Kid annotation (NO /T — inherits from parent; has /AS, /AP, /Parent)
            annot = pdf.make_indirect(pikepdf.Dictionary({
                "/Type": pikepdf.Name("/Annot"),
                "/Subtype": pikepdf.Name("/Widget"),
                "/Rect": rect,
                "/AP": ap,
                "/Ff": pikepdf.Integer(32768),
                "/Parent": field,
            }))
            if selected == opt:
                annot["/AS"] = pikepdf.Name(f"/{opt}")
            else:
                annot["/AS"] = pikepdf.Name("/Off")

            kids.append(annot)
            page["/Annots"].append(annot)

        y -= len(options) * 24 + 30

    pdf.save(path)
    return path


def main():
    fixtures = []

    # 1. Yes/No vocabulary
    fixtures.append(create_radio_pdf(
        "yes_no.pdf",
        [{"name": "agree", "options": ["Yes", "No"], "selected": "Yes"}],
    ))

    # 2. On/Off vocabulary
    fixtures.append(create_radio_pdf(
        "on_off.pdf",
        [{"name": "enable_feature", "options": ["On", "Off"], "selected": "On"}],
    ))

    # 3. Email/Phone/Mail vocabulary
    fixtures.append(create_radio_pdf(
        "email_phone.pdf",
        [{"name": "contact_method", "options": ["Email", "Phone", "Mail"], "selected": "Email"}],
    ))

    # 4. Hierarchical dotted names
    fixtures.append(create_radio_pdf(
        "hierarchical.pdf",
        [
            {"name": "applicant.contact", "options": ["Email", "Phone"], "selected": "Phone"},
            {"name": "applicant.preference", "options": ["Morning", "Afternoon", "Evening"], "selected": "Morning"},
        ],
    ))

    # 5. Multiple groups on one page
    fixtures.append(create_radio_pdf(
        "multi_group.pdf",
        [
            {"name": "priority", "options": ["High", "Medium", "Low"], "selected": "Medium"},
            {"name": "status", "options": ["Active", "Inactive", "Pending"], "selected": "Active"},
            {"name": "visibility", "options": ["Public", "Private"], "selected": "Private"},
        ],
    ))

    # 6. Single-option radio (degenerate)
    fixtures.append(create_radio_pdf(
        "single_option.pdf",
        [{"name": "confirm", "options": ["Yes"], "selected": "Yes"}],
    ))

    # 7. Numeric vocabulary
    fixtures.append(create_radio_pdf(
        "numeric_vocabulary.pdf",
        [{"name": "rating", "options": ["0", "1", "2", "3"], "selected": "2"}],
    ))

    # 8. Off-token-adjacent export
    fixtures.append(create_radio_pdf(
        "off_adjacent.pdf",
        [{"name": "choice", "options": ["0", "1"], "selected": "1"}],
    ))

    print(f"Generated {len(fixtures)} radio fixtures in {OUTPUT_DIR}:")
    for f in fixtures:
        print(f"  {os.path.basename(f)}")

    # Verify each with pikepdf (tree structure check)
    print("\nTree structure verification:")
    for f in fixtures:
        pdf = pikepdf.open(f)
        acroform = pdf.Root.get("/AcroForm")
        if acroform:
            top_fields = acroform.get("/Fields", [])
            for field_ref in top_fields:
                field = field_ref if isinstance(field_ref, pikepdf.Dictionary) else field_ref
                name = str(field.get("/T", ""))
                kids = field.get("/Kids", [])
                kid_count = len(kids) if kids else 0
                value = str(field.get("/V", "none"))
                ft = str(field.get("/FT", ""))
                print(f"  {os.path.basename(f)}: {name} FT={ft} kids={kid_count} V={value}")
        pdf.close()


if __name__ == "__main__":
    main()
