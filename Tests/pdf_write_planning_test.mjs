import { test } from "node:test";
import assert from "node:assert/strict";

const {
  OVERLAY_PROPOSAL,
  planSingleLineOverlay,
  proposeOverlayBounds,
  valuesMatch
} = await import("../web/pdf-write-planning.mjs");

// Deterministic metrics stand-in for the injected pdf-lib font.
const metrics = {
  widthOfTextAtSize: (text, size) => text.length * size * 0.5,
  heightAtSize: (size) => size * 1.2
};

test("valuesMatch compares plain text trimmed", () => {
  assert.equal(valuesMatch("Ada ", "Ada", {}), true);
  assert.equal(valuesMatch("Ada", "Grace", {}), false);
});

test("valuesMatch handles boolean truthiness and radio index round-trips", () => {
  assert.equal(valuesMatch("yes", "1", { payload: { kind: "boolean" } }), true);
  assert.equal(valuesMatch("", "off", { payload: { kind: "boolean" } }), true);
  assert.equal(valuesMatch("email", "0", { payload: { kind: "radio", options: ["email", "phone"] } }), true);
  assert.equal(valuesMatch("email", "email", { payload: { kind: "radio", options: ["email"] } }), true);
  assert.equal(valuesMatch("phone", "0", { payload: { kind: "radio", options: ["email", "phone"] } }), false);
});

test("planSingleLineOverlay centers text and shrinks to fit the authorized region", () => {
  const bounds = { x: 100, y: 200, width: 120, height: 24 };
  const plan = planSingleLineOverlay({ text: "Hello", bounds, ...metrics });
  assert.ok(plan.size >= 6 && plan.size <= 14);
  // Horizontal padding respected.
  assert.ok(plan.x >= bounds.x + 2);
  // Vertically centered within the available box.
  assert.ok(plan.y > bounds.y && plan.y < bounds.y + bounds.height);
});

test("planSingleLineOverlay refuses text that cannot fit at legible size", () => {
  const bounds = { x: 0, y: 0, width: 20, height: 8 };
  assert.throws(
    () => planSingleLineOverlay({ text: "This value is far too long for the region", bounds, ...metrics }),
    /cannot fit inside its declared region/
  );
});

test("planSingleLineOverlay refuses missing or degenerate bounds", () => {
  assert.throws(() => planSingleLineOverlay({ text: "x", bounds: null, ...metrics }), /usable coordinate bounds/);
});

test("proposeOverlayBounds clamps click points into the crop box", () => {
  const crop = [0, 0, 612, 792];
  const center = proposeOverlayBounds({ x: 306, y: 396 }, crop);
  assert.equal(center.width, OVERLAY_PROPOSAL.widthPt);
  assert.equal(center.height, OVERLAY_PROPOSAL.heightPt);

  const nearEdge = proposeOverlayBounds({ x: 3, y: 790 }, crop);
  assert.ok(nearEdge.x >= OVERLAY_PROPOSAL.paddingPt - 0.001);
  assert.ok(nearEdge.y + nearEdge.height <= 792 - OVERLAY_PROPOSAL.paddingPt + 0.001);
});

test("proposeOverlayBounds rejects a crop box too small to host an overlay", () => {
  assert.throws(() => proposeOverlayBounds({ x: 5, y: 5 }, [0, 0, 20, 20]), /too small/);
});
