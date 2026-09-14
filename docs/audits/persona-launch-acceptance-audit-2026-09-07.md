# Persona-Lens Launch & Buyer-Acceptance Audit — 2026-09-07

**Lens source:** `~/Desktop/Understanding_Personas_sept6/01 Expanded Personas/06 Launch, Growth & Market/` — 30 canonical persona documents read in full (IDs cited inline as PER-xxxx, matching the Master Persona Registry).
**Product ground truth:** repo docs as of 2026-09-07 (HEAD `aa599f5` + dirty tree), cited per claim.
**Question asked:** launch readiness, customer/buyer acceptance, missing surfaces, and what would make or break a deal for Northstar PDF (Free / Pro $79 one-time / Agent+ $4.99·mo per D-052).

**Method note (PER-0100 §4 / PER-0352):** every gate below names its evidence source and separates *missing evidence* from *negative evidence*. No checklist theatre: a gate is red only when the underlying evidence is red, not when it is merely uncollected.

---

## 1. Verdict (PER-0352 taxonomy)

### **NO-GO for general availability. GO-WITH-CONDITIONS for a bounded paid-early-access launch.**

GA is blocked by four hard gates with no workaround: an unsigned build (buyers cannot open it without a Gatekeeper bypass), no purchase/entitlement path (D-052: "commerce mechanics are unselected"), RG-135 fail-closed at 0/38, and an unreproducible evidence chain (134 uncommitted files). PER-0100 explicitly warns against "converting uncertainty into automatic no-go" — the pricing/onboarding unknowns are exactly the kind that a **bounded cohort launch is designed to answer** — so the correct recommendation is a conditional limited release, not an indefinite wait.

### Conditions (all owner-gated, ordered by leverage)

| # | Condition | Evidence today | Path |
|---|---|---|---|
| C1 | Commit the working tree; land `benchmark/acroform-lane/` (CI-critical, currently untracked) | EI-A2, epistemic audit §: 134 dirty files, last commit 2026-09-02 | Owner git approval; preservation audit first |
| C2 | Apple Developer account + execute the existing runbook: sign → notarize → staple → spctl | `docs/codesign-notarize-workflow.md` is DRAFT RG-122; "no app-bundle signing… has been performed" | $99/yr; runbook already written |
| C3 | Select and build minimal commerce: processor + license keys + entitlement check | D-052 (`docs/decisions.md:2478-2508`): Paddle vs Lemon Squeezy unselected | Choose one; smallest viable license flow |
| C4 | Close RG-135 human visual confirmation (38/38) | `epistemic-integrity-audit-per-0922-2026-09-06.md`: 0/38, fail-closed NO-GO | Human review time (T1) |
| C5 | Activate support policy + known-issues pack + pricing/entitlement scripts | `docs/support-policy.md` DRAFT, RG-084 "requires human product decision" | Decide platform tiers, publish |
| C6 | Enforce claim scope: mark "source-preserving export" as native-only; fix stale JTBD roadmap claims | loops exploration §4; `cross-jtbd-unified-roadmap-2026-08-26.md` §4 "Price: FREE" vs D-052 | Doc edits, same pass as C1 |
| C7 | Design the launch cohort: paid early access, 10–25 buyers, graduation criteria written before invite | No beta program exists anywhere | See §7 |
| C8 | Prove license-lapse UX: expired Pro keeps documents readable; no entitlement/product divergence | PER-0129 invariant untestable until commerce exists | Fold into C3 acceptance tests |

C1 is first because it is free, instant, and everything else (evidence, releases, trust claims) hangs off a pinned commit.

---

## 2. Seven-dimension readiness scorecard (PER-0100 §3)

| Dimension | Status | Buyer-visible failure if launched today |
|---|---|---|
| Product | **STRONG** (native lane) | Core candidate→review→edit→export→validate loop works end-to-end; reading modes, autosave/recovery, intent modes live. Gaps: browser security-guard cluster test-only; L4/L5 calibration loops CI-only (`epistemic-integrity-audit` §6.2); several Core subsystems (AISummarizer, TableExporter, collaboration) library-only — fine as long as *unclaimed*. |
| Engineering | **GOOD, unproven at distribution** | ~1,635 tests, 7 CI jobs; but web-e2e advisory-only, node-contract partial (29→35 of 88, 6 env-dependent failures), full `swift test` blocked by concurrent lane edits 2026-09-07. Nothing says "installable by a stranger." |
| Operational | **FAIL** | Support is the founder; RG-084 draft; no known-issues pack, no escalation path, no entitlement Q&A scripts (PER-0122: "inconsistent answers" at first contact is a named trust killer). |
| Data | **N/A-LOW** | Local-first; no server migrations. Autosave/recovery is implemented and gated. |
| Commercial | **FAIL** | D-052 defines tiers but "commerce mechanics are unselected"; no buy page, no license issuance, no entitlement check. PER-0121: "a broken commercial flow is a launch blocker, not an app bug." |
| Trust | **SPLIT** | Privacy posture unusually well-evidenced *internally* (EgressGate fail-closed, audit trail, provenance). But externally unverifiable while uncommitted (C1) and the browser export uses pdf-lib, not the incremental writer — the preservation story is native-only (C6). |
| Learning | **FAIL** | Zero instrumentation decision exists. PER-0100 names "analytics added after release" as an anti-pattern; a privacy-first product must decide *opt-in* telemetry/funnel events **before** first cohort, or the launch produces "exposure without measurement." |

---

## 3. Deal-makers (what closes the sale — persona-backed)

1. **The $79 one-time position is persona-endorsed, not just owner preference.** PER-0547 verbatim: "One-time: useful for tools with low recurring service cost or local-first desktop products." Incumbents are vacating perpetual (Nitro sub-only $139.99/yr, Foxit killed perpetual, PDF Expert $139.99 lifetime — verified 2026-08-25, `docs/pdf-pricing-marketing-exploration-2026-08-25.md`). $79 + $39/yr optional renewal is a legible, differentiated offer with defensible economics.
2. **A real-workflow demo exists.** PER-0370's dealmaker is demoing the buyer's *own* document through *their* task. The native candidate-detection → review → edit → export → validate loop does exactly that for form completion — the wedge use case — today. This is demoable; the trust story (native-field vs static-marks distinction, evidence beside every suggestion, honest abstention) is *shown*, not claimed.
3. **The anti-iLovePDF wedge is evidenced, unlike the competitor's claims.** The ihatepdf exploration (`docs/competitor-ihatepdf-cv-exploration-2026-08-24.md`) documented their privacy claims as contradicted in part (Clarity analytics, Gemini API transmission, Razorpay, 150 MB limit vs "no limits"). Northstar can run "privacy claims with proof vs privacy claims with tracking scripts" — a positioning PER-0567 calls "demonstrably different from real alternatives." Caveat (PER-0347): that snapshot is Tier-1 static inspection, 2 weeks old; refresh before citing publicly.
4. **The free tier passes the freemium value test.** PER-0132: free must "reach a meaningful value moment." D-052 commits the free reader to being "genuinely better than Preview" for reading/annotation/AcroForm-fill — and the native lane delivers. Free has a stated strategic purpose (acquisition + evaluation), not "free forever without a rationale."

---

## 4. Deal-breakers (ranked; what makes the buyer walk)

**DB1 — The buyer cannot even open the app.** Unsigned, unnotarized: Gatekeeper blocks first launch. Everything else is moot until C2. (PER-0100 Trust/commercial dimensions.) *Severity: absolute.*

**DB2 — There is nothing to buy with.** No processor, no license keys, no entitlement check. PER-0121 requires "billing/pricing… validated end-to-end" as a launch gate; it is at 0%. *Severity: absolute.*

**DB3 — The version-bump gate is fail-closed RED.** RG-135 at 0/38 human visual confirmations. You have a gate that says NO-GO and it is being respected — that is good discipline — but it blocks shipping. (T1, human time.)

**DB4 — Trust claims are unpinnable.** 134 dirty files; the CI-critical `benchmark/acroform-lane/` is untracked, so RG-134 closure evidence does not reproduce from a fresh clone (EI-A2). Any "independently verified" trust claim a buyer or journalist checks collapses to "trust the uncommitted tree." (PER-0352: "accepting owner self-certification without evidence.")

**DB5 — Claim enforcement, not claim honesty, is the residual risk.** The epistemic audit found "no status inflation in product/marketing prose" — but two enforcement gaps remain: (a) shipped browser export uses pdf-lib, so *source-preserving export* is true only on native; (b) `cross-jtbd-unified-roadmap` §4 still says "Price: FREE" and §8 marks library-only subsystems DONE. PER-0568's named failure — "different channels describing the company differently" — already exists *inside the repo*, and would be found by any Sales-Engineer-lens buyer ("prove-versus-claim classification").

**DB6 — Lapse behavior is undefined and untested.** Perpetual license + 12-month updates + $39/yr renewal means one day a customer's entitlement lapses. PER-0129's hard invariant: "billing says entitled but product says unavailable" and "expired users lose work" must be structurally impossible. Currently unverifiable because commerce doesn't exist. Must be an acceptance test in C3, not a post-launch apology.

**DB7 — Every number in the pricing is an unvalidated hypothesis.** No VoC corpus, no beta cohort, no WTP evidence. PER-1422: "treating willingness-to-pay statements as equivalent to observed purchase behavior" is a named failure; PER-20748 requires ACTUAL/ESTIMATE/HYPOTHESIS labels. D-052 itself says launch prices are "evidence-gated" — the evidence doesn't exist yet. This is *acceptable pre-launch* and *fatal post-launch if never collected*: the bounded cohort (§7) is the collection instrument.

**DB8 — Support is the founder, with no day-one pack.** RG-084 draft; no known-issues guide, no pricing/refund scripts. PER-0122 failure mode "support-as-sensor" absent: ticket themes will never reach pricing decisions. PER-0137: founder must keep a *manual-intervention ledger* so founder-performed support is labeled as learning, not hidden as product.

**DB9 — No measurement means no interpretable launch.** PER-0100 Learning dimension: launch must "produce interpretable evidence rather than exposure without measurement." For a privacy-first product the instrument must be **explicitly opt-in, locally-scoped funnel events** (activation, critical-task success, paywall impressions) — a product decision that doesn't exist yet, and that PER-0134 makes a per-stage contract requirement.

---

## 5. Buyer-acceptance analysis of the current packaging (pricing personas)

| Element | Persona verdict | Gap to close |
|---|---|---|
| Free forever reader | **Passes** PER-0132 (meaningful value moment, stated purpose, data never trapped) | Keep save/annotate basics ungated — PER-0547: never "paywalling basic utility simply because it is easy to gate" |
| $79 one-time + 12-mo updates + $39/yr renewal | **Structurally endorsed** (PER-0547 local-first quote; PER-1422 lists perpetual as a legitimate metric) | WTP evidence (Van Westendorp/Gabor-Granger or observed cohort purchases); renewal must visibly fund something the buyer values ("models-as-content" story needs a user-facing line, not just internal rationale) |
| $59 early-adopter window | **Conditionally OK** (PER-1422: discounts are a system with reference-price effects) | Decide the window's end *before* launch and publish it — improvised discounts are "discount chaos"; the $79 reference price must be real from day one |
| Agent+ $4.99/mo, 500 credits | **Well-designed value metric** (clear, comprehensible, not raw tokens; cost gate not artificial gate; margin-positive under default-cheap routing per the verified 2026-08-25 economics) | P95/heavy-user cost model incl. retries (PER-20748: model "low, expected, heavy, extreme"); premium-model escalation must stay explicit-metered or margin dies |
| ~300 fair-use local agent runs/mo | **Risky if opaque** | Surface the number in-product before throttle, not after (PER-0547: predictable limits; "opaque credits make users afraid to use the product") |
| Gating boundaries | Needs explicit gate classification | AI = cost gate; updates = value gate; reader basics = ungated. Write the matrix down (PER-0129 entitlement matrix) — it doubles as the paywall UX spec |
| Grandfathering / migration | **Not yet written** | PER-0115: any future price change without grandfathering logic "destroys trust." One page now, written before the first price change ever happens |

---

## 6. Missing surface inventory (what doesn't exist and must, before any buyer touches it)

| Surface | Persona gate | Effort | Blocks |
|---|---|---|---|
| Signed + notarized + stapled build (runbook exists) | RG-122; PER-0100 trust | Small once account exists ($99/yr) | everything |
| Sparkle auto-update | RG-123 | Small | post-launch trust |
| Buy path: processor, license keys, entitlement check, refund path | PER-0121 commercial flow; PER-0129 entitlement matrix | Medium — biggest *new* build item | all paid |
| Download page + one-page site (hero = the form-completion wedge, proof above the fold, no "AI-powered" generic hero) | PER-0789, PER-0133 promise→product alignment | Small–Medium | acquisition |
| Opt-in local funnel events (activation, task success, paywall impressions) | PER-0100 Learning; PER-0134 stage contracts | Small–Medium (privacy design is the work) | interpretable launch |
| Support pack: known issues, pricing/entitlement scripts, refund policy, contact channel | PER-0122; RG-084 | Small | first contact |
| Claim-scope fixes: export claim native-only; JTBD roadmap refresh | PER-0568/0370 | Tiny | C1 commit |
| Grandfathering/entitlement one-pager | PER-0115 | Tiny | first price change |
| Beta cohort design: invite list, hypotheses, graduation criteria | PER-0130/0131 | Small | bounded launch |
| Proof library: the demo script, the iLovePDF contrast evidence (refreshed), preservation digests | PER-0104/0347 | Small | sales/messaging |

Notably absent but **not launch-blocking**: per-tool SEO pages (iLovePDF pattern — post-traction), localization (PER-0116 — later), Team tier (deferred per D-052).

---

## 7. Recommended launch mechanism (PER-0100 §6, PER-0130, PER-0131, PER-0137)

**Mechanism: paid early access, founder-led, cohort-sequenced.** PER-0130 names "paid early access" as a legitimate beta type — it converts WTP hypotheses into observed purchase behavior (the exact evidence DB7 lacks) while the cohort stays small enough for founder support to be honest learning rather than hidden dependency.

**Sequence:**
1. **C1 commit → C2 sign/notarize** (week-scale, money + runbook, no product work).
2. **C3 minimal commerce + C8 lapse tests** — smallest viable license flow; treat PER-0129 invariants as acceptance tests.
3. **Cohort 1: 10–25 paid early-access buyers** ($59 window), explicitly instrumented (C-learnings: opt-in funnel events). Hypotheses declared per PER-0130: activation rate on the form-completion job, price acceptance, support load. No product+price+audience changes simultaneously (PER-0131).
4. **Graduation criteria to wider launch** (adapted from PER-0130's GA list): critical-task completion measured; activation threshold met; support load within solo-founder+docs capacity; "onboarding understandable without founder intervention"; cost sustainable at observed usage; no unresolved trust/security issue; known limitations acceptable *and communicated*.
5. **Founder-led announcement only after graduation** (PER-0137): founder message states "what is built; what it currently does; what is still being learned" — no inflated origin story; manual-intervention ledger maintained throughout.

**Anti-target (persona-named):** indefinite beta, founder onboarding everyone forever, launching on signup volume, declaring success on traffic.

---

## 8. Falsifiers

- This audit is wrong about DB1/DB2 being absolute *if* a signed build or working commerce path exists somewhere unindexed — searched docs/ and tools/; none found (Tier 1).
- DB5's severity drops if the browser lane is explicitly scoped out of v1 claims (it partially is under D-071–D-073) — enforcement is then a doc fix, which is condition C6.
- The $79 acceptance signal is unfalsifiable until a cohort transacts — that is the point of §7.3.

## 9. Sources

- Personas: `~/Desktop/Understanding_Personas_sept6/01 Expanded Personas/06 Launch, Growth & Market/` — PER-0100, 0104, 0107, 0115, 0119, 0121, 0122, 0127, 0129, 0130, 0131, 0132, 0133, 0134, 0137, 0339, 0347, 0352, 0353, 0370, 0547, 0567, 0568, 0569, 0789, 1422, 20748, 29000, 29001, 29005 (all read in full via the repository's canonical docx).
- Repo: `docs/decisions.md` (D-052), `docs/audits/epistemic-integrity-audit-per-0922-2026-09-06.md`, `docs/explorations/features-flows-loops-exploration-2026-09-06.md`, `docs/market-strategy.md` (+supersession banner), `docs/codesign-notarize-workflow.md`, `docs/support-policy.md`, `docs/competitor-ihatepdf-cv-exploration-2026-08-24.md`, `docs/pdf-pricing-marketing-exploration-2026-08-25.md`, `docs/audits/cross-jtbd-unified-roadmap-2026-08-26.md`, `docs/implementation-status.md`.

---

## 10. Task ledger (explicit + implicit findings)

Every finding above and every persona gate it implies, as an actionable ledger item. Codes: **R** = research/document, **D** = decision (owner), **I** = implement, **V** = verify/evidence. Origin: **E** = explicit in this audit, **Im** = implicit (persona gate or carry-over blocker surfaced while auditing). Priority: **P0** blocks any buyer contact; **P1** needed for the bounded cohort; **P2** needed for wider GA; **P3** post-GA. Gate-state authority remains `../release-gates.md` (D-055) — this ledger proposes, that file disposes.

### 10.1 Chain of custody & evidence

| ID | Task | Type | Origin | Pri | Depends on |
|---|---|---|---|---|---|
| PL-I01 | Commit the 134-file tree; land CI-critical `benchmark/acroform-lane/`; preservation audit first; resolve `git rm --cached` hygiene (EI-A2 deferred item) | I | E (§1 C1) | P0 | owner git approval |
| PL-V01 | Post-commit: run full `swift test` (blocked 2026-09-07 by parallel lane edits) and record the baseline pass/fail | V | Im | P0 | PL-I01, lane free |

### 10.2 Distribution & update

| ID | Task | Type | Origin | Pri | Depends on |
|---|---|---|---|---|---|
| PL-D01 | Apple Developer account ($99/yr) — decision T8 (RG-122/RG-123 blocker) | D | E (§1 C2) | P0 | — |
| PL-I02 | Execute existing runbook: codesign hardened runtime → notarytool → stapler → spctl | I | E (§1 C2) | P0 | PL-D01 |
| PL-V02 | Clean-machine Gatekeeper test: download, quarantine attribute, first launch | V | Im (PER-0134 entry-stage contract) | P0 | PL-I02 |
| PL-I03 | Sparkle auto-update + signed appcast (RG-123) | I | E (§6) | P1 | PL-I02 |
| PL-R01 | Update-rollback story: Sparkle cannot downgrade; design staged/suspend channel + rollback comms | R | Im (PER-0100 §8 rollback) | P2 | PL-I03 |

### 10.3 Commerce, entitlement & pricing mechanics

| ID | Task | Type | Origin | Pri | Depends on |
|---|---|---|---|---|---|
| PL-R02 | Processor research: Paddle vs Lemon Squeezy (MoR/tax, fees, license-key API, webhook entitlements, refunds) | R | E (§1 C3) | P0 | — |
| PL-D02 | Select processor + license issuance model | D | E (§1 C3) | P0 | PL-R02 |
| PL-I04 | Build minimal purchase → license key → in-app entitlement check flow | I | E (§1 C3) | P0 | PL-D02 |
| PL-I05 | Entitlement state machine + lapse acceptance tests: expired license keeps documents readable; billing/product state can never diverge (PER-0129 invariants) | I | E (§1 C8) | P0 | PL-I04 |
| PL-D03 | $59 early-adopter window: set end date + publish terms before first sale (reference-price discipline, PER-1422) | D | E (§5) | P1 | — |
| PL-R03 | AI unit-economics model: low/expected/heavy/extreme usage incl. retries/failures; per-tier margin table; premium-model escalation stays explicit-metered; label every number ACTUAL/ESTIMATE/HYPOTHESIS (PER-20748) | R | E (§5) | P1 | — |
| PL-R04 | Credit semantics: define what one Agent+ credit buys; predictability rules (PER-0547 — "opaque credits make users afraid to use the product") | R | E (§5) | P1 | PL-R03 |
| PL-I06 | Surface fair-use (~300 local runs) + credit counter in-product *before* throttle, not at throttle | I | E (§5) | P1 | PL-R04 |
| PL-I07 | Entitlement/gate-classification matrix (cost / value / persona / artificial gate per PER-0547; entitlement source, override, expiration, user-facing explanation per PER-0129) — doubles as paywall UX spec | I | E (§5) | P1 | — |
| PL-I08 | Grandfathering/entitlement-change one-pager, written before the first price change ever happens (PER-0115) | I | E (§6) | P2 | — |
| PL-D04 | Multi-Mac license scope (2–3 Macs): honor-system vs device-count enforcement | D | Im (D-052 detail) | P2 | PL-D02 |
| PL-R05 | Education 40% discount verification mechanics (what proves student/faculty status without a service?) | R | Im (D-052 detail) | P3 | — |

### 10.4 Release gates

| ID | Task | Type | Origin | Pri | Depends on |
|---|---|---|---|---|---|
| PL-I09 | RG-135 human visual confirmation 38/38 (currently 0/38, fail-closed) — T1 human time | I | E (§1 C4) | P0 | — |
| PL-I10 | RG-136 remediation (N15, Phase 4): dead `GATE_MIN_PROVIDERS`, dishonest test docstring, replace 8 trivially synthetic fixtures; address near-unfalsifiable absolute WER threshold | I | E (§2 Engineering) | P2 | — |
| PL-D05 | RG-134 ≥0.9 production-ready floor in CI: keep warning vs make blocking | D | E (§2 Engineering) | P2 | PL-V01 |
| PL-I11 | RG-089 v1 descope record (T7, NOT STARTED) — required launch-gate doc | I | Im (ground truth D/C) | P1 | — |
| PL-V03 | Starved surfaces Tier-4 runtime confirmation: launch app, verify Governance dashboard / version compare / document browser actually populate (I1/I2/I3 follow-up owed) | V | Im (loops §8.3) | P1 | — |

### 10.5 Claims enforcement & proof

| ID | Task | Type | Origin | Pri | Depends on |
|---|---|---|---|---|---|
| PL-I12 | Claim-enforcement sweep + fixes (C6): scope "source-preserving export" to native; fix cross-JTBD roadmap §4 "Price: FREE" → D-052 and §8 DONE-overclaims for library-only subsystems; grep all buyer-adjacent docs against D-052 | I | E (§4 DB5) | P0 | — |
| PL-R06 | "Genuinely better than Preview" evidence pack (D-052 claim → Tier-4 comparison task) | R | Im (§3 M4) | P2 | — |
| PL-I13 | Proof library (PER-0104): real-workflow demo script, refreshed iLovePDF contrast evidence, preservation digests, sample what-changed report | I | E (§6) | P1 | PL-R07 |

### 10.6 GTM surfaces

| ID | Task | Type | Origin | Pri | Depends on |
|---|---|---|---|---|---|
| PL-I14 | One-page site + download page: hero = form-completion wedge, proof above fold, no generic "AI-powered" hero (PER-0789 anti-patterns) | I | E (§6) | P1 | PL-I12 (claims fixed first) |
| PL-R07 | Homepage claim-supportability + message test (PER-0568 test criteria: contradiction, redundancy, vagueness, unsupported claims); one message system across site/pricing/in-app paywall | R | Im (PER-0568/0789 gates) | P1 | PL-I14 draft |
| PL-R08 | Funnel continuity audit (PER-0133: promise → signup → initial state → first task → result → next action) + define activation as demonstrated value, not install | R | Im (PER-0133/0134) | P2 | PL-I14, PL-I04 |
| PL-R09 | Competitive refresh: Tier-4 runtime capture of ihatepdf.cv privacy claims; 30-day competitor price re-verification cadence (already a D-052 gate) | R | E (§8 falsifier) | P2 | — |

### 10.7 Instrumentation, learning & launch ops

| ID | Task | Type | Origin | Pri | Depends on |
|---|---|---|---|---|---|
| PL-D06 | Opt-in instrumentation decision: which events, local-only vs consented aggregate, retention, off-switch — privacy design *is* the work | D | E (§2 Learning) | P0 | — |
| PL-I15 | Implement opt-in funnel events: activation, critical-task success, paywall impressions, refund reason | I | E (§4 DB9) | P1 | PL-D06 |
| PL-D07 | Crash reporting boundary: wire the documented boundary vs explicitly defer (doc exists, nothing wired; silent crashes = invisible launch failures) | D | Im (§2 Engineering) | P1 | — |
| PL-I16 | Launch-day operating plan (PER-0100 §8): decision authority, health metrics, incident channel, pause/expand rules, observation cadence, change freeze — even solo, name the fallback | I | Im (PER-0100 §8) | P1 | — |
| PL-I17 | Post-launch scorecard template (PER-0100 §9: system health vs user value vs growth; assumption check) | I | Im (PER-0100 §9) | P2 | — |
| PL-I18 | Support-as-sensor loop: ticket-theme → pricing/product decision cadence (PER-0122) | I | Im (PER-0122) | P2 | PL-I19 |

### 10.8 Cohort & support operations

| ID | Task | Type | Origin | Pri | Depends on |
|---|---|---|---|---|---|
| PL-D08 | Support policy activation (RG-084, "requires human product decision"): platform tiers, response expectations | D | E (§1 C5) | P1 | — |
| PL-I19 | Support pack: known-issues guide, pricing/entitlement Q&A scripts, refund policy, contact channel (PER-0122: "inconsistent answers" = day-one trust killer) | I | E (§1 C5) | P1 | PL-D08 |
| PL-D09 | Cohort design (C7, PER-0130/0131): 10–25 paid early-access buyers, declared hypotheses, graduation criteria, cohort bias register, no-simultaneous-changes rule | D | E (§1 C7) | P1 | PL-I04 (needs commerce) |
| PL-I20 | Manual-intervention ledger (PER-0137): log every founder-performed task during early access, labeled learning vs product gap | I | E (§4 DB8) | P1 | PL-D09 |
| PL-I21 | Founder message template: "what is built / what it does / what is still being learned" (PER-0137 anti-inflation gate) | I | Im (PER-0137) | P2 | — |
| PL-R10 | WTP evidence design: Van Westendorp/Gabor-Granger survey or cohort-observed-purchase protocol; stated-preference ≠ observed-behavior rule (PER-1422) | R | E (§4 DB7) | P1 | — |

### 10.9 Buyer-touching engineering carry-over

| ID | Task | Type | Origin | Pri | Depends on |
|---|---|---|---|---|---|
| PL-I22 | Absolute-path portability sweep (28 Swift + 14 mjs machine paths) — app must run on machines that are not this one | I | Im (ground truth C) | P1 | — |
| PL-I23 | Main-actor ≤250 MB synchronous open (EI-B5) | I | Im (ground truth C) | P2 | — |
| PL-I24 | `exportCopy` mutation-gate routing (T11, contested web/app files) | I | Im (ground truth C) | P2 | — |
| PL-I25 | CI hardening: complete node-contract to full 88-test discovery, fix 6 env-dependent failures, decide web-e2e blocking vs documented-advisory, add CI caching | I | Im (ground truth C) | P2 | PL-V01 |
| PL-I26 | Scripting consolidation (T3) | I | Im (ground truth C) | P3 | — |
| PL-I27 | Test-honesty pass (N18) | I | Im (ground truth C) | P3 | — |
| PL-D10 | Companion transport canonical choice (X3/X4) | D | Im (ground truth C) | P3 | — |
| PL-D11 | Legacy web retirement date | D | Im (ground truth C) | P3 | — |
| PL-D12 | Wire-or-descope per orphan, each with a decision record: L4/L5 calibration loops to runtime, AISummarizer, TableExporter/TextExporter, collaboration stack, PDFUATaggingEngine, ProfileStore, ShadowMode (L9), L19 sync, browser security-guard cluster | D | E (§2 Product) | P2 | — |

### 10.10 Explicitly deferred (post-traction, ledgered so they aren't lost)

- Per-tool SEO entry pages (iLovePDF pattern) — P3, after traction evidence.
- Localization (PER-0116) — P3.
- Hosted Workspace tier ($12.99–$14.99/mo) — demand-gated per pricing direction.
- Team tier — deferred per D-052.

**Critical path to first buyer:** PL-I01 → (PL-D01 ∥ PL-R02) → PL-I02/PL-D02 → PL-I04 → PL-I05 → PL-I09 ∥ PL-D06 → PL-D09 cohort. Everything else parallaxes.

### 10.11 Revision 2026-09-07 (owner re-scope): macOS-app-first

Owner direction 2026-09-07: the **macOS app is the launch surface; the web/browser plane is not a priority**. The persona lens set is channel-agnostic (no member of the 30-persona Launch family is web-plane-specific), so no persona re-read was required — only the scoping changes. Segregation rule: an item is **MAC** if it gates buying, installing, or using the native app; **WEB** if it exists only for the browser editor plane; **SHARED** if a web surface exists solely to distribute the Mac app (the download/marketing site is MAC-serving even though it is technically a web page).

**New items surfaced by the Mac-first scope:**

| ID | Task | Type | Origin | Pri |
|---|---|---|---|---|
| PL-I28 | Package the notarized app for direct download: .dmg (or zip) layout, quarantine/translocation check, appcast hosting for PL-I03 | I | Im (PER-0134 entry-stage: the Mac download IS the entry stage) | P1 |
| PL-D13 | Mac App Store vs direct-first timing: direct-first is the documented lean (fees, upgrade mechanics, IAP constraint 3.1.1 on feature unlocks); decide whether MAS is v1, later, or never | D | Im (D-052 distribution context) | P2 |
| PL-D14 | Browser-plane disposition: park as experimental, freeze, or retire. Absorbs PL-D11 (legacy web retirement). Decide *before* any public claim implies the browser editor is a supported launch surface | D | E (this revision) | P1 |

**Re-labeled by the re-scope:**

- **PL-I12** narrows: the browser-export claim fix is *descoping the claim* (mark web lane experimental/unsupported in prose), not fixing the web exporter. Still P0 — it is doc work that protects the Mac launch story.
- **PL-I25** splits: MAC part = `swift test` blocking status + CI caching (P2). WEB part = web-e2e blocking decision + node-contract completion → parked with the plane.
- **PL-D12** splits: MAC part = wire-or-descope decisions for Core orphans into the **native** app (L4/L5 runtime, AISummarizer, TableExporter/TextExporter, collaboration, PDFUATaggingEngine, ProfileStore, ShadowMode L9, L19 sync) — P2. WEB part = browser security-guard cluster → covered by PL-D14.
- **PL-D11** folds into **PL-D14**.

**Parked with the web plane (not launch work; revisit only if PL-D14 revives the plane):** PL-I24 (`exportCopy` routing), PL-D10 (companion transport choice), web side of PL-I25, React migration completion, browser guard wiring.

**Unchanged by the re-scope:** the critical path above — it was already all-Mac. The starved-surface check (PL-V03), instrumentation (PL-D06/PL-I15), crash reporting (PL-D07), commerce (10.3), cohort ops (10.8), and all pricing items are native-lane work.

### 10.12 Sim-found gaps (native computer-use sim, 2026-09-07)

From `docs/simulations/RUN-2026-09-07-N2N1-native-first-run-and-fill.md` (protocol: `docs/simulations/NATIVE-SIM-PROTOCOL.md`; bench N1=PER-0121, N2=PER-0303, N3=PER-0302, N4=PER-0370). These are **new P0s discovered only by driving the real app** — the wedge journey is GUI-inaccessible today despite being code-complete.

| ID | Gap | Type | Pri |
|---|---|---|---|
| PL-I29 | GAP-C: fill-mode scan never completes on a native-widget fixture (2/2 runs, 15 KB / 1 field); memory-pressure abort leaves honest status but wedges the menu bar disabled with no retry affordance. Investigate dropped continuation in scan task launch; add cancel/retry; menu validation must recover | I | P0 |
| PL-I30 | GAP-A/B: programmatic open paths broken — argv launch is windowless; Apple-Event open loads the doc but spawns a duplicate welcome window and never enables the menu bar. Buyer "Open With" path is dead. Likely fixed together with PL-I02's .app bundling | I | P0 |
| PL-I31 | GAP-D: welcome recents-button click closed all windows leaving a zombie process (single observation — reproduce, then fix window restoration) | I | P1 |
| PL-I32 | GAP-E: AX label of the Fill-mode radio is the raw SF Symbol name (`pencil.and.list.clipboard`); File > Open… disabled on welcome surface; intent-picker AX label inconsistent between states | I | P2 |
| PL-V04 | Re-run the native sim protocol end-to-end after PL-I29/PL-I30, then complete the wedge: field fill → export copy → byte-level preservation validation; then N3 discoverability sweep and N4 sales-demo run | V | P1 |

**Remediation status (2026-09-07, same-day):**

- **PL-I29 — FIXED in code** (D-080): native-fields-first guard (the sim fixture's page had 1 native widget and 0 characters, so the auto-OCR pass was both unnecessary and fatal when its `try?` swallowed failure); honest failure status; 45 s watchdog; memory-pressure handler no longer stomps in-flight scan status. `Sources/PDFEditorRecovery/AppModel.swift` (`autoOCRIfNeededForFillMode`, `handleMemoryWarning`).
- **PL-I30 — FIXED in code** (D-081): `PDFEditorExternalOpenRouter` now owns argv (drained in `applicationDidFinishLaunching` — raw SwiftPM binaries get no LS argv routing, which was GAP-A) and Launch Services opens; after opening into the key window it closes any *other* visible clean-scratch window, making the outcome one coherent window regardless of SwiftUI's WindowGroup racing (GAP-B). `Sources/PDFEditorApp/PDFEditorApp.swift`. Post-bundle verification steps added to `docs/codesign-notarize-workflow.md` §10 (PL-R15 done: §9 document-type wiring + §10 gate).
- **PL-I31 — RECLASSIFIED, no code change:** code walk found no window-destructive path from the recents button (its only action is `model.open(url:)`); the observed all-windows-closed coincided with a helper-side AX dispatch failure (`cannot_complete`/`possibly_sent`). Not reproducible from code; NS-P2's recovery matrix will exercise recents deliberately. Watch, don't patch blind (no-hacks doctrine).
- **PL-I32 — FIXED in code:** per-segment `.accessibilityLabel(mode.displayName)` on the intent-mode picker (segments exposed the SF Symbol name). The welcome File > Open… first-launch disabled read was not reproducible on second launch (AX timing artifact); monitored. `Sources/PDFEditorApp/ContentView.swift`.
- **Evidence tier for the four code fixes:** `swiftc -parse` clean (Tier 1) **and full `swift build` green in an isolated scratch path** (Tier 2, 2026-09-08 02:0x, 211/211 targets) — the shared `.build` stayed held by the parallel agent's test run.
- **PL-V04 partial re-verification (2026-09-08, scratch binary + Apple-Event open of `yes_off_unchecked_basic.pdf`):** ✅ fill mode activates with status "Fill mode — 0 / 1 fields filled" — **no scan, no hang, no memory-pressure stomp** (PL-I29 verified); ✅ menu bar stays enabled through mode switch — Save…/Export Copy…/Append/Open all pressable (GAP-B menu wedge **gone**); ✅ intent-mode radios read "Read / Fill / Sign / Edit" in AX (PL-I32 verified); ✅ document opens via Apple Event with the native field detected and its field editor functional ("consent — Native form field ready for input or autofill", Checked toggle + Apply Field Value). **Residual:** SwiftUI's WindowGroup still spawns its own duplicate start-surface window *after* the router's cleanup pass runs — ordering issue, fix is a deferred second cleanup pass (~1 s after route), ledgered as PL-I30b. The Apply step itself could not be completed in-environment: the ad-hoc binary's unstable signature makes macOS SecurityAgent re-prompt for the recovery-payload keychain item on every recovery save and the prompt layer ignores synthetic clicks — ledgered as PL-I36 (dissolves with PL-D01/PL-I02 stable signing; app-side hardening option: probe keychain writability and surface the banner instead of per-edit prompts).
- **PL-I33 — DONE:** `tools/airgap-watch.mjs` (+ `tools/README.md` section): lsof-sampling network-boundary capture with allowlist, JSON verdict, non-zero exit on violation; serves NS-P5 and the proof library.
- **PL-I12 — DONE:** cross-JTBD roadmap §4 "Price: FREE" → D-052 pricing; §8 completion log carries a supersession banner (code-level DONE ≠ user-reachable; verified library-only list; pointer to PL-D12). `docs/architecture.md` verified already plane-scoped; README clean.
- **PL-R14 — DONE via D-082:** pressure-handler fix landed; remaining policy (eviction candidates, thresholds, ≤250 MB main-actor open) consolidated under PL-R14/PL-I23 rather than patched piecemeal.
- **Owner-gated prep — DONE:** `docs/audits/owner-decision-briefs-2026-09-07.md` covers PL-D01 (Apple account), PL-D02 (Paddle vs Lemon Squeezy with decision criteria; fee figures flagged ESTIMATE — live search quota exhausted), PL-D03 ($59 window terms; recommendation: first 100 licenses or 30 days post-launch).

Sim-confirmed strengths (evidence for the proof library, PL-I13): welcome value-prop + preservation promise; recents ("Continue where you left off") surviving restarts; honest recovery-session banner; the Reader-tab **Capability Passport** (per-session LOCAL capability + export-gate + privacy-preflight evidence) — the single best buyer-trust surface found in the app to date.

### 10.13 Sim-program tasks & persona pack (2026-09-07, second pass)

New personas created (project-scoped, `docs/simulations/personas/NS-PERSONA-PACK.md`; bench updated in `NATIVE-SIM-PROTOCOL.md`): **NS-P1** Maya Recurring Form Filler (wedge buyer), **NS-P2** Recovery & State Integrity Auditor, **NS-P3** Export Preservation Validator, **NS-P4** Assistive-Tech Operator (parent PER-0318), **NS-P5** Privacy Forensics Auditor. Deferred: NS-P6 License Activator (blocked on PL-I04), NS-P7 Localization, NS-P8 Team Admin.

| ID | Task | Type | Origin | Pri |
|---|---|---|---|---|
| PL-R11 | Root-cause study of the fill-scan lane before patching: trace scan task launch/continuation/debounce in code, write diagnosis into the PL-I29 fix PR (why it hangs for both fresh and pressure-aborted runs) | R | Im (RUN step 6) | P1 |
| PL-R12 | Whole-app AX labeling census (raw symbol names, duplicated labels, state-inconsistent labels) → feeds PL-I32 and NS-P4 runs | R | Im (RUN finding 6) | P2 |
| PL-R13 | Multi-display window placement study: why windows spawn at negative-Y secondary coordinates; define default-placement + remembered-frame policy → feeds PL-I34 | R | Im (RUN env caveats) | P2 |
| PL-R14 | Memory-pressure policy review: what is cleared, thresholds, user messaging; reconcile with the ≤250 MB main-actor open item (PL-I23) so pressure handling is one coherent design | R | Im (RUN step 6, run 1) | P2 |
| PL-R15 | Extend RG-122 bundling runbook with Info.plist document wiring (CFBundleDocumentTypes, open-document events) so GAP-A/B die permanently with the .app bundle — argv + Apple Event become first-class tested paths | R | Im (GAP-A/B root) | P1 |
| PL-I33 | Air-gap runtime capture harness in `tools/`: reusable nettop/lsof wrapper that records per-app connections during any sim run (serves NS-P5 and the proof library) | I | Im (RUN step 11 PENDING) | P1 |
| PL-I34 | Window placement fix: spawn on the key display, remember per-document frames, handle display removal | I | Im (RUN env caveats) | P2 |
| PL-I35 | Register NS-P1–P5 in the sim protocol + audit ledger (done this pass); keep persona pack in sync as sims run | I | E (this pass) | P1 |
| PL-V05 | Run NS-P2 recovery matrix, NS-P3 export validation, and NS-P5 air-gap capture after PL-I29/PL-I30 land; fold results into the RUN doc series | V | Im | P1 |
| PL-D15 | Registry sync ritual: add NS-P1–P5 rows to the Desktop Master Persona Registry as project-scoped personas (repository rule 9), or record the decision to keep them repo-only | D | E | P3 |
| PL-I30b | ✅ **FIXED + verified (2026-09-08):** deferred sweep passes (0.5 s/1.5 s) added to the router; Apple-Event open now ends with exactly **one window** holding the document (scratch build, live re-run). First-read AX menu staleness noted, prior verified run shows menus enabled after focus settles | I | Im (PL-V04 partial re-run) | ~~P1~~ done |
| PL-I36 | Ad-hoc-build keychain prompt loop: every recovery save during edits re-fires a SecurityAgent prompt for `com.pdfeditor.recovery-payload` (unstable ad-hoc signature), blocking unattended GUI runs. App-side option: probe keychain writability, batch recovery saves, and keep the "Recovery save needs attention" banner as the affordance. Dissolves for buyers once RG-122 stable signing lands | I | Im (PL-V04 partial re-run) | P2 |
| PL-I37 | **NEW (battery finding F1, RUN-2026-09-10):** scope "source-preserving = byte-exact prefix" to the incremental-writer path in `docs/architecture.md` — the GUI Export Copy flow for a native-field edit routes through the PDFKit provider (valid export, `/Prev` chain kept, objects rewritten; verified qpdf-clean, field `/V /Yes`, Preview-valid) — or wire the writer into that flow; add a byte-prefix regression test | I | Im | P2 |
| PL-V04 | ✅ **PASS WITH FINDINGS (2026-09-10 battery, `RUN-2026-09-10-native-battery.md`):** wedge journey GUI-complete — odoc open → recovery-restored fill → Export Review (fingerprint-matched) → save → qpdf-clean, field persisted, Preview-valid; NS-P5 air-gap **PASS (0 connections)**; NS-P2 recovery **PASS (bounded)**. Remaining legs: sanitized/flattened export variants, bundled-app odoc post-RG-122 | V | E | ~~P1~~ done (residual legs P2) |
| PL-I30 argv leg | **RECLASSIFIED (2026-09-10):** bare-executable argv launch = SwiftUI/AppKit launch-arg suppression (window never created; not the delegate, not the router — verified by removal experiment + 16-sample timing sweep). Developer-only artifact; buyers use the bundled app (runtime odoc verified working). Developer path: `PDF_EDITOR_OPEN_SOURCE` env hook (verified). Delegate handler retained for runtime Open-With | D | Im | closed-as-documented |
