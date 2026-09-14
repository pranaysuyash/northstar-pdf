# Open Items, Architectural Handoff & Continuation Guide

**Repository:** `/Users/pranay/Projects/pdf_editor`  
**Date:** 2026-09-09  
**Current State:**
- **Swift Tests:** 219 native tests in 31 suites passed at 100% (0 failures).
- **Node Contract Tests:** 51/51 checks passed across web reader, template index, and capability lanes.
- **Rule Constraints:** Operating Doctrine 8.0 active; NO git commands (`git checkout`, `git reset`, `git stash`, etc. are strictly forbidden; fix code directly in place); immutable source preservation.

---

## 1. Overview & Context

This document is the authoritative continuation guide for any agent or developer picking up work on `/Users/pranay/Projects/pdf_editor`. It records the exact status of the system, all open items, decisions, and the implementation roadmap for wiring Core engine modules into the native macOS UI surfaces (`PL-D12`).

---

## 2. Exhaustive Classification of Open Items

### Category 1: Owner-Gated Decisions (Commercial & Distribution)
*These require external founder action/purchases outside the codebase ([`owner-decision-briefs-2026-09-07.md`](file:///Users/pranay/Projects/pdf_editor/docs/audits/owner-decision-briefs-2026-09-07.md)):*

| Item ID | Title | Summary & Decision Requirement | Status |
|---|---|---|---|
| `PL-D01` | Apple Developer Program ($99/yr) | Enrollment required for Developer ID signing (`codesign`) and notarization (`notarytool`). Unblocks distribution and dissolves ad-hoc keychain prompts (`PL-I36`). | Awaiting Owner Approval |
| `PL-D02` | Merchant of Record (Paddle vs. Lemon Squeezy) | Select MoR processor for $79 Pro / $39 renewal / $4.99 Agent+ license keys and global VAT handling. (Recommended: Paddle). | Awaiting Owner Decision |
| `PL-D03` | Early-Adopter Pricing Window Terms | Set strict reference-price window: "First 100 licenses or 30 days post-launch, whichever comes first". | Awaiting Owner Decision |

### Category 2: Native App Packaging & Platform Distribution
*Gated on PL-D01 Developer ID certificate:*

| Item ID | Title | Description | Target / File |
|---|---|---|---|
| `PL-I28` | Direct-Download DMG Packaging | Create notarized `.dmg` layout with Applications shortcut, quarantine/translocation checks, and Sparkle appcast hosting. | `docs/codesign-notarize-workflow.md` |
| `PL-I36` | Keychain Ad-Hoc Prompt Loop Hardening | Batch recovery saves in debug builds to prevent `SecurityAgent` re-prompt loops before stable signing. | `Sources/PDFEditorRecovery/AppModel.swift` |
| `PL-I34` | Multi-Display Window Placement | Ensure windows spawn on the active display and persist frame geometry across sessions. | `Sources/PDFEditorApp/PDFEditorApp.swift` |

### Category 3: Core Engine to Native UI Wiring (`PL-D12`) — COMPLETE (2026-09-09)
*Fully wired and verified into `PDFEditorApp` SwiftUI views and `AppModel.swift`:*

| Sub-item | Core Engine Module | Target UI Surface | User-Facing Action | Status |
|---|---|---|---|---|
| `PL-D12.1` | `PDFDigitalSignatureVerifier` | Review / Trust tab (`ContextualInspectorView.swift`) | Show signature validity badge, signer name, reason, tampering indicator (`isAlteredAfterSigning`), SHA-256 digest, and re-verify button. | **Completed & Verified** |
| `PL-D12.2` | `XFAFormProcessor` | Complete / Focus tab (`ContextualInspectorView.swift`) | Automatic detection on open. Shows dynamic/static badge, packet manifest, and expandable extracted XML fields with "Copy Form Dataset". | **Completed & Verified** |
| `PL-D12.3` | `PDFBatchProcessor` | Edit / Redact mode (`ContentView.swift`) | "Scan Sensitive PII" button in status toolbar scans SSNs, emails, credit cards, phones, and stages `.redactMark` operations with a 1-click "Commit Redactions" button. | **Completed & Verified** |
| `PL-D12.4` | `TableExtractor` & `TableExporter` | Understand tab (`ContextualInspectorView.swift`) | Detects tables, displays columns/rows/confidence, and offers 1-click export to CSV, JSON, or Markdown. | **Completed & Verified** |

### Category 4: Simulation & Quality Verification Gates
*Protocols defined in `docs/simulations/NATIVE-SIM-PROTOCOL.md`:*

| Item ID | Persona / Protocol | Goal |
|---|---|---|
| `PL-V05 (NS-P1)` | Maya Recurring Form Filler | Complete wedge journey: open form $\rightarrow$ fill field $\rightarrow$ export copy $\rightarrow$ verify byte-level preservation. |
| `PL-V05 (NS-P2)` | Recovery & State Integrity Auditor | Force kill process mid-edit; verify zero recovery state loss and clean resume. |
| `PL-V05 (NS-P3)` | Export Preservation Validator | Validate that unchanged pages and objects remain byte-identical with zero vector degradation. |
| `PL-V05 (NS-P4)` | Assistive-Tech Operator | Full keyboard-only (Tab/⌘Return) navigation and VoiceOver accessibility announcement validation. |
| `PL-V05 (NS-P5)` | Air-Gap Forensics Auditor | Run `tools/airgap-watch.mjs` during high-volume document sessions to prove 0 socket/network connections occur. |

---

## 3. Continuation Instructions for Any Agent

1. **Do Not Run Git Commands:** The user has an explicit rule forbidding git operations. Never run `git checkout`, `git reset`, `git stash`, etc.
2. **Preserve Tests Green:** Always run `swift test --filter ComprehensivePersonaAuditProgramTests` and `swift test` to ensure 100% pass rate.
3. **Execution Sequence for `PL-D12`:**
   - **Step 1:** In `Sources/PDFEditorRecovery/AppModel.swift`, expose properties and methods for signature verification (`verifySignatures()`), XFA inspection (`inspectXFA()`), PII scanning (`scanDocumentPII()`), and table extraction (`extractTables()`).
   - **Step 2:** In `Sources/PDFEditorApp/ContextualInspectorView.swift`:
     - In Review/Trust tab: add `digitalSignatureSection`.
     - In Complete/Focus tab: add `xfaInspectionSection`.
     - In Understand tab: add `tableExtractionSection`.
   - **Step 3:** In `Sources/PDFEditorApp/ContentView.swift`:
     - In Redact toolbar / panel: add `scanPIIButton` that populates redaction marks from `PDFBatchProcessor`.
   - **Step 4:** Add automated tests in `Tests/PDFEditorCoreTests/` verifying the end-to-end integration contracts.
