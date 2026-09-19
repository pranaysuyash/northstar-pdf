# Liquid Glass (macOS 26) Migration Plan — 2026-09-17 (MAD-R3)

**Position:** the app targets macOS 15 and uses classic materials (`regularMaterial`/`thinMaterial`
heavily in the inspector, `ultraThinMaterial` remnants in overlay chrome). Liquid Glass adoption is
**not** a reskin — the 2026-09-11 design audit (MAD-007) already identified that the inspector
expresses hierarchy through 20+ material cards, which is exactly the surface that must
*de-materialize*, not glassify, when the min OS moves to 26.

## Migration map (surface → target)

| Surface | Today | Target on 26 | Prerequisite |
|---|---|---|---|
| Window toolbars, sidebar | SwiftUI system bars | System Liquid Glass bars (free) | Remove `menuStyle(.borderlessButton)` custom styling (MAD-016) |
| Zoom pill, canvas control chips, freeze-pane handle | Fixed materials + fixed fonts | `.glassEffect` on the *control*, not its container; semantic fonts (MAD-I13) | MAD-I13 font pass |
| Inspector (2,930 lines) | 20+ material cards + 5 thin panels | Grouped sections with layout hierarchy; **no glass on content containers** | MAD-I7 de-card (the critical path) |
| SecurityVaultSheet | Material card nested inside material panel | De-nest to a single chrome layer | Same MAD-I7 pass |
| HUD overlays (AgentCommandHUD, status toasts) | Custom materials | `.glassEffect` + reduce-transparency fallback | MAD-I9 |

## Ordered path (each step valuable on macOS 15, not just future-proofing)

1. **MAD-I7 inspector de-card** — grouped sections replace material cards. Benefits today:
   clearer hierarchy, less translucency cost, and it is the single largest prep item.
2. **MAD-I9 accessibility fallbacks** — `accessibilityReduceTransparency` +
   system Increase Contrast. This is literally the same fallback contract Liquid Glass
   requires; doing it now means the 26 migration needs no accessibility retrofit.
3. **MAD-R2 evidence pass** — screenshot each material surface under
   motion/transparency/contrast settings (T4 evidence doc).
4. **Min-OS bump decision** (owner decision, see audit decision list) — then glassify only the
   nav layers listed above. Content stays plain; glass-on-glass remains banned.

## Anti-goals

- No `.glassEffect` on content containers (inspector sections, cards, lists) — the design
  system's own rule; glass is for navigation/control layers.
- No conditional `if #available(macOS 26)` branching inside view bodies beyond a thin
  `ViewModifier` seam — collect the seam in `DesignSystem.swift` so the eventual bump is a
  cleanup, not a rewrite.
