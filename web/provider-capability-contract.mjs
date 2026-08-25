const HEX64 = /^[0-9a-f]{64}$/i;
const CONTRACT_VERSION = Object.freeze({ major: 1, minor: 0 });

export const PROVIDER_INSTALL_STATES = Object.freeze([
  "discovered",
  "installing",
  "installed",
  "probing",
  "measured",
  "enabled",
  "revoked",
  "quarantined",
  "removed"
]);

export const CAPABILITY_STATES = Object.freeze([
  "declared",
  "unavailable",
  "installedUnmeasured",
  "measuredPartial",
  "enabled",
  "revoked",
  "quarantined",
  "expired"
]);

const ENABLED_STATES = new Set(["enabled"]);

function fail(message) {
  throw new TypeError(message);
}

function requireString(value, path) {
  if (typeof value !== "string" || value.length === 0) fail(`${path} must be a non-empty string`);
}

function requireBoolean(value, path) {
  if (typeof value !== "boolean") fail(`${path} must be boolean`);
}

function requireHex(value, path) {
  if (!HEX64.test(value)) fail(`${path} must be a 64-character hex digest`);
}

function requireEnum(value, values, path) {
  if (!values.includes(value)) fail(`${path} has unsupported value ${String(value)}`);
}

function validateVersion(version, path) {
  if (!version || !Number.isInteger(version.major) || !Number.isInteger(version.minor)) {
    fail(`${path} must contain integer major and minor`);
  }
}

function validateLimits(limits, path) {
  if (!limits || !Number.isInteger(limits.maxBytes) || limits.maxBytes < 0) fail(`${path}.maxBytes must be a non-negative integer`);
  if (!Number.isInteger(limits.maxPages) || limits.maxPages < 0) fail(`${path}.maxPages must be a non-negative integer`);
  requireBoolean(limits.supportsEncrypted, `${path}.supportsEncrypted`);
  requireBoolean(limits.supportsScanned, `${path}.supportsScanned`);
}

function validateLicense(license, path) {
  requireString(license.name, `${path}.name`);
  requireString(license.status, `${path}.status`);
  requireEnum(license.status, ["approved", "reviewRequired", "rejected"], `${path}.status`);
}

function validateMeasurement(measurement, path) {
  requireString(measurement.measurementID, `${path}.measurementID`);
  requireString(measurement.capabilityID, `${path}.capabilityID`);
  requireHex(measurement.artifactDigest, `${path}.artifactDigest`);
  requireHex(measurement.corpusDigest, `${path}.corpusDigest`);
  requireHex(measurement.reportDigest, `${path}.reportDigest`);
  requireEnum(measurement.status, ["passed", "partial", "failed"], `${path}.status`);
  requireEnum(measurement.evidenceTier, ["T1", "T2", "T3", "T4", "T5"], `${path}.evidenceTier`);
  requireEnum(measurement.sensitivity, ["S0", "S1", "S2", "S3"], `${path}.sensitivity`);
  if (!Array.isArray(measurement.gates) || measurement.gates.some((gate) => typeof gate !== "string" || gate.length === 0)) {
    fail(`${path}.gates must be a non-empty-string array`);
  }
}

function validateCapability(capability, path) {
  requireString(capability.capabilityID, `${path}.capabilityID`);
  requireEnum(capability.state, CAPABILITY_STATES, `${path}.state`);
  validateLimits(capability.limits, `${path}.limits`);
  if (!Array.isArray(capability.measurementIDs)) fail(`${path}.measurementIDs must be an array`);
  if (capability.state === "enabled" && capability.measurementIDs.length === 0) {
    fail(`${path} enabled capability requires a measurement reference`);
  }
}

export function validateProviderManifest(manifest) {
  if (!manifest || manifest.contract !== "pdf-editor.provider-capability") fail("manifest.contract must be pdf-editor.provider-capability");
  validateVersion(manifest.version, "manifest.version");
  requireString(manifest.providerID, "manifest.providerID");
  requireString(manifest.engineFamily, "manifest.engineFamily");
  requireString(manifest.providerVersion, "manifest.providerVersion");
  requireString(manifest.runtimeKind, "manifest.runtimeKind");
  requireHex(manifest.artifactDigest, "manifest.artifactDigest");
  requireEnum(manifest.installState, PROVIDER_INSTALL_STATES, "manifest.installState");
  validateLicense(manifest.license, "manifest.license");
  if (!Array.isArray(manifest.capabilities)) fail("manifest.capabilities must be an array");
  const capabilityIDs = new Set();
  manifest.capabilities.forEach((capability, index) => {
    validateCapability(capability, `manifest.capabilities[${index}]`);
    if (capabilityIDs.has(capability.capabilityID)) fail(`${manifest.providerID} has duplicate capability ${capability.capabilityID}`);
    capabilityIDs.add(capability.capabilityID);
  });
  if (!Array.isArray(manifest.measurements)) fail("manifest.measurements must be an array");
  manifest.measurements.forEach((measurement, index) => validateMeasurement(measurement, `manifest.measurements[${index}]`));
  const measurementIDs = new Set();
  for (const measurement of manifest.measurements) {
    if (measurementIDs.has(measurement.measurementID)) fail(`${manifest.providerID} has duplicate measurement ${measurement.measurementID}`);
    measurementIDs.add(measurement.measurementID);
  }
  if (!Array.isArray(manifest.revocations)) fail("manifest.revocations must be an array");
  for (const [index, revocation] of manifest.revocations.entries()) {
    requireString(revocation.revocationID, `manifest.revocations[${index}].revocationID`);
    requireString(revocation.reasonCode, `manifest.revocations[${index}].reasonCode`);
    requireString(revocation.effectiveAt, `manifest.revocations[${index}].effectiveAt`);
  }
  const measurements = new Map(manifest.measurements.map((measurement) => [measurement.measurementID, measurement]));
  for (const capability of manifest.capabilities) {
    for (const measurementID of capability.measurementIDs) {
      const measurement = measurements.get(measurementID);
      if (!measurement) fail(`${manifest.providerID}.${capability.capabilityID} references missing measurement ${measurementID}`);
      if (measurement.capabilityID !== capability.capabilityID || measurement.artifactDigest !== manifest.artifactDigest) {
        fail(`${manifest.providerID}.${capability.capabilityID} has a mismatched measurement binding`);
      }
    }
  }
  return manifest;
}

export function validateRegistry(registry) {
  if (!registry || registry.contract !== "pdf-editor.provider-capability-registry") fail("registry.contract is invalid");
  validateVersion(registry.version, "registry.version");
  if (!Array.isArray(registry.providers)) fail("registry.providers must be an array");
  const IDs = new Set();
  registry.providers.forEach((provider) => {
    validateProviderManifest(provider);
    if (IDs.has(provider.providerID)) fail(`duplicate providerID ${provider.providerID}`);
    IDs.add(provider.providerID);
  });
  return registry;
}

function sourceFits(source, limits) {
  return source.byteCount <= limits.maxBytes &&
    source.pageCount <= limits.maxPages &&
    (!source.isEncrypted || limits.supportsEncrypted) &&
    (!source.isScanned || limits.supportsScanned);
}

export function negotiateCapability(registry, request) {
  validateRegistry(registry);
  if (!request || request.contract !== "pdf-editor.provider-capability-request") fail("request.contract is invalid");
  validateVersion(request.version, "request.version");
  requireString(request.capability, "request.capability");
  if (!Array.isArray(request.operationKinds)) fail("request.operationKinds must be an array");
  if (!request.source || !Number.isInteger(request.source.byteCount) || !Number.isInteger(request.source.pageCount)) fail("request.source must contain byteCount and pageCount");
  if (!request.policy) fail("request.policy is required");
  requireBoolean(request.policy.localOnly, "request.policy.localOnly");
  requireBoolean(request.policy.allowExperimental, "request.policy.allowExperimental");
  requireEnum(request.policy.minimumState, ["enabled", "measuredPartial", "installedUnmeasured"], "request.policy.minimumState");
  const preferred = new Map();
  for (const [index, id] of (request.policy.preferredProviderIDs || []).entries()) {
    if (preferred.has(id)) fail(`request.policy.preferredProviderIDs contains duplicate ${id}`);
    preferred.set(id, index);
  }
  const eligible = [];
  const rejectionReasons = new Set();
  for (const provider of registry.providers) {
    const capability = provider.capabilities.find((item) => item.capabilityID === request.capability);
    if (!capability) continue;
    if (!["enabled", "measured"].includes(provider.installState)) {
      rejectionReasons.add(`providerState:${provider.installState}`);
      continue;
    }
    if (provider.license.status !== "approved") {
      rejectionReasons.add("licenseUnapproved");
      continue;
    }
    if (["revoked", "quarantined", "expired", "unavailable"].includes(capability.state)) {
      rejectionReasons.add(`capabilityState:${capability.state}`);
      continue;
    }
    if (capability.state === "installedUnmeasured" && !request.policy.allowExperimental) {
      rejectionReasons.add("capabilityUnmeasured");
      continue;
    }
    if (request.policy.minimumState === "enabled" && capability.state !== "enabled") {
      rejectionReasons.add("capabilityBelowMinimumState");
      continue;
    }
    if (request.policy.minimumState === "measuredPartial" && !["enabled", "measuredPartial"].includes(capability.state)) {
      rejectionReasons.add("capabilityBelowMinimumState");
      continue;
    }
    if (!sourceFits(request.source, capability.limits)) {
      rejectionReasons.add("sourceOutsideProviderLimits");
      continue;
    }
    const measurements = provider.measurements.filter((measurement) => capability.measurementIDs.includes(measurement.measurementID) && measurement.status === "passed");
    if (capability.state === "enabled" && measurements.length === 0) {
      rejectionReasons.add("missingPassedMeasurement");
      continue;
    }
    if (provider.revocations.length > 0) {
      rejectionReasons.add("providerRevoked");
      continue;
    }
    eligible.push({ provider, capability, preferred: preferred.has(provider.providerID) ? preferred.get(provider.providerID) : Number.MAX_SAFE_INTEGER });
  }
  eligible.sort((a, b) => a.preferred - b.preferred || a.provider.providerID.localeCompare(b.provider.providerID));
  if (eligible.length === 0) {
    return {
      contract: "pdf-editor.provider-capability-decision",
      version: CONTRACT_VERSION,
      decision: "abstained",
      providerID: null,
      capability: request.capability,
      measurementID: null,
      fallbackProviderIDs: [],
      reasonCodes: [...rejectionReasons].sort().concat("noEligibleLocalProvider"),
      expiresAt: null
    };
  }
  const selected = eligible[0];
  return {
    contract: "pdf-editor.provider-capability-decision",
    version: CONTRACT_VERSION,
    decision: "selected",
    providerID: selected.provider.providerID,
    capability: request.capability,
    measurementID: selected.provider.measurements.find((measurement) => selected.capability.measurementIDs.includes(measurement.measurementID) && measurement.status === "passed")?.measurementID || null,
    fallbackProviderIDs: eligible.slice(1).map((item) => item.provider.providerID),
    reasonCodes: ["exactArtifactMeasured", "licenseApproved", "sourceWithinLimits", ...(request.policy.localOnly ? ["localOnly"] : [])],
    expiresAt: null
  };
}

export { CONTRACT_VERSION };
