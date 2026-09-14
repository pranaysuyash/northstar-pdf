# Owner Decision Briefs — PL-D01 / PL-D02 / PL-D03 (2026-09-07)

One-approval-each briefs for the three owner-gated commerce/distribution decisions in
`persona-launch-acceptance-audit-2026-09-07.md` §10. Everything else in the ledger is
executable without these.

## PL-D01 — Apple Developer Program account ($99/yr)

- **Asks:** approve the $99/yr purchase (RG-122/RG-123 unblock; every distribution gate
  hangs on it: PL-I02 signing, PL-I03 Sparkle, PL-I28 packaged download, PL-V02
  clean-machine test).
- **Facts:** enrollment needs a verified Apple ID + D-U-N-S only for organizations;
  individual enrollment is same-day to a few days. Nothing in the repo blocks on it —
  the codesign/notarize runbook (`docs/codesign-notarize-workflow.md`) is complete and
  now includes document-type wiring (§9) and the external-open gate (§10).
- **Recommendation:** enroll as Individual now; the earlier it exists, the earlier the
  notarized .app dissolves the sim environment's CUA/bundle quirks (bundle-less-binary
  issues in the RUN doc).
- **Reversibility:** none needed once enrolled; cost is trivial vs. launch timeline.

## PL-D02 — Commerce processor: Paddle vs Lemon Squeezy

- **Asks:** select the Merchant of Record + license-key provider for the $79 Pro /
  $39 renewal / $4.99 Agent+ SKUs (D-052 left mechanics unselected).
- **Facts (label: ESTIMATE — fee pages must be re-verified at decision time; live
  search quota exhausted until 2026-10):** both are MoR (they carry global sales
  tax/VAT — for a solo founder this alone decides the category vs raw Stripe).
  Historically both list ~5% + $0.50/txn; Lemon Squeezy was acquired by Stripe (2024),
  so its long-term roadmap is Stripe-bound; Paddle is the more established MoR for
  desktop/SaaS with stronger subscription/retention tooling. License-key delivery:
  both support license keys; verify key-generation + validation API + webhook
  entitlement events fit PL-I04's acceptance tests before committing.
- **Decision criteria (ranked):** (1) webhook + license-key API fit for the
  entitlement state machine (PL-I05 acceptance tests); (2) refund flow control;
  (3) fee + payout cadence; (4) checkout localization for the $59 window.
- **Recommendation:** run PL-I04's entitlement acceptance tests as a spike against
  BOTH sandboxes, pick by criterion (1). Default lean: **Paddle** for desktop-SaaS
  maturity; **Lemon Squeezy** acceptable if its Stripe-bound direction is not a
  concern. Time-box the spike: 2 days.
- **Reversibility:** license records are exportable from both; migration mid-flight is
  painful but possible — decide before first sale (that is the point of the gate).

## PL-D03 — $59 early-adopter window terms

- **Asks:** publish the window's end before the first sale (reference-price
  discipline, PER-1422; the $79 anchor must be real from day one).
- **Options:** (a) date-capped: ends 30 days after GA announcement; (b) quantity-capped:
  first 100 licenses; (c) hybrid: whichever comes first. Option (b/c) is honest
  scarcity grounded in a real cohort size (matches the 10–25 buyer first cohort +
  early expansion); option (a) risks "perpetual extension" creep.
- **Recommendation:** (c) "First 100 licenses or 30 days after public launch,
  whichever comes first," stated on the pricing page and in the purchase email.
- **Reversibility:** extending a quantity cap is a visible change; do not — honor the
  published terms exactly (PER-0115: improvised discounts destroy trust).
