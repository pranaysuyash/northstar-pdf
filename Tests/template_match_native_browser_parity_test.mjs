import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";
import {
  calibrateDocumentClassPolicies,
  TEMPLATE_MATCH_BENCHMARK_VERSION
} from "../web/template-match-benchmark.mjs";
import { REVIEWED_TEMPLATE_FIXTURES } from "./fixtures/template_matching_reviewed_fixtures.mjs";

const testDirectory = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(testDirectory, "..");
const baseURL = process.env.PDF_EDITOR_BASE_URL || "http://127.0.0.1:4173/web/index.html";
const outputDirectory = path.join(projectRoot, "benchmark/results/template-matching");
const corpusPath = path.join(outputDirectory, "2026-08-24-reviewed-corpus.json");
const nativeRunPath = path.join(outputDirectory, "2026-08-24-native-run.json");
const reportPath = path.join(outputDirectory, "2026-08-24-native-browser-semantic-parity.json");

function writeJSON(filePath, value) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, `${JSON.stringify(value, null, 2)}\n`);
}

function rounded(value, places = 9) {
  if (typeof value !== "number" || !Number.isFinite(value)) return value;
  const factor = 10 ** places;
  return Math.round(value * factor) / factor;
}

function candidateEvidence(candidate) {
  return {
    templateID: candidate.templateID,
    state: candidate.state,
    score: rounded(candidate.score),
    reason: candidate.reason,
    components: {
      pageCount: candidate.components.pageCount,
      geometry: rounded(candidate.components.geometry),
      nativeFields: rounded(candidate.components.nativeFields),
      anchors: rounded(candidate.components.anchors),
      regions: rounded(candidate.components.regions)
    }
  };
}

function policyProjection(policy) {
  return {
    familyThreshold: rounded(policy.familyThreshold, 4),
    ambiguityMargin: rounded(policy.ambiguityMargin, 4),
    familyAcceptance: policy.familyAcceptance,
    calibrationStatus: policy.calibrationStatus || null
  };
}

function resultProjection(fixture, actual) {
  return {
    id: fixture.id,
    documentClass: fixture.documentClass,
    expectedState: fixture.expected.state,
    actualState: actual.state,
    expectedSelectedTemplateID: fixture.expected.selectedTemplateID ?? null,
    actualSelectedTemplateID: actual.selectedTemplateID ?? null,
    abstained: actual.selectedTemplateID == null,
    score: rounded(actual.score),
    candidates: (actual.candidates || []).map(candidateEvidence),
    falsePositiveGatePassed: Boolean(actual.falsePositiveGate?.passed),
    falsePositiveGateSelected: Boolean(actual.falsePositiveGate?.selected),
    policy: policyProjection(actual.policy),
    passed: actual.state === fixture.expected.state
      && (fixture.expected.selectedTemplateID === undefined
        || actual.selectedTemplateID === fixture.expected.selectedTemplateID)
      && !(fixture.expected.forbiddenStates || []).includes(actual.state)
      && (fixture.expected.mustNotSelect !== true || actual.selectedTemplateID == null)
  };
}

function compareValues(mismatches, kind, pathName, nativeValue, browserValue) {
  if (JSON.stringify(nativeValue) !== JSON.stringify(browserValue)) {
    mismatches.push({ kind, path: pathName, native: nativeValue, browser: browserValue });
  }
}

function compareNumbers(mismatches, kind, pathName, nativeValue, browserValue, tolerance = 1e-8) {
  if (Math.abs(nativeValue - browserValue) > tolerance) {
    mismatches.push({ kind, path: pathName, native: nativeValue, browser: browserValue, tolerance });
  }
}

function compareCase(nativeCase, browserCase) {
  const mismatches = [];
  if (!browserCase) {
    mismatches.push({ kind: "case.presence", path: nativeCase.id, native: true, browser: false });
    return mismatches;
  }
  compareValues(mismatches, "document-class", `${nativeCase.id}.documentClass`, nativeCase.documentClass, browserCase.documentClass);
  compareValues(mismatches, "state", `${nativeCase.id}.actualState`, nativeCase.actualState, browserCase.actualState);
  compareValues(
    mismatches,
    "selection",
    `${nativeCase.id}.actualSelectedTemplateID`,
    nativeCase.actualSelectedTemplateID ?? null,
    browserCase.actualSelectedTemplateID ?? null
  );
  compareValues(mismatches, "abstention", `${nativeCase.id}.abstained`, nativeCase.abstained, browserCase.abstained);
  compareValues(
    mismatches,
    "false-positive-gate",
    `${nativeCase.id}.falsePositiveGate`,
    {
      passed: nativeCase.falsePositiveGatePassed,
      selected: nativeCase.falsePositiveGateSelected
    },
    {
      passed: browserCase.falsePositiveGatePassed,
      selected: browserCase.falsePositiveGateSelected
    }
  );
  compareNumbers(mismatches, "score", `${nativeCase.id}.score`, nativeCase.score, browserCase.score);
  compareValues(
    mismatches,
    "policy",
    `${nativeCase.id}.policy`,
    policyProjection(nativeCase.policy),
    policyProjection(browserCase.policy)
  );
  if (nativeCase.candidates.length !== browserCase.candidates.length) {
    mismatches.push({
      kind: "candidate-evidence.count",
      path: `${nativeCase.id}.candidates.length`,
      native: nativeCase.candidates.length,
      browser: browserCase.candidates.length
    });
  }
  const count = Math.min(nativeCase.candidates.length, browserCase.candidates.length);
  for (let index = 0; index < count; index += 1) {
    const nativeCandidate = nativeCase.candidates[index];
    const browserCandidate = browserCase.candidates[index];
    compareValues(
      mismatches,
      "candidate-evidence.identity",
      `${nativeCase.id}.candidates[${index}].identity`,
      { templateID: nativeCandidate.templateID, state: nativeCandidate.state, reason: nativeCandidate.reason },
      { templateID: browserCandidate.templateID, state: browserCandidate.state, reason: browserCandidate.reason }
    );
    compareNumbers(
      mismatches,
      "candidate-evidence.score",
      `${nativeCase.id}.candidates[${index}].score`,
      nativeCandidate.score,
      browserCandidate.score
    );
    for (const component of ["pageCount", "geometry", "nativeFields", "anchors", "regions"]) {
      if (component === "pageCount") {
        compareValues(
          mismatches,
          "candidate-evidence.component",
          `${nativeCase.id}.candidates[${index}].components.${component}`,
          nativeCandidate.components[component],
          browserCandidate.components[component]
        );
      } else {
        compareNumbers(
          mismatches,
          "candidate-evidence.component",
          `${nativeCase.id}.candidates[${index}].components.${component}`,
          nativeCandidate.components[component],
          browserCandidate.components[component]
        );
      }
    }
  }
  return mismatches;
}

const calibration = calibrateDocumentClassPolicies(REVIEWED_TEMPLATE_FIXTURES);
assert.equal(calibration.passed, true, "reviewed calibration must pass before parity is attempted");
const corpus = {
  corpusVersion: { ...TEMPLATE_MATCH_BENCHMARK_VERSION },
  policyByDocumentClass: calibration.policyByDocumentClass,
  fixtures: REVIEWED_TEMPLATE_FIXTURES
};
writeJSON(corpusPath, corpus);

execFileSync("swift", [
  "run",
  "PDFTemplateParityHarness",
  "--corpus",
  path.relative(projectRoot, corpusPath),
  "--output",
  path.relative(projectRoot, nativeRunPath)
], { cwd: projectRoot, stdio: "inherit" });

const nativeReport = JSON.parse(fs.readFileSync(nativeRunPath, "utf8"));
assert.equal(nativeReport.passed, true, JSON.stringify(nativeReport, null, 2));
assert.equal(nativeReport.fixtureCount, REVIEWED_TEMPLATE_FIXTURES.length);

const browser = await chromium.launch({ channel: "chrome", headless: true });
const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
const consoleErrors = [];
const pageErrors = [];
page.on("console", (message) => {
  if (message.type() === "error") consoleErrors.push(message.text());
});
page.on("pageerror", (error) => pageErrors.push(error.message));

let browserCases;
try {
  await page.goto(baseURL, { waitUntil: "networkidle" });
  await page.waitForFunction(
    () => Boolean(window.__pdfEditorContractFixture?.classifyTemplateIndex),
    undefined,
    { timeout: 30_000 }
  );
  browserCases = await page.evaluate(({ fixtures, policyByDocumentClass }) => {
    const api = window.__pdfEditorContractFixture;
    return fixtures.map((fixture) => {
      const actual = api.classifyTemplateIndex({
        ...fixture.input,
        documentClass: fixture.documentClass,
        policy: { documentClassPolicies: policyByDocumentClass }
      });
      return {
        id: fixture.id,
        documentClass: fixture.documentClass,
        expectedState: fixture.expected.state,
        actualState: actual.state,
        expectedSelectedTemplateID: fixture.expected.selectedTemplateID ?? null,
        actualSelectedTemplateID: actual.selectedTemplateID ?? null,
        abstained: actual.selectedTemplateID == null,
        score: actual.score,
        candidates: (actual.candidates || []).map((candidate) => ({
          templateID: candidate.templateID,
          state: candidate.state,
          score: candidate.score,
          reason: candidate.reason,
          components: candidate.components
        })),
        falsePositiveGatePassed: Boolean(actual.falsePositiveGate?.passed),
        falsePositiveGateSelected: Boolean(actual.falsePositiveGate?.selected),
        policy: {
          familyThreshold: actual.policy.familyThreshold,
          ambiguityMargin: actual.policy.ambiguityMargin,
          familyAcceptance: actual.policy.familyAcceptance,
          calibrationStatus: actual.policy.calibrationStatus || null
        },
        passed: actual.state === fixture.expected.state
          && (fixture.expected.selectedTemplateID === undefined
            || actual.selectedTemplateID === fixture.expected.selectedTemplateID)
          && !(fixture.expected.forbiddenStates || []).includes(actual.state)
          && (fixture.expected.mustNotSelect !== true || actual.selectedTemplateID == null)
      };
    });
  }, corpus);
} finally {
  await browser.close();
}

assert.deepEqual(consoleErrors, [], `browser console errors: ${consoleErrors.join(" | ")}`);
assert.deepEqual(pageErrors, [], `browser page errors: ${pageErrors.join(" | ")}`);
const nativeByID = new Map(nativeReport.cases.map((entry) => [entry.id, entry]));
const browserByID = new Map(browserCases.map((entry) => [entry.id, entry]));
const parityCases = REVIEWED_TEMPLATE_FIXTURES.map((fixture) => {
  const nativeCase = nativeByID.get(fixture.id);
  const browserCase = browserByID.get(fixture.id);
  const mismatches = compareCase(nativeCase, browserCase);
  return {
    id: fixture.id,
    documentClass: fixture.documentClass,
    expectedState: fixture.expected.state,
    nativeState: nativeCase?.actualState ?? null,
    browserState: browserCase?.actualState ?? null,
    nativeSelectedTemplateID: nativeCase?.actualSelectedTemplateID ?? null,
    browserSelectedTemplateID: browserCase?.actualSelectedTemplateID ?? null,
    nativeAbstained: nativeCase?.abstained ?? true,
    browserAbstained: browserCase?.abstained ?? true,
    mismatchCount: mismatches.length,
    mismatches
  };
});
const mismatches = parityCases.flatMap((entry) => entry.mismatches.map((mismatch) => ({
  fixtureID: entry.id,
  documentClass: entry.documentClass,
  ...mismatch
})));
const mismatchCounts = mismatches.reduce((counts, mismatch) => {
  counts[mismatch.kind] = (counts[mismatch.kind] || 0) + 1;
  return counts;
}, {});
function countStates(entries, key) {
  return entries.reduce((counts, entry) => {
    const state = entry[key];
    counts[state] = (counts[state] || 0) + 1;
    return counts;
  }, {});
}

function countAbstentions(entries, key) {
  return entries.reduce((counts, entry) => {
    const bucket = entry[key] ? "abstained" : "selected";
    counts[bucket] += 1;
    return counts;
  }, { abstained: 0, selected: 0 });
}

const evidenceMismatchCount = mismatches.filter((mismatch) =>
  mismatch.kind.startsWith("candidate-evidence") || mismatch.kind === "score"
).length;
const report = {
  harness: "pdf-editor-native-browser-template-semantic-parity",
  version: { major: 1, minor: 0 },
  corpusPath: path.relative(projectRoot, corpusPath),
  nativeRunPath: path.relative(projectRoot, nativeRunPath),
  fixtureCount: parityCases.length,
  passed: mismatches.length === 0,
  semanticMismatchCount: mismatches.length,
  mismatchCounts,
  stateCounts: REVIEWED_TEMPLATE_FIXTURES.reduce((counts, fixture) => {
    counts[fixture.expected.state] = (counts[fixture.expected.state] || 0) + 1;
    return counts;
  }, {}),
  stateParity: {
    expected: REVIEWED_TEMPLATE_FIXTURES.reduce((counts, fixture) => {
      counts[fixture.expected.state] = (counts[fixture.expected.state] || 0) + 1;
      return counts;
    }, {}),
    native: countStates(parityCases, "nativeState"),
    browser: countStates(parityCases, "browserState")
  },
  abstentionCounts: {
    native: countAbstentions(parityCases, "nativeAbstained"),
    browser: countAbstentions(parityCases, "browserAbstained")
  },
  evidenceParity: {
    compared: [
      "candidate count",
      "candidate identity",
      "candidate state",
      "candidate reason",
      "candidate score",
      "page-count component",
      "geometry component",
      "native-field component",
      "anchor component",
      "region component",
      "class policy"
    ],
    mismatchCount: evidenceMismatchCount,
    passed: evidenceMismatchCount === 0
  },
  evidenceCompared: [
    "match state",
    "selected template identity",
    "abstention",
    "false-positive gate",
    "score",
    "candidate identity and reason",
    "candidate score components",
    "class policy"
  ],
  browser: {
    baseURL,
    consoleErrors,
    pageErrors
  },
  cases: parityCases
};
writeJSON(reportPath, report);
assert.equal(report.passed, true, JSON.stringify(report, null, 2));
assert.ok(parityCases.every((entry) => entry.nativeAbstained === entry.browserAbstained));
console.log(JSON.stringify({
  harness: report.harness,
  fixtureCount: report.fixtureCount,
  passed: report.passed,
  semanticMismatchCount: report.semanticMismatchCount,
  mismatchCounts: report.mismatchCounts,
  stateCounts: report.stateCounts,
  reportPath: path.relative(projectRoot, reportPath)
}, null, 2));
