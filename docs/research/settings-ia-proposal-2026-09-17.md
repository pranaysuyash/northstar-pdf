# Settings IA Proposal — 2026-09-17 (MAD-R7)

**Current state (verified):** Settings (⌘,) has three tabs — General, Governance
(`checkmark.shield`), Companion Health (`heart.text.square`) — fixed 580×480 frame
(`ContentView.swift:2318-2340`). The lens is dev-era: the reading/export/agent surfaces a paying
user touches daily have no home, while two internal-infrastructure tabs sit at the same level.

**Principle:** Settings should be organized by what the *user* tunes, not by what the *architecture*
owns. Governance and Companion Health are real, but they are advanced/operational surfaces.

## Proposal

| Proposed tab | Contents | Notes |
|---|---|---|
| **General** | (existing) + appearance/theme, high-contrast toggle | Keep; absorb system-contrast merge from MAD-I9 |
| **Reading** *(new)* | Default reading mode (Study/Skim/Reference/Review), default zoom + scale mode, page-transition behavior, thumbnail rail density | The ⌘1–4 + zoom defaults currently live only in-session |
| **Export** *(new)* | Default export profile (edited/sanitized/page-extraction), output-naming pattern, post-export action (reveal in Finder / Share) | Directly strengthens the export-only model's daily loop |
| **Agent & Suggestions** *(new)* | Palette behavior, field-suggestion aggressiveness, learned-calibration visibility + per-document reset | The Stage-1 learning loop (`candidatePriors`) is currently user-invisible |
| **Advanced** *(new group)* | Governance + Companion Health (existing tabs, visually demoted) | Same content, correct altitude |

## Sequencing

- This is a proposal, not a commitment — MAD-D-listed decision, rides the paid-early-access
  persona work. No code change in this session.
- When built, drop the fixed `.frame(width: 580, height: 480)` (also a localizability hazard —
  see the survey).
- **One-sentence test for every new setting:** "would a cohort user plausibly change this in week
  one?" If not, it stays out of Settings (Developer surface) — the anti-pattern being avoided is
  settings-as-debug-panel, which is the current Governance-tab failure mode.
