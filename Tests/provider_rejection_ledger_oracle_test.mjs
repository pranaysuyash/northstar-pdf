import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import {
  RejectionLedgerError,
  createRejectionLedger,
  normalizeRejectionAttempt,
  compareRejectionLedgers
} from "../web/provider-rejection-ledger.mjs";
import { createCompanionHost } from "../web/provider-companion-host.mjs";

const root = path.resolve(new URL("..", import.meta.url).pathname);
const fixture = JSON.parse(fs.readFileSync(path.join(root, "Tests/fixtures/provider_rejection_ledger_fixture.json"), "utf8"));
const sourceDigest = fixture.sourceDigest;
const ledgers = Object.values(fixture.ledgers).map((definition) => createRejectionLedger({
  ledgerID: `${fixture.ledgerID}-${definition.providerKind}`,
  sourceDigest,
  attempts: definition.attempts
}));

assert.deepEqual(ledgers.map((ledger) => ledger.attempts.map((attempt) => attempt.rejection.code)), [
  ["staleSourceDigest", "unsupportedOperation"],
  ["staleSourceDigest", "unsupportedOperation"],
  ["staleSourceDigest", "providerUnavailable"]
]);

const report = compareRejectionLedgers(ledgers);
assert.deepEqual(report.sourceDigests, [sourceDigest]);
assert.equal(report.summary.providerCount, 3);
assert.equal(report.summary.caseCount, 2);
assert.equal(report.summary.comparisonCount, 6);
assert.equal(report.summary.comparableCount, 6);
assert.equal(report.summary.equivalentCount, 4);
assert.equal(report.summary.disagreementCount, 2);
assert.equal(report.summary.unknownCount, 0);
assert.deepEqual(Object.keys(report.providerSummaries).sort(), ["companion-pdfbox", "pdfjs-pdflib", "pdfkit"]);

const stale = report.comparisons.filter((comparison) => comparison.caseID === "stale-source");
assert.equal(stale.length, 3);
assert.ok(stale.every((comparison) => comparison.equivalent));
const unsupported = report.comparisons.filter((comparison) => comparison.caseID === "unsupported-capability");
assert.equal(unsupported.length, 3);
assert.equal(unsupported.filter((comparison) => comparison.equivalent).length, 1);
assert.equal(unsupported.filter((comparison) => !comparison.equivalent).length, 2);

const normalizedAgain = normalizeRejectionAttempt(ledgers[0].attempts[0]);
assert.equal(normalizedAgain.rejection.code, "staleSourceDigest");
assert.equal(normalizedAgain.operationLineageSignature, ledgers[0].attempts[0].operationLineageSignature);
assert.equal(Object.hasOwn(normalizedAgain, "observedAt"), false);
assert.equal(JSON.stringify(report).includes("outputDigest"), false);

const companionHello = {
  type: "pdf-editor.companion.hello",
  version: { major: 1, minor: 0 },
  sessionID: "rejection-ledger-companion-session",
  clientNonce: "client-nonce",
  origin: "http://127.0.0.1:4174",
  requestedCapabilities: ["edit.existingText"],
  localOnly: true
};
const companionHost = createCompanionHost({
  providerIDs: ["companion-pdfbox"],
  allowedOrigins: [companionHello.origin],
  serverNonceFactory: () => "server-nonce"
});
const companionHelloResponse = await companionHost.handle(companionHello);
const companionEvents = await companionHost.handle({
  type: "pdf-editor.companion.capability-request",
  version: { major: 1, minor: 0 },
  sessionID: companionHello.sessionID,
  requestID: "companion-unavailable-001",
  clientNonce: companionHello.clientNonce,
  serverNonce: companionHelloResponse.serverNonce,
  capability: "edit.existingText",
  sourceDigest,
  sourceByteCount: 1,
  sourcePageCount: 1,
  maxOutputBytes: 100,
  timeoutMs: 1000,
  inputMode: "file-token",
  sourceFileToken: "local-file-token",
  operationIDs: ["logical-op-001"],
  localOnly: true
});
const companionResponse = companionEvents.at(-1);
const companionAttempt = normalizeRejectionAttempt({
  attemptID: "companion-runtime-001",
  caseID: "unsupported-capability",
  providerID: companionResponse.providerID,
  providerKind: "companion",
  capability: "text.runReplacement",
  phase: "execution",
  state: companionResponse.state,
  sourceDigest,
  operationLineage: fixture.operationLineage,
  reasonCodes: companionResponse.reasonCodes
});
assert.equal(companionAttempt.rejection.code, "providerUnavailable");

assert.throws(
  () => createRejectionLedger({ ledgerID: "bad", sourceDigest, attempts: [{ ...fixture.ledgers.native.attempts[0], sourceDigest: "b".repeat(64) }] }),
  (error) => error instanceof RejectionLedgerError && error.code === "invalidRejectionLedger"
);
assert.throws(
  () => normalizeRejectionAttempt({ ...fixture.ledgers.native.attempts[0], operationLineage: [{ ...fixture.operationLineage[0], sourceDigest: "b".repeat(64) }] }),
  (error) => error instanceof RejectionLedgerError && error.code === "invalidRejectionLedger"
);
const unknown = normalizeRejectionAttempt({
  ...fixture.ledgers.native.attempts[0],
  attemptID: "unknown-001",
  reasonCodes: ["providerReturnedOpaqueState"]
});
assert.equal(unknown.rejection.code, "unknownRejection");
assert.equal(unknown.rejection.unknownProviderReasonCodeCount, 1);
const unknownLedger = createRejectionLedger({ ledgerID: "unknown-ledger", sourceDigest, attempts: [unknown] });
const unknownBrowserLedger = createRejectionLedger({
  ledgerID: "unknown-browser-ledger",
  sourceDigest,
  attempts: [{ ...unknown, attemptID: "unknown-002", providerID: "unknown-browser", providerKind: "browser" }]
});
const unknownComparison = compareRejectionLedgers([unknownLedger, unknownBrowserLedger]);
assert.equal(unknownComparison.comparisons[0].comparable, false);
assert.equal(unknownComparison.comparisons[0].equivalent, false);
assert.throws(
  () => createRejectionLedger({
    ledgerID: "mixed-provider-ledger",
    sourceDigest,
    attempts: [
      fixture.ledgers.native.attempts[0],
      fixture.ledgers.browser.attempts[0]
    ]
  }),
  (error) => error instanceof RejectionLedgerError && error.code === "invalidRejectionLedger"
);

const reportPath = path.join(root, "benchmark/results/rejection-ledger/2026-08-31/report.json");
fs.mkdirSync(path.dirname(reportPath), { recursive: true });
fs.writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`);
console.log(`provider rejection ledger oracle: ${report.summary.providerCount} providers, ${report.summary.caseCount} cases, ${report.summary.equivalentCount}/${report.summary.comparableCount} equivalent comparisons, ${report.summary.disagreementCount} explicit divergences`);
