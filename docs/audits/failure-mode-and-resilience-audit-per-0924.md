# Failure Mode and Effects Analysis (FMEA) & Resilience Audit

**Auditor Persona:** `PER-0924 — FAILURE MODE ARCHITECT` (Meta-Reasoning & Decision Systems)  
**Secondary Persona Lenses:** `PER-0925` (Graceful Degradation Designer), `PER-PDEV-0167` (Application Security Tester)  
**Persona Source:** `desktop/personas_23rdaug26.zip` (`01 Expanded Personas/14 Meta-Reasoning & Decision Systems/PER-0924 - Failure Mode Architect.docx`)  
**Workspace:** `/Users/pranay/Projects/pdf_editor`  
**Audit Date:** 2026-08-24  
**Doctrine Baseline:** Operating Doctrine 8.0 / 6.1  

---

## 1. Persona Mandate & Core Question

> **Core Mandate:** Design and audit a system from the perspective of how it can fail, degrade, mislead, deadlock, corrupt state, create unsafe outputs, or produce silent damage before failure occurs in production.
>
> **Core Question:** *How can this system fail, how will we detect each failure, and what containment, recovery, or prevention mechanism should exist before failure occurs?*

---

## 2. Failure Mode Taxonomy & Blast-Radius Mapping

We categorize all potential failures in the PDF Editor system across four architectural layers:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      PDF EDITOR FAILURE TAXONOMY                            │
├─────────────────────────────────────────────────────────────────────────────┤
│ 1. Ingest & Stream Layer: Truncated headers, malformed XRef, decompression  │
│ 2. Geometry & Spatial Layer: Rotation skew, crop box shift, negative bounds │
│ 3. State & Mutation Layer: Race conditions, dirty state leaks, undo desync │
│ 4. Export & Integrity Layer: Silent text drop, radio button loss, overwrite │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Failure Mode and Effects Analysis (FMEA) Matrix

*Scoring scale: 1 (Lowest) to 10 (Highest / Most Catastrophic).*  
*$\text{RPN} = \text{Severity} \times \text{Likelihood} \times \text{Detectability}$ (Higher RPN indicates higher uncontained risk).*

| Failure Mode ID | Failure Mode Description | Root Cause / Trigger | Severity (1-10) | Likelihood (1-10) | Detectability (1-10, 10=undetectable) | Pre-Mitigation RPN | Containment & Recovery Design | Post-Mitigation RPN |
|---|---|---|:---:|:---:|:---:|:---:|---|:---:|
| **FM-001** | **Silent Overwrite of Source PDF** | User selects source file path as export output destination. | **10** (Catastrophic data loss) | 4 | 8 | **320** | **Hard Guard:** `standardizedFileURL == outputURL` throws `PDFEditorError.exportFailed` before writing. | **20** (Contained) |
| **FM-002** | **Partial / Corrupted Export File** | Write process interrupted or disk full during save. | **9** (File corruption) | 4 | 6 | **216** | **Staging Invariant:** Writes to `.pdf-editor-[UUID].pdf` temp file; reopens & validates before atomic filesystem rename. | **18** (Contained) |
| **FM-003** | **Radio Choice Metadata Loss in PDFKit** | macOS PDFKit `/Btn` widget choice array dropped on no-op export. | **7** (Semantic form degradation) | 8 | 9 | **504** | **Consensus Validation:** `ValidationCheckKind.nativeFields` checks choice count equality; fails export validation explicitly. | **42** (Visible Warning) |
| **FM-004** | **Silent Surrounding Text Mutation** | Text reflow or engine rewrite changes unedited body text. | **10** (Legal / document invalidation) | 3 | 9 | **270** | **Text Invariance Oracle:** `validate()` runs full page text extraction diffing; flags text delta as validation failure. | **30** (Contained) |
| **FM-005** | **Memory Exhaustion (Zip Bomb / Massive PDF)** | Malicious or huge PDF (>500MB, >10,000 pages) allocated in RAM. | **9** (Process crash / DoS) | 3 | 4 | **108** | **Safety Limit Pre-Filter:** `Limits(maximumInputBytes: 250MB, maximumPageCount: 2000)` checked pre-parse. | **18** (Contained) |
| **FM-006** | **Coordinate Desynchronization on Rotated Pages** | Page rotated $90^\circ/270^\circ$; overlays placed in raw rather than visual space. | **8** (Misaligned overlay text) | 5 | 7 | **280** | **Geometric Determinism:** `PDFCoordinateSpace` binds `rotationDegrees` & `pageBox`; `PDFVectorStreamParser` applies CTM matrix. | **32** (Contained) |
| **FM-007** | **Malformed / Truncated PDF Crash** | Input truncated mid-stream; missing `%EOF` marker. | **8** (Unhandled app crash) | 4 | 5 | **160** | **Defensive Ingest:** `PDFDocument(data:)` check throws localized `.cannotOpen(path)` with zero process termination. | **16** (Contained) |
| **FM-008** | **Negative / Zero-Dimension Overlay Bounds** | User or detector produces inverted rectangle ($w \le 0$ or $h \le 0$). | **6** (Rendering glitch) | 4 | 4 | **96** | **Standardization Gate:** `CGRect.standardized` + min dimension clamps ($w \ge 1, h \ge 1$). | **12** (Contained) |
| **FM-009** | **Malicious Remote URL Injection in Links** | PDF contains `javascript:`, `file:`, or shell URL action annotations. | **9** (Arbitrary code execution / exfiltration) | 3 | 8 | **216** | **Strict Scheme Whitelist:** `isSafeExternalLink()` permits only `http` / `https`; blocks all remote actions. | **18** (Contained) |
| **FM-010** | **Undo State Desynchronization** | Undoing edits causes document to diverge from operation log. | **7** (State corruption) | 4 | 6 | **168** | **Pure Event Replay:** Undo deterministically clears last op and replays remaining ops from immutable source bytes. | **14** (Contained) |
| **FM-011** | **External CDN Dependency Outage in Web Lane** | Web companion fails to open when offline / air-gapped. | **8** (Availability failure) | 6 | 2 | **96** | **Zero-CDN Bundling:** Strict CSP + local vendor scripts in `web/vendor/`. | **8** (Contained) |
| **FM-012** | **OCR Coordinate Hallucination on Skewed Scans** | Vision OCR detects rotated text block with misleading box. | **6** (Misplaced suggestions) | 5 | 5 | **150** | **Epistemic Labeling:** Tagged as `CandidateKind.ocrRegion` with confidence $< 0.5$; requires explicit user confirmation. | **30** (Contained) |

---

## 4. Fault Tree Analysis (FTA) for Catastrophic Hazards

### Hazard 1: Source Document Corruption
```
                           [Source Document Corrupted]
                                       │
                    ┌──────────────────┴──────────────────┐
                    ▼                                     ▼
        [In-Place Overwrite]                  [Temporary File Collision]
                    │                                     │
         (Direct Save to Source)               (Predictable Temp Name)
                    │                                     │
           [MITIGATED: Check]                    [MITIGATED: UUID Temp]
      url != outputURL standardized         .pdf-editor-[UUID].pdf isolated
```

### Hazard 2: Silent Alteration of Unedited Text
```
                     [Unedited Document Text Changed]
                                     │
                  ┌──────────────────┴──────────────────┐
                  ▼                                     ▼
       [Engine Content Rewrite]               [Encoding / Font Swap]
                  │                                     │
       (Engine Modifies Stream)              (Glyph Map Desynchronization)
                  │                                     │
         [MITIGATED: Text Diff]                [MITIGATED: Extraction Check]
       validate() compares before/after     PDFTextStripper / Poppler match
```

---

## 5. Resilience & Fault-Injection Test Matrix

We define five automated resilience test categories implemented in [`Tests/PDFEditorCoreTests/PDFEditorCoreTests.swift`](../../Tests/PDFEditorCoreTests/PDFEditorCoreTests.swift):

```
1. Truncated & Corrupted Stream Injection -> Must throw .cannotOpen without crashing.
2. Boundary Safety Limits Injection     -> Must reject >250MB / >2000 pages pre-parse.
3. Rotated Page Coordinate Stress Test   -> Must round-trip 90°, 180°, 270° without geometry shift.
4. Overwrite Collision Defense           -> Must reject exporting over source URL.
5. Inverted / Zero Geometry Clamping     -> Must standardize bounds to positive dimensions.
```

---

## 6. Failure Mode Architect Sign-off

- **FMEA Status:** All 12 identified failure modes have active prevention and containment mechanisms.
- **Unresolved High Risks:** PDFKit external AcroForm radio button serialization remains a known provider bug, contained via explicit validation warnings.
- **Conclusion:** The PDF Editor architecture meets high-integrity fault tolerance requirements under Operating Doctrine 8.0/6.1.

*Report compiled by Failure Mode Architect (`PER-0924`).*
