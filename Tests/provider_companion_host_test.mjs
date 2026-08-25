import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { createCompanionHost } from "../web/provider-companion-host.mjs";
import { validateCompanionCapabilityResponse, validateCompanionHelloResponse } from "../web/provider-companion-protocol.mjs";

const bytes = Buffer.from("pdf-source-fixture");
const sourceDigest = createHash("sha256").update(bytes).digest("hex");
const hello = {
  type: "pdf-editor.companion.hello",
  version: { major: 1, minor: 0 },
  sessionID: "host-session",
  clientNonce: "client-nonce",
  origin: "http://127.0.0.1:4174",
  requestedCapabilities: ["ocr.textBounds", "validate.rasterDiff"],
  localOnly: true
};

const logs = [];
const host = createCompanionHost({
  companionID: "reference-host",
  providerIDs: ["fixture-provider"],
  allowedOrigins: [hello.origin],
  serverNonceFactory: () => "server-nonce",
  logger: (entry) => logs.push(entry),
  handlers: {
    "ocr.textBounds": async ({ sourceBytes, signal }) => {
      assert.equal(Buffer.from(sourceBytes).toString(), bytes.toString());
      assert.equal(signal.aborted, false);
      return { outputBytes: new Uint8Array([1, 2, 3]), reasonCodes: ["fixtureMeasured"] };
    }
  }
});

const helloResponse = await host.handle(hello);
validateCompanionHelloResponse(helloResponse, hello);
assert.equal(helloResponse.accepted, true);

const request = {
  type: "pdf-editor.companion.capability-request",
  version: { major: 1, minor: 0 },
  sessionID: hello.sessionID,
  requestID: "host-request",
  clientNonce: hello.clientNonce,
  serverNonce: helloResponse.serverNonce,
  capability: "ocr.textBounds",
  sourceDigest,
  sourceByteCount: bytes.byteLength,
  sourcePageCount: 1,
  maxOutputBytes: 100,
  timeoutMs: 1000,
  inputMode: "source-bytes",
  sourceBytesBase64: bytes.toString("base64"),
  operationIDs: [],
  localOnly: true
};
const events = await host.handle(request);
assert.deepEqual(events.map((event) => event.state), ["started", "completed"]);
validateCompanionCapabilityResponse(events.at(-1), request);
assert.equal(events.at(-1).outputDigest.length, 64);

const unavailable = await host.handle({ ...request, requestID: "unavailable", capability: "edit.existingText" });
assert.deepEqual(unavailable.map((event) => event.state), ["abstained"]);
assert.deepEqual(unavailable[0].reasonCodes, ["noHandler", "providerUnavailable"]);

const oversized = await host.handle({ ...request, requestID: "oversized", maxOutputBytes: 2 });
assert.deepEqual(oversized.map((event) => event.state), ["started", "failed"]);
assert.deepEqual(oversized.at(-1).reasonCodes, ["outputLimit"]);

const stale = await host.handle({ ...request, requestID: "stale", sourceDigest: "a".repeat(64) });
assert.deepEqual(stale.map((event) => event.state), ["failed"]);
assert.deepEqual(stale[0].reasonCodes, ["sourceDigestMismatch"]);

const slowHost = createCompanionHost({
  companionID: "slow-reference-host",
  providerIDs: ["slow-provider"],
  allowedOrigins: [hello.origin],
  serverNonceFactory: () => "slow-server-nonce",
  handlers: {
    "validate.rasterDiff": async ({ signal }) => new Promise((resolve) => {
      setTimeout(() => resolve({ reasonCodes: [signal.aborted ? "aborted" : "unexpected"] }), 100);
    })
  }
});
const slowHelloResponse = await slowHost.handle(hello);
const slowRequest = { ...request, requestID: "slow-request", capability: "validate.rasterDiff", serverNonce: slowHelloResponse.serverNonce, timeoutMs: 1000 };
const pendingSlowRequest = slowHost.handle(slowRequest);
await new Promise((resolve) => setTimeout(resolve, 10));
const cancellation = await slowHost.handle({
  type: "pdf-editor.companion.cancel",
  version: { major: 1, minor: 0 },
  sessionID: hello.sessionID,
  requestID: slowRequest.requestID,
  clientNonce: hello.clientNonce,
  serverNonce: slowHelloResponse.serverNonce
});
assert.equal(cancellation.state, "cancelled");
const slowEvents = await pendingSlowRequest;
assert.deepEqual(slowEvents.map((event) => event.state), ["started", "cancelled"]);

assert.ok(logs.length >= 3);
assert.equal(logs.some((entry) => Object.keys(entry).some((key) => ["sourceBytes", "sourceDigest", "outputDigest", "text", "value"].includes(key))), false);
console.log(`companion host: handshake, source binding, abstention, output limits, and zero-content logging passed (${logs.length} events)`);
