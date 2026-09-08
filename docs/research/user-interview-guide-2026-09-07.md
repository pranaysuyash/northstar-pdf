# User Interview Guide — Market Falsifiers (2026-09-07)

**Status:** GUIDE ONLY — no interviews have been conducted, no findings claimed.
Companion to `pricing-validation-protocol-2026-09-07.md` (price) — this guide covers
jobs, preservation pain, and recurrence. It tests the falsifiers in
`docs/market-strategy.md` §Falsifiers and Stop Conditions and the D-005 wedge
(`docs/decisions.md`), not product usability.
**Recruiting frame:** the six Census sectors in the pricing protocol (§2); screen for
≥4 similar documents/month.

## 0. Consent / privacy script (read verbatim, local-first)

> "This is research for a local-first PDF tool — everything stays on devices you
> control. Please do NOT upload or send us any document. If you share your screen,
> keep client names, IDs, and financials closed or redacted — I'll ask you to pause
> if I see personal data. Notes will be value-free summaries (what kind of form, what
> went wrong, how often) with no names, no document contents, and no screenshots of
> your files. You can skip any question and stop at any time. May I take typed notes?"

- No participant docs are collected, photographed, or retained — narratives only.
- If a participant offers a file, decline: "I can't accept files — describe it instead."
- Label every note ACTUAL (observed/said) vs interviewer INFERENCE.

## 1. Last-document-completed walkthrough (15 min — the core of the interview)

Reconstruct the LAST document they had to complete; stay on that instance before
generalizing. Falsifier tested: "users cannot name a recurring preservation or
completion problem beyond generic PDF editing."

1. "Walk me through the last form or packet you had to fill in — what was it for?"
2. "What tool did you use, step by step? Where did you get stuck?"
3. "Did anything shift, lose content, or print differently than on screen? What exactly?"
4. "How did you check the result was correct before sending? How long did that take?"
5. "What did you do the last time this same layout came back with new data?"

Probe for: radio/checkbox state loss, retyped addresses, print-scan-email loops,
broken AcroForms in Preview, free-tier daily limits (concrete preservation failures
beat generic "PDFs are annoying").

## 2. Preservation-problem evidence (10 min)

Falsifiers tested: no-op/bounded saves changing unrelated content; AcroForm hierarchy
loss; "local processing creates no meaningful trust/workflow advantage."

1. "Have you ever had a tool change something you didn't touch? What happened?"
2. "Show/describe how you recovered. Did you trust the file afterwards?"
3. "Some tools send files to the cloud to process them — does that matter for your
   work? When would it be forbidden?" (listen for HIPAA/client-PII/PHI constraints
   like Marcus P2; do not lead with regulated examples)
4. "What would proof that 'nothing else changed' look like to you?"

## 3. Suggestion-acceptance measurement (10 min, concierge demo)

Falsifier tested: "reviewed static suggestions are rarely accepted after users
understand them." Demo the concept on a SAMPLE form (never their document):

1. Show one static blank region surfaced as a *reviewed suggestion* (explicitly NOT
   auto-applied). "In your own words, what just happened?"
2. "Would you apply this, edit it first, or dismiss it? Why?"
3. After they understand review-gating: "If 9 out of 10 suggestions were right but you
   still had to check each one — useful or annoying?"
4. Record per-suggestion: applied / edited-then-applied / dismissed / confused.
   Acceptance without comprehension does not count — re-explain and re-ask once.

## 4. Recurrence + willingness-to-pay probes (10 min)

Falsifiers tested: low recurrence; occasional-use supporting one-off but not repeat
value; e-signature/retention/admin required before paying.

1. "How many times a month does this same layout recur? What happens if you skip it?"
2. "What does the current workaround cost you — minutes, money, rework, risk?"
3. "If repeat fill took under 2 minutes and print always matched, what would that be
   worth — per month, roughly?" (record number + hesitation verbatim)
4. "Would you pay once ($79-ish) or per-month? What would make you stop paying?"
5. "Is there anything that must be included before you'd pay — signatures, sharing,
   admin controls, cloud access?" (any "must-have e-sign/retention/admin" answer is a
   wedge-falsifier — record verbatim)

## 5. Note template (per interview, value-free)

`sector / role / docs-per-month / last-doc-kind / preservation failure (actual quote
paraphrase) / recovery story / suggestion accepts-edits-dismissals / recurrence rate /
WTP number + billing preference / must-have blockers / falsifier rows touched`

## 6. Stopping rule (when recurrence is / isn't established)

- **Per sector:** minimum 6 interviews. After 6, stop the sector if the last 3 added
  no new preservation-failure type AND the recurrence verdict is unanimous
  (all-recurring or all-occasional).
- **Recurrence ESTABLISHED:** ≥4 of 6 in a sector name the same recurring layout with
  a concrete preservation failure → wedge holds for that sector; move sample to the
  next sector.
- **Recurrence NOT established:** ≤2 of 6 report any repeat preservation problem after
  8 interviews → record the wedge as FALSIFIED for that sector, stop recruiting it,
  and reallocate to the remaining sectors.
- **Global stop:** all six sectors resolved, or n=48 total. Write falsifier verdicts
  per sector into a dated amendment referencing D-005/D-052 — never as edits to the
  strategy doc itself.
