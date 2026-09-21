#!/usr/bin/env node
// EXP-JEV-1 replay orchestrator (NM-R15).
//
// Usage:
//   node tools/jev-replay/replay.mjs                 # baseline + Jev if key present
//   node tools/jev-replay/replay.mjs --baseline-only # deterministic lane only
//
// Outputs:
//   - docs/research/jev-expjev1-report-<date>.md  (tracked evidence)
//   - tools/jev-replay/raw/                       (per-call captures, gitignored)
//
// Exit oracle (research doc §4): per-class accuracy + calibration error vs
// this deterministic baseline. KILL if calibration is materially worse than
// baseline, or if confidence is INFLATED on the known false-positive class.

import { writeFileSync, mkdirSync } from "node:fs";
import { join } from "node:path";
import { buildCases, scoreableCases, TRIAGE_OPTIONS } from "./corpus.mjs";
import { baselineTriage } from "./baseline.mjs";
import { loadApiKey, jevChoice } from "./jev-client.mjs";

const REPO_ROOT = join(import.meta.dirname, "..", "..");
const args = new Set(process.argv.slice(2));
const QUESTION =
  "A PDF security lane produced this finding. Triage it for a privacy-positioned desktop PDF app: should the finding be closed (false positive/stale/benign), escalated (true issue requiring remediation before release), or contained (true issue already mitigated or accepted with a control)?";

function accuracy(preds) {
  const byClass = {};
  let hits = 0;
  for (const p of preds) {
    byClass[p.expected] ??= { n: 0, hit: 0 };
    byClass[p.expected].n += 1;
    if (p.verdict === p.expected) {
      byClass[p.expected].hit += 1;
      hits += 1;
    }
  }
  return {
    overall: preds.length ? hits / preds.length : 0,
    byClass,
  };
}

function calibrationStats(preds) {
  // Brier score over the realized class (lower is better). Confidence is
  // deterministic-rule-authored for the baseline (honest, not model-derived);
  // for Jev it is the model's trained calibration — the thing under test.
  let brier = 0;
  const fpConf = [];
  for (const p of preds) {
    const correct = p.verdict === p.expected ? 1 : 0;
    const conf = typeof p.confidence === "number" ? p.confidence : 0.5;
    brier += (conf - correct) ** 2;
    if (p.trueClass === "fp" || p.trueClass === "fp_stale") fpConf.push(conf);
  }
  return {
    brier: preds.length ? brier / preds.length : 1,
    meanFpConfidence: fpConf.length ? fpConf.reduce((a, b) => a + b, 0) / fpConf.length : 0,
    fpCount: fpConf.length,
  };
}

async function main() {
  const allCases = buildCases();
  const scoreable = scoreableCases(allCases);
  const { key } = args.has("--baseline-only") ? { key: null } : loadApiKey();
  const runJev = Boolean(key);

  console.log(`cases: ${allCases.length} total, ${scoreable.length} scoreable (non-circular)`);
  console.log(`jev lane: ${runJev ? "ON (key found)" : "OFF — baseline-only run (no JEV_API_KEY/TYPESAFE_API_KEY in env or .env)"}`);

  // Baseline pass (always — it is the comparator).
  const baselinePreds = scoreable.map((c) => ({ ...c, ...baselineTriage(c) }));
  const baseline = { acc: accuracy(baselinePreds), cal: calibrationStats(baselinePreds) };
  console.log(`baseline: accuracy=${baseline.acc.overall.toFixed(3)} brier=${baseline.cal.brier.toFixed(3)} meanFpConf=${baseline.cal.meanFpConfidence.toFixed(3)}`);

  // Jev pass (only with a key).
  let jev = null;
  if (runJev) {
    const preds = [];
    for (const c of scoreable) {
      try {
        const a = await jevChoice(key, c.state, { question: QUESTION, options: TRIAGE_OPTIONS }, {
          capture: true,
          label: c.id,
        });
        const verdict = TRIAGE_OPTIONS.includes(a.selection) ? a.selection : "contain";
        preds.push({ ...c, verdict, confidence: a.confidence ?? 0.5, rule: "jev" });
        console.log(`  jev ${c.id}: ${verdict} (conf ${a.confidence ?? "?"}) expected ${c.expected}`);
      } catch (err) {
        console.error(`  jev ${c.id} FAILED: ${err.message}`);
        preds.push({ ...c, verdict: "error", confidence: 0, rule: "jev-error" });
      }
    }
    const ok = preds.filter((p) => p.verdict !== "error");
    jev = ok.length ? { acc: accuracy(ok), cal: calibrationStats(ok), errors: preds.length - ok.length } : null;
  }

  // Kill-criterion evaluation (v1 = smoke test; see corpus honesty notes).
  let killVerdict = "n/a — smoke-test run";
  if (jev) {
    const worseAccuracy = jev.acc.overall < baseline.acc.overall - 0.1;
    const fpInflation = jev.cal.meanFpConfidence > 0.8 && jev.cal.fpCount > 0;
    killVerdict = worseAccuracy || fpInflation
      ? "KILL SIGNAL: Jev materially worse than baseline or confidence-inflated on the known FP class"
      : "PASS-THROUGH: no kill signal on the smoke corpus (not a graduation — see corpus limits)";
  }

  const date = new Date().toISOString().slice(0, 10);
  const report = `# EXP-JEV-1 replay report — ${date}

Run mode: ${runJev ? "baseline + jev-1.13 (pinned)" : "baseline-only (no API key placed; Jev lane dormant)"}
Cases: ${allCases.length} total / ${scoreable.length} scoreable (fixture-derived circular cases excluded from scoring)
Label semantics + honesty notes: tools/jev-replay/corpus.mjs header; scope amendment in docs/task-inventory.md (JEV-1)

## Results

| Lane | Accuracy | Brier | Mean conf on known-FP class |
|---|---|---|---|
| Deterministic baseline | ${baseline.acc.overall.toFixed(3)} | ${baseline.cal.brier.toFixed(3)} | ${baseline.cal.meanFpConfidence.toFixed(3)} |
| Jev ${runJev ? "(jev-1.13)" : "(not run)"} | ${jev ? jev.acc.overall.toFixed(3) : "—"} | ${jev ? jev.cal.brier.toFixed(3) : "—"} | ${jev ? jev.cal.meanFpConfidence.toFixed(3) : "—"} |

Per-class (baseline): ${JSON.stringify(baseline.acc.byClass)}
Per-class (jev): ${jev ? JSON.stringify(jev.acc.byClass) : "—"}
Jev API errors: ${jev ? (jev.errors ?? 0) : "n/a"}

## Verdict

${killVerdict}

## Scope caveats (v1 smoke test)

- Corpus is smoke-test-grade: ~30 independent outcome-labeled cases; the FP
  class is one episode (Mimosa, narrative-reconstructed); no native "escalate"
  exemplar class exists — the mapping is experimenter-imposed and ratification
  is an open owner item (JEV register).
- Fixture labels are circular vs. the baseline and are excluded from scoring.
- Per-class calibration-error claims require the corpus expansion recorded in
  the register (synthetic FP/stale generation, raw Mimosa text recovery).
`;
  mkdirSync(join(REPO_ROOT, "docs", "research"), { recursive: true });
  const outPath = join(REPO_ROOT, "docs", "research", `jev-expjev1-report-${date}.md`);
  writeFileSync(outPath, report);
  console.log(`report written: docs/research/jev-expjev1-report-${date}.md`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
