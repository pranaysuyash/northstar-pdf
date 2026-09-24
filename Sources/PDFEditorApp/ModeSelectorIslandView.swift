import AppKit
import PDFEditorCore
import PDFEditorRecovery
import SwiftUI

/// Island 1: Floating Mode Selector & Omni-Find Action HUD Chip.
///
/// Designed per the Floating Glass Islands Architecture (MAD-I6 / Sprint 1 Phase 1).
/// Positioned at the top center (.principal) of the document window to preserve native
/// window dragging regions while elevating document focus.
public struct ModeSelectorIslandView: View {
  @Bindable var model: AppModel
  @Binding var isCommandPalettePresented: Bool

  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorScheme) private var colorScheme

  public init(
    model: AppModel,
    isCommandPalettePresented: Binding<Bool>
  ) {
    self.model = model
    self._isCommandPalettePresented = isCommandPalettePresented
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
    HStack(spacing: 8) {
      // Mode Switcher Segmented Pill
      HStack(spacing: 2) {
        ForEach(EditorMode.allCases, id: \.self) { mode in
          let isSelected = model.editorMode == mode
          Button {
            if reduceMotion {
              model.setEditorMode(mode)
            } else {
              withAnimation(.easeInOut(duration: 0.15)) {
                model.setEditorMode(mode)
              }
            }
          } label: {
            HStack(spacing: 5) {
              Image(systemName: mode.symbolName)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
              Text(mode.displayName)
                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
            }
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
              if isSelected {
                Capsule()
                  .fill(colorScheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.08))
                  .shadow(color: Color.black.opacity(0.1), radius: 2, y: 1)
              }
            }
            .contentShape(Capsule())
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Switch to \(mode.displayName) mode")
          .accessibilityAddTraits(isSelected ? [.isSelected] : [])
          .help("Switch editor intent to \(mode.displayName)")
        }
      }
      .padding(3)
      .background(
        Capsule()
          .fill(colorScheme == .dark ? Color.black.opacity(0.28) : Color.black.opacity(0.05))
      )

      // Hairline Divider
      Rectangle()
        .fill(borderColor)
        .frame(width: 1, height: 18)
        .accessibilityHidden(true)

      // Omni-Find & Action HUD Chip (⌘K Ask Northstar)
      Button {
        isCommandPalettePresented.toggle()
      } label: {
        HStack(spacing: 6) {
          Image(systemName: "sparkles")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.accentColor)

          Text("Ask Northstar")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.primary)

          Text("⌘K")
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
              RoundedRectangle(cornerRadius: 4)
                .fill(Color.primary.opacity(0.08))
                .stroke(borderColor, lineWidth: 0.5)
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
          Capsule()
            .fill(Color.accentColor.opacity(0.12))
            .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
        )
        .contentShape(Capsule())
      }
      .buttonStyle(.plain)
      .keyboardShortcut("k", modifiers: .command)
      .accessibilityLabel("Ask Northstar")
      .accessibilityHint("Command-K. Opens Agent Command Palette for actions, search, OCR, and workflows.")
      .help("Open Agent Command Palette (⌘K)")
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 4)
    .background(islandBackground)
    .clipShape(Capsule())
    .overlay(
      Capsule()
        .stroke(borderColor, lineWidth: 1)
    )
    .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 3)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Editor modes and command palette")
  }
}
