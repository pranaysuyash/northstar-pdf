import assert from "node:assert/strict";
import {
  buildTemplateIndex,
  queryTemplateIndex,
  validateTemplateIndex
} from "../web/template-index.mjs";

const page = {
  pageIndex: 0,
  widthPoints: 612,
  heightPoints: 792,
  rotationDegrees: 0,
  nativeFieldKinds: ["text", "button"],
  nativeFieldNameTokens: ["hmac:name", "hmac:agree"],
  anchorTokens: ["hmac:name"],
  regionSignatures: [{ kind: "vectorRectangle", suggestedFieldType: "text", normalizedRect: { x: 0.1, y: 0.2, width: 0.3, height: 0.04 }, groupMemberCount: 1 }]
};

function revision({ templateID, revisionID, lifecycle = "active", layoutFingerprint = "layout-a", digest = "a".repeat(64) }) {
  return {
    header: {
      contractName: "pdf-editor.template",
      version: { major: 1, minor: 0 },
      templateDigest: layoutFingerprint,
      generatedAt: "2026-08-25T00:00:00.000Z",
      provider: { id: "test", version: "1", platform: "node", capabilities: [] }
    },
    payload: {
      templateID,
      revisionID,
      parentRevisionID: null,
      displayName: `Template ${templateID}`,
      lifecycle,
      privacyMode: "localMinimized",
      fingerprint: {
        algorithm: "layout-v1+hmac-sha256",
        keyScope: "workspace",
        featureVersion: "layout-features-1",
        layoutFingerprint,
        exactSourceDigests: [digest],
        pageSignatures: [page]
      },
      mappings: [],
      reviewPolicy: { requireValueReview: true }
    }
  };
}

const sourceDigest = "b".repeat(64);
const exact = revision({ templateID: "template-exact", revisionID: "revision-exact", digest: sourceDigest });
const variant = revision({ templateID: "template-variant", revisionID: "revision-variant", digest: "c".repeat(64) });
const familyOne = revision({ templateID: "template-family-one", revisionID: "revision-family-one", layoutFingerprint: "layout-family-one" });
const familyTwo = revision({ templateID: "template-family-two", revisionID: "revision-family-two", layoutFingerprint: "layout-family-two" });
const stale = revision({ templateID: "template-stale", revisionID: "revision-stale", lifecycle: "revoked", digest: sourceDigest });
const index = buildTemplateIndex([
  { templateID: exact.payload.templateID, revisions: [exact] },
  { templateID: variant.payload.templateID, revisions: [variant] },
  { templateID: familyOne.payload.templateID, revisions: [familyOne] },
  { templateID: familyTwo.payload.templateID, revisions: [familyTwo] },
  { templateID: stale.payload.templateID, revisions: [stale] }
]);
validateTemplateIndex(index);
assert.equal(index.privacy, "value-free-keyed-layout-only");
assert.equal(JSON.stringify(index).includes("profileValue"), false);
assert.equal(JSON.stringify(index).includes("%PDF-"), false);

const exactResult = queryTemplateIndex({ index, fingerprint: exact.payload.fingerprint, sourceDigest });
assert.equal(exactResult.state, "exact");
assert.equal(exactResult.selected.templateID, exact.payload.templateID);

const knownVariantResult = queryTemplateIndex({ index, fingerprint: variant.payload.fingerprint, sourceDigest: "d".repeat(64) });
assert.equal(knownVariantResult.state, "knownVariant");

const familyResult = queryTemplateIndex({
  index: buildTemplateIndex([{ templateID: familyOne.payload.templateID, revisions: [familyOne] }]),
  fingerprint: { ...familyOne.payload.fingerprint, layoutFingerprint: "different-keyed-layout" },
  sourceDigest: "e".repeat(64)
});
assert.equal(familyResult.state, "familyMatch");
assert.ok(familyResult.selected, "family matches may identify a review candidate but cannot auto-apply mappings");
assert.deepEqual(familyResult.selected.approvedMappingIDs, []);
assert.equal(familyResult.abstained, false);

const ambiguousResult = queryTemplateIndex({
  index,
  fingerprint: { ...familyOne.payload.fingerprint, layoutFingerprint: "different-keyed-layout" },
  sourceDigest: "f".repeat(64)
});
assert.equal(ambiguousResult.state, "ambiguous");
assert.equal(ambiguousResult.selected, null);
assert.equal(ambiguousResult.abstained, true);

const staleResult = queryTemplateIndex({
  index: buildTemplateIndex([{ templateID: stale.payload.templateID, revisions: [stale] }]),
  fingerprint: stale.payload.fingerprint,
  sourceDigest
});
assert.equal(staleResult.state, "stale");
assert.equal(staleResult.abstained, true);

const noMatch = queryTemplateIndex({
  index,
  fingerprint: {
    ...page,
    layoutFingerprint: "not-a-family",
    pageSignatures: [{
      ...page,
      widthPoints: 100,
      heightPoints: 100,
      rotationDegrees: 90,
      nativeFieldKinds: [],
      anchorTokens: [],
      regionSignatures: []
    }]
  },
  sourceDigest: "1".repeat(64)
});
assert.equal(noMatch.state, "noMatch");
assert.equal(noMatch.selected, null);

assert.throws(() => validateTemplateIndex({ ...index, entries: [{ ...index.entries[0], profileValue: "secret" }] }), /profile values/);
console.log("template index: exact, variant, family, ambiguous, stale, no-match, privacy, and abstention checks passed");
