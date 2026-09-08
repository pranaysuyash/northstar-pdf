# Pricing Validation Protocol — D-052 Structure (2026-09-07)

**Status:** PROTOCOL ONLY — no survey has been run, no respondent data collected,
no result claimed. This document specifies what to run, not what was found.
**Decision under test:** `docs/decisions.md` D-052 (Free forever / Pro $79 one-time +
$39/yr renewal + 12-mo update window / Agent+ $4.99/mo or $39/yr only when the cloud
lane ships; two-column pricing page until then; launch prices evidence-gated).
**Supersedes nothing:** the hypotheses in `docs/market-strategy.md` §Proposed Pricing
Experiments are already superseded by D-052; this protocol tests the D-052 structure.

## 1. Structure under test (from D-052 — do not re-litigate here)

- **Free forever:** reading, annotation, native AcroForm fill, limited export.
- **Pro $79 one-time** (early-adopter $59 window noted but not tested here): perpetual
  license + 12 months of updates, optional **$39/yr renewal** extending the update
  window (JetBrains-fallback model). 2–3 personal Macs; education 40% off.
- **Agent+ $4.99/mo or $39/yr, 500 cloud credits/mo:** cloud-escalation credits only;
  appears on the pricing page only when the cloud lane ships.
- Constraints for all instruments below: pricing pages list only shipped,
  capability-matrix-verified features; metering telemetry stays value-free; local
  compute is never metered as billable.

## 2. Sampling frame (six Census sectors, `docs/market-strategy.md` §Bottom-Up Sizing)

2022 Nonemployer establishments (upper-bound candidate pool, not TAM):

| NAICS | Sector | Establishments |
|---|---|---:|
| 52 | Finance and insurance | 782,618 |
| 53 | Real estate and rental and leasing | 3,145,367 |
| 54 | Professional, scientific, technical services | 4,013,209 |
| 56 | Administrative and support services | 2,819,562 |
| 61 | Educational services | 859,958 |
| 62 | Health care and social assistance | 2,256,042 |
| | **Selected pool** | **13,876,756** |

- Recruit only respondents who **repeatedly complete client/admin/finance/real-estate/
  education/healthcare paperwork** (screen: ≥4 similar documents/month); the Census
  pool is a frame, not the audience.
- Quota: minimum 30 completes per sector (n≥180 total) before reading Van Westendorp
  intersections; oversample 53/54/56 (first learning markets per buyer-personas) and
  treat 62 as design-constraint signal (slow procurement — attitudes, not pipeline).
- Record ESTIMATE vs HYPOTHESIS labels on every reported number; never present the
  scenario-model range ($1.1M–$25.8M) as a forecast.

## 3. Instrument A — Van Westendorp (Pro $79 one-time price)

Administer after a 3-minute bounded-completion demo (or concierge walkthrough) so price
answers anchor on preservation/recovery value, not "a better PDF editor." Ask in this
order, free numeric response, Pro one-time price as context:

1. At what price would Pro feel **so cheap you would doubt it preserves your
   documents correctly**? (too cheap)
2. At what price would Pro feel like a **bargain worth buying now**? (bargain)
3. At what price would Pro feel **expensive but still worth considering**? (expensive)
4. At what price would Pro feel **too expensive to consider at all**? (too expensive)

Derive: Optimal Price Point (too-cheap × too-expensive intersection), Indifference
Price (bargain × expensive), acceptable range, Point of Marginal Cheapness/Expensiveness.
Pre-registered read: OPP/IDP inside $59–$99 corroborates the $79 anchor; OPP below $49
or PMC above $79 challenges it.

## 4. Instrument B — Renewal + Agent+ take-up (Gabor-Granger style, asked separately)

- **Renewal:** "After your 12 months of updates end, would you pay $39/yr to keep
  receiving updates at [randomized: $29 / $39 / $49]?" Record yes/no per price point;
  renewal intent ≥40% at $39 supports the JetBrains-fallback model.
- **Agent+:** only among respondents who hit local limits in the demo or ask for
  multi-device/team review: "Would you pay $4.99/mo for 500 cloud-escalation credits
  at [randomized: $2.99 / $4.99 / $7.99]?" Agent+ demand below 15% take-up at $4.99
  keeps it off the launch page per the D-052 SKU admission rule (no change needed).

## 5. Instrument C — Pricing-page test plan (two-column Free/Pro until cloud ships)

- Build the page per D-052 invariants (shipped features only, Agent+ column hidden).
- Task: complete one bounded fill with the free reader, then show the Pro upsell at
  the moment of a locked Pro action; log **value-free attempted-Pro-action funnel
  events** (counts/durations only, D-052 metering constraint).
- Metrics: free→Pro click-through, stated take-up at $79 vs $89/$99 (randomized page
  variant), completion time, suggestion acceptance, recovery use. Report WTP evidence
  as observed behavior first, statements second.

## 6. Stopping rule

Stop collection when EITHER (a) n≥180 with sector quotas met AND the OPP 95% CI width
is ≤$20 across two consecutive 40-respondent batches, OR (b) n=400 reached (read what
exists). Stop early for futility if after n=100 the too-expensive CDF shows >60% of
respondents rejecting at $49 (anchor rejected — go to §7 falsifiers, don't buy sample).

## 7. Falsifiers that would change D-052 (pre-registered)

| Observation | D-052 change triggered |
|---|---|
| Respondents one-and-done, renewal intent <20% at any price | Drop renewals; move to paid major versions (D-052's own falsifier) |
| $79 conversion weak vs lifetime framing; IDP ≥$89 | Test $89/$99 price points (D-052's own falsifier) |
| Agent+ take-up ≥25% + hosted/multi-device demand | Spin up the Workspace tier $12.99–$14.99/mo (D-052's own falsifier) |
| Occasional-use pattern dominates (no repeat job) | One-time purchase holds, subscription-equivalent renewal fails — revisit D-005 wedge, not just price |
| Local processing not valued over cloud tools | Trust wedge fails; pricing cannot fix positioning |

## 8. How results map to the decision record

- Results NEVER edit D-052 in place: append a dated `D-052 validation` amendment to
  `docs/decisions.md` recording method, n, OPP/IDP with CIs, renewal/Agent+ take-up,
  page-test funnel, and which falsifier rows fired.
- Satisfy D-052's evidence gates in order: (1) this survey, (2) funnel events from
  Instrument C, (3) competitor price re-verification within 30 days of launch.
- Commerce mechanics remain unselected until gates (1)–(2) read out; no vendor choice
  is authorized by this protocol.
