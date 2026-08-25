import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  validateCompanionCapabilityRequest,
  validateCompanionCapabilityResponse,
  validateCompanionCancellation,
  validateCompanionHello,
  validateCompanionHelloResponse
} from "../web/provider-companion-protocol.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const fixture = JSON.parse(fs.readFileSync(path.join(root, "Tests/fixtures/provider_companion_protocol_fixture.json"), "utf8"));

validateCompanionHello(fixture.hello);
validateCompanionHelloResponse(fixture.helloResponse, fixture.hello);
validateCompanionCapabilityRequest(fixture.request, { hello: fixture.hello, helloResponse: fixture.helloResponse });
validateCompanionCapabilityResponse(fixture.response, fixture.request);
validateCompanionCancellation(fixture.cancel, { request: fixture.request });

const badDigest = structuredClone(fixture.request);
badDigest.sourceDigest = "not-a-digest";
assert.throws(() => validateCompanionCapabilityRequest(badDigest), /64-character hex digest/);

const missingBytes = structuredClone(fixture.request);
delete missingBytes.sourceBytesBase64;
assert.throws(() => validateCompanionCapabilityRequest(missingBytes), /source bytes are required/);

const forbiddenBytes = structuredClone(fixture.request);
forbiddenBytes.inputMode = "file-token";
assert.throws(() => validateCompanionCapabilityRequest(forbiddenBytes), /source bytes are forbidden/);

const missingFileToken = structuredClone(fixture.request);
missingFileToken.inputMode = "file-token";
delete missingFileToken.sourceBytesBase64;
assert.throws(() => validateCompanionCapabilityRequest(missingFileToken), /source file token is required/);

const badCancellation = structuredClone(fixture.cancel);
badCancellation.serverNonce = "";
assert.throws(() => validateCompanionCancellation(badCancellation), /cancellation nonce is empty/);

const badOutput = structuredClone(fixture.response);
badOutput.outputDigest = "bad";
assert.throws(() => validateCompanionCapabilityResponse(badOutput), /output digest is invalid/);

console.log("companion protocol: 11 checks passed");
