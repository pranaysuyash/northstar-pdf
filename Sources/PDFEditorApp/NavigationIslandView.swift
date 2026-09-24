import AppKit
import PDFEditorCore
import PDFEditorRecovery
import SwiftUI

/// Island 3: Floating Canvas Stepper & Zoom Island.
///
/// Designed per the Floating Glass Islands Architecture (MAD-I6 / Sprint 1 Phase 1).
/// Positioned at the bottom center of the document canvas, floating with an elevated
/// glass pill aesthetic. Preserves viewport space and requires a 72pt bottom content
/// inset on the underlying PDF scrollview to prevent page footer occlusion.
public struct NavigationIslandView: View {
  @Bindable var model: AppModel
  let inspection: DocumentInspection?
  let onToggleThumbnailRail: (() -> Void)?

  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.colorScheme) private var colorScheme

  public init(
    model: AppModel,
    inspection: DocumentInspection?,
    onToggleThumbnailRail: (() -> Void)? = nil
  ) {
    self.model = model
    self.inspection = inspection
    self.onToggleThumbnailRail = onToggleThumbnailRail
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

  private var totalPages: Int {
    max(1, inspection?.pages.count ?? 1)
  }

  public var body: some View {
    HStack(spacing: 8) {
      // Toggle Thumbnails Rail
      if let onToggleThumbnailRail {
        Button {
          onToggleThumbnailRail()
        } label: {
          Image(systemName: "sidebar.left")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.primary)
            .frame(width: 26, height: 26)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Toggle thumbnail sidebar")
        .help("Show or hide the page thumbnail sidebar")

        Rectangle()
          .fill(borderColor)
          .frame(width: 1, height: 16)
          .accessibilityHidden(true)
      }

      // Page Navigation Pill / Badge
      Menu {
        ForEach(0..<totalPages, id: \.self) { idx in
          Button("Page \(idx + 1)") {
            model.jumpToPage(idx)
          }
        }
      } label: {
        Text("Page \(model.selectedPageIndex + 1) of \(totalPages)")
          .font(.caption.weight(.semibold).monospacedDigit())
          .foregroundStyle(Color.primary)
          .padding(.horizontal, 8)
          .padding(.vertical, 3)
          .background(
            Capsule()
              .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.06))
          )
      }
      .menuStyle(.borderlessButton)
      .fixedSize()
      .accessibilityLabel("Page \(model.selectedPageIndex + 1) of \(totalPages). Click to jump.")
      .help("Click to jump to a specific page")

      // Hairline Divider
      Rectangle()
        .fill(borderColor)
        .frame(width: 1, height: 16)
        .accessibilityHidden(true)

      // Zoom Stepper Controls
      HStack(spacing: 4) {
        // Zoom Out
        Button {
          model.setZoom(max(0.25, model.readerZoom - 0.1))
        } label: {
          Image(systemName: "minus")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Color.primary)
            .frame(width: 24, height: 24)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Zoom out")
        .help("Zoom Out")

        // Zoom Level Menu
        Menu {
          Button("Fit Width") { model.setReaderScaleMode(.fitWidth) }
          Button("Fit Page") { model.setReaderScaleMode(.fitPage) }
          Divider()
          Button("50%") { model.setZoom(0.5) }
          Button("75%") { model.setZoom(0.75) }
          Button("100% (Actual Size)") { model.setZoom(1.0) }
          Button("125%") { model.setZoom(1.25) }
          Button("150%") { model.setZoom(1.5) }
          Button("200%") { model.setZoom(2.0) }
        } label: {
          Text("\(Int(model.readerZoom * 100))%")
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(Color.primary)
            .frame(minWidth: 42)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel("Zoom level \(Int(model.readerZoom * 100)) percent")
        .help("Zoom level options")

        // Zoom In
        Button {
          model.setZoom(min(3.0, model.readerZoom + 0.1))
        } label: {
          Image(systemName: "plus")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Color.primary)
            .frame(width: 24, height: 24)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Zoom in")
        .help("Zoom In")
      }

      // Hairline Divider
      Rectangle()
        .fill(borderColor)
        .frame(width: 1, height: 16)
        .accessibilityHidden(true)

      // Fit Width Quick Action
      Button {
        model.setReaderScaleMode(.fitWidth)
      } label: {
        Image(systemName: "arrow.left.and.right")
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(Color.secondary)
          .frame(width: 24, height: 24)
          .contentShape(Circle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Fit width")
      .help("Fit document to window width")

      // Rotate Right Quick Action
      Button {
        model.rotateRight()
      } label: {
        Image(systemName: "arrow.clockwise")
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(Color.secondary)
          .frame(width: 24, height: 24)
          .contentShape(Circle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Rotate 90 degrees clockwise")
      .help("Rotate 90° Clockwise")

      // Pinned Layout Clear Indicator (D-057)
      if model.hasPinnedLayout {
        Rectangle()
          .fill(borderColor)
          .frame(width: 1, height: 16)
          .accessibilityHidden(true)

        Button {
          model.clearPinnedLayout()
        } label: {
          Image(systemName: "pin.fill")
            .font(.caption)
            .foregroundStyle(Color.orange)
            .frame(width: 22, height: 24)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Saved layout is active. Click to clear.")
        .help("Clear saved layout for this document")
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 5)
    .background(islandBackground)
    .clipShape(Capsule())
    .overlay(
      Capsule()
        .stroke(borderColor, lineWidth: 1)
    )
    .shadow(color: Color.black.opacity(0.18), radius: 14, x: 0, y: 4)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Canvas navigation and zoom island")
  }
}
