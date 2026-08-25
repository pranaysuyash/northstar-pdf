// pdf-hidden-revision-analyzer.mjs
//
// RG-097 remaining gate: hidden-revision analysis.
//
// Incremental updates (the RG-002 source-preserving writer, and any producer
// that appends rather than rewrites) leave PRIOR REVISIONS physically present
// in the file bytes: older object bodies stay on disk but become unreachable
// once a newer xref re-defines their object numbers. A document whose CURRENT
// revision is fully sanitized can still carry JavaScript, Launch actions, or
// removed metadata inside shadowed earlier revisions. qpdf/PDFKit do not
// surface this; it must be analyzed directly from the /Prev chain.
//
// This analyzer walks the revision chain newest→oldest and reports, per
// revision: defined objects, objects still visible at that point in history,
// and objects SHADOWED by a newer definition — scanning shadowed bodies for
// active-content markers. Local-first: pure byte parsing, no egress.

import { readSourceXref, readXrefAt } from "./pdf-incremental-form-writer.mjs";

export const HIDDEN_REVISION_ACTIVE_MARKERS = Object.freeze([
  "/JS",
  "/JavaScript",
  "/Launch",
  "/OpenAction",
  "/SubmitForm",
  "/EmbeddedFile"
]);

const MAX_REVISIONS = 64;

function objectBodyAt(buf, offset) {
  const s = buf.toString("latin1", offset);
  const end = s.indexOf("endobj");
  return end < 0 ? s : s.slice(0, end);
}

function parsePrevOffset(trailer) {
  const raw = trailer?.["/Prev"];
  if (!raw) return null;
  const off = parseInt(String(raw).trim(), 10);
  return Number.isFinite(off) ? off : null;
}

export function analyzeHiddenRevisions(srcBuf) {
  const revisions = [];
  const remnants = [];
  const seen = new Set();
  let x;
  try {
    x = readSourceXref(srcBuf);
  } catch (err) {
    return {
      revisionCount: 0,
      chainOffsets: [],
      totalShadowedObjects: 0,
      activeContentRemnants: [],
      hasHiddenRevisions: false,
      error: `unreadable xref: ${err.message}`,
      revisions: []
    };
  }

  let index = 0;
  while (true) {
    let newlyVisible = 0;
    const shadowedNums = [];
    for (const [num, meta] of x.offsets) {
      if (seen.has(num)) {
        shadowedNums.push(num);
        if (meta.compressed || !meta.offset) continue;
        try {
          const body = objectBodyAt(srcBuf, meta.offset);
          const marker = HIDDEN_REVISION_ACTIVE_MARKERS.find((m) => body.includes(m));
          if (marker) remnants.push({ revision: index, objNum: num, marker });
        } catch {
          // unreadable span: report as remnant-unknown is out of scope here
        }
      } else {
        newlyVisible++;
      }
    }
    revisions.push({
      index,
      type: x.type,
      xrefOffset: x.offset,
      definedObjects: x.offsets.size,
      newlyVisible,
      shadowed: shadowedNums.length,
      shadowedObjectNumbers: shadowedNums,
      prevOffset: parsePrevOffset(x.trailer)
    });
    for (const num of x.offsets.keys()) seen.add(num);

    const prevOff = parsePrevOffset(x.trailer);
    if (prevOff == null || index >= MAX_REVISIONS) break;
    try {
      x = readXrefAt(srcBuf, prevOff);
    } catch {
      break;
    }
    index++;
  }

  const totalShadowed = revisions.reduce((a, r) => a + r.shadowed, 0);
  return {
    revisionCount: revisions.length,
    chainOffsets: revisions.map((r) => r.xrefOffset),
    totalShadowedObjects: totalShadowed,
    activeContentRemnants: remnants,
    hasHiddenRevisions: revisions.length > 1 && totalShadowed > 0,
    revisions
  };
}
