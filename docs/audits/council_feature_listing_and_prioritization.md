# Council Report: Master Feature Listing & Strategic Prioritization

**Date:** 2026-09-24  
**Convening Authority:** User Directive via `council-orchestrator`  
**Governing Doctrine:** `OPERATING_DOCTRINE.md` v8.1 (§1 First Principles, §2 Truth Taxonomy, §3 Proportional Rigor, §6 Semantic Salvage, §16 Specialist Doctrine Routing)  
**Target Repository:** `pranaysuyash/northstar-pdf`  
**Review Mode:** REVIEW_DOCTRINE (Evidence-Aware Decision & Prioritization Synthesis)  

---

## 1. Council Manifest & Seat Coverage

| Seat ID | Role / Title | Seat Type | Mandate & Specific Lens |
|---|---|---|---|
| **PER-0926** *(Lead)* | **Product Evolution Architect** | Decision Owner | Continuity with D-083 & Vision Council (2026-09-22); synthesizes trade-offs into an executable roadmap. |
| **PER-0755** | **Principal Product Designer** | Design & Craft | Evaluates the 4-pillar visual language, toolbar island demotion, inspector hierarchy, and spatial paper elevation. |
| **PER-0172** | **Product Thesis Guardian** | Thesis Guardian | Ensures the "modern new-age AI-native PDF reader/editor" thesis is executed rather than drift-washed into generic PDF utilities. |
| **PER-PDEV-0149** | **Systems & Performance Architect** | Engineering Feasibility | Evaluates 250 MB memory budgeting, sub-50ms UI snappiness, async ingest, and zero-egress cryptographic boundaries. |
| **PER-0315** | **JTBD Strategist & Commercial Lead** | Market & Wedge Adoption | Analyzes customer switching triggers, early-adopter pricing ($59 tier), wedge workflows (invoices, Form 6, W-9), and competitor moats. |
| **PER-91013** | **No-Go Adversarial Reviewer** | Skeptic / Falsifier | Stress-tests feature utility, exposes slow or brittle loops, and challenges unfalsifiable claims. |

---

## 2. Master Feature Inventory & Live State Taxonomy

Every feature in the repository is classified into one of four verified lifecycle tiers:

```
+---------------------------------------------------------------------------------------------------+
|                                     NORTHSTAR FEATURE SPECTRUM                                    |
+---------------------+---------------------+-----------------------+-------------------------------+
|   TIER 1: FOUNDED   |  TIER 2: IN-FLIGHT  |    TIER 3: PLANNED    |       TIER 4: FRONTIER        |
|    (Implemented &   |   (Source Landed,   |   (Design & Contract  |      (Researched / Spec'd,    |
|       Verified)     |   Gating Active)    |        Ready)         |        Deferred to v2)        |
+---------------------+---------------------+-----------------------+-------------------------------+
```

### 2.1 Tier 1: Founded Core (Implemented, Verified & Locked)
1. **Zero-Egress Document Inspection:** Single/continuous page viewing, PDFKit bounding-box extraction, and geometry normalization (`PDFRect.standardized`, `PDFQuad`).
2. **Deterministic Edit Operation Log:** Reverse-replay undo/redo, cryptographic `operationId`, content-preserving export pipelines.
3. **Forensic Inspection Substrates:** Native AcroForm extraction, XFA static XML decoding (`XFAFormProcessor`), digital signature verification (`PDFDigitalSignatureVerifier`), and PII redaction sweeps (`PDFBatchProcessor`).
4. **Native App Intents & Automation:** `SanitizePDFIntent` (strips metadata, actions, files), `ExtractTableCSVIntent` (multi-table CSV export), and `ComparePDFVersionsIntent` wired directly to core engines (`MAD-001`).
5. **Action Composer & HUD:** Multi-tier relevance scoring (Title: 150/100/70, Keyword: 80/60/40), candidate suggestion review parity (`confirm-candidate` / `reject-candidate`), and Return-key disambiguation (`PER-0784`).
6. **Agent Run Journal:** Append-only JSONL event persistence (`AgentRunJournalLog`) under Application Support (`NM-T41`).

### 2.2 Tier 2: In-Flight & Gated (Active Slices & Verification)
1. **Signature Stamp Overlay Writer (`NM-T46` / `NM-T47`):** Native `overlayImage` placement, incremental `/AP` stamp generation, rotation preservation. *Status: Stamp writer landed; publication-path merge/split unification in progress.*
2. **Page Paper Elevation & Shadows:** Native PDFKit page drop shadows and subtle elevation in `DocumentCanvasView.swift`.
3. **Thumbnail Rail Diagnostic Declutter:** Removal of raw `chars · W×H` technical leaks in `PageThumbnailRailView.swift`, adding clean selected-card accent halo.
4. **Adaptive Command Policy & History:** Deterministic command execution tracking and error recovery.

### 2.3 Tier 3: Planned & Highest-Leverage Backlog (The Immediate Arena)
1. **Pillar 2: Toolbar Demotion into Islands (`MAD-I6` / `PER-0755`):** Replacing the cluttered 13-element toolbar (`ContentView.swift`) with 3 focused, floating pill islands:
   - *Island A (Navigation/Zoom):* Thumbnails toggle, zoom preset, page counter.
   - *Island B (Mode Switcher):* Read (Skim) vs. Review (Form/Overlay) vs. Audit (Forensics).
   - *Island C (Action/Export):* Action Composer HUD trigger (`⌘K`), Share, Verified Export.
2. **Pillar 3: Two-Tier Inspector Hierarchy (`PER-0755`):** Partitioning `ContextualInspectorView.swift` into a primary immediate-action deck and a secondary progressive disclosure group.
3. **Pillar 4: Persistent Spatial Agent Lane (`PER-1228` / `D-083`):** Transitioning the agent loop from an intrusive modal sheet into a collateral side pane beside the canvas.
4. **The "Won't-Change Map" (`PER-0436` / Headline Bet):** Visualizing the Document Impact Validator's non-disturbance proof per-page before committing bulk fills or redactions.
5. **D-083 Slice 1: "Teach Northstar" Recurring Workflow Loop (`NM-T42`):** Drop document $\rightarrow$ detect recurrence $\rightarrow$ propose plan $\rightarrow$ user approves $\rightarrow$ bulk fill $\rightarrow$ export receipt $\rightarrow$ save as reusable workflow.
6. **CoreSpotlight On-Device Deep Indexing:** Enabling native macOS `Cmd+Space` deep search down to specific PDF bounding boxes with zero network egress.

### 2.4 Tier 4: Frontier & Deferred Slices
1. **Arbitrary In-Place Text Object Rewriting:** Requires custom font embedding and glyph subsetting engines; deferred behind overlays.
2. **Cloud Companion Offloading:** Strictly barred by Zero-Egress Boundary until explicit customer-authorized enterprise lane.
3. **Ambient Screen Recording / Audio Capture:** Rejected permanently as invasive and violating local trust.

---

## 3. Cross-Examination of Material Disagreements

### Issue A: "AI-Native" Agentic Spine vs. Desktop Craft & Chrome Polishing
- **PER-0172 (Thesis Guardian):** "If we spend the next two weeks fiddling with toolbar buttons, we become an expensive, slower PDF viewer. The owner’s core thesis is an *AI-native* tool made from first principles. Slice 1 (`NM-T42` - 'Teach Northstar') must be the primary deliverable."
- **PER-0755 (Principal Designer):** "An agentic loop embedded in a 2004-style cluttered window with 13 generic toolbar buttons and modal sheets repels modern users. The visual grammar *is* the trust substrate. Users will not trust an AI agent on their tax form if the application feels dated or claustrophobic."
- **PER-91013 (Skeptic):** "Worse yet: if the agent loop takes 4 clicks and 45 seconds to fill a form that Guided Next Blank completes in 10 seconds, the agent is an annoying gimmick. It must beat the direct path."
- **Lead Reconciliation (PER-0926):** **The Parallel Track Rule.** We do not choose between them. We execute the *Chrome Restructuring* (Toolbar Islands + Inspector Hierarchy) as the spatial container, and place the *Persistent Agent Lane* (`NM-T42`) directly inside that new container. The agent is never a modal pop-up; it is a permanent co-pilot lane that proves it can beat the manual path on recurring files.

### Issue B: The "Won't-Change Map" vs. Standard Document Diffs
- **PER-0436 (Innovation Scout):** "Everyone offers diffs after the fact. What Adobe and preview *cannot* do is mathematically prove to a legal compliance officer: *'These 3 fields changed; these 99.8% of bytes and vector paths were physically undisturbed.'* The 'Won't-Change Map' turns our internal `DocumentImpactValidator` into a killer commercial feature."
- **PER-PDEV-0149 (Systems Architect):** "We already have the computational geometry: `PDFRect.intersectionRatio` and `DocumentDiffBuilder`. Surfacing this visually on the canvas before export costs less than 200 lines of SwiftUI, but provides 10x trust leverage."
- **PER-0315 (JTBD Strategist):** "This is our primary B2B/legal wedge. Legal and accounting professionals are terrified of AI hallucinations or corrupted vector stamps. A green non-disturbance shield closes sales."
- **Lead Reconciliation:** Adopt the **"Won't-Change Map"** as a P0 headline feature for the Review/Export milestone.

---

## 4. Definitive Prioritization Matrix (Value vs. Complexity)

```
        High  │                                                  
              │  [Won't-Change Map]          [Toolbar Islands]   
              │  [CoreSpotlight Indexing]    [Teach Northstar (S1)]
  PRODUCT     │  [Two-Tier Inspector]                            
  VALUE /     │                                                  
  LEVERAGE    │  [Guided Next Blank]         [Persistent Spine]  
              │  [Signature Stamp Unification]                   
              │                                                  
        Low   │  [Recent File History]       [Full PDF/UA Tree]  
              └──────────────────────────────────────────────────
                    Low                           High           
                                IMPLEMENTATION COMPLEXITY         
```

### Prioritization Rankings:

| Rank | Task / Feature ID | Description | Impact | Effort | Owner Seat |
|---|---|---|---|---|---|
| **P0-1** | **MAD-I6 / R3** | **Toolbar Demotion into Floating Islands** (De-densify 13 buttons into Navigation, Mode, Action pills) | Transformative | Low-Med | PER-0755 |
| **P0-2** | **NM-T42 (Slice 1)** | **"Teach Northstar" Recurring Workflow Loop** (Candidate learning $\rightarrow$ template suggestion $\rightarrow$ 1-click fill) | Core Thesis | Medium | PER-0172 |
| **P0-3** | **R5 (Headline)** | **The "Won't-Change Map" Non-Disturbance Overlay** (Visual proof of zero unintended modifications) | B2B Wedge | Low | PER-0436 |
| **P1-1** | **MAD-I7 / R3** | **Two-Tier Inspector Hierarchy** (Immediate Action Cards on top; disclosure groups for geometry/evidence) | High Usability | Low | PER-0755 |
| **P1-2** | **EXP-1** | **CoreSpotlight Native Deep-Indexing Substrate** (macOS Spotlight search jumping to PDF coordinates) | Native Citizen | Medium | PER-PDEV-0149 |
| **P1-3** | **NM-T47** | **Publication-Path Stamp Unification** (Merge/split with interactive annotation/stamp preservation) | Core Robustness| Medium | PER-PDEV-0149 |
| **P2-1** | **EXP-3** | **Degraded Real-World OCR Benchmark Hardening** (5-profile adversarial test corpus with WER gates) | Quality Proof | Medium | PER-91013 |
| **P2-2** | **NM-T43 (Slice 2)**| **Omnibox Goal Capture with Ranked Fallback** (Goal intent input degrading honestly to commands) | Long-Term UI | Medium | PER-0172 |

---

## 5. Actionable 3-Sprint Execution Sequence

### Sprint 1: The Modern Workspace & Chrome Restructuring (Days 1–5)
- **Target:** Transform the physical feel from a 2004 reader into an elevated macOS Sequoia/Tahoe desktop canvas.
- **Deliverables:**
  1. Refactor `ContentView.swift` toolbar: Extract 3 floating islands (`NavigationIslandView`, `ModeSelectorIslandView`, `ActionIslandView`).
  2. Implement Two-Tier Inspector in `ContextualInspectorView.swift`: Pinned high-priority cards for active candidate/field, with secondary forensic details under clean `DisclosureGroup`s.
  3. Render the **"Won't-Change Map"** visual overlay toggle in Review mode.

### Sprint 2: The AI-Native Spine & "Teach Northstar" Loop (Days 6–10)
- **Target:** Execute D-083 Slice 1 (`NM-T42`) and beat the manual path on recurring documents.
- **Deliverables:**
  1. Build persistent `AgentSpineView` collateral to the document canvas (replacing the modal plan sheet).
  2. Wire `CandidateReviewLearningEventStore` into automatic template candidate generation.
  3. Benchmark test at $n=1$: Verify recurring invoice / form completion takes $<2$ minutes and is faster than Guided Next Blank.

### Sprint 3: Deep macOS Integration & Commercial Packaging (Days 11–15)
- **Target:** Prepare distribution-ready artifacts and system integration.
- **Deliverables:**
  1. Implement `NorthstarSpotlightIndexer` (`CoreSpotlight` deep links into PDF page bounding boxes).
  2. Unify publication path (`NM-T47`) for signed/stamped multi-page exports.
  3. Wire Lemon Squeezy / Paddle license key validator with offline grace period.

---

## 6. Lead Recommendation & Reconciled Verdict

**Lead Verdict (PER-0926):**  
The council unanimously ratifies this plan:
1. We **reject** both extremes: we refuse to merely re-skin existing cluttered toolbars, and we refuse to build an agent loop that hides inside a clunky modal sheet.
2. We sequence **Toolbar Islands + Inspector Hierarchy (Sprint 1)** immediately followed by **Persistent Agent Spine & Teach Northstar (Sprint 2)**.
3. We introduce the **Won't-Change Map** as Northstar's defining product wedge—establishing verifiable cryptographic and geometric proof of non-disturbance.
