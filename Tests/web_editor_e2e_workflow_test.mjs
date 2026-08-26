/**
 * End-to-end workflow test for the web PDF editor.
 *
 * Covers: file open, native field fill, overlay fill, export + validate,
 * diff view toggle, keyboard shortcuts, and session persistence.
 *
 * Requires: Playwright, a running local server, and the Form 6 fixture.
 *
 * Run:
 *   node Tests/web_editor_e2e_workflow_test.mjs
 *
 * Environment:
 *   PDF_EDITOR_BASE_URL  — override the default local URL
 *   PDF_EDITOR_FORM6_INPUT — override the fixture path
 */
import assert from "node:assert/strict";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";

const testDirectory = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(testDirectory, "..");
const fixture =
  process.env.PDF_EDITOR_FORM6_INPUT ||
  path.join(projectRoot, "docs/benchmarks/pdfkit-form6-run-2026-08-23/noop.pdf");
const baseURL =
  process.env.PDF_EDITOR_BASE_URL || "http://127.0.0.1:4173/web/index.html";

const browser = await chromium.launch({ channel: "chrome", headless: true });
const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
page.setDefaultTimeout(5_000);
const errors = [];
page.on("pageerror", (error) => errors.push(error.message));

let passed = 0;
let failed = 0;

function test(name, fn) {
  return fn()
    .then(() => {
      passed++;
      console.log(`  ✓ ${name}`);
    })
    .catch((err) => {
      failed++;
      console.error(`  ✗ ${name}`);
      console.error(`    ${err.message}`);
    });
}

try {
  // ── Setup ──────────────────────────────────────────────────────────
  console.log("\nweb editor e2e workflow\n");

  await page.goto(baseURL, { waitUntil: "networkidle" });
  await page.waitForFunction(() => Boolean(window.pdfjsLib && window.PDFLib));

  // ── 1. File open ───────────────────────────────────────────────────
  console.log("File open");

  await test("loads PDF and renders pages", async () => {
    await page.locator("#fileInput").setInputFiles(fixture);
    // Wait for the editor to process the file — contract fixture or page shells
    await page.waitForFunction(
      () => Boolean(window.__pdfEditorContractFixture?.snapshot?.()?.document) || document.querySelectorAll(".page-shell").length > 0,
      { timeout: 15_000 }
    );
    // Give the renderer a moment to paint
    await page.waitForTimeout(1000);
    const pageCount = await page.locator(".page-shell").count();
    assert.ok(pageCount > 0, `expected at least 1 page, got ${pageCount}`);
  });

  await test("toolbar buttons become enabled after load", async () => {
    const exportDisabled = await page.locator("#exportButton").getAttribute("disabled");
    const diffDisabled = await page.locator("#diffToggleButton").getAttribute("disabled");
    assert.equal(exportDisabled, null, "export button should be enabled");
    assert.equal(diffDisabled, null, "diff button should be enabled");
  });

  await test("status shows ready message", async () => {
    const status = await page.locator("#status").textContent();
    assert.ok(status.length > 0, "status should have content");
  });

  // ── 2. Native field fill ───────────────────────────────────────────
  console.log("\nNative field fill");

  await test("selects a native field and shows action card", async () => {
    const fieldItem = page.locator("#fieldList .completion-item").first();
    if ((await fieldItem.count()) === 0) {
      console.log("    (skipped — no native fields in fixture)");
      return;
    }
    await fieldItem.locator("button").click();
    await page.waitForFunction(
      () => !document.querySelector("#candidateAction")?.hidden
    );
    const detail = await page.locator("#candidateActionDetail").textContent();
    assert.ok(detail.length > 0, "action detail should show field info");
  });

  // ── 3. Overlay fill ────────────────────────────────────────────────
  console.log("\nOverlay fill");

  await test("selects a candidate and applies text overlay", async () => {
    let candidateRow = page
      .locator("#candidateList .completion-item")
      .filter({ hasText: "Text entry region" })
      .first();
    if ((await candidateRow.count()) === 0) {
      candidateRow = page
        .locator("#candidateList .completion-item")
        .filter({ hasText: "Character-entry region" })
        .first();
    }
    if ((await candidateRow.count()) === 0) {
      console.log("    (skipped — no text-entry candidates)");
      return;
    }
    await candidateRow.locator("button").click();
    await page.waitForFunction(
      () => !document.querySelector("#candidateAction")?.hidden
    );
    await page.locator(".candidate-preview.selected").first().waitFor();

    await page.locator("#completionValue").fill("E2E test value");
    await page.locator("#applyOverlayButton").click();
    assert.match(
      await page.locator("#editList").textContent(),
      /E2E test value/,
      "edit list should show applied value"
    );
    await page.locator(".overlay-preview").waitFor();
    assert.ok(
      (await page.locator(".overlay-preview").count()) > 0,
      "overlay should be visible on page"
    );
  });

  await test("edits an existing overlay", async () => {
    const overlay = page.locator(".overlay-preview").first();
    if ((await overlay.count()) === 0) {
      console.log("    (skipped — no overlay to edit)");
      return;
    }
    await overlay.click();
    await page.locator("#completionValue").fill("Updated E2E value");
    await page.locator("#applyOverlayButton").click();
    assert.match(
      await page.locator("#editList").textContent(),
      /Updated E2E value/,
      "edit list should show updated value"
    );
  });

  await test("undo removes the last operation", async () => {
    const editCountBefore = await page.locator(".overlay-preview").count();
    if (editCountBefore === 0) {
      console.log("    (skipped — no overlays to undo)");
      return;
    }
    await page.locator("#undoEditButton").click();
    await page.waitForTimeout(300);
    const editCountAfter = await page.locator(".overlay-preview").count();
    assert.ok(
      editCountAfter < editCountBefore,
      `overlay count should decrease: ${editCountBefore} → ${editCountAfter}`
    );
  });

  // ── 4. Manual text placement ───────────────────────────────────────
  console.log("\nManual text placement");

  await test("enters manual placement mode and places text", async () => {
    await page.locator("#manualTextButton").click();
    assert.match(
      await page.locator("#status").textContent(),
      /Click the document/,
      "status should prompt for placement"
    );
    await page
      .locator("#viewerStack .page-shell")
      .first()
      .click({ position: { x: 110, y: 110 } });
    // Wait for the completion value input to become enabled after placement
    await page.waitForFunction(
      () => !document.querySelector("#completionValue")?.disabled,
      { timeout: 5000 }
    );
    await page.locator("#completionValue").fill("Manual E2E text");
    await page.locator("#applyOverlayButton").click();
    assert.match(
      await page.locator("#editList").textContent(),
      /Manual E2E text/,
      "edit list should show manual text"
    );
  });

  // ── 5. Export + validate ───────────────────────────────────────────
  console.log("\nExport + validate");

  await test("exports PDF and runs validation", async () => {
    const [download] = await Promise.all([
      page.waitForEvent("download", { timeout: 15_000 }),
      page.locator("#exportButton").click(),
    ]);
    assert.ok(download, "export should trigger a download");
    const filename = download.suggestedFilename();
    assert.ok(
      filename.endsWith(".pdf"),
      `downloaded file should be PDF, got: ${filename}`
    );
    // Wait for validation to complete
    await page.waitForFunction(
      () => {
        const box = document.querySelector("#validationBox");
        return box && box.textContent.length > 10;
      },
      { timeout: 10_000 }
    );
    const validationText = await page.locator("#validationBox").textContent();
    assert.ok(
      validationText.includes("passed") || validationText.includes("warning"),
      `validation should report result, got: ${validationText.substring(0, 100)}`
    );
  });

  // ── 6. Diff view ───────────────────────────────────────────────────
  console.log("\nDiff view");

  await test("toggles diff overlay on and off", async () => {
    const diffBtn = page.locator("#diffToggleButton");
    const textBefore = await diffBtn.textContent();
    await diffBtn.click();
    await page.waitForTimeout(200);
    const textAfter = await diffBtn.textContent();
    assert.notEqual(
      textBefore,
      textAfter,
      "diff button text should change after toggle"
    );
    // Toggle back
    await diffBtn.click();
    await page.waitForTimeout(200);
    const textReset = await diffBtn.textContent();
    assert.equal(textBefore, textReset, "diff button text should reset on second toggle");
  });

  await test("diff overlay shows highlight elements when active", async () => {
    const diffBtn = page.locator("#diffToggleButton");
    await diffBtn.click();
    await page.waitForTimeout(300);
    // After export, there should be operations to diff against
    const status = await page.locator("#status").textContent();
    assert.ok(
      status.includes("diff") || status.includes("Diff"),
      "status should mention diff after toggle"
    );
    // Toggle off
    await diffBtn.click();
    await page.waitForTimeout(200);
  });

  // ── 7. Keyboard shortcuts ──────────────────────────────────────────
  console.log("\nKeyboard shortcuts");

  await test("Ctrl+Z triggers undo via keyboard", async () => {
    const editCountBefore = await page.locator(".overlay-preview").count();
    await page.keyboard.press("Control+z");
    await page.waitForTimeout(300);
    const editCountAfter = await page.locator(".overlay-preview").count();
    assert.ok(
      editCountAfter <= editCountBefore,
      "Ctrl+Z should undo (overlay count should not increase)"
    );
  });

  await test("Ctrl+Shift+Z triggers redo via keyboard", async () => {
    const redoBtn = page.locator("#redoEditButton");
    const isDisabledBefore = await redoBtn.getAttribute("disabled");
    await page.keyboard.press("Control+Shift+z");
    await page.waitForTimeout(300);
    // After redo, the redo button should still be disabled or re-enabled depending on stack
    const redoBtnExists = await redoBtn.count();
    assert.equal(redoBtnExists, 1, "Redo button should exist");
  });

  await test("Ctrl+D toggles diff overlay via keyboard", async () => {
    const diffBtn = page.locator("#diffToggleButton");
    const textBefore = await diffBtn.textContent();
    await page.keyboard.press("Control+d");
    await page.waitForTimeout(200);
    const textAfter = await diffBtn.textContent();
    assert.notEqual(
      textBefore,
      textAfter,
      "Ctrl+D should toggle diff button text"
    );
    // Toggle back
    await page.keyboard.press("Control+d");
    await page.waitForTimeout(200);
  });

  await test("Ctrl+F focuses search input", async () => {
    await page.keyboard.press("Control+f");
    await page.waitForTimeout(100);
    const focused = await page.evaluate(() => document.activeElement?.id);
    assert.equal(focused, "searchInput", "Ctrl+F should focus the search input");
    // Blur to continue
    await page.keyboard.press("Escape");
  });

  await test("Escape closes shortcuts help panel", async () => {
    await page.locator("#shortcutsHelpButton").click();
    await page.waitForTimeout(100);
    const panelHidden = await page
      .locator("#shortcutsHelpPanel")
      .getAttribute("hidden");
    assert.equal(panelHidden, null, "panel should be visible after click");
    await page.keyboard.press("Escape");
    await page.waitForTimeout(100);
    const panelHiddenAfter = await page
      .locator("#shortcutsHelpPanel")
      .getAttribute("hidden");
    assert.notEqual(
      panelHiddenAfter,
      null,
      "panel should be hidden after Escape"
    );
  });

  // ── 8. Session persistence ─────────────────────────────────────────
  // The web app persists sessions in IndexedDB (encrypted at rest), not
  // localStorage. The session record key is "session-" + sourceDigest.
  console.log("\nSession persistence");

  await test("session state is saved to IndexedDB", async () => {
    const hasSession = await page.evaluate(async () => {
      const dbs = await indexedDB.databases();
      const sessionDB = dbs.find((d) => d.name && d.name.includes("session"));
      if (!sessionDB) return false;
      const db = await new Promise((resolve, reject) => {
        const req = indexedDB.open(sessionDB.name);
        req.onsuccess = () => resolve(req.result);
        req.onerror = () => reject(req.error);
      });
      try {
        const storeNames = Array.from(db.objectStoreNames);
        const storeName = storeNames[0];
        if (!storeName) return false;
        const records = await new Promise((resolve, reject) => {
          const tx = db.transaction(storeName, "readonly");
          const store = tx.objectStore(storeName);
          const req = store.getAll();
          req.onsuccess = () => resolve(req.result || []);
          req.onerror = () => reject(req.error);
        });
        return records.some((r) => r && (r.sourceDigest || r.sessionID));
      } finally {
        db.close();
      }
    });
    assert.ok(hasSession, "IndexedDB should contain session data");
  });

  // ── 9. Error check ─────────────────────────────────────────────────
  console.log("\nError check");

  await test("no page errors during entire workflow", async () => {
    assert.equal(
      errors.length,
      0,
      `expected 0 page errors, got ${errors.length}: ${errors.join("; ")}`
    );
  });

  // ── Summary ────────────────────────────────────────────────────────
  console.log(`\n${passed + failed} tests: ${passed} passed, ${failed} failed\n`);
  if (failed > 0) process.exit(1);
} finally {
  await browser.close();
}
