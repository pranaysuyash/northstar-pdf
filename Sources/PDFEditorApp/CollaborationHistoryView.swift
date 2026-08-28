import SwiftUI
import PDFEditorCore

/// Timeline view of all collaboration events — who did what, when, and which resolutions were chosen.
///
/// First principle: history is trust. The user can see every action ever taken
/// on their collaboration data, with full provenance.
struct CollaborationHistoryView: View {
  @ObservedObject var history: CollaborationHistory

  @State private var selectedFilter: HistoryEventKind?
  @State private var selectedDocument: String?
  @State private var selectedPartner: String?

  var body: some View {
    VStack(spacing: 0) {
      // Filter bar
      filterBar
      Divider()

      // Timeline
      if filteredEvents.isEmpty {
        emptyState
      } else {
        ScrollView {
          LazyVStack(spacing: 0) {
            ForEach(filteredEvents) { event in
              HistoryEventRow(event: event)
            }
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
        }
      }

      // Summary footer
      Divider()
      summaryFooter
    }
    .navigationTitle("Collaboration History")
  }

  // MARK: - Filter Bar

  private var filterBar: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        // Event kind filter
        Picker("Event", selection: $selectedFilter) {
          Text("All Events").tag(nil as HistoryEventKind?)
          ForEach(HistoryEventKind.allCases) { kind in
            Label(kind.displayName, systemImage: kind.symbolName).tag(kind as HistoryEventKind?)
          }
        }
        .pickerStyle(.menu)
        .frame(width: 160)

        // Document filter
        if !history.documentNames.isEmpty {
          Picker("Document", selection: $selectedDocument) {
            Text("All Documents").tag(nil as String?)
            ForEach(history.documentNames, id: \String.self) { name in
              Text(name).tag(name as String?)
            }
          }
          .pickerStyle(.menu)
          .frame(width: 160)
        }

        // Partner filter
        if !history.partnerNames.isEmpty {
          Picker("Partner", selection: $selectedPartner) {
            Text("All Partners").tag(nil as String?)
            ForEach(history.partnerNames, id: \String.self) { name in
              Text(name).tag(name as String?)
            }
          }
          .pickerStyle(.menu)
          .frame(width: 140)
        }

        Spacer()

        // Event count
        Text("\(filteredEvents.count) event\\(filteredEvents.count == 1 ? \"\" : \"s\")")
          .font(.caption)
          .foregroundColor(.secondary)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
    }
  }

  // MARK: - Empty State

  private var emptyState: some View {
    VStack(spacing: 16) {
      Spacer()
      Image(systemName: "clock.arrow.circlepath")
        .font(.system(size: 40))
        .foregroundColor(.secondary.opacity(0.5))
      Text("No History Events")
        .font(.subheadline.bold())
        .foregroundColor(.secondary)
      Text("Collaboration events will appear here as you import packages, merge annotations, and resolve conflicts.")
        .font(.caption)
        .foregroundColor(.secondary.opacity(0.7))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 60)
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: - Summary Footer

  private var summaryFooter: some View {
    let s = history.summary
    return HStack(spacing: 16) {
      Label("\(s.totalMerges) merges", systemImage: "arrow.triangle.merge")
      Label("\(s.totalResolutions) resolutions", systemImage: "checkmark.circle")
      if s.totalReverts > 0 {
        Label("\(s.totalReverts) reverts", systemImage: "arrow.uturn.backward")
          .foregroundColor(.orange)
      }
      if s.suggestionFollowRate > 0 {
        Label("\(Int(s.suggestionFollowRate * 100))% followed suggestions", systemImage: "lightbulb")
          .foregroundColor(.yellow)
      }
      Spacer()
      if let lastDate = s.lastActivityDate {
        Text("Last: \(lastDate.formatted(.relative(presentation: .named)))")
          .font(.caption2)
          .foregroundColor(.secondary)
      }
    }
    .font(.caption)
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
  }

  // MARK: - Filtering

  private var filteredEvents: [CollaborationHistoryEvent] {
    history.events.filter { event in
      if let filter = selectedFilter, event.kind != filter { return false }
      if let doc = selectedDocument, event.documentName != doc { return false }
      if let partner = selectedPartner, event.partnerName != partner { return false }
      return true
    }
  }
}

// MARK: - History Event Row

/// A single event in the history timeline.
struct HistoryEventRow: View {
  let event: CollaborationHistoryEvent

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      // Timeline dot
      VStack(spacing: 0) {
        Circle()
          .fill(eventColor)
          .frame(width: 10, height: 10)
        Rectangle()
          .fill(Color.secondary.opacity(0.15))
          .frame(width: 1)
      }
      .frame(width: 10)

      // Event content
      VStack(alignment: .leading, spacing: 6) {
        // Header
        HStack {
          Image(systemName: event.kind.symbolName)
            .font(.caption)
            .foregroundColor(eventColor)

          Text(event.kind.displayName)
            .font(.caption.bold())

          if let partner = event.partnerName {
            Text("with")
              .font(.caption)
              .foregroundColor(.secondary)
            Text(partner)
              .font(.caption.bold())
          }

          Spacer()

          Text(event.timestamp.formatted(.relative(presentation: .named)))
            .font(.caption2)
            .foregroundColor(.secondary)
        }

        // Summary
        Text(event.summary)
          .font(.subheadline)
          .foregroundColor(.primary.opacity(0.8))

        // Details row
        HStack(spacing: 12) {
          Label(event.actor, systemImage: "person")
          Label(event.documentName, systemImage: "doc")
          if event.markCount > 0 {
            Label("\(event.markCount) marks", systemImage: "pencil.and.outline")
          }
          if event.conflictCount > 0 {
            Label("\(event.conflictCount) conflict\\(event.conflictCount == 1 ? \"\" : \"s\")", systemImage: "exclamationmark.triangle")
              .foregroundColor(.orange)
          }
        }
        .font(.caption2)
        .foregroundColor(.secondary)

        // Resolution details
        if !event.resolutions.isEmpty {
          resolutionDetails
        }
      }
    }
    .padding(.vertical, 8)
  }

  private var resolutionDetails: some View {
    VStack(alignment: .leading, spacing: 4) {
      ForEach(0..<event.resolutions.count, id: \.self) { index in
        let detail = event.resolutions[index]
        HStack(spacing: 6) {
          Circle()
            .fill(detail.followedSuggestion ? Color.green : Color.orange)
            .frame(width: 5, height: 5)

          Text("Page \(detail.pageNumber)")
            .font(.caption2.monospacedDigit())

          Text("·")
            .foregroundColor(.secondary)

          Text(detail.conflictReason)
            .font(.caption2)
            .foregroundColor(.secondary)

          Text("→")
            .foregroundColor(.secondary)

          Text(detail.resolution.displayName)
            .font(.caption2.bold())

          if detail.followedSuggestion {
            Image(systemName: "lightbulb.fill")
              .font(.caption2)
              .foregroundColor(.yellow)
          } else {
            Text("suggested \(detail.suggestedResolution.displayName)")
              .font(.caption2)
              .foregroundColor(.secondary.opacity(0.6))
          }
        }
      }
    }
    .padding(8)
    .background(Color.gray.opacity(0.06))
    .cornerRadius(6)
  }

  private var eventColor: Color {
    switch event.kind {
    case .packageImported: return .blue
    case .mergeExecuted: return .green
    case .conflictResolved: return .green
    case .mergeReverted: return .orange
    case .packageRejected: return .red
    case .packageRemoved: return .secondary
    }
  }
}
