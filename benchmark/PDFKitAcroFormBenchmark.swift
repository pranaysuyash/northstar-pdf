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
            throw BenchmarkError.usage("usage: PDFKitAcroFormBenchmark --input <pdf> --output-dir <directory>")
        }
        inputURL = URL(fileURLWithPath: inputPath)
        outputDirectory = URL(fileURLWithPath: outputPath, isDirectory: true)
    }
}

private struct WidgetSnapshot: Codable, Equatable {
    let fieldName: String
    let fieldType: String
    let controlType: Int?
    let value: String?
    let choices: [String]?
    let bounds: [Double]
}

private struct BenchmarkResult: Codable {
    let provider: String
    let fixture: String
    let inputSHA256: String
    let pages: Int
    let widgetCount: Int
    let widgetTypes: [String]
    let noOpReopen: Bool
    let widgetStateEquivalent: Bool
    let mutatedReopen: Bool
    let originalUnchanged: Bool
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

private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else { throw BenchmarkError.failed(message) }
}

private func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func widgetSnapshots(in document: PDFDocument) -> [WidgetSnapshot] {
    var annotations: [PDFAnnotation] = []
    for index in 0..<document.pageCount {
        guard let page = document.page(at: index) else { continue }
        annotations.append(contentsOf: page.annotations)
    }

    var widgets: [WidgetSnapshot] = []
    for annotation in annotations where annotation.type == "Widget" {
        guard let fieldName = annotation.fieldName else { continue }
        let fieldType = annotation.widgetFieldType
        let controlType: Int?
        if fieldType == PDFAnnotationWidgetSubtype.button {
            controlType = annotation.widgetControlType.rawValue
        } else {
            controlType = nil
        }
        let bounds = annotation.bounds
        widgets.append(WidgetSnapshot(
            fieldName: fieldName,
            fieldType: fieldType.rawValue,
            controlType: controlType,
            value: annotation.widgetStringValue,
            choices: annotation.choices,
            bounds: [Double(bounds.minX), Double(bounds.minY), Double(bounds.width), Double(bounds.height)]
        ))
    }
    return widgets.sorted { $0.fieldName < $1.fieldName }
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
          let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw BenchmarkError.failed("could not create render output at \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw BenchmarkError.failed("could not finalize render output at \(url.path)")
    }
}

private func run(arguments: Arguments) throws -> BenchmarkResult {
    let fileManager = FileManager.default
    try fileManager.createDirectory(at: arguments.outputDirectory, withIntermediateDirectories: true)
    let inputData = try Data(contentsOf: arguments.inputURL)
    let inputDigest = sha256(inputData)
    guard let document = PDFDocument(data: inputData) else {
        throw BenchmarkError.failed("PDFKit could not open input")
    }

    let originalWidgets = widgetSnapshots(in: document)
    let widgetTypes = Array(Set(originalWidgets.map(\.fieldType))).sorted()
    try require(document.pageCount == 1, "expected one public sample page")
    try require(originalWidgets.count > 0, "expected public sample to contain widgets")
    try require(widgetTypes.contains(PDFAnnotationWidgetSubtype.text.rawValue), "missing text widgets")
    try require(widgetTypes.contains(PDFAnnotationWidgetSubtype.button.rawValue), "missing button widgets")
    try require(widgetTypes.contains(PDFAnnotationWidgetSubtype.choice.rawValue), "missing choice widgets")

    guard let originalPage = document.page(at: 0) else {
        throw BenchmarkError.failed("missing public sample page")
    }
    try render(page: originalPage, to: arguments.outputDirectory.appendingPathComponent("original-page-1.png"))

    let noOpURL = arguments.outputDirectory.appendingPathComponent("noop.pdf")
    guard document.write(to: noOpURL), let noOp = PDFDocument(url: noOpURL) else {
        throw BenchmarkError.failed("could not write or reopen no-op output")
    }
    let noOpWidgets = widgetSnapshots(in: noOp)
    let noOpReopen = noOp.pageCount == document.pageCount && noOpWidgets.count == originalWidgets.count
    let widgetStateEquivalent = noOpWidgets == originalWidgets
    try require(noOpReopen, "no-op output changed page or widget count")
    guard let noOpPage = noOp.page(at: 0) else {
        throw BenchmarkError.failed("missing no-op page")
    }
    try render(page: noOpPage, to: arguments.outputDirectory.appendingPathComponent("noop-page-1.png"))

    guard let textWidget = noOpPage.annotations.first(where: {
        $0.type == "Widget" && $0.widgetFieldType == PDFAnnotationWidgetSubtype.text
    }) else {
        throw BenchmarkError.failed("could not find public sample text widget")
    }
    textWidget.widgetStringValue = "PDFKit benchmark"
    let mutatedURL = arguments.outputDirectory.appendingPathComponent("mutated.pdf")
    guard noOp.write(to: mutatedURL), let mutated = PDFDocument(url: mutatedURL) else {
        throw BenchmarkError.failed("could not write or reopen mutated output")
    }
    let mutatedReopen = mutated.page(at: 0)?.annotations.contains {
        $0.type == "Widget" && $0.widgetStringValue == "PDFKit benchmark"
    } ?? false
    try require(mutatedReopen, "mutated text value did not survive reopen")

    let sourceUnchanged = sha256(try Data(contentsOf: arguments.inputURL)) == inputDigest
    try require(sourceUnchanged, "input digest changed during benchmark")

    return BenchmarkResult(
        provider: "PDFKit",
        fixture: "public-acroform",
        inputSHA256: inputDigest,
        pages: document.pageCount,
        widgetCount: originalWidgets.count,
        widgetTypes: widgetTypes,
        noOpReopen: noOpReopen,
        widgetStateEquivalent: widgetStateEquivalent,
        mutatedReopen: mutatedReopen,
        originalUnchanged: sourceUnchanged
    )
}

do {
    let result = try run(arguments: Arguments(arguments: Array(CommandLine.arguments.dropFirst())))
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(result)
    print(String(decoding: data, as: UTF8.self))
    try require(
        result.widgetStateEquivalent,
        "no-op output changed widget state; inspect result.json for the original/reopened field comparison"
    )
} catch {
    fputs("ERROR: \(error)\n", stderr)
    exit(1)
}
