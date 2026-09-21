#!/usr/bin/env node
// Case corpus for EXP-JEV-1 (NM-R15): labeled security-finding triage history.
//
// Label semantics (ratification tracked as an open owner item — see the JEV
// register in docs/task-inventory.md):
//   close   = the finding, as presented, should NOT have blocked work
//             (false positive, stale ledger entry, benign/informational)
//   escalate= true issue that required code remediation before release
//   contain = true issue already mitigated/contained at triage time, or
//             accepted-with-control (monitor/guard exists)
//
// Corpus honesty notes (from the 2026-09-19 data inventory, keep visible):
// - SEC/RT cases are human-adjudicated audit findings (independent labels).
// - Mimosa cases are reconstructed from docs/audits/epistemic-integrity-audit-
//   per-0922-2026-09-06.md §15 prose (12 of 13 itemized; raw scanner text is
//   not recoverable — upgrade path recorded in the register).
// - Fixture-derived cases are CIRCULAR vs. the deterministic baseline (labels
//   come from the same rules) and are therefore excluded from calibration
//   scoring in v1; they serve only as regression/clean-class smoke cases.
//
// Triage-time framing: SEC/RT findings are labeled as-presented-at-discovery
// (escalate) with a containment note; at post-remediation replay they would
// read contain. v1 replays the discovery frame.

export const TRIAGE_OPTIONS = ["close", "escalate", "contain"];

const sec = (id, severity, title, findingText, rationale) => ({
  id,
  source: "application-security-audit-per-pdev-0167",
  expected: severity === "Info" ? "close" : "escalate",
  trueClass: "tp",
  rationale,
  state: `[PDF security lane finding ${id}] severity=${severity}. ${findingText}`,
});

const rt = (id, severity, title, findingText) => ({
  id,
  source: "red-team-campaign-audit-per-pdev-0168",
  expected: severity === "Informational" ? "close" : "escalate",
  trueClass: "tp",
  rationale: `red-team ${severity}, remediated with regression test`,
  state: `[PDF security lane finding ${id}] severity=${severity}. ${findingText}`,
});

const mimosa = (id, kind, findingText) => ({
  id,
  source: "mimosa-episode-2026-09-08 (epistemic audit §15)",
  expected: "close",
  trueClass: kind === "stale" ? "fp_stale" : "fp",
  rationale:
    kind === "stale"
      ? "gate replayed a ledger entry for a file that no longer exists"
      : "static-analysis false positive on trusted-input operator tooling (fixed constants / guard-ignoring rule)",
  state: `[static-analysis finding ${id}] ${findingText}`,
});

export function buildCases() {
  return [
    // --- SEC-001..008 (application security audit §3; severity + containment recorded there)
    sec("SEC-001", "High", "Path traversal in extraction sink", "Extraction output path built from unvalidated user-supplied filename allows writing outside the workspace boundary via ../ traversal.", "real vulnerability class; required sink containment fix"),
    sec("SEC-002", "High", "Unconfined file write in tooling", "Operator CLI tool wrote extracted artifacts to an unconfined path derived from input arguments.", "real; required confined-path write fix"),
    sec("SEC-003", "Medium", "Sanitize bypass via incremental revision", "Stripped metadata remains recoverable through a previous incremental revision shadow; sanitize reported clean while original content persisted in the revision chain.", "real; required revision-aware strip"),
    sec("SEC-004", "Medium", "Attachment content-type spoofing", "Embedded attachment declares benign extension while carrying executable content type; scanner surfaced suspicious reasons but release flow did not block.", "real; required verdict wiring into preflight block"),
    sec("SEC-005", "Medium", "JavaScript remnant across rewrite", "Document rewrite collapsed visible structure but /JS action remnant survived in an orphaned object.", "real; required remnant sweep on rewrite"),
    sec("SEC-006", "Low", "Metadata over-retention", "Producer/creator tool strings and timestamps retained after 'privacy clean' export, over-disclosing provenance.", "real but low; policy hardening"),
    sec("SEC-007", "Low", "Weak default crypto params in template persistence", "Locally persisted encrypted templates used a less conservative KDF iteration count than the platform default recommendation.", "real but low; parameter bump"),
    sec("SEC-008", "Info", "Informational: verbose error surfaces", "Internal error strings surfaced file-system paths in debug logs; no boundary crossed in release configuration.", "informational; log hygiene only"),

    // --- RT-001..004 (red-team campaign §3/§6; all High/Medium/Low remediated + regression-tested)
    rt("RT-001", "High", "Malformed xref crash", "Hand-crafted cross-reference table causes parser index panic; crash-only, no memory disclosure observed.", "remediated fail-safe + regression test"),
    rt("RT-002", "Medium", "Signature ghost via unsigned incremental save", "Document displays a valid signature widget while an incremental update after signing alters page content undetected by the viewer path.", "remediated: post-signature revision detection + guard"),
    rt("RT-003", "Medium", "Encrypted reader bypass via empty-user-password", "Owner-password-only document opened with implicit empty user password exposes content the operator believed protected.", "remediated: explicit auth-state disclosure"),
    rt("RT-004", "Low", "Extraction doublespeak", "Extracted text differs from rendered page under specific glyph-to-Unicode maps, enabling rendering/extract divergence.")

    ,
    // --- Mimosa episode, reconstructed from epistemic audit §5/§15 prose (12 of 13 itemized)
    mimosa("MIM-01", "fp", "Path traversal: open(<var>,'w') in operator script", "Scanner flags open(variable,'w') sink in a trusted-input operator CLI script; the path is a compile-time constant passed by the repo's own tooling; the rule ignores _confined() containment wrappers."),
    mimosa("MIM-02", "fp", "Path traversal: fixed-constant sink", "Identical rule firing on a second operator script whose write target is a literal constant directory inside the workspace."),
    mimosa("MIM-03", "fp", "Path traversal: fixed-constant sink (3rd script)", "Same rule, same trusted-input pattern, third operator script with a constant output path."),
    mimosa("MIM-04", "fp", "Path traversal: fixed-constant sink (4th script)", "Same rule family; constant output path; no user data reaches the sink."),
    mimosa("MIM-05", "fp", "Path traversal: fixed-constant sink (5th script)", "Same rule family; constant output path; generator script writing into its own benchmark directory."),
    mimosa("MIM-06", "fp", "Path traversal: fixed-constant sink (6th script)", "Same rule family; constant output path under docs/."),
    mimosa("MIM-07", "fp", "Path traversal: fixed-constant sink (7th script)", "Same rule family; constant output path under tools/."),
    mimosa("MIM-08", "fp", "Path traversal: fixed-constant sink (8th script)", "Same rule family; constant output path under benchmark/."),
    mimosa("MIM-09", "fp", "Path traversal: guard-ignored containment", "Sink uses the project's _confined() containment helper; the scanner rule does not recognize the guard and flags the raw sink call."),
    mimosa("MIM-10", "fp", "Path traversal: guard-ignored containment (2nd)", "Second _confined()-guarded sink flagged by the same guard-ignoring rule."),
    mimosa("MIM-11", "fp", "Path traversal: guard-ignored containment (3rd)", "Third _confined()-guarded sink flagged by the same rule."),
    mimosa("MIM-12", "fp_stale", "Code injection: vendored test.js resurrect", "Injection finding on test.js inside vendored veraPDF's Rhino test payload, extracted from a tracked zip; the file is vendored test data, not executed code, and the ledger entry kept resurrecting from the archive."),

    // --- Clean-class smoke cases (fixture-derived, circular vs baseline; excluded from calibration)
    {
      id: "CLEAN-01",
      source: "fixture: pdf-signature-guard unsigned-clean",
      expected: "close",
      trueClass: "clean",
      circular: true,
      rationale: "unsigned document, no signature expectations, detector reports clean",
      state: "[PDF security lane finding CLEAN-01] Unsigned document scanned by signature guard: no signature widgets, no byte-range anomalies, status clean.",
    },
    {
      id: "CLEAN-02",
      source: "fixture: pdf-xfa-guard acroform-no-xfa",
      expected: "close",
      trueClass: "clean",
      circular: true,
      rationale: "real AcroForm document, XFA detector reports absent",
      state: "[PDF security lane finding CLEAN-02] AcroForm-only document scanned by XFA guard: no XFA packets present, xfaKind=none.",
    },
    {
      id: "CLEAN-03",
      source: "fixture: pdf-hidden-revision-analyzer single-revision",
      expected: "close",
      trueClass: "clean",
      circular: true,
      rationale: "single-revision document, no shadowed remnant objects",
      state: "[PDF security lane finding CLEAN-03] Hidden-revision analyzer: document has a single revision, no orphaned object streams, no active-content remnants.",
    },
    {
      id: "CLEAN-04",
      source: "fixture: pdf-attachment-scanner clean attachment",
      expected: "close",
      trueClass: "clean",
      circular: true,
      rationale: "text attachment with benign declared type, no suspicious reasons",
      state: "[PDF security lane finding CLEAN-04] Attachment scanner: single text/plain attachment, declared type matches content, no suspicious reasons.",
    },
  ];
}

export function scoreableCases(cases) {
  return cases.filter((c) => !c.circular);
}
