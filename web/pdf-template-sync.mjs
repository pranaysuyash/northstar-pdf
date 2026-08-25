import { appendTemplateRevision, validateTemplateContract } from "./pdf-template-contract.mjs";

export const PDF_TEMPLATE_SYNC_CONTRACT = Object.freeze({
  contractName: "pdf-editor.template-sync",
  version: Object.freeze({ major: 1, minor: 0 }),
  payload: "client-encrypted-template-history-and-learning-events"
});

function requirePassphrase(passphrase) {
  if (typeof passphrase !== "string" || passphrase.length < 12) {
    throw new Error("A sync passphrase of at least 12 characters is required.");
  }
}

function bytesToBase64(bytes) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function base64ToBytes(value) {
  return Uint8Array.from(atob(value), (character) => character.charCodeAt(0));
}

async function deriveKey(passphrase, salt) {
  requirePassphrase(passphrase);
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

function rejectContent(value) {
  const text = JSON.stringify(value);
  if (text.includes("%PDF-") || text.includes('"profileValue"') || text.includes('"rawPDF"') || text.includes('"bytes"')) {
    throw new Error("Template sync cannot contain source bytes or profile values.");
  }
}

function validatePayload(payload) {
  if (!payload || typeof payload !== "object" || !payload.history?.templateID || !Array.isArray(payload.history.revisions)) {
    throw new Error("Template sync payload is invalid.");
  }
  let history = { templateID: payload.history.templateID, revisions: [] };
  for (const revision of payload.history.revisions) {
    validateTemplateContract(revision);
    history = appendTemplateRevision(history, revision);
  }
  for (const event of payload.learningEvents || []) {
    if (event.templateID !== history.templateID || typeof event.id !== "string" || event.status === "applied" && event.value) {
      throw new Error("Template sync learning event is invalid or contains value data.");
    }
  }
  rejectContent(payload);
  return { ...payload, history };
}

export async function encryptTemplateSyncEnvelope({ history, learningEvents = [], deviceID, generation = 0, passphrase }) {
  const payload = validatePayload({ history, learningEvents });
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const key = await deriveKey(passphrase, salt);
  const ciphertext = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv },
    key,
    new TextEncoder().encode(JSON.stringify(payload))
  );
  return {
    contractName: PDF_TEMPLATE_SYNC_CONTRACT.contractName,
    version: { ...PDF_TEMPLATE_SYNC_CONTRACT.version },
    algorithm: "PBKDF2-SHA256-150000+AES-256-GCM",
    deviceID: deviceID || "anonymous-local-device",
    generation,
    templateID: history.templateID,
    revisionIDs: history.revisions.map((revision) => revision.payload.revisionID),
    salt: bytesToBase64(salt),
    iv: bytesToBase64(iv),
    ciphertext: bytesToBase64(new Uint8Array(ciphertext))
  };
}

export async function decryptTemplateSyncEnvelope(envelope, { passphrase }) {
  if (!envelope || envelope.contractName !== PDF_TEMPLATE_SYNC_CONTRACT.contractName
      || envelope.version?.major !== PDF_TEMPLATE_SYNC_CONTRACT.version.major
      || typeof envelope.ciphertext !== "string") throw new Error("Unsupported template sync envelope.");
  requirePassphrase(passphrase);
  try {
    const key = await deriveKey(passphrase, base64ToBytes(envelope.salt));
    const plaintext = await crypto.subtle.decrypt(
      { name: "AES-GCM", iv: base64ToBytes(envelope.iv) },
      key,
      base64ToBytes(envelope.ciphertext)
    );
    return validatePayload(JSON.parse(new TextDecoder().decode(plaintext)));
  } catch {
    throw new Error("Template sync authentication failed.");
  }
}

export function mergeTemplateHistories(localHistory, incomingHistory) {
  if (localHistory.templateID !== incomingHistory.templateID) throw new Error("Template sync identity mismatch.");
  const byID = new Map();
  const conflicts = [];
  for (const revision of [...(localHistory.revisions || []), ...(incomingHistory.revisions || [])]) {
    validateTemplateContract(revision);
    const existing = byID.get(revision.payload.revisionID);
    if (existing && JSON.stringify(existing) !== JSON.stringify(revision)) {
      conflicts.push({ revisionID: revision.payload.revisionID, reason: "same revision ID has different content" });
    } else if (!existing) {
      byID.set(revision.payload.revisionID, revision);
    }
  }
  const all = [...byID.values()];
  const ids = new Set(all.map((revision) => revision.payload.revisionID));
  for (const revision of all) {
    const parent = revision.payload.parentRevisionID;
    if (parent && !ids.has(parent)) conflicts.push({ revisionID: revision.payload.revisionID, reason: "missing parent revision" });
  }
  if (conflicts.length) return { history: null, conflicts };
  const ordered = [];
  const remaining = new Map(all.map((revision) => [revision.payload.revisionID, revision]));
  while (remaining.size) {
    const ready = [...remaining.values()]
      .filter((revision) => !revision.payload.parentRevisionID || ordered.some((entry) => entry.payload.revisionID === revision.payload.parentRevisionID))
      .sort((left, right) => left.payload.revisionID.localeCompare(right.payload.revisionID));
    if (!ready.length) return { history: null, conflicts: [{ reason: "revision parent graph is cyclic" }] };
    for (const revision of ready) {
      ordered.push(revision);
      remaining.delete(revision.payload.revisionID);
    }
  }
  return { history: { templateID: localHistory.templateID, revisions: ordered }, conflicts: [] };
}
