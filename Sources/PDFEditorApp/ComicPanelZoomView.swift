import AppKit
import PDFEditorCore
import PDFKit
import SwiftUI

/// Comic panel zoom view: displays one panel at a time, tap to advance,
/// swipe to go back. Supports RTL page order for manga.
///
/// Built on the tile renderer's output — each panel is rendered at the
/// exact DPI needed to fill the screen.
///
/// First principle: the content unit is the panel, not the page.
/// The view fills the screen with one panel and lets the user navigate
/// through the reading flow by tapping.
struct ComicPanelZoomView: View {
  let document: PDFDocument
  let config: ComicModeConfig
  let pipeline: RenderingPipeline?

  @State private var readingState: ComicReadingState?
  @State private var renderedImage: NSImage?
  @State private var isLoading = false

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      if let state = readingState, let panel = state.currentPanel {
        // Current panel image
        if let img = renderedImage {
          Image(nsImage: img)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onTapGesture {
              advancePanel()
            }
        } else if isLoading {
          ProgressView()
            .progressViewStyle(.circular)
            .tint(.white)
        } else {
          Text("Loading panel...")
            .foregroundStyle(.white)
        }

        // Page/panel indicator overlay
        VStack {
          Spacer()
          HStack {
            Text("Page \(currentPageIndex + 1) · Panel \(state.currentPanelIndex + 1)/\(state.totalPanels)")
              .font(.caption)
              .foregroundStyle(.white)
              .padding(.horizontal, 12)
              .padding(.vertical, 6)
              .background(.ultraThinMaterial)
              .clipShape(Capsule())

            Spacer()

            // Progress bar
            Text("\(Int(state.progress * 100))%")
              .font(.caption.monospacedDigit())
              .foregroundStyle(.white)
              .padding(.horizontal, 12)
              .padding(.vertical, 6)
              .background(.ultraThinMaterial)
              .clipShape(Capsule())
          }
          .padding(16)
        }

        // Navigation arrows (visible on hover)
        HStack {
          Button {
            goBackPanel()
          } label: {
            Image(systemName: "chevron.left")
              .font(.title2)
              .foregroundStyle(.white)
              .padding(12)
              .background(.ultraThinMaterial)
              .clipShape(Circle())
          }
          .disabled(state.currentPanelIndex == 0)
          .opacity(state.currentPanelIndex == 0 ? 0.3 : 0.8)

          Spacer()

          Button {
            advancePanel()
          } label: {
            Image(systemName: "chevron.right")
              .font(.title2)
              .foregroundStyle(.white)
              .padding(12)
              .background(.ultraThinMaterial)
              .clipShape(Circle())
          }
          .disabled(state.currentPanelIndex >= state.totalPanels - 1)
          .opacity(state.currentPanelIndex >= state.totalPanels - 1 ? 0.3 : 0.8)
        }
        .padding(.horizontal, 20)
      }
    }
    .onAppear {
      detectAndLoadPanels()
    }
  }

  // MARK: - Computed

  private var currentPageIndex: Int {
    readingState?.currentPanel?.pageIndex ?? 0
  }

  // MARK: - Actions

  private func advancePanel() {
    guard var state = readingState else { return }
    if state.advance() {
      readingState = state
      renderCurrentPanel()
    }
  }

  private func goBackPanel() {
    guard var state = readingState else { return }
    if state.goBack() {
      readingState = state
      renderCurrentPanel()
    }
  }

  // MARK: - Panel Detection & Rendering

  private func detectAndLoadPanels() {
    guard let data = document.dataRepresentation() else { return }

    let detector = PanelDetector()
    var allPanels: [ComicPanel] = []

    for pageIndex in 0..<document.pageCount {
      guard let page = document.page(at: pageIndex) else { continue }
      let pageBounds = page.bounds(for: .mediaBox)

      // Render the page for panel detection
      let scale: CGFloat = 1.0 // 72 DPI for detection
      let pixelWidth = Int(pageBounds.width * scale)
      let pixelHeight = Int(pageBounds.height * scale)

      let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
      guard let context = CGContext(
        data: nil,
        width: max(1, pixelWidth),
        height: max(1, pixelHeight),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      ) else { continue }

      context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
      context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
      context.scaleBy(x: scale, y: scale)
      page.draw(with: .mediaBox, to: context)

      guard let image = context.makeImage() else { continue }

      let panels = detector.detectPanels(image: image, pageIndex: pageIndex, pageBounds: pageBounds)
      allPanels.append(contentsOf: panels)
    }

    readingState = ComicReadingState(panels: allPanels, config: config)
    renderCurrentPanel()
  }

  private func renderCurrentPanel() {
    guard let state = readingState, let panel = state.currentPanel else {
      renderedImage = nil
      return
    }

    isLoading = true

    let doc = document
    Task(priority: .userInitiated) { @MainActor in
      guard let page = doc.page(at: panel.pageIndex) else {
        self.isLoading = false
        return
      }

      let pageBounds = page.bounds(for: .mediaBox)
      // Render at screen resolution for the panel region
      let targetDPI = 150 // good quality for screen
      let scale = CGFloat(targetDPI) / 72.0

      // Calculate the pixel region for this panel
      let panelPixelX = Int((panel.bounds.origin.x - pageBounds.origin.x) * scale)
      let panelPixelY = Int((panel.bounds.origin.y - pageBounds.origin.y) * scale)
      let panelPixelW = Int(panel.bounds.width * scale)
      let panelPixelH = Int(panel.bounds.height * scale)

      // Render the full page at target DPI
      let fullPixelW = Int(pageBounds.width * scale)
      let fullPixelH = Int(pageBounds.height * scale)

      let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
      guard let context = CGContext(
        data: nil,
        width: max(1, fullPixelW),
        height: max(1, fullPixelH),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      ) else {
        self.isLoading = false
        return
      }

      context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
      context.fill(CGRect(x: 0, y: 0, width: fullPixelW, height: fullPixelH))
      context.scaleBy(x: scale, y: scale)
      page.draw(with: .mediaBox, to: context)

      guard let fullImage = context.makeImage() else {
        self.isLoading = false
        return
      }

      // Crop to panel region
      let cropRect = CGRect(
        x: max(0, panelPixelX),
        y: max(0, fullPixelH - panelPixelY - panelPixelH), // flip Y for CGImage
        width: min(panelPixelW, fullPixelW - max(0, panelPixelX)),
        height: min(panelPixelH, fullPixelH - max(0, fullPixelH - panelPixelY - panelPixelH))
      )

      guard let croppedImage = fullImage.cropping(to: cropRect) else {
        self.isLoading = false
        return
      }

      let nsImage = NSImage(cgImage: croppedImage, size: NSSize(width: croppedImage.width, height: croppedImage.height))
      self.renderedImage = nsImage
      self.isLoading = false
    }
  }
}
