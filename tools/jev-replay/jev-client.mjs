#!/usr/bin/env node
// Jev System-One client for the NM-R15 / EXP-JEV replay harness.
// Model pin: see PINNED_MODEL below — request id is `jev-latest` (the
// researched `jev-1.13` id returns 400); responses report the served
// version (jev-1.13.0) and raw captures pin reproducibility. Key comes from
// JEV_API_KEY/TYPESAFE_API_KEY in the process env, the repo .env, or the
// shared ~/Projects/.env.local (in that precedence order); it is never
// logged or written to any tracked file (raw captures go to
// tools/jev-replay/raw/, gitignored).

import { readFileSync, mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";

// Model pin (research doc: pin a versioned id, never unanchored jev-latest).
// Live-validated 2026-09-21: the API accepts the EXACT version `jev-1.13.0`
// (200) but rejects the minor alias `jev-1.13` and the wildcard `jev-1.13.x`
// (400 "Unknown model"); GET /v1/models lists only jev-latest/jev-preview,
// and `jev-latest` currently serves jev-1.13.0. We request the exact version
// directly; every response's `model` field is recorded in raw captures as the
// served-version anchor.
const PINNED_MODEL = process.env.JEV_MODEL ?? "jev-1.13.0";
const PINNED_MODEL_ANCHOR = "2026-09-10";
const ENDPOINT = "https://api.typesafe.ai/v1/systemone";
const REPO_ROOT = join(import.meta.dirname, "..", "..");
const RAW_DIR = join(import.meta.dirname, "raw");

// Key precedence (dotenv-style layering): process env → repo .env → shared
// ~/Projects/.env.local (single source of truth across projects; documented
// in ~/Projects/AGENTS.md and ~/Projects/.env.example). The key is never
// logged or written to any tracked file (raw captures go to
// tools/jev-replay/raw/, gitignored).
function readKeyFromEnvFile(path) {
  try {
    const env = readFileSync(path, "utf8");
    for (const line of env.split("\n")) {
      const m = line.match(/^(JEV_API_KEY|TYPESAFE_API_KEY)\s*=\s*(.+)\s*$/);
      if (m) return { key: m[2].replace(/^["']|["']$/g, ""), source: path };
    }
  } catch {
    /* file absent or unreadable — fall through */
  }
  return null;
}

export function loadApiKey() {
  for (const name of ["JEV_API_KEY", "TYPESAFE_API_KEY"]) {
    if (process.env[name]) return { key: process.env[name], source: `env:${name}` };
  }
  const REPO_ENV = join(REPO_ROOT, ".env");
  const SHARED_ENV = join(homedir(), "Projects", ".env.local");
  return (
    readKeyFromEnvFile(REPO_ENV) ??
    readKeyFromEnvFile(SHARED_ENV) ?? { key: null, source: null }
  );
}

/**
 * Ask Jev one or more typed questions against a state.
 * @param {string} apiKey
 * @param {string} state  serialized context text
 * @param {Array<{id: string, type: "noul"|"choice"|"score", prompt: string,
 *                options?: string[], levels?: [number, number]}>} questions
 * @param {{capture?: boolean, label?: string}} opts
 * @returns {Promise<Array<{id, selection?, score?, distribution?, probabilities?, confidence?, raw}>>}
 *   One entry per question, tolerating both observed response shapes
 *   ({answers:[…]} and {results:[…]}); shape is sourced-only until first call.
 */
export async function jevQuestions(apiKey, state, questions, opts = {}) {
  const body = {
    model: PINNED_MODEL,
    state,
    // Live-validated request schema (jev-1.13, 2026-09-21): questions is a
    // dict keyed by question id; each value is a tagged variant with the
    // discriminator ON the object. Score: criteria is a LIST of criterion
    // strings. Choice: criteria is a DICT of option -> description.
    questions: Object.fromEntries(questions.map((q) => {
      if (q.type === "score") {
        return [q.id, {
          type: "score",
          criteria: q.criteria ?? [q.prompt],
          ...(q.levels ? { levels: q.levels } : {}),
        }];
      }
      if (q.type === "choice") {
        const optionCriteria = q.optionCriteria ??
          Object.fromEntries((q.options ?? []).map((o) => [o, ""]));
        return [q.id, { type: "choice", criteria: optionCriteria, options: q.options }];
      }
      if (q.type === "noul") {
        // Validated 2026-09-21: noul takes `instructions` (string). A
        // `criteria` field on noul is rejected at the application layer
        // ("Noul question must have criteria or instructions") even when
        // present, and a list criteria 422s at the schema layer.
        return [q.id, { type: "noul", instructions: q.prompt }];
      }
      return [q.id, { type: "noul", instructions: q.criteria ?? q.prompt }];
    })),
  };
  const res = await fetch(ENDPOINT, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    const text = await res.text().catch(() => "");
    throw new Error(`jev api ${res.status}: ${text.slice(0, 300)}`);
  }
  const json = await res.json();
  if (opts.capture) {
    mkdirSync(RAW_DIR, { recursive: true });
    const stamp = new Date().toISOString().replace(/[:.]/g, "-");
    writeFileSync(
      join(RAW_DIR, `${stamp}-${(opts.label ?? "case").replace(/\W+/g, "_")}.json`),
      JSON.stringify({ request: { model: PINNED_MODEL, state, questions }, response: json }, null, 2),
    );
  }
  const answers = json.answers ?? {};
  if (json.results && !Array.isArray(json.results) && typeof json.results === "object") {
    Object.assign(answers, json.results);
  }
  return questions.map((q) => {
    const answer = answers[q.id] ?? {};
    return {
      id: q.id,
      type: answer.type ?? q.type,
      selection: answer.choice ?? null,
      score: answer.score ?? null,
      noul: answer.noul ?? null,
      legend: answer.legend ?? null,
      probabilities: answer.probabilities ?? answer.distribution ?? null,
      confidence: answer.confidence ?? null,
      servedModel: json.model ?? null,
      raw: answer,
    };
  });
}

/**
 * Ask Jev one Choice question against a state.
 * Thin wrapper over jevQuestions (the original hand-rolled request shape
 * 422'd against the live API; see schema notes there).
 * @param {string} apiKey
 * @param {string} state  serialized finding/context text
 * @param {{question: string, options: string[]}} choice
 * @param {{capture?: boolean, label?: string}} opts
 */
export async function jevChoice(apiKey, state, choice, opts = {}) {
  const [answer] = await jevQuestions(
    apiKey,
    state,
    [{ id: "triage", type: "choice", prompt: choice.question, options: choice.options }],
    opts,
  );
  return {
    selection: answer.selection,
    distribution: answer.probabilities,
    confidence: answer.confidence,
    raw: answer.raw,
  };
}
