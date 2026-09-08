#!/usr/bin/env python3
"""Generate choice-field (/FT /Ch) fixtures with diverse /Opt arrays.

Radio groups encode their export vocabulary in kid /AS + /AP state names
(see generate_radio_fixtures.py). Choice fields — dropdowns and combos —
encode theirs in the field-level /Opt array (PDF 32000-1 §12.7.5.4,
Table 247). These fixtures harden the choice-field claim the same way the
radio fixtures harden the radio claim.

Each fixture is a single-page PDF with one or more choice fields. /V holds
the current export value; /Opt holds the option vocabulary.

Fixtures:
1. dropdown_strings.pdf       — region: plain string /Opt (US/EU/APAC)
2. dropdown_pairs.pdf         — ship_method: [export, display] pair /Opt
3. dropdown_numeric.pdf       — tier: numeric export values 0/1/2/3
4. choice_hierarchical.pdf    — order.priority + order.warehouse (dotted names)
5. choice_multi_field.pdf     — 3 choice fields on one page (combo included)
6. dropdown_empty_selection.pdf — selection: /Opt present, no /V (empty state)
7. combo_editable.pdf         — combo (Ff bit 18) with editable /V outside /Opt
8. listbox_multi_presets.pdf  — MULTI-SELECT (Ff bit 22): array /V, 2 of 5
9. listbox_multi_pairs.pdf    — multi-select with [export, display] /Opt, 3 of 4
10. listbox_multi_empty.pdf   — multi-select flag set, no /V (empty selection)
11. listbox_multi_hierarchical.pdf — dotted names, two multi-select fields
12. listbox_single_select.pdf — plain listbox (no bit 22): array /V must be
    refused by writers (fail-closed check target)
"""

import os
import sys

try:
    import pikepdf
except ImportError:
    print("ERROR: pikepdf not installed. Run: uv pip install --python benchmark/datasets/.venv/bin/python pikepdf")
    sys.exit(1)

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "choice-fixtures")


def create_choice_pdf(filename: str, fields: list[dict]) -> str:
    """Create a PDF with tree-structured choice fields.

    fields: list of {
        "name": str,              # field name (T key)
        "options": list,          # /Opt: [str] or [[export, display], ...]
        "selected": str | None,   # /V export value, or None for empty
        "combo": bool,            # set /Ff combo bit (18)
        "multiselect": bool,      # set /Ff multi-select bit (22, 1 << 21)
        "selected_values": list,  # multi-select: /V as array of exports
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

    fields_arr = pikepdf.Array()
    acroform = pdf.make_indirect(pikepdf.Dictionary({
        "/Type": pikepdf.Name("/AcroForm"),
        "/Fields": fields_arr,
        "/NeedAppearances": pikepdf.Boolean(True),
    }))
    pdf.Root["/AcroForm"] = acroform

    y = 700
    for spec in fields:
        name = spec["name"]
        options = spec["options"]
        selected = spec.get("selected")
        combo = spec.get("combo", False)
        multiselect = spec.get("multiselect", False)
        selected_values = spec.get("selected_values")

        # Choice fields are terminal field+widget merged objects: /T, /FT,
        # /Opt, /V (when set) and /Rect live on the same dictionary.
        field = pdf.make_indirect(pikepdf.Dictionary({
            "/Type": pikepdf.Name("/Annot"),
            "/Subtype": pikepdf.Name("/Widget"),
            "/T": pikepdf.String(name),
            "/FT": pikepdf.Name("/Ch"),
            "/Rect": pikepdf.Array([72, y, 300, y + 20]),
            "/Opt": pikepdf.Array(
                [pikepdf.String(o) if isinstance(o, str) else pikepdf.Array([pikepdf.String(o[0]), pikepdf.String(o[1])]) for o in options]
            ),
        }))
        ff = 0
        if combo:
            ff |= 262144   # bit 18: combo
        if multiselect:
            ff |= 2097152  # bit 22: multi-select (1 << 21; measured on
                           # pdf-lib AcroChoiceFlags.MultiSelect = flag(22 - 1))
        if ff:
            field["/Ff"] = pikepdf.Integer(ff)
        if selected_values is not None:
            # Multi-select shape: /V is an ARRAY of export strings, /I the
            # sorted option indices (§12.7.5.4 Table 247; matches pdf-lib
            # PDFAcroChoice.setValues for >1 selections).
            field["/V"] = pikepdf.Array([pikepdf.String(v) for v in selected_values])
            # /I indexes the /Opt array positionally; pair-form elements
            # ([export, display]) index by their export element.
            def opt_export(o):
                return o[0] if isinstance(o, (list, tuple)) else o
            indices = sorted(
                i for i, o in enumerate(options) if opt_export(o) in selected_values)
            field["/I"] = pikepdf.Array([pikepdf.Integer(i) for i in indices])
        elif selected is not None:
            field["/V"] = pikepdf.String(selected)

        fields_arr.append(field)
        page["/Annots"].append(field)
        y -= 30

    pdf.save(path)
    return path


def main():
    fixtures = []

    # 1. Plain string /Opt vocabulary
    fixtures.append(create_choice_pdf(
        "dropdown_strings.pdf",
        [{"name": "region", "options": ["US", "EU", "APAC"], "selected": "EU"}],
    ))

    # 2. [export, display] pair /Opt — export must win for /V comparison
    fixtures.append(create_choice_pdf(
        "dropdown_pairs.pdf",
        [{"name": "ship_method", "options": [
            ["ground", "Ground (5-7 days)"],
            ["air", "Air (1-2 days)"],
            ["freight", "Freight (quote)"],
        ], "selected": "air"}],
    ))

    # 3. Numeric export vocabulary
    fixtures.append(create_choice_pdf(
        "dropdown_numeric.pdf",
        [{"name": "tier", "options": ["0", "1", "2", "3"], "selected": "2"}],
    ))

    # 4. Hierarchical dotted names, two choice fields
    fixtures.append(create_choice_pdf(
        "choice_hierarchical.pdf",
        [
            {"name": "order.priority", "options": ["High", "Medium", "Low"], "selected": "Medium"},
            {"name": "order.warehouse", "options": ["West", "East"], "selected": "West"},
        ],
    ))

    # 5. Multiple choice fields on one page, including a combo
    fixtures.append(create_choice_pdf(
        "choice_multi_field.pdf",
        [
            {"name": "country", "options": ["US", "CA", "MX"], "selected": "CA"},
            {"name": "currency", "options": ["USD", "CAD", "EUR", "MXN"], "selected": "CAD"},
            {"name": "custom_code", "options": ["A1", "A2"], "selected": "A2", "combo": True},
        ],
    ))

    # 6. Empty selection: /Opt present, no /V
    fixtures.append(create_choice_pdf(
        "dropdown_empty_selection.pdf",
        [{"name": "selection", "options": ["Alpha", "Beta", "Gamma"], "selected": None}],
    ))

    # 7. Combo whose /V sits outside /Opt (editable-entry pattern)
    fixtures.append(create_choice_pdf(
        "combo_editable.pdf",
        [{"name": "custom_entry", "options": ["Preset1", "Preset2"], "selected": "CustomText", "combo": True}],
    ))

    # 8. Multi-select listbox: array /V of 2 exports + /I sorted indices
    fixtures.append(create_choice_pdf(
        "listbox_multi_presets.pdf",
        [{"name": "skills", "options": ["Swift", "Python", "Rust", "Go", "Ruby"],
          "multiselect": True, "selected_values": ["Swift", "Go"]}],
    ))

    # 9. Multi-select with pair-form /Opt: /V carries EXPORTS, /I indices
    fixtures.append(create_choice_pdf(
        "listbox_multi_pairs.pdf",
        [{"name": "regions_multi", "options": [
            ["na", "North America"],
            ["emea", "Europe/Middle-East/Africa"],
            ["apac", "Asia-Pacific"],
            ["latam", "Latin America"],
        ], "multiselect": True, "selected_values": ["emea", "apac", "latam"]}],
    ))

    # 10. Multi-select flag set but empty selection: /V and /I absent
    fixtures.append(create_choice_pdf(
        "listbox_multi_empty.pdf",
        [{"name": "addons", "options": ["Backup", "Encryption", "Support"],
          "multiselect": True, "selected": None}],
    ))

    # 11. Hierarchical multi-select: two dotted multi-select fields on one page
    fixtures.append(create_choice_pdf(
        "listbox_multi_hierarchical.pdf",
        [
            {"name": "project.tags", "options": ["core", "ui", "docs", "infra"],
             "multiselect": True, "selected_values": ["core", "ui"]},
            {"name": "project.reviewers", "options": ["ada", "linus", "grace"],
             "multiselect": True, "selected_values": ["grace"]},
        ],
    ))

    # 12. Single-select listbox (bit 22 CLEAR): negative control — array /V
    # writes must be refused here, singleton writes stay legal.
    fixtures.append(create_choice_pdf(
        "listbox_single_select.pdf",
        [{"name": "department", "options": ["Eng", "Design", "Ops"],
          "multiselect": False, "selected": "Eng"}],
    ))

    print(f"Generated {len(fixtures)} choice fixtures in {OUTPUT_DIR}:")
    for f in fixtures:
        print(f"  {os.path.basename(f)}")

    # Structural verification with pikepdf: /FT, /Opt length, /V.
    print("\nStructure verification:")
    for f in fixtures:
        pdf = pikepdf.open(f)
        acroform = pdf.Root["/AcroForm"]
        for field_ref in acroform["/Fields"]:
            field = field_ref
            name = str(field.get("/T", ""))
            opt = field.get("/Opt")
            opt_len = len(opt) if opt is not None else 0
            value = str(field.get("/V", "none"))
            ft = str(field.get("/FT", ""))
            ff = int(field.get("/Ff", 0))
            vi = field.get("/V")
            v_shape = ("array" if isinstance(vi, pikepdf.Array)
                       else f"string({value})" if vi is not None else "absent")
            ii = field.get("/I")
            i_shape = f"[{','.join(str(int(x)) for x in ii)}]" if ii is not None else "absent"
            print(f"  {os.path.basename(f)}: {name} ft={ft} ff={ff} opt_len={opt_len} v={v_shape} i={i_shape}")


if __name__ == "__main__":
    main()
