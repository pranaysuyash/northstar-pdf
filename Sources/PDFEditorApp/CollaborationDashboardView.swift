import SwiftUI
import PDFEditorCore

/// Collaboration dashboard showing all partner packages, merge status,
/// and unresolved conflicts across documents.
///
/// First principle: visibility is trust. The user sees everything —
/// every package, every conflict, every resolution — at a glance.
///
/// Doctrine alignment:
/// - §3: Do things smartly — single view, no navigation maze
/// - §5: Evidence-based — every status backed by data
/// - §8: Capability activation — dashboard only shows when packages exist
struct CollaborationDashboardView: View {
  @ObservedObject var manager: CollaborationManager

  var body: some View {
    VStack(spacing: 0) {
      if manager.packages.isEmpty {
        emptyState
      } else {
        // Summary header
        summaryHeader
        Divider()

        // Main content
        HSplitView {
          // Left: Package list
          packageListPanel
            .frame(minWidth: 300, idealWidth: 380)

          // Right: Conflicts panel
          conflictsPanel
            .frame(minWidth: 350, idealWidth: 450)
        }
      }
    }
    .navigationTitle("Collaboration")
    .frame(minWidth: 700, minHeight: 500)
  }

  // MARK: - Empty State

  private var emptyState: some View {
    VStack(spacing: 20) {
      Spacer()
      Image(systemName: "person.2.circle")
        .font(.system(size: 56))
        .foregroundColor(.secondary.opacity(0.5))

      Text("No Collaboration Packages")
        .font(.title3.bold())

      Text("Import a partner's annotation package to start collaborating.\nPackages are file-level bundles — no cloud sync required.")
        .multilineTextAlignment(.center)
        .foregroundColor(.secondary)
        .font(.subheadline)

      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: - Summary Header

  private var summaryHeader: some View {
    let summary = manager.dashboardSummary
    return HStack(spacing: 20) {
      // Package count
      StatBadge(
        count: summary.totalPackages,
        label: "Packages",
        color: .primary,
        icon: "shippingbox"
      )

      // Merged
      if summary.mergedCount > 0 {
        StatBadge(
          count: summary.mergedCount,
          label: "Merged",
          color: .green,
          icon: "checkmark.circle"
        )
      }

      // Resolved
      if summary.resolvedCount > 0 {
        StatBadge(
          count: summary.resolvedCount,
          label: "Resolved",
          color: .green,
          icon: "checkmark.seal"
        )
      }

      // Pending
      if summary.pendingCount > 0 {
        StatBadge(
          count: summary.pendingCount,
          label: "Pending",
          color: .blue,
          icon: "clock"
        )
      }

      // Conflicts (highlighted)
      if summary.totalUnresolvedConflicts > 0 {
        StatBadge(
          count: summary.totalUnresolvedConflicts,
          label: "Conflicts",
          color: .orange,
          icon: "exclamationmark.triangle"
        )
      }

      // Rejected
      if summary.rejectedCount > 0 {
        StatBadge(
          count: summary.rejectedCount,
          label: "Rejected",
          color: .red,
          icon: "xmark.circle"
        )
      }

      Spacer()

      // Document count
      Text("\(summary.documentsInvolved) document\(summary.documentsInvolved == 1 ? "" : "s")")
        .font(.caption)
        .foregroundColor(.secondary)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }

  // MARK: - Package List Panel

  private var packageListPanel: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("Partner Packages")
        .font(.headline)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)

      Divider()

      ScrollView {
        LazyVStack(spacing: 8) {
          ForEach(sortedPackages) { record in
            PackageCard(record: record, manager: manager)
          }
        }
        .padding(12)
      }
    }
  }

  private var sortedPackages: [PartnerPackageRecord] {
    manager.packages.sorted { a, b in
      // Conflicts first, then pending, then by date
      let statusOrder: (MergeStatus) -> Int = { status in
        switch status {
        case .conflicts: return 0
        case .pending: return 1
        case .merged: return 2
        case .resolved: return 3
        case .rejected: return 4
        }
      }
      let aOrder = statusOrder(a.mergeStatus)
      let bOrder = statusOrder(b.mergeStatus)
      if aOrder != bOrder { return aOrder < bOrder }
      return a.importedAt > b.importedAt
    }
  }

  // MARK: - Conflicts Panel

  private var conflictsPanel: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text("Unresolved Conflicts")
          .font(.headline)
        Spacer()
        let unresolved = manager.conflicts.filter { !$0.isResolved }
        if !unresolved.isEmpty {
          Text("\(unresolved.count)")
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.orange.opacity(0.15))
            .foregroundColor(.orange)
            .cornerRadius(10)
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 10)

      Divider()

      let grouped = manager.unresolvedConflictsByDocument
      if grouped.isEmpty {
        allConflictsResolvedView
      } else {
        ScrollView {
          LazyVStack(spacing: 16) {
            ForEach(grouped, id: \.documentName) { group in
              DocumentConflictSection(
                documentName: group.documentName,
                conflicts: group.conflicts,
                manager: manager
              )
            }
          }
          .padding(12)
        }
      }
    }
  }

  private var allConflictsResolvedView: some View {
    VStack(spacing: 16) {
      Spacer()
      Image(systemName: "checkmark.seal.fill")
        .font(.system(size: 36))
        .foregroundColor(.green)
      Text("All Conflicts Resolved")
        .font(.subheadline.bold())
        .foregroundColor(.secondary)
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

// MARK: - Stat Badge

struct StatBadge: View {
  let count: Int
  let label: String
  let color: Color
  let icon: String

  var body: some View {
    VStack(spacing: 4) {
      HStack(spacing: 4) {
        Image(systemName: icon)
          .font(.caption2)
        Text("\(count)")
          .font(.title3.bold().monospacedDigit())
      }
      .foregroundColor(color)

      Text(label)
        .font(.caption2)
        .foregroundColor(.secondary)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(color.opacity(0.08))
    .cornerRadius(8)
  }
}

// MARK: - Package Card

struct PackageCard: View {
  let record: PartnerPackageRecord
  @ObservedObject var manager: CollaborationManager

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      // Header row
      HStack {
        // Author avatar circle
        Circle()
          .fill(Color.blue.opacity(0.15))
          .frame(width: 28, height: 28)
          .overlay(
            Text(String(record.package.authorName.prefix(1)).uppercased())
              .font(.caption.bold())
              .foregroundColor(.blue)
          )

        VStack(alignment: .leading, spacing: 1) {
          Text(record.package.authorName)
            .font(.subheadline.bold())
          Text(record.documentName)
            .font(.caption2)
            .foregroundColor(.secondary)
        }

        Spacer()

        // Status badge
        statusBadge(record.mergeStatus)
      }

      // Package info
      HStack(spacing: 12) {
        Label("\(record.package.annotations.count) marks", systemImage: "pencil.and.outline")
        Label("\(record.package.summary.pageCount) pages", systemImage: "doc.richtext")
        Label(formattedDate(record.importedAt), systemImage: "clock")
      }
      .font(.caption2)
      .foregroundColor(.secondary)

      // Author note
      if !record.package.authorNote.isEmpty {
        Text("\"\(record.package.authorNote)\"")
          .font(.caption.italic())
          .foregroundColor(.secondary)
          .lineLimit(2)
          .padding(6)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(Color.gray.opacity(0.06))
          .cornerRadius(4)
      }

      // Conflict count warning
      if record.unresolvedConflictCount > 0 {
        HStack(spacing: 4) {
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.caption2)
          Text("\(record.unresolvedConflictCount) unresolved conflict\(record.unresolvedConflictCount == 1 ? "" : "s")")
            .font(.caption.bold())
        }
        .foregroundColor(.orange)
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(4)
      }
    }
    .padding(12)
    .background(Color(NSColor.controlBackgroundColor))
    .cornerRadius(10)
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .stroke(statusBorder, lineWidth: 1)
    )
  }

  private func statusBadge(_ status: MergeStatus) -> some View {
    Label(status.displayName, systemImage: status.symbolName)
      .font(.caption2.bold())
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(statusColor(status).opacity(0.12))
      .foregroundColor(statusColor(status))
      .cornerRadius(6)
  }

  private func statusColor(_ status: MergeStatus) -> Color {
    switch status {
    case .pending: return .blue
    case .merged: return .green
    case .conflicts: return .orange
    case .resolved: return .green
    case .rejected: return .red
    }
  }

  private var statusBorder: Color {
    switch record.mergeStatus {
    case .conflicts: return .orange.opacity(0.4)
    case .rejected: return .red.opacity(0.3)
    case .pending: return .blue.opacity(0.2)
    default: return .gray.opacity(0.15)
    }
  }

  private func formattedDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }
}

// MARK: - Document Conflict Section

struct DocumentConflictSection: View {
  let documentName: String
  let conflicts: [ConflictRecord]
  @ObservedObject var manager: CollaborationManager

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      // Document header
      HStack {
        Image(systemName: "doc.text")
          .foregroundColor(.secondary)
        Text(documentName)
          .font(.subheadline.bold())
        Spacer()
        Text("\(conflicts.count) conflict\(conflicts.count == 1 ? "" : "s")")
          .font(.caption)
          .foregroundColor(.orange)
      }

      // Conflict cards
      ForEach(conflicts) { record in
        DashboardConflictCard(record: record, manager: manager)
      }
    }
    .padding(12)
    .background(Color.orange.opacity(0.03))
    .cornerRadius(10)
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .stroke(Color.orange.opacity(0.15), lineWidth: 1)
    )
  }
}

// MARK: - Dashboard Conflict Card

struct DashboardConflictCard: View {
  let record: ConflictRecord
  @ObservedObject var manager: CollaborationManager

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      // Reason
      HStack {
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.caption2)
          .foregroundColor(.orange)
        Text(record.conflict.reason.description)
          .font(.caption.bold())
          .foregroundColor(.orange)
        Spacer()
        Text("Page \(record.conflict.localMark.pageIndex + 1)")
          .font(.caption2)
          .foregroundColor(.secondary)
      }

      // Side-by-side text preview
      HStack(spacing: 8) {
        // Local
        VStack(alignment: .leading, spacing: 2) {
          HStack(spacing: 3) {
            Circle().fill(Color.blue).frame(width: 5, height: 5)
            Text("Yours")
              .font(.caption2.bold())
              .foregroundColor(.blue)
          }
          if !record.conflict.localMark.selectedText.isEmpty {
            Text(record.conflict.localMark.selectedText)
              .font(.caption2)
              .lineLimit(2)
              .padding(4)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(Color.blue.opacity(0.05))
              .cornerRadius(3)
          }
          if !record.conflict.localMark.note.isEmpty {
            Text(record.conflict.localMark.note)
              .font(.caption2)
              .foregroundColor(.secondary)
              .lineLimit(1)
          }
        }

        // Partner
        VStack(alignment: .leading, spacing: 2) {
          HStack(spacing: 3) {
            Circle().fill(Color.green).frame(width: 5, height: 5)
            Text("Theirs")
              .font(.caption2.bold())
              .foregroundColor(.green)
          }
          if !record.conflict.partnerMark.selectedText.isEmpty {
            Text(record.conflict.partnerMark.selectedText)
              .font(.caption2)
              .lineLimit(2)
              .padding(4)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(Color.green.opacity(0.05))
              .cornerRadius(3)
          }
          if !record.conflict.partnerMark.note.isEmpty {
            Text(record.conflict.partnerMark.note)
              .font(.caption2)
              .foregroundColor(.secondary)
              .lineLimit(1)
          }
        }
      }

      // Resolution hint
      if record.conflict.hintConfidence >= 0.5 {
        HStack(spacing: 6) {
          Image(systemName: "lightbulb.fill")
            .font(.caption2)
            .foregroundColor(.yellow)
          Text(record.conflict.hintExplanation)
            .font(.caption2)
            .foregroundColor(.secondary)
          Spacer()
          Text("\(Int(record.conflict.hintConfidence * 100))%")
            .font(.caption2.monospacedDigit())
            .foregroundColor(.secondary.opacity(0.6))
        }
        .padding(6)
        .background(Color.yellow.opacity(0.06))
        .cornerRadius(4)
      }

      // Resolution picker
      Picker("Resolution", selection: Binding(
        get: { record.resolution },
        set: { newResolution in
          if let res = newResolution {
            manager.resolveConflict(conflictID: record.id, resolution: res)
          }
        }
      )) {
        Text("Unresolved").tag(nil as ConflictResolution?)
        ForEach(ConflictResolution.allCases) { res in
          HStack {
            if res == record.conflict.suggestedResolution {
              Image(systemName: "lightbulb.fill")
                .font(.caption2)
            }
            Text(res.displayName)
          }.tag(res as ConflictResolution?)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
    }
    .padding(10)
    .background(Color(NSColor.controlBackgroundColor))
    .cornerRadius(8)
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(record.isResolved ? Color.green.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
    )
  }
}
