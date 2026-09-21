#!/usr/bin/env node
// Jev-backed priority pass over the open-items ledger (owner request,
// 2026-09-21). Asks the pinned System-One model two typed questions per open
// item: a Score on an explicit 2..10 priority ladder and a Choice of
// execution lane. Internal-only use (our own ledger text — no user data, no
// egress concerns beyond the API call itself).
//
// Usage:
//   node tools/jev-prioritize/prioritize.mjs [--items <path>] [--limit N] [--concurrency N]
//
// Outputs:
//   - tools/jev-prioritize/results-<date>.json   (full per-item judgments)
//   - stdout: ranked markdown table
//
// Validity ceiling: EXP-JEV-1 (docs/research/jev-expjev1-report-2026-09-21.md)
// recorded a KILL SIGNAL for Jev's close/escalate/contain triage calibration.
// This pass is exploratory (different task shape: explicit score ladder +
// structured states), not calibrated evidence — treat as advisory input only.

import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { loadApiKey, jevQuestions } from "../jev-replay/jev-client.mjs";

const REPO_ROOT = join(import.meta.dirname, "..", "..");
const argv = process.argv.slice(2);
const arg = (name, fallback) => {
  const i = argv.indexOf(name);
  return i >= 0 && argv[i + 1] !== undefined ? argv[i + 1] : fallback;
};

// Project state preamble — the same facts for every item so judgments are
// comparable. Sourced from docs/task-inventory.md, docs/release-gates.md,
// docs/audits/ (persona-launch + snappiness audits) as of 2026-09-21.
const PREAMBLE = `Project: Northstar PDF — a native macOS SwiftUI PDF reader/editor (technical target PDFEditor), pre-GA, single owner.
Current facts (2026-09-21): full Swift test suite green on CI since 2026-09-15; deterministic form-parity gates green (RG-134 closed; radio 0.938 is a known, classified residual); human visual confirmation gate RG-135 stands at 0/38 fixtures and fails closed against any release; codesign/notarization and auto-update are blocked on external credentials/hosting; commerce/monetization is not started (planned $79 one-time tier); a persona-launch audit verdict is NO-GO for GA with a bounded-cohort path instead; the owner has locked decision D-083: an AI-native agentic shell direction with implementation slices 0-4 (NM-T41..45) all pending; a 2026-09-19 SwiftUI performance audit confirmed 12 findings including 2 critical main-thread stalls that degrade app snappiness today; a large React-port program (A-11..A-16) is mid-flight with legacy app.js still the editor of record.
Release rule: no unrestricted release claim while a hard release gate is OPEN, BLOCKED, or FAIL.
The owner is one person; agent lanes do implementation work, the owner makes decision-class calls and external purchases.`;

const PRIORITY_LADDER = [
  "Priority 2: defer indefinitely — cosmetic only",
  "Priority 3: park — revisit next quarter",
  "Priority 4: backlog — no scheduled slot",
  "Priority 5: nice-to-have someday",
  "Priority 6: useful when convenient",
  "Priority 7: schedule soon — helps velocity",
  "Priority 8: high — blocks other work",
  "Priority 9: very high — gates the next milestone",
  "Priority 10: launch-blocking — do now",
];

const LANE_QUESTION = {
  id: "lane",
  type: "choice",
  prompt: "Which execution lane should this item's next action sit in?",
  options: ["do-now", "do-next", "do-later", "owner-decision", "park"],
  optionCriteria: {
    "do-now": "start immediately — high urgency and agent-executable or cheap",
    "do-next": "schedule next — important but sequenced after current work",
    "do-later": "backlog — real but not now",
    "owner-decision": "the next action is fundamentally an owner call (money, credentials, product direction, kill/continue)",
    "park": "shelve — low value or premature",
  },
};

const PRIORITY_QUESTION = {
  id: "priority",
  type: "score",
  criteria: PRIORITY_LADDER,
};

function itemState(item) {
  return `${PREAMBLE}

OPEN ITEM [${item.id}] — lane: ${item.lane}; ledger state: ${item.state}
Open work: ${item.action}`;
}

async function judgeWithRetry(key, item, attempts = 3) {
  let lastErr;
  for (let i = 0; i < attempts; i++) {
    try {
      const answers = await jevQuestions(key, itemState(item), [PRIORITY_QUESTION, LANE_QUESTION], {
        capture: true,
        label: item.id,
      });
      const priority = answers.find((a) => a.id === "priority");
      const lane = answers.find((a) => a.id === "lane");
      return {
        id: item.id,
        priorityScore: priority.score,
        priorityLevel: priority.score == null ? null : priority.score + 2,
        priorityConfidence: priority.confidence,
        priorityProbabilities: priority.probabilities,
        lane: lane.selection,
        laneConfidence: lane.confidence,
        laneProbabilities: lane.probabilities,
        servedModel: priority.servedModel,
      };
    } catch (err) {
      lastErr = err;
      await new Promise((r) => setTimeout(r, 1500 * (i + 1)));
    }
  }
  return { id: item.id, error: String(lastErr?.message ?? lastErr) };
}

async function main() {
  const { key, source } = loadApiKey();
  if (!key) {
    console.error("no JEV_API_KEY/TYPESAFE_API_KEY found (checked env, repo .env, ~/Projects/.env.local)");
    process.exit(1);
  }
  const itemsPath = arg("--items", join(import.meta.dirname, "open-items-2026-09-21.json"));
  const items = JSON.parse(readFileSync(itemsPath, "utf8")).items;
  const limit = Number(arg("--limit", "0"));
  const concurrency = Number(arg("--concurrency", "4"));
  const run = limit > 0 ? items.slice(0, limit) : items;

  console.error(`items: ${run.length}/${items.length} (key: ${source})`);
  const results = [];
  let next = 0;
  await Promise.all(
    Array.from({ length: Math.min(concurrency, run.length) }, async () => {
      while (next < run.length) {
        const item = run[next++];
        const r = await judgeWithRetry(key, item);
        results.push(r);
        console.error(`  ${item.id}: ${r.error ? "ERROR " + r.error : `P${r.priorityLevel?.toFixed(2)} ${r.lane} (conf ${r.priorityConfidence}/${r.laneConfidence})`}`);
      }
    }),
  );

  const date = new Date().toISOString().slice(0, 10);
  const errors = results.filter((r) => r.error);
  const ranked = results.filter((r) => !r.error).sort((a, b) => b.priorityScore - a.priorityScore);
  const out = {
    run_date: date,
    items_file: itemsPath,
    item_count: run.length,
    errors: errors.length,
    results: ranked.concat(errors),
  };
  const outPath = join(import.meta.dirname, `results-${date}.json`);
  writeFileSync(outPath, JSON.stringify(out, null, 2));

  console.log(`\n| Rank | Item | P-level | Lane (conf) | P-conf |`);
  console.log(`|---|---|---|---|---|`);
  ranked.forEach((r, i) => {
    console.log(`| ${i + 1} | ${r.id} | ${r.priorityLevel.toFixed(2)} | ${r.lane} (${r.laneConfidence}) | ${r.priorityConfidence} |`);
  });
  if (errors.length) {
    console.log(`\nERRORS (${errors.length}):`);
    for (const e of errors) console.log(`  ${e.id}: ${e.error}`);
  }
  console.error(`results written: ${outPath}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
