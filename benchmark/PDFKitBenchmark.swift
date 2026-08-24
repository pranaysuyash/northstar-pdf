import AppKit
import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers

private struct Arguments {
    let inputURL: URL
    let outputDirectory: URL

    init(arguments: [String]) throws {
        var inputPath: String?
        var outputPath: String?
        var index = 0

        while index < arguments.count {
            switch arguments[index] {
            case "--input":
                index += 1
                guard index < arguments.count else { throw BenchmarkError.usage("--input requires a path") }
                inputPath = arguments[index]
            case "--output-dir":
                index += 1
                guard index < arguments.count else { throw BenchmarkError.usage("--output-dir requires a path") }
                outputPath = arguments[index]
            default:
                throw BenchmarkError.usage("unknown argument: \(arguments[index])")
            }
            index += 1
        }

        guard let inputPath, let outputPath else {
            throw BenchmarkError.usage("usage: PDFKitBenchmark --input <pdf> --output-dir <directory>")
        }

        inputURL = URL(fileURLWithPath: inputPath, isDirectory: false)
        outputDirectory = URL(fileURLWithPath: outputPath, isDirectory: true)
    }
}

private struct PageSnapshot: Encodable {
    let width: Double
    let height: Double
    let rotation: Int
    let characterCount: Int
    let annotationCount: Int
    let widgetCount: Int
}

private struct BenchmarkResult: Encodable {
    let provider: String
    let inputSHA256: String
    let pages: Int
    let nativeWidgetCount: Int
    let textNonEmpty: Bool
    let noOpReopen: Bool
    let noOpTextEquivalent: Bool
    let overlayReopen: Bool
    let overlayTextEquivalent: Bool
    let overlayAnnotationCount: Int
    let renderedPageCount: Int
    let originalUnchanged: Bool
    let pageSnapshots: [PageSnapshot]
}

private enum BenchmarkError: Error, CustomStringConvertible {
    case usage(String)
    case failed(String)

    var description: String {
        switch self {
        case let .usage(message), let .failed(message):
            return message
        }
    }
}

private func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else { throw BenchmarkError.failed(message) }
}

private func approximatelyEqual(_ lhs: CGRect, _ rhs: CGRect, tolerance: CGFloat = 0.01) -> Bool {
    abs(lhs.minX - rhs.minX) < tolerance
        && abs(lhs.minY - rhs.minY) < tolerance
        && abs(lhs.width - rhs.width) < tolerance
        && abs(lhs.height - rhs.height) < tolerance
}

private func pageStrings(in document: PDFDocument) -> [String] {
    (0..<document.pageCount).map { document.page(at: $0)?.string ?? "" }
}

private func snapshots(in document: PDFDocument) -> [PageSnapshot] {
    (0..<document.pageCount).compactMap { index -> PageSnapshot? in
        guard let page = document.page(at: index) else { return nil }
        let annotations = page.annotations
        let widgetCount = annotations.filter { $0.type == "Widget" }.count
        let bounds = page.bounds(for: .mediaBox)
        return PageSnapshot(
            width: Double(bounds.width),
            height: Double(bounds.height),
            rotation: page.rotation,
            characterCount: page.numberOfCharacters,
            annotationCount: annotations.count,
            widgetCount: widgetCount
        )
    }
}

private func nativeWidgetCount(in document: PDFDocument) -> Int {
    snapshots(in: document).reduce(0) { $0 + $1.widgetCount }
}

private func render(page: PDFPage, to url: URL, scale: CGFloat = 2) throws {
    let bounds = page.bounds(for: .mediaBox)
    let width = max(1, Int(ceil(bounds.width * scale)))
    let height = max(1, Int(ceil(bounds.height * scale)))
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else {
        throw BenchmarkError.failed("could not create render context")
    }

    context.setFillColor(NSColor.white.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.saveGState()
    context.scaleBy(x: scale, y: scale)
    page.draw(with: .mediaBox, to: context)
    context.restoreGState()

    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(
              url as CFURL,
              UTType.png.identifier as CFString,
              1,
              nil
          ) else {
        throw BenchmarkError.failed("could not create PNG destination at \(url.path)")
    }

    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw BenchmarkError.failed("could not finalize PNG at \(url.path)")
    }
}

private func render(document: PDFDocument, into directory: URL, prefix: String) throws -> Int {
    var count = 0
    for index in 0..<document.pageCount {
        guard let page = document.page(at: index) else {
            throw BenchmarkError.failed("missing page at index \(index)")
        }
        let outputURL = directory.appendingPathComponent("\(prefix)-page-\(index + 1).png")
        try render(page: page, to: outputURL)
        count += 1
    }
    return count
}

private func makeOverlayDocument(from data: Data) throws -> (PDFDocument, CGRect) {
    guard let document = PDFDocument(data: data), let page = document.page(at: 0) else {
        throw BenchmarkError.failed("could not create overlay document")
    }

    let mediaBox = page.bounds(for: .mediaBox)
    let bounds = CGRect(
        x: mediaBox.minX + 72,
        y: mediaBox.maxY - 96,
        width: 140,
        height: 20
    )
    let annotation = PDFAnnotation(
        bounds: bounds,
        forType: PDFAnnotationSubtype.freeText,
        withProperties: nil
    )
    annotation.contents = "PDFKit benchmark"
    annotation.font = NSFont.systemFont(ofSize: 10)
    annotation.fontColor = NSColor.black
    page.addAnnotation(annotation)
    return (document, bounds)
}

private func run(arguments: Arguments) throws -> BenchmarkResult {
    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: arguments.inputURL.path) else {
        throw BenchmarkError.failed("input does not exist: \(arguments.inputURL.path)")
    }
    try fileManager.createDirectory(at: arguments.outputDirectory, withIntermediateDirectories: true)

    let inputData = try Data(contentsOf: arguments.inputURL)
    let inputDigest = sha256(inputData)
    guard let document = PDFDocument(data: inputData) else {
        throw BenchmarkError.failed("PDFKit could not open input")
    }

    let originalStrings = pageStrings(in: document)
    let originalSnapshots = snapshots(in: document)
    let originalWidgetCount = nativeWidgetCount(in: document)
    try require(document.pageCount == 2, "expected Form 6 to have 2 pages")
    try require(originalWidgetCount == 0, "expected Form 6 to have zero native widgets")
    try require(originalStrings.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }, "expected extracted text")
    try require(originalSnapshots.count == 2, "expected two page snapshots")
    for snapshot in originalSnapshots {
        try require(abs(snapshot.width - 612) < 0.01, "unexpected page width: \(snapshot.width)")
        try require(abs(snapshot.height - 841.68) < 0.01, "unexpected page height: \(snapshot.height)")
    }

    let renderedOriginalCount = try render(document: document, into: arguments.outputDirectory, prefix: "original")

    let noOpURL = arguments.outputDirectory.appendingPathComponent("noop.pdf")
    guard document.write(to: noOpURL) else {
        throw BenchmarkError.failed("PDFKit failed to write no-op output")
    }
    guard let noOpDocument = PDFDocument(url: noOpURL) else {
        throw BenchmarkError.failed("PDFKit could not reopen no-op output")
    }
    let noOpStrings = pageStrings(in: noOpDocument)
    let noOpReopen = noOpDocument.pageCount == document.pageCount
        && snapshots(in: noOpDocument).map(\.width) == originalSnapshots.map(\.width)
        && snapshots(in: noOpDocument).map(\.height) == originalSnapshots.map(\.height)
        && snapshots(in: noOpDocument).map(\.rotation) == originalSnapshots.map(\.rotation)
        && nativeWidgetCount(in: noOpDocument) == originalWidgetCount
    try require(noOpReopen, "no-op output did not preserve page or widget state")
    try require(noOpStrings == originalStrings, "no-op output changed extracted page text")
    _ = try render(document: noOpDocument, into: arguments.outputDirectory, prefix: "noop")

    let (overlayDocument, overlayBounds) = try makeOverlayDocument(from: inputData)
    let overlayURL = arguments.outputDirectory.appendingPathComponent("overlay.pdf")
    guard overlayDocument.write(to: overlayURL) else {
        throw BenchmarkError.failed("PDFKit failed to write overlay output")
    }
    guard let reopenedOverlay = PDFDocument(url: overlayURL),
          let overlayPage = reopenedOverlay.page(at: 0) else {
        throw BenchmarkError.failed("PDFKit could not reopen overlay output")
    }
    let matchingAnnotations = overlayPage.annotations.filter {
        $0.type == "FreeText" && approximatelyEqual($0.bounds, overlayBounds)
    }
    let reopenedAnnotationSummary = overlayPage.annotations.map {
        "type=\($0.type ?? "nil"),bounds=\($0.bounds)"
    }.joined(separator: ";")
    try require(
        matchingAnnotations.count == 1,
        "expected one bounded FreeText annotation after reopen; observed [\(reopenedAnnotationSummary)]"
    )
    let overlayStrings = pageStrings(in: reopenedOverlay)
    try require(overlayStrings == originalStrings, "overlay output changed extracted page text")

    let finalDigest = sha256(try Data(contentsOf: arguments.inputURL))
    let originalUnchanged = finalDigest == inputDigest
    try require(originalUnchanged, "input digest changed during benchmark")

    return BenchmarkResult(
        provider: "PDFKit",
        inputSHA256: inputDigest,
        pages: document.pageCount,
        nativeWidgetCount: originalWidgetCount,
        textNonEmpty: originalStrings.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
        noOpReopen: noOpReopen,
        noOpTextEquivalent: noOpStrings == originalStrings,
        overlayReopen: true,
        overlayTextEquivalent: overlayStrings == originalStrings,
        overlayAnnotationCount: matchingAnnotations.count,
        renderedPageCount: renderedOriginalCount,
        originalUnchanged: originalUnchanged,
        pageSnapshots: originalSnapshots
    )
}

do {
    let arguments = try Arguments(arguments: Array(CommandLine.arguments.dropFirst()))
    let result = try run(arguments: arguments)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let output = try encoder.encode(result)
    FileHandle.standardOutput.write(output)
    FileHandle.standardOutput.write(Data("\n".utf8))
} catch {
    FileHandle.standardError.write(Data("PDFKit benchmark failed: \(error)\n".utf8))
    exit(EXIT_FAILURE)
}
