#!/usr/bin/env python3
"""Marker wrapper for the benchmark harness.

Usage: python3 marker_wrapper.py <pdf_path>
Output: Markdown text to stdout.

Requires: pip install marker-pdf (marker_single CLI).

Marker CLI note (v2.x): `marker_single FPATH` writes Markdown to
`<output_dir>/<basename>/<basename>.md`; the output directory is passed via
`--output_dir`, not a second positional argument (that signature was removed).
This wrapper resolves the produced .md file and prints its text.
"""
import sys
import os
import glob
import shutil
import subprocess
import tempfile
from pathlib import Path


def main():
    if len(sys.argv) < 2:
        print("Usage: marker_wrapper.py <pdf_path>", file=sys.stderr)
        sys.exit(1)

    pdf_path = sys.argv[1]
    if not os.path.exists(pdf_path):
        print(f"Error: file not found: {pdf_path}", file=sys.stderr)
        sys.exit(1)

    try:
        marker_bin = os.path.join(
            os.path.dirname(os.path.abspath(__file__)),
            "datasets", ".venv", "bin", "marker_single",
        )
        if not os.path.exists(marker_bin):
            marker_bin = "marker_single"  # fallback to PATH

        out_dir = tempfile.mkdtemp(prefix="marker-bench-")
        result = subprocess.run(
            [marker_bin, pdf_path, "--output_dir", out_dir],
            capture_output=True, text=True, timeout=300,
        )
        if result.returncode != 0:
            # marker_single writes logs to stdout; surface the tail as the error.
            tail = "\n".join(result.stdout.strip().splitlines()[-5:])
            print(f"Marker error (rc={result.returncode}): {tail}", file=sys.stderr)
            shutil.rmtree(out_dir, ignore_errors=True)
            sys.exit(1)

        # marker_single writes <out_dir>/<basename>/<basename>.md
        md_files = glob.glob(os.path.join(out_dir, "**", "*.md"), recursive=True)
        if not md_files:
            print("Marker error: no .md output produced", file=sys.stderr)
            shutil.rmtree(out_dir, ignore_errors=True)
            sys.exit(1)

        text = Path(md_files[0]).read_text().strip()
        shutil.rmtree(out_dir, ignore_errors=True)
        print(text)
    except subprocess.TimeoutExpired:
        print("Marker error: timed out after 300s", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Marker error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()