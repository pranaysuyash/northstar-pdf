#!/usr/bin/env python3
"""Marker wrapper for the benchmark harness.

Usage: python3 marker_wrapper.py <pdf_path>
Output: Markdown text to stdout.

Requires: pip install marker-pdf
"""
import sys
import os
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
        # Use marker_single CLI — more stable than the Python API across versions
        import subprocess
        marker_bin = os.path.join(
            os.path.dirname(os.path.abspath(__file__)),
            "datasets", ".venv", "bin", "marker_single"
        )
        if not os.path.exists(marker_bin):
            marker_bin = "marker_single"  # fallback to PATH
        
        result = subprocess.run(
            [marker_bin, pdf_path, "/tmp/marker-bench-out"],
            capture_output=True, text=True, timeout=120
        )
        
        # marker_single writes a .md file next to the PDF or in the output dir
        md_files = list(Path("/tmp/marker-bench-out").glob("*.md")) if Path("/tmp/marker-bench-out").exists() else []
        if not md_files:
            # Try the directory where the PDF is
            md_files = list(Path(pdf_path).parent.glob(Path(pdf_path).stem + ".md"))
        
        if md_files:
            text = md_files[0].read_text().strip()
        else:
            # Fallback: parse stdout
            text = result.stdout.strip()
        
        # Cleanup
        import shutil
        shutil.rmtree("/tmp/marker-bench-out", ignore_errors=True)
        
        print(text)
    except Exception as e:
        print(f"Marker error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
