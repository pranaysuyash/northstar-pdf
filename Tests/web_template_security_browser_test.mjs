import assert from "node:assert/strict";
import { chromium } from "/Users/pranay/.agents/skills/testing/playwright-skill/node_modules/playwright/index.mjs";

const baseURL = process.env.PDF_PROOF_BASE_URL || "http://127.0.0.1:4173/web/index.html";
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
    () => Boolean(window.__pdfEditorContractFixture?.createEncryptedTemplateStore),
    undefined,
    { timeout: 30_000 }
  );

  const result = await page.evaluate(async () => {
    const fixture = window.__pdfEditorContractFixture;
    const expectEqual = (actual, expected, label) => {
      if (actual !== expected) throw new Error(`${label}: expected ${expected}, received ${actual}`);
    };
    const expectRejectCode = async (operation, code) => {
      try {
        await operation();
      } catch (error) {
        if (error.code === code) return;
        throw new Error(`Expected ${code}, received ${error.code || error.message}`);
      }
      throw new Error(`Expected rejection with ${code}.`);
    };
    const expectEmpty = (value, label) => {
      if (!Array.isArray(value) || value.length !== 0) throw new Error(`${label} was not empty.`);
    };
    const dbName = `pdf-editor-template-security-${Date.now()}`;
    const storePassphrase = "browser-store-security-passphrase";
    const profilePassphrase = "browser-profile-security-passphrase";
    const logger = fixture.createZeroContentLogger();
    const template = {
      header: {
        contractName: "pdf-editor.template",
        version: { major: 1, minor: 0 },
        templateDigest: "hmac:security",
        generatedAt: "2026-08-24T00:00:00.000Z",
        provider: { id: "security-test", version: "1", platform: "web", capabilities: [] }
      },
      payload: {
        templateID: "template-security",
        revisionID: "revision-security",
        displayName: "Private applicant template",
        lifecycle: "active",
        privacyMode: "localMinimized",
        fingerprint: { layoutFingerprint: "hmac:security" },
        mappings: [],
        reviewPolicy: { requireValueReview: true }
      }
    };
    const profile = {
      header: {
        contractName: "pdf-editor.profile",
        version: { major: 1, minor: 0 },
        profileID: "profile-security",
        revisionID: "profile-revision-security",
        generatedAt: "2026-08-24T00:00:00.000Z",
        provider: { id: "security-test", version: "1", platform: "web", capabilities: [] }
      },
      payload: {
        profileID: "profile-security",
        revisionID: "profile-revision-security",
        displayName: "Private profile",
        revisionNumber: 1,
        storageScope: "deviceLocal",
        requiresUnlock: true,
        values: [{
          id: "profile-value-security",
          semanticKey: "person.fullName",
          value: { kind: "text", text: "Ada Lovelace Secret Value" }
        }]
      }
    };
    const childTemplate = {
      ...template,
      payload: {
        ...template.payload,
        revisionID: "revision-security-child",
        parentRevisionID: template.payload.revisionID,
        displayName: "Private applicant template child"
      }
    };

    const store = fixture.createEncryptedTemplateStore({ dbName, logger });
    logger.record({
      event: "privacy_probe",
      code: "probe",
      kind: "profile",
      id: "Ada Lovelace Secret Value",
      value: "browser-store-security-passphrase"
    });
    await expectRejectCode(() => store.get("template", template.payload.templateID), "store_locked");
    await store.unlock(storePassphrase);
    expectEqual(store.isUnlocked, true, "store unlock state");
    await store.put("template", template.payload.templateID, template);
    await store.saveTemplateRevision(template);
    await store.saveTemplateRevision(childTemplate);
    await expectRejectCode(
      () => store.put("profile", profile.payload.profileID, profile),
      "passphrase_too_short"
    );
    await store.put("profile", profile.payload.profileID, profile, { profilePassphrase });
    await store.saveProfileRevision(profile, { profilePassphrase });
    store.lockProfile(profile.payload.profileID);
    await expectRejectCode(() => store.get("profile", profile.payload.profileID), "profile_locked");
    await expectRejectCode(() => store.unlockProfile(profile.payload.profileID, "wrong-profile-passphrase"), "profile_unlock_failed");
    await store.unlockProfile(profile.payload.profileID, profilePassphrase);
    const unlockedProfile = await store.get("profile", profile.payload.profileID);
    expectEqual(unlockedProfile.payload.values[0].value.text, "Ada Lovelace Secret Value", "unlocked profile value");

    const healthBefore = await store.inspectHealth();
    expectEqual(healthBefore.state, "ready", "initial health state");
    expectEqual(healthBefore.recordCount, 4, "initial health count");
    const backup = await store.exportEncryptedBackup();
    const backupText = JSON.stringify(backup);
    expectEqual(backupText.includes("Ada Lovelace Secret Value"), false, "backup profile-content exclusion");
    expectEqual(backupText.includes("browser-profile-security-passphrase"), false, "backup passphrase exclusion");
    expectEqual(backupText.includes("%PDF-"), false, "backup source-byte exclusion");
    const recoveryPassphrase = "browser-key-recovery-passphrase";
    const recoveryEnvelope = await store.exportPassphraseRecovery(recoveryPassphrase);
    const recoveryText = JSON.stringify(recoveryEnvelope);
    expectEqual(recoveryText.includes(recoveryPassphrase), false, "recovery passphrase exclusion");
    expectEqual(recoveryEnvelope.contractName, "pdf-editor.local-store-recovery", "recovery contract");

    store.lock();
    expectEqual(store.isUnlocked, false, "store lock state");
    await expectRejectCode(() => store.get("template", template.payload.templateID), "store_locked");
    store.close();
    await new Promise((resolve, reject) => {
      const request = indexedDB.deleteDatabase(dbName);
      request.onsuccess = resolve;
      request.onerror = () => reject(request.error);
      request.onblocked = () => reject(new Error("eviction simulation was blocked"));
    });

    const evictedStore = fixture.createEncryptedTemplateStore({ dbName, logger });
    const evictedHealth = await evictedStore.inspectHealth();
    expectEqual(evictedHealth.state, "evicted", "evicted health state");
    expectEqual(evictedHealth.recovery, "restoreEncryptedBackup", "eviction recovery action");
    await expectRejectCode(() => evictedStore.unlock(storePassphrase), "store_evicted");
    await expectRejectCode(() => evictedStore.recoverPassphraseRecovery(recoveryEnvelope, "wrong-recovery-passphrase"), "recovery_failed");
    const recoveredKeyHealth = await evictedStore.recoverPassphraseRecovery(recoveryEnvelope, recoveryPassphrase);
    expectEqual(recoveredKeyHealth.state, "evicted", "recovered key with evicted records");
    await expectRejectCode(() => evictedStore.restoreEncryptedBackup({ ...backup, version: { major: 99, minor: 0 } }, { storePassphrase }), "backup_invalid");
    const restoredHealth = await evictedStore.restoreEncryptedBackup(backup, { storePassphrase });
    expectEqual(restoredHealth.state, "ready", "restored health state");
    expectEqual(restoredHealth.recordCount, 4, "restored health count");
    const restoredTemplate = await evictedStore.get("template", template.payload.templateID);
    expectEqual(restoredTemplate.payload.templateID, template.payload.templateID, "restored template identity");
    await expectRejectCode(() => evictedStore.get("profile", profile.payload.profileID), "profile_locked");
    await evictedStore.unlockProfile(profile.payload.profileID, profilePassphrase);
    const restoredProfile = await evictedStore.get("profile", profile.payload.profileID);
    expectEqual(restoredProfile.payload.values[0].value.text, "Ada Lovelace Secret Value", "restored profile value");

    const crossDeviceBundle = fixture.createCrossDeviceRecoveryBundle({
      backup,
      recovery: recoveryEnvelope,
      storeKind: "template"
    });
    expectEqual(fixture.validateCrossDeviceRecoveryBundle(crossDeviceBundle), true, "cross-device bundle validation");
    const workerEvidence = await fixture.validateEncryptedBackupInWorker(crossDeviceBundle.backup);
    expectEqual(workerEvidence.plaintextInspected, false, "worker plaintext boundary");
    const crossDeviceDbName = `${dbName}-different-device`;
    const crossDeviceStore = fixture.createEncryptedTemplateStore({ dbName: crossDeviceDbName, logger });
    await crossDeviceStore.recoverPassphraseRecovery(crossDeviceBundle.recovery, recoveryPassphrase, { crossDevice: true });
    await crossDeviceStore.restoreEncryptedBackup(crossDeviceBundle.backup, {
      replace: true,
      preserveRecoveredKey: true
    });
    await crossDeviceStore.rekeyStore(recoveryPassphrase);
    crossDeviceStore.lock();
    await crossDeviceStore.unlock(recoveryPassphrase);
    const crossDeviceTemplate = await crossDeviceStore.get("template", template.payload.templateID);
    expectEqual(crossDeviceTemplate.payload.templateID, template.payload.templateID, "cross-device template identity");
    const crossDeviceProfileLocked = await crossDeviceStore.get("profile", profile.payload.profileID).then(
      () => false,
      (error) => error.code === "profile_locked"
    );
    await crossDeviceStore.unlockProfile(profile.payload.profileID, profilePassphrase);
    const crossDeviceProfile = await crossDeviceStore.get("profile", profile.payload.profileID);
    expectEqual(crossDeviceProfile.payload.values[0].value.text, "Ada Lovelace Secret Value", "cross-device profile value");

    const wrongPassphraseStore = fixture.createEncryptedTemplateStore({ dbName, logger });
    await expectRejectCode(() => wrongPassphraseStore.unlock("wrong-store-passphrase"), "unlock_failed");
    wrongPassphraseStore.close();
    await evictedStore.deleteProfile(profile.payload.profileID);
    await evictedStore.deleteTemplate(template.payload.templateID);
    expectEmpty(await evictedStore.list("profile"), "deleted profile list");
    expectEmpty(await evictedStore.list("template"), "deleted template list");
    expectEmpty(await evictedStore.list("profileHistory"), "deleted profile history list");
    expectEmpty(await evictedStore.list("templateHistory"), "deleted template history list");
    await evictedStore.deleteStore();
    const deletedHealth = await evictedStore.inspectHealth();
    expectEqual(deletedHealth.state, "uninitialized", "deleted store health state");

    const logs = logger.snapshot();
    const logText = JSON.stringify(logs);
    return {
      healthBefore,
      evictedHealth,
      restoredHealth,
      deletedHealth,
      crossDevice: {
        worker: workerEvidence.worker,
        encryptedRecordCount: workerEvidence.encryptedRecordCount,
        templateRoundTrip: crossDeviceTemplate.payload.templateID === template.payload.templateID,
        profileLockedUntilUnlock: crossDeviceProfileLocked,
        profileRoundTrip: crossDeviceProfile.payload.profileID === profile.payload.profileID
      },
      logs,
      zeroContent: !logText.includes("Ada Lovelace Secret Value")
        && !logText.includes("browser-store-security-passphrase")
        && !logText.includes("browser-profile-security-passphrase")
        && !logText.includes("%PDF-")
        && !logText.includes(recoveryPassphrase),
      auditCount: evictedStore.auditSnapshot().length
    };
  });

  assert.equal(result.healthBefore.state, "ready");
  assert.equal(result.evictedHealth.state, "evicted");
  assert.equal(result.restoredHealth.state, "ready");
  assert.equal(result.deletedHealth.state, "uninitialized");
  assert.equal(result.crossDevice.templateRoundTrip, true);
  assert.equal(result.crossDevice.profileLockedUntilUnlock, true);
  assert.equal(result.crossDevice.profileRoundTrip, true);
  assert.equal(result.zeroContent, true);
  assert.ok(result.auditCount >= 1);
  assert.ok(result.logs.some((event) => event.code === "profile_unlock_failed"));
  assert.ok(result.logs.some((event) => event.code === "store_evicted"));
  assert.ok(result.logs.some((event) => event.code === "backup_restore_ok"));
  assert.ok(result.logs.some((event) => event.code === "store_delete_ok"));
  assert.equal(result.logs.some((event) => event.event === "privacy_probe"), false);
  for (const event of result.logs) {
    assert.deepEqual(Object.keys(event).sort(), Object.keys(event).filter((key) => ["event", "code", "kind", "mode", "state", "count"].includes(key)).sort());
  }
  assert.deepEqual(consoleErrors, []);
  assert.deepEqual(pageErrors, []);
  console.log("web template security: store unlock, profile unlock, deletion, eviction recovery, and zero-content logging passed");
} finally {
  await browser.close();
}
