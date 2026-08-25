import assert from "node:assert/strict";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "/Users/pranay/.agents/skills/testing/playwright-skill/node_modules/playwright/index.mjs";

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const baseURL = process.env.PDF_PROOF_BASE_URL || "http://127.0.0.1:4173/web/index.html";
const publicSamplePath = path.join(projectRoot, "benchmark/results/public-sample-form.pdf");
const form6Path = path.join(projectRoot, "benchmark/results/2026-08-23-pdfkit-form6/artifacts/noop.pdf");

async function waitForDigest(page, digest = null) {
  await page.waitForFunction(
    (expected) => {
      const actual = window.__pdfEditorContractFixture?.snapshot?.()?.document?.payload?.source?.sha256;
      return Boolean(actual) && (!expected || actual === expected);
    },
    digest,
    { timeout: 30_000 }
  );
}

async function waitForDifferentDigest(page, previousDigest) {
  await page.waitForFunction(
    (previous) => {
      const actual = window.__pdfEditorContractFixture?.snapshot?.()?.document?.payload?.source?.sha256;
      return Boolean(actual) && actual !== previous;
    },
    previousDigest,
    { timeout: 30_000 }
  );
}

const browser = await chromium.launch({ channel: "chrome", headless: true });
const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
const consoleErrors = [];
const pageErrors = [];
page.on("console", (message) => {
  if (message.type() === "error") consoleErrors.push(message.text());
});
page.on("pageerror", (error) => pageErrors.push(error.message));

try {
  await page.goto(baseURL, { waitUntil: "networkidle" });
  await page.waitForFunction(
    () => Boolean(
      window.pdfjsLib
      && window.__pdfEditorContractFixture?.classifyTemplateIndex
      && window.__pdfEditorContractFixture?.calibrateDocumentClassPolicies
    ),
    undefined,
    { timeout: 30_000 }
  );

  await page.locator("#fileInput").setInputFiles(publicSamplePath);
  await waitForDigest(page);
  const publicEvidence = await page.evaluate(async () => {
    const fixture = window.__pdfEditorContractFixture;
    const snapshot = fixture.snapshot();
    const fingerprint = await fixture.createTemplateFingerprint({
      workspaceKey: "browser-reviewed-benchmark-key",
      includeExactSourceDigest: true
    });
    const template = {
      header: {
        contractName: "pdf-editor.template",
        version: { major: 1, minor: 0 },
        templateDigest: fingerprint.layoutFingerprint,
        generatedAt: "2026-08-24T00:00:00.000Z",
        provider: snapshot.document.header.provider
      },
      payload: {
        templateID: "browser-corpus-public-sample",
        revisionID: "browser-corpus-public-sample-revision-1",
        parentRevisionID: null,
        displayName: "Browser corpus reviewed template",
        lifecycle: "active",
        privacyMode: "localMinimized",
        fingerprint,
        mappings: [],
        reviewPolicy: { requireValueReview: true }
      }
    };
    const sourceDigest = snapshot.document.payload.source.sha256;
    const exact = fixture.classifyTemplateIndex({ templates: [template], fingerprint, sourceDigest });
    const knownVariant = fixture.classifyTemplateIndex({
      templates: [template],
      fingerprint: { ...fingerprint, exactSourceDigests: [] },
      sourceDigest: "sha256:browser-reviewed-variant"
    });
    const familyFingerprint = {
      ...fingerprint,
      layoutFingerprint: "hmac:browser-family-drift",
      pageSignatures: fingerprint.pageSignatures.map((page) => ({
        ...page,
        widthPoints: page.widthPoints + 1,
        heightPoints: page.heightPoints - 1
      }))
    };
    const family = fixture.classifyTemplateIndex({
      templates: [template],
      fingerprint: familyFingerprint,
      sourceDigest: "sha256:browser-family",
      documentClass: "staticPrintedForm"
    });
    const scannedFamilyDisabled = fixture.classifyTemplateIndex({
      templates: [template],
      fingerprint: familyFingerprint,
      sourceDigest: "sha256:browser-scanned-family",
      documentClass: "scannedDocument"
    });
    const ambiguousInput = { ...fingerprint, layoutFingerprint: "hmac:browser-ambiguous-input", exactSourceDigests: [] };
    const ambiguous = fixture.classifyTemplateIndex({
      templates: [
        { ...template, payload: { ...template.payload, templateID: "browser-family-a", fingerprint: { ...fingerprint, layoutFingerprint: "hmac:browser-family-a", exactSourceDigests: [] } } },
        { ...template, payload: { ...template.payload, templateID: "browser-family-b", fingerprint: { ...fingerprint, layoutFingerprint: "hmac:browser-family-b", exactSourceDigests: [] } } }
      ],
      fingerprint: ambiguousInput,
      sourceDigest: "sha256:browser-ambiguous"
    });
    return {
      sourceDigest,
      fingerprint,
      template,
      exact,
      knownVariant,
      family,
      scannedFamilyDisabled,
      ambiguous
    };
  });

  assert.equal(publicEvidence.exact.state, "exact");
  assert.equal(publicEvidence.knownVariant.state, "knownVariant");
  assert.equal(publicEvidence.family.state, "familyMatch");
  assert.equal(publicEvidence.scannedFamilyDisabled.state, "noMatch");
  assert.equal(publicEvidence.scannedFamilyDisabled.selectedTemplateID, null);
  assert.equal(publicEvidence.ambiguous.state, "ambiguous");
  assert.equal(publicEvidence.ambiguous.selectedTemplateID, null);

  await page.locator("#fileInput").setInputFiles(form6Path);
  await waitForDifferentDigest(page, publicEvidence.sourceDigest);
  const negative = await page.evaluate(async (template) => {
    const fixture = window.__pdfEditorContractFixture;
    const snapshot = fixture.snapshot();
    const fingerprint = await fixture.createTemplateFingerprint({
      workspaceKey: "browser-reviewed-benchmark-key",
      includeExactSourceDigest: false
    });
    const result = fixture.classifyTemplateIndex({
      templates: [template],
      fingerprint,
      sourceDigest: snapshot.document.payload.source.sha256
    });
    const stale = fixture.classifyTemplateIndex({
      templates: [template],
      fingerprint: publicEvidenceFingerprint(template),
      sourceDigest: snapshot.document.payload.source.sha256,
      expectedSourceDigest: template.payload.fingerprint.exactSourceDigests[0]
    });
    return { result, stale, pageCount: fingerprint.pageSignatures.length };

    function publicEvidenceFingerprint(value) {
      return { ...value.payload.fingerprint, exactSourceDigests: [] };
    }
  }, publicEvidence.template);

  assert.equal(negative.result.state, "noMatch", `Form 6 false-positive score: ${negative.result.score}`);
  assert.equal(negative.result.selectedTemplateID, null);
  assert.equal(negative.stale.state, "stale");
  assert.equal(negative.stale.selectedTemplateID, null);
  assert.ok(negative.pageCount >= 1);
  assert.deepEqual(consoleErrors, [], `browser console errors: ${consoleErrors.join(" | ")}`);
  assert.deepEqual(pageErrors, [], `browser page errors: ${pageErrors.join(" | ")}`);

  console.log(JSON.stringify({
    benchmark: "reviewed-template-matching-browser-corpus",
    source: "PDF.js emitted fingerprints",
    publicSample: {
      exact: publicEvidence.exact.state,
      knownVariant: publicEvidence.knownVariant.state,
      family: publicEvidence.family.state,
      ambiguous: publicEvidence.ambiguous.state
    },
    form6FalsePositiveGate: {
      state: negative.result.state,
      score: negative.result.score,
      selectedTemplateID: negative.result.selectedTemplateID,
      staleState: negative.stale.state
    }
  }, null, 2));
} finally {
  await browser.close();
}
