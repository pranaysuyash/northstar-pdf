#!/usr/bin/env python3
"""Generate diverse-layout PDF fixtures using raw PDF with correct xref."""

from pathlib import Path
import struct, io

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "benchmark/results/diverse-layout-corpus"
OUTPUT.mkdir(parents=True, exist_ok=True)


def make_pdf(pages_content, width, height, filename):
    """Build a valid PDF with proper xref offsets."""
    
    objects = []  # list of (num, data_or_stream)
    
    # Object 1: Catalog
    objects.append((1, b"<< /Type /Catalog /Pages 2 0 R >>"))
    
    # Object 2: Pages — placeholder, fill kids later
    objects.append((2, None))  # will fill
    
    # Object 3: Font
    objects.append((3, b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"))
    
    # For each page: content stream + page object
    page_nums = []
    for i, content in enumerate(pages_content):
        stream_num = 4 + i * 2
        page_num = 5 + i * 2
        page_nums.append(page_num)
        objects.append((stream_num, ("stream", content.encode("latin-1", errors="replace"))))
        objects.append((page_num, (
            f"<< /Type /Page /Parent 2 0 R "
            f"/MediaBox [0 0 {width} {height}] "
            f"/Contents {stream_num} 0 R "
            f"/Resources << /Font << /F1 3 0 R >> >> >>"
        ).encode()))
    
    # Fill Pages object
    kids = " ".join(f"{n} 0 R" for n in page_nums)
    objects[1] = (2, f"<< /Type /Pages /Count {len(pages_content)} /Kids [{kids}] >>".encode())
    
    # Serialize with correct xref
    pdf = bytearray()
    pdf.extend(b"%PDF-1.4\n")
    pdf.extend(b"%\xc3\xa2\xc3\xa3\xcf\xd3\n")  # binary marker
    
    xref_offsets = {}
    for num, data in objects:
        xref_offsets[num] = len(pdf)
        pdf.extend(f"{num} 0 obj\n".encode())
        if isinstance(data, tuple) and data[0] == "stream":
            stream_data = data[1]
            pdf.extend(f"<< /Length {len(stream_data)} >>\nstream\n".encode())
            pdf.extend(stream_data)
            pdf.extend(b"\nendstream\n")
        elif data is None:
            pdf.extend(b"ERROR\n")
        else:
            pdf.extend(data)
            pdf.extend(b"\n")
        pdf.extend(b"endobj\n")
    
    xref_offset = len(pdf)
    num_objs = max(xref_offsets.keys()) + 1
    pdf.extend(b"xref\n")
    pdf.extend(f"0 {num_objs}\n".encode())
    pdf.extend(b"0000000000 65535 f \n")
    for i in range(1, num_objs):
        offset = xref_offsets.get(i, 0)
        pdf.extend(f"{offset:010d} 00000 n \n".encode())
    
    pdf.extend(b"trailer\n")
    pdf.extend(f"<< /Size {num_objs} /Root 1 0 R >>\n".encode())
    pdf.extend(b"startxref\n")
    pdf.extend(f"{xref_offset}\n".encode())
    pdf.extend(b"%%EOF\n")
    
    out_path = OUTPUT / filename
    out_path.write_bytes(bytes(pdf))
    print(f"  {filename}: {width}x{height}, {len(pages_content)}p, {len(pdf)}b")


def gen_single_column():
    lines = []
    y = 720
    for i in range(20):
        lines.append(f"BT /F1 10 Tf 72 {y} Td (Line {i+1}: Single-column text paragraph with varied content for diversity.) Tj ET")
        y -= 30
    return "\n".join(lines)


def gen_two_column():
    lines = ["q"]
    y = 720
    for i in range(15):
        lines.append(f"BT /F1 9 Tf 72 {y} Td (Left col {i+1}: two-column academic text sample.) Tj ET")
        y -= 25
    y = 720
    for i in range(15):
        lines.append(f"BT /F1 9 Tf 320 {y} Td (Right col {i+1}: two-column academic text sample.) Tj ET")
        y -= 25
    lines.append("0.8 0.8 0.8 RG 0.5 w 310 700 m 310 340 l S")
    lines.append("Q")
    return "\n".join(lines)


def gen_three_column():
    lines = ["q"]
    for col in range(3):
        x = 72 + col * 180
        y = 720
        for i in range(12):
            lines.append(f"BT /F1 8 Tf {x} {y} Td (Col{col+1} L{i+1}: three-col newspaper text.) Tj ET")
            y -= 22
    lines.append("Q")
    return "\n".join(lines)


def gen_graphics_heavy():
    lines = ["q"]
    for row in range(8):
        for col in range(6):
            x = 50 + col * 90
            y = 50 + row * 90
            if (row + col) % 3 == 0:
                lines.append(f"0.9 0.9 0.9 rg {x} {y} 80 80 re f")
            elif (row + col) % 3 == 1:
                lines.append(f"0.5 0.5 0.5 RG 2 w {x} {y} 80 80 re S")
            else:
                lines.append(f"0 0 0 RG 1 w {x} {y} m {x+80} {y+80} l S")
                lines.append(f"{x+80} {y} m {x} {y+80} l S")
    lines.append("Q")
    return "\n".join(lines)


def gen_form_fields():
    lines = ["q"]
    fields = [("Name:", 700), ("Date:", 650), ("Address:", 600),
              ("City:", 550), ("State:", 500), ("Zip:", 450),
              ("Phone:", 400), ("Email:", 350)]
    for label, y in fields:
        lines.append(f"BT /F1 11 Tf 72 {y} Td ({label}) Tj ET")
        lines.append(f"0.7 0.7 0.7 RG 1 w 180 {y-10} 250 28 re S")
    lines.append("Q")
    return "\n".join(lines)


def gen_table_grid():
    lines = ["q", "0 0 0 RG 0.8 w"]
    x0, y0 = 50, 750
    cw, rh = 100, 50
    cols, rows = 5, 10
    for r in range(rows + 1):
        y = y0 - r * rh
        lines.append(f"{x0} {y} m {x0 + cols * cw} {y} l S")
    for c in range(cols + 1):
        x = x0 + c * cw
        lines.append(f"{x} {y0} m {x} {y0 - rows * rh} l S")
    for r in range(rows):
        for c in range(cols):
            x = x0 + c * cw + 5
            y = y0 - r * rh - 30
            lines.append(f"BT /F1 8 Tf {x} {y} Td (R{r+1}C{c+1}) Tj ET")
    lines.append("Q")
    return "\n".join(lines)


def gen_scanned_sim():
    lines = ["q"]
    lines.append("0.95 0.95 0.95 rg 0 0 612 792 re f")
    y = 700
    for i in range(30):
        w = 350 + (i * 7) % 100
        lines.append(f"0.2 0.2 0.2 rg 80 {y} {w} 12 re f")
        y -= 22
    lines.append("0.5 0.5 0.5 rg 200 100 200 150 re f")
    lines.append("Q")
    return "\n".join(lines)


def gen_header_footer():
    lines = ["q"]
    lines.append("0.8 0.8 0.8 rg 0 760 612 32 re f")
    lines.append("BT /F1 14 Tf 72 770 Td (DOCUMENT TITLE - Header Region) Tj ET")
    lines.append("0.8 0.8 0.8 rg 0 0 612 32 re f")
    lines.append("BT /F1 8 Tf 72 10 Td (Page 1 - Footer Region) Tj ET")
    y = 720
    for i in range(20):
        lines.append(f"BT /F1 10 Tf 72 {y} Td (Content line {i+1} with margins for readability.) Tj ET")
        y -= 30
    lines.append("0.9 0.9 0.9 rg 0 40 36 712 re f")
    lines.append("0.9 0.9 0.9 rg 576 40 36 712 re f")
    lines.append("Q")
    return "\n".join(lines)


def gen_landscape_chart():
    lines = ["q"]
    lines.append("0 0 0 RG 1.5 w 80 80 m 740 80 l S")
    lines.append("80 80 m 80 550 l S")
    bars = [150, 280, 420, 350, 500, 200, 380, 450, 300, 250]
    for i, h in enumerate(bars):
        x = 90 + i * 60
        lines.append(f"0.{30+i*5} 0.{50+i*3} 0.{80-i*4} rg {x} 80 50 {h} re f")
        lines.append(f"0 0 0 RG 0.5 w {x} 80 50 {h} re S")
    lines.append("BT /F1 9 Tf 80 65 Td (Q1 Q2 Q3 Q4 Q5 Q6 Q7 Q8 Q9 Q10) Tj ET")
    lines.append("Q")
    return "\n".join(lines)


def gen_sparse():
    lines = ["q"]
    lines.append("BT /F1 24 Tf 200 400 Td (TITLE) Tj ET")
    lines.append("BT /F1 12 Tf 200 360 Td (A single line of text.) Tj ET")
    lines.append("Q")
    return "\n".join(lines)


def gen_dense_grid():
    lines = ["q", "0 0 0 RG 0.3 w"]
    for x in range(0, 612, 20):
        lines.append(f"{x} 0 m {x} 792 l S")
    for y in range(0, 792, 20):
        lines.append(f"0 {y} m 612 {y} l S")
    for r in range(0, 39, 2):
        for c in range(0, 30, 3):
            lines.append(f"0.8 0.8 0.8 rg {c*20} {r*20} 20 20 re f")
    lines.append("Q")
    return "\n".join(lines)


def gen_single_column_variant():
    lines = []
    y = 720
    for i in range(20):
        lines.append(f"BT /F1 10 Tf 72 {y} Td (Line {i+1}: Variant text with different content but identical layout.) Tj ET")
        y -= 30
    return "\n".join(lines)


def main():
    print("Generating diverse-layout fixtures...")
    make_pdf([gen_single_column()], 612, 792, "diverse-single-column.pdf")
    make_pdf([gen_two_column()], 595, 842, "diverse-two-column.pdf")
    make_pdf([gen_three_column()], 612, 792, "diverse-three-column.pdf")
    make_pdf([gen_graphics_heavy()], 612, 792, "diverse-graphics-heavy.pdf")
    make_pdf([gen_form_fields()], 612, 792, "diverse-form-layout.pdf")
    make_pdf([gen_table_grid()], 612, 792, "diverse-table-grid.pdf")
    make_pdf([gen_scanned_sim()], 612, 792, "diverse-scanned-sim.pdf")
    make_pdf([gen_header_footer()], 612, 792, "diverse-header-footer.pdf")
    make_pdf([gen_landscape_chart()], 792, 612, "diverse-landscape-chart.pdf")
    make_pdf([gen_sparse()], 612, 792, "diverse-sparse-text.pdf")
    make_pdf([gen_dense_grid()], 612, 792, "diverse-dense-grid.pdf")
    make_pdf([gen_single_column_variant()], 612, 792, "diverse-single-column-variant.pdf")
    make_pdf([gen_two_column()], 500, 500, "diverse-two-column-square.pdf")
    make_pdf([gen_single_column(), gen_two_column(), gen_table_grid()], 612, 792, "diverse-mixed-3page.pdf")
    print(f"\nDone. {len(list(OUTPUT.glob('*.pdf')))} fixtures")


if __name__ == "__main__":
    main()
