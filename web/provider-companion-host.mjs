import { createHash, randomUUID } from "node:crypto";
import {
  validateCompanionHello,
  validateCompanionCapabilityRequest,
  validateCompanionCancellation,
  CONTRACT_VERSION,
  COMPANION_STATES
} from "./provider-companion-protocol.mjs";

const CAPABILITY_PREFIX = "pdf-editor.companion.";

function digestBytes(bytes) {
  return createHash("sha256").update(bytes).digest("hex");
}

function asBytes(value) {
  if (value instanceof Uint8Array) return value;
  if (value instanceof ArrayBuffer) return new Uint8Array(value);
  return null;
}

function safeLog(logger, event) {
  if (typeof logger !== "function") return;
  const allowed = {
    event: event.event,
    code: event.code,
    capability: event.capability,
    providerID: event.providerID,
    state: event.state,
    timingMs: Number.isFinite(event.timingMs) ? Math.max(0, Math.round(event.timingMs)) : undefined
  };
  logger(Object.fromEntries(Object.entries(allowed).filter(([, value]) => value !== undefined)));
}

function response({ request, state, providerID, outputDigest = null, reasonCodes = [] }) {
  if (!COMPANION_STATES.includes(state)) throw new Error(`Unknown companion response state: ${state}`);
  return {
    type: "pdf-editor.companion.capability-response",
    version: CONTRACT_VERSION,
    sessionID: request.sessionID,
    requestID: request.requestID,
    state,
    providerID: providerID || "companion-none",
    outputDigest,
    reasonCodes: [...new Set(reasonCodes)].sort()
  };
}

/**
 * Narrow local provider host. It accepts typed companion messages only and
 * exposes provider handlers by capability name. It deliberately has no path,
 * shell, network, or arbitrary JSON execution surface.
 */
export function createCompanionHost({
  companionID = "companion-reference-host",
  providerIDs = [],
  allowedOrigins = [],
  handlers = {},
  serverNonceFactory = () => `server-${randomUUID()}`,
  logger = null
} = {}) {
  const sessions = new Map();
  const active = new Map();

  async function handleHello(message) {
    validateCompanionHello(message);
    const accepted = allowedOrigins.length === 0 || allowedOrigins.includes(message.origin);
    const serverNonce = serverNonceFactory();
    const session = { hello: message, serverNonce, accepted };
    sessions.set(message.sessionID, session);
    safeLog(logger, { event: "hello", code: accepted ? "session_accepted" : "origin_rejected", state: accepted ? "accepted" : "rejected" });
    return {
      type: "pdf-editor.companion.hello-response",
      version: CONTRACT_VERSION,
      sessionID: message.sessionID,
      serverNonce,
      accepted,
      companionID,
      providerIDs: accepted ? providerIDs : []
    };
  }

  function sessionFor(request) {
    const session = sessions.get(request.sessionID);
    if (!session?.accepted) throw new Error("companion session is not accepted");
    validateCompanionCapabilityRequest(request, {
      hello: session.hello,
      helloResponse: {
        type: "pdf-editor.companion.hello-response",
        version: CONTRACT_VERSION,
        sessionID: request.sessionID,
        serverNonce: session.serverNonce,
        accepted: true,
        companionID,
        providerIDs
      }
    });
    return session;
  }

  async function handleRequest(request) {
    const session = sessionFor(request);
    const startedAt = Date.now();
    const sourceBytes = request.inputMode === "source-bytes"
      ? Uint8Array.from(Buffer.from(request.sourceBytesBase64, "base64"))
      : null;
    if (sourceBytes) {
      if (sourceBytes.byteLength !== request.sourceByteCount) {
        return [response({ request, state: "failed", providerID: "companion-none", reasonCodes: ["sourceByteCountMismatch"] })];
      }
      if (digestBytes(sourceBytes) !== request.sourceDigest.toLowerCase()) {
        return [response({ request, state: "failed", providerID: "companion-none", reasonCodes: ["sourceDigestMismatch"] })];
      }
    }
    const handler = handlers[request.capability];
    const providerID = providerIDs.find((id) => typeof id === "string") || "companion-none";
    if (typeof handler !== "function") {
      safeLog(logger, { event: "capability", code: "provider_unavailable", capability: request.capability, providerID, state: "abstained", timingMs: Date.now() - startedAt });
      return [response({ request, state: "abstained", providerID, reasonCodes: ["providerUnavailable", "noHandler"] })];
    }
    const controller = new AbortController();
    const activeRequest = { controller, request, session };
    active.set(request.requestID, activeRequest);
    const events = [response({ request, state: "started", providerID, reasonCodes: ["localOnly"] })];
    try {
      const work = Promise.resolve(handler({ request, sourceBytes, signal: controller.signal }));
      const timeout = new Promise((_, reject) => setTimeout(() => {
        controller.abort();
        reject(new Error("timeout"));
      }, request.timeoutMs));
      const result = await Promise.race([work, timeout]);
      if (controller.signal.aborted) throw new Error("cancelled");
      const outputBytes = asBytes(result?.outputBytes);
      if (outputBytes && outputBytes.byteLength > request.maxOutputBytes) {
        events.push(response({ request, state: "failed", providerID, reasonCodes: ["outputLimit"] }));
      } else {
        const outputDigest = outputBytes ? digestBytes(outputBytes) : result?.outputDigest || null;
        events.push(response({ request, state: result?.state || "completed", providerID, outputDigest, reasonCodes: result?.reasonCodes || ["localOnly"] }));
      }
    } catch (error) {
      const code = controller.signal.aborted ? "cancelled" : error?.message === "timeout" ? "timeout" : "providerFailure";
      events.push(response({ request, state: code === "cancelled" ? "cancelled" : "failed", providerID, reasonCodes: [code] }));
    } finally {
      active.delete(request.requestID);
      safeLog(logger, { event: "capability", code: events.at(-1).reasonCodes[0], capability: request.capability, providerID, state: events.at(-1).state, timingMs: Date.now() - startedAt });
    }
    return events;
  }

  async function handleCancel(message) {
    const session = sessions.get(message.sessionID);
    if (!session) throw new Error("companion session is not accepted");
    validateCompanionCancellation(message, { request: active.get(message.requestID)?.request });
    const current = active.get(message.requestID);
    if (current) current.controller.abort();
    safeLog(logger, { event: "cancel", code: current ? "cancel_requested" : "request_not_active", state: "cancelled" });
    return { type: "pdf-editor.companion.cancelled", version: CONTRACT_VERSION, sessionID: message.sessionID, requestID: message.requestID, state: "cancelled" };
  }

  return Object.freeze({
    async handle(message) {
      if (message?.type === "pdf-editor.companion.hello") return handleHello(message);
      if (message?.type === "pdf-editor.companion.capability-request") return handleRequest(message);
      if (message?.type === "pdf-editor.companion.cancel") return handleCancel(message);
      throw new Error("unsupported companion message type");
    }
  });
}
