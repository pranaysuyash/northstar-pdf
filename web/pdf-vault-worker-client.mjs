export function validateEncryptedBackupInWorker(backup) {
  if (typeof Worker !== "function") {
    if (!backup || !Array.isArray(backup.records) || !backup.metaRecord) throw new Error("invalid-encrypted-backup");
    return Promise.resolve({ valid: true, encryptedRecordCount: backup.records.length, serializedBytes: JSON.stringify(backup).length, plaintextInspected: false, worker: false });
  }
  return new Promise((resolve, reject) => {
    const id = crypto.randomUUID();
    const worker = new Worker(new URL("./pdf-vault-worker.mjs", import.meta.url), { type: "module" });
    const finish = () => worker.terminate();
    worker.onmessage = (event) => {
      if (event.data?.id !== id) return;
      finish();
      if (event.data.ok) resolve({ ...event.data.result, worker: true });
      else reject(new Error(event.data.error || "worker-validation-failed"));
    };
    worker.onerror = () => {
      finish();
      reject(new Error("worker-validation-failed"));
    };
    worker.postMessage({ id, task: "validate-encrypted-backup", payload: backup });
  });
}

