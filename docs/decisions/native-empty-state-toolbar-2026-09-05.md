# Native Empty-State Toolbar Decision

**Date:** 2026-09-05  
**Status:** Accepted working decision; packaged runtime observation remains open  
**Product:** Northstar

## Decision

The document toolbar appears only after a PDF has been admitted into the
document workspace. While the home state has no admitted document, Northstar
hides the window toolbar and keeps the standard macOS menu bar, titlebar, and
welcome workspace actions available.

An open document restores the existing full toolbar or the minimal skim toolbar
according to the active reading mode. The home surface remains the place for
Open, New blank, recent-document recovery, and PDF drop.

## Why

The toolbar is a document instrument. Showing it before a document exists turns
the first viewport into a disabled catalog of future actions and pushes the
actual admission choices lower in the window. This is a state-model problem,
not a missing disabled-state message.

The macOS menu bar remains the global recovery and keyboard path. The welcome
surface already owns the high-value home actions, so hiding the document
toolbar does not remove a command or create a second command authority.

## Implementation boundary

`Sources/PDFEditorApp/ContentView.swift` derives toolbar presence from
`model.inspection`, conditionally projects the existing document/skim toolbar,
and uses `toolbarVisibility(_:for: .windowToolbar)` to remove the empty window
toolbar chrome. No document model, command registry, or menu-bar behavior is
changed.

## Verification

- Source inspection confirms the home/document boundary is the authority.
- The current-source macOS 15 build must pass after the change.
- Packaged T4 observation remains required for home, open, skim, close,
  narrow-window, menu recovery, reduced-motion, VoiceOver, and keyboard paths.

## Revisit triggers

- The welcome surface loses a primary admission or creation path.
- User observation shows that Open/New are materially harder to discover
  without a home toolbar.
- A future documentless workspace gains legitimate global tools that need
  titlebar placement, in which case those tools should be added deliberately
  through the menu/toolbar command model rather than reviving disabled editor
  controls.
