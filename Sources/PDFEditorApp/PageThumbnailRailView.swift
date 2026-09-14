import AppKit
import PDFEditorCore
import PDFEditorRecovery
import SwiftUI
import UniformTypeIdentifiers

public struct PageThumbnailRailView: View {
  let model: AppModel
  let inspection: DocumentInspection
  /// Shared rendering pipeline (owned by ContentView) whose cache this rail
  /// both consumes and warms.
  let renderingPipeline: RenderingPipeline
  @State private var isRailDropTargeted = false

  public init(
    model: AppModel,
    inspection: DocumentInspection,
    renderingPipeline: RenderingPipeline
  ) {
    self.model = model
    self.inspection = inspection
    self.renderingPipeline = renderingPipeline
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Sidebar Header
      HStack {
        Text("Pages")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.secondary)
        Spacer()
        Menu {
          Button("Insert Blank Page", systemImage: "plus.rectangle") {
            AdaptiveCommandHistory.shared.record(.organizePages)
            model.insertBlankPage()
          }
        } label: {
          Image(systemName: "plus")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.secondary)
            .frame(minWidth: 44, minHeight: 44)
        }
        .menuStyle(.borderlessButton)
        .disabled(!canOrganizePages)
        .accessibilityLabel("Insert page")
        .help("Insert page")

        Text("\(inspection.pages.count)")
          .font(.caption2.weight(.medium).monospacedDigit())
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(Color.secondary.opacity(0.15))
          .clipShape(Capsule())
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 14)
      .padding(.top, 12)
      .padding(.bottom, 8)

      Divider()

      // Pages List
      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(spacing: 8) {
            let counts = pageBadgeCounts
            ForEach(inspection.pages) { page in
              PageThumbnailCardView(
                model: model,
                page: page,
                fieldCount: counts.fields[page.pageIndex, default: 0],
                candidateCount: counts.candidates[page.pageIndex, default: 0],
                redactionCount: counts.redactions[page.pageIndex, default: 0],
                renderingPipeline: renderingPipeline,
                canOrganizePages: canOrganizePages,
                totalPages: inspection.pages.count,
                onRecordOrganization: recordPageOrganization
              )
              .id(page.pageIndex)
            }
          }
          .padding(10)
        }
        .onDrop(of: [UTType.pdf.identifier, UTType.fileURL.identifier], isTargeted: $isRailDropTargeted) { providers in
          handleRailDroppedPDF(providers)
        }
        .overlay {
          if isRailDropTargeted {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
              .strokeBorder(Color.accentColor, lineWidth: 2)
              .background(Color.accentColor.opacity(0.08))
              .padding(4)
              .allowsHitTesting(false)
          }
        }
        .onChange(of: model.selectedPageIndex) { _, newIndex in
          withAnimation(.easeInOut(duration: 0.25)) {
            proxy.scrollTo(newIndex, anchor: .center)
          }
        }
      }
    }
    /* Apple Design §12: heavier material for structural sidebar */
    .background(.thinMaterial)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Page navigation")
    .accessibilityIdentifier("pdfEditor.pageNavigation")
  }

  private func handleRailDroppedPDF(_ providers: [NSItemProvider]) -> Bool {
    guard let provider = providers.first else { return false }
    provider.loadInPlaceFileRepresentation(forTypeIdentifier: UTType.pdf.identifier) { url, inPlace, error in
      guard let url else { return }
      let targetURL: URL
      if inPlace {
        targetURL = url
      } else {
        let destination = FileManager.default.temporaryDirectory
          .appendingPathComponent("PDFEditor-RailDrop-\(UUID().uuidString).pdf")
        do {
          try FileManager.default.copyItem(at: url, to: destination)
          targetURL = destination
        } catch {
          return
        }
      }
      Task { @MainActor in
        model.insertPages(from: targetURL)
      }
    }
    return true
  }

  /// Per-page badge counts, built in one pass. Computing these inside each
  /// card filtered the fields, candidates, and operation ledger once per page
  /// per body evaluation — O(pages × operations) work on every model change.
  private struct PageBadgeCounts {
    var fields: [Int: Int] = [:]
    var candidates: [Int: Int] = [:]
    var redactions: [Int: Int] = [:]
  }

  private var pageBadgeCounts: PageBadgeCounts {
    var counts = PageBadgeCounts()
    for field in inspection.fields {
      counts.fields[field.pageIndex, default: 0] += 1
    }
    for candidate in model.activeCandidates {
      counts.candidates[candidate.pageIndex, default: 0] += 1
    }
    for operation in model.operations where operation.kind == .redactMark {
      counts.redactions[operation.pageIndex, default: 0] += 1
    }
    return counts
  }

  private var canOrganizePages: Bool {
    let input = AdaptiveCommandContext.input(
      model: model,
      intent: .organize,
      target: .pageThumbnail
    )
    return AdaptiveCommandPolicy.standard.assess(input)
      .first { $0.command.id == .organizePages }?.state.isActionable ?? false
  }

  private func recordPageOrganization() {
    AdaptiveCommandHistory.shared.record(.organizePages)
  }
}

private struct PageThumbnailCardView: View {
  let model: AppModel
  let page: PageSnapshot
  let fieldCount: Int
  let candidateCount: Int
  let redactionCount: Int
  let renderingPipeline: RenderingPipeline
  let canOrganizePages: Bool
  let totalPages: Int
  let onRecordOrganization: () -> Void

  @State private var isHovered = false

  var isSelected: Bool {
    model.selectedPageIndex == page.pageIndex
  }

  private var cardBackground: Color {
    if isSelected {
      return Color.accentColor.opacity(0.12)
    } else if isHovered {
      return Color.primary.opacity(0.05)
    } else {
      return Color.clear
    }
  }

  private var cardBorderColor: Color {
    if isSelected {
      return Color.accentColor.opacity(0.35)
    } else if isHovered {
      return Color.primary.opacity(0.12)
    } else {
      return Color.clear
    }
  }

  var body: some View {
    Button {
      model.selectedPageIndex = page.pageIndex
    } label: {
      HStack(alignment: .top, spacing: 10) {
        // Real page thumbnail rendered through the shared pipeline, with a
        // graceful fallback to the generic document icon while it loads.
        RailThumbnail(
          pipeline: renderingPipeline,
          pageIndex: page.pageIndex,
          isSelected: isSelected,
          label: page.pageLabel
        )
        .frame(width: 38, height: 48)

        // Metadata & semantic badges
        VStack(alignment: .leading, spacing: 3) {
          HStack {
            Text("Page \(page.pageLabel)")
              .font(.caption.weight(isSelected ? .semibold : .medium))
              .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.85))

            Spacer()

            if page.hasSelectableText {
              Image(systemName: "text.alignleft")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .help("Selectable text layer available")
            }
          }

          Text("\(page.characterCount) chars · \(Int(page.bounds.width))×\(Int(page.bounds.height))")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .monospacedDigit()

          // Semantic Pills
          HStack(spacing: 4) {
            if fieldCount > 0 {
              Text("\(fieldCount) field\(fieldCount == 1 ? "" : "s")")
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.blue.opacity(0.12))
                .foregroundStyle(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            }

            if candidateCount > 0 {
              Text("\(candidateCount) sugg")
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.orange.opacity(0.15))
                .foregroundStyle(Color.orange)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            }

            if redactionCount > 0 {
              Text("\(redactionCount) redact")
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.red.opacity(0.15))
                .foregroundStyle(Color.red)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            }
          }
        }
        Spacer(minLength: 0)
      }
      .padding(8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(cardBackground)
      .contentShape(RoundedRectangle(cornerRadius: 8))
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .strokeBorder(cardBorderColor, lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      isHovered = hovering
    }
    .contextMenu {
      if canOrganizePages {
        Menu("Organize Page", systemImage: "rectangle.split.3x1") {
          Button("Rotate Clockwise 90°", systemImage: "rotate.right") {
            onRecordOrganization()
            model.rotatePage(at: page.pageIndex, by: 90)
          }
          Button("Rotate Counter-Clockwise 90°", systemImage: "rotate.left") {
            onRecordOrganization()
            model.rotatePage(at: page.pageIndex, by: 270)
          }
          Divider()
          if page.pageIndex > 0 {
            Button("Move Page Up", systemImage: "arrow.up") {
              onRecordOrganization()
              model.movePage(from: page.pageIndex, to: page.pageIndex - 1)
            }
          }
          if page.pageIndex < totalPages - 1 {
            Button("Move Page Down", systemImage: "arrow.down") {
              onRecordOrganization()
              model.movePage(from: page.pageIndex, to: page.pageIndex + 1)
            }
          }
          Divider()
          Button("Insert Blank Page After", systemImage: "plus.rectangle") {
            onRecordOrganization()
            model.insertBlankPage(at: page.pageIndex + 1)
          }
          Divider()
          Button("Delete Page", systemImage: "trash", role: .destructive) {
            onRecordOrganization()
            model.deletePage(at: page.pageIndex)
          }
          .disabled(totalPages <= 1)
        }
      } else {
        Label("Page editing unavailable", systemImage: "lock")
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Page \(page.pageLabel), \(page.characterCount) characters, \(fieldCount) fields, \(candidateCount) suggestions")
    .accessibilityHint("Selects page \(page.pageLabel)")
    .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
  }
}

/// A page thumbnail rendered through the shared rendering pipeline.
///
/// Renders asynchronously off the main thread and falls back to a generic
/// document icon until the render is available or if rendering fails.
private struct RailThumbnail: View {
  let pipeline: RenderingPipeline
  let pageIndex: Int
  let isSelected: Bool
  let label: String

  @State private var image: NSImage?

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 4)
        .fill(Color(NSColor.textBackgroundColor))
        .shadow(
          color: Color.black.opacity(isSelected ? 0.15 : 0.06),
          radius: isSelected ? 3 : 1,
          x: 0,
          y: 1
        )

      /* Apple Design: colored border for selected state */
      RoundedRectangle(cornerRadius: 4)
        .stroke(
          isSelected ? Color.accentColor : Color.secondary.opacity(0.15),
          lineWidth: isSelected ? 2 : 1
        )

      if let image {
        Image(nsImage: image)
          .resizable()
          .interpolation(.high)
          .aspectRatio(contentMode: .fit)
          .padding(3)
      } else {
        Image(systemName: isSelected ? "doc.fill" : "doc")
          .font(.title3)
          .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
      }

      Text(label)
        .font(.caption2.weight(.bold))
        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
        .padding(.horizontal, 3)
        .padding(.vertical, 1)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 2))
        .frame(maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 2)
    }
    .task(id: "thumb-\(pageIndex)") {
      guard image == nil else { return }
      let rendered = await pipeline.renderThumbnailAsync(pageIndex: pageIndex, maxPixelWidth: 110)
      guard let rendered, let nsImage = NSImage(data: rendered.imageData) else { return }
      image = nsImage
    }
  }
}
