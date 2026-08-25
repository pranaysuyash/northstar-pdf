import {
  appendProfileRevision,
  appendTemplateRevision,
  exportTemplateHistory as exportTemplateHistoryContract,
  importTemplateHistory as importTemplateHistoryContract,
  validateProfileContract,
  validateTemplateContract
} from "./pdf-template-contract.mjs";

const STORE_VERSION = 2;
const BACKUP_CONTRACT_NAME = "pdf-editor.template-store-backup";
const BACKUP_VERSION = { major: 1, minor: 0 };
const META_KEY = "__meta__";
const PRESENCE_PREFIX = "pdf-editor-template-store-present:";
const PROFILE_SALT_BYTES = 16;

const RECORD_KINDS = new Set([
  "template",
  "templateHistory",
  "profile",
  "profileHistory",
  "learningEvent",
  "revisionPromotion"
]);
const PRIVACY_EVENT_FIELDS = new Set(["event", "code", "kind", "mode", "state", "count"]);
const ALLOWED_PRIVACY_EVENTS = new Set([
  "store_version_changed",
  "store_access_blocked",
  "store_eviction_detected",
  "store_unlocked",
  "store_unlock_failed",
  "record_written",
  "profile_access_blocked",
  "profile_unlock_failed",
  "profile_unlocked",
  "profile_locked",
  "store_locked",
  "store_health",
  "backup_exported",
  "backup_restored",
  "store_closed",
  "store_deleted"
]);
const ALLOWED_PRIVACY_CODES = new Set([
  "locked",
  "store_locked",
  "store_evicted",
  "store_initialized",
  "store_authenticated",
  "unlock_failed",
  "write_ok",
  "profile_locked",
  "profile_unlock_failed",
  "profile_authenticated",
  "backup_export_ok",
  "backup_restore_ok",
  "store_closed",
  "store_delete_ok",
  "delete_ok"
]);
const ALLOWED_PRIVACY_STATES = new Set(["locked", "unlocked", "ready", "evicted", "closed", "deleted"]);

export class TemplateStoreError extends Error {
  constructor(code, message = code) {
    super(message);
    this.name = "TemplateStoreError";
    this.code = code;
  }
}

function assertKind(kind) {
  if (!RECORD_KINDS.has(kind)) {
    throw new TemplateStoreError("unsupported_record_kind", "Unsupported template store record kind.");
  }
}

function assertNoSourceBytes(value) {
  const serialized = JSON.stringify(value);
  if (serialized.includes("%PDF-") || serialized.includes('"bytes"') || serialized.includes('"rawPDF"')) {
    throw new TemplateStoreError("source_bytes_rejected", "Template store records cannot contain source PDF bytes.");
  }
}

function requirePassphrase(passphrase, label = "local template-store") {
  if (typeof passphrase !== "string" || passphrase.length < 12) {
    throw new TemplateStoreError("passphrase_too_short", `A ${label} passphrase of at least 12 characters is required.`);
  }
}

function bytesToBase64(bytes) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function base64ToBytes(value) {
  try {
    return Uint8Array.from(atob(value), (character) => character.charCodeAt(0));
  } catch {
    throw new TemplateStoreError("record_corrupt", "Encrypted template store record is corrupt.");
  }
}

function fixedPrivacyEvent(event) {
  const output = {};
  for (const field of PRIVACY_EVENT_FIELDS) {
    if (event[field] !== undefined) output[field] = event[field];
  }
  if (!ALLOWED_PRIVACY_EVENTS.has(output.event) || !ALLOWED_PRIVACY_CODES.has(output.code)) return null;
  if (output.kind !== undefined && !RECORD_KINDS.has(output.kind)) delete output.kind;
  if (output.mode !== undefined && !["indexeddb-aes-gcm", "opfs-aes-gcm", "ephemeral"].includes(output.mode)) delete output.mode;
  if (output.state !== undefined && !ALLOWED_PRIVACY_STATES.has(output.state)) delete output.state;
  if (output.count !== undefined && (!Number.isInteger(output.count) || output.count < 0)) delete output.count;
  return output;
}

export function createZeroContentLogger({ sink = () => {} } = {}) {
  const events = [];
  const record = (event) => {
    const safeEvent = fixedPrivacyEvent(event);
    if (!safeEvent) return;
    events.push(structuredClone(safeEvent));
    try {
      sink(structuredClone(safeEvent));
    } catch {
      // Diagnostics must never change the storage outcome or expose an error.
    }
  };
  return Object.freeze({
    record,
    snapshot: () => structuredClone(events)
  });
}

async function deriveKey(passphrase, salt, label = "local template-store") {
  requirePassphrase(passphrase, label);
  const material = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(passphrase),
    "PBKDF2",
    false,
    ["deriveKey"]
  );
  return crypto.subtle.deriveKey(
    { name: "PBKDF2", salt, iterations: 150_000, hash: "SHA-256" },
    material,
    { name: "AES-GCM", length: 256 },
    false,
    ["encrypt", "decrypt"]
  );
}

async function encryptJSON(key, value) {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ciphertext = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv },
    key,
    new TextEncoder().encode(JSON.stringify(value))
  );
  return { iv: bytesToBase64(iv), ciphertext: bytesToBase64(new Uint8Array(ciphertext)) };
}

async function decryptJSON(key, record) {
  try {
    const plaintext = await crypto.subtle.decrypt(
      { name: "AES-GCM", iv: base64ToBytes(record.iv) },
      key,
      base64ToBytes(record.ciphertext)
    );
    return JSON.parse(new TextDecoder().decode(plaintext));
  } catch (error) {
    if (error instanceof TemplateStoreError) throw error;
    throw new TemplateStoreError("authentication_failed", "Encrypted template store record could not be authenticated.");
  }
}

function validateRecord(kind, value) {
  assertKind(kind);
  assertNoSourceBytes(value);
  if (kind === "template") validateTemplateContract(value);
  if (kind === "profile" || kind === "profileHistory") validateProfileRecord(kind, value);
  if (kind === "templateHistory") validateTemplateHistory(value);
}

function validateTemplateHistory(history) {
  if (!history || typeof history !== "object" || typeof history.templateID !== "string" || !Array.isArray(history.revisions)) {
    throw new TemplateStoreError("invalid_revision_history", "Template revision history is invalid.");
  }
  if (history.revisions.length === 0) {
    throw new TemplateStoreError("invalid_revision_history", "Template revision history cannot be empty.");
  }
  const seen = new Set();
  for (const [index, revision] of history.revisions.entries()) {
    validateTemplateContract(revision);
    if (revision.payload.templateID !== history.templateID || seen.has(revision.payload.revisionID)) {
      throw new TemplateStoreError("invalid_revision_history", "Template revision identity is duplicated or inconsistent.");
    }
    if (revision.payload.parentRevisionID && !seen.has(revision.payload.parentRevisionID)) {
      throw new TemplateStoreError("invalid_revision_history", "Template revision parent must precede its child.");
    }
    seen.add(revision.payload.revisionID);
  }
}

function validateProfileRecord(kind, value) {
  if (kind === "profile") {
    validateProfileContract(value);
    return;
  }
  if (!value || typeof value !== "object" || typeof value.profileID !== "string" || !Array.isArray(value.revisions) || value.revisions.length === 0) {
    throw new TemplateStoreError("invalid_revision_history", "Profile revision history is invalid.");
  }
  const seen = new Set();
  for (const revision of value.revisions) {
    validateProfileContract(revision);
    if (revision.payload.profileID !== value.profileID || revision.header.profileID !== value.profileID || seen.has(revision.payload.revisionID)) {
      throw new TemplateStoreError("invalid_revision_history", "Profile revision identity is duplicated or inconsistent.");
    }
    if (revision.payload.parentRevisionID && !seen.has(revision.payload.parentRevisionID)) {
      throw new TemplateStoreError("invalid_revision_history", "Profile revision parent must precede its child.");
    }
    seen.add(revision.payload.revisionID);
  }
}

function isProfileKind(kind) {
  return kind === "profile" || kind === "profileHistory";
}

function openDatabase(dbName) {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(dbName, STORE_VERSION);
    request.onupgradeneeded = () => {
      const database = request.result;
      if (!database.objectStoreNames.contains("records")) {
        database.createObjectStore("records", { keyPath: "key" });
      }
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(new TemplateStoreError("database_open_failed", "Unable to open template store."));
  });
}

function requestResult(request) {
  return new Promise((resolve, reject) => {
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(new TemplateStoreError("database_request_failed", "Template store request failed."));
  });
}

function presenceMarkerKey(dbName) {
  return `${PRESENCE_PREFIX}${dbName}`;
}

function hasPresenceMarker(dbName) {
  try {
    return localStorage.getItem(presenceMarkerKey(dbName)) === "1";
  } catch {
    return false;
  }
}

function setPresenceMarker(dbName) {
  try {
    localStorage.setItem(presenceMarkerKey(dbName), "1");
  } catch {
    // The encrypted database remains authoritative if localStorage is unavailable.
  }
}

function clearPresenceMarker(dbName) {
  try {
    localStorage.removeItem(presenceMarkerKey(dbName));
  } catch {
    // Best effort only. The database deletion itself remains authoritative.
  }
}

function validateBackup(backup) {
  if (!backup || typeof backup !== "object" || Array.isArray(backup)) {
    throw new TemplateStoreError("backup_invalid", "Template store backup is invalid.");
  }
  if (backup.contractName !== BACKUP_CONTRACT_NAME
      || backup.version?.major !== BACKUP_VERSION.major
      || backup.version?.minor > BACKUP_VERSION.minor
      || !Array.isArray(backup.records)
      || !backup.metaRecord) {
    throw new TemplateStoreError("backup_invalid", "Template store backup version is not readable.");
  }
  const seen = new Set();
  for (const record of [backup.metaRecord, ...backup.records]) {
    if (!record || typeof record.key !== "string" || seen.has(record.key)) {
      throw new TemplateStoreError("backup_invalid", "Template store backup contains invalid record identity.");
    }
    seen.add(record.key);
    if (record.schemaVersion !== STORE_VERSION || typeof record.ciphertext !== "string") {
      throw new TemplateStoreError("backup_invalid", "Template store backup contains an unsupported encrypted record.");
    }
  }
  if (backup.metaRecord.key !== META_KEY) {
    throw new TemplateStoreError("backup_invalid", "Template store backup metadata is missing.");
  }
}

export function createEncryptedTemplateStore({
  dbName = "pdf-editor-template-store-v2",
  passphrase = null,
  logger = createZeroContentLogger()
} = {}) {
  let databasePromise;
  let databaseHandle = null;
  let storeKey = null;
  let storeState = "locked";
  let initialized = false;
  const unlockedProfiles = new Map();
  const database = () => databasePromise ||= openDatabase(dbName).then((db) => {
    databaseHandle = db;
    db.onversionchange = () => {
      db.close();
      databaseHandle = null;
      databasePromise = null;
      storeKey = null;
      storeState = "locked";
      unlockedProfiles.clear();
      logger.record({ event: "store_version_changed", code: "locked", mode: "indexeddb-aes-gcm", state: storeState });
    };
    return db;
  });

  async function rawGet(key) {
    const db = await database();
    return requestResult(db.transaction("records", "readonly").objectStore("records").get(key));
  }

  async function rawGetAll() {
    const db = await database();
    return requestResult(db.transaction("records", "readonly").objectStore("records").getAll());
  }

  async function rawPut(record) {
    const db = await database();
    return requestResult(db.transaction("records", "readwrite").objectStore("records").put(record));
  }

  async function ensureUnlocked(providedPassphrase = passphrase, { allowEvictionRecovery = false } = {}) {
    if (storeKey) return storeKey;
    if (!providedPassphrase) {
      logger.record({ event: "store_access_blocked", code: "store_locked", mode: "indexeddb-aes-gcm", state: "locked" });
      throw new TemplateStoreError("store_locked", "Unlock the local template store before accessing records.");
    }
    requirePassphrase(providedPassphrase);
    const metaRecord = await rawGet(META_KEY);
    if (!metaRecord) {
      if (initialized || hasPresenceMarker(dbName)) {
        storeState = "evicted";
        logger.record({ event: "store_eviction_detected", code: "store_evicted", mode: "indexeddb-aes-gcm", state: storeState });
        if (!allowEvictionRecovery) {
          throw new TemplateStoreError("store_evicted", "The browser removed this local store. Restore an encrypted backup before use.");
        }
      }
      const salt = crypto.getRandomValues(new Uint8Array(16));
      const key = await deriveKey(providedPassphrase, salt);
      const meta = {
        contractName: "pdf-editor.template-store-meta",
        version: { major: 1, minor: 0 },
        storeID: crypto.randomUUID(),
        createdAt: new Date().toISOString()
      };
      const encrypted = await encryptJSON(key, meta);
      await rawPut({
        key: META_KEY,
        schemaVersion: STORE_VERSION,
        kind: "meta",
        id: META_KEY,
        salt: bytesToBase64(salt),
        ...encrypted,
        updatedAt: new Date().toISOString()
      });
      storeKey = key;
      initialized = true;
      storeState = "unlocked";
      setPresenceMarker(dbName);
      logger.record({ event: "store_unlocked", code: "store_initialized", mode: "indexeddb-aes-gcm", state: storeState });
      return storeKey;
    }
    if (metaRecord.schemaVersion !== STORE_VERSION || metaRecord.kind !== "meta") {
      throw new TemplateStoreError("store_schema_unsupported", "The local template store schema is not supported.");
    }
    try {
      const key = await deriveKey(providedPassphrase, base64ToBytes(metaRecord.salt));
      const meta = await decryptJSON(key, metaRecord);
      if (meta.contractName !== "pdf-editor.template-store-meta" || meta.version?.major !== 1) {
        throw new TemplateStoreError("store_metadata_invalid", "The local template store metadata is invalid.");
      }
      storeKey = key;
      initialized = true;
      storeState = "unlocked";
      setPresenceMarker(dbName);
      logger.record({ event: "store_unlocked", code: "store_authenticated", mode: "indexeddb-aes-gcm", state: storeState });
      return storeKey;
    } catch (error) {
      storeState = "locked";
      logger.record({ event: "store_unlock_failed", code: "unlock_failed", mode: "indexeddb-aes-gcm", state: storeState });
      if (error instanceof TemplateStoreError && error.code === "store_metadata_invalid") throw error;
      throw new TemplateStoreError("unlock_failed", "The local template store passphrase was not accepted.");
    }
  }

  async function encryptRecord(kind, id, value, options = {}) {
    const key = await ensureUnlocked(options.storePassphrase);
    let payload = value;
    if (isProfileKind(kind)) {
      requirePassphrase(options.profilePassphrase, "profile");
      const profileSalt = crypto.getRandomValues(new Uint8Array(PROFILE_SALT_BYTES));
      const profileKey = await deriveKey(options.profilePassphrase, profileSalt, "profile");
      const profileCipher = await encryptJSON(profileKey, value);
      payload = {
        profileEnvelope: {
          profileSchemaVersion: 1,
          profileSalt: bytesToBase64(profileSalt),
          profileIV: profileCipher.iv,
          profileCiphertext: profileCipher.ciphertext
        }
      };
      unlockedProfiles.set(id, profileKey);
    }
    const encrypted = await encryptJSON(key, payload);
    return {
      key: `${kind}:${id}`,
      schemaVersion: STORE_VERSION,
      kind,
      id,
      ...encrypted,
      updatedAt: new Date().toISOString()
    };
  }

  async function decryptRecord(record, options = {}) {
    const key = await ensureUnlocked(options.storePassphrase);
    if (record.schemaVersion !== STORE_VERSION) {
      throw new TemplateStoreError("record_schema_unsupported", "Encrypted template store record schema is not supported.");
    }
    const payload = await decryptJSON(key, record);
    if (!isProfileKind(record.kind)) {
      validateRecord(record.kind, payload);
      return payload;
    }
    const profileEnvelope = payload.profileEnvelope;
    const profileKey = options.profilePassphrase
      ? await deriveKey(options.profilePassphrase, base64ToBytes(profileEnvelope?.profileSalt), "profile")
      : unlockedProfiles.get(record.id);
    if (!profileKey) {
      logger.record({ event: "profile_access_blocked", code: "profile_locked", kind: "profile", mode: "indexeddb-aes-gcm", state: "locked" });
      throw new TemplateStoreError("profile_locked", "Unlock this profile before accessing its values.");
    }
    try {
      const profile = await decryptJSON(profileKey, {
        iv: profileEnvelope?.profileIV,
        ciphertext: profileEnvelope?.profileCiphertext
      });
      validateProfileContract(profile);
      unlockedProfiles.set(record.id, profileKey);
      return profile;
    } catch (error) {
      logger.record({ event: "profile_unlock_failed", code: "profile_unlock_failed", kind: "profile", mode: "indexeddb-aes-gcm", state: "locked" });
      if (error instanceof TemplateStoreError && error.code === "profile_locked") throw error;
      throw new TemplateStoreError("profile_unlock_failed", "The profile passphrase was not accepted.");
    }
  }

  async function put(kind, id, value, options = {}) {
    validateRecord(kind, value);
    const record = await encryptRecord(kind, id, value, options);
    await rawPut(record);
    initialized = true;
    setPresenceMarker(dbName);
    logger.record({ event: "record_written", code: "write_ok", kind, mode: "indexeddb-aes-gcm", state: "unlocked" });
    return { kind, id, updatedAt: record.updatedAt };
  }

  async function get(kind, id, options = {}) {
    assertKind(kind);
    await ensureUnlocked(options.storePassphrase);
    const record = await rawGet(`${kind}:${id}`);
    if (!record) return null;
    return decryptRecord(record, options);
  }

  async function remove(kind, id, options = {}) {
    assertKind(kind);
    await ensureUnlocked(options.storePassphrase);
    const db = await database();
    await requestResult(db.transaction("records", "readwrite").objectStore("records").delete(`${kind}:${id}`));
    if (isProfileKind(kind)) unlockedProfiles.delete(id);
    logger.record({ event: "record_deleted", code: "delete_ok", kind, mode: "indexeddb-aes-gcm", state: "unlocked" });
  }

  async function list(kind, options = {}) {
    assertKind(kind);
    await ensureUnlocked(options.storePassphrase);
    const records = await rawGetAll();
    return records
      .filter((record) => record.kind === kind)
      .map(({ id, kind: recordKind, updatedAt }) => ({ id, kind: recordKind, updatedAt }));
  }

  async function saveTemplateRevision(revision, options = {}) {
    validateTemplateContract(revision);
    const templateID = revision.payload.templateID;
    const current = await get("templateHistory", templateID, options);
    const history = current
      ? appendTemplateRevision(current, revision)
      : { templateID, revisions: [revision] };
    validateTemplateHistory(history);
    await put("templateHistory", templateID, history, options);
    return structuredClone(history);
  }

  async function getTemplateHistory(templateID, options = {}) {
    return get("templateHistory", templateID, options);
  }

  async function exportTemplateHistory(templateID, options = {}) {
    const history = await getTemplateHistory(templateID, options);
    if (!history) throw new TemplateStoreError("template_not_found", "The requested template was not found.");
    return exportTemplateHistoryContract(history);
  }

  async function importTemplateHistory(envelope, { storePassphrase = passphrase, replace = false } = {}) {
    const history = importTemplateHistoryContract(envelope);
    const existing = await getTemplateHistory(history.templateID, { storePassphrase });
    if (existing && !replace) {
      throw new TemplateStoreError("template_exists", "The template already exists. Replace it explicitly to import over it.");
    }
    await put("templateHistory", history.templateID, history, { storePassphrase });
    return structuredClone(history);
  }

  async function saveLearningEvent(event, options = {}) {
    if (!event || typeof event.templateID !== "string" || typeof event.id !== "string") {
      throw new TemplateStoreError("invalid_learning_event", "Learning event identity is invalid.");
    }
    const current = await get("learningEvent", event.templateID, options);
    const events = current?.events || [];
    if (events.some((entry) => entry.id === event.id)) {
      throw new TemplateStoreError("duplicate_learning_event", "Learning event already exists.");
    }
    const journal = { templateID: event.templateID, events: [...events, structuredClone(event)] };
    await put("learningEvent", event.templateID, journal, options);
    return structuredClone(journal);
  }

  async function getLearningEvents(templateID, options = {}) {
    return (await get("learningEvent", templateID, options))?.events || [];
  }

  async function deleteLearningEvents(templateID, options = {}) {
    await remove("learningEvent", templateID, options);
  }

  async function deleteTemplate(templateID, options = {}) {
    await remove("templateHistory", templateID, options);
    await remove("template", templateID, options);
  }

  async function saveProfileRevision(revision, options = {}) {
    validateProfileContract(revision);
    const profileID = revision.payload.profileID;
    const current = await get("profileHistory", profileID, options);
    const history = current
      ? appendProfileRevision(current, revision)
      : { profileID, revisions: [revision] };
    validateProfileRecord("profileHistory", history);
    await put("profileHistory", profileID, history, {
      ...options,
      profilePassphrase: options.profilePassphrase
    });
    return structuredClone(history);
  }

  async function getProfileHistory(profileID, options = {}) {
    return get("profileHistory", profileID, options);
  }

  async function deleteProfile(profileID, options = {}) {
    await remove("profileHistory", profileID, options);
    await remove("profile", profileID, options);
  }

  async function unlock(providedPassphrase = passphrase) {
    return ensureUnlocked(providedPassphrase);
  }

  async function unlockProfile(profileID, profilePassphrase, options = {}) {
    requirePassphrase(profilePassphrase, "profile");
    const record = (await rawGet(`profile:${profileID}`)) || (await rawGet(`profileHistory:${profileID}`));
    if (!record) throw new TemplateStoreError("profile_not_found", "The requested local profile was not found.");
    try {
      await decryptRecord(record, { ...options, profilePassphrase });
      logger.record({ event: "profile_unlocked", code: "profile_authenticated", kind: "profile", mode: "indexeddb-aes-gcm", state: "unlocked" });
      return { profileID, unlocked: true };
    } catch (error) {
      if (error instanceof TemplateStoreError && error.code === "profile_unlock_failed") throw error;
      throw new TemplateStoreError("profile_unlock_failed", "The profile passphrase was not accepted.");
    }
  }

  function lockProfile(profileID) {
    unlockedProfiles.delete(profileID);
    logger.record({ event: "profile_locked", code: "profile_locked", kind: "profile", mode: "indexeddb-aes-gcm", state: "locked" });
  }

  function lock() {
    storeKey = null;
    storeState = "locked";
    unlockedProfiles.clear();
    logger.record({ event: "store_locked", code: "store_locked", mode: "indexeddb-aes-gcm", state: storeState });
  }

  async function inspectHealth() {
    const records = await rawGetAll();
    const hasMeta = records.some((record) => record.key === META_KEY);
    let quota = {};
    try {
      quota = navigator.storage?.estimate ? await navigator.storage.estimate() : {};
    } catch {
      quota = {};
    }
    const state = hasMeta ? (storeKey ? "ready" : "locked") : (hasPresenceMarker(dbName) ? "evicted" : "uninitialized");
    if (state === "evicted") logger.record({ event: "store_health", code: "store_evicted", mode: "indexeddb-aes-gcm", state });
    return {
      mode: "indexeddb-aes-gcm",
      state,
      recordCount: records.filter((record) => record.kind !== "meta").length,
      quotaBytes: Number.isFinite(quota.quota) ? quota.quota : null,
      usageBytes: Number.isFinite(quota.usage) ? quota.usage : null,
      recovery: state === "evicted" ? "restoreEncryptedBackup" : state === "ready" ? "exportEncryptedBackup" : null
    };
  }

  async function exportEncryptedBackup(options = {}) {
    await ensureUnlocked(options.storePassphrase);
    const records = await rawGetAll();
    const metaRecord = records.find((record) => record.key === META_KEY);
    const backup = {
      contractName: BACKUP_CONTRACT_NAME,
      version: { ...BACKUP_VERSION },
      storeVersion: STORE_VERSION,
      exportedAt: new Date().toISOString(),
      metaRecord,
      records: records.filter((record) => record.key !== META_KEY)
    };
    validateBackup(backup);
    logger.record({ event: "backup_exported", code: "backup_export_ok", mode: "indexeddb-aes-gcm", state: "unlocked", count: backup.records.length });
    return structuredClone(backup);
  }

  async function restoreEncryptedBackup(backup, { storePassphrase = passphrase, replace = false } = {}) {
    validateBackup(backup);
    requirePassphrase(storePassphrase);
    const existing = await rawGetAll();
    if (existing.length && !replace) {
      throw new TemplateStoreError("restore_requires_empty_store", "Restore requires an empty local store unless replace is explicit.");
    }
    const db = await database();
    await new Promise((resolve, reject) => {
      const transaction = db.transaction("records", "readwrite");
      const objectStore = transaction.objectStore("records");
      if (replace) objectStore.clear();
      objectStore.put(backup.metaRecord);
      for (const record of backup.records) objectStore.put(record);
      transaction.oncomplete = resolve;
      transaction.onerror = () => reject(new TemplateStoreError("restore_failed", "Encrypted template store recovery failed."));
      transaction.onabort = () => reject(new TemplateStoreError("restore_failed", "Encrypted template store recovery was aborted."));
    });
    storeKey = null;
    initialized = true;
    await ensureUnlocked(storePassphrase, { allowEvictionRecovery: true });
    setPresenceMarker(dbName);
    logger.record({ event: "backup_restored", code: "backup_restore_ok", mode: "indexeddb-aes-gcm", state: "unlocked", count: backup.records.length });
    return inspectHealth();
  }

  function close() {
    databaseHandle?.close();
    databaseHandle = null;
    databasePromise = null;
    storeKey = null;
    storeState = "locked";
    unlockedProfiles.clear();
    logger.record({ event: "store_closed", code: "store_closed", mode: "indexeddb-aes-gcm", state: storeState });
  }

  async function deleteStore() {
    close();
    await new Promise((resolve, reject) => {
      const request = indexedDB.deleteDatabase(dbName);
      request.onsuccess = resolve;
      request.onerror = () => reject(new TemplateStoreError("store_delete_failed", "Local template store deletion failed."));
      request.onblocked = () => reject(new TemplateStoreError("store_delete_blocked", "Local template store deletion was blocked by another browser connection."));
    });
    clearPresenceMarker(dbName);
    initialized = false;
    storeState = "deleted";
    logger.record({ event: "store_deleted", code: "store_delete_ok", mode: "indexeddb-aes-gcm", state: storeState });
  }

  const api = {
    mode: "indexeddb-aes-gcm",
    version: STORE_VERSION,
    unlock,
    lock,
    unlockProfile,
    lockProfile,
    inspectHealth,
    exportEncryptedBackup,
    restoreEncryptedBackup,
    close,
    deleteStore,
    put,
    get,
    remove,
    list,
    saveTemplateRevision,
    getTemplateHistory,
    exportTemplateHistory,
    importTemplateHistory,
    saveLearningEvent,
    getLearningEvents,
    deleteLearningEvents,
    deleteTemplate,
    saveProfileRevision,
    getProfileHistory,
    deleteProfile
  };
  Object.defineProperty(api, "isUnlocked", { enumerable: true, get: () => Boolean(storeKey) });
  Object.defineProperty(api, "logger", { enumerable: true, value: logger });
  return Object.freeze(api);
}

export function createEphemeralTemplateStore({ logger = createZeroContentLogger() } = {}) {
  const records = new Map();
  const unlockedProfiles = new Set();
  let storeState = "unlocked";
  const api = {
    mode: "ephemeral",
    version: STORE_VERSION,
    async unlock() {
      storeState = "unlocked";
      logger.record({ event: "store_unlocked", code: "store_authenticated", mode: "ephemeral", state: storeState });
      return true;
    },
    lock() {
      storeState = "locked";
      unlockedProfiles.clear();
      logger.record({ event: "store_locked", code: "store_locked", mode: "ephemeral", state: storeState });
    },
    async unlockProfile(profileID) {
      if (!records.has(`profile:${profileID}`) && !records.has(`profileHistory:${profileID}`)) throw new TemplateStoreError("profile_not_found", "The requested local profile was not found.");
      unlockedProfiles.add(profileID);
      logger.record({ event: "profile_unlocked", code: "profile_authenticated", kind: "profile", mode: "ephemeral", state: "unlocked" });
      return { profileID, unlocked: true };
    },
    lockProfile(profileID) {
      unlockedProfiles.delete(profileID);
      logger.record({ event: "profile_locked", code: "profile_locked", kind: "profile", mode: "ephemeral", state: "locked" });
    },
    async inspectHealth() {
      return { mode: "ephemeral", state: storeState, recordCount: records.size, quotaBytes: null, usageBytes: null, recovery: null };
    },
    async exportEncryptedBackup() {
      throw new TemplateStoreError("backup_unavailable", "Encrypted backup is unavailable for an ephemeral store.");
    },
    async restoreEncryptedBackup() {
      throw new TemplateStoreError("backup_unavailable", "Encrypted backup is unavailable for an ephemeral store.");
    },
    close() {
      records.clear();
      unlockedProfiles.clear();
      logger.record({ event: "store_closed", code: "store_closed", mode: "ephemeral", state: "closed" });
    },
    async deleteStore() {
      records.clear();
      unlockedProfiles.clear();
      storeState = "deleted";
      logger.record({ event: "store_deleted", code: "store_delete_ok", mode: "ephemeral", state: storeState });
    },
    async put(kind, id, value) {
      validateRecord(kind, value);
      if (storeState !== "unlocked") throw new TemplateStoreError("store_locked", "Unlock the local template store before accessing records.");
      records.set(`${kind}:${id}`, structuredClone(value));
      if (isProfileKind(kind)) unlockedProfiles.add(id);
      logger.record({ event: "record_written", code: "write_ok", kind, mode: "ephemeral", state: storeState });
      return { kind, id };
    },
    async get(kind, id) {
      assertKind(kind);
      if (storeState !== "unlocked") throw new TemplateStoreError("store_locked", "Unlock the local template store before accessing records.");
      if (isProfileKind(kind) && !unlockedProfiles.has(id)) throw new TemplateStoreError("profile_locked", "Unlock this profile before accessing its values.");
      const value = records.get(`${kind}:${id}`);
      return value ? structuredClone(value) : null;
    },
    async remove(kind, id) {
      assertKind(kind);
      records.delete(`${kind}:${id}`);
      if (isProfileKind(kind)) unlockedProfiles.delete(id);
      logger.record({ event: "record_deleted", code: "delete_ok", kind, mode: "ephemeral", state: storeState });
    },
    async list(kind) {
      assertKind(kind);
      return [...records.keys()]
        .filter((key) => key.startsWith(`${kind}:`))
        .map((key) => ({ kind, id: key.slice(kind.length + 1) }));
    },
    async saveTemplateRevision(revision) {
      validateTemplateContract(revision);
      const templateID = revision.payload.templateID;
      const current = records.get(`templateHistory:${templateID}`);
      const history = current ? appendTemplateRevision(current, revision) : { templateID, revisions: [revision] };
      validateTemplateHistory(history);
      records.set(`templateHistory:${templateID}`, structuredClone(history));
      return structuredClone(history);
    },
    async getTemplateHistory(templateID) {
      const history = records.get(`templateHistory:${templateID}`);
      return history ? structuredClone(history) : null;
    },
    async exportTemplateHistory(templateID) {
      const history = records.get(`templateHistory:${templateID}`);
      if (!history) throw new TemplateStoreError("template_not_found", "The requested template was not found.");
      return exportTemplateHistoryContract(history);
    },
    async importTemplateHistory(envelope, { replace = false } = {}) {
      const history = importTemplateHistoryContract(envelope);
      const key = `templateHistory:${history.templateID}`;
      if (records.has(key) && !replace) throw new TemplateStoreError("template_exists", "The template already exists. Replace it explicitly to import over it.");
      records.set(key, structuredClone(history));
      return structuredClone(history);
    },
    async saveLearningEvent(event) {
      if (!event || typeof event.templateID !== "string" || typeof event.id !== "string") throw new TemplateStoreError("invalid_learning_event", "Learning event identity is invalid.");
      const key = `learningEvent:${event.templateID}`;
      const current = records.get(key);
      const events = current?.events || [];
      if (events.some((entry) => entry.id === event.id)) throw new TemplateStoreError("duplicate_learning_event", "Learning event already exists.");
      const journal = { templateID: event.templateID, events: [...events, structuredClone(event)] };
      records.set(key, structuredClone(journal));
      return structuredClone(journal);
    },
    async getLearningEvents(templateID) {
      return structuredClone(records.get(`learningEvent:${templateID}`)?.events || []);
    },
    async deleteLearningEvents(templateID) {
      records.delete(`learningEvent:${templateID}`);
    },
    async deleteTemplate(templateID) {
      records.delete(`templateHistory:${templateID}`);
      records.delete(`template:${templateID}`);
    },
    async saveProfileRevision(revision) {
      validateProfileContract(revision);
      const profileID = revision.payload.profileID;
      const current = records.get(`profileHistory:${profileID}`);
      const history = current
        ? appendProfileRevision(current, revision)
        : { profileID, revisions: [revision] };
      validateProfileRecord("profileHistory", history);
      records.set(`profileHistory:${profileID}`, structuredClone(history));
      unlockedProfiles.add(profileID);
      return structuredClone(history);
    },
    async getProfileHistory(profileID) {
      const history = records.get(`profileHistory:${profileID}`);
      if (!history) return null;
      if (!unlockedProfiles.has(profileID)) throw new TemplateStoreError("profile_locked", "Unlock this profile before accessing its values.");
      return history ? structuredClone(history) : null;
    },
    async deleteProfile(profileID) {
      records.delete(`profileHistory:${profileID}`);
      records.delete(`profile:${profileID}`);
      unlockedProfiles.delete(profileID);
    }
  };
  Object.defineProperty(api, "isUnlocked", { enumerable: true, get: () => storeState === "unlocked" });
  Object.defineProperty(api, "logger", { enumerable: true, value: logger });
  return Object.freeze(api);
}

/**
 * OPFS-backed encrypted store. OPFS is useful for larger local histories and
 * explicit backup files, but it is still origin-private and evictable. The
 * adapter therefore keeps the same unlock, health, deletion, and encrypted
 * backup semantics as IndexedDB instead of presenting OPFS as a backup.
 */
export function createEncryptedOPFSTemplateStore({
  fileName = "pdf-editor-template-store-v1.json",
  passphrase = null,
  logger = createZeroContentLogger()
} = {}) {
  let rootPromise;
  let storeKey = null;
  let storeState = "locked";
  const unlockedProfiles = new Map();
  const getRoot = async () => {
    if (!globalThis.navigator?.storage?.getDirectory) {
      throw new TemplateStoreError("opfs_unavailable", "The browser does not expose the Origin Private File System.");
    }
    return rootPromise ||= navigator.storage.getDirectory();
  };
  async function readEnvelope() {
    try {
      const root = await getRoot();
      const handle = await root.getFileHandle(fileName);
      return JSON.parse(await (await handle.getFile()).text());
    } catch (error) {
      if (error?.name === "NotFoundError") return null;
      if (error instanceof TemplateStoreError) throw error;
      throw new TemplateStoreError("opfs_read_failed", "The encrypted OPFS store could not be read.");
    }
  }
  async function writeEnvelope(envelope) {
    const root = await getRoot();
    const handle = await root.getFileHandle(fileName, { create: true });
    const writable = await handle.createWritable();
    try {
      await writable.write(JSON.stringify(envelope));
      await writable.close();
    } catch (error) {
      await writable.abort?.();
      throw new TemplateStoreError("opfs_write_failed", "The encrypted OPFS store could not be written.");
    }
  }
  async function unlock(providedPassphrase = passphrase) {
    if (storeKey) return true;
    requirePassphrase(providedPassphrase);
    const existing = await readEnvelope();
    if (!existing) {
      const salt = crypto.getRandomValues(new Uint8Array(16));
      storeKey = await deriveKey(providedPassphrase, salt);
      const meta = await encryptJSON(storeKey, {
        contractName: "pdf-editor.template-opfs-meta",
        version: { major: 1, minor: 0 },
        storeID: crypto.randomUUID(),
        createdAt: new Date().toISOString()
      });
      await writeEnvelope({ mode: "opfs-aes-gcm", version: STORE_VERSION, salt: bytesToBase64(salt), meta, records: [] });
      storeState = "unlocked";
      logger.record({ event: "store_unlocked", code: "store_initialized", mode: "opfs-aes-gcm", state: storeState });
      return true;
    }
    try {
      const key = await deriveKey(providedPassphrase, base64ToBytes(existing.salt));
      const meta = await decryptJSON(key, existing.meta);
      if (meta.contractName !== "pdf-editor.template-opfs-meta" || existing.version !== STORE_VERSION) throw new Error("metadata");
      storeKey = key;
      storeState = "unlocked";
      logger.record({ event: "store_unlocked", code: "store_authenticated", mode: "opfs-aes-gcm", state: storeState });
      return true;
    } catch {
      storeState = "locked";
      logger.record({ event: "store_unlock_failed", code: "unlock_failed", mode: "opfs-aes-gcm", state: storeState });
      throw new TemplateStoreError("unlock_failed", "The encrypted OPFS store passphrase was not accepted.");
    }
  }
  async function requireUnlocked(options = {}) {
    if (!storeKey) await unlock(options.storePassphrase);
    if (!storeKey) throw new TemplateStoreError("store_locked", "Unlock the encrypted OPFS store first.");
  }
  async function readRecords(options = {}) {
    await requireUnlocked(options);
    const envelope = await readEnvelope();
    if (!envelope) throw new TemplateStoreError("store_evicted", "The encrypted OPFS store file is missing.");
    const records = [];
    const opaqueRecords = [];
    for (const record of envelope.records || []) {
      const value = await decryptJSON(storeKey, record);
      if (isProfileKind(value.kind)) {
        const profileEnvelope = value.profileEnvelope;
        const profileKey = options.profilePassphrase
          ? await deriveKey(options.profilePassphrase, base64ToBytes(profileEnvelope.profileSalt), "profile")
          : unlockedProfiles.get(value.id);
        if (!profileKey) {
          if (options.allowLockedProfiles) {
            opaqueRecords.push(record);
            continue;
          }
          throw new TemplateStoreError("profile_locked", "Unlock this profile before accessing its values.");
        }
        const profile = await decryptJSON(profileKey, { iv: profileEnvelope.profileIV, ciphertext: profileEnvelope.profileCiphertext });
        validateRecord(value.kind, profile);
        records.push({ kind: value.kind, id: value.id, value: profile });
        unlockedProfiles.set(value.id, profileKey);
      } else {
        validateRecord(value.kind, value.value);
        records.push(value);
      }
    }
    return { envelope, records, opaqueRecords };
  }
  async function writeRecords(records, options = {}, opaqueRecords = []) {
    await requireUnlocked(options);
    const existing = await readEnvelope();
    const encryptedRecords = [];
    for (const record of records) {
      let value = record.value;
      if (isProfileKind(record.kind)) {
        requirePassphrase(options.profilePassphrase, "profile");
        const salt = crypto.getRandomValues(new Uint8Array(PROFILE_SALT_BYTES));
        const profileKey = await deriveKey(options.profilePassphrase, salt, "profile");
        const profileCipher = await encryptJSON(profileKey, value);
        value = {
          kind: record.kind,
          id: record.id,
          profileEnvelope: {
            profileSchemaVersion: 1,
            profileSalt: bytesToBase64(salt),
            profileIV: profileCipher.iv,
            profileCiphertext: profileCipher.ciphertext
          }
        };
        unlockedProfiles.set(record.id, profileKey);
      } else {
        value = { kind: record.kind, id: record.id, value };
      }
      encryptedRecords.push(await encryptJSON(storeKey, value));
    }
    await writeEnvelope({ ...existing, records: [...encryptedRecords, ...opaqueRecords], updatedAt: new Date().toISOString() });
  }
  async function put(kind, id, value, options = {}) {
    validateRecord(kind, value);
    const { records, opaqueRecords } = await readRecords({ ...options, allowLockedProfiles: true });
    const next = records.filter((record) => !(record.kind === kind && record.id === id));
    next.push({ kind, id, value: structuredClone(value) });
    await writeRecords(next, options, opaqueRecords.filter((record) => record.id !== id || !isProfileKind(kind)));
    logger.record({ event: "record_written", code: "write_ok", kind, mode: "opfs-aes-gcm", state: "unlocked" });
    return { kind, id };
  }
  async function get(kind, id, options = {}) {
    assertKind(kind);
    const { records } = await readRecords({ ...options, allowLockedProfiles: !isProfileKind(kind) });
    return structuredClone(records.find((record) => record.kind === kind && record.id === id)?.value || null);
  }
  async function remove(kind, id, options = {}) {
    assertKind(kind);
    const { records, opaqueRecords } = await readRecords({ ...options, allowLockedProfiles: true });
    await writeRecords(
      records.filter((record) => !(record.kind === kind && record.id === id)),
      options,
      opaqueRecords.filter((record) => record.id !== id || !isProfileKind(kind)));
    unlockedProfiles.delete(id);
    logger.record({ event: "record_deleted", code: "delete_ok", kind, mode: "opfs-aes-gcm", state: "unlocked" });
  }
  async function list(kind, options = {}) {
    assertKind(kind);
    const { records, opaqueRecords } = await readRecords({ ...options, allowLockedProfiles: true });
    return [
      ...records.filter((record) => record.kind === kind).map(({ kind: recordKind, id }) => ({ kind: recordKind, id })),
      ...opaqueRecords.filter((record) => record.kind === kind).map(({ kind: recordKind, id }) => ({ kind: recordKind, id }))
    ];
  }
  async function saveTemplateRevision(revision, options = {}) {
    validateTemplateContract(revision);
    const id = revision.payload.templateID;
    const current = await get("templateHistory", id, options);
    const history = current ? appendTemplateRevision(current, revision) : { templateID: id, revisions: [revision] };
    validateTemplateHistory(history);
    await put("templateHistory", id, history, options);
    return structuredClone(history);
  }
  async function exportTemplateHistory(templateID, options = {}) {
    const history = await get("templateHistory", templateID, options);
    if (!history) throw new TemplateStoreError("template_not_found", "The requested template was not found.");
    return exportTemplateHistoryContract(history);
  }
  async function importTemplateHistory(envelope, { storePassphrase = passphrase, replace = false } = {}) {
    const history = importTemplateHistoryContract(envelope);
    const existing = await get("templateHistory", history.templateID, { storePassphrase });
    if (existing && !replace) throw new TemplateStoreError("template_exists", "The template already exists. Replace it explicitly to import over it.");
    await put("templateHistory", history.templateID, history, { storePassphrase });
    return structuredClone(history);
  }
  async function saveLearningEvent(event, options = {}) {
    if (!event || typeof event.templateID !== "string" || typeof event.id !== "string") {
      throw new TemplateStoreError("invalid_learning_event", "Learning event identity is invalid.");
    }
    const current = await get("learningEvent", event.templateID, options);
    const events = current?.events || [];
    if (events.some((entry) => entry.id === event.id)) throw new TemplateStoreError("duplicate_learning_event", "Learning event already exists.");
    const journal = { templateID: event.templateID, events: [...events, structuredClone(event)] };
    await put("learningEvent", event.templateID, journal, options);
    return structuredClone(journal);
  }
  async function getLearningEvents(templateID, options = {}) {
    return (await get("learningEvent", templateID, options))?.events || [];
  }
  async function deleteLearningEvents(templateID, options = {}) {
    await remove("learningEvent", templateID, options);
  }
  async function saveProfileRevision(revision, options = {}) {
    validateProfileContract(revision);
    const id = revision.payload.profileID;
    const current = await get("profileHistory", id, options);
    const history = current ? appendProfileRevision(current, revision) : { profileID: id, revisions: [revision] };
    validateProfileRecord("profileHistory", history);
    await put("profileHistory", id, history, options);
    return structuredClone(history);
  }
  async function deleteStore() {
    try {
      const root = await getRoot();
      await root.removeEntry(fileName);
    } catch (error) {
      if (error?.name !== "NotFoundError") throw new TemplateStoreError("store_delete_failed", "Encrypted OPFS store deletion failed.");
    }
    storeKey = null;
    storeState = "deleted";
    unlockedProfiles.clear();
    logger.record({ event: "store_deleted", code: "store_delete_ok", mode: "opfs-aes-gcm", state: storeState });
  }
  async function exportEncryptedBackup() {
    await requireUnlocked();
    const envelope = await readEnvelope();
    const backup = {
      contractName: BACKUP_CONTRACT_NAME,
      version: { ...BACKUP_VERSION },
      storeVersion: STORE_VERSION,
      exportedAt: new Date().toISOString(),
      metaRecord: { salt: envelope.salt, meta: envelope.meta },
      records: envelope.records || []
    };
    if (!backup.metaRecord?.salt || !backup.metaRecord?.meta || !Array.isArray(backup.records)) {
      throw new TemplateStoreError("backup_invalid", "Encrypted OPFS backup is invalid.");
    }
    logger.record({ event: "backup_exported", code: "backup_export_ok", mode: "opfs-aes-gcm", state: "unlocked", count: backup.records.length });
    return structuredClone(backup);
  }
  async function restoreEncryptedBackup(backup, { storePassphrase = passphrase } = {}) {
    if (!backup || backup.contractName !== BACKUP_CONTRACT_NAME || backup.version?.major !== BACKUP_VERSION.major
      || !backup.metaRecord?.salt || !backup.metaRecord?.meta || !Array.isArray(backup.records)) {
      throw new TemplateStoreError("backup_invalid", "Encrypted OPFS backup is invalid.");
    }
    requirePassphrase(storePassphrase);
    await writeEnvelope({
      mode: "opfs-aes-gcm",
      version: STORE_VERSION,
      salt: backup.metaRecord.salt,
      meta: backup.metaRecord.meta,
      records: backup.records || [],
      updatedAt: new Date().toISOString()
    });
    storeKey = null;
    await unlock(storePassphrase);
    logger.record({ event: "backup_restored", code: "backup_restore_ok", mode: "opfs-aes-gcm", state: "unlocked", count: backup.records.length });
    return inspectHealth();
  }
  const api = {
    mode: "opfs-aes-gcm",
    version: STORE_VERSION,
    unlock,
    lock() { storeKey = null; storeState = "locked"; unlockedProfiles.clear(); logger.record({ event: "store_locked", code: "store_locked", mode: "opfs-aes-gcm", state: storeState }); },
    async unlockProfile(profileID, profilePassphrase, options = {}) {
      const profile = await get("profile", profileID, { ...options, profilePassphrase })
        || await get("profileHistory", profileID, { ...options, profilePassphrase });
      if (!profile) throw new TemplateStoreError("profile_not_found", "The requested local profile was not found.");
      return { profileID, unlocked: true };
    },
    lockProfile(profileID) { unlockedProfiles.delete(profileID); logger.record({ event: "profile_locked", code: "profile_locked", kind: "profile", mode: "opfs-aes-gcm", state: "locked" }); },
    async inspectHealth() { const { records, opaqueRecords } = await readRecords({ allowLockedProfiles: true }); return { mode: "opfs-aes-gcm", state: storeState, recordCount: records.length + opaqueRecords.length, quotaBytes: null, usageBytes: null, recovery: "exportEncryptedBackup" }; },
    exportEncryptedBackup,
    restoreEncryptedBackup,
    async put(kind, id, value, options) { return put(kind, id, value, options); },
    async get(kind, id, options) { return get(kind, id, options); },
    async remove(kind, id, options) { return remove(kind, id, options); },
    async list(kind, options) { return list(kind, options); },
    async saveTemplateRevision(revision, options) { return saveTemplateRevision(revision, options); },
    async exportTemplateHistory(id, options) { return exportTemplateHistory(id, options); },
    async importTemplateHistory(envelope, options) { return importTemplateHistory(envelope, options); },
    async saveLearningEvent(event, options) { return saveLearningEvent(event, options); },
    async getLearningEvents(id, options) { return getLearningEvents(id, options); },
    async deleteLearningEvents(id, options) { return deleteLearningEvents(id, options); },
    async getTemplateHistory(id, options) { return get("templateHistory", id, options); },
    async deleteTemplate(id, options) { await remove("templateHistory", id, options); await remove("template", id, options); await deleteLearningEvents(id, options); },
    async saveProfileRevision(revision, options) { return saveProfileRevision(revision, options); },
    async getProfileHistory(id, options) { return get("profileHistory", id, options); },
    async deleteProfile(id, options) { await remove("profileHistory", id, options); await remove("profile", id, options); },
    deleteStore
  };
  Object.defineProperty(api, "isUnlocked", { enumerable: true, get: () => Boolean(storeKey) });
  Object.defineProperty(api, "logger", { enumerable: true, value: logger });
  return Object.freeze(api);
}

export { BACKUP_CONTRACT_NAME, BACKUP_VERSION, STORE_VERSION };
