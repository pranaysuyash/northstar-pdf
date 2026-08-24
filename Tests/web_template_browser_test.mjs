import assert from "node:assert/strict";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "/Users/pranay/.agents/skills/testing/playwright-skill/node_modules/playwright/index.mjs";

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const baseURL = process.env.PDF_PROOF_BASE_URL || "http://127.0.0.1:4173/web/index.html";
const sourcePath = path.join(projectRoot, "benchmark/results/public-sample-form.pdf");

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
    () => Boolean(window.pdfjsLib && window.PDFLib && window.__pdfEditorContractFixture?.createTemplateFingerprint),
    undefined,
    { timeout: 30_000 }
  );
  await page.locator("#fileInput").setInputFiles(sourcePath);
  await page.waitForFunction(
    () => Boolean(window.__pdfEditorContractFixture.snapshot()?.document?.payload?.source?.sha256),
    undefined,
    { timeout: 30_000 }
  );

  await page.locator("#captureTemplateButton").click();
  await page.waitForFunction(() => document.querySelector("#templateSummary")?.textContent?.startsWith("draft revision"));
  const draftMappingCount = await page.locator("#templateMappingList input[type=checkbox]").count();
  assert.ok(draftMappingCount > 0, "capture should expose mapping review controls");
  for (let index = 0; index < draftMappingCount; index += 1) {
    await page.locator("#templateMappingList input[type=checkbox]").nth(index).check();
  }
  await page.locator("#activateTemplateButton").click();
  await page.waitForFunction(() => document.querySelector("#templateSummary")?.textContent?.startsWith("active revision"));
  await page.locator("#prepareTemplateButton").click();
  await page.waitForFunction(() => document.querySelectorAll("#templateCompletionList input[type=checkbox]").length > 0);
  assert.equal(await page.locator("#applyTemplateButton").isDisabled(), true, "unreviewed template entries must remain blocked");

  const result = await page.evaluate(async () => {
    const fixture = window.__pdfEditorContractFixture;
    const snapshot = fixture.snapshot();
    const fingerprint = await fixture.createTemplateFingerprint({
      workspaceKey: "browser-local-template-key",
      includeExactSourceDigest: true
    });
    const candidate = snapshot.candidates.find((entry) => entry.coordinate && entry.suggestedFieldType === "text")
      || snapshot.candidates.find((entry) => entry.coordinate);
    const mapping = candidate ? {
      id: "mapping-browser-1",
      semanticKey: "person.fullName",
      target: {
        kind: "staticRegion",
        pageIndex: candidate.pageIndex,
        region: candidate.coordinate,
        candidateKind: candidate.kind
      },
      suggestedFieldType: "text",
      evidenceReferences: candidate.id ? [candidate.id] : [],
      status: "confirmed",
      reviewPolicy: "alwaysReviewMappingAndValue"
    } : null;
    const template = {
      header: {
        contractName: "pdf-editor.template",
        version: { major: 1, minor: 0 },
        templateDigest: fingerprint.layoutFingerprint,
        generatedAt: new Date().toISOString(),
        provider: snapshot.document.header.provider
      },
      payload: {
        templateID: "template-browser",
        revisionID: "revision-browser",
        displayName: "Browser fixture template",
        lifecycle: "active",
        privacyMode: "localMinimized",
        fingerprint,
        mappings: mapping ? [mapping] : [],
        reviewPolicy: { requireValueReview: true }
      }
    };
    fixture.validateTemplateContract(template);
    const match = fixture.matchTemplate({
      template,
      fingerprint,
      sourceDigest: snapshot.document.payload.source.sha256
    });
    const profile = {
      header: {
        contractName: "pdf-editor.profile",
        version: { major: 1, minor: 0 },
        profileID: "profile-browser",
        revisionID: "profile-revision-browser",
        generatedAt: new Date().toISOString(),
        provider: snapshot.document.header.provider
      },
      payload: {
        profileID: "profile-browser",
        revisionID: "profile-revision-browser",
        displayName: "Browser profile",
        revisionNumber: 1,
        storageScope: "deviceLocal",
        requiresUnlock: true,
        values: [{ id: "profile-value-1", semanticKey: "person.fullName", value: { kind: "text", text: "Ada Lovelace" } }]
      }
    };
    const proposal = fixture.createCompletionProposal({ template, match, profile, sessionID: "browser-completion" });
    const reviewedMapping = fixture.reviewCompletionMapping(proposal, "mapping-browser-1", true);
    const reviewedValue = fixture.reviewCompletionValue(reviewedMapping, "mapping-browser-1", { kind: "text", text: "Ada Lovelace" });
    const gate = fixture.canMaterializeCompletion({
      proposal: reviewedValue,
      currentSourceDigest: snapshot.document.payload.source.sha256
    });
    const operations = gate.ok
      ? fixture.materializeCompletionOperations({
        proposal: reviewedValue,
        currentSourceDigest: snapshot.document.payload.source.sha256
      })
      : [];
    const store = fixture.createEncryptedTemplateStore({
      dbName: `pdf-editor-template-browser-test-${Date.now()}`,
      passphrase: "browser-template-test-passphrase"
    });
    await store.put("template", template.payload.templateID, template);
    await store.put("profile", profile.payload.profileID, profile, {
      profilePassphrase: "browser-profile-test-passphrase"
    });
    const storedTemplate = await store.get("template", template.payload.templateID);
    const storedProfile = await store.get("profile", profile.payload.profileID);
    const storedKinds = (await store.list("template")).map((entry) => entry.kind);
    await store.remove("profile", profile.payload.profileID);
    const removedProfile = await store.get("profile", profile.payload.profileID);
    return {
      match,
      candidatePresent: Boolean(candidate),
      gate,
      operations,
      storage: {
        mode: store.mode,
        templateRoundTrip: storedTemplate.payload.templateID === template.payload.templateID,
        profileRoundTrip: storedProfile.payload.profileID === profile.payload.profileID,
        storedKinds,
        removedProfile
      }
    };
  });

  assert.equal(result.match.state, "exact");
  assert.equal(result.match.score, 1);
  assert.equal(result.candidatePresent, true);
  assert.deepEqual(result.match.approvedMappingIDs, ["mapping-browser-1"]);
  assert.equal(result.match.requiresMappingReview, true);
  assert.equal(result.match.requiresValueReview, true);
  assert.equal(result.gate.ok, true);
  assert.equal(result.operations.length, 1);
  assert.equal(result.operations[0].sourceDigest.length, 64);
  assert.equal(result.operations[0].destructive, false);
  assert.equal(result.storage.mode, "indexeddb-aes-gcm");
  assert.equal(result.storage.templateRoundTrip, true);
  assert.equal(result.storage.profileRoundTrip, true);
  assert.deepEqual(result.storage.storedKinds, ["template"]);
  assert.equal(result.storage.removedProfile, null);
  assert.deepEqual(consoleErrors, [], `browser console errors: ${consoleErrors.join(" | ")}`);
  assert.deepEqual(pageErrors, [], `browser page errors: ${pageErrors.join(" | ")}`);
  console.log("web template browser adapter: fingerprint creation and exact reviewed proposal passed");
} finally {
  await browser.close();
}
