#!/bin/bash
# AppModel.swift integrity guard.
#
# This file has twice been reverted to stale editor-buffer snapshots during
# active work (2026-08-25/26). This script detects a revert in seconds and
# restores the last verified content without touching Git.
#
# Usage:
#   tools/verify_appmodel.sh             # check markers; exit 1 on regression
#   tools/verify_appmodel.sh --restore   # restore from the verified snapshot
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="$ROOT/Sources/PDFEditorRecovery/AppModel.swift"
SNAPSHOT="$ROOT/tools/snapshots/AppModel.verified-2026-08-26.swift"

if [[ "${1:-}" == "--restore" ]]; then
  cp "$SNAPSHOT" "$TARGET"
  echo "restored AppModel.swift from verified snapshot"
  exit 0
fi

missing=()
for marker in \
  "private let candidateReviewEventStore: CandidateReviewLearningEventStore" \
  "self.candidateReviewEventStore = candidateReviewEventStore" \
  "private func recordCandidateLearningEvent(" \
  "public var rankedActiveCandidates: \\[RegionCandidate\\]" \
  "private func autoOCRIfNeededForFillMode(pageIndex:" \
  "private func mergeOCRObservations(" \
  "private nonisolated static func runRecognition(" \
  "public func renameCandidate(" \
  "CandidateReviewLearningEventFactory.make(" \
  "public private(set) var lastValueSuggestions"
do
  grep -q "$marker" "$TARGET" || missing+=("$marker")
done

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "REGRESSION DETECTED — AppModel.swift is missing markers:"
  printf '  %s\n' "${missing[@]}"
  echo "A stale editor buffer likely overwrote it. Fix:"
  echo "  tools/verify_appmodel.sh --restore"
  exit 1
fi

echo "AppModel.swift integrity OK (${#missing[@]} missing of 10 markers checked)"
