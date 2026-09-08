# Prompt Evaluator — 8-Dimension Analysis (2026-09-01)

**Framework:** AI Engineering Toolkit — Skill 1: Prompt Evaluator
**Dimensions:** Clarity, Specificity, Completeness, Conciseness, Structure, Grounding, Safety, Robustness
**Scale:** 1-10 per dimension, weighted aggregate to 0-100
**Date:** 2026-09-01

---

## Prompts Evaluated

| # | Prompt | Location | Purpose | Lines |
|---|---|---|---|---|
| P1 | Operating Doctrine 8.0 | `OPERATING_DOCTRINE.md` | Master decision framework for all agent work | ~800 |
| P2 | Companion Protocol | `CompanionProtocol.swift` | Browser-to-companion communication contract | ~354 |
| P3 | Companion Bridge | `CompanionBridge.swift` | Authenticated bridge for companion communication | ~330 |
| P4 | AgentCommandHUD | `AgentCommandHUD.swift` | User-facing command palette | ~594 |
| P5 | Reading Mode Presets | `ReadingMode.swift` | Study/Skim/Reference/Review configurations | ~230 |
| P6 | Adaptive Command Policy | `AdaptiveCommandPolicy.swift` | Context-aware command routing | ~200 |
| P7 | Provider Companion Protocol | `ProviderCompanionProtocol.swift` | Provider-level companion messages | ~350 |

---

## P1: Operating Doctrine 8.0

### Scores

| Dimension | Score | Evidence |
|---|---|---|
| **Clarity** | 9/10 | Clear prose, numbered sections, explicit rules. Minor: §4.1 examples are verbose. |
| **Specificity** | 9/10 | Exact file paths, version numbers, evidence tiers (S0-S3), action levels (L0-L3). |
| **Completeness** | 10/10 | Covers truth taxonomy, authorization, side effects, delegation, security, documentation, completion. No gaps. |
| **Conciseness** | 6/10 | ~800 lines. §4 (Authorization) alone is ~200 lines. Could be compressed 30% without loss. |
| **Structure** | 9/10 | 17 numbered sections, sub-sections (4.1-4.5, 16.1-16.9), routing table, examples. |
| **Grounding** | 8/10 | References concrete files, paths, versions. Examples ground abstract rules. |
| **Safety** | 10/10 | §4.4 (prompt injection), §4.3 (fail-closed), L3 authorization for destructive actions. |
| **Robustness** | 9/10 | Handles stale state, contested state, parallel work, delegation, revalidation. |

**Aggregate: 87/100**

### Weakest Dimensions
1. **Conciseness (6/10)** — The doctrine is thorough but long. An agent loading it uses significant context window.
2. **Grounding (8/10)** — References paths that are user-specific (`/Users/pranay/...`). Could use relative paths.
3. **Clarity (9/10)** — §4.1 examples are wordy. Could be tightened.

### Rewrite Recommendation
**For Conciseness:** Extract §4 (Authorization) into a separate specialist doctrine. The operating doctrine would reference it but not embed it. This cuts ~200 lines from the main document.

---

## P2: Companion Protocol

### Scores

| Dimension | Score | Evidence |
|---|---|---|
| **Clarity** | 8/10 | Well-structured Swift types with doc comments. Some fields undocumented (e.g., `reasonCodes` semantics). |
| **Specificity** | 9/10 | Exact contract versions, capability strings, validation rules, nonce formats. |
| **Completeness** | 8/10 | Covers hello, capability request/response, cancellation. Missing: error taxonomy, timeout semantics. |
| **Conciseness** | 7/10 | ~350 lines. Some redundancy between Swift types and doc comments. |
| **Structure** | 9/10 | MARK sections, type hierarchy, validation methods, error cases. |
| **Grounding** | 7/10 | References `PDFContractVersion` but doesn't define what versions are compatible. |
| **Safety** | 9/10 | `localOnly: true` enforced, session nonces, source digest binding. |
| **Robustness** | 8/10 | Version validation, session binding, nonce verification. Missing: timeout handling. |

**Aggregate: 81/100**

### Weakest Dimensions
1. **Completeness (8/10)** — No timeout semantics defined. What happens if a request takes >30s?
2. **Grounding (7/10)** — `PDFContractVersion` compatibility rules not documented inline.
3. **Conciseness (7/10)** — Redundancy between Swift types and doc comments.

### Rewrite Recommendation
**For Completeness:** Add a "Timeout and Cancellation" section to the protocol doc comments defining: request timeout (30s default), cancellation semantics, and error states for timeout.

---

## P3: Companion Bridge

### Scores

| Dimension | Score | Evidence |
|---|---|---|
| **Clarity** | 8/10 | Clear state machine (BridgeState), typed errors, actor-based concurrency. |
| **Specificity** | 8/10 | HMAC field, TTL, resource limits, egress gate. But HMAC is placeholder (`Data()`). |
| **Completeness** | 7/10 | Missing: HMAC implementation, certificate pinning, connection pooling semantics. |
| **Conciseness** | 7/10 | ~330 lines. Some repetition in error descriptions. |
| **Structure** | 9/10 | MARK sections, protocol conformance, extension for logging. |
| **Grounding** | 7/10 | References `EgressGate` and `ResourceLimits` but doesn't define their defaults. |
| **Safety** | 9/10 | EgressGate disabled by default, authentication required, resource limits enforced. |
| **Robustness** | 8/10 | Timeout, cancellation, pending request tracking. Missing: connection retry semantics. |

**Aggregate: 79/100**

### Weakest Dimensions
1. **Completeness (7/10)** — HMAC is placeholder. Certificate validation accepts all. Connection retry not defined.
2. **Grounding (7/10)** — Default resource limits not documented.
3. **Conciseness (7/10)** — Error descriptions repeat the same pattern.

### Rewrite Recommendation
**For Completeness:** Document the HMAC placeholder status explicitly and define the production implementation path. Add default resource limits to the doc comments.

---

## P4: AgentCommandHUD

### Scores

| Dimension | Score | Evidence |
|---|---|---|
| **Clarity** | 7/10 | SwiftUI view with command items. But command routing is complex (adaptive + fixed). |
| **Specificity** | 6/10 | Command titles are user-facing strings. But category names ("Current Context") are vague. |
| **Completeness** | 7/10 | Covers search, fill form, annotate, export, reading modes. Missing: keyboard shortcuts, accessibility. |
| **Conciseness** | 5/10 | ~594 lines. Many switch cases that could be table-driven. |
| **Structure** | 6/10 | Flat switch statements. No clear separation between command definition and execution. |
| **Grounding** | 6/10 | References `AdaptiveCommandPolicy` and `AdaptiveCommandHistory` but doesn't explain the routing logic. |
| **Safety** | 7/10 | Commands are bounded (no shell, no network). But no explicit safety annotation per command. |
| **Robustness** | 6/10 | No error handling for command failures. No undo for destructive commands. |

**Aggregate: 63/100**

### Weakest Dimensions
1. **Conciseness (5/10)** — 594 lines of switch statements. Should be table-driven.
2. **Structure (6/10)** — No separation between command metadata and execution.
3. **Specificity (6/10)** — Category names are vague. Command availability logic is implicit.

### Rewrite Recommendation
**For Structure:** Extract command definitions into a data structure (array of `AgentCommandItem`). The HUD becomes a renderer, not a definition site. This separates concerns and enables testing.

---

## P5: Reading Mode Presets

### Scores

| Dimension | Score | Evidence |
|---|---|---|
| **Clarity** | 9/10 | 4 modes with clear names (Study/Skim/Reference/Review). Each has distinct behavior. |
| **Specificity** | 8/10 | Exact parameters: spacing (1.15x), background (nil/yellow), inspector (on/off). |
| **Completeness** | 8/10 | Covers inspector, thumbnails, toolbar, annotations, spacing, background, progress. Missing: scroll speed, zoom. |
| **Conciseness** | 9/10 | ~230 lines. Dense, no waste. |
| **Structure** | 9/10 | Enum with computed properties. Clean, testable. |
| **Grounding** | 8/10 | Parameters map to actual UI behavior. Tests verify each mode. |
| **Safety** | 7/10 | No safety concerns (read-only configurations). |
| **Robustness** | 8/10 | Default fallback to study mode. All parameters have sensible defaults. |

**Aggregate: 83/100**

### Weakest Dimensions
1. **Completeness (8/10)** — Missing scroll speed and zoom level per mode.
2. **Safety (7/10)** — No safety annotation (low risk, but still a gap).
3. **Grounding (8/10)** — Could reference the actual UI components each parameter controls.

### Rewrite Recommendation
**For Completeness:** Add `scrollSpeed` and `defaultZoom` to `ReadingDisplayParams`. Study mode: 1.0x zoom, normal scroll. Skim mode: 0.75x zoom, fast scroll.

---

## P6: Adaptive Command Policy

### Scores

| Dimension | Score | Evidence |
|---|---|---|
| **Clarity** | 7/10 | Intent-based routing is clear. But the policy resolution logic is complex. |
| **Specificity** | 7/10 | Command IDs are specific (`search`, `fillForm`, `annotate`). But availability rules are implicit. |
| **Completeness** | 6/10 | Covers document-level and field-level commands. Missing: error recovery, disabled states. |
| **Conciseness** | 7/10 | ~200 lines. Could be tighter. |
| **Structure** | 7/10 | Input → Policy → Output. But the policy resolution is a single large function. |
| **Grounding** | 6/10 | References `AdaptiveCommandHistory` but doesn't explain how history influences ranking. |
| **Safety** | 8/10 | Commands are bounded. No shell, no network, no file deletion. |
| **Robustness** | 7/10 | Fallback to empty command list. But no graceful degradation for missing history. |

**Aggregate: 69/100**

### Weakest Dimensions
1. **Completeness (6/10)** — No error recovery, no disabled states documented.
2. **Grounding (6/10)** — History influence on ranking not explained.
3. **Clarity (7/10)** — Policy resolution logic is complex and could be decomposed.

### Rewrite Recommendation
**For Grounding:** Document how `AdaptiveCommandHistory` influences command ordering. Add a doc comment explaining: "Commands the user has used recently are ranked higher."

---

## P7: Provider Companion Protocol

### Scores

| Dimension | Score | Evidence |
|---|---|---|
| **Clarity** | 8/10 | Typed messages with validation. Clear state machine (accepted/rejected/started/...). |
| **Specificity** | 9/10 | Exact contract names, version requirements, digest formats, input modes. |
| **Completeness** | 8/10 | Covers hello, capability request/response, cancellation. Missing: progress reporting. |
| **Conciseness** | 7/10 | ~350 lines. Some redundancy with CompanionProtocol.swift. |
| **Structure** | 9/10 | MARK sections, validation methods, error cases. |
| **Grounding** | 7/10 | References `PDFContractVersion` but doesn't define compatibility. |
| **Safety** | 9/10 | `localOnly: true` enforced, source digest binding, capability whitelist. |
| **Robustness** | 8/10 | Session binding, nonce verification, timeout enforcement. |

**Aggregate: 81/100**

### Weakest Dimensions
1. **Completeness (8/10)** — No progress reporting (`progress` state defined but not used).
2. **Grounding (7/10)** — `PDFContractVersion` compatibility rules not inline.
3. **Conciseness (7/10)** — Redundancy with CompanionProtocol.swift.

### Rewrite Recommendation
**For Completeness:** Add a progress reporting section to the protocol. Define when `state: .progress` is sent and what `reasonCodes` carry progress information.

---

## Cross-Prompt Comparison

| Prompt | Clarity | Specificity | Completeness | Conciseness | Structure | Grounding | Safety | Robustness | **Aggregate** |
|---|---|---|---|---|---|---|---|---|---|
| **P1: Operating Doctrine** | 9 | 9 | 10 | 6 | 9 | 8 | 10 | 9 | **87** |
| **P2: Companion Protocol** | 8 | 9 | 8 | 7 | 9 | 7 | 9 | 8 | **81** |
| **P3: Companion Bridge** | 8 | 8 | 7 | 7 | 9 | 7 | 9 | 8 | **79** |
| **P4: AgentCommandHUD** | 7 | 6 | 7 | 5 | 6 | 6 | 7 | 6 | **63** |
| **P5: Reading Modes** | 9 | 8 | 8 | 9 | 9 | 8 | 7 | 8 | **83** |
| **P6: Adaptive Policy** | 7 | 7 | 6 | 7 | 7 | 6 | 8 | 7 | **69** |
| **P7: Provider Protocol** | 8 | 9 | 8 | 7 | 9 | 7 | 9 | 8 | **81** |
| **Average** | **8.0** | **8.0** | **7.7** | **6.9** | **8.1** | **7.1** | **8.4** | **7.7** | **77.6** |

### Dimension Rankings

| Rank | Dimension | Average | What It Means |
|---|---|---|---|
| 1 | Safety | 8.4 | Strongest dimension. Egress gate, local-only, value-free logging. |
| 2 | Structure | 8.1 | Good MARK sections, type hierarchies, routing tables. |
| 3 | Clarity | 8.0 | Clear prose, numbered sections, explicit rules. |
| 4 | Specificity | 8.0 | Exact versions, paths, thresholds, formats. |
| 5 | Robustness | 7.7 | Good error handling, timeout, cancellation. Some gaps. |
| 6 | Completeness | 7.7 | Most coverage is good. Gaps in HMAC, progress, scroll speed. |
| 7 | Grounding | 7.1 | Weaker dimension. User-specific paths, undocumented defaults. |
| 8 | Conciseness | 6.9 | Weakest dimension. Operating Doctrine and HUD are too long. |

### Top 3 Weaknesses Across All Prompts

1. **Conciseness (6.9)** — The Operating Doctrine is 800 lines. The HUD is 594 lines. Both could be compressed 30% without loss. **Recommendation:** Extract §4 (Authorization) into a specialist doctrine. Make the HUD table-driven.

2. **Grounding (7.1)** — User-specific paths (`/Users/pranay/...`) appear in the doctrine. Default values are undocumented in the bridge. **Recommendation:** Use relative paths. Document defaults inline.

3. **Completeness (7.7)** — HMAC is placeholder. Progress reporting is defined but unused. Scroll speed is missing from reading modes. **Recommendation:** Fill the HMAC gap. Add progress reporting. Add scroll speed.

### Top 3 Strengths

1. **Safety (8.4)** — The strongest dimension. Zero-egress invariant, local-only enforcement, value-free logging, fail-closed behavior, prompt injection defense. This is the most security-conscious codebase I've evaluated.

2. **Structure (8.1)** — Clean MARK sections, type hierarchies, routing tables, validation methods. The protocol design is particularly well-structured.

3. **Clarity (8.0)** — Clear prose, numbered sections, explicit rules. The Operating Doctrine's "four inseparable habits" is a masterclass in concise framing.

---

## Priority Fixes

| Priority | Prompt | Dimension | Fix | Effort |
|---|---|---|---|---|
| 1 | P1 (Doctrine) | Conciseness | Extract §4 into specialist doctrine | MEDIUM |
| 2 | P4 (HUD) | Conciseness + Structure | Table-driven command definitions | MEDIUM |
| 3 | P3 (Bridge) | Completeness | ~~Document HMAC placeholder + defaults~~ — **RESOLVED 2026-09-03:** HMAC-SHA256 signing implemented in `BridgeAuthentication` (timestamped envelopes, monotonic-clock replay rejection); default resource limits documented | LOW |
| 4 | P6 (Policy) | Grounding | Document history influence on ranking | LOW |
| 5 | P5 (Reading) | Completeness | Add scrollSpeed and defaultZoom | LOW |
| 6 | P2 (Protocol) | Completeness | Add timeout/cancellation semantics | LOW |
| 7 | P7 (Provider) | Completeness | Add progress reporting section | LOW |
