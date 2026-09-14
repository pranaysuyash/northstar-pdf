#!/usr/bin/env node
// airgap-watch.mjs — runtime network-boundary capture for persona sims.
//
// Answers, with Tier-4 evidence, the launch-audit question "does the app make
// any network connection during a journey?" (NS-P5 Privacy Forensics Auditor;
// audit §10.12 step-11 PENDING → PL-I33). Spawns a command (or attaches to a
// running pid), samples `lsof -i` for that process on an interval, records
// every socket against an allowlist, and exits non-zero on any violation so
// the harness can gate a sim run.
//
// Usage:
//   node tools/airgap-watch.mjs --exec .build/debug/PDFEditor --out report.json
//   node tools/airgap-watch.mjs --pid 1234 --duration 30
//   node tools/airgap-watch.mjs --exec ./app --allow host:443 --out report.json
//
// Allowlist: loopback (127.0.0.1/::1) is always allowed. Add remote hosts via
// repeatable --allow host or --allow host:port. Everything else is a
// violation. Reports are value-free metadata (hosts/ports/timestamps only).
//
// Exit codes: 0 = no violations, 1 = violations found, 2 = usage/runtime error.

import { spawn, execFileSync } from "node:child_process";
import { writeFileSync } from "node:fs";

function parseArgs(argv) {
  const opts = {
    exec: null,
    pid: null,
    duration: 0,
    out: null,
    intervalMs: 500,
    allow: [],
    execArgs: [],
  };
  let i = 0;
  while (i < argv.length) {
    const a = argv[i];
    if (a === "--exec") opts.exec = argv[++i];
    else if (a === "--pid") opts.pid = Number(argv[++i]);
    else if (a === "--duration") opts.duration = Number(argv[++i]);
    else if (a === "--out") opts.out = argv[++i];
    else if (a === "--interval") opts.intervalMs = Number(argv[++i]);
    else if (a === "--allow") opts.allow.push(argv[++i]);
    else if (a === "--") { opts.execArgs = argv.slice(i + 1); break; }
    else if (opts.exec && !a.startsWith("--")) { opts.execArgs = argv.slice(i); break; }
    else throw new Error(`unknown argument: ${a}`);
    i += 1;
  }
  if (!opts.exec && !opts.pid) throw new Error("need --exec <cmd> or --pid <n>");
  if (opts.exec && opts.execArgs.length === 0) opts.execArgs = [opts.exec];
  return opts;
}

function isAllowed(remote, allow) {
  if (!remote) return false;
  const host = remote.replace(/^\[?([^\]]+)\]?(:\d+)?$/, "$1");
  if (host === "127.0.0.1" || host === "::1" || host === "localhost") return true;
  return allow.some((spec) => {
    if (spec.includes(":")) {
      const [h, p] = spec.split(":");
      return host === h && remote.endsWith(`:${p}`);
    }
    return host === spec || host.endsWith(`.${spec}`);
  });
}

// lsof -F output: one record per process, fields p<pid> n<local->remote> etc.
function sampleConnections(pid) {
  let raw;
  try {
    raw = execFileSync("/usr/sbin/lsof", ["-an", "-i", "-p", String(pid), "-Fpn"], {
      encoding: "utf8",
      timeout: 4000,
    });
  } catch {
    return []; // process may have no sockets right now (lsof exits 1)
  }
  const found = [];
  let currentPid = null;
  for (const line of raw.split("\n")) {
    if (line.startsWith("p")) currentPid = Number(line.slice(1));
    else if (line.startsWith("n") && currentPid) {
      const spec = line.slice(1);
      const arrow = spec.indexOf("->");
      if (arrow !== -1) {
        found.push({ pid: currentPid, local: spec.slice(0, arrow), remote: spec.slice(arrow + 2) });
      }
    }
  }
  return found;
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  const startedAt = new Date().toISOString();
  let child = null;
  let pid = opts.pid;

  if (opts.exec) {
    child = spawn(opts.execArgs[0], opts.execArgs.slice(1), { stdio: "ignore" });
    pid = child.pid;
    await new Promise((r) => setTimeout(r, 1000)); // let the process start
  }
  if (!pid || !Number.isFinite(pid)) throw new Error("no pid to watch");

  const seen = new Map();
  const deadline = opts.duration > 0 ? Date.now() + opts.duration * 1000 : null;
  const shouldStop = () =>
    (child !== null && child.exitCode !== null) ||
    (deadline !== null && Date.now() > deadline);

  while (!shouldStop()) {
    for (const conn of sampleConnections(pid)) {
      const key = `${conn.local}->${conn.remote}`;
      if (!seen.has(key)) {
        seen.set(key, {
          ...conn,
          remoteHost: conn.remote.replace(/^\[?([^\]]+)\]?(:\d+)?$/, "$1"),
          allowed: isAllowed(conn.remote, opts.allow),
          firstSeenAt: new Date().toISOString(),
        });
      }
    }
    await new Promise((r) => setTimeout(r, opts.intervalMs));
  }

  const connections = [...seen.values()];
  const violations = connections.filter((c) => !c.allowed);
  const report = {
    tool: "airgap-watch.mjs",
    startedAt,
    finishedAt: new Date().toISOString(),
    mode: opts.exec ? "exec" : "pid",
    pid,
    allowlist: ["loopback", ...opts.allow],
    sampleIntervalMs: opts.intervalMs,
    connections,
    violations,
    verdict: violations.length === 0 ? "PASS" : "FAIL",
  };

  const text = JSON.stringify(report, null, 2);
  if (opts.out) writeFileSync(opts.out, text);
  else process.stdout.write(text + "\n");

  if (violations.length > 0) {
    process.stderr.write(
      `AIRGAP VIOLATIONS (${violations.length}):\n` +
        violations.map((v) => `  ${v.remote} (first ${v.firstSeenAt})`).join("\n") +
        "\n",
    );
  }
  process.exit(violations.length === 0 ? 0 : 1);
}

main().catch((err) => {
  process.stderr.write(`airgap-watch: ${err.message}\n`);
  process.exit(2);
});
