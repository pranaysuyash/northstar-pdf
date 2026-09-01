import PDFEditorCore
import PDFEditorRecovery
import SwiftUI

/// The native review moment before `AppModel.export()` opens the save panel.
/// It is intentionally a sheet because the user is making an explicit export
/// decision, while the document context remains visible behind it.
struct ExportReviewReceiptView: View {
  @Bindable var model: AppModel
  let onContinue: () -> Void
  @Environment(\.dismiss) private var dismiss

  private var receipt: ExportReviewReceipt {
    model.exportReviewReceipt
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
      Divider()

      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          operationSection
          checksSection
          sourceFingerprint
        }
        .padding(20)
      }

      Divider()
      footer
        .padding(16)
    }
    .frame(width: 620, height: 560)
    .accessibilityElement(children: .contain)
  }

  private var header: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: stateSymbol)
        .font(.title2)
        .foregroundStyle(stateColor)

      VStack(alignment: .leading, spacing: 4) {
        Text("Review \(receipt.profile.title)")
          .font(.title3.weight(.semibold))
        Text(receipt.sourceFileName)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(1)
        Text(stateMessage)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer()
    }
    .padding(20)
  }

  private var operationSection: some View {
    GroupBox {
      if receipt.operationSummaries.isEmpty {
          Label(receipt.profile.detail, systemImage: "doc.on.doc")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      } else {
        VStack(alignment: .leading, spacing: 8) {
          ForEach(receipt.operationSummaries) { summary in
            HStack(spacing: 10) {
              Image(systemName: summary.containsDestructiveOperation ? "exclamationmark.triangle" : "checkmark.circle")
                .foregroundStyle(summary.containsDestructiveOperation ? Color.orange : Color.secondary)
              Text(summary.title)
                .font(.callout)
              Spacer()
              Text("\(summary.count)")
                .font(.callout.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
            }
          }
        }
      }
    } label: {
      Label("Included changes", systemImage: "list.bullet.rectangle")
        .font(.headline)
    }
  }

  private var checksSection: some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 12) {
        ForEach(receipt.checks) { check in
          HStack(alignment: .top, spacing: 10) {
            Image(systemName: checkSymbol(for: check.state))
              .foregroundStyle(checkColor(for: check.state))
              .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
              Text(check.title)
                .font(.callout.weight(.medium))
              Text(check.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
        }
      }
    } label: {
      Label("Checks", systemImage: "checklist")
        .font(.headline)
    }
  }

  @ViewBuilder
  private var sourceFingerprint: some View {
    if let digest = receipt.sourceDigest {
      VStack(alignment: .leading, spacing: 4) {
        Text("Source fingerprint")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        Text(digest)
          .font(.caption2.monospaced())
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
      }
    }
  }

  private var footer: some View {
    HStack {
      Button("Cancel") {
        dismiss()
      }
      .keyboardShortcut(.cancelAction)

      Spacer()

      Button("Continue to Save…", action: onContinue)
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.defaultAction)
        .disabled(!receipt.canProceed)
        .help(receipt.canProceed
          ? "Open the save panel for a separate export copy."
          : "Resolve the blocked permission or operation condition before exporting.")
    }
  }

  private var stateMessage: String {
    switch receipt.state {
    case .ready:
      return "The export path is available. Output validation will run after saving."
    case .needsReview:
      return "Review the warnings or high-impact changes before continuing."
    case .blocked:
      return "Export is blocked until the unresolved condition is corrected."
    case .validated:
      return "This receipt represents an export that has already passed validation."
    }
  }

  private var stateSymbol: String {
    switch receipt.state {
    case .ready: return "arrow.right.circle"
    case .needsReview: return "exclamationmark.triangle"
    case .blocked: return "nosign"
    case .validated: return "checkmark.seal"
    }
  }

  private var stateColor: Color {
    switch receipt.state {
    case .ready: return .accentColor
    case .needsReview: return .orange
    case .blocked: return .red
    case .validated: return .green
    }
  }

  private func checkSymbol(for state: ExportReviewCheckState) -> String {
    switch state {
    case .confirmed: return "checkmark.circle.fill"
    case .pending: return "clock"
    case .needsReview: return "exclamationmark.triangle.fill"
    case .blocked: return "xmark.octagon.fill"
    }
  }

  private func checkColor(for state: ExportReviewCheckState) -> Color {
    switch state {
    case .confirmed: return .green
    case .pending: return .secondary
    case .needsReview: return .orange
    case .blocked: return .red
    }
  }
}
