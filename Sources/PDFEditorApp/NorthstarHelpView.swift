import SwiftUI

/// Built-in help surface (MAD-I5): the app's differentiated concepts get one
/// honest paragraph each. Static content by design — no help-book bundle, no
/// network fetch, no claims about features that do not exist.
struct NorthstarHelpView: View {
  fileprivate enum HelpTopic: String, CaseIterable, Identifiable {
    case exportOnlyModel
    case adaptiveCommands
    case commandPalette
    case formReview
    case readingModes
    case printing
    case securityVault
    case recovery

    var id: String { rawValue }

    var title: String {
      switch self {
      case .exportOnlyModel: return "The Export-Only Model"
      case .adaptiveCommands: return "Adaptive Commands"
      case .commandPalette: return "Command Palette (⌘K)"
      case .formReview: return "Form Review"
      case .readingModes: return "Reading Modes"
      case .printing: return "Printing"
      case .securityVault: return "Security Vault"
      case .recovery: return "Recovery & Autosave"
      }
    }

    @ViewBuilder var detail: some View {
      switch self {
      case .exportOnlyModel:
        helpSection(
          "Northstar never overwrites your source PDF.",
          "Save… (⌘S) and Export Copy… (⇧⌘E) create a separate edited PDF that contains your changes. The original file on disk stays exactly as it was, which is why replacing a document or closing a window asks about unexported changes instead of silently saving.")
      case .adaptiveCommands:
        helpSection(
          "Commands appear when they can act.",
          "Menus and inspector actions are enabled by the document's actual state and your current editor mode (Read, Fill, Sign, Edit). A command that cannot run right now is disabled with an explanation, rather than pretending to succeed.")
      case .commandPalette:
        helpSection(
          "Every command, one keystroke away.",
          "Press ⌘K to open the command palette. It fuzzy-searches all commands with their shortcuts and hints, so you can act without hunting through menus.")
      case .formReview:
        helpSection(
          "Confirm or reject detected fields.",
          "When Northstar detects form fields, the Form Review menu (and the inspector) lets you confirm a suggestion with ⌘⏎ or reject it with ⇧⌘⌫. Confirmed fields are learned for this document so future suggestions rank better.")
      case .readingModes:
        helpSection(
          "Four ways to read the same document.",
          "⌘1 Study (dense text and annotations), ⌘2 Skim (minimal chrome), ⌘3 Reference (tinted, spaced), ⌘4 Review (change tracking). Zoom with ⌘+ / ⌘- / ⌘0 for actual size.")
      case .printing:
        helpSection(
          "Print through the standard dialog.",
          "File ▸ Print… (⌘P) sends the current document — including your edits — to the standard macOS print dialog, with page-range and printer controls as in any Mac app.")
      case .securityVault:
        helpSection(
          "Sensitive documents stay contained.",
          "The Security Vault (⌘8) holds documents that should not mix with normal browsing: their state is tracked separately, and export from the vault goes through the same export-only gate as everything else.")
      case .recovery:
        helpSection(
          "Work is preserved across sessions.",
          "Edits are autosaved on a short debounce and flushed before any document switch, so switching documents never silently drops in-flight work. Closing a dirty window offers to keep a recoverable session; the Document Browser lists it for restoration.")
      }
    }

    private func helpSection(_ headline: String, _ body: String) -> some View {
      VStack(alignment: .leading, spacing: 10) {
        Text(headline)
          .font(.title3.bold())
        Text(body)
          .font(.body)
          .foregroundStyle(.primary)
        Spacer()
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 24)
      .padding(.top, 20)
    }
  }

  @State private var selectedTopic: HelpTopic = .exportOnlyModel

  var body: some View {
    NavigationSplitView {
      List(HelpTopic.allCases, selection: $selectedTopic) { topic in
        Label(topic.title, systemImage: symbol(for: topic))
          .tag(topic)
      }
      .navigationSplitViewColumnWidth(min: 200, ideal: 220)
    } detail: {
      selectedTopic.detail
    }
    .frame(minWidth: 640, minHeight: 480)
  }

  private func symbol(for topic: HelpTopic) -> String {
    switch topic {
    case .exportOnlyModel: return "arrow.down.doc"
    case .adaptiveCommands: return "slider.horizontal.3"
    case .commandPalette: return "command"
    case .formReview: return "checklist"
    case .readingModes: return "book"
    case .printing: return "printer"
    case .securityVault: return "lock.shield"
    case .recovery: return "clock.arrow.circlepath"
    }
  }
}
