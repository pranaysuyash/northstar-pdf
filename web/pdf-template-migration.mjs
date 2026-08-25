// Reviewed, immutable template-revision migration. This module only moves
// mappings and fingerprint metadata. It never carries profile values.

export const MIGRATION_STATES = Object.freeze(["reviewRequired", "ready", "abstained"]);

function payloadOf(template) {
  return template?.payload || {};
}

export function diffTemplateMappings(from, to) {
  const before = new Map((payloadOf(from).mappings || []).map((mapping) => [mapping.id, mapping]));
  const after = new Map((payloadOf(to).mappings || []).map((mapping) => [mapping.id, mapping]));
  return [...new Set([...before.keys(), ...after.keys()])]
    .map((id) => {
      const left = before.get(id) || null;
      const right = after.get(id) || null;
      if (JSON.stringify(left) === JSON.stringify(right)) return null;
      return { id, change: !left ? "added" : !right ? "removed" : "changed", before: left, after: right };
    })
    .filter(Boolean)
    .sort((left, right) => String(left.id).localeCompare(String(right.id)));
}

export function createTemplateMigrationProposal({ from, to, sourceDigest } = {}) {
  const fromPayload = payloadOf(from);
  const toPayload = payloadOf(to);
  if (fromPayload.templateID !== toPayload.templateID) throw new Error("template-id-mismatch");
  if (!sourceDigest) throw new Error("source-digest-missing");
  const decisions = diffTemplateMappings(from, to).map((change) => ({
    ...change, reviewed: false, approved: false
  }));
  return {
    id: `migration-${crypto.randomUUID()}`,
    templateID: fromPayload.templateID,
    fromRevisionID: fromPayload.revisionID,
    toRevisionID: toPayload.revisionID,
    sourceDigest,
    fromRevision: from,
    toRevision: to,
    decisions,
    state: decisions.length ? "reviewRequired" : "ready",
    reasons: decisions.length
      ? ["The candidate revision contains mapping changes that require explicit review."]
      : ["The revisions differ only in source identity or layout metadata; no mapping migration is required."]
  };
}

export function reviewTemplateMigration(proposal, decisionID, approved) {
  const decisions = (proposal?.decisions || []).map((decision) => decision.id === decisionID
    ? { ...decision, reviewed: true, approved: Boolean(approved) }
    : decision);
  const ready = decisions.every((decision) => decision.reviewed);
  return {
    ...proposal,
    decisions,
    state: ready ? "ready" : "reviewRequired",
    reasons: ready
      ? ["Every revision change has an explicit migration decision."]
      : ["Review every mapping change before migration."]
  };
}

export function canMaterializeTemplateMigration(proposal) {
  return Boolean(proposal && proposal.state === "ready" && proposal.sourceDigest
    && proposal.decisions.every((decision) => decision.reviewed));
}

export function materializeTemplateMigration(proposal) {
  if (!canMaterializeTemplateMigration(proposal)) throw new Error("unresolved-mapping-decisions");
  const fromPayload = payloadOf(proposal.fromRevision);
  const toPayload = payloadOf(proposal.toRevision);
  const before = new Map((fromPayload.mappings || []).map((mapping) => [mapping.id, mapping]));
  const after = new Map((toPayload.mappings || []).map((mapping) => [mapping.id, mapping]));
  const decisions = new Map((proposal.decisions || []).map((decision) => [decision.id, decision]));
  const IDs = new Set([...before.keys(), ...after.keys()]);
  const mappings = [...IDs].map((id) => {
    const decision = decisions.get(id);
    if (decision?.approved && decision.change === "removed") return null;
    if (decision?.approved) return after.get(id) || before.get(id);
    if (decision) return before.get(id);
    return after.get(id) || before.get(id);
  }).filter(Boolean).map((mapping) => mapping.status === "proposed"
    ? { ...mapping, status: "rejected" }
    : mapping).sort((left, right) => String(left.id).localeCompare(String(right.id)));
  if (!mappings.length) throw new Error("no-reviewed-mappings");
  const fingerprint = {
    ...toPayload.fingerprint,
    exactSourceDigests: [...new Set([...(fromPayload.fingerprint?.exactSourceDigests || []), proposal.sourceDigest])].sort()
  };
  return {
    header: { ...proposal.toRevision.header, generatedAt: new Date().toISOString() },
    payload: {
      ...toPayload,
      revisionID: `revision-${crypto.randomUUID()}`,
      parentRevisionID: fromPayload.revisionID,
      lifecycle: "active",
      fingerprint,
      mappings
    }
  };
}

