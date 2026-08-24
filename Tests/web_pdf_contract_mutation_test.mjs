import assert from "node:assert/strict";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "/Users/pranay/.agents/skills/testing/playwright-skill/node_modules/playwright/index.mjs";

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const sourceRelativePath = "benchmark/results/public-sample-form.pdf";
const sourcePath = path.join(projectRoot, sourceRelativePath);
const baseURL = process.env.PDF_PROOF_BASE_URL || "http://127.0.0.1:4173/web/index.html";

const browser = await chromium.launch({ channel: "chrome", headless: true });
const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
const consoleErrors = [];
const pageErrors = [];
page.on("console", (message) => {
  if (message.type() === "error") consoleErrors.push(message.text());
});
page.on("pageerror", (error) => pageErrors.push(error.message));

function operationFor(snapshot, overrides = {}) {
  const pageContract = snapshot.coordinates.pages[0];
  const rect = {
    x: pageContract.region.rect.x + 12,
    y: pageContract.region.rect.y + 12,
    width: 120,
    height: 22
  };
  return {
    id: "browser-mutation-operation",
    pageIndex: 0,
    kind: "overlayText",
    value: "reviewed",
    bounds: rect,
    sourceDigest: snapshot.document.header.sourceDigest,
    coordinate: {
      pageIndex: 0,
      rect,
      coordinateSpace: { ...pageContract.region.coordinateSpace }
    },
    payload: { kind: "text", value: "reviewed" },
    reversible: true,
    destructive: false,
    ...overrides
  };
}

async function expectRejected(fixture, name, options, expectedCode) {
  const result = await page.evaluate(async ({ name, options, expectedCode }) => {
    let writerCalls = 0;
    let error = null;
    try {
      await window.__pdfEditorContractFixture.guardedPdfLibExport({
        ...options,
        writer: () => {
          writerCalls += 1;
          return "writer-called";
        }
      });
    } catch (caught) {
      error = {
        name: caught.name,
        code: caught.code,
        message: caught.message,
        issueCodes: (caught.issues || []).map((issue) => issue.code)
      };
    }
    return { name, expectedCode, writerCalls, error };
  }, { name, options, expectedCode });
  assert.equal(result.writerCalls, 0, `${name} must reject before the writer callback`);
  assert.ok(result.error, `${name} should throw a contract mutation error`);
  assert.equal(result.error.name, "ContractMutationError");
  assert.equal(result.error.code, expectedCode, `${name} should expose its stable error code`);
  assert.ok(result.error.issueCodes.includes(expectedCode), `${name} should retain the issue code`);
  return result;
}

async function expectMaterializerRejected(page, name, operation, validation, expectedCode) {
  const result = await page.evaluate(async ({ operation, validation }) => {
    const originalLoad = window.PDFLib.PDFDocument.load;
    let loadCalls = 0;
    window.PDFLib.PDFDocument.load = async (...args) => {
      loadCalls += 1;
      return originalLoad.apply(window.PDFLib.PDFDocument, args);
    };
    let error = null;
    try {
      await window.__pdfEditorContractFixture.runMaterializationProbe({
        operationsOverride: [operation],
        validationOverride: validation
      });
    } catch (caught) {
      error = { name: caught.name, code: caught.code };
    } finally {
      window.PDFLib.PDFDocument.load = originalLoad;
    }
    return { loadCalls, error };
  }, { operation, validation });
  assert.equal(result.loadCalls, 0, `${name} must reject before PDFDocument.load()`);
  assert.deepEqual(result.error, {
    name: "ContractMutationError",
    code: expectedCode
  }, `${name} should fail in the materializer with its contract code`);
  return result;
}

try {
  await page.goto(baseURL, { waitUntil: "networkidle" });
  await page.waitForFunction(
    () => Boolean(window.pdfjsLib && window.PDFLib && window.__pdfEditorContractFixture?.guardedPdfLibExport),
    undefined,
    { timeout: 30_000 }
  );
  await page.locator("#fileInput").setInputFiles(sourcePath);
  await page.waitForFunction(
    () => Boolean(window.__pdfEditorContractFixture.snapshot()?.document?.payload?.source?.sha256),
    undefined,
    { timeout: 30_000 }
  );

  const fixtureState = await page.evaluate(() => {
    const snapshot = window.__pdfEditorContractFixture.snapshot();
    return {
      sourceDigest: snapshot.document.header.sourceDigest,
      pages: snapshot.coordinates.pages,
      operation: {
        id: "browser-mutation-operation",
        pageIndex: 0,
        kind: "overlayText",
        value: "reviewed",
        bounds: {
          x: snapshot.coordinates.pages[0].region.rect.x + 12,
          y: snapshot.coordinates.pages[0].region.rect.y + 12,
          width: 120,
          height: 22
        },
        sourceDigest: snapshot.document.header.sourceDigest,
        coordinate: null,
        payload: { kind: "text", value: "reviewed" },
        reversible: true,
        destructive: false
      }
    };
  });
  fixtureState.operation.coordinate = {
    pageIndex: 0,
    rect: fixtureState.operation.bounds,
    coordinateSpace: { ...fixtureState.pages[0].region.coordinateSpace }
  };

  const passed = await page.evaluate(async ({ sourceDigest, pages, operation }) => {
    let writerCalls = 0;
    const result = await window.__pdfEditorContractFixture.guardedPdfLibExport({
      currentSourceDigest: sourceDigest,
      operations: [operation],
      pageCoordinates: pages.map((entry) => ({
        pageIndex: entry.pageIndex,
        rotation: entry.region.coordinateSpace.rotationDegrees
      })),
      validation: {
        status: "validated",
        checks: [{ kind: "sourceDigest", status: "passed", operationIDs: [] }]
      },
      writer: () => {
        writerCalls += 1;
        return "writer-called";
      }
    });
    return { result, writerCalls };
  }, fixtureState);
  assert.deepEqual(passed, { result: "writer-called", writerCalls: 1 });

  const cases = [];
  cases.push(await expectRejected(page, "stale source digest", {
    currentSourceDigest: fixtureState.sourceDigest,
    operations: [operationFor({
      document: { header: { sourceDigest: fixtureState.sourceDigest } },
      coordinates: { pages: fixtureState.pages }
    }, { sourceDigest: "f".repeat(64) })],
    pageCoordinates: fixtureState.pages.map((entry) => ({ pageIndex: entry.pageIndex, rotation: entry.region.coordinateSpace.rotationDegrees })),
    validation: { status: "validated", checks: [{ status: "passed" }] }
  }, "staleSourceDigest"));
  cases.push(await expectRejected(page, "unsupported operation", {
    currentSourceDigest: fixtureState.sourceDigest,
    operations: [{ ...fixtureState.operation, kind: "sanitize" }],
    pageCoordinates: fixtureState.pages.map((entry) => ({ pageIndex: entry.pageIndex, rotation: entry.region.coordinateSpace.rotationDegrees })),
    validation: { status: "validated", checks: [{ status: "passed" }] }
  }, "unsupportedOperation"));
  cases.push(await expectRejected(page, "destructive operation", {
    currentSourceDigest: fixtureState.sourceDigest,
    operations: [{ ...fixtureState.operation, destructive: true }],
    pageCoordinates: fixtureState.pages.map((entry) => ({ pageIndex: entry.pageIndex, rotation: entry.region.coordinateSpace.rotationDegrees })),
    validation: { status: "validated", checks: [{ status: "passed" }] }
  }, "destructiveOperation"));
  cases.push(await expectRejected(page, "unknown validation check", {
    currentSourceDigest: fixtureState.sourceDigest,
    operations: [fixtureState.operation],
    pageCoordinates: fixtureState.pages.map((entry) => ({ pageIndex: entry.pageIndex, rotation: entry.region.coordinateSpace.rotationDegrees })),
    validation: { status: "validatedWithWarnings", checks: [{ kind: "visualDiff", status: "unknown", operationIDs: [fixtureState.operation.id] }] }
  }, "unknownValidationState"));
  cases.push(await expectRejected(page, "coordinate page mismatch", {
    currentSourceDigest: fixtureState.sourceDigest,
    operations: [{
      ...fixtureState.operation,
      coordinate: { ...fixtureState.operation.coordinate, pageIndex: 1 }
    }],
    pageCoordinates: fixtureState.pages.map((entry) => ({ pageIndex: entry.pageIndex, rotation: entry.region.coordinateSpace.rotationDegrees })),
    validation: { status: "validated", checks: [{ status: "passed" }] }
  }, "coordinateMismatch"));
  cases.push(await expectRejected(page, "coordinate bounds mismatch", {
    currentSourceDigest: fixtureState.sourceDigest,
    operations: [{
      ...fixtureState.operation,
      coordinate: {
        ...fixtureState.operation.coordinate,
        rect: { ...fixtureState.operation.bounds, x: fixtureState.operation.bounds.x + 8 }
      }
    }],
    pageCoordinates: fixtureState.pages.map((entry) => ({ pageIndex: entry.pageIndex, rotation: entry.region.coordinateSpace.rotationDegrees })),
    validation: { status: "validated", checks: [{ status: "passed" }] }
  }, "coordinateMismatch"));

  const pdfLibLoadProbes = [];
  pdfLibLoadProbes.push(await expectMaterializerRejected(
    page,
    "stale source digest materializer probe",
    { ...fixtureState.operation, sourceDigest: "e".repeat(64) },
    null,
    "staleSourceDigest"
  ));
  pdfLibLoadProbes.push(await expectMaterializerRejected(
    page,
    "unsupported operation materializer probe",
    { ...fixtureState.operation, kind: "sanitize" },
    null,
    "unsupportedOperation"
  ));
  pdfLibLoadProbes.push(await expectMaterializerRejected(
    page,
    "destructive operation materializer probe",
    { ...fixtureState.operation, destructive: true },
    null,
    "destructiveOperation"
  ));
  pdfLibLoadProbes.push(await expectMaterializerRejected(
    page,
    "unknown validation materializer probe",
    fixtureState.operation,
    { status: "validatedWithWarnings", checks: [{ kind: "visualDiff", status: "unknown" }] },
    "unknownValidationState"
  ));
  pdfLibLoadProbes.push(await expectMaterializerRejected(
    page,
    "coordinate page materializer probe",
    { ...fixtureState.operation, coordinate: { ...fixtureState.operation.coordinate, pageIndex: 1 } },
    null,
    "coordinateMismatch"
  ));
  pdfLibLoadProbes.push(await expectMaterializerRejected(
    page,
    "coordinate bounds materializer probe",
    {
      ...fixtureState.operation,
      coordinate: {
        ...fixtureState.operation.coordinate,
        rect: { ...fixtureState.operation.bounds, x: fixtureState.operation.bounds.x + 8 }
      }
    },
    null,
    "coordinateMismatch"
  ));

  assert.deepEqual(consoleErrors, [], `browser console errors: ${consoleErrors.join(" | ")}`);
  assert.deepEqual(pageErrors, [], `browser page errors: ${pageErrors.join(" | ")}`);
  console.log(JSON.stringify({
    test: "web_pdf_contract_mutation",
    cases: cases.map((entry) => ({ name: entry.name, code: entry.error.code, writerCalls: entry.writerCalls })),
    pdfLibLoadProbes
  }, null, 2));
} finally {
  await browser.close();
}
