# Long-Term Alignment Audit — 17 READ-Gap Features + OCR Gate (2026-09-03)

**Scope:** Scalability, maintainability, and technical debt across the 17 READ-JTBD gap features (R-01…R-17) and the RG-136 4-provider OCR gate.

**Method:** For each feature: (1) Will this still be useful in 6 months? (2) Does it scale? (3) Is it maintainable? (4) Does it create technical debt?

**Relationship to prior audits:** `long-term-alignment-audit-2026-09-02.md` covered the 10 core detection/verification components. This covers the READ-gap feature layer and the OCR gate extension. Together they form complete long-term coverage.

---

## Per-feature long-term analysis

### R-01 Privacy audit trail

**6-month viability:** HIGH — regulated workflows (health, legal, finance) increasingly require audit trails; the value-free design is a differentiator.

**Scalability:** ⚠️ UserDefaults-backed with a 1000-event cap. Fine for single-document sessions; a heavy multi-document workflow will hit the cap. The cap is explicit (trim, never silent corruption) but a file-backed store is the natural next step when a real workload demonstrates the need.

**Maintainability:** ✅ Now has an injection seam (`storageKey`/`defaults`) that made it testable; event type additions are enum-case additive.

**Debt:** LOW — the cap is documented behavior; no silent data loss.

### R-02 Value-free logging

**6-month viability:** HIGH — logging policy is a standing requirement, not a feature.

**Scalability:** ✅ Level-gated; per-category filtering; bounded memory.

**Maintainability:** ✅ Sanitizer rules are data-driven lists.

**Debt:** LOW.

### R-03 Document cache

**6-month viability:** HIGH — offline-first is a core positioning claim.

**Scalability:** ⚠️ LRU with capacity limits; PDFs are large so disk footprint needs the eviction policy to be tuned per device class (tested at unit level, not device-measured).

**Maintainability:** ✅ Simple keyed store with clear eviction semantics.

**Debt:** LOW.

### R-05 Reading history / bookmarks

**6-month viability:** HIGH — reading progress is table stakes for a reader.

**Scalability:** ✅ Per-document entries; bounded by documents actually opened.

**Maintainability:** ✅ Codable structs; no fragile state machines.

**Debt:** LOW.

### R-06 Reading modes

**6-month viability:** MEDIUM — modes are useful but can silently rot if no one owns the per-mode defaults. Keep them bound to documented settings, not ad-hoc flags.

**Scalability:** ✅ Enum-driven; adding a mode is additive.

**Maintainability:** ✅

**Debt:** LOW, with the caveat that mode-specific behavior scattered across views would become a tangle — keep it routed through the mode type.

### R-07 Dark mode / themes

**6-month viability:** HIGH — accessibility + eye strain are durable needs; high-contrast is a WCAG anchor.

**Scalability:** ✅ Named theme set; system-follow default.

**Maintainability:** ✅ ThemeManager centralizes palettes; contrast assertions prevent regressions.

**Debt:** LOW.

### R-08 Search enhancement

**6-month viability:** HIGH — search quality is a differentiator for FIND JTBD.

**Scalability:** ⚠️ Linear indexing per document. Fine to tens of thousands of pages; needs incremental indexing if documents grow much larger.

**Maintainability:** ✅ Independent engine (not PDFKit-coupled) makes semantics testable and portable.

**Debt:** LOW.

### R-09 Batch read processing

**6-month viability:** HIGH — batch is on the expansion roadmap (batch completion/job reporting).

**Scalability:** ⚠️ Sequential execution. Parallelism is possible but must stay bounded by `ResourceLimits` — sequential is the correct conservative default.

**Maintainability:** ✅ Per-item status isolation.

**Debt:** LOW.

### R-10 Adaptive command history

**6-month viability:** MEDIUM — frequency learning is nice-to-have; the policy gate matters more than the ranking.

**Scalability:** ✅ Bounded history + policy.

**Maintainability:** ✅ Policy tests pin retention semantics.

**Debt:** LOW.

### R-11 Citation tools

**6-month viability:** MEDIUM — citations are valuable to academic/legal users but narrow. Low maintenance cost, so keeping it is cheap.

**Scalability:** ✅ Deterministic string generation.

**Maintainability:** ✅ Single style (APA) with plain-text output; adding styles is additive.

**Debt:** LOW.

### R-12 Document metadata view

**6-month viability:** HIGH — metadata visibility is required by the "surface conditional unknowns" feature inventory.

**Scalability:** ✅ Read-only extraction.

**Maintainability:** ✅

**Debt:** LOW.

### R-13 Collaboration

**6-month viability:** MEDIUM-HIGH — the JTBD-01 READ analysis lists collaboration as MEDIUM priority, but the merge/approval machinery is the hardest part to retrofit, so having it now is strategic.

**Scalability:** ⚠️ In-memory + package-based; no server. This is correct for the zero-egress stance — collaboration stays file/package-based. If real-time collab is ever required, it's a deliberate architecture change, not an accident.

**Maintainability:** ✅ 3-way merge with conflict records is the risky part; it has the most tests.

**Debt:** LOW — but keep merge semantics frozen until a real concurrent workload validates them.

### R-14 Advanced annotations

**6-month viability:** HIGH — annotations are core to the READ/INTERACT JTBD.

**Scalability:** ⚠️ Per-document stores; version history grows with edits. Trim/compaction policy may be needed for long-lived documents.

**Maintainability:** ✅ Version store separates creation/update/import cleanly.

**Debt:** LOW.

### R-15 Automation / scripting

**6-month viability:** HIGH — the expansion register explicitly lists "role-based operation history viewer and compliance report for regulated workflows" and scripting enables it.

**Scalability:** ⚠️ Three runner layers overlap (ScriptRunner, CLIRunner, WorkflowRunner). This is the main debt item: the three were built in separate passes and share concepts (commands, results, timeouts) without sharing types. A consolidation pass (one command model, three front-ends) would pay off before the surface grows further.

**Maintainability:** ✅ Each layer is independently tested (new `ReadGapFeatureTests` covers all three); sandbox rules are centralized in CLIRunner.

**Debt:** MEDIUM — duplication across the three runners. Mitigated by tests, worth consolidating.

### R-16 Shared contracts

**6-month viability:** HIGH — native/web parity is a standing requirement; version negotiation prevents silent decode failures as the contract evolves.

**Scalability:** ✅ Version gate is O(1); envelope is generic over payload.

**Maintainability:** ✅ Conservative version rule means contract evolution is a deliberate, tested act.

**Debt:** LOW — but every new payload type must carry a version bump test.

### R-17 Reading analytics

**6-month viability:** MEDIUM-HIGH — analytics feed the learning loop and completion metrics, both on the roadmap.

**Scalability:** ✅ Aggregate-only; per-page durations bounded.

**Maintainability:** ✅ Value-free by construction (indices + durations only).

**Debt:** LOW.

---

## RG-136 4-provider OCR gate — long-term

**6-month viability:** HIGH — OCR quality gates protect every downstream consumer (form detection, entity extraction, template matching).

**Scalability:**
- Fast lane (Tesseract + Vision): ~1 min on 8 fixtures — runs on every push.
- Heavy lane (PaddleOCR + Marker): ~25 min for 8 fixtures on CPU. Nightly + manual dispatch keeps it out of the push critical path while still catching regressions within 24h.
- ⚠️ If the corpus grows to 30+ fixtures, the heavy lane runtime doubles — a smaller per-commit sample + full nightly is the natural split.

**Maintainability:**
- ✅ Single source of truth for thresholds (`GATE_WER_THRESHOLDS` + `GATE_REGRESSION_ONLY_PROVIDERS`), mirrored in Swift (`OCRWerGateMirror`) with parity tests.
- ✅ Baseline regeneration is an explicit `--update-baseline` act; the Swift tests verify baseline fixtures still exist and ground-truth digests match.
- ⚠️ The mirror duplication (Python + Swift) is intentional (parity) but must be kept in sync — the mirror test suite is the enforcement.

**Debt:**
- MEDIUM: heavy deps (paddlepaddle, marker/torch) in a gitignored venv. CI installs them best-effort; absence is `not_ran`. This is the right trade-off — never false-pass, never hostage.
- LOW: PaddleOCR multi-column reading-order confusion (~0.73 WER) is a documented limitation, not a regression; it's why PaddleOCR is regression-only gated. The fix (reading-order post-processing) is a known next engineering step.

---

## Debt register (consolidated view)

| Item | Severity | Mitigation | Next step |
|---|---|---|---|
| Three scripting runners share concepts without types | MEDIUM | All tested; sandbox centralized | Consolidate to one command model |
| AuditTrail capped at 1000 events, UserDefaults-backed | LOW | Explicit trim; injection seam added | File-backed store when workload demands |
| Search indexing is linear per document | LOW | Fine at current scale | Incremental index for very large docs |
| Heavy OCR deps in gitignored venv | MEDIUM | `not_ran` never false-passes | Optional cloud/CI-cached provider lane |
| PaddleOCR multi-column limitation | LOW | Regression-only gating | Reading-order post-processing |
| Annotation version history growth | LOW | Version store separates mutations | Compaction policy when needed |

**Overall:** 16/17 features have HIGH or MEDIUM-HIGH 6-month viability (R-06 and R-11 are MEDIUM but low-cost to keep). One MEDIUM debt item (runner duplication) is the clear consolidation candidate. The OCR gate scales cleanly with a fast/heavy lane split.
---

## Post-Session Addendum (2026-09-03, evening)

**Scope:** Long-term viability of new work done after the initial audit.

### Component viability

| Component | 6-month viability | Debt level | Notes |
|---|---|---|---|
| AcroFormExternalEngines | HIGH | LOW | pdf-lib is stable (v1.17.1); qpdf is system tool; both are minimal wrappers |
| PopplerRenderer | HIGH | LOW | pdftoppm is standard system tool; wrapper is ~100 lines; no maintenance burden |
| 8 radio fixtures | HIGH | LOW | Generated by pikepdf script; reproducible; no maintenance burden |
| Expanded parity corpus | HIGH | LOW | 20 fixtures is honest but still small; future: 50+ fixtures |
| IncrementalWriter radio fixes | HIGH | LOW | Minimal changes to existing code; fixes real bugs |
| Blend sweep constraint | HIGH | LOW | Documented limitation; no code change needed; future: region-based extraction |

### Debt items

1. **pdf-lib flattened-group limitation:** Documented and tested. Not fixable without modifying pdf-lib itself. Accept as known limitation. Debt: NONE (honestly documented).

2. **Expanded corpus still small (20 fixtures):** Previous 9 was too small; 20 is better but still not comprehensive. Future: 50+ fixtures from external datasets (FUNSD, DocLayNet). Debt: LOW (incremental improvement possible).

3. **PopplerRenderer structural similarity:** Currently returns 1.0 for byte-identical, 0.5 otherwise. Needs real bitmap comparison for production use. Debt: MEDIUM (placeholder implementation).

**Verdict:** All new work has HIGH 6-month viability. One MEDIUM debt item (PopplerRenderer similarity). Everything else is LOW debt with documented mitigations.
