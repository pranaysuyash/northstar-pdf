# HTML Visual Preview Overview

## What was produced

Created `DESIGN-PREVIEW.html`, a standalone, interactive browser preview of the PDF Editor Northstar design system.

## What the preview shows

- Dark command shell with local-first and source-preservation status.
- Five-mode navigation: Reader, Understand, Complete, Organize, and Review.
- Warm paper document canvas on a slate stage.
- Native field, suggested-region, selected-region, and applied-overlay semantics.
- Evidence inspector with review actions, operation history, validation metrics, and provider capability states.
- Honest partial, reader-only, abstained, and validated states for future capability lanes.
- Responsive behavior for desktop, tablet, and mobile compositions.
- Small interactions for mode switching, applying/dismissing a suggestion, undo, and export validation.

## Platform scope

This HTML file is a web rendering used to make the design tangible. `DESIGN.md` is cross-platform: the same colors, spacing, typography roles, mode model, evidence semantics, and safety states apply to native macOS as well. SwiftUI/AppKit should translate the system into native window chrome, sheets, menus, focus behavior, and system controls rather than copy the HTML structure literally.

## Validation

The HTML contains five mode buttons and five mode panels, four responsive media-query groups, a viewport meta tag, inline design tokens, and JavaScript that passes a syntax check. No production app files were changed.
