// This worker validates only encrypted backup structure. It deliberately has
// no vault passphrase, WebCrypto key, IndexedDB handle, or PDF parser.

function validateBackup(backup) {
  if (!backup || backup.contractName !== "pdf-editor.template-store-backup"
      || !Array.isArray(backup.records) || !backup.metaRecord
      || backup.records.some((record) => typeof record?.ciphertext !== "string")) {
    throw new Error("invalid-encrypted-backup");
  }
  return {
    valid: true,
    encryptedRecordCount: backup.records.length,
    serializedBytes: JSON.stringify(backup).length,
    plaintextInspected: false
  };
}

self.onmessage = (event) => {
  const { id, task, payload } = event.data || {};
  try {
    if (task !== "validate-encrypted-backup") throw new Error("unsupported-worker-task");
    self.postMessage({ id, ok: true, result: validateBackup(payload) });
  } catch (error) {
    self.postMessage({ id, ok: false, error: error.message || "worker-validation-failed" });
  }
};
