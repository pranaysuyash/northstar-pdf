# Performance and Speed Workplan (Native-Only, Non-Market, Swift-first)

## Why this plan exists
The repo has already made a deliberate native macOS path choice (Swift + PDFKit), and your priority is now execution speed, responsiveness, and long-term maintainability. This plan translates the earlier 40-point list into a long-term, doctrine-aligned task list with measurable outcomes and safe sequencing.

## Doctrine alignment (short version)
- Native first: keep macOS-native provider and UX path as the canonical shipping lane.
- Evidence-led change: no optimization may remove correctness invariants.
- Fail-closed gates: if a benchmark/validation fails, do not weaken the gate.
- Long-term stability: prefer fewer architecture-level rewrites over one-off hot-path hacks.
- Privacy-first: avoid introducing diagnostics that persist source labels/values in insecure telemetry.

## Execution model
This work is partitioned into 4 synchronized subagent lanes.

### Subagent A: Telemetry + Benchmarks
- Owner: Performance instrumentation lane
- Scope: metrics, baselines, reproducibility
- Deliverable: fixed benchmark harness outputs and trend dashboards

### Subagent B: Edit Pipeline + Undo
- Owner: Core edit orchestration lane
- Scope: undo, replay, state model, operation log
- Deliverable: lower latency per edit and bounded undo/redo replay

### Subagent C: Detection + Parser
- Owner: Content understanding lane
- Scope: parser geometry pass, candidate suggestion, caching
- Deliverable: lower CPU cost while preserving candidate quality

### Subagent D: Render + IO + Memory
- Owner: Resource optimization lane
- Scope: rendering strategy, caching, disk and memory budget controls
- Deliverable: smoother UI and reduced memory pressure for large PDFs

## Long-term KPI targets
1. App warm start target: reduce to stable first usable page < 2.0s on target Mac profile (P50)
2. Large doc open target: document open + first page raster ready P95 <= 5.0s at 15-20 pages mixed content
3. Undo/redo target: single edit undo/redo P95 <= 250ms for small-to-moderate changes
4. Detection target: candidate refresh under normal UI cadence at 60Hz budget (no UI freeze)
5. Peak memory target: no regression beyond budget at file-size-normalized thresholds
6. Repeated save/reopen correctness target: preserve existing fidelity gates with zero regression
7. Crash-free target: no additional crash classes introduced by optimization paths

## Epic 0: Baseline and safety before optimization
- [ ] Add instrumentation in app and benchmark harness for operation durations and memory peaks
- [ ] Add a fixed corpus manifest for repeated speed/accuracy comparisons
- [ ] Add baseline snapshots for existing workflows in a dedicated JSON/CSV artifact
- [ ] Pin benchmark output schema for cross-run diffing
- [ ] Gate PRs with no-op checks and regression thresholds before tuning

## Epic 1: Remove avoidable full-document recomputation (highest priority)
- [ ] Track page-level dirty bit per operation.
- [ ] Memoize parsed page geometry per page hash.
- [ ] Invalidate only changed pages in parse/detection passes.
- [ ] Introduce page-scoped operation checkpoints for undo replay.
- [ ] Remove full document reopen from hot undo/redo path when state can be replayed from checkpoints.
- [ ] Keep strict fallback to full reopen on recovery boundary or corruption.

## Epic 2: Rendering throughput
- [ ] Add page image cache with memory budget and LRU eviction.
- [ ] Render visible window + prefetch window, not whole document.
- [ ] Reduce preview quality under fast interaction modes.
- [ ] Keep high-quality rerender only for active/hovered target.
- [ ] Deduplicate render and transform matrix operations.
- [ ] Add per-page render dedupe key to avoid duplicate work.

## Epic 3: Detection geometry throughput
- [ ] Replace pairwise comparison hot paths with spatial indexing (grid/binning first, R-tree later if needed).
- [ ] Add fast candidate pruning via geometric range checks before overlap math.
- [ ] Precompute normalized coordinates and cache label token vectors.
- [ ] Short-circuit detection branches with clear confidence thresholds.
- [ ] Measure impact of each heuristic toggle by corpus segment.

## Epic 4: Undo/redo and operation model
- [ ] Replace full reapplication model for every change with incremental inverse operations where safe.
- [ ] Add bounded in-memory operation history policy by edit count and file size.
- [ ] Persist long histories as compact logs with lazy hydration.
- [ ] Add coalescing for burst edits (typing, drag jitter, repeated transforms).
- [ ] Add deterministic replay mode for verification runs.

## Epic 5: I/O and persistence
- [ ] Audit every write path for unnecessary serialization.
- [ ] Skip save when no effective diff exists.
- [ ] Batch temp file writes in user-input bursts.
- [ ] Add fast-path for metadata-only or no-op updates.
- [ ] Use temporary directories with deterministic cleanup and crash-safe temp lifecycle.

## Epic 6: Concurrency and app responsiveness
- [ ] Move CPU-heavy parse/detect to background actor/queues.
- [ ] Debounce high-frequency UI events before model recomputation.
- [ ] Ensure background work publishes incremental progress state instead of blocking.
- [ ] Profile lock contention and reduce shared mutable state width.
- [ ] Add queue depth and worker saturation monitoring.

## Epic 7: Memory discipline
- [ ] Add bounded caches for parsed geometry, page rasters, and detector intermediates.
- [ ] Implement proactive memory cleanup hooks under pressure.
- [ ] Avoid temporary object churn in hot loops.
- [ ] Add ARC/object lifetime audits for recurring allocation spikes.

## Epic 8: OCR and scanned document path
- [ ] Add separate scanned/handwritten benchmark lane.
- [ ] Cache OCR preprocess and results.
- [ ] Skip repeated OCR passes without content changes.
- [ ] Keep OCR lanes asynchronous with explicit timeout and graceful degradation.

## Epic 9: Provider and engine fallback strategy
- [ ] Keep PDFKit as primary native lane.
- [ ] Preserve provider-neutral contracts for future drop-in lanes.
- [ ] Route known-failure fixture classes to independent validation only, not silent retries.
- [ ] Add health checks for provider-specific fallbacks where they improve stability.

## Epic 10: Test and regression hardening
- [ ] Add perf baselines in CI-like local gate docs and scripts.
- [ ] Add regression tests for page cache correctness.
- [ ] Add stress test for repeated edits on 20+MB and 100-page docs.
- [ ] Track false-positive rate on detection with and without fast-path toggles.

## Sequencing (0->1->2 style)
- Phase 1 (1-2 weeks): Epic 0, Epic 1, Epic 4 partial, Epic 7 partial
- Phase 2 (3-5 weeks): Epic 2, Epic 3, Epic 6
- Phase 3 (6-10 weeks): Epic 5, Epic 8, Epic 10
- Phase 4 (11-16 weeks): Epic 9 and hardening of all cross-cutting gates

## Daily execution template
- [ ] Morning: choose 1 task from Telemetry + 1 task from one optimization lane
- [ ] Midday: run benchmark slice relevant to that task
- [ ] End of day: record delta against baseline and open risks
- [ ] End of week: update gate status (Pass/Block) and next dependencies

## Risk register (must stay visible)
- Avoided optimization: any change that breaks existing parity checks.
- Serialization race: async work that mutates shared state without sequencing.
- Over-caching: stale page state after edits causing wrong candidates.
- Undo ambiguity: checkpoint policy changing user-visible undo behavior.
- Performance regressions hidden by changed corpus: must benchmark across fixed fixture set only.

## Subagent-ready task packet mapping
- For each task above, open with one metric, one owner, one deadline.
- Close only when:
  1) code landed,
  2) benchmark delta logged,
  3) safety gate checks pass,
  4) evidence file linked.

## Evidence attachments to produce
- `benchmark/perf-baseline-YYYY-MM-DD.json`
- `benchmark/perf-latency-deltas-YYYY-MM-DD.json`
- `docs/roadmaps/performance-retrospective-YYYY-MM-DD.md`

