import assert from "node:assert/strict";
import { resolveTemplateProfile } from "../web/pdf-template-profile-resolver.mjs";
import {
  canMaterializeTemplateMigration,
  createTemplateMigrationProposal,
  materializeTemplateMigration,
  reviewTemplateMigration
} from "../web/pdf-template-migration.mjs";

const templateID = "template-resolver";
const mappingID = "mapping-name";
const removedID = "mapping-email";
const provider = { id: "test", version: "1", platform: "node" };
const fingerprint = {
  algorithm: "hmac-sha256", keyScope: "test", featureVersion: 1,
  layoutFingerprint: "layout", exactSourceDigests: ["a"], pageSignatures: []
};
function mapping(id, semanticKey, status = "confirmed") {
  return {
    id, semanticKey,
    target: { kind: "nativeField", pageIndex: 0, region: { pageIndex: 0, rect: { x: 0, y: 0, width: 10, height: 10 } } },
    suggestedFieldType: "text", evidenceReferences: [], status,
    reviewPolicy: "alwaysReviewMappingAndValue"
  };
}
function revision(revisionID, mappings) {
  return {
    header: { contractName: "pdf-editor.template", version: { major: 1, minor: 0 }, provider },
    payload: {
      templateID, revisionID, parentRevisionID: null, displayName: "fixture", lifecycle: "active",
      privacyMode: "localMinimized", fingerprint, mappings,
      reviewPolicy: { defaultMappingPolicy: "alwaysReviewMappingAndValue", requireValueReview: true, allowBatchMappingApproval: false }
    }
  };
}
function profile(profileID, text) {
  return {
    payload: {
      profileID, revisionID: `${profileID}-revision`, displayName: profileID,
      values: [{ semanticKey: "person.fullName", value: { kind: "text", text } }]
    }
  };
}

const base = revision("revision-a", [mapping(mappingID, "person.fullName")]);
const complete = resolveTemplateProfile({
  template: base,
  profiles: [profile("profile-a", "private")]
});
assert.equal(complete.state, "selected");
assert.equal(complete.selectedProfileID, "profile-a");
assert.equal(JSON.stringify(complete).includes("private"), false);

const tie = resolveTemplateProfile({
  template: base,
  profiles: [profile("profile-a", "one"), profile("profile-b", "two")]
});
assert.equal(tie.state, "ambiguous");
assert.equal(tie.abstained, true);

const changed = revision("revision-b", [mapping(mappingID, "person.fullName")]);
changed.payload.mappings = [mapping(mappingID, "person.fullName")];
const removed = revision("revision-c", [mapping(mappingID, "person.fullName"), mapping(removedID, "person.email")]);
let proposal = createTemplateMigrationProposal({ from: removed, to: changed, sourceDigest: "b" });
assert.equal(proposal.state, "reviewRequired");
assert.equal(canMaterializeTemplateMigration(proposal), false);
for (const decision of proposal.decisions) {
  proposal = reviewTemplateMigration(proposal, decision.id, true);
}
assert.equal(canMaterializeTemplateMigration(proposal), true);
const migrated = materializeTemplateMigration(proposal);
assert.equal(migrated.payload.mappings.some((entry) => entry.id === removedID), false);
assert.equal(migrated.payload.parentRevisionID, removed.payload.revisionID);
assert.equal(migrated.payload.fingerprint.exactSourceDigests.includes("b"), true);
assert.equal(JSON.stringify(migrated).includes("private"), false);

console.log("template profile resolver and migration: 10 checks passed");

