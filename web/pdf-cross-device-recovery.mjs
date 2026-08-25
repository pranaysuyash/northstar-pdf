export const CROSS_DEVICE_RECOVERY_CONTRACT = "pdf-editor.local-cross-device-recovery";

function assertOpaqueBackup(backup) {
  if (!backup || backup.contractName !== "pdf-editor.template-store-backup"
      || !Array.isArray(backup.records) || !backup.metaRecord) {
    throw new Error("invalid-encrypted-backup");
  }
}

function assertRecoveryEnvelope(recovery) {
  if (!recovery || recovery.contractName !== "pdf-editor.local-store-recovery"
      || typeof recovery.ciphertext !== "string" || typeof recovery.salt !== "string") {
    throw new Error("invalid-key-recovery-envelope");
  }
}

export function createCrossDeviceRecoveryBundle({ backup, recovery, storeKind = "template" } = {}) {
  if (!["template", "profile"].includes(storeKind)) throw new Error("invalid-store-kind");
  assertOpaqueBackup(backup);
  assertRecoveryEnvelope(recovery);
  return {
    contractName: CROSS_DEVICE_RECOVERY_CONTRACT,
    version: { major: 1, minor: 0 },
    storeKind,
    backup,
    recovery,
    createdAt: new Date().toISOString(),
    sourceRetention: "none",
    profileValues: "encrypted-records-only"
  };
}

export function validateCrossDeviceRecoveryBundle(bundle) {
  if (!bundle || bundle.contractName !== CROSS_DEVICE_RECOVERY_CONTRACT
      || bundle.version?.major !== 1 || !["template", "profile"].includes(bundle.storeKind)) {
    throw new Error("invalid-cross-device-recovery-bundle");
  }
  assertOpaqueBackup(bundle.backup);
  assertRecoveryEnvelope(bundle.recovery);
  return true;
}
