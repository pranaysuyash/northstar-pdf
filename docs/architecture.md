# Architecture — PDF Editor

**Status:** Canonical module map and data flow
**Date:** 2026-08-26

## Module dependency graph

```
┌─────────────────────────────────────────────────────────┐
│                    PDFEditorApp (SwiftUI)                │
│  ContentView, ContextualInspector, PageThumbnail,       │
│  Toolbar, AgentCommandHUD, DiffComparison               │
└──────────────────────┬──────────────────────────────────┘
                       │ depends on
┌──────────────────────▼──────────────────────────────────┐
│               PDFEditorRecovery (AppModel)               │
│  Document lifecycle, session persistence, autosave,      │
│  candidate ranking, learning loop, OCR triggering        │
└──────────────────────┬──────────────────────────────────┘
                       │ depends on
┌──────────────────────▼──────────────────────────────────┐
│                    PDFEditorCore                         │
│  ┌─────────────────┐  ┌──────────────────────────────┐  │
│  │ SharedContracts  │  │ PDFIncrementalFormWriter      │  │
│  │ (DocumentSource, │  │ (xref parsing, field update,  │  │
│  │  EditOperation,  │  │  PNG predictor, appearance    │  │
│  │  Validation)     │  │  streams, compressed objects) │  │
│  └─────────────────┘  └──────────────────────────────┘  │
│  ┌─────────────────┐  ┌──────────────────────────────┐  │
│  │ Detection        │  │ Security                      │  │
│  │ (StaticRegion,   │  │ (SignatureGuard, XfaGuard,   │  │
│  │  VectorStream,   │  │  Sanitize, ActionNeutralize,  │  │
│  │  Fusion, OCR)    │  │  AttachmentScanner)           │  │
│  └─────────────────┘  └──────────────────────────────┘  │
│  ┌─────────────────┐  ┌──────────────────────────────┐  │
│  │ Templates        │  │ CapabilityLanes               │  │
│  │ (Fingerprints,   │  │ (OCR, TextReplace, Redact,   │  │
│  │  Profiles,       │  │  Signatures, XFA, PDF/UA)     │  │
│  │  EncryptedStore) │  │                               │  │
│  └─────────────────┘  └──────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────┐  │
│  │ LearningLoop (CandidateReviewEvents, Priors,       │  │
│  │  SuggestionExplainer, CandidatePriorScorer)        │  │
│  └────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
                       │
            ┌──────────┴──────────┐
            │   Provider adapters │
            ├─────────────────────┤
            │ Native: PDFKit      │
            │ Browser: PDF.js +   │
            │   pdf-lib           │
            │ Future: PDFBox,     │
            │   MuPDF, Vision OCR │
            └─────────────────────┘
```

## Data flow: edit lifecycle

```
1. OPEN: File → Provider.inspect() → DocumentInspection
   ├── pages, fields, candidates, accessibility, security
   └── source digest (SHA-256)

2. DETECT: Inspection → StaticRegionDetector → [RegionCandidate]
   ├── geometry, evidence, score, label, entry mode
   └── learning loop ranks by historical acceptance

3. REVIEW: User → CandidateStatus (confirmed/rejected/dismissed)
   ├── learning event recorded (value-free, privacy-safe)
   └── priors re-aggregated for immediate re-ranking

4. EDIT: Candidate + value → EditOperation
   ├── .overlayText (visual overlay on page)
   ├── .nativeFieldValue (AcroForm widget edit)
   ├── .textRunReplacement (abstained until proven)
   ├── .annotation, .pageInsert, .pageDelete, .pageRotate
   └── .applyRedaction (two-phase, destructive)

5. EXPORT: Source + operations → Provider.export() → ExportArtifact
   ├── source-preserving: original bytes = byte-exact prefix
   ├── incremental update: xref chain appended (native)
   ├── pdf-lib bounded write (browser)
   └── validation: reopen, text, raster, structural

6. VALIDATE: ExportArtifact → ValidationReport
   ├── source unchanged, text preserved, raster diff
   ├── reopenable, qpdf clean, independent viewer
   └── evidence tier + sensitivity label
```

## Trust boundaries

```
┌──────────────────────────────────────────────────────┐
│                 LOCAL ONLY (no network)               │
│  Source bytes, extracted text, OCR output,            │
│  candidate evidence, edit operations, templates       │
│                                                      │
│  ┌────────────────────────────────────────────────┐  │
│  │            USER REVIEW BOUNDARY                │  │
│  │  Candidates enter as "suggested" only.         │  │
│  │  Must pass user confirmation before mutation.  │  │
│  │  Never auto-applied.                           │  │
│  └────────────────────────────────────────────────┘  │
│                                                      │
│  ┌────────────────────────────────────────────────┐  │
│  │            EXPORT BOUNDARY                     │  │
│  │  Original bytes untouched.                     │  │
│  │  Export creates new file.                      │  │
│  │  Validation required before presented as done. │  │
│  └────────────────────────────────────────────────┘  │
│                                                      │
│  ┌────────────────────────────────────────────────┐  │
│  │            CRYPTOGRAPHIC BOUNDARY              │  │
│  │  Template/profile stores: AES-256-GCM.         │  │
│  │  Keychain-backed on native.                    │  │
│  │  Separate profile vault.                       │  │
│  └────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────┘
```

## Provider adapter pattern

```
SharedContract ←→ ProviderAdapter ←→ ProviderEngine

PDFContractEnvelope:
  header: { contractName, version, sourceDigest, provider }
  payload: DocumentInspection | EditOperation | ValidationReport

Native adapter: PDFKitProvider (PDFKit framework)
Browser adapter: pdf.js + pdf-lib (JavaScript)
Future adapters: PDFBox (JVM), MuPDF (C/WASM), Vision OCR (macOS)
```

## Key invariants

1. **Source bytes immutable** — every edit, undo, recovery depends on this
2. **Candidates require review** — never auto-applied, always user-confirmed
3. **Fail closed by default** — encrypted, XFA, signature, malformed → refuse
4. **Privacy per capability** — each capability declares its own data boundary
5. **Evidence before claims** — no capability advertised without provider + fixture + validator
6. **Contract versions monotonic** — forward only, reject future major versions
