export const IHATEPDF_EXPERIMENT_LEDGER_VERSION = Object.freeze({ major: 1, minor: 0 });

const REQUIRED_EXPERIMENT_IDS = Object.freeze(["E-001", "E-002", "E-003", "E-004", "E-005", "E-006"]);
const REQUIRED_COORDINATE = Object.freeze({ unit: "points", origin: "lowerLeft", pageBox: "crop", rotationDegrees: 0 });

function sameJSON(left, right) {
  return JSON.stringify(left) === JSON.stringify(right);
}

export function validateIhatepdfExperimentLedger(ledger) {
  const errors = [];
  if (ledger?.ledgerName !== "pdf-editor.ihatepdf-experiment-ledger") errors.push("ledgerName");
  if (!sameJSON(ledger?.ledgerVersion, IHATEPDF_EXPERIMENT_LEDGER_VERSION)) errors.push("ledgerVersion");
  if (ledger?.truthStatus !== "proposed-experiment") errors.push("truthStatus");
  const entries = Array.isArray(ledger?.entries) ? ledger.entries : [];
  const cases = Array.isArray(ledger?.parityCases) ? ledger.parityCases : [];
  if (entries.length !== REQUIRED_EXPERIMENT_IDS.length) errors.push("entryCount");
  if (cases.length !== REQUIRED_EXPERIMENT_IDS.length) errors.push("caseCount");
  for (const id of REQUIRED_EXPERIMENT_IDS) {
    const entry = entries.find((candidate) => candidate.id === id);
    const parityCase = cases.find((candidate) => candidate.experimentID === id);
    if (!entry) {
      errors.push(`${id}.entryMissing`);
      continue;
    }
    if (!sameJSON(entry.version, IHATEPDF_EXPERIMENT_LEDGER_VERSION)) errors.push(`${id}.version`);
    if (entry.truthStatus !== "proposed-experiment") errors.push(`${id}.truthStatus`);
    if (entry.provenanceStatus !== "observed-public-claim-not-runtime-proof") errors.push(`${id}.provenanceStatus`);
    if (entry.licenseStatus !== "not-adopted-unverified") errors.push(`${id}.licenseStatus`);
    if (entry.runtimeEvidence?.tier !== 1 || entry.runtimeEvidence?.status !== "not-run") errors.push(`${id}.runtimeEvidence`);
    if (!entry.sourceFixture || !entry.operationKind || !entry.falsifier || !entry.rollback) errors.push(`${id}.evidenceFields`);
    if (!sameJSON(entry.coordinatePolicy, REQUIRED_COORDINATE)) errors.push(`${id}.coordinatePolicy`);
    if (!parityCase) {
      errors.push(`${id}.caseMissing`);
      continue;
    }
    if (!sameJSON(parityCase.coordinate, REQUIRED_COORDINATE)) errors.push(`${id}.caseCoordinate`);
    if (parityCase.operationKind !== entry.operationKind) errors.push(`${id}.operationKind`);
    if (parityCase.expected?.sourceBound !== true) errors.push(`${id}.sourceBinding`);
    if (parityCase.expected?.abstainIfUnsupported !== true) errors.push(`${id}.abstention`);
  }
  return { passed: errors.length === 0, errors };
}

export function projectBrowserIhatepdfParity({ ledger, sourceDigests = {} } = {}) {
  const validation = validateIhatepdfExperimentLedger(ledger);
  if (!validation.passed) throw new Error(`Invalid ihatepdf experiment ledger: ${validation.errors.join(", ")}`);
  return ledger.parityCases.map((parityCase) => {
    const entry = ledger.entries.find((candidate) => candidate.id === parityCase.experimentID);
    return {
      id: parityCase.id,
      experimentID: parityCase.experimentID,
      sourceFixture: parityCase.sourceFixture,
      sourceDigest: sourceDigests[parityCase.sourceFixture] || null,
      operationKind: parityCase.operationKind,
      coordinate: { ...parityCase.coordinate },
      executionState: parityCase.expected.executionState,
      sourceBound: parityCase.expected.sourceBound,
      reviewRequired: parityCase.expected.reviewRequired,
      abstainIfUnsupported: parityCase.expected.abstainIfUnsupported,
      privacyClass: parityCase.expected.privacyClass,
      validationKinds: [...parityCase.expected.validationKinds].sort(),
      ledgerVersion: { ...entry.version },
      semanticParity: {
        operationKind: entry.operationKind,
        coordinateSpace: { ...entry.coordinatePolicy },
        sourceFixture: entry.sourceFixture,
        reviewPolicy: { ...entry.reviewPolicy }
      }
    };
  });
}

export function runIhatepdfExperimentParity({ ledger, sourceDigests = {} } = {}) {
  const cases = projectBrowserIhatepdfParity({ ledger, sourceDigests });
  return {
    harness: "pdf-editor-browser-ihatepdf-experiment-parity",
    version: { ...IHATEPDF_EXPERIMENT_LEDGER_VERSION },
    ledgerName: ledger.ledgerName,
    entryCount: ledger.entries.length,
    caseCount: cases.length,
    passed: cases.length === REQUIRED_EXPERIMENT_IDS.length && cases.every((entry) => entry.sourceDigest),
    cases
  };
}
