import { test } from "node:test";
import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";
import path from "node:path";

const require = createRequire(import.meta.url);
// The vendored UMD bundle loads under CommonJS require (UMD detection).
const PDFLib = require(path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  "../web/vendor/pdf-lib/pdf-lib.min.js"
));

const planning = await import("../web/pdf-write-planning.mjs");

test("assertWritable refuses encrypted mutation but allows byte-preserving no-op", () => {
  assert.throws(
    () => planning.assertWritable({ encrypted: true, operationCount: 2 }),
    /Encrypted PDF editing is not supported/
  );
  assert.doesNotThrow(() => planning.assertWritable({ encrypted: true, operationCount: 0 }));
  assert.doesNotThrow(() => planning.assertWritable({ encrypted: false, operationCount: 5 }));
});

test("page-fact replay preserves a non-zero crop origin and rotation through a save round trip", async () => {
  const { PDFDocument, StandardFonts, degrees } = PDFLib;

  // Build a source with a non-zero crop-box origin — the exact case that
  // silently changes crop-relative coordinates when not replayed.
  const source = await PDFDocument.create();
  const page = source.addPage([612, 792]);
  const font = await source.embedFont(StandardFonts.Helvetica);
  page.drawText("Crop origin fixture", { x: 40, y: 700, size: 12, font });
  page.setCropBox(20, 10, 572, 762);
  const sourceBytes = await source.save();

  // Inspect facts from the untouched source; rotation truth is injected.
  const inspected = await PDFDocument.load(sourceBytes);
  const facts = planning.planPageFactReplay(inspected, () => 90);
  assert.equal(facts.length, 1);
  assert.deepEqual(
    [facts[0].boxes.crop.x, facts[0].boxes.crop.y, facts[0].boxes.crop.width, facts[0].boxes.crop.height],
    [20, 10, 572, 762]
  );

  // Replay onto a fresh copy before edits, then verify survival.
  const output = await PDFDocument.load(sourceBytes.slice());
  planning.applyPageFacts(output, facts, degrees);
  const outputBytes = await output.save({ useObjectStreams: false });

  const reopened = await PDFDocument.load(outputBytes);
  const outPage = reopened.getPage(0);
  const crop = outPage.getCropBox();
  assert.deepEqual([crop.x, crop.y], [20, 10]);
  assert.equal(outPage.getRotation().angle, 90);
});

test("applyPageFacts skips missing fact entries without throwing", async () => {
  const { PDFDocument } = PDFLib;
  const doc = await PDFDocument.create();
  doc.addPage([300, 300]);
  assert.doesNotThrow(() => planning.applyPageFacts(doc, [], PDFLib.degrees));
});
