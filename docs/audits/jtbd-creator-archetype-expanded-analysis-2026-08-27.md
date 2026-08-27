# Creator Archetype — Expanded 22-Dimension Analysis

**Date:** 2026-08-27
**Framework:** Expanded Analytical Framework (22 dimensions)
**Jobs:** CREATE (J8), TRANSFORM (J9), COMMIT (J7)
**Status:** First-principles, long-term, doctrine-aligned analysis
**Extends:** `personas-jobs-expanded-model-2026-08-26.md` §2-§3

---

## Purpose

The Creator archetype is where the bigger product opportunity lies. While the Reader archetype is about consuming content, the Creator archetype is about PRODUCING, MODIFYING, and BINDING documents. This is where the app transitions from a viewer to an authoring tool.

---

## 1. CREATE (J8) — "I want to produce a document"

### 1.1 WHO

| Persona | Core Need | Expertise | Frequency | Our Support |
|---|---|---|---|---|
| Author | Write a new document | Domain expert | Daily | ❌ No document creation |
| Form designer | Create fillable forms | PDF expert | Weekly | ⚠️ AcroForm exists |
| Template creator | Build reusable templates | PDF expert | Monthly | ⚠️ Template store exists |
| Teacher | Create assignments/tests | Education | Weekly | ❌ No document creation |
| Business analyst | Create reports | Business | Weekly | ❌ No document creation |
| Developer | Generate PDFs programmmaticall | Technical | Weekly | ⚠️ PDFBatchProcessor |

### 1.2 WHAT

| Object | Creation challenge | Our capability | Gap |
|---|---|---|---|
| New PDF from scratch | Empty canvas + content | ❌ No creation UI | LARGE |
| Form template | Fillable fields + layout | ⚠️ AcroForm writer | Medium |
| Report template | Headers, footers, sections | ❌ No template editor | Large |
| Invoice | Structured layout + data | ❌ No invoice creation | Large |
| Certificate | Formal layout + signature | ❌ No certificate creation | Large |
| Merge existing PDFs | Combine documents | ✅ BatchMergeSheet | Small |
| Split PDF | Extract pages | ⚠️ PdfCpuBatchProcessor | Small |
| Add watermark | Overlay text/image | ⚠️ PdfCpuBatchProcessor | Small |

### 1.3 WHEN

| Phase | What happens | Our support |
|---|---|---|
| 1. Content authoring | Write/place content | ❌ No authoring |
| 2. Layout design | Arrange elements | ❌ No layout tools |
| 3. Style application | Apply formatting | ❌ No styling |
| 4. Review | Check output | ⚠️ Diff view exists |
| 5. Finalize | Export as PDF | ✅ Export exists |
| 6. Distribute | Share with others | ✅ File export |

### 1.4 WHERE

| Context | Creation need | Our support |
|---|---|---|
| Desk (primary) | Full authoring | ❌ No creation tools |
| Meeting | Quick document | ❌ No quick-create |
| Mobile | Draft on-the-go | ❌ No mobile app |

### 1.5 WHY

| Why create | Depth | Our support |
|---|---|---|
| Produce a deliverable | Core | ❌ No creation |
| Build a template | Reusable | ⚠️ Template store |
| Generate a report | Recurring | ❌ No creation |
| Design a form | Interactive | ⚠️ AcroForm |
| Create a certificate | Formal | ❌ No creation |

### 1.6 HOW

| Method | Description | Our support |
|---|---|---|
| Blank canvas | Start from scratch | ❌ Not implemented |
| Template-based | Start from template | ⚠️ Template store exists |
| Import + modify | Start from existing PDF | ⚠️ Edit operations exist |
| Merge + compose | Combine existing PDFs | ✅ BatchMergeSheet |
| Programmatic | API-based generation | ⚠️ PDFBatchProcessor |

### 1.7 Current State

| Component | Status | Evidence |
|---|---|---|
| AcroForm creation | ⚠️ Partial | PDFIncrementalFormWriter |
| Template store | ⚠️ Partial | TemplateStore, TemplateSyncContracts |
| PDF merge | ✅ Complete | BatchMergeSheet |
| PDF split | ⚠️ External | PdfCpuBatchProcessor |
| Watermark | ⚠️ External | PdfCpuBatchProcessor |
| Blank canvas | ❌ Nothing | — |
| Rich text editor | ❌ Nothing | — |
| Image placement | ❌ Nothing | — |
| Form field designer | ❌ Nothing | — |

### 1.8 Assessment

CREATE is the **weakest archetype**. The app has:
- Edit operations (overlay text, fill fields) — but these modify existing PDFs, not create new ones
- Template store — but no template editor
- PDF merge/split — but these are composition, not authoring

**The gap is the authoring surface.** Users cannot create a new PDF from scratch within the app. This is the biggest product opportunity.

---

## 2. TRANSFORM (J9) — "I want to modify an existing document"

### 2.1 WHO

| Persona | Core Need | Expertise | Frequency | Our Support |
|---|---|---|---|---|
| Editor | Revise content | Domain expert | Daily | ⚠️ Overlay text exists |
| Form filler | Fill in data | Basic | Daily | ✅ AcroForm fill |
| Data entry | Batch fill forms | Operational | Daily | ⚠️ Batch processor |
| Redactor | Remove sensitive info | Security | Weekly | ⚠️ Redaction exists |
| Corrector | Fix errors in PDF | Domain expert | Weekly | ⚠️ Overlay text |
| Converter | Change format | Technical | Weekly | ⚠️ Export formats |

### 2.2 WHAT

| Object | Transformation challenge | Our capability | Gap |
|---|---|---|---|
| Text content | Edit text in-place | ⚠️ Overlay text (not in-place) | Medium |
| Form fields | Fill/change fields | ✅ AcroForm fill | Small |
| Pages | Add/remove/reorder | ⚠️ External tools | Medium |
| Images | Replace/add images | ❌ No image editing | Large |
| Annotations | Add/remove PDF annotations | ❌ No PDF annotation creation | Medium |
| Metadata | Edit title/author/etc. | ⚠️ Basic extraction | Medium |
| Security | Add/remove encryption | ✅ Password/permissions | Small |
| Redaction | Remove content permanently | ⚠️ Redaction exists | Small |

### 2.3 WHEN

| Phase | What happens | Our support |
|---|---|---|
| 1. Open document | Load existing PDF | ✅ Fast open |
| 2. Identify changes | What needs modification | ⚠️ Search exists |
| 3. Apply changes | Execute modifications | ⚠️ Edit operations |
| 4. Verify changes | Confirm correctness | ✅ Diff view |
| 5. Save changes | Persist modifications | ✅ Incremental save |
| 6. Export | Share modified version | ✅ Export |

### 2.4 HOW

| Method | Description | Our support |
|---|---|---|
| Overlay text | Place text over existing | ✅ OverlayText operation |
| Fill form fields | Write to AcroForm fields | ✅ FillForm operation |
| Redact content | Black out regions | ⚠️ Redaction exists |
| Add watermarks | Overlay text/image | ⚠️ External tool |
| Merge documents | Combine PDFs | ✅ BatchMergeSheet |
| Split document | Extract pages | ⚠️ External tool |
| Rotate pages | Change orientation | ⚠️ External tool |
| Compress | Reduce file size | ❌ Not implemented |
| Repair | Fix corrupted PDF | ⚠️ QPDFValidator |

### 2.5 Current State

| Component | Status | Evidence |
|---|---|---|
| Overlay text | ✅ Complete | EditOperation.overlayText |
| Fill form fields | ✅ Complete | EditOperation.fillForm |
| Redaction | ⚠️ Partial | Redaction exists |
| Incremental save | ✅ Complete | PDFIncrementalFormWriter |
| Source preservation | ✅ Complete | Bytes not modified |
| Diff comparison | ✅ Complete | DiffComparisonView |
| Undo/redo | ✅ Complete | Operation ledger |
| Page manipulation | ⚠️ External | PdfCpuBatchProcessor |
| Image editing | ❌ Nothing | — |
| Rich text editing | ❌ Nothing | — |

### 2.6 Assessment

TRANSFORM is **moderately capable**. The core operations (overlay text, fill forms, redact) work well with source preservation. The main gaps:
- No in-place text editing (overlay is a workaround, not true editing)
- No image manipulation
- Page operations require external tools

---

## 3. COMMIT (J7) — "I want to bind myself/others to this document"

### 3.1 WHO

| Persona | Core Need | Expertise | Frequency | Our Support |
|---|---|---|---|---|
| Signer | Digitally sign a document | Legal | Weekly | ✅ Signature sheet |
| Approver | Authorize a document | Business | Weekly | ❌ No approval gate |
| Notary | Certify document authenticity | Legal专业 | Weekly | ❌ No notarization |
| Witness | Co-sign a document | Legal | Monthly | ❌ No multi-sign |
| Executive | Final sign-off | Business | Weekly | ❌ No approval workflow |

### 3.2 WHAT

| Object | Commitment challenge | Our capability | Gap |
|---|---|---|---|
| Digital signature | Cryptographic binding | ✅ Signature guard | Small |
| Approval signature | Authorization mark | ❌ No approval state | Medium |
| Timestamp | Prove when signed | ⚠️ Audit timestamp exists | Small |
| Multi-signature | Multiple signers | ❌ No multi-sign | Large |
| Certificate signing | X.509 certificate | ❌ No certificate signing | Large |
| Witness signature | Co-signing | ❌ No witness flow | Large |

### 3.3 WHEN

| Phase | What happens | Our support |
|---|---|---|
| 1. Document review | Read before signing | ✅ Reader mode |
| 2. Integrity check | Verify document is unaltered | ✅ Signature verifier |
| 3. Identity verification | Confirm signer identity | ⚠️ CommitFlow exists |
| 4. Binding text | Show what you're signing | ✅ CommitFlowSheet |
| 5. Sign | Apply signature | ✅ Signature creation |
| 6. Audit | Record the signing | ✅ CommitAuditEntry |
| 7. Distribute | Send signed document | ✅ File export |

### 3.4 HOW

| Method | Description | Our support |
|---|---|---|
| Visual signature | Draw/upload signature image | ✅ Signature sheet |
| Digital signature | Cryptographic (PKCS#7) | ⚠️ Signature guard verifies |
| Approval mark | Simple "approved" stamp | ❌ Not implemented |
| Timestamp | RFC 3161 timestamp | ❌ Not implemented |
| Multi-party signing | Sequential/parallel | ❌ Not implemented |
| Certificate-based | X.509 certificate | ❌ Not implemented |

### 3.5 Current State

| Component | Status | Evidence |
|---|---|---|
| Signature creation | ✅ Complete | SignatureSheet |
| Signature verification | ✅ Complete | PDFDigitalSignatureVerifier |
| Integrity check | ✅ Complete | ByteRange verification |
| CommitFlow | ✅ Complete | Binding text + integrity + audit |
| CommitAuditEntry | ✅ Complete | Who/when/what/method |
| Digital signature (PKCS#7) | ⚠️ Partial | Verifier exists, creator partial |
| Approval workflow | ❌ Nothing | — |
| Multi-signature | ❌ Nothing | — |
| Certificate signing | ❌ Nothing | — |

### 3.6 Assessment

COMMIT is **well-founded**. The CommitFlow (binding text → integrity check → sign → audit) is the right architecture. The main gaps:
- No approval workflow (sequential sign-off)
- No multi-party signing
- No certificate-based signing

---

## 4. CROSS-CREATOR ASSESSMENT

### 4.1 What the Creator Archetype Needs Most

| Priority | Gap | Impact | Effort |
|---|---|---|---|
| 1 | Document creation from scratch | Opens entire authoring market | HIGH |
| 2 | In-place text editing | Core editing capability | HIGH |
| 3 | Form field designer | Template creation | MEDIUM |
| 4 | Approval workflow | Business use case | MEDIUM |
| 5 | Multi-party signing | Legal compliance | MEDIUM |
| 6 | Page manipulation UI | Common operation | LOW |

### 4.2 Doctrine Alignment

| Doctrine | CREATE | TRANSFORM | COMMIT |
|---|---|---|---|
| §3 Do things smartly | ⚠️ No creation tools | ✅ Incremental save | ✅ CommitFlow |
| §5 Evidence-based | ❌ No creation evidence | ✅ Diff view | ✅ Audit trail |
| §8 Capability activation | N/A | ✅ Opt-in operations | ✅ Explicit signing |
| §12 Privacy value-free | N/A | ✅ Source preservation | ✅ Value-free audit |

### 4.3 The Creator-Reader Bridge

```
READ (consume) → TRANSFORM (modify) → COMMIT (bind)
                                        ↑
                    CREATE (produce) ────┘
```

The natural flow: read a document, modify it, commit to it. Or create a new one, then commit. The app currently supports READ and partial TRANSFORM/COMMIT, but CREATE is the missing foundation.

---

## 5. EVIDENCE

- `Sources/PDFEditorCore/PDFIncrementalFormWriter.swift` — incremental save, source preservation
- `Sources/PDFEditorCore/CommitFlow.swift` — signing flow with integrity check + audit
- `Sources/PDFEditorApp/CommitFlowSheet.swift` — signing UI
- `Sources/PDFEditorCore/PDFDigitalSignatureVerifier.swift` — signature verification
- `Sources/PDFEditorApp/DiffComparisonView.swift` — visual diff
- `Sources/PDFEditorCore/PdfCpuBatchProcessor.swift` — external tool operations
- `Sources/PDFEditorApp/BatchMergeSheet.swift` — PDF merge
- `docs/audits/personas-jobs-expanded-model-2026-08-26.md` §2-§3 — original CREATE/TRANSFORM/COMMIT analysis
