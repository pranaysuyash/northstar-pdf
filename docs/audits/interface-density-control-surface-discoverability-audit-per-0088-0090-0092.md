# Interface Density, Control Surface & Capability Discoverability Audit

**Personas:** PER-0088 (Interface Density & Progressive Disclosure Architect), PER-0090 (Control Surface Architect), PER-0092 (Capability Discoverability Architect)

**Audit Date:** 2026-08-26  
**Scope:** SwiftUI views in `Sources/PDFEditorApp/`, web toolbar in `web/`, action authority matrix

---

## Executive Summary

This group audited the control surface from the perspective of interface density, progressive disclosure, keyboard/control surface discoverability, and capability exposure. The repo has a strong foundation — the 5-Tier Action Authority Matrix (PER-0927) defines what actions surface to users and at what friction level. The main gaps are at the UI layer: dense inspector panels expose all capabilities simultaneously, the web toolbar lacks a progressive disclosure layer, and keyboard shortcuts are partially documented.

---

## PER-0088 — Interface Density & Progressive Disclosure Architect

### Findings

| ID | Finding | Severity | Type |
|----|---------|----------|------|
| IDA-01 | `ContextualInspectorView.swift` renders all field properties (bounds, kind, score, evidence, provider ID) simultaneously — power-user information overloads casual users | High | Explicit |
| IDA-02 | Template match UI shows raw `familyName`, `variantName`, and confidence score together without collapsing secondary detail into an expandable disclosure group | Medium | Implicit |
| IDA-03 | The batch operations panel (merge, rotate, redact) is a flat list with no grouping by risk level (read-only vs destructive) — Tier 4 actions appear alongside Tier 0 | High | Implicit |
| IDA-04 | Preflight report surface shows all findings, including info-level items, without severity filtering | Medium | Explicit |

### Recommended Patterns

```swift
// Progressive disclosure for field inspector
DisclosureGroup("Advanced Details") {
    Text("Score: \(candidate.score, format: .percent)")
    Text("Provider: \(candidate.provider)")
    Text("Evidence: \(candidate.evidence.joined(separator: ", "))")
}
```

Batch operations panel should use a `Section` with header color-coded to authority tier:
- 🟢 Tier 0–1 (read, in-memory)
- 🟡 Tier 2 (heuristic proposal)
- 🔴 Tier 3–4 (vault/destructive)

---

## PER-0090 — Control Surface Architect

### Findings

| ID | Finding | Severity | Type |
|----|---------|----------|------|
| CSA-01 | Keyboard shortcut for "Confirm Field" is `⌘Return` but not registered in the macOS menu system — not discoverable via menu search or keyboard shortcut inspector | High | Implicit |
| CSA-02 | Tab cycling through candidates exists (per prior PER-0731 audit) but is not announced in the UI — no tooltip, no status bar hint, no onboarding cue | Medium | Explicit |
| CSA-03 | Web toolbar (PDF.js side) has no keyboard trap prevention — focus can escape the toolbar into the browser chrome on Tab keypress | Medium | Explicit |
| CSA-04 | The `AgentCommandHUD.swift` accepts freeform text commands but has no autocomplete or command palette — cognitive load is high for novice users | Medium | Implicit |
| CSA-05 | Right-click context menu on candidates only shows "Confirm" and "Reject" — missing "Skip to Next" and "View Evidence" | Low | Implicit |

### Recommendations

1. Register `⌘Return` via `Commands` in `PDFEditorApp.swift` so it appears in Edit menu.
2. Add a persistent tooltip at the bottom of the candidate rail: "Press Tab to cycle • ⌘Return to confirm".
3. Add `tabindex="0"` and `role="toolbar"` with `aria-keyshortcuts` in `web/app.js`.
4. Add command palette to `AgentCommandHUD` with prefix matching against a static command registry.

---

## PER-0092 — Capability Discoverability Architect

### Findings

| ID | Finding | Severity | Type |
|----|---------|----------|------|
| CDA-01 | New capabilities (digital signature verification, multi-engine validation, XFA detection) have no UI entry points — they exist only as Swift APIs | High | Implicit |
| CDA-02 | The provider capability manifest shows installed engines but is not surfaced anywhere in the app UI | High | Implicit |
| CDA-03 | No onboarding or contextual nudges when a user opens a form that would benefit from a capability they haven't used | Medium | Implicit |
| CDA-04 | Template matching is silently skipped when confidence < threshold — no UI feedback that a template was considered and rejected | High | Explicit |
| CDA-05 | Redaction capability (content stream redactor) has no UI surface — the only path is programmatic via `PDFContentStreamRedactor` | High | Implicit |

### Discoverability Ladder

Capabilities should be discoverable through at least one of:
1. **Menu item** (keyboard shortcut + search)
2. **Contextual toolbar button** (visible when relevant)
3. **Inspector panel entry** (when a relevant object is selected)
4. **First-run nudge** (once, if the feature is relevant to the open document)

Current coverage:
| Capability | Menu | Toolbar | Inspector | Nudge |
|-----------|------|---------|-----------|-------|
| Form fill | ❌ | ✅ | ✅ | ❌ |
| Template match | ❌ | ❌ | ✅ | ❌ |
| Digital signature | ❌ | ❌ | ❌ | ❌ |
| Redaction | ❌ | ❌ | ❌ | ❌ |
| Multi-engine validation | ❌ | ❌ | ❌ | ❌ |
| XFA detection | ❌ | ❌ | ❌ | ❌ |

---

## First Principles Alignment

| Principle | Status |
|-----------|--------|
| Progressive disclosure (Tesler's Law — complexity cannot be reduced, only moved) | ⚠️ Inspector panel violates; needs disclosure groups |
| Authority tier visible before action commit | ⚠️ Batch panel does not indicate tier |
| Every capability reachable via keyboard | ⚠️ Most new capabilities are API-only |
| Defaults to safe (low-tier) actions | ✅ 5-Tier matrix enforced in AppModel |

---

## Open Improvement Areas

1. **Command Palette (⌘K)** — A fuzzy-searchable command registry that surfaces all registered capabilities including their keyboard shortcut, authority tier badge, and last-used timestamp.
2. **Capability Inspector** — A "What can I do here?" panel that contextually shows available operations based on the selected object type and open document capabilities (AcroForm, XFA, signed, encrypted).
3. **Tier Badging** — Visual indicator (color + icon) on all action buttons showing which authority tier they invoke, so users can predict the confirmation friction before clicking.
