import assert from "node:assert/strict";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const baseURL = process.env.PDF_EDITOR_BASE_URL || "http://127.0.0.1:4173/web/index.html";
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
  assert.equal(await page.locator("#findTemplateMatchesButton").count(), 1, "local template search must be visible");
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
  const reviewText = await page.locator("#templateCompletionList").textContent();
  assert.match(reviewText, /Approve mapping/, "mapping approval must be visible");
  assert.match(reviewText, /Approve exact profile value/, "profile-value approval must be a separate visible decision");

  const result = await page.evaluate(async () => {
    const fixture = window.__pdfEditorContractFixture;
    const snapshot = fixture.snapshot();
    const fingerprint = await fixture.createTemplateFingerprint({
      workspaceKey: "browser-local-template-key",
      includeExactSourceDigest: true
    });
    const candidate = snapshot.candidates.find((entry) => entry.coordinate && entry.suggestedFieldType === "text")
      || snapshot.candidates.find((entry) => entry.coordinate);
    const nativeField = snapshot.document.payload.fields.find((entry) => entry.coordinate);
    const target = candidate
      ? {
        kind: "staticRegion",
        pageIndex: candidate.pageIndex,
        region: candidate.coordinate,
        candidateKind: candidate.kind
      }
      : nativeField
        ? {
          kind: "nativeField",
          pageIndex: nativeField.pageIndex,
          region: nativeField.coordinate,
          nativeFieldNameToken: nativeField.name
        }
        : null;
    const mapping = target ? {
      id: "mapping-browser-1",
      semanticKey: "person.fullName",
      target,
      suggestedFieldType: "text",
      evidenceReferences: candidate?.id ? [candidate.id] : [],
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
    const templateIndex = fixture.buildTemplateIndex([{ templateID: template.payload.templateID, revisions: [template] }]);
    const exactIndexMatch = fixture.queryTemplateIndex({
      index: templateIndex,
      fingerprint,
      sourceDigest: snapshot.document.payload.source.sha256
    });
    const staleIndexMatch = fixture.queryTemplateIndex({
      index: fixture.buildTemplateIndex([{
        templateID: template.payload.templateID,
        revisions: [{ ...template, payload: { ...template.payload, lifecycle: "revoked" } }]
      }]),
      fingerprint,
      sourceDigest: snapshot.document.payload.source.sha256
    });
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
    const resolvedTarget = target?.kind === "nativeField"
      ? fixture.resolveCompletionTarget(proposal, "mapping-browser-1", nativeField.id)
      : proposal;
    const reviewedMapping = fixture.reviewCompletionMapping(resolvedTarget, "mapping-browser-1", true);
    const reviewedValue = fixture.reviewCompletionValue(reviewedMapping, "mapping-browser-1", { kind: "text", text: "Ada Lovelace" }, true);
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
    let opfs = { available: Boolean(navigator.storage?.getDirectory) };
    if (opfs.available) {
      const opfsStore = fixture.createEncryptedOPFSTemplateStore({
        fileName: `pdf-editor-template-browser-test-${Date.now()}.json`,
        passphrase: "browser-opfs-test-passphrase"
      });
      await opfsStore.unlock();
      await opfsStore.put("template", template.payload.templateID, template);
      await opfsStore.put("profile", profile.payload.profileID, profile, {
        profilePassphrase: "browser-opfs-profile-passphrase"
      });
      opfsStore.lockProfile(profile.payload.profileID);
      await opfsStore.put("template", `${template.payload.templateID}-second`, template);
      const storedOPFSTemplate = await opfsStore.get("template", template.payload.templateID);
      const encryptedBackup = await opfsStore.exportEncryptedBackup();
      const opfsProfileLocked = await opfsStore.get("profile", profile.payload.profileID).then(
        () => false,
        (error) => error.code === "profile_locked"
      );
      await opfsStore.unlockProfile(profile.payload.profileID, "browser-opfs-profile-passphrase");
      const storedOPFSProfile = await opfsStore.get("profile", profile.payload.profileID);
      opfs = {
        available: true,
        mode: opfsStore.mode,
        templateRoundTrip: storedOPFSTemplate.payload.templateID === template.payload.templateID,
        encryptedBackup: encryptedBackup.records.length > 0,
        plaintextBackupLeak: JSON.stringify(encryptedBackup).includes("Ada Lovelace"),
        lockedProfilePreserved: opfsProfileLocked,
        profileRoundTrip: storedOPFSProfile.payload.profileID === profile.payload.profileID
      };
      await opfsStore.deleteStore();
    }
    return {
      match,
      index: {
        privacy: templateIndex.privacy,
        exactState: exactIndexMatch.state,
        exactSelected: Boolean(exactIndexMatch.selected),
        staleState: staleIndexMatch.state,
        staleAbstained: staleIndexMatch.abstained
      },
      targetKind: target?.kind || null,
      targetPresent: Boolean(target),
      gate,
      operations,
      storage: {
        mode: store.mode,
        templateRoundTrip: storedTemplate.payload.templateID === template.payload.templateID,
        profileRoundTrip: storedProfile.payload.profileID === profile.payload.profileID,
        storedKinds,
        removedProfile,
        opfs
      }
    };
  });

  assert.equal(result.match.state, "exact");
  assert.equal(result.match.score, 1);
  assert.equal(result.targetPresent, true);
  assert.ok(["nativeField", "staticRegion"].includes(result.targetKind));
  assert.deepEqual(result.match.approvedMappingIDs, ["mapping-browser-1"]);
  assert.equal(result.match.requiresMappingReview, true);
  assert.equal(result.match.requiresValueReview, true);
  assert.equal(result.gate.ok, true);
  assert.equal(result.operations.length, 1);
  assert.equal(result.operations[0].sourceDigest.length, 64);
  assert.equal(result.operations[0].destructive, false);
  assert.equal(result.index.privacy, "value-free-keyed-layout-only");
  assert.equal(result.index.exactState, "exact");
  assert.equal(result.index.exactSelected, true);
  assert.equal(result.index.staleState, "stale");
  assert.equal(result.index.staleAbstained, true);
  assert.equal(result.storage.mode, "indexeddb-aes-gcm");
  assert.equal(result.storage.templateRoundTrip, true);
  assert.equal(result.storage.profileRoundTrip, true);
  assert.deepEqual(result.storage.storedKinds, ["template"]);
  assert.equal(result.storage.removedProfile, null);
  if (result.storage.opfs.available) {
    assert.equal(result.storage.opfs.mode, "opfs-aes-gcm");
    assert.equal(result.storage.opfs.templateRoundTrip, true);
    assert.equal(result.storage.opfs.encryptedBackup, true);
    assert.equal(result.storage.opfs.plaintextBackupLeak, false);
    assert.equal(result.storage.opfs.lockedProfilePreserved, true);
    assert.equal(result.storage.opfs.profileRoundTrip, true);
  }
  assert.deepEqual(consoleErrors, [], `browser console errors: ${consoleErrors.join(" | ")}`);
  assert.deepEqual(pageErrors, [], `browser page errors: ${pageErrors.join(" | ")}`);
  console.log("web template browser adapter: fingerprint creation and exact reviewed proposal passed");
} finally {
  await browser.close();
}
