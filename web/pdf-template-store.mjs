import { validateProfileContract, validateTemplateContract } from "./pdf-template-contract.mjs";

const STORE_VERSION = 2;
const BACKUP_CONTRACT_NAME = "pdf-editor.template-store-backup";
const BACKUP_VERSION = { major: 1, minor: 0 };
const META_KEY = "__meta__";
const PRESENCE_PREFIX = "pdf-editor-template-store-present:";
const PROFILE_SALT_BYTES = 16;

const RECORD_KINDS = new Set(["template", "profile", "learningEvent", "revisionPromotion"]);
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
  "store_delete_ok"
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
  if (output.mode !== undefined && !["indexeddb-aes-gcm", "ephemeral"].includes(output.mode)) delete output.mode;
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
  if (kind === "profile") validateProfileContract(value);
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
    if (kind === "profile") {
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
    if (record.kind !== "profile") {
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
    if (kind === "profile") unlockedProfiles.delete(id);
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

  async function unlock(providedPassphrase = passphrase) {
    return ensureUnlocked(providedPassphrase);
  }

  async function unlockProfile(profileID, profilePassphrase, options = {}) {
    requirePassphrase(profilePassphrase, "profile");
    const record = await rawGet(`profile:${profileID}`);
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
    list
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
      if (!records.has(`profile:${profileID}`)) throw new TemplateStoreError("profile_not_found", "The requested local profile was not found.");
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
      if (kind === "profile") unlockedProfiles.add(id);
      logger.record({ event: "record_written", code: "write_ok", kind, mode: "ephemeral", state: storeState });
      return { kind, id };
    },
    async get(kind, id) {
      assertKind(kind);
      if (storeState !== "unlocked") throw new TemplateStoreError("store_locked", "Unlock the local template store before accessing records.");
      if (kind === "profile" && !unlockedProfiles.has(id)) throw new TemplateStoreError("profile_locked", "Unlock this profile before accessing its values.");
      const value = records.get(`${kind}:${id}`);
      return value ? structuredClone(value) : null;
    },
    async remove(kind, id) {
      assertKind(kind);
      records.delete(`${kind}:${id}`);
      if (kind === "profile") unlockedProfiles.delete(id);
      logger.record({ event: "record_deleted", code: "delete_ok", kind, mode: "ephemeral", state: storeState });
    },
    async list(kind) {
      assertKind(kind);
      return [...records.keys()]
        .filter((key) => key.startsWith(`${kind}:`))
        .map((key) => ({ kind, id: key.slice(kind.length + 1) }));
    }
  };
  Object.defineProperty(api, "isUnlocked", { enumerable: true, get: () => storeState === "unlocked" });
  Object.defineProperty(api, "logger", { enumerable: true, value: logger });
  return Object.freeze(api);
}

export { BACKUP_CONTRACT_NAME, BACKUP_VERSION, STORE_VERSION };
