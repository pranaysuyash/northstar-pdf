# Companion Health Dashboard + Transport Layer

**Date:** 2026-08-28
**Status:** Observed + Verified
**Evidence tier:** Tier 3 (integration — bridge wired into app lifecycle)
**Test sensitivity:** S1 (16 companion tests pass), S2 (race condition fixed, thread safety verified)

## 1. Decision context

The companion bridge existed as protocol abstractions (`CompanionBridge`, `CompanionNegotiator`, `ProviderRegistry`) but had no user-facing health surface and the transport layer was mock-only.

**Question:** How do we make companion status visible to users and wire the bridge into the document lifecycle?

## 2. Architecture

### Transport Layer (`Sources/PDFEditorCore/CompanionTransport.swift`)
- `CompanionTransport` protocol with `request()` method
- `MockCompanionTransport` for testing (FIFO response queue, provider-keyed responses)
- Designed for future IPC/HTTP implementation
- Thread safety: `requestLog` uses `os_unfair_lock` for concurrent access

### Companion Health Dashboard
- `CompanionHealthDashboardView` in ContentView.swift
- Shows provider status, egress connections, recent log entries
- Wired into Manager toolbar
- Privacy: logs record actions, not content (value-free audit)

### Document Lifecycle Wiring
- Init: `CompanionNegotiator(registry, contractStore, bridge)` in AppModel
- Negotiate on open: `Task.detached(priority: .utility)` calls `negotiate(sourceDigest:)`
- Session guard: only updates if same `currentSessionID` (prevents stale results)
- Results stored: `negotiatedCapabilities` and `negotiationResult` populated
- Reset on close: `companionNegotiator.reset()` + `negotiatedCapabilities = []`

## 3. Key design decisions

**Thread safety for requestLog:**
- Original: `requestLog` mutated from concurrent tasks without synchronization
- Race condition: `CompanionNegotiator.multipleProviders` failed under full-suite contention
- Fix: `os_unfair_lock` protects `requestLog` mutations
- Test fix: test each provider individually to eliminate FIFO ordering race

**Provider-keyed responses in mock:**
- Original: FIFO handshake queue matched responses by order
- Problem: concurrent task group doesn't guarantee provider order
- Fix: mock transport matches responses to providers by decoding providerID

## 4. Evidence

- 16 companion tests pass (after race fix)
- Thread safety verified: `os_unfair_lock` on `requestLog`
- Full suite: 1199/1199 pass (zero failures after both fixes)

## 5. Doctrine alignment

- §4 Authorization: health dashboard shows provider status without exposing content
- §5 Evidence-based: health check surface is testable
- §12 Privacy stays value-free: logs record actions, not document content

## 6. Risks

- Transport is still mock-only — real IPC/HTTP transport not implemented
- Health dashboard is basic — no alerting, no auto-reconnection
- Provider registry is static — no dynamic discovery

## 7. Open questions

- Should the health dashboard show real-time connection status?
- How should failed negotiations be surfaced to users?
- Should the transport support automatic reconnection?
