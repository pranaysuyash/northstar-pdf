# Round-3 Cohort Research — W-9 demand, distribution channels, refund mechanics

**Research date:** 2026-09-17 · **Governing doctrine:** `RESEARCH_DOCTRINE.md` (canonical root) · **Consumers:** pool ledger R3 items, exploration map, decision list
**Research questions:**
1. Is IRS W-9 the right anchor form class for the cohort-anchored single-form edition (R3-03/R3-22)?
2. Are the assumed distribution venues for R3-18 (exchange listing) viable for a zero-egress product?
3. What are the verified payment mechanics (refund fees, chargeback exposure) for the refund-escrowed presale (R3-25) and the $0-authorization quorum variant (§7.2 child 2)?
4. Do bookkeepers' observed W-9 workflows match the product's certified-fill wedge?

---

## 1. Scope and definitions

"Anchor form class" = the named recurring form the first sellable SKU certifies. "Refund-escrowed presale" = charge-now/refund-until-green mechanics. "Zero-egress" = the doctrine that document content never leaves the process boundary; product-level network integrations are excluded by architecture.

## 2. Current assumptions entering research

- W-9 is the most universally recurring SMB bookkeeping form (assumption, Tier 0 at entry).
- Professional-association venues are reachable without paid ads (assumption).
- Refund mechanics carry fee/chargeback costs that must be owned in presale terms (audit §7.2 stated this as a hazard; unquantified).

## 3. Method

Built-in WebSearch (Z.ai MCP) was rate-limited until 2026-10-06 (provider quota); fallback per established runbook was direct WebFetch against primary sources (Stripe official docs; IRS.gov). Search-engine fallback output (unattributed model general knowledge) is treated as **discovery only** and labeled Inferred where used. Bounded pass: 3 primary fetches, 1 search-round. Research-to-testing handoff: none of these claims is code-testable; they are external facts.

## 4. Evidence map

| # | Claim | Source | Tier | Truth status |
|---|---|---|---|---|
| E1 | Stripe does not return original processing fees on refunds | [docs.stripe.com/refunds](https://docs.stripe.com/refunds) ("Stripe's processing fees from the original transaction aren't returned") | T5 (primary vendor doc) | **Verified** |
| E2 | Refunds issued shortly after the charge may process as fee-free *reversals* | same, "Refund and reversal" section | T5 | **Verified** |
| E3 | Stripe explicitly recommends manual authorization + capture for cost control on refund-heavy flows (the $0-auth quorum variant's substrate) | same, "Cost optimization" section | T5 | **Verified** |
| E4 | Disputes debit the merchant for the payment amount **plus one or more network dispute fees**; networks run monitoring programs for excessive dispute rates | [docs.stripe.com/disputes](https://docs.stripe.com/disputes) | T5 | **Verified** (mechanism); exact fee amount **Unknown** (pricing page not fetched) |
| E5 | W-9's official purpose: supplying a TIN to a requester who must file information returns (1099 series) | [irs.gov about-form-w-9](https://www.irs.gov/forms-pubs/about-form-w-9) | T5 (primary government) | **Verified** |
| E6 | The IRS page states **no explicit collection deadline**; the "collect before Jan-31 1099 filing" pressure is common practice, not statute | same (absence) + general knowledge | T5/T0 | **Inferred** |
| E7 | W-9 pain cluster: chasing vendors, re-keying into accounting software, TIN/name mismatches, re-collection cycles | search-fallback general knowledge (Track1099/Tax1099/Avalara/QBO built-ins named as incumbents) | T0/T1 | **Inferred — unverified** |
| E8 | QuickBooks App Store listings require QBO OAuth API integration and Intuit review; ProAdvisor directory is for accountants, not apps | developer.intuit.com (existence verified via link); requirements detail from fallback knowledge | T1/T0 | **Contested→Verified-absence risk** (see §6) |

## 5. Findings by subquestion

**Q1 (W-9 anchor).** E5 verifies W-9 is a universal information-return input; E7 (unverified) suggests the *workflow* pain is collection/chasing/re-keying — which is upstream of form *filling*. **Implication that matters:** the certified-fill wedge must be positioned as the receiving/filling side the bookkeeper controls (client-delivered W-9s, scan/rotate variants), not vendor-chasing (a workflow the app deliberately does not do — no egress, no email integration). Anchor-fit is **plausible but demand-unverified**; the audit's own §9 caveat stands: verify against real cohort intake before the D-055 claim.

**Q2 (distribution venues).** E8 cuts against R3-18 as literally conceived: app marketplaces are integration ecosystems, and Northstar's zero-egress architecture excludes the QBO OAuth integration those venues require. The viable re-angle: **CPA society vendor directories, bookkeeping-association catalogs, and practitioner newsletters** (R3-12's habitat list) — venues that list tools rather than integrations. This is counter-evidence against part of the round-3 idea; recorded, not silently dropped.

**Q3 (refund mechanics).** E1+E4 verify the audit's hazard precisely: every refunded presale dollar costs the original ~2.9%+$0.30 processing fee (non-refundable), and a chargeback costs the disputed amount plus network fees regardless of outcome. E2+E3 materially strengthen the **$0-authorization quorum variant**: authorizations that are never captured are cancellable pre-capture at no cost (E3's own recommended pattern), eliminating refund fees AND chargeback exposure entirely. **This shifts the presale branch's default mechanic from escrowed-charge to auth-hold quorum** — same demand signal, strictly lower payment-ops risk.

**Q4 (workflow fit).** E7's incumbents (Track1099, Tax1099, Avalara, QBO built-ins) own the collection+e-file workflow. The product's differentiated ground remains evidence/certification (fill with attested receipts) — consistent with the adopted "proof-of-change" position (round-1 C2). No contradiction with doctrine; confirms the wedge should NOT attempt the e-file workflow.

## 6. Contradictions

- **Fallback knowledge vs. primary architecture:** the search fallback recommended the QuickBooks App Store as a listing venue (R3-18's original example); the verified integration requirement makes that venue structurally incompatible with zero-egress. Preserved as Contested→resolved against the marketplace venue; R3-18's ledger entry needs the re-angle noted.
- **"Jan-31 deadline" pressure:** widely repeated, absent from the IRS page itself (E6). Treated as practice, not requirement.

## 7. Implications

1. Presale default mechanic → **$0-auth quorum** (verify-chain unchanged; payment-ops hazard reduced from "refund latency + fees + chargebacks" to near zero).
2. R3-18 re-angle → association/vendor directories; drop app-marketplace venues.
3. Envelope/W-9 positioning → certified fill of client-supplied W-9s (scan/rotate/raster variants are the real arrival variance — already the fixture plan's four variants).
4. The payment-terms page must state: processing fees are not returned on refunds (E1) IF the escrowed-charge variant is ever used.

## 8. Unknowns

- Exact Stripe dispute fee amount and current dispute-monitoring thresholds (pricing page; region-dependent).
- Whether W-9 is the cohort's actual highest-value form (needs the PL-D09 cohort intake instrument — not resolvable by desk research).
- Association vendor-directory pricing/submission requirements (per-organization; bounded pass deferred).
- r/Bookkeeping community quote quality (R3-20's landing-page input) — quota-gated.

## 9. Falsifiers / revisit triggers

- If cohort intake shows a different dominant recurring form, the anchor choice flips before any D-055 sale claim (decision-gated).
- If Stripe pricing changes refund/reversal fee behavior, Q3 conclusions re-check (freshness: 2026-09-17).
- If Intuit opens non-integration listing tiers for desktop tools, the app-marketplace venue re-opens.

## 10. Sources

- [Stripe — Refund and cancel payments](https://docs.stripe.com/refunds) (fetched 2026-09-17)
- [Stripe — Disputes](https://docs.stripe.com/disputes) (fetched 2026-09-17)
- [IRS — About Form W-9](https://www.irs.gov/forms-pubs/about-form-w-9) (fetched 2026-09-17)
- [Intuit Developer](https://developer.intuit.com) (existence check only)
- Search-fallback general knowledge (Track1099/Tax1099/Avalara naming; W-9 pain cluster) — unverified, labeled Inferred

## 11. Research completeness statement

**Established:** refund/reversal fee mechanics (E1–E3); dispute cost mechanism (E4); W-9 official purpose (E5); app-marketplace integration requirement (E8, against R3-18's original venue).
**Contested:** none remaining unresolved (E8 resolved against marketplace venue on primary evidence).
**Unknown:** exact dispute fee figure; cohort's dominant form; directory submission mechanics.
**Not Researched:** pricing-page detail (quota-bounded); competitor certification claims; association fee schedules.
**Freshness:** all primary fetches 2026-09-17; re-check Stripe pricing pages before presale terms are published.
**Decision Impact:** two decision-list items change content (presale default mechanic; R3-18 venue re-angle) but none blocks implementation already landed — the entitlement chain and auth-hold pattern were built mechanics-agnostic.
