import AppKit
import PDFEditorCore
import PDFEditorRecovery
import SwiftUI

public struct AgentCommandItem: Identifiable {
  public let id: String
  public let title: String
  public let subtitle: String
  public let icon: String
  public let category: String
  public let isAvailable: Bool
  public let action: @MainActor () -> Void

  public init(
    id: String,
    title: String,
    subtitle: String,
    icon: String,
    category: String,
    isAvailable: Bool = true,
    action: @escaping @MainActor () -> Void
  ) {
    self.id = id
    self.title = title
    self.subtitle = subtitle
    self.icon = icon
    self.category = category
    self.isAvailable = isAvailable
    self.action = action
  }
}

public struct AgentCommandHUD: View {
  @Bindable var model: AppModel
  @Binding var isPresented: Bool
  @Binding var isSecurityVaultPresented: Bool
  @State private var query = ""
  @State private var selectedIndex = 0
  @FocusState private var isFieldFocused: Bool

  public init(
    model: AppModel,
    isPresented: Binding<Bool>,
    isSecurityVaultPresented: Binding<Bool>
  ) {
    self.model = model
    self._isPresented = isPresented
    self._isSecurityVaultPresented = isSecurityVaultPresented
  }

  private var allCommands: [AgentCommandItem] {
    var items: [AgentCommandItem] = []

    // 1. Intelligent Fill & Auto-Completion
    if let profile = model.currentProfile {
      items.append(
        AgentCommandItem(
          id: "bulk-fill-apply",
          title: "Bulk Fill with Profile: \(profile.displayName)",
          subtitle: "Auto-populate all matching native fields and detected static candidates",
          icon: "sparkles",
          category: "AI & Automation",
          isAvailable: model.inspection != nil
        ) {
          model.previewBulkFill()
          model.applyBulkFill()
        }
      )
    } else {
      items.append(
        AgentCommandItem(
          id: "bulk-fill-preview",
          title: "Auto-Fill from Local Profile",
          subtitle: "Preview profile values across recognized document fields",
          icon: "person.crop.circle.badge.plus",
          category: "AI & Automation",
          isAvailable: model.inspection != nil
        ) {
          model.setEditorMode(.fill)
        }
      )
    }

    if model.inspection?.candidates.isEmpty == false {
      items.append(
        AgentCommandItem(
          id: "fill-next-candidate",
          title: "Jump to Next Detected Field",
          subtitle: "Review static suggestion with one-click candidate placement",
          icon: "scope",
          category: "AI & Automation"
        ) {
          model.selectNextCandidate()
        }
      )
    }

    // 2. OCR & Document Intelligence
    items.append(
      AgentCommandItem(
        id: "ocr-current-page",
        title: "Run Vision OCR on Current Page",
        subtitle: "Extract selectable text and synthesize form geometry locally",
        icon: "text.viewfinder",
        category: "Intelligence",
        isAvailable: model.inspection?.permissions.canCopy ?? false
      ) {
        model.runOCROnSelectedPage()
      }
    )

    items.append(
      AgentCommandItem(
        id: "template-match",
        title: "Find Template Layout Matches",
        subtitle: "Query local encrypted vault for layout geometry matches",
        icon: "checklist",
        category: "Intelligence",
        isAvailable: model.isTemplateVaultUnlocked
      ) {
        model.findLocalTemplateMatches()
      }
    )

    // 3. Document Authoring & Sign
    items.append(
      AgentCommandItem(
        id: "add-signature",
        title: "Place Signature",
        subtitle: "Draw, type, or import a visual signature overlay",
        icon: "signature",
        category: "Authoring",
        isAvailable: model.inspection?.permissions.canAddAnnotations ?? false
      ) {
        model.beginSign(for: nil)
      }
    )

    items.append(
      AgentCommandItem(
        id: "add-text",
        title: "Add Text Overlay",
        subtitle: "Click anywhere on the document canvas to position text",
        icon: "text.cursor",
        category: "Authoring",
        isAvailable: model.inspection?.permissions.canAddAnnotations ?? false
      ) {
        model.beginManualTextPlacement()
      }
    )

    let markedCount = model.operations.filter { $0.kind == .redactMark }.count
    if markedCount > 0 {
      items.append(
        AgentCommandItem(
          id: "commit-redactions",
          title: "Commit \(markedCount) Marked Redaction(s)",
          subtitle: "Irrevocably remove underlying text/vector stream on exported copy",
          icon: "eye.slash.fill",
          category: "Authoring"
        ) {
          model.isRedactionCommitPresented = true
        }
      )
    }

    // 4. Visual Verification & Diff
    if model.sourceInspection != nil {
      items.append(
        AgentCommandItem(
          id: "toggle-diff-overlay",
          title: model.showDiff ? "Hide Visual Diff Overlay" : "Show Visual Diff Overlay",
          subtitle: "Highlight outside-region changes and edits directly on page",
          icon: "doc.text.magnifyingglass",
          category: "Verification"
        ) {
          model.toggleDiffView()
        }
      )

      items.append(
        AgentCommandItem(
          id: "open-diff-sheet",
          title: "Side-by-Side Diff Inspector",
          subtitle: "Compare original source vs live edited state with pixel delta",
          icon: "rectangle.split.2x1",
          category: "Verification"
        ) {
          model.openDiffComparison()
        }
      )
    }

    // 5. Modes & Navigation
    for mode in EditorMode.allCases {
      if mode != model.editorMode {
        items.append(
          AgentCommandItem(
            id: "mode-\(mode.rawValue)",
            title: "Switch to \(mode.displayName) Mode",
            subtitle: mode == .fill ? "Highlight and navigate form fields" :
                      mode == .sign ? "Place signatures and initials" :
                      mode == .edit ? "Full authoring, placement, and redactions" : "Passive reading and search",
            icon: mode.symbolName,
            category: "Navigation"
          ) {
            model.setEditorMode(mode)
          }
        )
      }
    }

    // 6. Security & Privacy Vault
    items.append(
      AgentCommandItem(
        id: "open-security-vault",
        title: "Open Security & Privacy Vault",
        subtitle: "Manage Keychain unlocking, encrypted recovery envelopes, and audit logs",
        icon: "lock.shield",
        category: "Security"
      ) {
        isSecurityVaultPresented = true
      }
    )

    // 7. Safe Export
    items.append(
      AgentCommandItem(
        id: "export-copy",
        title: "Export Validated PDF Copy",
        subtitle: "Preflights and writes an immutable separate copy (source never overwritten)",
        icon: "square.and.arrow.down",
        category: "Export",
        isAvailable: model.canExportCurrentOperations
      ) {
        model.export()
      }
    )

    return items
  }

  private var filteredCommands: [AgentCommandItem] {
    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return allCommands
    }
    let lower = query.lowercased()
    return allCommands.filter {
      $0.title.lowercased().contains(lower) ||
      $0.subtitle.lowercased().contains(lower) ||
      $0.category.lowercased().contains(lower)
    }
  }

  public var body: some View {
    VStack(spacing: 0) {
      // Search Bar Header
      HStack(spacing: 12) {
        Image(systemName: "sparkle.magnifyingglass")
          .font(.system(size: 18, weight: .medium))
          .foregroundStyle(.tint)

        TextField("Ask Agent or search commands (e.g. 'fill', 'ocr', 'diff', 'sign')…", text: $query)
          .textFieldStyle(.plain)
          .font(.system(size: 14, weight: .regular))
          .focused($isFieldFocused)
          .onSubmit {
            executeSelected()
          }

        if !query.isEmpty {
          Button {
            query = ""
          } label: {
            Image(systemName: "xmark.circle.fill")
              .foregroundStyle(.secondary)
          }
          .buttonStyle(.plain)
        }

        Text("ESC")
          .font(.caption2.weight(.bold))
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(Color.secondary.opacity(0.15))
          .clipShape(RoundedRectangle(cornerRadius: 4))
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)

      Divider()

      // Results List
      if filteredCommands.isEmpty {
        VStack(spacing: 8) {
          Image(systemName: "questionmark.folder")
            .font(.system(size: 28))
            .foregroundStyle(.secondary)
          Text("No matching agent commands")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
      } else {
        ScrollViewReader { proxy in
          ScrollView {
            LazyVStack(spacing: 4) {
              ForEach(Array(filteredCommands.enumerated()), id: \.element.id) { index, item in
                Button {
                  executeCommand(item)
                } label: {
                  HStack(spacing: 12) {
                    Image(systemName: item.icon)
                      .font(.system(size: 16, weight: .medium))
                      .frame(width: 24, height: 24)
                      .foregroundStyle(item.isAvailable ? Color.accentColor : Color.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                      HStack {
                        Text(item.title)
                          .font(.system(size: 13, weight: .medium))
                          .foregroundStyle(item.isAvailable ? Color.primary : Color.secondary)

                        Spacer()

                        Text(item.category)
                          .font(.caption2)
                          .foregroundStyle(.secondary)
                          .padding(.horizontal, 6)
                          .padding(.vertical, 2)
                          .background(Color.secondary.opacity(0.1))
                          .clipShape(Capsule())
                      }

                      Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    }
                  }
                  .padding(.horizontal, 12)
                  .padding(.vertical, 8)
                  .background(
                    selectedIndex == index ? Color.accentColor.opacity(0.12) : Color.clear
                  )
                  .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(!item.isAvailable)
                .id(item.id)
              }
            }
            .padding(8)
          }
          .frame(maxHeight: 320)
          .onChange(of: selectedIndex) { _, newIndex in
            if filteredCommands.indices.contains(newIndex) {
              proxy.scrollTo(filteredCommands[newIndex].id)
            }
          }
        }
      }

      Divider()

      // Footer
      HStack {
        Label("Local-first agent execution · Zero-egress guarantee", systemImage: "shield.checkered")
          .font(.caption2)
          .foregroundStyle(.secondary)
        Spacer()
        Text("↵ to run · ⎋ to close")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 8)
      .background(Color.secondary.opacity(0.04))
    }
    .frame(width: 580)
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .shadow(color: Color.black.opacity(0.25), radius: 24, x: 0, y: 12)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color.white.opacity(0.2), lineWidth: 1)
    )
    .onAppear {
      isFieldFocused = true
      selectedIndex = 0
    }
    .onChange(of: query) { _, _ in
      selectedIndex = 0
    }
    .onKeyPress(.downArrow) {
      if selectedIndex < filteredCommands.count - 1 {
        selectedIndex += 1
        return .handled
      }
      return .ignored
    }
    .onKeyPress(.upArrow) {
      if selectedIndex > 0 {
        selectedIndex -= 1
        return .handled
      }
      return .ignored
    }
    .onKeyPress(.escape) {
      isPresented = false
      return .handled
    }
  }

  private func executeSelected() {
    guard filteredCommands.indices.contains(selectedIndex) else { return }
    executeCommand(filteredCommands[selectedIndex])
  }

  private func executeCommand(_ item: AgentCommandItem) {
    guard item.isAvailable else { return }
    isPresented = false
    item.action()
  }
}
