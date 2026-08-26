import AppKit
import PDFEditorCore
import PDFEditorRecovery
import SwiftUI

public struct PageThumbnailRailView: View {
  let model: AppModel
  let inspection: DocumentInspection

  public init(model: AppModel, inspection: DocumentInspection) {
    self.model = model
    self.inspection = inspection
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
            model.insertBlankPage()
          }
        } label: {
          Image(systemName: "plus")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 16)
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
      ScrollView {
        LazyVStack(spacing: 8) {
          let counts = pageBadgeCounts
          ForEach(inspection.pages) { page in
            pageThumbnailCard(page, counts: counts)
          }
        }
        .padding(10)
      }
    }
    /* Apple Design §12: heavier material for structural sidebar */
    .background(.thinMaterial)
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

  @ViewBuilder
  private func pageThumbnailCard(
    _ page: PageSnapshot,
    counts: PageBadgeCounts
  ) -> some View {
    let isSelected = model.selectedPageIndex == page.pageIndex
    let fieldCount = counts.fields[page.pageIndex, default: 0]
    let candidateCount = counts.candidates[page.pageIndex, default: 0]
    let redactionCount = counts.redactions[page.pageIndex, default: 0]

    Button {
      model.selectedPageIndex = page.pageIndex
    } label: {
      HStack(alignment: .top, spacing: 10) {
        // Page representation icon / preview box
        ZStack {
          RoundedRectangle(cornerRadius: 4)
            .fill(Color(NSColor.textBackgroundColor))
            .shadow(color: Color.black.opacity(isSelected ? 0.15 : 0.06), radius: isSelected ? 3 : 1, x: 0, y: 1)

          /* Apple Design: colored border for selected state */
          RoundedRectangle(cornerRadius: 4)
            .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.15), lineWidth: isSelected ? 2 : 1)

          VStack(spacing: 2) {
            Image(systemName: isSelected ? "doc.fill" : "doc")
              .font(.title3)
              .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

            Text("\(page.pageLabel)")
              .font(.caption2.weight(.bold))
              .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
          }
        }
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
      }
      .padding(8)
      .background(
        isSelected ? Color.accentColor.opacity(0.10) : Color.clear
      )
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .contextMenu {
        Button("Rotate Clockwise 90°", systemImage: "rotate.right") {
          model.rotatePage(at: page.pageIndex, by: 90)
        }
        Button("Rotate Counter-Clockwise 90°", systemImage: "rotate.left") {
          model.rotatePage(at: page.pageIndex, by: 270)
        }
        Divider()
        if page.pageIndex > 0 {
          Button("Move Page Up", systemImage: "arrow.up") {
            model.movePage(from: page.pageIndex, to: page.pageIndex - 1)
          }
        }
        if page.pageIndex < inspection.pages.count - 1 {
          Button("Move Page Down", systemImage: "arrow.down") {
            model.movePage(from: page.pageIndex, to: page.pageIndex + 1)
          }
        }
        Divider()
        Button("Insert Blank Page After", systemImage: "plus.rectangle") {
          model.insertBlankPage(at: page.pageIndex + 1)
        }
        Divider()
        Button("Delete Page", systemImage: "trash", role: .destructive) {
          model.deletePage(at: page.pageIndex)
        }
        .disabled(inspection.pages.count <= 1)
      }
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Page \(page.pageLabel), \(page.characterCount) characters, \(fieldCount) fields, \(candidateCount) suggestions")
    .accessibilityHint("Selects page \(page.pageLabel)")
    .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
  }
}
