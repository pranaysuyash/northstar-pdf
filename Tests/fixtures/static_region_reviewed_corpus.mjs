/*
 * Reviewed semantic ledger for the real Form 6 static-form fixture.
 *
 * This is intentionally not a detector output. It records what a human review
 * says exists on the document, including targets the detector is expected to
 * miss or abstain on. Geometry truth is represented by the page and label cue;
 * exact rectangles remain a follow-up annotation lane.
 */
export const reviewedStaticRegionCorpus = Object.freeze({
  version: "2026-08-24.1",
  fixture: "docs/benchmarks/pdfkit-form6-run-2026-08-23/noop.pdf",
  sourceDigest: "81e59007c14307ad7a40a99f051363b99c9a5d78c880f67507082f12ff72cef0",
  reviewStatus: "reviewed-semantic-ledger",
  metricsScope: "label-associated candidate recall and precision proxy; not geometric IoU",
  targets: Object.freeze([
    ["F6-01", 0, ["form number", "office form number"], "singleText"],
    ["F6-02", 0, ["assembly constituency"], "singleText"],
    ["F6-03", 0, ["parliamentary constituency"], "singleText"],
    ["F6-04", 0, ["space for pasting", "photograph"], "unknown"],
    ["F6-05", 0, ["official language", "first name followed"], "characterGrid"],
    ["F6-06", 0, ["surname"], "characterGrid"],
    ["F6-07", 0, ["english in block letters"], "characterGrid"],
    ["F6-08", 0, ["surname"], "characterGrid"],
    ["F6-09", 0, ["relative type", "father", "mother", "husband", "wife"], "radioGroup"],
    ["F6-10", 0, ["relative name", "official language"], "characterGrid"],
    ["F6-11", 0, ["relative name", "english"], "characterGrid"],
    ["F6-12", 0, ["mobile", "telephone"], "characterGrid"],
    ["F6-13", 0, ["email"], "singleText"],
    ["F6-14", 0, ["aadhaar"], "radioGroup"],
    ["F6-15", 0, ["gender", "male", "female"], "radioGroup"],
    ["F6-16", 0, ["date of birth", "dob"], "characterGrid"],
    ["F6-17", 0, ["proof", "date of birth"], "radioGroup"],
    ["F6-18", 0, ["other date"], "singleText"],
    ["F6-19", 0, ["present residence", "address"], "singleText"],
    ["F6-20", 1, ["residence proof"], "radioGroup"],
    ["F6-21", 1, ["other residence"], "singleText"],
    ["F6-22", 1, ["disability category", "disability"], "checkbox"],
    ["F6-23", 1, ["other disability"], "singleText"],
    ["F6-24", 1, ["percentage", "certificate"], "singleText"],
    ["F6-25", 1, ["family member", "relationship"], "singleText"],
    ["F6-26", 1, ["place of birth", "declaration"], "singleText"],
    ["F6-27", 1, ["residence since"], "singleText"],
    ["F6-28", 1, ["age proof", "document"], "singleText"],
    ["F6-29", 1, ["declaration date", "declaration"], "singleText"],
    ["F6-30", 1, ["signature", "thumb impression"], "signature"],
    ["F6-31", 1, ["acknowledgement", "acknowledgment"], "singleText"],
    ["F6-32", 1, ["received applicant name"], "singleText"],
    ["F6-33", 1, ["ero", "aero", "blo", "signature"], "signature"]
  ].map(([id, pageIndex, cues, expectedMode]) => ({ id, pageIndex, cues, expectedMode }))),
  nonTargets: Object.freeze(["instruction", "declaration", "page border", "table border", "photograph instruction", "logo"])
});

export function candidateMatchesTarget(candidate, target) {
  const text = String(candidate.labelText || candidate.evidenceItems?.[0]?.text || "").toLowerCase();
  return candidate.pageIndex === target.pageIndex
    && target.cues.some((cue) => text.includes(cue))
    && (target.expectedMode === "unknown" || candidate.entryMode === target.expectedMode);
}
