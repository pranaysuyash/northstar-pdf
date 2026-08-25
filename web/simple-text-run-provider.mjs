/**
 * Bounded semantic text-run provider for a deliberately small PDF class.
 *
 * Supported class:
 *   - classic, uncompressed PDF content streams;
 *   - one unique ASCII literal string `(text)` as the target;
 *   - same-byte-length ASCII replacement;
 *   - existing font/content operators and xref offsets remain untouched.
 *
 * This is a real text-object rewrite for the controlled class, not a visual
 * overlay. It must abstain from compressed streams, escaped literals,
 * ambiguous targets, or replacements that change byte length.
 */

export const SIMPLE_TEXT_RUN_PROVIDER = "pdf-editor.simple-text-run-provider";
export const SIMPLE_TEXT_RUN_PROVIDER_VERSION = Object.freeze({ major: 1, minor: 0 });

function latin1(bytes) {
  let result = "";
  for (let index = 0; index < bytes.length; index += 1) result += String.fromCharCode(bytes[index]);
  return result;
}

function bytes(value) {
  return Uint8Array.from(value, (character) => character.charCodeAt(0));
}

async function sha256Hex(value) {
  if (!globalThis.crypto?.subtle) throw new Error("crypto.subtle is required for source binding");
  const digest = await globalThis.crypto.subtle.digest("SHA-256", value);
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function assertAsciiLiteral(value, label) {
  const text = String(value ?? "");
  if (!text || /[^\x20-\x7e]/u.test(text) || /[()\\]/u.test(text)) {
    throw new Error(`${label} must be a non-empty printable ASCII PDF literal without escapes`);
  }
  return text;
}

function literal(value) {
  return `(${assertAsciiLiteral(value, "text")})`;
}

/**
 * Rewrite one same-width literal string while retaining the rest of the PDF
 * byte layout. The returned value is an export candidate, not a publish
 * decision. Callers still need outside-region, reopen, and independent-viewer
 * validation before publication.
 */
export async function replaceSimpleTextRun({
  sourceBytes,
  sourceDigest,
  targetRunID,
  originalText,
  replacementText,
  coordinate,
  originalTextHash,
  fontFingerprint = null
}) {
  if (!(sourceBytes instanceof Uint8Array)) throw new Error("sourceBytes must be Uint8Array");
  if (!sourceDigest || !/^[0-9a-f]{64}$/u.test(sourceDigest)) throw new Error("sourceDigest must be SHA-256");
  if (!targetRunID || !coordinate?.rect || !Number.isInteger(coordinate.pageIndex)) {
    throw new Error("source-bound target run and coordinate are required");
  }
  const original = assertAsciiLiteral(originalText, "originalText");
  const replacement = assertAsciiLiteral(replacementText, "replacementText");
  if (original.length !== replacement.length) {
    throw new Error("same-byte-length replacement is required for this provider");
  }
  if (!originalTextHash || !/^[0-9a-f]{64}$/u.test(originalTextHash)) {
    throw new Error("originalTextHash must be SHA-256");
  }
  const actualSourceDigest = await sha256Hex(sourceBytes);
  if (actualSourceDigest !== sourceDigest) throw new Error("stale source digest");

  const sourceText = latin1(sourceBytes);
  const sourceLiteral = literal(original);
  const firstIndex = sourceText.indexOf(sourceLiteral);
  if (firstIndex < 0) throw new Error("target literal was not found in source content");
  if (sourceText.indexOf(sourceLiteral, firstIndex + sourceLiteral.length) >= 0) {
    throw new Error("target literal is ambiguous in source content");
  }
  const outputText = `${sourceText.slice(0, firstIndex)}${literal(replacement)}${sourceText.slice(firstIndex + sourceLiteral.length)}`;
  const outputBytes = bytes(outputText);
  if (outputBytes.length !== sourceBytes.length) throw new Error("provider changed PDF byte length");

  return {
    provider: SIMPLE_TEXT_RUN_PROVIDER,
    version: SIMPLE_TEXT_RUN_PROVIDER_VERSION,
    sourceDigest,
    targetRunID,
    originalTextHash,
    fontFingerprint,
    coordinate,
    outputBytes,
    operation: {
      kind: "textRunReplacement",
      targetID: targetRunID,
      sourceDigest,
      coordinate,
      reversible: true,
      destructive: false
    },
    status: "candidateNeedsValidation"
  };
}
