# google/artemis testing-fit evaluation — 2026-09-14

**Question (owner):** can `github.com/google/artemis` help us test Northstar PDF better? If useful and it needs local installation, install it; update `AGENTS.md` if it proves helpful.

## Verdict: NOT APPLICABLE — do not install.

google/artemis (Apache-2.0, ~5.3k stars) is an agent-driven **Android** automation
framework: natural-language tasks executed by AI agents driving a real Android
device or emulator over ADB, perceiving via Android accessibility hierarchies +
OCR of the mirrored screen (Flash ~3–5s/step reactive loop; Pro multi-agent
Planner/Operator/Checker ~15–40s/step). iOS is roadmap-only in its own README;
macOS is not a supported target at all.

Northstar PDF is a native macOS AppKit/SwiftUI application with no Android
surface (the web plane is parked pending PL-D14). Artemis has no mechanism to
launch, observe, or drive a macOS app: its perception and actuation layers are
ADB + Android a11y bound. Installing it would add an unusable dependency, not a
capability — so the install and the `AGENTS.md` update were skipped per the
owner's condition ("if useful").

## What actually fits this repo (already present — use these)

| Artemis concept | Native equivalent here |
|---|---|
| NL task → observe-and-act agent loop | Native sim protocol: `docs/simulations/NATIVE-SIM-PROTOCOL.md` — AX-driven GUI journeys with NS-P1..P5 personas (RUN-2026-09-07/09-10 batteries) |
| Element location via a11y tree + OCR | macOS Accessibility API runs (PL-I29..I32 findings came from exactly this) |
| Network/privacy observation during runs | `tools/airgap-watch.mjs` (lsof allowlist capture; NS-P5 air-gap PASS) |
| Long-horizon workflow verification | PL-V04 wedge journey: open → recovery-fill → export review → save → qpdf-clean |

The standing gap Artemis would have addressed is *automation* of those sims —
they are currently hand/harness-driven, not self-rolling agent loops. If that
gap becomes worth closing, the right comparison set is macOS-native UI
automation (XCUITest, `osascript`+AX, or a Mac-aware computer-use agent), not an
Android device driver.

## Evaluation method

README + repo facts read via web fetch 2026-09-14 (Apache-2.0; Android-only;
device/emulator required; MCP/SDK interfaces). No local installation performed;
no `AGENTS.md` change — the owner's condition for that update ("actually
helpful") was not met.
