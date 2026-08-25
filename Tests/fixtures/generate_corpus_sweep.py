#!/usr/bin/env python3
# generate_corpus_sweep.py
#
# RG-060/063/064/065/066/070/071 synthetic fixture corpus generator.
# Deterministic: no timestamps, no randomness. Each fixture carries explicit
# expected structural outcomes recorded in the manifest by the verifying test.
#
# Usage: python3 generate_corpus_sweep.py <outdir> <base_fixture_pdf>

import os
import sys

import pikepdf

OUT = sys.argv[1]
BASE = sys.argv[2]
os.makedirs(OUT, exist_ok=True)


def path(name):
    return os.path.join(OUT, name)


def text_page(p, width, height, lines, rotate=0, crop=None, columns=None):
    page = p.add_blank_page(page_size=(width, height))
    font = pikepdf.Dictionary(
        Type=pikepdf.Name("/Font"),
        Subtype=pikepdf.Name("/Type1"),
        BaseFont=pikepdf.Name("/Helvetica"),
    )
    page.Resources = pikepdf.Dictionary(Font=pikepdf.Dictionary(F1=p.make_indirect(font)))
    if rotate:
        page.Rotate = rotate
    if crop is not None:
        page.CropBox = pikepdf.Array(crop)

    def column_stream(x, entries):
        parts = ["BT", f"/F1 11 Tf", f"1 0 0 1 {x} {height - 72} Tm", "14 TL"]
        for line in entries:
            safe = line.replace("\\", r"\\").replace("(", r"\(").replace(")", r"\)")
            parts.append(f"({safe}) Tj T*")
        parts.append("ET")
        return "\n".join(parts).encode("latin-1", "replace")

    streams = []
    if columns is not None:
        for x, entries in columns:
            streams.append(column_stream(x, entries))
    else:
        streams.append(column_stream(72, lines))
    for s in streams:
        page.contents_add(pikepdf.Stream(p, s))
    return page


# --- RG-060: plain text (multi-page, headings, paragraphs, Latin-1 accents) --
p = pikepdf.open(BASE)
text_page(
    p,
    612,
    792,
    [
        "Heading One",
        "",
        "First paragraph of body copy spanning several words and lines.",
        "The second line continues the paragraph naturally.",
        "",
        "Cafe resume naivete - accented Latin-1 words follow.",
        "Resume with acute accent and cedilla appear in this corpus.",
    ],
)
text_page(
    p,
    612,
    792,
    ["Heading Two", "", "Second page paragraph. Multi-page flow continues here.", "Final line of the fixture."],
)
p.save(path("plain-text.pdf"))
p.close()

# --- RG-063: multi-column ----------------------------------------------------
p = pikepdf.open(BASE)
text_page(
    p,
    792,
    612,
    None,
    columns=[
        (
            54,
            [
                "LEFT COLUMN HEADING",
                "Left column body line one.",
                "Left column body line two.",
                "Left column footnote marker.",
            ],
        ),
        (
            440,
            [
                "RIGHT COLUMN HEADING",
                "Right column body line one.",
                "Right sidebar note follows.",
                "Sidebar continues here.",
            ],
        ),
    ],
)
p.save(path("multi-column.pdf"))
p.close()

# --- RG-064: geometry (unusual size, rotation, crop box) ---------------------
p = pikepdf.open(BASE)
text_page(p, 200, 2000, ["Tall narrow page."])
text_page(p, 612, 792, ["Rotated landscape content."], rotate=90)
text_page(p, 612, 792, ["Cropped region text."], crop=[36, 36, 400, 700])
p.save(path("geometry.pdf"))
p.close()

# --- RG-065: navigation (outlines, internal/external/missing links) ----------
p = pikepdf.open(BASE)
page1 = text_page(p, 612, 792, ["Navigation target one."])
page2 = text_page(p, 612, 792, ["Navigation target two."])

items = []
outlines = pikepdf.Dictionary(Type=pikepdf.Name("/Outlines"), Count=len(items) or 0)
root_outlines = p.make_indirect(outlines)
p.Root.Outlines = root_outlines
refs = []
for title, pageref in [("Target One", page1.obj), ("Target Two", page2.obj)]:
    d = pikepdf.Dictionary(
        Title=pikepdf.String(title),
        Dest=pikepdf.Array([pageref, pikepdf.Name("/Fit")]),
    )
    refs.append(p.make_indirect(d))
for i, d in enumerate(refs):
    d.Parent = root_outlines
    if i > 0:
        d.Prev = refs[i - 1]
    if i < len(refs) - 1:
        d.Next = refs[i + 1]
outlines.First = refs[0]
outlines.Last = refs[-1]
outlines.Count = len(refs)

annots = pikepdf.Array(
    [
        p.make_indirect(
            pikepdf.Dictionary(
                Subtype=pikepdf.Name("/Link"),
                Rect=pikepdf.Array([50, 700, 300, 730]),
                Border=pikepdf.Array([0, 0, 0]),
                A=pikepdf.Dictionary(S=pikepdf.Name("/URI"), URI=pikepdf.String("https://example.test/")),
            )
        ),
        p.make_indirect(
            pikepdf.Dictionary(
                Subtype=pikepdf.Name("/Link"),
                Rect=pikepdf.Array([50, 650, 300, 680]),
                Border=pikepdf.Array([0, 0, 0]),
                Dest=pikepdf.Array([page2.obj, pikepdf.Name("/Fit")]),
            )
        ),
        p.make_indirect(
            pikepdf.Dictionary(
                Subtype=pikepdf.Name("/Link"),
                Rect=pikepdf.Array([50, 600, 300, 630]),
                Border=pikepdf.Array([0, 0, 0]),
                A=pikepdf.Dictionary(S=pikepdf.Name("/GoTo"), D=pikepdf.Name("/NoSuchNamedDest")),
            )
        ),
    ]
)
page1.Annots = annots
p.save(path("navigation.pdf"))
p.close()

# --- RG-066: metadata variants ----------------------------------------------
def save_with_docinfo(name, mutate=None):
    q = pikepdf.open(BASE)
    if mutate is not None:
        mutate(q)
    q.save(path(name))
    q.close()


save_with_docinfo(
    "metadata-complete.pdf",
    lambda q: (
        q.docinfo.__setitem__("/Title", "Complete Metadata Fixture"),
        q.docinfo.__setitem__("/Author", "Corpus Generator"),
        q.docinfo.__setitem__("/Subject", "RG-066"),
        q.docinfo.__setitem__("/Creator", "generate_corpus_sweep.py"),
        q.docinfo.__setitem__("/Producer", "pikepdf"),
        q.docinfo.__setitem__("/Keywords", "corpus, metadata"),
    ),
)
save_with_docinfo(
    "metadata-absent.pdf",
    lambda q: q.trailer.__delitem__("/Info") if "/Info" in q.trailer else None,
)
save_with_docinfo(
    "metadata-unicode.pdf",
    lambda q: q.docinfo.__setitem__("/Title", "Título — Ünïcødé ✓ 日本語"),
)
save_with_docinfo(
    "metadata-custom.pdf",
    lambda q: (
        q.docinfo.__setitem__("/CustomKey", "CustomValue"),
        q.docinfo.__setitem__("/ReviewState", "bounded"),
    ),
)

# Malformed docinfo: non-string scalar value where a text string is expected.
q = pikepdf.open(BASE)
q.docinfo["/Title"] = "Malformed Fixture"
q.docinfo["/WeirdScalar"] = 42
q.save(path("metadata-malformed.pdf"))
q.close()

# --- RG-070: signed structures (structure-level; NOT cryptographically valid) -
def write_signed(name, sig_specs):
    q = pikepdf.open(BASE)
    fields = []
    for idx, contents_len in enumerate(sig_specs):
        sigdict = q.make_indirect(
            pikepdf.Dictionary(
                ByteRange=pikepdf.Array([0, 8, 64, 8]),
                Contents=pikepdf.String("/" + "0" * contents_len),
                Filter=pikepdf.Name("/Adobe.PPKLite"),
            )
        )
        fields.append(
            q.make_indirect(
                pikepdf.Dictionary(
                    FT=pikepdf.Name("/Sig"),
                    T=pikepdf.String(f"Signature{idx + 1}"),
                    V=sigdict,
                )
            )
        )
    af = q.make_indirect(
        pikepdf.Dictionary(SigFlags=int(1), Fields=pikepdf.Array(fields))
    )
    q.Root.AcroForm = af
    q.save(path(name))
    q.close()


write_signed("signed-valid-structure.pdf", [40])
write_signed("signed-invalid-structure.pdf", [17])  # Contents length inconsistent with /ByteRange convention
write_signed("signed-multiple.pdf", [40, 40])

# --- RG-071: XFA variants ----------------------------------------------------
XDP_STATIC = (
    '<?xdp version="2.6"?><?xfa generator="CorpusSweep"?>'
    '<template xmlns="http://www.xfa.org/schema/xfa-template/2.6/"/>'
)
XDP_DYNAMIC = (
    '<?xdp version="2.6"?><?xfa generator="CorpusSweep"?>'
    '<template xmlns="http://www.xfa.org/schema/xfa-template/2.6/"/>'
    '<config xmlns="http://www.xfa.org/schema/xci/2.6/"><present><output/></present></config>'
)


def write_xfa(name, xdp, with_acroform_fields):
    q = pikepdf.open(BASE)
    stream = q.make_indirect(pikepdf.Stream(q, xdp.encode()))
    af = q.make_indirect(pikepdf.Dictionary(XFA=q.make_indirect(stream)))
    if with_acroform_fields:
        field = q.make_indirect(
            pikepdf.Dictionary(
                FT=pikepdf.Name("/Tx"), T=pikepdf.String("hybridField"), V=pikepdf.String("")
            )
        )
        af.Fields = pikepdf.Array([field])
    q.Root.AcroForm = af
    q.save(path(name))
    q.close()


write_xfa("xfa-static.pdf", XDP_STATIC, False)
write_xfa("xfa-dynamic.pdf", XDP_DYNAMIC, False)
write_xfa("xfa-hybrid.pdf", XDP_STATIC, True)

print("generated:", ", ".join(sorted(os.listdir(OUT))))
