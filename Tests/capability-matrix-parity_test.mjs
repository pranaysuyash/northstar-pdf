// capability-matrix-parity_test.mjs
// RG-076: Automated validation that capability-matrix.json matches capability-matrix.md
// Catches drift between machine-readable and prose matrices.
import assert from "node:assert";
import fs from "node:fs";
import path from "node:path";

const ROOT = path.resolve(import.meta.dirname, "..");
const JSON_PATH = path.join(ROOT, "docs", "capability-matrix.json");
const MD_PATH = path.join(ROOT, "docs", "capability-matrix.md");

// Load the JSON matrix
const jsonRaw = fs.readFileSync(JSON_PATH, "utf-8");
const jsonMatrix = JSON.parse(jsonRaw);

// Load the prose matrix
const mdRaw = fs.readFileSync(MD_PATH, "utf-8");

// Extract capability names from the prose table
const proseCapabilities = [];
const lines = mdRaw.split("\n");
for (const line of lines) {
  const trimmed = line.trim();
  if (trimmed.startsWith("|") && !trimmed.startsWith("|---") && !trimmed.startsWith("| Capability")) {
    const cells = trimmed.split("|").map(c => c.trim()).filter(c => c.length > 0);
    if (cells.length >= 2 && cells[0] !== "Capability" && cells[0] !== "capability") {
      proseCapabilities.push(cells[0]);
    }
  }
}

// Extract capability names from JSON
const jsonCapabilities = jsonMatrix.capabilities.map(c => c.name);
const jsonUnsupported = jsonMatrix.unsupported_capabilities.map(c => c.name);

let passed = 0;
let failed = 0;

function test(name, fn) {
  try {
    fn();
    console.log(`  ✅ ${name}`);
    passed++;
  } catch (e) {
    console.log(`  ❌ ${name}: ${e.message}`);
    failed++;
  }
}

console.log("\n=== Capability Matrix Parity Check ===\n");

// Tests
test("JSON has a version field", () => {
  assert.ok(jsonMatrix.version, "JSON matrix must have a version field");
  assert.ok(/^\d+\.\d+\.\d+$/.test(jsonMatrix.version), `Version must be semver: ${jsonMatrix.version}`);
});

test("JSON has a generated date", () => {
  assert.ok(jsonMatrix.generated, "JSON matrix must have a generated date");
});

test("JSON has capabilities array", () => {
  assert.ok(Array.isArray(jsonMatrix.capabilities), "capabilities must be an array");
  assert.ok(jsonMatrix.capabilities.length > 0, "capabilities must not be empty");
});

test("Each JSON capability has required fields", () => {
  const required = ["id", "name", "native", "web", "contract", "gates", "claim"];
  for (const cap of jsonMatrix.capabilities) {
    for (const field of required) {
      assert.ok(cap[field] !== undefined, `Capability "${cap.name}" missing field "${field}"`);
    }
  }
});

test("Each capability has native and web with provider and status", () => {
  for (const cap of jsonMatrix.capabilities) {
    assert.ok(cap.native.provider, `Capability "${cap.name}" missing native.provider`);
    assert.ok(cap.native.status, `Capability "${cap.name}" missing native.status`);
    assert.ok(cap.web.provider, `Capability "${cap.name}" missing web.provider`);
    assert.ok(cap.web.status, `Capability "${cap.name}" missing web.status`);
  }
});

test("JSON capability names appear in prose matrix", () => {
  const missing = [];
  for (const name of jsonCapabilities) {
    if (!proseCapabilities.some(p => p.includes(name) || name.includes(p))) {
      missing.push(name);
    }
  }
  assert.deepStrictEqual(missing, [], `JSON capabilities missing from prose: ${missing.join(", ")}`);
});

test("Gates are valid RG-XXX format", () => {
  for (const cap of jsonMatrix.capabilities) {
    assert.ok(Array.isArray(cap.gates), `Capability "${cap.name}" gates must be an array`);
    for (const gate of cap.gates) {
      assert.ok(/^RG-\d+$/.test(gate), `Capability "${cap.name}" has invalid gate: ${gate}`);
    }
  }
});

test("Statuses are valid values", () => {
  const valid = ["implemented", "partial", "not-implemented"];
  for (const cap of jsonMatrix.capabilities) {
    assert.ok(valid.includes(cap.native.status), `Capability "${cap.name}" invalid native.status: ${cap.native.status}`);
    assert.ok(valid.includes(cap.web.status), `Capability "${cap.name}" invalid web.status: ${cap.web.status}`);
  }
});

test("Unsupported capabilities have required fields", () => {
  const required = ["id", "name", "status", "note", "gate"];
  for (const cap of jsonMatrix.unsupported_capabilities) {
    for (const field of required) {
      assert.ok(cap[field] !== undefined, `Unsupported "${cap.name}" missing "${field}"`);
    }
  }
});

test("No duplicate capability names", () => {
  const names = jsonMatrix.capabilities.map(c => c.name);
  const dupes = names.filter((n, i) => names.indexOf(n) !== i);
  assert.deepStrictEqual(dupes, [], `Duplicates: ${dupes.join(", ")}`);
});

test("No duplicate capability IDs", () => {
  const ids = jsonMatrix.capabilities.map(c => c.id);
  const dupes = ids.filter((id, i) => ids.indexOf(id) !== i);
  assert.deepStrictEqual(dupes, [], `Duplicate IDs: ${dupes.join(", ")}`);
});

// Summary
console.log(`\nResults: ${passed} passed, ${failed} failed`);
console.log(`JSON capabilities: ${jsonCapabilities.length}`);
console.log(`JSON unsupported: ${jsonUnsupported.length}`);
console.log(`Prose capabilities: ${proseCapabilities.length}`);
console.log(`Version: ${jsonMatrix.version}`);

if (failed > 0) {
  process.exit(1);
}
