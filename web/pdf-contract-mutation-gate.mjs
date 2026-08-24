/**
 * Browser-side preflight for source-bound PDF mutations.
 *
 * PDF.js supplies the inspection facts and pdf-lib is the writer. This module
 * is deliberately independent of both runtimes so it can be exercised in
 * Node and in the browser before PDFDocument.load/save is reached.
 */

export const BROWSER_EXPORT_OPERATION_KINDS = Object.freeze([
  "nativeFieldValue",
  "overlayText"
]);

const VALIDATION_STATUSES = new Set([
  "passed",
  "warning",
  "failed",
  "skipped",
  "unknown"
]);

const VALIDATION_REPORT_STATUSES = new Set([
  "validated",
  "validatedWithWarnings",
  "failed"
]);

const EPSILON = 0.01;

export class ContractMutationError extends Error {
  constructor(issues) {
    const normalizedIssues = Array.isArray(issues) ? issues : [issues];
    const first = normalizedIssues[0] || {
      code: "invalidOperation",
      message: "The edit session failed browser contract preflight."
    };
    super(normalizedIssues.map((issue) => `[${issue.code}] ${issue.message}`).join(" "));
    this.name = "ContractMutationError";
    this.code = first.code;
    this.issues = normalizedIssues;
    this.operationIDs = normalizedIssues.flatMap((issue) => issue.operationIDs || []);
    this.readerCode = "invalid-operation";
  }
}

function issue(code, message, operationIDs = []) {
  return { code, message, operationIDs };
}

function finiteNumber(value) {
  return typeof value === "number" && Number.isFinite(value);
}

function normalizeRotation(value) {
  const rotation = Number(value || 0);
  return ((rotation % 360) + 360) % 360;
}

function rectEqual(left, right) {
  return left && right
    && ["x", "y", "width", "height"].every((key) =>
      finiteNumber(left[key]) && finiteNumber(right[key]) && Math.abs(left[key] - right[key]) <= EPSILON
    );
}

function coordinateSpaceEqual(actual, expectedRotation) {
  const space = actual?.coordinateSpace;
  return space?.unit === "points"
    && space?.origin === "lowerLeft"
    && space?.pageBox === "crop"
    && normalizeRotation(space.rotationDegrees) === normalizeRotation(expectedRotation);
}

function pageFactsByIndex(pageCoordinates) {
  const entries = Array.isArray(pageCoordinates) ? pageCoordinates : [];
  return new Map(entries.map((page) => [page.pageIndex, page]));
}

function validateValidationState(validation) {
  if (validation == null) return [];
  const issues = [];
  const reportStatus = validation.status;
  if (!VALIDATION_REPORT_STATUSES.has(reportStatus)) {
    issues.push(issue(
      "unknownValidationState",
      `Validation report has an unknown status: ${String(reportStatus)}.`
    ));
  }
  if (!Array.isArray(validation.checks)) {
    issues.push(issue(
      "unknownValidationState",
      "Validation report does not contain a checks array."
    ));
    return issues;
  }
  for (const check of validation.checks) {
    if (!VALIDATION_STATUSES.has(check?.status) || check.status === "unknown") {
      issues.push(issue(
        "unknownValidationState",
        `Validation check ${check?.kind || "<unknown>"} has an unknown status: ${String(check?.status)}.`,
        Array.isArray(check?.operationIDs) ? check.operationIDs : []
      ));
    }
  }
  return issues;
}

function validateOperation(operation, currentSourceDigest, pages) {
  const operationID = operation?.id || "<unknown>";
  const operationIDs = [operationID];
  const issues = [];
  if (!operation || typeof operation !== "object") {
    return [issue("invalidOperation", "An operation must be an object.", operationIDs)];
  }
  if (operation.sourceDigest !== currentSourceDigest) {
    issues.push(issue(
      "staleSourceDigest",
      `Operation ${operationID} is bound to a stale or mismatched source digest.`,
      operationIDs
    ));
  }
  if (!BROWSER_EXPORT_OPERATION_KINDS.includes(operation.kind)) {
    issues.push(issue(
      "unsupportedOperation",
      `Operation ${operationID} uses unsupported browser export kind ${String(operation.kind)}.`,
      operationIDs
    ));
  }
  if (operation.destructive === true || operation.reversible === false) {
    issues.push(issue(
      "destructiveOperation",
      `Operation ${operationID} is destructive or not reversible; browser export requires explicit provider policy.`,
      operationIDs
    ));
  }

  const page = pages.get(operation.pageIndex);
  if (!Number.isInteger(operation.pageIndex) || !page) {
    issues.push(issue(
      "coordinateMismatch",
      `Operation ${operationID} targets a page that is not present in the inspected page contract.`,
      operationIDs
    ));
    return issues;
  }

  const coordinate = operation.coordinate;
  if (!coordinate || !coordinate.rect) {
    issues.push(issue(
      "coordinateMismatch",
      `Operation ${operationID} has no page-space coordinate rectangle.`,
      operationIDs
    ));
    return issues;
  }
  if (coordinate.pageIndex !== operation.pageIndex) {
    issues.push(issue(
      "coordinateMismatch",
      `Operation ${operationID} coordinate page does not match the operation page.`,
      operationIDs
    ));
  }
  if (operation.bounds && !rectEqual(operation.bounds, coordinate.rect)) {
    issues.push(issue(
      "coordinateMismatch",
      `Operation ${operationID} bounds do not match its page-space coordinate.`,
      operationIDs
    ));
  }
  if (!operation.bounds && BROWSER_EXPORT_OPERATION_KINDS.includes(operation.kind)) {
    issues.push(issue(
      "coordinateMismatch",
      `Operation ${operationID} has no writer bounds.`,
      operationIDs
    ));
  }
  if (!coordinateSpaceEqual(coordinate, page.rotation)) {
    issues.push(issue(
      "coordinateMismatch",
      `Operation ${operationID} coordinate space does not match the inspected page space.`,
      operationIDs
    ));
  }
  if (!rectEqual(coordinate.rect, operation.bounds || coordinate.rect)) {
    issues.push(issue(
      "coordinateMismatch",
      `Operation ${operationID} contains a non-finite or invalid coordinate rectangle.`,
      operationIDs
    ));
  }
  return issues;
}

export function collectExportContractViolations({
  currentSourceDigest,
  operations = [],
  pageCoordinates = [],
  validation = null
} = {}) {
  const issues = [];
  if (typeof currentSourceDigest !== "string" || currentSourceDigest.length !== 64) {
    issues.push(issue("staleSourceDigest", "The current inspected source digest is missing or malformed."));
  }
  if (!Array.isArray(operations)) {
    issues.push(issue("invalidOperation", "The edit session operations value must be an array."));
  } else {
    const pages = pageFactsByIndex(pageCoordinates);
    for (const operation of operations) {
      issues.push(...validateOperation(operation, currentSourceDigest, pages));
    }
  }
  issues.push(...validateValidationState(validation));
  return issues;
}

export function assertExportableContract(options = {}) {
  const issues = collectExportContractViolations(options);
  if (issues.length) throw new ContractMutationError(issues);
  return {
    ok: true,
    operationIDs: (options.operations || []).map((operation) => operation.id).filter(Boolean)
  };
}

/**
 * The only writer seam. Preflight executes before the callback, allowing a
 * browser test to prove that rejected contracts never reach pdf-lib.
 */
export async function guardedPdfLibExport({
  currentSourceDigest,
  operations = [],
  pageCoordinates = [],
  validation = null,
  writer
} = {}) {
  assertExportableContract({ currentSourceDigest, operations, pageCoordinates, validation });
  if (typeof writer !== "function") {
    throw new TypeError("A PDF writer callback is required after contract preflight.");
  }
  return writer();
}
