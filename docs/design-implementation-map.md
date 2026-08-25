# Web product design implementation map

**Date:** 2026-08-24  
**Source:** `Web-Prototype.zip`, especially `DESIGN-HANDOFF.md`,
`DESIGN-MANIFEST.json`, and `pdf-reader-design-rationale.md`  
**Status:** Active implementation boundary  
**Scope:** Full long-term browser PDF platform

## Decision

The prototype is the visual and workflow direction for the long-term web
product. It is not a scope cap and it is not permission to ship only a reader
because later capabilities are not yet connected to a provider.

The product surface remains the complete five-mode workflow:

```text
Reader -> Understand -> Complete -> Organize -> Review
```

Incomplete capabilities must remain visible as explicit product states such as
available, partial, blocked, failed, or reader-only. They must not be removed
from the product model or represented as successful functionality without
provider and validation evidence.

## Design invariants

- The document is the primary visual surface.
- The dark shell contains product navigation and local-session context.
- The slate canvas separates application chrome from the source document.
- The warm paper treatment identifies the source-document boundary.
- Native PDF fields and product-inferred regions are different semantic types.
- Inferred findings remain review-only until the user confirms them.
- Every confirmed mutation enters the reversible operation history.
- Export creates a new copy and exposes reopen and preservation validation.
- Analysis is local and evidence-oriented. It does not imply general document
  understanding or autonomous correctness.
- Responsive behavior is one adaptive product surface, not a desktop mockup
  squeezed into mobile dimensions.

## Mode ownership and provider boundary

| Mode | Product responsibility | Provider responsibility | Evidence required |
|---|---|---|---|
| Reader | Document navigation, search, selection, page view, source status | PDF.js parsing/rendering/text/annotations | Open, render, search, navigation, password and failure states |
| Understand | Page/document map, evidence origins, structured intents, limitation disclosure | PDF.js facts plus geometry detector and shared contracts | Page-indexed evidence, coordinates, provenance, abstention |
| Complete | Native-field editing, review queue, candidate confirmation, undo | pdf-lib supported form writes and bounded overlays | Separate native versus inferred paths, operation lineage, source binding |
| Organize | Page selection, insert/delete/reorder/rotate/extract workflows | pdf-lib/page provider or future companion provider | Page identity, geometry, links, bookmarks, reopen and preservation |
| Review | Operation log, validation preview, export guardrails, recovery | Export provider plus independent validation lanes | New-copy export, reopen, geometry, outside-region and provider warnings |

## Implementation sequence

1. Freeze the token system and responsive layout contract from the prototype.
2. Establish the canonical React, TypeScript, and Vite entry point without
   discarding the existing browser contract modules.
3. Build the shell and five-mode information architecture with real loading,
   empty, blocked, partial, failed, and success states.
4. Move PDF.js into a controller boundary that owns workers, page rendering,
   text layers, coordinates, search, navigation, and cancellation.
5. Move the current completion and template contracts behind typed adapters.
6. Connect native-field and candidate review flows without auto-applying
   inferred findings.
7. Connect page organization to the provider capability manifest and keep
   unsupported operations explicit rather than silently hiding them.
8. Connect export and validation to Review mode, preserving the source and
   operation history.
9. Verify the full mode workflow across the handoff viewport matrix and the
   existing browser contract, parity, accessibility, and preservation tests.

## Current work

- Prototype archive inspected and rendered at 1440 x 900.
- No horizontal overflow observed in that desktop render.
- SignKit product, roadmap, native workflow, public web, and metadata-only
  workspace were audited in
  [`docs/audits/signkit-capability-crosswalk-2026-08-24.md`](audits/signkit-capability-crosswalk-2026-08-24.md).
- SignKit-derived source identity, evidence lineage, workflow state, recovery,
  topology, and passport concepts are now explicit inputs to the long-term
  contracts. Signature extraction, cleanup, Vault, and signature-specific
  claims remain owned by SignKit.
- Prototype-derived tokens and responsive visual overrides are in
  `web/design-system.css` and are linked from the current browser entry.
- The existing PDF.js/pdf-lib behavior and DOM contracts remain intact while
  the visual foundation is being evaluated.
- React migration is the next architectural slice. The current CSS pass is a
  compatibility bridge, not the final framework boundary.

## Explicit non-goals of this record

This map does not promote any provider capability by declaration. It records
the complete product target and the evidence required before each capability
can be called available. It also does not authorize Git staging, commits,
pushes, or deployment.
