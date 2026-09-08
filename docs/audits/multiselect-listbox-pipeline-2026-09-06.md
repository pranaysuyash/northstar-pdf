# Multi-Select Listbox Pipeline — Extension Audit (2026-09-06)

**Status:** COMPLETE — all suites green
**Scope:** `Sources/PDFEditorCore/PDFIncrementalFormWriter.swift`, `Sources/PDFEditorCore/AcroFormParityExperiment.swift`, `Sources/PDFEditorCore/AcroFormExternalEngines.swift`, `benchmark/acroform-lane/lane.mjs`, `benchmark/datasets/generate_choice_fixtures.py`, `benchmark/datasets/choice-fixtures/listbox_*.pdf` (5 new), `Tests/PDFEditorCoreTests/GeneratedListboxFixtureTests.swift`

## Request

> Extend the choice pipeline to multi-select listboxes (/Ff bit 22, array /V) with fixtures and round-trip tests

## What was measured before writing anything

- **pdf-lib** (installed, `node_modules/pdf-lib/cjs/core/acroform/flags.js` line 128): `AcroChoiceFlags.MultiSelect = flag(22 - 1)` → bit 22 = `1 << 21` = **2097152**. `PDFAcroChoice.setValues()`: >1 selections → `/V` written as a string array **plus** `/I` as sorted option indices; exactly 1 → scalar `/V` and `/I` **deleted**; 0 → `/V` **deleted**. `PDFAcroChoice.setValues` throws `MultiSelectValueError` when >1 values are set without bit 22. `PDFOptionList.select(array)` auto-enables bit 22 (form-creation convenience). `PDFOptionList.clear()` → `setValues([])`.
- **PDFKit** (measured on this machine, macOS 26): reads scalar `/V` through `widgetStringValue`/KVC; returns **empty string and nil KVC for array `/V` even on the pristine pikepdf-written fixture** — a viewer read limitation, independent of any writer (asserted in a dedicated drift-canary test).

## Producer/reader pipeline changes

### Structural model (`FormObjectNode`)

New public fields, decoded in `walkField`:

- `isMultiSelect: Bool` — `/Ff` bit 22 (2097152) on `/FT /Ch`.
- `values: [String]` — all elements of `/V` **when it is an array**. Array tokens never populate the scalar `value` channel and vice versa, so single vs multi shape stays observable (a single-selection write can never masquerade as an array read).
- `selectedIndices: [Int]` — sorted `/I` contents (decoded through `parseNumberArray`, negatives dropped).

### Dict editor: real key removal

`insertIntoDict` gains removal semantics via the new `removeKeySentinel` pair value: the whole `key value` span (key start → value end) is deleted in the same descending-position pass as replacements (`DictEntry` now carries `keyRange`). This is what makes `/I` deletion for singleton writes and `/V`+`/I` deletion for empty multi-selections byte-true instead of writing degenerate empty values.

### Write path: `resolveMultiSelectEditPlan`

Mirrors pdf-lib's *measured* three shapes:

| request | `/V` | `/I` |
|---|---|---|
| multi (`n > 1`) | string array | sorted option indices |
| singleton | scalar string | **removed** |
| empty | **removed** | **removed** |

- Requests resolve against `/Opt` exports **or** display strings (pair-form `/Opt` maps display→export positionally); dedup preserves request order.
- **Fail closed** on: any out-of-vocabulary request (`requestedStateUnavailable`), and — the deliberate doctrine call — **multi-value writes to a field without bit 22**. pdf-lib auto-upgrades the flag for its form-creation API; this writer fills documents whose field semantics the *author* chose, so silently flipping `/Ff` would change what the form means. Refused; a caller that genuinely wants the upgrade performs the `/Ff` write as an explicit, auditable step. (Negative control fixture `listbox_single_select.pdf` pins this.)

### Verification: `verifyMultiSelectStructurally`

Fail-closed structural check (unparseable bytes ⇒ false): bit 22 presence when required; `/V` shape agreement (array == set of exports for multi, scalar for singleton, absent for empty); `/I`, when present, must equal the sorted option indices of `/V`.

### Cross-engine lane

- `lane.mjs`: new `choice_multi` write type (value = **JSON array** of option strings — JSON, not a separator, so options containing commas stay representable); empty array routes to `clear()`. `inspect`/`read` now emit `values` (the full `getSelected()` array) for choice fields.
- `AcroFormExternalEngines.Field` gains `values: [String]?` (tolerant decode; nil for single-valued engines).

## Fixtures (5 new, generator-verified via pikepdf dump)

| fixture | field | bit 22 | `/V` | `/I` |
|---|---|---|---|---|
| `listbox_multi_presets.pdf` | skills | 2097152 | `[Swift, Go]` | `[0,3]` |
| `listbox_multi_pairs.pdf` | regions_multi | 2097152 | `[emea, apac, latam]` (exports of pair-form `/Opt`) | `[1,2,3]` |
| `listbox_multi_empty.pdf` | addons | 2097152 | absent | absent |
| `listbox_multi_hierarchical.pdf` | project.tags / project.reviewers | 2097152 | `[core, ui]` / `[grace]` | `[0,1]` / `[2]` |
| `listbox_single_select.pdf` | department | 0 | `(Eng)` scalar | absent |

Generator hardening along the way: `/Ff` now ORs combo (18) and multiselect (22) bits instead of overwriting; `/I` indexing is pair-form aware (`opt_export`); verification printout shows ff value, `/V` shape and `/I` contents.

## Round-trip evidence (all green)

`Tests/PDFEditorCoreTests/GeneratedListboxFixtureTests.swift` — 9 tests:

1. **fixturesPresent** — 5+ distinct files on disk.
2. **structuralReadMatchesGenerator** — walker decodes bit/`/Opt`/scalar `/V`/array `/V`/`/I` for all 6 rows; array-vs-scalar channel separation asserted.
3. **multiValueRoundTrip** — 4 multi writes (incl. re-select on `skills` after a different selection and a 3-value write): array `/V` + sorted `/I` + bit 22 read back, `verifyMultiSelectStructurally` accepts.
4. **singletonAndEmptyShapes** — singleton → scalar `/V`, no `/I`; empty → no `/V`/`/I`; bit survives both.
5. **singleSelectRefusesMulti** — multi write on `department` **throws** (asserted with the concrete returned plan in the failure message before the fix); singleton stays legal and does not add bit 22.
6. **outOfVocabularyRefused** — `["Swift", "NotAnOption"]` throws.
7. **pdfKitCrossRead** — singleton write readable through `widgetStringValue`; **drift canary**: pristine array `/V` must read empty — if a future PDFKit starts decoding arrays, this fails and the documented claim must be re-verified, not silently drifted.
8. **pdfLibRoundTrip** — pdf-lib sees the pristine `[Swift, Go]` in its own `values` channel; `choice_multi ["Rust","Go"]` write reads back via `getSelected()` and passes `verifyMultiSelectStructurally` on pdf-lib's own output bytes.
9. **fixtureDiversity** — array ≥2, singleton array, pair-form, empty, negative control, hierarchical names all covered.

Regression suites: GeneratedChoiceFixtures (7 ✔), AcroForm Parity Experiment full-corpus (4 ✔ — no parity drift from the dict-editor change), PDFIncrementalWriterTests (24 ✔), RadioCorpusDiversity (7 ✔), GeneratedRadioFixtures (6 ✔).

## Measured limitation on record

PDFKit (macOS 26) cannot *display or read* array `/V` multi-selections — `widgetStringValue` returns `""` and KVC `/V` returns nil on the pristine fixture. This is a viewer-read gap, not a writer defect: the bytes are spec-shaped (§12.7.5.4 Table 247), qpdf-structural verification passes, and pdf-lib — an independent engine — round-trips them. Production read paths for multi-select must use the structural walker (`values`/`selectedIndices`), not PDFKit annotation APIs. The canary test (7 above) converts any future PDFKit change into an explicit re-verification task.
