/**
 * Framework-neutral product surface contract.
 *
 * This module deliberately contains no DOM or provider implementation. React,
 * the current browser entry, and a future native/web bridge can all consume
 * the same five-mode model and capability-state vocabulary.
 */

export const PRODUCT_MODES = Object.freeze([
  Object.freeze({
    id: "reader",
    label: "Reader",
    shortLabel: "Read",
    description: "Navigate, search, and inspect the source document.",
    defaultCapability: "available"
  }),
  Object.freeze({
    id: "understand",
    label: "Understand",
    shortLabel: "Map",
    description: "Review document structure, evidence, and suggested regions.",
    defaultCapability: "partial"
  }),
  Object.freeze({
    id: "complete",
    label: "Complete",
    shortLabel: "Fill",
    description: "Confirm fields, place content, and build reversible operations.",
    defaultCapability: "partial"
  }),
  Object.freeze({
    id: "organize",
    label: "Organize",
    shortLabel: "Arrange",
    description: "Plan page, template, and repeatable workflow operations.",
    defaultCapability: "reader_only"
  }),
  Object.freeze({
    id: "review",
    label: "Review",
    shortLabel: "Prove",
    description: "Validate changes, preserve lineage, and export a new copy.",
    defaultCapability: "partial"
  })
]);

export const CAPABILITY_STATES = Object.freeze([
  "available",
  "loading",
  "partial",
  "reader_only",
  "blocked",
  "failed",
  "validated"
]);

const MODE_IDS = new Set(PRODUCT_MODES.map((mode) => mode.id));
const CAPABILITY_STATE_SET = new Set(CAPABILITY_STATES);

function assertModeID(modeID) {
  if (!MODE_IDS.has(modeID)) {
    throw new RangeError(`Unknown PDF Editor mode: ${modeID}`);
  }
}

function assertCapabilityState(state) {
  if (!CAPABILITY_STATE_SET.has(state)) {
    throw new RangeError(`Unknown PDF Editor capability state: ${state}`);
  }
}

export function getProductMode(modeID) {
  assertModeID(modeID);
  return PRODUCT_MODES.find((mode) => mode.id === modeID);
}

export function createProductSurfaceState() {
  return {
    activeMode: "reader",
    capabilities: Object.fromEntries(
      PRODUCT_MODES.map((mode) => [mode.id, mode.defaultCapability])
    ),
    modeHistory: ["reader"]
  };
}

export function selectProductMode(state, modeID) {
  assertModeID(modeID);
  if (state.activeMode === modeID) return state;
  return {
    ...state,
    activeMode: modeID,
    modeHistory: [...state.modeHistory, modeID]
  };
}

export function setModeCapability(state, modeID, capabilityState) {
  assertModeID(modeID);
  assertCapabilityState(capabilityState);
  return {
    ...state,
    capabilities: {
      ...state.capabilities,
      [modeID]: capabilityState
    }
  };
}

export function getModeCapability(state, modeID) {
  assertModeID(modeID);
  return state.capabilities[modeID];
}
