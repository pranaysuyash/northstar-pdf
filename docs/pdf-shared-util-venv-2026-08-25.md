# Shared Local PDF Utility Environment

**Created:** 2026-08-25
**Location:** `/Users/pranay/.workbuddy-ai/binaries/python/envs/pdf-utils`
**Purpose:** Reusable permissive PDF parsing/rendering/extraction utility environment for Projects experiments and future provider adapters.

## Installed packages

- `pypdfium2==5.11.0` — PDFium bindings; permissive package licensing signal
- `pypdf==6.14.2` — BSD-3-Clause
- `pdfplumber==0.11.10` — MIT
- `pdfminer.six==20260107` — MIT
- `pikepdf==10.0.2` — MPL-2.0
- `reportlab==4.4.5` — BSD-3-Clause

Transitive packages include Pillow, lxml, cryptography, cffi, charset-normalizer, packaging, Deprecated, wrapt, and pycparser. Their exact metadata should be included in a future distribution SBOM; this environment is an exploration utility, not an approved application bundle.

## Verification

The managed Python 3.13 runtime created the environment and installed all six requested packages. A second command imported `pypdfium2`, `pypdf`, `pdfplumber`, `pdfminer`, `pikepdf`, and `reportlab`, and read these versions successfully:

```text
pypdfium2 5.11.0
pypdf 6.14.2
pdfplumber 0.11.10
pdfminer.six 20260107
pikepdf 10.0.2
reportlab 4.4.5
imports_ok
```

## Usage

```bash
ENV=/Users/pranay/.workbuddy-ai/binaries/python/envs/pdf-utils
"$ENV/bin/python3" your_script.py
```

This environment is intentionally outside any one project's `.venv`; it does not replace project-specific lockfiles or authorize copying the environment into a shipped product. It is a local bake-off and shared utility surface.

## Admission boundary

The environment excludes PyMuPDF/MuPDF, OCRmyPDF, Surya, DocTR, PaddleOCR, and other restricted/heavy providers. Adding a provider to this environment does not clear its license, security, model, privacy, or corpus gates.
