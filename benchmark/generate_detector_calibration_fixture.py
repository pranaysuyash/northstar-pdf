#!/usr/bin/env python3
"""Create the deterministic synthetic geometry fixture used by detector calibration.

The fixture intentionally uses only standard Helvetica and simple PDF path
operators. It is not production content and contains no user data.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "benchmark/results/detector-calibration/detector-calibration.pdf"


def stream(page: int) -> bytes:
    commands = [
        "q",
        "0 0 0 RG 1 w",
    ]
    if page == 0:
        commands += [
            "BT /F1 12 Tf 72 720 Td (Applicant Name:) Tj ET",
            "180 700 300 32 re S",
            "BT /F1 12 Tf 72 630 Td (Agree to terms:) Tj ET",
            "72 600 16 16 re S",
            "BT /F1 12 Tf 72 540 Td (Date:) Tj ET",
            "180 520 m 320 520 l S",
            "BT /F1 12 Tf 72 450 Td (Address:) Tj ET",
        ]
    else:
        commands += [
            "BT /F1 12 Tf 72 720 Td (Section:) Tj ET",
            "180 700 300 32 re S",
            "72 600 16 16 re S",
            "180 520 m 320 520 l S",
            "BT /F1 12 Tf 72 440 Td (Note:) Tj ET",
            "180 420 260 30 re S",
            "BT /F1 12 Tf 72 350 Td (Section:) Tj ET",
        ]
    commands.append("Q")
    return ("\n".join(commands) + "\n").encode("ascii")


def make_pdf() -> bytes:
    objects: dict[int, bytes] = {}
    objects[1] = b"<< /Type /Catalog /Pages 2 0 R >>"
    objects[2] = b"<< /Type /Pages /Kids [3 0 R 6 0 R] /Count 2 >>"
    objects[3] = (
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] "
        b"/Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>"
    )
    objects[4] = b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"
    objects[5] = b""
    objects[6] = (
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] "
        b"/Resources << /Font << /F1 4 0 R >> >> /Contents 7 0 R >>"
    )
    objects[7] = b""
    objects[5] = stream(0)
    objects[7] = stream(1)

    output = bytearray(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
    offsets = [0] * 8
    for number in range(1, 8):
        offsets[number] = len(output)
        body = objects[number]
        if number in (5, 7):
            output.extend(f"{number} 0 obj\n<< /Length {len(body)} >>\nstream\n".encode())
            output.extend(body)
            output.extend(b"endstream\nendobj\n")
        else:
            output.extend(f"{number} 0 obj\n".encode())
            output.extend(body)
            output.extend(b"\nendobj\n")

    xref_offset = len(output)
    output.extend(b"xref\n0 8\n0000000000 65535 f \n")
    for number in range(1, 8):
        output.extend(f"{offsets[number]:010d} 00000 n \n".encode())
    output.extend(
        b"trailer\n<< /Size 8 /Root 1 0 R >>\n"
        + f"startxref\n{xref_offset}\n%%EOF\n".encode()
    )
    return bytes(output)


OUTPUT.parent.mkdir(parents=True, exist_ok=True)
OUTPUT.write_bytes(make_pdf())
print(OUTPUT)
