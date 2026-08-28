import SwiftUI
import PDFEditorCore

/// SwiftUI view for reviewing and resolving annotation merge conflicts.
///
/// Shows:
/// 1. Merge summary (local-only, partner-only, duplicates, conflicts)
/// 2. Conflict list with resolution pickers
/// 3. Accept/Reject per conflict
/// 4. Apply merge button
///
/// Doctrine alignment:
/// - §3: Do things smartly — user controls every merge decision
/// - §5: Evidence-based — full conflict detail shown before resolution
struct CollaborationMergeView: View {
  let localMarks: [AnnotationMark]
  let partnerMarks: [AnnotationMark]
  let partnerName: String
  let documentID: String
  let onMergeComplete: ([AnnotationMark]) -> Void

  @State private var mergeResult: AnnotationMergeResult?
  @State private var conflictResolutions: [UUID: ConflictResolution] = [:]
  @State private var showingApplyConfirmation = false
  @State private var isApplying = false

  var body: some View {
    VStack(spacing: 0) {
      if let result = mergeResult {
        // Header with summary
        mergeSummaryHeader(result)
        Divider()

        if result.conflicts.isEmpty {
          // No conflicts — show clean merge
          noConflictsView(result)
        } else {
          // Conflicts to resolve
          conflictListView(result)
        }

        Divider()
        // Apply button
        applyFooter(result)
      } else {
        // Computing merge
        ProgressView("Analyzing annotations…")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .onAppear { computeMerge() }
      }
    }
    .navigationTitle("Merge Annotations")
    .frame(minWidth: 700, minHeight: 500)
  }

  // MARK: - Summary Header

  private func mergeSummaryHeader(_ result: AnnotationMergeResult) -> some View {
    let s = result.summary
    return HStack(spacing: 16) {
      Image(systemName: s.hasConflicts ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
        .font(.title2)
        .foregroundColor(s.hasConflicts ? .orange : .green)

      VStack(alignment: .leading, spacing: 2) {
        Text("Merge Preview")
          .font(.headline)
        Text(s.description)
          .font(.caption)
          .foregroundColor(.secondary)
      }

      Spacer()

      // Legend
      HStack(spacing: 12) {
        legendDot(color: .blue, label: "Yours (\(s.localOnlyCount))")
        legendDot(color: .green, label: "Theirs (\(s.partnerOnlyCount))")
        legendDot(color: .gray, label: "Shared (\(s.duplicateCount))")
        if s.conflictCount > 0 {
          legendDot(color: .orange, label: "Conflicts (\(s.conflictCount))")
        }
      }
      .font(.caption2)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }

  private func legendDot(color: Color, label: String) -> some View {
    HStack(spacing: 4) {
      Circle().fill(color).frame(width: 8, height: 8)
      Text(label)
    }
  }

  // MARK: - No Conflicts View

  private func noConflictsView(_ result: AnnotationMergeResult) -> some View {
    VStack(spacing: 16) {
      Spacer()
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 48))
        .foregroundColor(.green)
      Text("No Conflicts Found")
        .font(.title3.bold())
      Text("All \(result.partnerOnly.count) partner annotations can be added without conflicts.")
        .foregroundColor(.secondary)
      if result.summary.duplicateCount > 0 {
        Text("\(result.summary.duplicateCount) duplicate annotation\(result.summary.duplicateCount == 1 ? "" : "s") will be removed.")
          .font(.caption)
          .foregroundColor(.secondary)
      }
      Spacer()
    }
  }

  // MARK: - Conflict List View

  private func conflictListView(_ result: AnnotationMergeResult) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("\(result.conflicts.count) Conflict\(result.conflicts.count == 1 ? "" : "s") to Resolve")
        .font(.subheadline.bold())
        .padding(.horizontal, 16)
        .padding(.vertical, 8)

      ScrollView {
        LazyVStack(spacing: 12) {
          ForEach(result.conflicts) { conflict in
            ConflictCard(
              conflict: conflict,
              resolution: Binding(
                get: { conflictResolutions[conflict.id] ?? conflict.resolution },
                set: { conflictResolutions[conflict.id] = $0 }
              )
            )
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
      }
    }
  }

  // MARK: - Apply Footer

  private func applyFooter(_ result: AnnotationMergeResult) -> some View {
    HStack {
      let unresolvedCount = result.conflicts.filter { conflictResolutions[$0.id] == nil }.count
      if unresolvedCount > 0 {
        Text("\(unresolvedCount) conflict\(unresolvedCount == 1 ? "" : "s") unresolved")
          .font(.caption)
          .foregroundColor(.orange)
      }

      Spacer()

      Button("Cancel") {
        onMergeComplete(localMarks)
      }
      .buttonStyle(.bordered)

      Button(action: { showingApplyConfirmation = true }) {
        Label("Apply Merge", systemImage: "checkmark")
      }
      .buttonStyle(.borderedProminent)
      .disabled(result.conflicts.contains { conflictResolutions[$0.id] == nil })
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .alert("Apply Merge?", isPresented: $showingApplyConfirmation) {
      Button("Cancel", role: .cancel) {}
      Button("Apply") { applyMerge(result) }
    } message: {
      Text("This will combine \(result.summary.totalCount) annotations into your document. This action can be undone.")
    }
  }

  // MARK: - Actions

  private func computeMerge() {
    mergeResult = AnnotationMerger.merge(local: localMarks, partner: partnerMarks)
  }

  private func applyMerge(_ result: AnnotationMergeResult) {
    // Apply resolutions to conflicts
    var finalMarks = result.mergedMarks

    // Handle "keep both" — add the partner mark back
    for conflict in result.conflicts {
      let resolution = conflictResolutions[conflict.id] ?? conflict.resolution
      if resolution == .keepBoth {
        finalMarks.append(conflict.partnerMark)
      }
    }

    // Remove duplicates that were already handled
    onMergeComplete(finalMarks)
  }
}

// MARK: - Conflict Card

/// A single conflict card showing both marks and resolution picker.
struct ConflictCard: View {
  let conflict: AnnotationConflict
  @Binding var resolution: ConflictResolution

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      // Conflict reason
      HStack {
        Image(systemName: "exclamationmark.triangle.fill")
          .foregroundColor(.orange)
          .font(.caption)
        Text(conflict.reason.description)
          .font(.caption.bold())
          .foregroundColor(.orange)
        Spacer()
        Text("Page \(conflict.localMark.pageIndex + 1)")
          .font(.caption)
          .foregroundColor(.secondary)
      }

      // Side-by-side comparison
      HStack(spacing: 12) {
        // Local mark
        markColumn(
          title: "Yours",
          mark: conflict.localMark,
          color: .blue
        )

        Divider()

        // Partner mark
        markColumn(
          title: "Theirs",
          mark: conflict.partnerMark,
          color: .green
        )
      }

      // Resolution picker
      Picker("Resolution", selection: $resolution) {
        ForEach(ConflictResolution.allCases) { res in
          Text(res.displayName).tag(res)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()

      // Hint (if available)
      if !conflict.hintExplanation.isEmpty {
        HStack(spacing: 4) {
          Image(systemName: "lightbulb.fill")
            .font(.caption2)
            .foregroundColor(.yellow)
          Text(conflict.hintExplanation)
            .font(.caption2)
            .foregroundColor(.secondary)
          Text("\(Int(conflict.hintConfidence * 100))%")
            .font(.caption2)
            .foregroundColor(.secondary)
        }
      }
    }
    .padding(12)
    .background(Color.orange.opacity(0.05))
    .cornerRadius(10)
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
    )
  }

  private func markColumn(title: String, mark: AnnotationMark, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Circle().fill(color).frame(width: 8, height: 8)
        Text(title)
          .font(.caption.bold())
          .foregroundColor(color)
      }

      HStack(spacing: 4) {
        Image(systemName: mark.type.symbolName)
          .font(.caption2)
        Text(mark.type.displayName)
          .font(.caption2)
        Circle()
          .fill(mark.color.swiftUIColor)
          .frame(width: 6, height: 6)
      }
      .foregroundColor(.secondary)

      if !mark.selectedText.isEmpty {
        Text(mark.selectedText)
          .font(.caption)
          .lineLimit(3)
          .padding(6)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(mark.color.swiftUIColor.opacity(0.1))
          .cornerRadius(4)
      }

      if !mark.note.isEmpty {
        Text(mark.note)
          .font(.caption2)
          .foregroundColor(.secondary)
          .lineLimit(2)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
