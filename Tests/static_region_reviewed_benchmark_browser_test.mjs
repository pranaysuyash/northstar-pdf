import assert from "node:assert/strict";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "/Users/pranay/.agents/skills/testing/playwright-skill/node_modules/playwright/index.mjs";
import { candidateMatchesTarget, reviewedStaticRegionCorpus } from "./fixtures/static_region_reviewed_corpus.mjs";

const testDirectory = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(testDirectory, "..");
const fixture = path.join(projectRoot, reviewedStaticRegionCorpus.fixture);
const baseURL = process.env.PDF_EDITOR_BASE_URL || "http://127.0.0.1:4173/web/index.html";
const browser = await chromium.launch({ channel: "chrome", headless: true });
const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
page.setDefaultTimeout(10_000);

try {
  await page.goto(baseURL, { waitUntil: "networkidle" });
  await page.waitForFunction(() => Boolean(window.pdfjsLib && window.PDFLib));
  await page.locator("#fileInput").setInputFiles(fixture);
  await page.waitForFunction(() => Boolean(window.__pdfEditorContractFixture?.snapshot?.()?.document));
  const snapshot = await page.evaluate(() => window.__pdfEditorContractFixture.snapshot());
  const candidates = snapshot.document.payload.candidates;
  assert.equal(snapshot.document.payload.fields.length, 0, "Form 6 remains a static form, not an AcroForm");
  assert.ok(candidates.every((candidate) => candidate.status !== "confirmed"), "detector output must not auto-confirm a candidate");

  const matchedTargets = reviewedStaticRegionCorpus.targets.filter((target) => candidates.some((candidate) => candidateMatchesTarget(candidate, target)));
  const associatedCandidates = candidates.filter((candidate) => candidate.labelText && candidate.labelText.trim());
  const trueAssociatedCandidates = associatedCandidates.filter((candidate) => reviewedStaticRegionCorpus.targets.some((target) => candidateMatchesTarget(candidate, target)));
  const report = {
    benchmark: "reviewed-static-region-corpus",
    fixture: reviewedStaticRegionCorpus.fixture,
    reviewStatus: reviewedStaticRegionCorpus.reviewStatus,
    metricsScope: reviewedStaticRegionCorpus.metricsScope,
    targetCount: reviewedStaticRegionCorpus.targets.length,
    matchedTargetCount: matchedTargets.length,
    labelRecall: matchedTargets.length / reviewedStaticRegionCorpus.targets.length,
    labeledCandidateCount: associatedCandidates.length,
    labelPrecisionProxy: associatedCandidates.length ? trueAssociatedCandidates.length / associatedCandidates.length : 0,
    abstentionCount: candidates.filter((candidate) => candidate.status === "unknown").length,
    candidateCount: candidates.length
  };
  assert.equal(report.targetCount, 33);
  assert.ok(Number.isFinite(report.labelRecall) && Number.isFinite(report.labelPrecisionProxy));
  console.log(JSON.stringify(report));
} finally {
  await browser.close();
}
