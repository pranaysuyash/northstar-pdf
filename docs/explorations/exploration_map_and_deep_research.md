# Northstar Master Exploration Map & Deep Research Architecture

**Status:** Canonical Reference & Roadmap  
**Doctrine Alignment:** `OPERATING_DOCTRINE.md` v8.0 (§1 First Principles, §2 Epistemic Integrity, §4 Preserving Value, §7 Zero Egress Boundary, §8 Capability Routing)  
**Target Repository:** `pranaysuyash/northstar-pdf` (`/Users/pranay/Projects/pdf_editor`)  
**Author:** Antigravity Architect & Specialist Persona Council  

---

## Executive Summary & First-Principles Framing

Northstar PDF is architected as an air-gapped, zero-network-egress, native macOS document workspace. While core document inspection, overlay rendering, incremental saving, PII scrubbing, digital signature forensics, XFA extraction, and App Intents are now implemented in the primary pipeline, long-term technical superiority requires structured research and architecture exploration in four specific areas:

> **Verification note (2026-09-17 audit):** "implemented" above reflects source work only
> (MAD-001 intents wiring resolved via commit `aa7e2da`; print + entitlements work landed
> 2026-09-17). Shortcuts runtime proof is still open at evidence tier T4 — do not cite this
> document as verification evidence. Task state lives in `docs/task-inventory.md`.

```
+---------------------------------------------------------------------------------------+
|                                NORTHSTAR CORE ENGINE                                  |
+---------------------------+-------------------------------+---------------------------+
                            |
           +----------------+----------------+
           |                                 |
           v                                 v
+-----------------------+         +-----------------------+
|     EXPLORATION 1     |         |     EXPLORATION 2     |
| CoreSpotlight Native  |         |   "Teach Northstar"   |
|   Deep Indexing &     |         |   Recurring Template  |
| Deep-Link Navigation  |         |   Synthesis Engine    |
+-----------------------+         +-----------------------+
           |                                 |
           v                                 v
+-----------------------+         +-----------------------+
|     EXPLORATION 3     |         |     EXPLORATION 4     |
| Real-World Degraded   |         | Asynchronous Chunked  |
|    OCR Benchmark      |         | Multi-Thread Ingest   |
|  & Adversarial Corpus |         |  & Memory Budgeting   |
+-----------------------+         +-----------------------+
```

---

## Exploration 1: CoreSpotlight Native Deep-Indexing Architecture

### 1.1 First-Principles Objective
Allow macOS system-wide Spotlight (`Cmd+Space`) and Alfred/Raycast integrations to index local PDF documents processed by Northstar down to individual pages, bounding boxes, form field labels, and extracted table cells—without ever sending document contents or embeddings across a network boundary.

### 1.2 Architectural Invariants & macOS Substrates
1. **Zero-Egress Indexing:** Uses `CoreSpotlight.framework` (`CSSearchableIndex` and `CSSearchableItemAttributeSet`). All index records reside in the local APFS Spotlight database (`/.Spotlight-V100/` or user cache).
2. **Granular Deep-Link Identifiers:**
   - Universal URL Scheme: `northstar://document?path=<encoded_path>&page=<index>&rect=<x,y,w,h>&fieldId=<id>`
   - Bounding Box Geometry: Encoded as normalized 72 DPI PDF coordinates `(x, y, width, height)`.
   - Spotlight Domain Identifier: `com.northstar.pdf.documents` and `com.northstar.pdf.forms`.
3. **Incremental Invalidation:** When a document is modified or sanitized, its corresponding `CSSearchableItem` IDs are invalidated via `deleteSearchableItems(withIdentifiers:)` before re-indexing.

### 1.3 Proposed Core Interface
```swift
import CoreSpotlight
import UniformTypeIdentifiers

public final class NorthstarSpotlightIndexer: Sendable {
    public static let shared = NorthstarSpotlightIndexer()
    private let index = CSSearchableIndex.default()

    public func indexDocument(
        inspection: DocumentInspection,
        fileURL: URL
    ) async throws {
        var items: [CSSearchableItem] = []

        // Document-level item
        let docSet = CSSearchableItemAttributeSet(contentType: .pdf)
        docSet.title = fileURL.lastPathComponent
        docSet.contentCreationDate = Date()
        docSet.textContent = inspection.pages.map { $0.hasSelectableText ? "Page \($0.pageIndex)" : "" }.joined(separator: "\n")
        
        let docItem = CSSearchableItem(
            uniqueIdentifier: "doc:\(fileURL.path)",
            domainIdentifier: "com.northstar.pdf.documents",
            attributeSet: docSet
        )
        items.append(docItem)

        // Field & Candidate items for instant jump
        for field in inspection.fields {
            let fieldSet = CSSearchableItemAttributeSet(contentType: .text)
            fieldSet.title = "\(field.name): \(field.value ?? "")"
            fieldSet.containerTitle = fileURL.lastPathComponent
            let deepLink = "northstar://document?path=\(fileURL.path)&page=\(field.pageIndex)&rect=\(field.bounds.x),\(field.bounds.y),\(field.bounds.width),\(field.bounds.height)&field=\(field.id)"
            fieldSet.url = URL(string: deepLink)

            let fieldItem = CSSearchableItem(
                uniqueIdentifier: "field:\(fileURL.path):\(field.id)",
                domainIdentifier: "com.northstar.pdf.forms",
                attributeSet: fieldSet
            )
            items.append(fieldItem)
        }

        try await index.indexSearchableItems(items)
    }
}
```

### 1.4 Hardening & Failure Modes
- **File System Eviction:** If a file is deleted from Finder, a `NSFilePresenter` or `FSEvents` monitor purges orphaned searchable items.
- **Privacy Gating:** Documents flagged with `PDFSecuritySummary.isEncrypted` or containing sensitive PII (per `BatchPIIProcessor`) can have text indexing explicitly suppressed or opted out per user preference.

---

## Exploration 2: "Teach Northstar" Recurring Template Synthesis

### 2.1 First-Principles Objective
Transform human candidate reviews from ephemeral click-actions into a durable, self-improving template induction engine. When an operator corrects field boundaries, confirms radio groups, or labels form items across repeated invoices or government filings (e.g. Form 6, W-9, CMS-1500), Northstar should infer structural invariants and synthesize a canonical `PDFDocumentTemplate`.

### 2.2 Mathematical & Algorithmic Foundation
1. **Anchor Point Triangulation:**
   Given a set of human-confirmed field locations across documents $\{D_1, D_2, \dots, D_k\}$ with matching semantic keys $K$, compute the spatial variance vector:
   $$\sigma^2(K) = \frac{1}{k}\sum_{i=1}^k \|\mathbf{p}_i(K) - \mathbf{a}_i(Anchor)\|^2$$
   where $\mathbf{a}_i(Anchor)$ is the centroid of invariant text tokens (e.g., `"VOTER IDENTIFICATION CARD"`, `"Employer ID Number"`).
2. **Invariant Token Extraction:**
   Tokens with zero positional variance relative to page margins are flagged as `AnchorTokens`.
3. **Threshold-Gated Synthesis:**
   When $\sigma^2(K) < \epsilon$ across $\ge 3$ documents, Northstar generates a draft template in `TemplateStore` with confidence tier `high`.

### 2.3 Integration Flow
```
[User Form Review]
       │
       ▼
[CandidateReviewEventStore] ─── (Record accept / reject / move events)
       │
       ▼
[TemplateSynthesisEngine]
       │
       ├─ Cluster documents by visual hash & invariant text anchors
       ├─ Compute relative offset matrices (Field Rect - Anchor Rect)
       └─ Verify non-overlapping layout validity
       │
       ▼
[Draft Template Candidate]
       │
       ▼
[Operator Review Prompt in Command Palette] -> "Save detected 'Acme Invoice' template?"
```

---

## Exploration 3: Real-World Degraded OCR Benchmark & Adversarial Corpus

### 3.1 First-Principles Objective
Create a scientific, reproducible evaluation framework that measures the limits of on-device OCR under severe real-world scanning defects (skew, low contrast, bleed-through, fax compression, salt-and-pepper noise), ensuring epistemic honesty rather than synthetic 100% test claims.

### 3.2 Corpus Matrix & Distortion Profiles
| Distortion ID | Description | Degradation Transform | Target Word Error Rate (WER) |
|---|---|---|---|
| **CORP-DEG-01** | Skewed Scan | $\pm 3.5^\circ$ affine rotation + edge clip | $\le 4.2\%$ |
| **CORP-DEG-02** | Photocopied Grain | Bilinear downsample to 150 DPI + contrast stretch | $\le 6.5\%$ |
| **CORP-DEG-03** | Fax G3/G4 Simulation | 1-bit thresholding + horizontal run-length artifacts | $\le 9.0\%$ |
| **CORP-DEG-04** | Bleed-Through | Background overlay of verso page text at 15% opacity | $\le 5.0\%$ |
| **CORP-DEG-05** | Carbon Copy / Dot Matrix | Low-ink font degradation with broken strokes | $\le 8.0\%$ |

### 3.3 Comparative Harness Design
The harness runs against both:
1. `VNRecognizeTextRequest` (Apple Vision Framework native on Apple Silicon Neural Engine)
2. Fallback OCR provider (Local companion / Tesseract CLI bridge)

When Apple Vision confidence falls below 0.65 or character entropy exceeds normal distribution thresholds, the harness triggers the multi-engine consensus protocol (`MultiLibraryValidationTests`), fusing bounding boxes via `PDFQuad.intersectionRatio`.

---

## Exploration 4: Asynchronous Chunked Multi-Thread Ingest & Memory Budgeting

### 4.1 First-Principles Objective
Heavy PDFs (500+ page legal discovery bundles, technical manuals with thousands of vector paths) must never hitch the macOS main thread (`@MainActor`). Ingest, catalog extraction, text parsing, and table recognition must run asynchronously across a cooperative actor pool while strictly observing an RSS memory ceiling (250 MB).

### 4.2 Pipeline Architecture
```
[File URL / NSData]
       │
       ▼
[PDFIngestCoordinator (Actor)]
       │
       ├─ Phase 1: Fast Header & Catalog Probe (< 15ms)
       │    └─ Extract page count, media boxes, encryption, XFA status
       │    └─ Yield initial DocumentInspection to UI (immediate render of Page 1)
       │
       ├─ Phase 2: Parallel Page Extraction TaskGroup (Cooperative Swift Concurrency)
       │    ├─ Task 1: Pages 1..50 (High priority viewport)
       │    ├─ Task 2: Pages 51..100
       │    └─ Task N: Pages N..N+50
       │
       └─ Phase 3: Deferred Forensic Analysis (Background Queue)
            ├─ Signature stream validation
            ├─ Table detection via ImprovedTextExtractor
            └─ Full-text search index generation
```

### 4.3 Memory Budgeting Safeguards
- **Chunked Rendering:** Raster caches keep at most 10 high-resolution page bitmaps in memory (`DocumentCacheManager`), using LRU eviction.
- **Autoreleasepool Scoping:** Heavy PDFKit page representations are scoped within local `@autoreleasepool` blocks in the background workers to prevent heap runaway.

---

## Traceability to Doctrines & Roadmap Integration

- **§1 First Principles:** Document capabilities derive from exact PDF ISO 32000-1 specification realities, not third-party SaaS wrappers.
- **§2 Epistemic Honesty:** All metrics must be falsifiable with ground-truth test corpora.
- **§7 Zero-Egress Boundary:** Spotlight, OCR, and template synthesis operate 100% on-device with zero network requests.
- **Next Steps:** As decisions are made on release packaging, components from Explorations 1–4 will be promoted into implementation plans with discrete unit and integration test coverage.

---

## Ledger Integration & 2026-09-17 Audit Deltas

**Promotion rule (binding):** an exploration only becomes implementation work through a
`task-inventory.md` entry (with exit oracle and evidence tier) — never by implementation directly
from this document. This map proposes; `docs/task-inventory.md` owns state; `docs/release-gates.md`
owns gates; `docs/decisions.md` owns decisions.

### Errata against Explorations 1–4 (2026-09-17 audit cross-check)

| Exploration | Correction |
|---|---|
| **1 — CoreSpotlight indexing** | Add sandbox dependency: URL-scheme registration and Spotlight indexing must be validated under the staged entitlements (`docs/research/sandbox-entitlements-plan-2026-09-17.md`). Demand-side evidence for deep-link navigation does not exist yet — needs a cohort instrument before build (council demand-first posture). |
| **2 — "Teach Northstar" template synthesis** | Scope as UX packaging of the existing TASK-B4 substrate (council 2026-09-17, step 8) — not a new synthesis engine. Gated on PL-D12 (table-extraction demand check) before any engine work. |
| **3 — Degraded OCR benchmark** | Link to the existing program instead of a parallel harness: `PDFOCRBenchmark`/`PDFTextRunOCRBenchmark` targets, `docs/research/` form-detection map (FD-R1), and NM-T28 calibration-drift reconciliation. |
| **4 — Async chunked ingest** | This is the ledgered debt, not a new program: it overlaps MAD-004 (main-actor parse, still open), MDEV-I3/A-9 (AppModel 6,527-line decomposition), and NM-T01 (ownership matrix). Route through NM-T01; a second pipeline would violate the no-parallel-systems rule. |

### ADHD pool-ledger ban discipline (added 2026-09-17, second pass)

The errata above overlap the ADHD divergent-audit pool: all four explorations
are already-known candidates in
[`docs/explorations/adhd-exploration-pool-ledger.md`](adhd-exploration-pool-ledger.md)
(Spotlight indexing, template synthesis ≈ round-2 B1-adjacent, degraded-OCR
benchmark, chunked ingest ≈ round-2 D1-adjacent). Any future divergent or
exploration round MUST read that ledger's ban list before generating and must
append new pools to it. Register hygiene is machine-checked:
`node tools/register-lifecycle-check.mjs` (3 rounds, 89 rows, 0 violations at
2026-09-17).

### Round-3 divergent-audit nodes (added 2026-09-17)

Nodes from [`../audits/comprehensive-adhd-audit-round3-2026-09-17.md`](../audits/comprehensive-adhd-audit-round3-2026-09-17.md);
full pool + lifecycle statuses = ledger R3-01…R3-30. These are the
launch-relevant directions Explorations 1–4 and entries 5–9 do not cover.

| Node | Direction | Implemented substrate (2026-09-17) | Status / falsifier |
|---|---|---|---|
| **N-R3-A** | Cohort-anchored single-form edition + operating envelope | `OperatingEnvelope.swift` + shipped `operating-envelope.json` (Bundle resource, single source of truth); `DemandLedger.swift` (local-only value-free JSONL + rotation); 12/12 tests pass (incl. tamper mutations) | Candidate ★. Open-time wiring into `AppModel.open` pending (parallel-lane collision avoidance). Falsifier: fixtures covering only clean digital PDFs make the datasheet honest-but-empty. Decisions: D-055 envelope-claim entry; anchor-form confirmation. |
| **N-R3-B** | Demand-priced gate backlog / presale | `tools/export-form-class-ledger.mjs` → `docs/public/form_class_ledger.json` + `ledger.html` (honest-empty); signed evidence chain in Core — `ReceiptSigning.swift` + `GateReportAttestation` + `CohortEntitlement.swift` (entitlement → attestation → report-digest, per-link verdicts), optional `ExecutionReceipt.signature`; 8/8 chain tests incl. authority-mismatch | Candidate. Research-updated default mechanic = **$0-auth quorum** (Stripe-verified: refunds forfeit processing fees; auth-holds cancel pre-capture free — see [`../research/round3-cohort-research-2026-09-17.md`](../research/round3-cohort-research-2026-09-17.md)). Falsifier: empty order book at zero audience. Decisions: provider/account, terms owner, redacted-contribution lane. |
| **N-R3-C** | Parity coverage extension | `tools/parity-settlement-classify.mjs` + `Tests/parity_settlement_classification_test.mjs`; measurement 2026-09-17: 13 exact-agree / 3 classified-variance / 2 malformed-agree / **0 disputes** | Mapped. **Netting premise falsified by measurement** — parity state is open measurement scope (OCR, companion providers, non-noop edits, candidate reconciliation), not disputes; ParitySettlementReport parked-conditional (revisit when `disputeCount > 0` in a fresh run). |
| **N-R3-D** | Borrowed humans / review integrity | `GateReportAttestation` substrate binds reviewer outputs like gate reports | Research needed: how external reviewers preserve D-055 authority (R3-17/R3-27); security/privacy/safety handoff for reviewer trust boundaries. |
| **N-R3-E** | Habitat distribution (re-angled) | — | Research needed: association/vendor-directory venues only — integration marketplaces are structurally incompatible with zero-egress (research doc §5 Q2). Submission requirements/fees = bounded pass remaining. |

### New exploration entries (registered 2026-09-17)

| # | Exploration | Research output | Status |
|---|---|---|---|
| **5** | **Liquid Glass (macOS 26) migration** — which surfaces glassify (nav layers only), which de-materialize (inspector cards); de-card → accessibility fallbacks → evidence pass → min-OS bump | [`research/liquid-glass-migration-plan-2026-09-17.md`](../research/liquid-glass-migration-plan-2026-09-17.md) | Plan documented; waits on MAD-I7 + min-OS decision |
| **6** | **Sandbox entitlements** — minimal entitlement set, file-access audit, companion-child-process exposure, opt-in signing flag | [`research/sandbox-entitlements-plan-2026-09-17.md`](../research/sandbox-entitlements-plan-2026-09-17.md) | Staged (`tools/native-preview.entitlements` + `PDF_EDITOR_ENABLE_SANDBOX=1`); default-on gated on T4 matrix + NM-T32 |
| **7** | **Localizability** — string-extraction cost and layout risk survey | [`research/localizability-survey-2026-09-17.md`](../research/localizability-survey-2026-09-17.md) | Surveyed (~600 literals, zero infrastructure); gates MAD-D4 |
| **8** | **Generated command map** — `tools/` generator emitting menus/shortcuts/palette as a checked-in doc so drift is visible (MAD-R4) | — | Open, not started |
| **9** | **Concurrency remediation** — five race-flagged sites (`RenderingPipeline`, both `CompanionTransport`s, `StudyLoopManager`, `FreezePaneState`) + PDFPage-handoff enforcement | [`research/sendability-invariant-ledger-2026-09-17.md`](../research/sendability-invariant-ledger-2026-09-17.md) | Ledger + drift check landed; fixes = MDEV-I6 |
| **10** | **External decision-tier model (TypeSafe AI Jev / System One)** — typed calibrated judgments (Noul/Choice/Score) as a candidate fast judgment lane: agent-shell tool selection + per-action risk, execution-receipt "needs review" triage, security-finding triage, OCR confirm-queue ordering, backend support/refund/telemetry routing. **Zero-egress conditional:** exploration restricted to internal/own-data lanes (finding history, agent traces, telemetry, OCR text corpora). Any document-content egress to the vendor requires a doctrine-amendment decision + explicit opt-in + receipt disclosure; dark sessions are categorically excluded. Shadow-mode spike registered as NM-R15. | [`research/jev-system-one-model-capability-map-2026-09-18.md`](../research/jev-system-one-model-capability-map-2026-09-18.md) (**living doc** — updated after every access-window experiment) | Early access requested 2026-09-18; no API grant yet; capability claims sourced-only, none reproduced locally |

### Source map

- Task state: [`../task-inventory.md`](../task-inventory.md) · Gates: [`../release-gates.md`](../release-gates.md) · Decisions: [`../decisions.md`](../decisions.md)
- macOS design findings: [`../audits/macos-app-design-skill-audit-2026-09-11.md`](../audits/macos-app-design-skill-audit-2026-09-11.md) (MAD-001..018)
- macOS developer-quality findings: [`../audits/macos-development-skill-audit-2026-09-17.md`](../audits/macos-development-skill-audit-2026-09-17.md) (MDEV-001..005)
- Council review (demand-side posture): [`../audits/chatgpt-feedback-council-review-2026-09-17.md`](../audits/chatgpt-feedback-council-review-2026-09-17.md)
