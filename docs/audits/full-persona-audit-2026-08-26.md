# Full Persona Audit — 2026-08-26

> **SUPERSEDED IN PART — 2026-08-26 (PER-0428 doctrine-alignment audit).**
> This document predates same-day gate updates and contains stale status
> claims. Specifically: the "FAIL Gates" table records RG-001 as `FAIL`, but
> `docs/release-gates.md` shows RG-001 as `PARTIAL` with delivered evidence
> (incremental writer, appearance streams, compressed-object corpus support).
> **The release-gate registry is the sole authority for gate status** (see
> decision record D-055). Its remaining task priorities were folded into
> `docs/roadmaps/implementation-plan-2026-08-26.md`. Retained as historical
> evidence; do not cite its status tables.

**Scope:** Native macOS app + web companion, all source files, design docs, release gates
**Personas applied:** Researcher, Security Auditor, Reviewer, Design Doc Reviewer, Test Writer, Implementer

---

## Researcher — Codebase Recon

| Metric | Value |
|---|---|
| Swift files | 91 |
| JS files | ~50 app + node_modules |
| CSS files | 11 |
| HTML files | 16 |
| Swift modules | 10 (App, Core, Recovery, Contract, Parity×2, Benchmark×3, Interruption) |
| Test files | 25 Swift, 78 JS |
| Test functions | 170 Swift |
| Open TODOs (Swift + app.js) | 0 |
| Release gates OPEN | 8 |
| Release gates FAIL | 1 (RG-001: AcroForm) |
| Release gates PARTIAL | 14+ |

**Architecture:** SwiftUI @Observable AppModel → PDFEditorCore (PDFKit provider, region detection, incremental form writer) → PDFEditorRecovery (session persistence, autosave, markdown-to-PDF) → PDFEditorApp (views, toolbar, inspector). Web companion mirrors core via JS modules.

---

## Security Auditor — Findings

| # | Severity | Category | Location | Finding |
|---|---|---|---|---|
| 1 | informational | Force unwrap | `PDFOCRBenchmark/main.swift:161` | `try!` in benchmark code — acceptable, not production path |
| 2 | informational | fatalError | `DocumentCanvasView.swift:262` | Standard `init(coder:)` fatalError — SwiftUI convention |
| 3 | clean | Secrets | All source | No hardcoded secrets, keys, or credentials found |
| 4 | clean | XSS | web/app.js | All 731 innerHTML uses are `innerHTML = ""` (clearing) — no user input interpolation |
| 5 | clean | eval | web/ | Only in vite node_modules, not app code |
| 6 | clean | Passwords | ContentView + PDFKitProvider | SecureField used for input, password passed as parameter (not stored), proper validation |

**Verdict:** Clean. No exploitable vulnerabilities found.

---

## Reviewer — Code Review

| # | Severity | Location | Finding | Status |
|---|---|---|---|---|
| 1 | MEDIUM | SecurityVaultSheet:313 | Sorting in body — `.sorted()` on every body eval | ✅ FIXED (cached) |
| 2 | MEDIUM | AppModel:1816 | `activeCandidates` filters on every access | ✅ FIXED (cached with didSet) |
| 3 | LOW | ContentView:149, Inspector:155 | `operations.filter` in body | ✅ FIXED (redactionMarkCount) |
| 4 | LOW | ContextualInspectorView:486 | ForEach `.offset` identity | ✅ FIXED (prior session) |

---

## Design Doc Reviewer — Release Gate Status

### OPEN Gates (blocking release)
| ID | Gate | What's needed |
|---|---|---|
| RG-005 | Authored tag-tree preservation | Source structure tree preserved or rejected with evidence |
| RG-006 | Native VoiceOver workflow | VoiceOver covers all reader controls, errors, navigation |
| RG-007 | Browser screen-reader workflow | Screen-reader covers landmarks, text layer, search, status |
| RG-029 | Crash and recovery behavior | Import, render, worker, export failures recover safely |
| RG-043 | Search status announcements | Match counts, current result, no-match state announced |
| RG-052 | Accessibility source fidelity | Source structure preserved or marked unavailable |
| RG-057 | Focus restoration | Focus returns after modal, search, link, error, jump |
| RG-058 | Reduced motion | Motion preferences respected across transitions |
| RG-059 | Zoom and responsive layout | 200% zoom, large text, narrow windows usable |

### FAIL Gates
| ID | Gate | Status |
|---|---|---|
| RG-001 | Public AcroForm fidelity | FAIL — form-aware writer still required |

---

## Test Writer — Coverage Gaps

| Area | Coverage | Gap |
|---|---|---|
| Swift core | 164/164 pass | ✅ Solid |
| Swift recovery | Tests exist | ✅ Covered |
| Web E2E | 16 tests written | ⏳ Needs Playwright + server |
| Markdown-to-PDF | No dedicated tests | ⚠️ Should add unit tests |
| Rubber-band scroll | No tests | ⚠️ JS feature, no test framework |
| Keyboard shortcuts | No dedicated tests | ⚠️ Could add integration tests |

---

## Implicit Tasks (from context + doctrines)

1. **RG-001 fix:** AcroForm editing rejection is correct behavior; gate needs evidence update, not code fix
2. **Markdown-to-PDF tests:** Add unit tests for the renderer
3. **Web E2E setup:** Get Playwright running in CI
4. **VoiceOver labels:** Add remaining accessibility labels for RG-006
5. **Reduced motion:** Ensure `prefers-reduced-motion` is respected (RG-058)
6. **Focus restoration:** After sheets/modals (RG-057)

---

## Prioritized Task List (Implementer)

| # | Priority | Task | Persona | Gate |
|---|---|---|---|---|
| 1 | HIGH | Add prefers-reduced-motion CSS + SwiftUI support | Security + Accessibility | RG-058 |
| 2 | HIGH | Add VoiceOver labels to remaining controls | Accessibility | RG-006 |
| 3 | MEDIUM | Add focus restoration after sheet dismiss | Accessibility | RG-057 |
| 4 | MEDIUM | Add markdown-to-PDF unit tests (TDD) | Test Writer | Coverage |
| 5 | MEDIUM | Add web search status announcements (ARIA live region) | Accessibility | RG-043, RG-007 |
| 6 | LOW | Update RG-001 evidence (rejection IS the correct behavior) | Design Doc | RG-001 |
| 7 | LOW | Add keyboard shortcut tests | Test Writer | Coverage |
