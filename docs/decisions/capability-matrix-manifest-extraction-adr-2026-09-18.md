# ADR: Extract the Capability Matrix from Data-as-Code to a Governed Manifest

**ADR ID:** CMM-001 (proposed — requires owner acceptance; recorded per DOCUMENTATION_DOCTRINE decision-record shape)
**Date:** 2026-09-18
**Status:** Proposed (R12 of `docs/explorations/features-flows-loops-exploration-2026-09-06.md` §8 — "recommendation, needs own ADR"; promoted from ledger row)
**Owner:** Pranay (acceptance) / native tools lane (implementation)

## Context

`Sources/PDFEditorCore/CanonicalCapabilityMatrixPopulation.swift` is a 918-line
Swift extension that hand-builds the 42-entry capability matrix
(`CanonicalCapabilityMatrix.populate()`) — capability, scope, providers per
lane, contracts, evidence gates, owners, sequencing — as compiled code.
`docs/capability-matrix.md` is generated as the human-readable export;
`GateMaturityBridge` (`Sources/PDFEditorCore/GateMaturityBridge.swift`) maps
entries to release-gate statuses.

Problems observed with the data-as-code form:

1. **Recompile tax on evidence churn.** Every gate-status or provider-evidence
   update — the most frequent legitimate edit to this data — recompiles
   PDFEditorCore and re-runs dependents. Data changes ride the code-change
   review path even though they change no behavior.
2. **Non-engineer authors blocked.** The matrix is the point where product
   claims, evidence, and sequencing meet. Updating it currently requires
   Swift fluency; a manifest (JSON) is editable and diffable by any lane
   (including agent lanes) without a compiler.
3. **Gate-report cross-verification is indirect.** Benchmark gate reports
   (JSON) and the matrix (compiled) live in different worlds; a manifest makes
   schema-level reconciliation (e.g. a CI check that matrix gate IDs exist in
   `docs/release-gates.md`) mechanical.
4. **Drift pressure.** The 2026-09-18 frontier audit found the *human-readable*
   matrix surface already diverging from code reality; making the canonical
   form machine-validated reduces the drift class that produced that finding.

## Options considered

- **A. Status quo (data-as-code).** Zero migration cost; keeps type-checking of
  entry construction; retains the recompile tax and author bottleneck.
- **B. Governed JSON manifest + loader (recommended).** Move the 42 entries to
  `docs/capability-matrix.manifest.json` (or `benchmark/capability-matrix/` —
  exact home is part of the implementation slice); `populate()` becomes a
  loader + schema validator (Codable structs already exist for the entry
  shape); fail-closed on schema violation. Data edits stop touching code.
- **C. Full database/registry.** Rejected: violates proportionality — one
  consumer process, ~42 rows, no concurrent writers. A file manifest is the
  smallest sufficient structure.

## Proposed shape (Option B)

- One canonical JSON file with a versioned schema
  (`capability-matrix.schema.v1`): entries[] with id, capability, scope,
  providers[], contracts[], gates[], owner, sequencing, evidence pointers.
- Loader validates: unique IDs, known contract names (cross-checked against
  `docs/shared-contracts.md` tokens), known gate IDs (cross-checked against
  `docs/release-gates.md`), no dangling dependencies. Validation failures are
  build/test errors, not warnings — the matrix is a trust surface.
- `GateMaturityBridge` reads the loaded matrix unchanged (its API already
  takes `CapabilityMatrixEntry`).
- Migration is one canonical move, not dual-read: populate() switches to the
  loader in the same slice that adds the manifest; the 918-line data block is
  deleted only after the loader reproduces `mapAll()` output byte-equivalently
  (golden-test: old `populate()` output vs. loader output, S2).

## Consequences / risks

- Loses compile-time typo safety on entry fields → mitigated by schema
  validation + golden test.
- JSON is a second surface that can drift from code *consumers* of the
  matrix → mitigated by the cross-checks above and by keeping `populate()`
  as the only in-process accessor (no consumer reads the file directly).
- Manifest edits bypass Swift review → acceptable: that is the point; schema
  validation is the review surface for data.

## Falsifier

If after extraction the matrix receives < ~1 data edit per month, or the
golden test cannot be made byte-equivalent without encoding Swift semantics
into the schema (computed fields, conditional gates), the extraction cost
exceeds its value — record that and close R12 with Option A retained.

## Decision request

Owner acceptance of Option B (target home for the manifest file, and whether
the loader lives in PDFEditorCore or a new small target). On acceptance this
becomes a bounded implement unit: manifest + loader + golden test, one slice.
