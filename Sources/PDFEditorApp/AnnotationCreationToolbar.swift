import PDFEditorCore
import SwiftUI

/// Toolbar that appears when text is selected, allowing the user to create
/// annotation marks from the selection.
///
/// First principle: annotation creation should be frictionless — select text,
/// pick a mark type, done. The toolbar appears at the selection location and
/// dismisses after creation.
///
/// Doctrine alignment:
/// - §3: One-click annotation — select → tap mark type → done
/// - §8: Capability routing — toolbar only appears when text is selected
///        and the document allows annotations
/// - Long-term: Foundation for annotation gestures, quick-note, study marks

// MARK: - Annotation Creation Toolbar

/// Floating toolbar for creating annotations from selected text.
public struct AnnotationCreationToolbar: View {
  @ObservedObject var store: AnnotationStore
  let selectedText: String
  let selectedBounds: PDFRect
  let pageIndex: Int
  let documentURL: URL?
  let onDismiss: () -> Void

  @State private var selectedType: AnnotationType = .highlight
  @State private var selectedColor: AnnotationColor = .yellow
  @State private var noteText: String = ""
  @State private var showNoteInput = false

  public init(
    store: AnnotationStore,
    selectedText: String,
    selectedBounds: PDFRect,
    pageIndex: Int,
    documentURL: URL?,
    onDismiss: @escaping () -> Void
  ) {
    self.store = store
    self.selectedText = selectedText
    self.selectedBounds = selectedBounds
    self.pageIndex = pageIndex
    self.documentURL = documentURL
    self.onDismiss = onDismiss
  }

  public var body: some View {
    VStack(spacing: 0) {
      // Mark type picker
      HStack(spacing: 8) {
        ForEach(AnnotationType.allCases) { type in
          Button {
            selectedType = type
            if type == .note {
              showNoteInput = true
            }
          } label: {
            Image(systemName: type.symbolName)
              .font(.system(size: 14))
              .frame(width: 28, height: 28)
              .background(selectedType == type ? Color.accentColor.opacity(0.2) : Color.clear)
              .cornerRadius(6)
          }
          .buttonStyle(.plain)
          .help(type.displayName)
        }

        Divider()
          .frame(height: 20)

        // Color picker
        ForEach(AnnotationColor.allCases) { color in
          Button {
            selectedColor = color
          } label: {
            Circle()
              .fill(Color(hex: color.hexColor))
              .frame(width: 16, height: 16)
              .overlay(
                Circle()
                  .stroke(Color.primary, lineWidth: selectedColor == color ? 2 : 0)
                  .frame(width: 20, height: 20)
              )
          }
          .buttonStyle(.plain)
          .help(color.displayName)
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)

      // Note input (expandable)
      if showNoteInput || selectedType == .note {
        Divider()
        HStack {
          TextField("Add a note...", text: $noteText)
            .textFieldStyle(.plain)
            .font(.caption)

          Button("Add") {
            createMark()
          }
          .font(.caption)
          .buttonStyle(.borderedProminent)
          .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
      }

      // Quick action buttons
      if !showNoteInput && selectedType != .note {
        Divider()
        HStack(spacing: 12) {
          Button {
            createMark()
          } label: {
            Label("Create \(selectedType.displayName)", systemImage: selectedType.symbolName)
              .font(.caption)
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.small)

          Button("Cancel") {
            onDismiss()
          }
          .font(.caption)
          .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
      }
    }
    .background(.regularMaterial)
    .cornerRadius(10)
    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
  }

  private func createMark() {
    let mark = AnnotationMark(
      type: selectedType,
      pageIndex: pageIndex,
      bounds: selectedBounds,
      selectedText: selectedText,
      note: noteText,
      color: selectedColor
    )
    store.addMark(mark)
    onDismiss()
  }
}

// MARK: - Annotation Marks Overlay

/// Renders annotation marks as colored overlays on the PDF page.
public struct AnnotationMarksOverlay: View {
  let marks: [AnnotationMark]
  let pageIndex: Int
  let pageBounds: CGRect
  let zoomScale: CGFloat

  public init(
    marks: [AnnotationMark],
    pageIndex: Int,
    pageBounds: CGRect,
    zoomScale: CGFloat
  ) {
    self.marks = marks
    self.pageIndex = pageIndex
    self.pageBounds = pageBounds
    self.zoomScale = zoomScale
  }

  public var body: some View {
    GeometryReader { geo in
      let visibleMarks = marks.filter { $0.pageIndex == pageIndex && $0.isVisible }

      ForEach(visibleMarks) { mark in
        let viewRect = pdfToView(mark.bounds, pageBounds: pageBounds, viewSize: geo.size)

        ZStack {
          // Mark overlay
          Rectangle()
            .fill(Color(hex: mark.color.hexColor).opacity(mark.type == .note ? 0.0 : 0.3))
            .frame(width: viewRect.width, height: viewRect.height)
            .position(x: viewRect.midX, y: viewRect.midY)

          // Border for non-note marks
          if mark.type != .note {
            Rectangle()
              .stroke(Color(hex: mark.color.hexColor).opacity(0.6), lineWidth: 1)
              .frame(width: viewRect.width, height: viewRect.height)
              .position(x: viewRect.midX, y: viewRect.midY)
          }

          // Note indicator
          if mark.type == .note {
            Image(systemName: "note.text")
              .font(.system(size: 12))
              .foregroundColor(Color(hex: mark.color.hexColor))
              .position(x: viewRect.maxX - 10, y: viewRect.minY + 10)
          }
        }
      }
    }
    .allowsHitTesting(false)
  }

  private func pdfToView(_ rect: PDFRect, pageBounds: CGRect, viewSize: CGSize) -> CGRect {
    let scaleX = viewSize.width / pageBounds.width
    let scaleY = viewSize.height / pageBounds.height
    let scale = min(scaleX, scaleY)

    // PDF coordinates: origin at bottom-left; SwiftUI: origin at top-left
    let x = (CGFloat(rect.x) - pageBounds.origin.x) * scale
    let y = (pageBounds.maxY - CGFloat(rect.y) - CGFloat(rect.height)) * scale
    let width = CGFloat(rect.width) * scale
    let height = CGFloat(rect.height) * scale

    return CGRect(x: x, y: y, width: width, height: height)
  }
}

// MARK: - Annotation List Sidebar

/// Sidebar showing all annotation marks for the current document.
public struct AnnotationListSidebar: View {
  @ObservedObject var store: AnnotationStore
  let onPageTap: (Int) -> Void

  public init(store: AnnotationStore, onPageTap: @escaping (Int) -> Void) {
    self.store = store
    self.onPageTap = onPageTap
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Header
      HStack {
        Text("Annotations")
          .font(.headline)
        Spacer()
        Text("\(store.marks.count)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)

      Divider()

      if store.marks.isEmpty {
        VStack(spacing: 8) {
          Image(systemName: "highlighter")
            .font(.title2)
            .foregroundStyle(.secondary)
          Text("No annotations yet")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text("Select text in the document to create highlights, underlines, or notes.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
      } else {
        ScrollView {
          LazyVStack(spacing: 2) {
            ForEach(store.marks) { mark in
              AnnotationMarkRow(mark: mark, onPageTap: onPageTap)
            }
          }
          .padding(.vertical, 4)
        }
      }
    }
    .frame(width: 220)
  }
}

// MARK: - Annotation Mark Row

struct AnnotationMarkRow: View {
  let mark: AnnotationMark
  let onPageTap: (Int) -> Void

  var body: some View {
    Button {
      onPageTap(mark.pageIndex)
    } label: {
      HStack(alignment: .top, spacing: 8) {
        Circle()
          .fill(Color(hex: mark.color.hexColor))
          .frame(width: 8, height: 8)
          .padding(.top, 4)

        VStack(alignment: .leading, spacing: 2) {
          HStack {
            Image(systemName: mark.type.symbolName)
              .font(.caption2)
              .foregroundStyle(.secondary)
            Text("Page \(mark.pageIndex + 1)")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }

          if !mark.selectedText.isEmpty {
            Text(mark.selectedText)
              .font(.caption)
              .lineLimit(2)
              .foregroundStyle(.primary)
          }

          if !mark.note.isEmpty {
            Text(mark.note)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        }

        Spacer()
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Color Extension

extension Color {
  init(hex: String) {
    let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&int)
    let a, r, g, b: UInt64
    switch hex.count {
    case 3: // RGB (12-bit)
      (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
    case 6: // RGB (24-bit)
      (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
    case 8: // ARGB (32-bit)
      (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
    default:
      (a, r, g, b) = (255, 0, 0, 0)
    }
    self.init(
      .sRGB,
      red: Double(r) / 255,
      green: Double(g) / 255,
      blue: Double(b) / 255,
      opacity: Double(a) / 255
    )
  }
}
