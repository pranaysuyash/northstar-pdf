// pdf-sanitize-audited.mjs
//
// RG-097 integration: sanitization WITH hidden-revision audit.
//
// Sanitization is a full rewrite, and a full rewrite collapses revision
// history (see pdf-hidden-revision-analyzer falsifier). That is desirable for
// removal — but it also DESTROYS the evidence of what prior revisions
// contained. Safe default: if the source carries active-content remnants in
// shadowed revisions, refuse to sanitize until the operator explicitly
// acknowledges that rewriting will destroy that evidence ("acknowledge"
// policy). The output's collapsed chain is verified post-write.
//
// Local-first: no egress. Runs in the companion (Node).

import { sanitizePdf } from "./pdf-sanitize.mjs";
import { analyzeHiddenRevisions } from "./pdf-hidden-revision-analyzer.mjs";

export const REMNANT_POLICIES = Object.freeze(["refuse", "acknowledge"]);

export class SanitizeAuditError extends Error {
  constructor(remnants) {
    super(
      `Source carries ${remnants.length} active-content remnant(s) in shadowed revisions; ` +
      "sanitizing would rewrite (and destroy) that evidence. Re-run with remnantPolicy " +
      "\"acknowledge\" after recording the findings."
    );
    this.name = "SanitizeAuditError";
    this.remnants = remnants;
  }
}

export function sanitizePdfAudited(srcBuf, opts = {}) {
  const policy = opts.remnantPolicy === "acknowledge" ? "acknowledge" : "refuse";
  const before = analyzeHiddenRevisions(srcBuf);
  if (policy === "refuse" && before.activeContentRemnants.length > 0) {
    throw new SanitizeAuditError(before.activeContentRemnants);
  }

  const bytes = sanitizePdf(srcBuf, opts);
  const after = analyzeHiddenRevisions(bytes);

  return {
    bytes,
    policy,
    before,
    after,
    historyCollapsed:
      before.revisionCount > 1 && after.revisionCount === 1 && after.totalShadowedObjects === 0,
    remnantsAcknowledgedDestroyed:
      policy === "acknowledge" ? before.activeContentRemnants.length : 0
  };
}
