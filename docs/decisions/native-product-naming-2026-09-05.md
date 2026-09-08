# Native Product Naming Decision

**Date:** 2026-09-05  
**Status:** Accepted working decision; distribution identity remains a separate release gate  
**Product:** Northstar  
**Technical workspace:** PDF Editor

## Decision

The user-facing native product name is **Northstar**. The supporting descriptor
is **Local-first PDF workbench**. “PDF editor” remains a generic capability
description, not the brand shown in the macOS app menu, window scene title,
welcome accessibility surface, or bundle display metadata.

The existing technical names remain stable for now:

- Swift package, executable target, and module names remain `PDFEditor` and
  `PDFEditor*`.
- The preview artifact path remains `.build/native-preview/PDFEditor.app`.
- Internal service names and historical evidence identifiers are not renamed as
  part of a visual-brand change.
- The preview bundle's user-facing display/name metadata is `Northstar`, with
  bundle identifier `com.northstar.pdf`.

## Rationale

Northstar is already the canonical product name in the product-direction and
commercial strategy records, while “PDF Editor” describes the category and the
current implementation workspace. Showing the category name in the app menu
and window makes the product feel unfinished and weakens the differentiated
promise: a calm, local-first, evidence-aware document workbench.

The distinction also follows first principles. Branding is a user-facing
identity concern; Swift target renaming is a repository and distribution
migration concern. They should not be coupled without a migration plan for
bundle identity, preferences, keychain services, recovery data, tests, scripts,
and release artifacts.

## Implementation boundary

`Sources/PDFEditorApp/ProductIdentity.swift` owns the native visible name used
by SwiftUI surfaces. `tools/native-preview-Info.plist` owns the corresponding
preview bundle display metadata. Source and package names remain compatibility
identifiers until a separately approved technical migration is required.

Existing screenshots and runtime observations that say “PDF Editor” remain
historical evidence of the pre-rebrand package. A fresh packaged launch must
verify the new app-menu and window title before the naming gate is considered
runtime-verified.

## Falsifiers and revisit triggers

- A legal, App Store, or domain conflict makes Northstar unavailable.
- A released bundle identity requires an explicit migration strategy for
  preferences, keychain services, bookmarks, or update continuity.
- User research shows that “Northstar” is less discoverable than a tested
  descriptor pairing.
- The native and browser products intentionally diverge into separately named
  products.

## Evidence

- `DESIGN.md` identifies Northstar as the product direction and retains
  `PDFEditor` as the technical target name.
- `docs/northstar-macos-landscape-and-product-direction-2026-08-25.md` calls
  Northstar the canonical local-first native macOS product.
- `docs/pdf-pricing-marketing-exploration-2026-08-25.md` records Northstar as
  the canonical product name and `com.northstar.pdf` as the intended identity.
- Native source uses `ProductIdentity.displayName` for the scene and visible
  app surfaces; the preview plist uses `Northstar` for display/name metadata.
- T2 current-source build and preview-package rebuild pass. T4 fresh launch,
  app-menu, window-title, and distribution verification remain open.
