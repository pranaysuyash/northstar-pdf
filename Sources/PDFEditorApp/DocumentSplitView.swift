import PDFEditorCore
import PDFKit
import SwiftUI

/// Split view for side-by-side document viewing.
///
/// Shows two synchronized PDFView panes that scroll together.
/// Useful for comparing pages, reading two sections at once, or
/// viewing a document while checking annotations on another page.
///
/// First principle: spatial comparison requires both contexts visible
/// simultaneously. Tab-switching loses spatial reference.
///
/// Doctrine alignment:
/// - §3: Do things smartly — sync scroll position between panes
/// - §8: Capability routing — split view is opt-in, not default
/// - Long-term: Foundation for multi-page comparison, diff view

// MARK: - Split View State

/// Manages the synchronized state of a split view.
@MainActor
public final class SplitViewState: ObservableObject {
  /// Whether split view is active.
  @Published public var isActive: Bool = false
  /// Left pane page index.
  @Published public var leftPageIndex: Int = 0
  /// Right pane page index.
  @Published public var rightPageIndex: Int = 0
  /// Whether panes are synchronized (scroll together).
  @Published public var isSynchronized: Bool = true
  /// Split direction.
  @Published public var splitDirection: SplitDirection = .horizontal

  public enum SplitDirection: String, CaseIterable, Sendable {
    case horizontal // side by side
    case vertical   // top and bottom
  }

  public init() {}

  /// Toggle split view on/off.
  public func toggle() {
    isActive.toggle()
    if !isActive {
      isSynchronized = true
    }
  }

  /// Navigate left pane.
  public func navigateLeft(to pageIndex: Int) {
    leftPageIndex = pageIndex
    if isSynchronized {
      rightPageIndex = pageIndex
    }
  }

  /// Navigate right pane.
  public func navigateRight(to pageIndex: Int) {
    rightPageIndex = pageIndex
    if isSynchronized {
      leftPageIndex = pageIndex
    }
  }
}

// MARK: - Split View

/// Two-pane split view for side-by-side document viewing.
public struct DocumentSplitView: View {
  @ObservedObject var state: SplitViewState
  let document: PDFDocument?
  let onNavigate: (Int) -> Void

  public init(
    state: SplitViewState,
    document: PDFDocument?,
    onNavigate: @escaping (Int) -> Void
  ) {
    self.state = state
    self.document = document
    self.onNavigate = onNavigate
  }

  public var body: some View {
    if state.isActive, let doc = document {
      Group {
        switch state.splitDirection {
        case .horizontal:
          HSplitView {
            paneView(pageIndex: $state.leftPageIndex, label: "Left", isLeft: true)
            paneView(pageIndex: $state.rightPageIndex, label: "Right", isLeft: false)
          }
        case .vertical:
          VSplitView {
            paneView(pageIndex: $state.leftPageIndex, label: "Top", isLeft: true)
            paneView(pageIndex: $state.rightPageIndex, label: "Bottom", isLeft: false)
          }
        }
      }
      .overlay(alignment: .topTrailing) {
        splitControls
      }
    }
  }

  // MARK: - Pane View

  @ViewBuilder
  private func paneView(pageIndex: Binding<Int>, label: String, isLeft: Bool) -> some View {
    let totalPages = document?.pageCount ?? 0
    VStack(spacing: 0) {
      // Page indicator
      HStack {
        Text(label)
          .font(.caption2)
          .foregroundStyle(.secondary)
        Spacer()
        Text("Page \(pageIndex.wrappedValue + 1) of \(totalPages)")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(.ultraThinMaterial)

      // PDF view
      if pageIndex.wrappedValue >= 0, pageIndex.wrappedValue < totalPages,
         let page = document?.page(at: pageIndex.wrappedValue) {
        PDFKitPageView(page: page)
          .onAppear {
            onNavigate(pageIndex.wrappedValue)
          }
      } else {
        Color.clear
      }

      // Navigation
      HStack {
        Button {
          if pageIndex.wrappedValue > 0 {
            pageIndex.wrappedValue -= 1
            if state.isSynchronized {
              if isLeft {
                state.rightPageIndex = pageIndex.wrappedValue
              } else {
                state.leftPageIndex = pageIndex.wrappedValue
              }
            }
          }
        } label: {
          Image(systemName: "chevron.left")
        }
        .disabled(pageIndex.wrappedValue <= 0)

        Spacer()

        Button {
          if pageIndex.wrappedValue < totalPages - 1 {
            pageIndex.wrappedValue += 1
            if state.isSynchronized {
              if isLeft {
                state.rightPageIndex = pageIndex.wrappedValue
              } else {
                state.leftPageIndex = pageIndex.wrappedValue
              }
            }
          }
        } label: {
          Image(systemName: "chevron.right")
        }
        .disabled(pageIndex.wrappedValue >= totalPages - 1)
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
    }
  }

  // MARK: - Controls

  private var splitControls: some View {
    HStack(spacing: 6) {
      Button {
        state.isSynchronized.toggle()
      } label: {
        Image(systemName: state.isSynchronized ? "link" : "link.badge.xmark")
          .font(.caption)
      }
      .help(state.isSynchronized ? "Panes are synchronized" : "Panes navigate independently")

      Button {
        withAnimation {
          state.splitDirection = state.splitDirection == .horizontal ? .vertical : .horizontal
        }
      } label: {
        Image(systemName: state.splitDirection == .horizontal ? "rectangle.split纵向" : "rectangle.split横向")
          .font(.caption)
      }
      .help("Toggle split direction")
    }
    .padding(4)
    .background(.regularMaterial)
    .cornerRadius(6)
    .padding(8)
  }
}

// MARK: - PDFKit Page View (Single Page)

/// A simple NSViewRepresentable that renders a single PDFPage.
struct PDFKitPageView: NSViewRepresentable {
  let page: PDFPage

  func makeNSView(context: Context) -> PDFView {
    let pdfView = PDFView()
    pdfView.document = PDFDocument(data: Data())
    pdfView.autoScales = true
    pdfView.displayMode = .singlePage
    pdfView.backgroundColor = .windowBackgroundColor

    // Create a single-page document
    if let pageData = page.document?.dataRepresentation(),
       let singlePageDoc = PDFDocument(data: pageData) {
      pdfView.document = singlePageDoc
    }

    return pdfView
  }

  func updateNSView(_ nsView: PDFView, context: Context) {
    // Update if page changed
  }
}
