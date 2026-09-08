import CoreGraphics
import Foundation
import ImageIO

/// Poppler-based PDF renderer using pdftoppm for visual fidelity comparison.
///
/// This provides an independent rendering engine to compare against PDFKit's
/// built-in thumbnail generation. Uses pdftoppm to render pages to PNG at
/// configurable DPI.
///
/// Usage:
///   let renderer = PopplerRenderer()
///   let images = renderer.renderPages(pdfURL: url, dpi: 150)
///   // images is [Int: Data] mapping page numbers to PNG data
public struct PopplerRenderer: Sendable {

    /// Path to pdftoppm binary. Resolved once at init time.
    private let pdftoppmPath: String

    public init() {
        // Standard Homebrew path on Apple Silicon
        let candidates = [
            "/opt/homebrew/bin/pdftoppm",
            "/usr/local/bin/pdftoppm",
            "/usr/bin/pdoppm",
        ]
        self.pdftoppmPath = candidates.first { FileManager.default.fileExists(atPath: $0) } ?? "pdftoppm"
    }

    /// Whether pdftoppm is available on this system.
    public var isAvailable: Bool {
        FileManager.default.fileExists(atPath: pdftoppmPath)
    }

    /// Render specific pages of a PDF to PNG data.
    ///
    /// - Parameters:
    ///   - pdfURL: URL of the PDF file
    ///   - dpi: Resolution in dots per inch (default 150, matching PDFKit thumbnails)
    ///   - pages: Page numbers to render (1-indexed, matching PDF convention). nil = all pages.
    ///     pdftoppm only supports an inclusive first/last range, so a sparse list
    ///     renders the enclosing range and the result is filtered back to exactly
    ///     the requested page numbers. An empty list renders nothing.
    /// - Returns: Dictionary mapping 1-indexed page numbers to PNG Data, or empty on failure.
    public func renderPages(pdfURL: URL, dpi: Int = 150, pages: [Int]? = nil) -> [Int: Data] {
        guard isAvailable else { return [:] }
        guard FileManager.default.fileExists(atPath: pdfURL.path) else { return [:] }

        let outputDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("poppler-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outputDir) }

        let prefix = outputDir.appendingPathComponent("page").path

        var requestedPages: Set<Int>?
        var args = ["-r", "\(dpi)", "-png"]
        if let pages {
            let valid = Set(pages.filter { $0 >= 1 })
            guard let first = valid.sorted().first, let last = valid.sorted().last else {
                // Explicit but empty/invalid selection: nothing to render.
                return [:]
            }
            requestedPages = valid
            args += ["-f", "\(first)", "-l", "\(last)"]
        }
        args += [pdfURL.path, prefix]

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pdftoppmPath)
        process.arguments = args
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return [:]
        }

        guard process.terminationStatus == 0 else { return [:] }

        // Collect output files (pdftoppm names them page-1.png, page-2.png, etc.)
        var result: [Int: Data] = [:]
        let fm = FileManager.default
        if let files = try? fm.contentsOfDirectory(atPath: outputDir.path) {
            for file in files where file.hasSuffix(".png") {
                // Extract page number from filename like "page-3.png"
                let name = (file as NSString).deletingPathExtension
                let components = name.components(separatedBy: "-")
                if let last = components.last, let pageNum = Int(last) {
                    let fileURL = outputDir.appendingPathComponent(file)
                    if let data = try? Data(contentsOf: fileURL) {
                        result[pageNum] = data
                    }
                }
            }
        }

        // Honor the exact requested selection (the tool rendered the enclosing range).
        if let requestedPages {
            result = result.filter { requestedPages.contains($0.key) }
        }

        return result
    }

    /// Render all pages of a PDF to PNG data.
    public func renderAllPages(pdfURL: URL, dpi: Int = 150) -> [Int: Data] {
        renderPages(pdfURL: pdfURL, dpi: dpi, pages: nil)
    }

    /// Render a single page to PNG data.
    public func renderPage(pdfURL: URL, page: Int, dpi: Int = 150) -> Data? {
        renderPages(pdfURL: pdfURL, dpi: dpi, pages: [page])[page]
    }

    /// Compute structural similarity between two PNG images.
    ///
    /// Both images are decoded and downscaled to a 32×32 device-gray grid;
    /// similarity is `1 −` the normalized mean absolute pixel difference.
    /// Byte-identical inputs short-circuit to 1.0.
    ///
    /// Returns `nil` when either image cannot be decoded — callers must treat
    /// that as "unknown", never as a measured (dis)similarity score.
    public static func structuralSimilarity(_ lhs: Data, _ rhs: Data) -> Double? {
        if lhs == rhs { return 1.0 }
        guard let lhsGrid = grayscaleGrid(from: lhs),
              let rhsGrid = grayscaleGrid(from: rhs),
              lhsGrid.count == rhsGrid.count else {
            return nil
        }

        var totalDifference = 0.0
        for (a, b) in zip(lhsGrid, rhsGrid) {
            totalDifference += abs(Double(a) - Double(b))
        }
        let normalized = totalDifference / Double(lhsGrid.count * 255)
        return max(0.0, min(1.0, 1.0 - normalized))
    }

    /// Decode image data and downscale to a `size × size` grayscale grid.
    private static func grayscaleGrid(from data: Data, size: Int = 32) -> [UInt8]? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }

        guard let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .low
        context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
        guard let buffer = context.data else { return nil }
        return Array(
            UnsafeBufferPointer(
                start: buffer.assumingMemoryBound(to: UInt8.self),
                count: size * size
            )
        )
    }
}
