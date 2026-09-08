# First-Principles & Doctrine-Aligned Exploration: The Northstar Contextual Inspector

> **Status:** Exploration & Architecture Discovery  
> **Target Surface:** `ContextualInspectorView.swift`, `DocumentCanvasView.swift`, `AppModel.swift`  
> **Parent Doctrines:** `OPERATING_DOCTRINE.md` (v8.0 §2, §3, §8, §10, §12), `EXPLORATION_DOCTRINE.md` (v1.1), `ARCHITECTURE_DOCTRINE.md`  
> **Date:** September 2026  

---

## 1. Executive Intent & Root Problem

### The User Critique
> *"what this card should actually be: Option A (Context-Aware Document Overview) vs Option B (True Contextual Selection)... should be done as per long term 1st principles and doctrines aligned so maybe both, maybe something else etc... needs to be explored first, documented"*

### The Core Tension
In early iterations, the inspector header was an unclassified hybrid: a static diagnostic box dumping internal engine telemetry (`PROVIDER: PDFKit`, `CONFIDENCE: Source inspection`) into the primary visual reading plane.

When proposing a replacement, a false dichotomy emerged:
* **Option A (Persistent Document Header):** Keep a permanent document-level summary card at the top of the inspector at all times.
* **Option B (Pure Selection Inspector):** Hide document details completely when unselected; show only property controls when an item on canvas is selected.

A first-principles inquiry reveals that **both options are incomplete in isolation**. Document work on macOS is neither pure document metadata viewing nor pure micro-property editing. It is an **adaptive spatial workflow** spanning distinct cognitive postures.

---

## 2. First-Principles Deconstruction (Stripping Nouns to Primitives)

Following `EXPLORATION_DOCTRINE §Kernel` (Habit 2: *Strip nouns to primitives*), we break down the inspector into fundamental human-computer primitives:

```
┌────────────────────────────────────────────────────────────────────────┐
│                          INSPECTOR PRIMITIVES                          │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Scope Primitive      │ Document Scope (Global) vs Entity (Local)    │
│ 2. Epistemic Primitive  │ Surface Value → Semantic Meaning → Provenance│
│ 3. Cognitive Posture    │ Reading → Authoring → Auditing/Review        │
│ 4. Density Primitive    │ Ambient Calm → Interactive Focus → Deep Data │
└────────────────────────────────────────────────────────────────────────┘
```

### Primitive 1: Scope (Global Document vs Local Selection)
* **Global Scope (`Selection == None`):** The user's mental model is the *document as an entity*. Questions: *What document is this? How long is it? Is it signed? Does it have fillable fields? Is it read-only?*
* **Local Scope (`Selection == Entity(id, kind)`):** The user's mental model shifts to the *selected artifact*. Questions: *What field is this? What is its value? Can I type here? What format is expected?*

### Primitive 2: Epistemic Depth & Truth Taxonomy (Operating Doctrine §2)
Information about a document or field exists at three distinct epistemic tiers:
1. **Tier 1 (Surface / Actionable):** Human-facing truth needed to make the next decision (*Field: "Applicant Full Name"*, *Current Value: "Jane Doe"*, *Status: Unfilled*).
2. **Tier 2 (Semantic / Probabilistic):** System inferences and heuristics (*"Detected via AcroForm dictionary"*, or *"OCR text match with 98% visual confidence"*).
3. **Tier 3 (Cryptographic / Forensic Provenance):** Strict data origin and ledger hashes (*Parser: PDFKit/CoreGraphics*, *Byte Offset: 0x004A2F*, *SHA-256 Digest: 8a3f...*, *TCC Sandbox: Read-Only*).

**The Architectural Bug:** The previous UI surfaced **Tier 3 (Forensic Provenance)** in the **Tier 1 (Actionable Surface)** location, creating cognitive fatigue without adding task value.

### Primitive 3: Cognitive Modes & Capability Routing (Operating Doctrine §8)
The user selects top-level modes based on Job-To-Be-Done (JTBD):
* **`Complete`**: Focus on filling form fields, signing, and exporting.
* **`Understand`**: Focus on document structure, outlines, tables, semantic entities, and AI summaries.
* **`Organize`**: Focus on page rotation, page ordering, insertion, and splits.
* **`Reader`**: Focus on uninterrupted typographic consumption and text flow.
* **`Review`**: Focus on security posture, privacy preflight, hash verification, and audit ledgers.

---

## 3. Negative Space Analysis (What is Missing or Contradictory?)

| Current Interface State | What is Missing? | The Cognitive Friction |
| :--- | :--- | :--- |
| **Nothing selected on canvas** | The inspector has no clear primary mission; it shows a static overview, then empty suggestions below. | User feels the inspector is "taking up space without doing anything." |
| **Field selected on canvas** | The canvas draws an inline editor, but the inspector sidebar keeps displaying the top document card while showing an unintegrated edit box at the bottom. | Visual fragmentation: attention is split between canvas, bottom of inspector, and top of inspector. |
| **OCR / Vision Suggestion selected** | User cannot tell *why* this box exists or whether it's safe to accept. | Ambiguity between native AcroForm certainty and probabilistic heuristic extraction. |
| **Auditing / Verification** | Forensic data is either hidden or was previously splattered into the regular view. | No dedicated, elegant home for verifiable cryptographic evidence. |

---

## 4. Architectural Alternatives Exploration

### Architecture Model 1: The Unified Adaptive Context Morph (Recommended)
Instead of an either/or choice, the inspector uses a **spring-animated semantic morphing container**:

```
State A: Selection == None (Document Posture)
┌────────────────────────────────────────────────────────┐
│ 📄 public-sample-form.pdf                        Page 1│
│ 163 chars · Letter (612×792)            ● Ready to fill│
├────────────────────────────────────────────────────────┤
│ ⚡ QUICK ACTIONS                                        │
│ [ ✍️ Fill 6 Fields ]    [ 🖋️ Sign ]    [ 🔍 Scan OCR ] │
├────────────────────────────────────────────────────────┤
│ 📋 DETECTED FIELDS (6)                                 │
│  ☑ applicant.name                (Unfilled)          › │
│  ☑ applicant.notes               (Unfilled)          › │
│  ☑ applicant.subscribe           (Off)               › │
└────────────────────────────────────────────────────────┘

        ▼  User taps "applicant.name" on canvas or list

State B: Selection == Field (Entity Property Posture)
┌────────────────────────────────────────────────────────┐
│ ‹ Back to Document                    FIELD INSPECTOR  │
├────────────────────────────────────────────────────────┤
│ 🏷️ applicant.name                           Page 1 · Text│
│ "Applicant Full Name"                                  │
├────────────────────────────────────────────────────────┤
│ VALUE ENTRY                                            │
│ [ Jane Doe                                           ] │
│ 🪄 Autofill Match: "Jane Doe" (from Profile Vault)     │
├────────────────────────────────────────────────────────┤
│ ℹ️ DETAILS & ORIGIN (Progressive Disclosure)          │
│ Native AcroForm Widget · Single-line Text              │
│ ↳ View Provenance & Byte Coordinates ›                 │
└────────────────────────────────────────────────────────┘
```

#### Why Model 1 Aligns with Long-Term Principles:
1. **Never Dead Space:** When nothing is selected, the inspector provides a meaningful overview and acts as a **Field Navigator** (jumping to any field on click).
2. **Contextual Focus:** The moment a field is tapped, the inspector morphs to serve *that specific field*, eliminating distance between canvas action and property controls.
3. **Progressive Disclosure:** Provenance (Tier 3) is one click away via a subtle disclosure link, but never clutters normal interaction.

---

### Architecture Model 2: The Two-Zone Split (Permanent Header + Dynamic Body)
* **Top Zone (Fixed 72pt Glass Bar):** Always shows document identity, total pages, and overall document progress (`4/6 fields completed`).
* **Bottom Zone (Dynamic Canvas):**
  * When `Selection == None`: Displays Authoring Tools, Field List, and Page Overview.
  * When `Selection == Field`: Displays Field Properties and Value Editor.

#### Trade-Off Analysis:
* *Strength:* Document identity is never lost from view.
* *Weakness:* Takes up 72pt of vertical height on laptops (13" MacBook Air) where vertical space is at a premium.

---

### Architecture Model 3: Mode-Gated Specialization (Capability Routing §8)
The inspector layout is determined strictly by the top Segmented Control:
* In **`Complete`**: Pure field filling, tab-order navigation, and signature capture. (Zero technical telemetry).
* In **`Understand`**: Document outline tree, table extractions, key-value entity pairs.
* In **`Organize`**: Page thumbnail grid, rotate/delete tools, PDF page geometry boxes (MediaBox, CropBox).
* In **`Reader`**: Inspector auto-collapses or shows typographic settings (font scaling, column view, dark mode inverter).
* In **`Review`**: The **exclusive home of technical telemetry**: cryptographic SHA-256 digests, AcroForm vs PDFKit provider attribution, sandbox bounds, mutation ledger diffs, and export signing certificates.

#### Trade-Off Analysis:
* *Strength:* Complete separation of concerns. Regular users never see developer telemetry; auditors and security engineers have a rich, dedicated cockpit in `Review`.
* *Doctrine Harmony:* Perfectly reflects Operating Doctrine §8 ("Capability Routing") and §12 ("Privacy & Security verification").

---

## 5. Synthesis: The Converged Architecture (Model 1 + Model 3)

The ideal long-term design is a synthesis of **Model 1 (Adaptive Context Morph)** inside **Model 3 (Mode-Gated Specialization)**:

```
                                  ┌─────────────────────────────┐
                                  │      ACTIVE MODE TAB        │
                                  └──────────────┬──────────────┘
                    ┌────────────────────────────┼────────────────────────────┐
                    ▼                            ▼                            ▼
            【 Complete Mode 】          【 Understand Mode 】         【 Review Mode 】
         (Filling & Authoring)          (Structure & Entities)     (Forensics & Posture)
                    │
       ┌────────────┴────────────┐
       ▼                         ▼
 [Selection == None]     [Selection == Field]
┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│ Document Summary │    │ Field Editor     │    │ Document Outline │    │ SHA-256 Digest   │
│ Field Navigator  │    │ Value & Autofill │    │ Extracted Tables │    │ Provider Audit   │
│ Quick Actions    │    │ Format / Choices │    │ Semantic Summary │    │ Mutation Ledger  │
└──────────────────┘    └──────────────────┘    └──────────────────┘    └──────────────────┘
```

### Key Principles of the Converged Architecture:
1. **The Inspector is Never Static:** It dynamically reflects what the user is interacting with on the canvas.
2. **Provenance is Relocated, Not Destroyed:** Provider information (`PDFKit`, `Vision OCR`, `AcroForm parser`) is promoted to first-class status in the **`Review`** tab, where compliance and integrity checks belong, rather than polluting the `Complete` authoring flow.
3. **Selection Drives Focus:** When a user taps a form field, candidate, or signature region on the page, the inspector smoothly shifts to show the properties, autofill suggestions, and validators for that exact element.
4. **Desktop Ergonomics:** Smooth spring animations and keyboard shortcuts (`Tab` advances to next field, `Esc` deselects to document scope).

---

## 6. Actionable Implementation Phasing

| Phase | Deliverable | Scope & Files | Evidence & Verification Gate |
| :--- | :--- | :--- | :--- |
| **Phase 1** | **Telemetry Relocation** | Move `evidenceRail` provider data from `Complete` to `Review` tab (`ContextualInspectorView.swift`). | `Review` tab displays complete engine provenance; `Complete` tab is 100% human-focused. |
| **Phase 2** | **Document Header Card** | Implement clean, human-centered `DocumentHeaderCard` (filename, page count, fill progress, verified status). | Window screenshot on multiple PDF fixtures. |
| **Phase 3** | **Adaptive Selection Morph** | Wire `selectedField` / `selectedCandidate` to trigger smooth transition between Document Scope and Field Property Scope. | Clicking a field on canvas automatically focuses and surfaces property card in inspector. |
| **Phase 4** | **Field Navigation List** | In Document Scope, display clickable list of all detected fields with status pills (`Unfilled`, `Filled`). | Clicking any item in list scrolls canvas and focuses field. |

---

## 7. Open Questions for Review
1. Should the Field Navigator in Document Scope show all fields across the entire document, or group them page-by-page with collapsible sections?
2. When a field is focused on canvas, should the inline canvas editor remain the primary typing target while the inspector shows auxiliary helpers (autofill, format options, choices), or should typing be mirrored in both?
