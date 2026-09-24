import AppKit
import PDFEditorCore
import PDFEditorRecovery
import SwiftUI

/// Island 2: Floating Quick Action & Verified Export Dock.
///
/// Designed per the Floating Glass Islands Architecture (MAD-I6 / Sprint 1 Phase 1).
/// Positioned at the top right (.primaryAction) to anchor high-confidence mutation actions
/// (Undo/Redo, Verified Export, and Workspace Tools) without competing with canvas space.
public struct ActionIslandView: View {
  @Bindable var model: AppModel
  let onBatchMerge: () -> Void
  let openGovernance: () -> Void
  let openCompanion: () -> Void
  let onHumanReview: () -> Void

  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.colorScheme) private var colorScheme

  public init(
    model: AppModel,
    onBatchMerge: @escaping () -> Void,
    openGovernance: @escaping () -> Void,
    openCompanion: @escaping () -> Void,
    onHumanReview: @escaping () -> Void = {}
  ) {
    self.model = model
    self.onBatchMerge = onBatchMerge
    self.openGovernance = openGovernance
    self.openCompanion = openCompanion
    self.onHumanReview = onHumanReview
  }

  @ViewBuilder
  private var islandBackground: some View {
    if reduceTransparency {
      Color(nsColor: .windowBackgroundColor).opacity(0.96)
    } else {
      Rectangle().fill(.ultraThinMaterial)
    }
  }

  private var borderColor: Color {
    colorScheme == .dark
      ? Color.white.opacity(0.18)
      : Color.black.opacity(0.12)
  }

  public var body: some View {
    HStack(spacing: 6) {
      // Undo Button
      Button {
        model.undoLastEdit()
      } label: {
        Image(systemName: "arrow.uturn.backward")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(model.canUndo ? Color.primary : Color.secondary.opacity(0.5))
          .frame(width: 26, height: 26)
          .contentShape(Circle())
      }
      .buttonStyle(.plain)
      .disabled(!model.canUndo)
      .accessibilityLabel("Undo last edit")
      .help("Undo last edit (⌘Z)")

      // Redo Button
      Button {
        model.redoLastEdit()
      } label: {
        Image(systemName: "arrow.uturn.forward")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(model.canRedo ? Color.primary : Color.secondary.opacity(0.5))
          .frame(width: 26, height: 26)
          .contentShape(Circle())
      }
      .buttonStyle(.plain)
      .disabled(!model.canRedo)
      .accessibilityLabel("Redo last edit")
      .help("Redo last edit (⇧⌘Z)")

      // Hairline Divider
      Rectangle()
        .fill(borderColor)
        .frame(width: 1, height: 16)
        .accessibilityHidden(true)

      // Verified Export Pill & Menu
      Menu {
        Button("Export Copy…", systemImage: "square.and.arrow.down") {
          model.presentExportReview()
        }
        .disabled(model.inspection == nil || model.liveDocument == nil)
        .help("Prepare an export copy with verified audit receipt")

        Button("Export Sanitized Copy (No Metadata)…", systemImage: "lock.shield") {
          model.presentExportReview(profile: .sanitizedCopy)
        }
        .disabled(model.inspection == nil || model.liveDocument == nil)

        Button("Extract / Split Pages…", systemImage: "arrow.triangle.pull") {
          model.presentExportReview(profile: .pageExtraction)
        }
        .disabled(model.inspection == nil || model.liveDocument == nil)

        Button("Batch Merge Documents…", systemImage: "doc.on.doc") {
          onBatchMerge()
        }

        Button("Synthesize Searchable OCR Layer", systemImage: "text.viewfinder") {
          model.synthesizeSearchableOCRLayer()
        }

        Divider()

        Button("Export Flattened Copy…", systemImage: "printer.dotmatrix") {
          model.presentExportReview(profile: .flattenedCopy)
        }
        .disabled(model.inspection == nil || model.liveDocument == nil)
      } label: {
        HStack(spacing: 5) {
          Image(systemName: "square.and.arrow.down")
            .font(.system(size: 11, weight: .bold))
          Text("Export")
            .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
          Capsule()
            .fill(Color.accentColor)
        )
        .shadow(color: Color.accentColor.opacity(0.3), radius: 4, y: 1)
      }
      .menuStyle(.borderlessButton)
      .fixedSize()
      .accessibilityLabel("Export options and verified export")
      .help("Export verified copy, sanitize metadata, split pages, or flatten")

      // Hairline Divider
      Rectangle()
        .fill(borderColor)
        .frame(width: 1, height: 16)
        .accessibilityHidden(true)

      // Workspace & Tools Menu
      Menu {
        Button("Document Browser…", systemImage: "books.vertical") {
          model.isDocumentBrowserPresented = true
        }
        .help("Browse and organize your document corpus")

        Button("Version History…", systemImage: "clock.arrow.circlepath") {
          model.isVersionComparePresented = true
        }
        .help("Compare and revert document versions")

        Button("Governance Dashboard…", systemImage: "checkmark.shield") {
          openGovernance()
        }
        .help("View compliance status and policy rules in a dedicated native window")

        Divider()

        Button("Companion Health…", systemImage: "heart.text.square") {
          openCompanion()
        }
        .help("Provider status, egress connections, and bridge log")

        Button("Security & Privacy Vault…", systemImage: "lock.shield") {
          model.isSecurityVaultPresented = true
        }
        .keyboardShortcut("8", modifiers: [.command])
        .help("Hardware-isolated encrypted local stores and audit ledger (⌘8)")

        Divider()

        Menu("Visual Diff") {
          Button {
            model.toggleDiffView()
          } label: {
            Label(
              model.showDiff ? "Hide Visual Diff Overlay" : "Show Visual Diff Overlay",
              systemImage: model.showDiff ? "rectangle.dashed" : "rectangle.fill"
            )
          }
          .disabled(model.sourceInspection == nil)

          Button {
            model.openDiffComparison()
          } label: {
            Label("Side-by-Side Comparison…", systemImage: "rectangle.split.2x1")
          }
          .disabled(model.sourceInspection == nil)
        }

        Menu("Reading Display") {
          ForEach(ReadingMode.allCases) { mode in
            Button {
              model.readingMode = mode
            } label: {
              Label(mode.displayName, systemImage: mode.symbolName)
            }
          }
          Divider()
          Toggle(isOn: $model.usePipelineRendering) {
            Label("Pipeline Renderer", systemImage: "cpu")
          }
        }

        #if DEBUG
        Divider()
        Button("Human Review Panel…", systemImage: "eye") {
          onHumanReview()
        }
        .help("Record human visual confirmations for governed fixtures (RG-135)")
        #endif
      } label: {
        Image(systemName: "ellipsis.circle")
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(Color.secondary)
          .frame(width: 24, height: 24)
      }
      .menuStyle(.borderlessButton)
      .fixedSize()
      .accessibilityLabel("Workspace tools and options")
      .help("Access document browser, version compare, governance, and reading settings")
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 4)
    .background(islandBackground)
    .clipShape(Capsule())
    .overlay(
      Capsule()
        .stroke(borderColor, lineWidth: 1)
    )
    .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 2)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Document actions and workspace dock")
  }
}
