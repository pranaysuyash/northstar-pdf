#!/usr/bin/env node
// Deterministic baseline triage for EXP-JEV-1: what the repo's own rule-based
// posture would say, without any model. This is the comparator the Jev
// calibration report must beat (kill criterion lives in the research doc §4).
//
// Design honesty: this baseline is experimenter-authored like every heuristic.
// Its rules mirror the two real deterministic signals we actually have —
// (a) lane reason-codes/markers (structural facts), (b) the Mimosa-episode
// lesson (trusted-input constant sinks and vendored test payloads are FPs).
// Unknown inputs fail CLOSED to "contain" (repo doctrine: never auto-close).

const RULES = [
  {
    name: "vendored-test-payload",
    test: (s) => /vendored|test\.js|rhino|verapdf.*test/i.test(s.text),
    verdict: "close",
    confidence: 0.9,
    why: "vendored test payload, not executed product code",
  },
  {
    name: "trusted-input-constant-sink",
    test: (s) =>
      /path traversal|open\(.*'w'\)|sink/i.test(s.text) &&
      /constant|fixed|trusted|\b_confined\b|own tooling/i.test(s.text),
    verdict: "close",
    confidence: 0.85,
    why: "traversal-shaped finding on a trusted-input constant sink (Mimosa class)",
  },
  {
    name: "stale-ledger-entry",
    test: (s) => /no longer exists|stale ledger|resurrect/i.test(s.text),
    verdict: "close",
    confidence: 0.9,
    why: "ledger cites a file that is gone — stale by definition",
  },
  {
    name: "informational-hygiene",
    test: (s) => /severity=Info|severity=Informational|log hygiene/i.test(s.text),
    verdict: "close",
    confidence: 0.8,
    why: "informational class never blocks",
  },
  {
    name: "active-content-remnant",
    test: (s) => /\/JS|JavaScript remnant|OpenAction|Launch.*action|\/AA\b/i.test(s.text) && /remnant|survived|shadow|persisted/i.test(s.text),
    verdict: "escalate",
    confidence: 0.85,
    why: "active content surviving sanitization is release-blocking",
  },
  {
    name: "signature-integrity",
    test: (s) => /signature.*(alter|undetected|bypass)|ghost|post-signature/i.test(s.text),
    verdict: "escalate",
    confidence: 0.85,
    why: "signature integrity break is trust-critical",
  },
  {
    name: "boundary-crossing",
    test: (s) => /outside the (workspace|boundary)|unvalidated user-supplied|unconfined/i.test(s.text),
    verdict: "escalate",
    confidence: 0.8,
    why: "validated boundary crossing with user-controlled input",
  },
  {
    name: "disclosure-vs-protection",
    test: (s) => /believed protected|over-disclos|over-retention/i.test(s.text),
    verdict: "contain",
    confidence: 0.6,
    why: "privacy/provenance hygiene — true but policy-tier, contained by disclosure fix",
  },
  {
    name: "crash-only-failsafe",
    test: (s) => /crash-only|panic|fail-safe/i.test(s.text),
    verdict: "contain",
    confidence: 0.6,
    why: "availability bug with fail-safe already landed",
  },
];

/**
 * @param {{id: string, state: string}}}}{{{case}}} c
 */
export function baselineTriage(c) {
  const text = c.state;
  for (const rule of RULES) {
    if (rule.test({ text })) {
      return { verdict: rule.verdict, confidence: rule.confidence, rule: rule.name, why: rule.why };
    }
  }
  return {
    verdict: "contain",
    confidence: 0.5,
    rule: "fail-closed-default",
    why: "no deterministic rule matched — contained pending human review",
  };
}
