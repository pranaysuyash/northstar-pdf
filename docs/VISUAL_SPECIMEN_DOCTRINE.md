# Visual Specimen & Design-First Operating Protocol

**Status:** Canonical Operating Directive for UI/UX Transformations  
**Effective Date:** 2026-09-24  
**Doctrine Alignment:** `OPERATING_DOCTRINE.md` v8.1 (§3 Visual-evidence sharpening & S0–S3 Sensitivity Tiers)  
**Target:** All user-facing UI modifications in Northstar PDF (`/Users/pranay/Projects/pdf_editor`)

---

## 1. The Core Mandate

> **"Before we make visual or interaction changes in the app, inspect and approve a pixel-accurate BEFORE vs. AFTER HTML specimen."**

In accordance with operator instructions and the Visual-Evidence Sharpening protocol:
1. **Never edit production SwiftUI views blindly.** No major restructuring of chrome, controls, or spatial views shall occur solely from code-level reasoning.
2. **Interactive HTML Specimen First:** Prior to code implementation, an interactive, responsive HTML/CSS specimen contrasting the current UI state (**BEFORE**) with the proposed architecture (**AFTER**) must be authored and documented.
3. **Specimen Storage & Archival:**
   - Active specimen stored in: `docs/visual_specimens/<feature>_before_after_specimen.html`
   - User-facing artifact mirrored in: `.gemini/antigravity/brain/<conversation-id>/`
4. **Inspection & Approval Gate:** The user inspects the live rendered specimen, tests interactions (segmented controls, button states, visual density), and explicitly approves the layout before native Swift engineering begins.

---

## 2. Specimen Requirements Checklist

Every Before/After visual specimen must satisfy the following criteria:
- [ ] **Accurate Baseline (BEFORE):** Faithfully mirrors the current code structure, button groupings, and known ergonomic friction (e.g. 13-element toolbar clutter).
- [ ] **Target Architecture (AFTER):** Renders the proposed macOS Sequoia/Tahoe design system (Pillars 1–4, `.ultraThinMaterial`, high-contrast hairline borders, elevated document shadows, tactile chips).
- [ ] **Toggleable Views:** Includes interactive controls (Side-by-Side, Before Only, After Only) so operators can toggle states instantly.
- [ ] **Accessibility & Keyboard Mapping:** Documents VoiceOver labels, accessibility hierarchy, and keyboard shortcut parity (`⌘K`, `⌘Z`, `⌘Return`).
- [ ] **Engineering Crosswalk:** Explicitly lists the destination files (e.g. `ContentView.swift`, `ContextualInspectorView.swift`) and models impacted.

---

## 3. Registered Specimen Inventory

| Specimen ID | Feature / Component | File Path | Status |
|---|---|---|---|
| **SPEC-01** | **MAD-I6 Toolbar Demotion into Floating Islands** | `docs/visual_specimens/toolbar_islands_before_after_specimen.html` | **Authored & Ready for Review** |
| **SPEC-02** | **MAD-I7 Two-Tier Contextual Inspector Hierarchy** | `docs/visual_specimens/inspector_hierarchy_specimen.html` | *Queued for Sprint 1* |
| **SPEC-03** | **R5 Headline: The "Won't-Change Map"** | `docs/visual_specimens/wont_change_map_specimen.html` | *Queued for Sprint 1* |
| **SPEC-04** | **D-083 Slice 1: Persistent Agent Spine** | `docs/visual_specimens/persistent_agent_spine_specimen.html` | *Queued for Sprint 2* |

