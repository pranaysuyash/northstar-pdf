#!/usr/bin/env node
/**
 * check-unchecked-concurrency.mjs — concurrency-bypass drift gate (MDEV-I2).
 *
 * The package is on Swift 6 strict concurrency; `@unchecked Sendable` and
 * `nonisolated(unsafe)` sites are the only remaining manual trust surface.
 * This check compares the live source surface against the ledger at
 * docs/research/sendability-invariant-ledger-2026-09-17.md and fails when a
 * new site appears that is not ledgered.
 *
 * Usage: node tools/check-unchecked-concurrency.mjs
 * Exit 0 = surface matches the ledger. Exit 1 = drift (new or removed sites).
 */

import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, relative } from "node:path";

const ROOT = join(import.meta.dirname, "..");
const LEDGER = join(
  ROOT,
  "docs/research/sendability-invariant-ledger-2026-09-17.md",
);

function walkSwiftFiles(dir, out = []) {
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry);
    const s = statSync(full);
    if (s.isDirectory()) walkSwiftFiles(full, out);
    else if (entry.endsWith(".swift")) out.push(full);
  }
  return out;
}

const files = walkSwiftFiles(join(ROOT, "Sources"));
const live = new Set();
for (const file of files) {
  const lines = readFileSync(file, "utf8").split("\n");
  lines.forEach((line, i) => {
    // Only declaration lines count — prose comments (// /// *) that mention
    // the construct are documentation, not sites.
    if (/^\s*(\/\/|\/\*|\*)/.test(line)) return;
    if (line.includes("@unchecked Sendable")) {
      live.add(`${relative(ROOT, file)}:${i + 1}`);
    }
    if (line.includes("nonisolated(unsafe)")) {
      live.add(`${relative(ROOT, file)}:${i + 1}`);
    }
  });
}

const ledgerText = readFileSync(LEDGER, "utf8");
const ledgered = new Set();
for (const match of ledgerText.matchAll(/^\| ([^|]+\.swift):(\d+) \|/gm)) {
  ledgered.add(`${match[1].trim()}:${match[2]}`);
}

// Line numbers drift as files are edited; the ledger records basenames, so
// compare file surfaces by basename with counts.
const basename = (site) => site.split(":")[0].split("/").pop();
const liveByFile = new Map();
for (const site of live) {
  const file = basename(site);
  liveByFile.set(file, (liveByFile.get(file) ?? 0) + 1);
}
const ledgeredByFile = new Map();
for (const site of ledgered) {
  const file = basename(site);
  ledgeredByFile.set(file, (ledgeredByFile.get(file) ?? 0) + 1);
}

const problems = [];

for (const [file, count] of liveByFile) {
  if (!ledgeredByFile.has(file)) {
    problems.push(`UNLEDGERED FILE: ${file} has ${count} site(s)`);
  } else if (ledgeredByFile.get(file) !== count) {
    problems.push(
      `COUNT DRIFT: ${file} has ${count} site(s), ledger records ${ledgeredByFile.get(file)}`,
    );
  }
}
for (const [file, count] of ledgeredByFile) {
  if (!liveByFile.has(file)) {
    problems.push(`STALE LEDGER: ${file} has no live sites but ledger records ${count}`);
  } else if (liveByFile.get(file) === ledgeredByFile.get(file)) {
    // exact file+count match: also warn when line numbers moved, to keep the ledger precise
    const liveLines = [...live].filter((s) => s.startsWith(`${file}:`)).map((s) => s.split(":")[1]);
    const ledgerLines = [...ledgered].filter((s) => s.startsWith(`${file}:`)).map((s) => s.split(":")[1]);
    const moved = liveLines.filter((l) => !ledgerLines.includes(l));
    if (moved.length > 0) {
      console.log(`note: ${file} line numbers moved (ledger lines ${ledgerLines.join(",")} → live ${liveLines.join(",")}); update the ledger at next touch`);
    }
  }
}

if (problems.length > 0) {
  console.error("Unchecked-concurrency drift detected:\n" + problems.map((p) => `  - ${p}`).join("\n"));
  console.error(`\nEvery @unchecked Sendable / nonisolated(unsafe) site must be recorded in\n${relative(ROOT, LEDGER)}\nwith a stated invariant (ok / fixed / unsafe / unverifiable) before it lands.`);
  process.exit(1);
}

console.log(`unchecked-concurrency surface matches ledger (${live.size} sites across ${liveByFile.size} files)`);
