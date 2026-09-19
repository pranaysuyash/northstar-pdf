#!/usr/bin/env node
// export-form-class-ledger.mjs — public validated-form-class ledger (round-3
// presale branch; R3-29 spine artifact / R3-25 step 1).
//
// Renders the repo's gate evidence as the public ledger page the presale
// branch publishes: which corpus fixtures are human-visually confirmed, and
// which recurring form classes are certified. Honesty is structural:
//   - Every row links back to the gate report it came from (path + SHA-256).
//   - Form-class certification starts EMPTY. Nothing here claims a form class
//     is green; certification is a decision + fixture + review act that has
//     not happened (D-055; RG-135 cohort scope pending).
//   - This tool is disclosure, not authority: it grants no gate status.
//
// Usage:
//   node tools/export-form-class-ledger.mjs \
//     --human-report benchmark/results/human-visual-confirmation/human-review-gate-report.json \
//     --out-json docs/public/form_class_ledger.json \
//     --out-html docs/public/ledger.html
//
// Exit codes: 0 = exported, 2 = usage/input error.

import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { createHash } from "node:crypto";
import path from "node:path";

function parseArgs(argv) {
  const opts = { humanReport: null, outJson: "docs/public/form_class_ledger.json", outHtml: "docs/public/ledger.html" };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--human-report") opts.humanReport = argv[++i];
    else if (argv[i] === "--out-json") opts.outJson = argv[++i];
    else if (argv[i] === "--out-html") opts.outHtml = argv[++i];
    else throw new Error(`Unknown argument: ${argv[i]}`);
  }
  if (!opts.humanReport) throw new Error("--human-report <human-review-gate-report.json> is required");
  return opts;
}

function digestOf(file) {
  return createHash("sha256").update(readFileSync(file)).digest("hex");
}

function fixtureRows(report) {
  const rows = [];
  const add = (name, status) => rows.push({ fixture: name, status });
  for (const name of report.pendingFixtures ?? []) add(name, "pending");
  for (const name of report.confirmedFixtures ?? report.confirmed ?? []) add(name, "confirmed");
  for (const name of report.failedFixtures ?? []) add(name, "failed");
  for (const name of report.staleFixtures ?? []) add(name, "stale");
  // Consistency check against the report's own counts — a mismatch is a
  // defect of the source report, surfaced here rather than silently papered.
  if (rows.length !== report.totalFixtures) {
    throw new Error(
      `Source report inconsistency: totalFixtures=${report.totalFixtures} but rows resolved=${rows.length}. ` +
        `Fix the source report; the public ledger must not guess.`
    );
  }
  return rows.sort((a, b) => a.fixture.localeCompare(b.fixture));
}

const HTML_SHELL = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Northstar PDF — Validated Form-Class Ledger</title>
<style>
  :root { color-scheme: light; }
  body { font: 15px/1.55 -apple-system, "SF Pro Text", Helvetica, Arial, sans-serif; margin: 0 auto; max-width: 56rem; padding: 2rem 1.25rem 4rem; color: #1d1d1f; }
  h1 { font-size: 1.6rem; margin: 0 0 .25rem; }
  .lede { color: #515154; margin-top: 0; }
  .provenance { font-size: .78rem; color: #6e6e73; word-break: break-all; }
  .banner { border: 1px solid #d2d2d7; border-left: 4px solid #b25000; background: #fff7ed; padding: .9rem 1rem; border-radius: 8px; margin: 1.25rem 0; }
  .banner strong { color: #b25000; }
  h2 { font-size: 1.15rem; margin-top: 2rem; }
  table { border-collapse: collapse; width: 100%; font-size: .85rem; }
  td, th { border: 1px solid #d2d2d7; padding: .35rem .6rem; text-align: left; }
  th { background: #f5f5f7; }
  .pending { color: #b25000; font-weight: 600; }
  .confirmed { color: #1d7a36; font-weight: 600; }
  .failed { color: #c21807; font-weight: 600; }
  .stale { color: #8a8a8e; font-weight: 600; }
  .empty-note { color: #515154; font-style: italic; }
  footer { margin-top: 3rem; font-size: .8rem; color: #6e6e73; border-top: 1px solid #d2d2d7; padding-top: 1rem; }
</style>
</head>
<body>
<h1>__TITLE__</h1>
<p class="lede">A live, honest record of what the product has and has not proven. This page is generated from the repository's gate reports; nothing on it is a marketing claim.</p>
<div class="banner"><strong>Nothing is certified yet.</strong> The form-class section below is empty by construction: certification requires a recorded decision, cohort fixtures, and human visual review. When a form class passes, it appears here with the gate report that proves it. No presale, deposit, or nomination promise should be read into this page — it only publishes observed gate state.</div>
<h2>Recurring form classes — certified</h2>
<p class="empty-note">None certified yet. Certification for a named form class (e.g. IRS W-9) requires: a D-055 decision entry, a cohort fixture set spanning real arrival variance, and human visual confirmation reported by the review gate.</p>
<h2>Human visual confirmation gate — corpus fixtures (38)</h2>
<p class="provenance">Source: <code>__REPORT_REL__</code> · sha256 <code>__REPORT_DIGEST__</code> · generated at <code>__GENERATED_AT__</code> · gate status: <code>__GATE_STATUS__</code></p>
<table>
<tr><th>Fixture</th><th>Status</th></tr>
__FIXTURE_ROWS__
</table>
<footer>Generated by <code>tools/export-form-class-ledger.mjs</code> · disclosure only, no gate authority (D-055) · schema <code>pdf-editor.form-class-ledger</code> v1.0</footer>
</body>
</html>
`;

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
    report = JSON.parse(readFileSync(opts.humanReport, "utf8"));
  } catch (error) {
    console.error(`INPUT ERROR: cannot read human-review gate report: ${error.message}`);
    process.exit(2);
  }
  const rows = fixtureRows(report);
  const reportRel = path.relative(process.cwd(), opts.humanReport);
  const reportDigest = digestOf(opts.humanReport);
  const generatedAt = new Date().toISOString();

  const ledger = {
    schema: "pdf-editor.form-class-ledger",
    version: { major: 1, minor: 0 },
    generatedAt,
    truthStatus: "observed-gate-state-public-disclosure",
    gateAuthority: "none-disclosure-only",
    sources: [{ path: reportRel, sha256: reportDigest, schema: report.schema, status: report.status }],
    humanVisualGate: {
      schema: report.schema,
      status: report.status,
      totalFixtures: report.totalFixtures,
      confirmedCount: report.confirmedCount,
      failedCount: report.failedCount,
      staleCount: report.staleCount,
      fixtures: rows,
    },
    formClasses: [],
    formClassNote:
      "Empty by construction: no recurring form class is certified. Certification requires a recorded decision (D-055), a cohort fixture set spanning real arrival variance, and human visual confirmation.",
  };

  const fixtureRowsHtml = rows
    .map((row) => `<tr><td>${row.fixture}</td><td class="${row.status}">${row.status}</td></tr>`)
    .join("\n");
  const html = HTML_SHELL.replace("__TITLE__", "Northstar PDF — Validated Form-Class Ledger")
    .replace("__REPORT_REL__", reportRel)
    .replace("__REPORT_DIGEST__", reportDigest.slice(0, 16) + "…")
    .replace("__GENERATED_AT__", generatedAt)
    .replace("__GATE_STATUS__", report.status)
    .replace("__FIXTURE_ROWS__", fixtureRowsHtml);

  for (const out of [opts.outJson, opts.outHtml]) mkdirSync(path.dirname(out), { recursive: true });
  writeFileSync(opts.outJson, JSON.stringify(ledger, null, 2) + "\n");
  writeFileSync(opts.outHtml, html);
  console.log(`Wrote ${opts.outJson} and ${opts.outHtml}`);
  console.log(`Ledger: fixtures=${rows.length} confirmed=${report.confirmedCount} formClasses=0 (honest-empty)`);
}

main();
