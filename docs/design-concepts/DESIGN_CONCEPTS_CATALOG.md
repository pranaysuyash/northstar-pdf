# Northstar PDF — Design Concepts Catalog & 15-Screen Audit Matrix

This catalog documents the versioned visual and architectural design concepts for Northstar PDF, capturing the evolution from standard document reader paradigms to next-generation AI-native operating environments based on the **2026-09-07 simulation runs and screen audits**.

---

## 1. Concept Generations Matrix

| Version | Design Idea & Paradigm | Visual Aesthetic | Key Role |
| :--- | :--- | :--- | :--- |
| **`v1-classic-hig`** | **Classic macOS HIG Native** | Standard macOS HIG, light grey chrome, 3-pane split (Nav / Viewport / Inspector). | Familiarity baseline, low cognitive friction. |
| **`v2-cyber-spatial`** | **Cyber Spatial Neural Canvas** | High-contrast dark acrylic glass, holographic threads, floating HUD, neon cyan/indigo accents. | Concept demonstration of interconnected knowledge graphs & mind-mapping. |
| **`v3-editorial-calm`** | **Editorial Calm & Living Margin** | Warm neutral paper, Apple New York serif typography, subtle margin annotations, minimal popovers. | High-readability long-form legal/academic review; quiet editorial AI. |
| **`v4-linear-visionos-fluid`** | **Modern Dark-Slate Spatial OS** | Obsidian & slate glass, Linear/Raycast/Arc/VisionOS aesthetic, modular card stacks, command pill (`⌘K`). | **Cutting-edge 2026 AI-native**: deconstructs flat pages into interactive computational blocks, live data charts, and dynamic streams. |

---

## 2. Complete 15-Screen Audit & Envisioned Redesign Coverage

Every single screen captured in today's audit (`docs/simulations/evidence/screen-audit-2026-09-07/`) is covered below:

| # | Screen ID & Basename | Baseline Audit Defect (2026-09-07) | Envisioned AI-Native Architecture | Concept Reference |
| :-: | :--- | :--- | :--- | :--- |
| **01** | `01_welcome_empty_state.png` | GAP-D zombie process on recent click; File > Open disabled on welcome. | **Neural Ingestion Hub**: Dropzone with drag spring animations, rendered page thumbnails, and readiness pills. | `v4/03-welcome-ingestion.jpg` |
| **02** | `02_document_complete_inspector.png` | Vertical text crush (`I\nn\ns\np\ne\nc\nt\no\nr`) due to missing `.labelsHidden()`. | **Living Form Navigator**: Floating confidence pills, auto-fill quick-selector, and biometrically gated Touch ID. | `v4/01-spatial-modular-stack.jpg` |
| **03** | `03_recovery_banner_expanded.png` | Abrupt orange banner without diff context; risk of unintended data overwrite. | **Non-Destructive Session Recovery**: Gentle banner with side-by-side diff preview and separate export copy guarantee. | `v4/04-recovery-banner.jpg` |
| **04** | `04_inspector_understand.png` | Empty placeholder ("No annotation marks yet"); single uninformative button. | **Semantic Knowledge Mesh**: Auto-generated document outline, entity extraction chips, and citation graph. | `v4/01-spatial-modular-stack.jpg` |
| **05** | `05_inspector_organize.png` | Bare action buttons ("Analyze Document") without visual page organization. | **Dynamic Page Deck & FSRS Recall**: Drag-and-drop page reordering with integrated spaced-repetition flashcard deck. | `v4/02-fluid-command-stream.jpg` |
| **06** | `06_inspector_reader.png` | Invisible hardware capabilities and missing on-device trust badges. | **Hardware Capability Passport**: Document SHA-256 fingerprint, PDF spec level, and `sandbox_net_none: ACTIVE`. | `v4/01-spatial-modular-stack.jpg` |
| **07** | `07_inspector_review.png` | Generic export options lacking integrity pre-flight checks. | **Integrity & Preflight Gate**: Checks for unsaved fields, flattened layers, metadata scrub, and export copy assurance. | `v4/02-fluid-command-stream.jpg` |
| **08** | `08_security_vault_sheet.png` | Settings sheet lacking visual hardware telemetry or proof of zero network egress. | **Hardware Trust Sphere**: Real-time Apple Silicon Secure Enclave status, AES-256-GCM keystore, and 0 KB egress monitor. | `v3/03-security-vault.jpg` & `v2/03-hardware-matrix-neon.jpg` |
| **09** | `09_security_vault_profiles.png` | Unmasked sensitive credentials; no biometric unlock trigger in list. | **Enclave Identity Profiles**: Multi-column profile manager with Touch ID unlock and visual masking (`••••-••-1234`). | `v3/02-intelligent-completion.jpg` |
| **10** | `10_security_vault_templates.png` | Blank template view without visual geometry coordinate bounds. | **Zero-Knowledge Geometry Templates**: Visual bounding-box schemas storing layout logic without storing user document bytes. | `v4/01-spatial-modular-stack.jpg` |
| **11** | `11_security_vault_audit_trail.png` | Plain text log without tamper-evident verification or cryptographic seals. | **Immutable Event Stream**: Cryptographically chained event blocks with tamper-evident SHA-256 receipts. | `v3/03-security-vault.jpg` |
| **12** | `12_agent_command_hud.png` | Basic search dialog without keyboard shortcuts or safety action badges. | **Ambient Agent Console (`⌘K`)**: Raycast-grade fuzzy palette with intent badges ("Read-Only" vs "Generates Copy"). | `v4/02-fluid-command-stream.jpg` |
| **13** | `13_visual_diff_sheet.png` | Static side-by-side view lacking synchronized scrolling and curtain controls. | **Interactive Curtain Diff**: Synchronized split-screen with interactive swipe curtain preserving bit-for-bit source integrity. | `v4/04-recovery-banner.jpg` |
| **14** | `14_document_browser_sheet.png` | Collapsed 200px sheet bug where search input collided over list items. | **Multi-Column Corpus Browser**: Fixed frame (`840x520`), tag filters, file deduplication, and thumbnail previews. | `v4/02-fluid-command-stream.jpg` |
| **15** | `15_version_history_sheet.png` | Collapsed modal sheet without visual checkpoint timeline or rollback diff. | **Document Time Machine**: Checkpoint timeline of autosave snapshots with instant preview, diffing, and one-click rollback. | `v4/04-recovery-banner.jpg` |

---

## 3. Verified Repository Assets

- **`v1-classic-hig/`**: `01-welcome-classic.jpg`, `02-workbench-classic.jpg`, `03-vault-classic.jpg`
- **`v2-cyber-spatial/`**: `01-neural-canvas-neon.jpg`, `02-form-execution-neon.jpg`, `03-hardware-matrix-neon.jpg`
- **`v3-editorial-calm/`**: `01-living-margin.jpg`, `02-intelligent-completion.jpg`, `03-security-vault.jpg`
- **`v4-linear-visionos-fluid/`**:
  - `01-spatial-modular-stack.jpg`: Modular document stack, dynamic context pillar, and semantic chips
  - `02-fluid-command-stream.jpg`: Ambient command bar (`⌘K`), fluid document stream, and live data projections
  - `03-welcome-ingestion.jpg`: Ingestion hub with drag-and-drop deconstruction & rich thumbnail recents
  - `04-recovery-banner.jpg`: Non-destructive session recovery with side-by-side diff preview

---

## 4. Interactive Testing Workbench

To inspect and interact with the redesigned screens, side-by-side audit baselines, defect ledgers, and exact SwiftUI bugfixes, open:
`envisioned_screens_workbench.html`
