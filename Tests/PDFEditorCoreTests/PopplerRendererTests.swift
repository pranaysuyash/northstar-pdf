import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import PDFEditorCore

/// Tests for the Poppler pdftoppm renderer (third viewer for visual fidelity).
@Suite("Poppler Renderer")
struct PopplerRendererTests {

    private static var projectRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    @Test("Poppler renderer is available")
    func rendererAvailable() {
        let renderer = PopplerRenderer()
        guard renderer.isAvailable else {
            // pdftoppm is a local brew dependency; absence = not_ran provenance
            // (same convention as the tool-dependent node contract tests).
            print("not_ran: pdftoppm not installed (brew install poppler)")
            return
        }
        #expect(renderer.isAvailable)
    }

    @Test("Render public-sample-form page 1 to PNG")
    func renderSinglePage() throws {
        let renderer = PopplerRenderer()
        guard renderer.isAvailable else {
            print("not_ran: pdftoppm not installed; skipping render fidelity check")
            return
        }
        let url = Self.projectRoot.appendingPathComponent("benchmark/results/public-sample-form.pdf")
        guard FileManager.default.fileExists(atPath: url.path) else {
            Issue.record("fixture not found"); return
        }
        let png = renderer.renderPage(pdfURL: url, page: 1, dpi: 72)
        #expect(png != nil, "pdftoppm must produce PNG output")
        #expect(png!.count > 1000, "PNG must be non-trivial (>1KB)")

        // Verify it starts with PNG header (89 50 4E 47 0D 0A 1A 0A)
        let header = Data(png!.prefix(8))
        let expectedHeader = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        #expect(header == expectedHeader,
                "Output must be valid PNG (correct header)")
    }

    @Test("Render all pages of a multi-page PDF")
    func renderAllPages() throws {
        let renderer = PopplerRenderer()
        guard renderer.isAvailable else {
            print("not_ran: pdftoppm not installed; skipping multi-page render check")
            return
        }
        // Use the 40-page hybrid as a multi-page test
        let url = Self.projectRoot.appendingPathComponent("benchmark/results/browser-corpus/large-hybrid-40-pages.pdf")
        guard FileManager.default.fileExists(atPath: url.path) else {
            Issue.record("fixture not found"); return
        }
        let pages = renderer.renderAllPages(pdfURL: url, dpi: 72)
        #expect(pages.count >= 1, "Must render at least 1 page")
        #expect(pages.keys.contains(1), "Page 1 must be present")
    }

    @Test("Render multiple fixtures to verify robustness")
    func renderMultipleFixtures() throws {
        let renderer = PopplerRenderer()
        guard renderer.isAvailable else {
            Issue.record("pdftoppm not installed"); return
        }
        let fixtures = [
            "benchmark/results/public-sample-form.pdf",
            "benchmark/results/2026-08-23-pdfkit-widgets/noop.pdf",
            "benchmark/results/browser-corpus/hybrid-text-raster-form.pdf",
        ]
        var rendered = 0
        for rel in fixtures {
            let url = Self.projectRoot.appendingPathComponent(rel)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            let png = renderer.renderPage(pdfURL: url, page: 1, dpi: 72)
            if png != nil && png!.count > 500 {
                rendered += 1
            }
        }
        #expect(rendered >= 2, "At least 2 of 3 fixtures must render successfully")
    }

    // MARK: - Structural Similarity (real bitmap comparison)

    private static func pngData(fill: CGFloat) -> Data {
        let size = 64
        let context = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
        )!
        context.setFillColor(gray: fill, alpha: 1.0)
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))
        let image = context.makeImage()!
        let output = NSMutableData()
        let destination = CGImageDestinationCreateWithData(
            output, UTType.png.identifier as CFString, 1, nil
        )!
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
        return output as Data
    }

    @Test("Byte-identical images score 1.0")
    func similarityIdentical() {
        let png = Self.pngData(fill: 0.5)
        #expect(PopplerRenderer.structuralSimilarity(png, png) == 1.0)
    }

    @Test("Different images score in [0, 1) — never the old constant 0.5")
    func similarityDifferent() {
        let white = Self.pngData(fill: 1.0)
        let black = Self.pngData(fill: 0.0)
        let score = PopplerRenderer.structuralSimilarity(white, black)
        #expect(score != nil, "Both PNGs must decode")
        #expect(score! >= 0.0 && score! < 1.0, "Fully-inverted images cannot score 1.0")
        #expect(score! < 0.5, "Black vs white is a maximal difference, not the stub's 0.5")
    }

    @Test("Undecodable input returns nil (unknown), not a score")
    func similarityUndecodable() {
        let garbage = Data("not a png at all".utf8)
        let png = Self.pngData(fill: 0.5)
        #expect(PopplerRenderer.structuralSimilarity(garbage, png) == nil)
        #expect(PopplerRenderer.structuralSimilarity(png, garbage) == nil)
    }

    // MARK: - Page Selection Semantics

    @Test("Empty page selection renders nothing instead of crashing")
    func emptyPageSelection() throws {
        let renderer = PopplerRenderer()
        guard renderer.isAvailable else {
            Issue.record("pdftoppm not installed"); return
        }
        let url = Self.projectRoot.appendingPathComponent("benchmark/results/public-sample-form.pdf")
        guard FileManager.default.fileExists(atPath: url.path) else {
            Issue.record("fixture not found"); return
        }
        #expect(renderer.renderPages(pdfURL: url, dpi: 72, pages: []).isEmpty)
        #expect(renderer.renderPages(pdfURL: url, dpi: 72, pages: [0, -1]).isEmpty)
    }
}
