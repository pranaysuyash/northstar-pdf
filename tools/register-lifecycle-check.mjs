#!/usr/bin/env node
// register-lifecycle-check.mjs — validates the ADHD exploration pool ledger's
// register lifecycle (the adhd skill's Persistence step 8: "if the project has
// a register-lifecycle checker (IDs, status, re-verification dates), run it
// before claiming done").
//
// Checks, per idea row of every round section in
// docs/explorations/adhd-exploration-pool-ledger.md:
//   1. IDs unique within their round section.
//   2. Primary status is from the ledger's status grammar.
//   3. parked-conditional rows carry an explicit promote/revisit condition
//      ("promote when X" — never a bare rejection).
//   4. graduated rows carry a pointer into a real register/commit.
//   5. The ledger header's coverage claim matches the round sections present.
//
// This tool validates register hygiene; it does NOT verify that statuses are
// factually current (that needs code inspection at pickup time).
//
// Usage:
//   node tools/register-lifecycle-check.mjs [--ledger docs/explorations/adhd-exploration-pool-ledger.md]
//
// Exit codes: 0 = register clean, 1 = violations found, 2 = usage/input error.

import { readFileSync } from "node:fs";

const STATUS_VOCABULARY = [
  "deepened",
  "parked-implementable",
  "parked-explorable",
  "parked-conditional",
  "graduated",
  "superseded",
  "rejected",
  "adopted",
  "partial",
  "open",
  "done",
  "standing principle",
];

function parseArgs(argv) {
  const opts = { ledger: "docs/explorations/adhd-exploration-pool-ledger.md" };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--ledger") opts.ledger = argv[++i];
    else throw new Error(`Unknown argument: ${argv[i]}`);
  }
  return opts;
}

function splitRoundSections(text) {
  const sections = [];
  const re = /^## (Round \d+ pool \(\d{4}-\d{2}-\d{2}\))$/gm;
  let match;
  while ((match = re.exec(text)) !== null) {
    sections.push({
      title: match[1],
      line: text.slice(0, match.index).split("\n").length,
      start: match.index + match[0].length,
    });
  }
  for (let i = 0; i < sections.length; i++) {
    const end = i + 1 < sections.length ? sections[i + 1].start : text.length;
    sections[i].body = text.slice(sections[i].start, end);
  }
  return sections;
}

function ideaRows(body, baseLine) {
  const rows = [];
  const lines = body.split("\n");
  lines.forEach((line, index) => {
    // Idea-table rows: | ID | Idea (short) | Status ... | — tolerate the
    // round-1 unnumbered IDs (R1, Y3, B2), the round-3 form (R3-01), and the
    // round-2 four-column summary (| # | Idea | Cluster | Status |), where the
    // status is the LAST cell.
    const match = line.match(/^\|\s*([A-Z]\d+(?:-\d+)?)\s*\|([^|]+)((?:\|[^|]+)+)\|/);
    if (match && !/^\s*Idea/.test(match[2]) && !/^-+$/.test(match[2].trim())) {
      const cells = match[3].split("|").map((cell) => cell.trim());
      rows.push({
        id: match[1],
        idea: match[2].trim(),
        statusCell: cells[cells.length - 1],
        line: baseLine + index,
      });
    }
  });
  return rows;
}

function check(opts) {
  let text;
  try {
    text = readFileSync(opts.ledger, "utf8");
  } catch (error) {
    console.error(`INPUT ERROR: cannot read ledger ${opts.ledger}: ${error.message}`);
    process.exit(2);
  }
  const violations = [];
  const sections = splitRoundSections(text);

  if (sections.length === 0) {
    violations.push("No '## Round N pool (YYYY-MM-DD)' sections found.");
  }

  const coveredInHeader = (text.match(/Round \d+ \(发光?\d{4}-\d{2}-\d{2}\)|Round \d+ \(\d{4}-\d{2}-\d{2}\)/g) ?? [])
    .filter((s) => !s.includes("pool")).length;
  if (coveredInHeader < sections.length) {
    violations.push(
      `Header coverage claim (${coveredInHeader} rounds) is below actual round sections (${sections.length}).`
    );
  }

  for (const section of sections) {
    const rows = ideaRows(section.body, section.line);
    const seen = new Map();
    for (const row of rows) {
      const where = `${opts.ledger}:${row.line} [${row.id}]`;
      if (seen.has(row.id)) violations.push(`${where} duplicate ID (first at line ${seen.get(row.id)}).`);
      seen.set(row.id, row.line);

      const clean = row.statusCell.replace(/\*\*/g, "").trim();
      const primary = STATUS_VOCABULARY.find((status) => clean.toLowerCase().startsWith(status));
      if (!primary) {
        violations.push(`${where} unknown status "${clean.slice(0, 40)}".`);
        continue;
      }
      if (primary === "parked-conditional" && !/promote|revisit|when\b|only if|unless/i.test(clean)) {
        violations.push(`${where} parked-conditional without an explicit promote/revisit condition.`);
      }
      if (primary === "graduated" && !/(docs\/|Sources\/|\.swift|commit|\()/i.test(clean)) {
        violations.push(`${where} graduated without a pointer into a real register/commit.`);
      }
    }
    if (rows.length === 0) violations.push(`${section.title} at line ${section.line}: no idea rows found.`);
  }

  return { sections: sections.length, rowsChecked: sections.reduce((n, s) => n + ideaRows(s.body, s.line).length, 0), violations };
}

function main() {
  let opts;
  try {
    opts = parseArgs(process.argv.slice(2));
  } catch (error) {
    console.error(`USAGE ERROR: ${error.message}`);
    process.exit(2);
  }
  const result = check(opts);
  console.log(`register-lifecycle-check: rounds=${result.sections} rows=${result.rowsChecked} violations=${result.violations.length}`);
  for (const violation of result.violations) console.log(`  VIOLATION: ${violation}`);
  process.exit(result.violations.length > 0 ? 1 : 0);
}

main();
