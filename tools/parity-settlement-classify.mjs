#!/usr/bin/env node
// parity-settlement-classify.mjs — netting-feasibility measurement over native/web
// semantic-parity reports (Round-3 R3-15 first step; must precede any settlement
// reducer build).
//
// Classifies every fixture of a parity report into settlement classes and
// answers the load-bearing question from the round-3 audit (§7.3): is the red
// parity state a *dispute backlog* (netting pays off) or *open measurement
// scope* (netting settles an empty set and adds machinery with zero payoff)?
//
// Classification rules (per fixture):
//   never-run          — fixture missing, or native/web status is not a
//                        terminal inspection state (inspected / inspectionFailed).
//   malformed-agree    — both lanes failed inspection AND the failure digests
//                        match exactly (failures agree; nothing to settle).
//   dispute            — one or more UNEXPECTED mismatches (not covered by the
//                        fixture's allowed-kinds classification). Only this
//                        class feeds a human-review queue under netting.
//   classified-variance— mismatches exist but every one is an allowed/classified
//                        kind (unexpected count 0): already dispositioned by the
//                        fixture classification, not a dispute.
//   exact-agree        — zero mismatches and the semantic projections agree
//                        (comparatorEquivalent or exactDigestEquality).
//   unclassified       — zero mismatches but the projections do not agree under
//                        either predicate; needs a comparator look before any
//                        settlement claim.
//
// Verdict semantics:
//   disputeCount === 0  → "trivially settled": a ParitySettlementReport reducer
//                         would attest an empty residual set. Record the
//                         condition instead of building machinery.
//   disputeCount > 0    → netting is feasible; the residual set is the human
//                         review queue (per reviewed-candidate doctrine).
//
// Usage:
//   node tools/parity-settlement-classify.mjs \
//     --report benchmark/results/preflight-parity-2026-08-25/parity-report.json \
//     --out benchmark/results/parity-settlement/classification-2026-09-17.json
//
// This tool is a measurement instrument, NOT a gate: it grants or revokes no
// gate status (D-055 concentration). Its output is evidence for release-gates
// bookkeeping and for the pool-ledger revisit condition on R3-15.
//
// Exit codes: 0 = classified (any outcome), 2 = usage/input error.

import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { createHash } from "node:crypto";
import path from "node:path";

const TERMINAL_STATUSES = new Set(["inspected", "inspectionFailed"]);

function parseArgs(argv) {
  const opts = { report: null, out: null };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--report") opts.report = argv[++i];
    else if (argv[i] === "--out") opts.out = argv[++i];
    else throw new Error(`Unknown argument: ${argv[i]}`);
  }
  if (!opts.report) throw new Error("--report <parity-report.json> is required");
  return opts;
}

export function classifyFixture(fixture) {
  const native = fixture.nativeStatus ?? "missing";
  const web = fixture.webStatus ?? "missing";
  if (!TERMINAL_STATUSES.has(native) || !TERMINAL_STATUSES.has(web)) {
    return { class: "never-run", reason: `non-terminal statuses native=${native} web=${web}` };
  }
  const digest = fixture.normalization?.semanticProjectionDigest ?? {};
  const exact = digest.exactDigestEquality === true;
  const comparatorEquivalent = digest.comparatorEquivalent === true;
  const unexpected = fixture.unexpectedMismatches ?? [];
  const mismatches = fixture.mismatches ?? [];

  if (native === "inspectionFailed" && web === "inspectionFailed") {
    if (exact) return { class: "malformed-agree", reason: "both lanes failed inspection; failure digests match exactly" };
    return { class: "unclassified", reason: "both lanes failed inspection but failure digests differ" };
  }
  if (unexpected.length > 0) {
    return {
      class: "dispute",
      reason: `${unexpected.length} unexpected mismatch(es)`,
      kinds: [...new Set(unexpected.map((m) => m.kind ?? "unknown"))].sort(),
    };
  }
  if (mismatches.length > 0) {
    return {
      class: "classified-variance",
      reason: `${mismatches.length} mismatch(es), all within the fixture's allowed/kinds classification`,
      kinds: [...new Set(mismatches.map((m) => m.kind ?? "unknown"))].sort(),
    };
  }
  if (comparatorEquivalent || exact) {
    return { class: "exact-agree", reason: exact ? "exact digest equality" : "comparator equivalence" };
  }
  return { class: "unclassified", reason: "zero mismatches but projections agree under neither predicate" };
}

export function summarize(fixtures) {
  const rows = fixtures.map((fixture) => {
    const outcome = classifyFixture(fixture);
    return {
      parityCaseID: fixture.parityCaseID ?? "(missing-id)",
      sourcePath: fixture.sourcePath ?? null,
      nativeStatus: fixture.nativeStatus ?? null,
      webStatus: fixture.webStatus ?? null,
      ...outcome,
    };
  });
  const counts = {};
  for (const row of rows) counts[row.class] = (counts[row.class] ?? 0) + 1;
  const disputeCount = counts.dispute ?? 0;
  const neverRunCount = counts["never-run"] ?? 0;
  const verdict = disputeCount > 0
    ? {
        nettingFeasible: true,
        statement:
          `${disputeCount} dispute fixture(s) form a non-empty residual set; a ` +
          `ParitySettlementReport reducer would route exactly these to human review ` +
          `and attest the remainder per fixture ID.`,
        reducerBuildRecommended: true,
      }
    : {
        nettingFeasible: false,
        statement:
          `Zero unexpected mismatches: the residual dispute set is EMPTY. The parity ` +
          `state is driven by open measurement scope (lanes/corpus classes not yet ` +
          `measured), not by engine disagreement. A settlement reducer would attest ` +
          `an empty set and add machinery with zero payoff — record the revisit ` +
          `condition instead of building it.`,
        reducerBuildRecommended: false,
      };
  return { rows, counts, disputeCount, neverRunCount, verdict };
}

function main() {
  let opts;
  try {
    opts = parseArgs(process.argv.slice(2));
  } catch (error) {
    console.error(`USAGE ERROR: ${error.message}`);
    process.exit(2);
  }
  let report;
  try {
    report = JSON.parse(readFileSync(opts.report, "utf8"));
  } catch (error) {
    console.error(`INPUT ERROR: cannot read parity report ${opts.report}: ${error.message}`);
    process.exit(2);
  }
  const fixtures = Array.isArray(report.fixtures) ? report.fixtures : [];
  if (fixtures.length === 0) {
    console.error(`INPUT ERROR: report contains no fixtures array: ${opts.report}`);
    process.exit(2);
  }
  const sourceDigest = createHash("sha256").update(readFileSync(opts.report)).digest("hex");
  const { rows, counts, disputeCount, neverRunCount, verdict } = summarize(fixtures);

  const classification = {
    schema: "pdf-editor.parity-settlement-classification",
    version: { major: 1, minor: 0 },
    generatedAt: new Date().toISOString(),
    sourceReport: { path: path.relative(process.cwd(), opts.report), sha256: sourceDigest },
    sourceHarness: report.harness ?? null,
    sourceProviders: { native: report.nativeProvider?.id ?? null, web: report.webProvider?.id ?? null },
    fixtureCount: fixtures.length,
    counts,
    disputeCount,
    neverRunCount,
    verdict,
    truthStatus: "observed-measurement",
    // Evidence, not authority: this artifact grants/revokes no gate status (D-055).
    // Its verdict feeds release-gates bookkeeping and the R3-15 revisit condition.
    gateAuthority: "none-measurement-only",
    fixtures: rows,
  };

  const encoded = JSON.stringify(classification, null, 2) + "\n";
  if (opts.out) {
    mkdirSync(path.dirname(opts.out), { recursive: true });
    writeFileSync(opts.out, encoded);
    console.log(`Wrote ${opts.out}`);
  } else {
    process.stdout.write(encoded);
  }
  console.log(
    `parity-settlement: fixtures=${fixtures.length} ` +
      Object.entries(counts).map(([k, v]) => `${k}=${v}`).join(" ") +
      ` | disputes=${disputeCount} neverRun=${neverRunCount}`
  );
  console.log(`verdict: ${verdict.statement}`);
}

// Only run main when executed directly (the test file imports the pure functions).
if (process.argv[1] && path.resolve(process.argv[1]) === path.resolve(import.meta.url.replace(/^file:\/\//, ""))) {
  main();
}
