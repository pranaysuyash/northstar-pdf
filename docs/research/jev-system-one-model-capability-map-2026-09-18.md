# Jev / System One Models — Capability Research & Product-Fit Map (2026-09-18)

**Status:** living doc — Exploration 10 in the canonical exploration map (`docs/explorations/exploration_map_and_deep_research.md`); shadow-mode spike registered as **NM-R15** in `docs/task-inventory.md`. Updated after every access-window experiment.
**Access state:** early access requested 2026-09-18 via console.typesafe.ai waitlist. **No API grant yet** — every capability claim below is from published sources, none reproduced locally. Treat §1–2 as sourced-only until the NM-R15 calibration replay produces first-party numbers.

## 1. What Jev is

TypeSafe AI (SF lab, launched Jev Sep 15 2026, reportedly $40M led by DCVC, built by Diogo Almeida, ex-RLHF/InstructGPT) calls Jev the first "System One" model: **a model that only outputs typed decisions, never text**. Kahneman framing — fast intuition, not slow reasoning.

- **Input:** a `state` (text or JSON — **text only, no images/audio/video**) plus any number of typed questions in one call.
- **Three primitives:**
  - **Noul** — yes/no as a single probability `{ "noul": 0.93 }` (the number *is* the confidence; no separate confidence field).
  - **Choice** — one of up to 255 options; returns selection + full distribution + confidence.
  - **Score** — position on a 2–10 level scale; returns score (can land between levels, e.g. 1.035) + probabilities + confidence.
- **API:** `POST https://api.typesafe.ai/v1/systemone`; Python `typesafe-sdk`, Node `@typesafe-ai/sdk`, or Vercel AI Gateway (`typesafe-ai/jev`). Keys via console.typesafe.ai (waitlisted early access).
- **Limits:** 64k total context (32k for state + longest question); rate limits ~250k tok/s, 1.2k req/min on `jev-1.13`.
- **Cost/speed:** $0.042/MTok input, output free; ~$0.0004/case on their benchmarks; 70–500ms end-to-end. Claims: 193.6x faster / 444.6x cheaper than frontier LLMs on "System One workflows" (ceiling, not typical).
- **Training:** new stack — new architecture + parallel sampler + RLCD ("Reinforcement Learning for Calibrated Decisions"), which penalizes *uncalibrated probability distributions*, unlike RLVR. Calibration is trained-in, not read off logprobs. This is the genuinely differentiating bit.

## 2. Hype audit (what to believe)

| Claim | Verdict |
|---|---|
| "Zero hallucinations" | **Marketing.** Type-safe ≠ correct. A wrong-but-valid value is still wrong; model "can't abstain," so out-of-range input gets a confidently wrong answer. What *is* true: no type errors (schema-guaranteed) and calibration is a first-class training objective. |
| "193.6x faster, 444.6x cheaper" | Real *on their four workflow evals*, self-run, labels = ensemble consensus of two frontier models (not ground truth). Treat as ceiling. |
| Frontier-level intelligence | On **narrow judgment tasks** (triage, routing, scoring) it's plausible; it cannot generate, count, do arithmetic, or reason about dates. "Smart if-statement" is the right mental model. |
| Workflow > prompt | Their evals site's actual thesis and it looks solid: structured decomposition (code handles rules, model handles judgments) beats the same policy as a prompt for every model tested. |
| Known weaknesses | Reads literally (negations, implied conditions); context rot with irrelevant state; **state is not treated as hostile — prompt injection from user content is your problem**; benchmarks unreproduced; pricing may be subsidized; `jev-latest` moves, pin versions. |

## 3. Fit against Northstar PDF

### Good fits (high-confidence)

**J-01. Agent-lane judgment tier (customer-facing).** The D-083 agentic shell (NM-T41–45) needs exactly this: intent routing, tool selection, and per-action risk scoring before the agent touches a document. Confidence-gated routing maps 1:1 onto our confirmation lanes: high → act autonomously, medium → confirm dialog, low → human/escalate. Jev's published "Customer Service — decide the assistant's next action" eval (76.0%) is literally this pattern. *Caveat:* D-083 bans "AI-native" from the UI until a 2nd model lane exists — Jev could *be* that second lane.

**J-02. Agent-trace observability → governance dashboard.** One of their four published workflows is "review full agent runs to decide if a human must look" (71.6%). Our ExecutionReceipts + GovernanceDashboardView already carry the structured traces; Jev could triage them server-side (or on-device companion) and surface "needs review" flags with calibrated confidence in the receipt itself. Strong thesis fit: receipts currently record *what happened*; this adds a calibrated *how risky was it*.

**J-03. Security-finding triage (internal/admin).** Our sanitize / action-neutralize / attachment-scanner / hidden-revision / signature-guard / XFA-guard lanes produce findings that need severity triage — the exact "security incidents: close/escalate/contain" eval pattern. The Mimosa stale-finding episode (13 false/stale findings blocking a push) is the concrete pain. Jev at $0.0004/case could pre-triage finding streams and CI failure floods, cutting human review to the ambiguous minority.

**J-04. OCR confirm-lane triage.** OCRConfirmLane currently asks the human to confirm OCR output. Jev can't see pixels, but it can judge *extracted text quality*: garbled-word detection, language mismatch, label/field semantic classification of OCR'd forms. Fan-out scoring of OCR confidence per field could reorder the confirm queue so humans see the likely-bad regions first. (FD-R1 form *detection* stays vision/ML-tier — Jev does not replace it.)

**J-05. Support/commerce triage (backend).** Refund-request triage (ties to the refund-escrow presale idea from ADHD round 3), support email routing, telemetry/crash clustering classification, waitlist/early-access request handling. All low-risk, confidence-gated, cheap.

**J-06. Internal docs/registry hygiene.** Classify doc staleness/relevance across docs/ (the frontier-doc audit found a stale shadow canonical map — this class of drift is exactly a Choice primitive at scale).

### Bad fits (do not use Jev)

- Anything visual: OCR itself, page rendering QA, form-field *detection* (no images).
- Arithmetic, counting, date math: parity netting, metadata forensic timelines, page counts — code does this.
- Anything needing an auditable rationale: Jev returns no rationale, only calibrated judgments. Our "provable OR absence certified" thesis requires mechanism-level evidence; a model judgment is a different evidence tier (see below).
- Text generation: rewriting, summaries, translation — stays with the LLM lane.

### Thesis fit and the new evidence-tier question

Our evidence ontology (D-067 "asserted-by-mechanism") is mechanism-first. Jev judgments would need a **new, lower tier**: e.g. `asserted-by-calibrated-model(confidence=0.93, model=jev-1.13.0, prompt-version=…)`. That is honest and consistent with the mutation-ledger product thesis ("sell the ledger"): a calibrated probabilistic judgment with a pinned model version is *recordable evidence*, unlike an LLM's prose. But it must never be presented as proof. This tier definition is a decision item, not something to slip in.

### Hard risks

1. **Prompt injection from user documents.** PDF text goes into `state`, which Jev does not defend. For a security-positioned product, any customer-facing Jev call on document content needs injection hardening (content framing, instruction-vs-data separation conventions, output-side checks). Mirrors our existing CSP/air-gap posture.
2. **Privacy / dark-session conflict.** Sending user document text to a third-party API conflicts with the dark-session attestation thesis and privacy positioning. Customer-facing use must be opt-in, disclosed in receipts, and never in dark sessions. Internal/backend use on our own telemetry is uncontaminated.
3. **Vendor maturity.** Early access, waitlist, self-run benchmarks, possibly subsidized pricing, no local/open weights, unknown OOD behavior, no images yet. Shadow-mode first; pin `jev-1.13.x`.
4. **Text-only state, 64k context.** 250MB PDFs mean chunked map-reduce judgments; irrelevant-state context rot means retrieval-then-judge, not dump-and-ask.

## 4. Recommended path (one decision)

**Decision taken 2026-09-18 (owner):** adopt the **shadow-mode spike** as the entry point, registered as **NM-R15**, with early access requested. Scope locked to **J-03 (security-finding triage)**: replay our existing labeled finding history (fixture corpora + Mimosa episode data) through Jev and measure calibration against known outcomes. Zero user exposure, no UI, no receipts changes; output is a calibration report that either graduates J-03 into the triage pipeline or kills the integration cheaply. J-01/J-02 (agent lane, receipts) are the product-shaped follow-ons but wait for the calibration report and the D-067 evidence-tier decision.

If the waitlist gates the spike, the Vercel AI Gateway path (`typesafe-ai/jev`) is the immediate fallback.

### Post-access exploration increments (this section is the living agenda)

Run in order; each writes results back into this doc and its change log. Promotion from any increment into implementation work goes through `task-inventory.md` per the map's binding rule — never directly.

| Increment | What | Exit oracle | Depends on |
|---|---|---|---|
| **EXP-JEV-1** | Calibration replay of security-finding history (fixture corpora + Mimosa episode) through Jev on triage judgments (close/escalate/contain) | Calibration report: per-class accuracy, calibration error vs known outcomes, cost/case. **Kill criterion:** calibration materially worse than regex/heuristic baseline on the same corpus, or inflated confidence on the known false-positive class | API access (NM-R15) |
| **EXP-JEV-2** | Agent-trace replay: run Jev's "needs human review" judgment over our ExecutionReceipt corpora; compare flagged runs against known-bad session history | Agreement report vs. receipt-ground-truth labels; decide if Governance Dashboard gets a calibrated-risk column (D-067 tier decision required first) | EXP-JEV-1 pass |
| **EXP-JEV-3** | OCR confirm-queue ordering simulation: score extracted-text quality on existing `OCREvalHarness` corpora; measure whether Jev-ordered queue puts known-bad regions first vs current ordering | Queue-efficiency delta on harness data; no production wiring | API access |
| **EXP-JEV-4** | Prompt-injection red-team on `state`: adversarial PDF-text probes (instructions smuggled in document content) against all three primitives; measure refusal/robustness | Threat-model addendum for the application-security audit; **hard gate** before any customer-facing consideration | API access |
| **EXP-JEV-5** | Doctrine-amendment draft for §7 zero-egress boundary (opt-in egress lane shape, disclosure, dark-session exclusion) | Decision item tabled in `docs/decisions.md`; owner call | Owner decision, informed by EXP-JEV-1/4 |

## 5. Change log

| Date | Entry |
|---|---|
| 2026-09-18 | Created. Capability/hype research from public sources; product-fit map J-01…J-06; risks; shadow-spike decision taken by owner; access requested (waitlist). Registered as exploration-map entry 10 and NM-R15. |
| 2026-09-18 | Living-doc scaffolding added: post-access increment agenda EXP-JEV-1…5, zero-egress condition recorded in exploration map entry 10. |

*(Append one row per access-window experiment; keep §1–2 claims sourced-only until EXP-JEV-1 produces first-party numbers.)*

## 6. Sources

- https://typesafe.ai — product overview, claims, pricing
- https://typesafe.ai/blog/introducing-system-one-models-and-jev — launch post, RLCD, limitations section
- https://evals.typesafe.ai — four workflow evals, primitives, methodology
- https://vercel.com/changelog/typesafe-ai-jev-now-available-on-ai-gateway + /ai-gateway/models/jev — availability, `typesafe-ai/jev`
- https://dev.to/valyuai/how-to-use-jev-a-practical-guide-to-typesafes-system-one-model-g5e — API shape, limits, failure modes
- https://flaviocopes.com/jev — practical patterns, honest caveats
- https://news.ycombinator.com/item?id=49717558 — skepticism, CEO counters, architecture questions
