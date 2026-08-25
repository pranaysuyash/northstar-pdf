import AppKit
import CryptoKit
import Foundation
import PDFEditorCore
import PDFKit

private struct NativeRun: Codable {
  let runID: String
  let pageIndex: Int
  let sequence: Int
  let textHash: String
  let characterCount: Int
  let bounds: PDFRect
  let pageBounds: PDFRect
  let coordinate: PDFPageRegion
  let geometryStatus: String
  let origin: String
  let providerID: String
  let sourceDigest: String
  let hasEOL: Bool
}

private struct NativeOCRRun: Codable {
  let runID: String
  let pageIndex: Int
  let sequence: Int
  let textHash: String
  let characterCount: Int
  let bounds: PDFRect
  let pageBounds: PDFRect
  let coordinate: PDFPageRegion
  let geometryStatus: String
  let origin: String
  let providerID: String
  let sourceDigest: String
  let hasEOL: Bool
  let confidence: Double?
}

private struct NativePage: Codable {
  let pageIndex: Int
  let bounds: PDFRect
  let rotation: Int
  let textRuns: [NativeRun]
  let ocrRuns: [NativeOCRRun]
  let ocrState: String
}

private struct NativeCase: Codable {
  let fixtureId: String
  let sourcePath: String
  let sourceDigest: String
  let status: String
  let pageCount: Int
  let native: NativeProjection
  let replacement: NativeReplacement
}

private struct NativeProjection: Codable {
  let providerID: String
  let providerVersion: String
  let pages: [NativePage]
}

private struct NativeReplacement: Codable {
  let operationKind: String
  let capabilityState: String
  let reviewState: String
  let replacementValueRetained: Bool
}

private struct NativeReport: Codable {
  let contractName: String
  let version: PDFContractVersion
  let corpusManifest: String
  let generatedAt: String
  let cases: [NativeCase]
}

private enum BenchmarkError: Error, LocalizedError {
  case usage
  case missingManifest(String)

  var errorDescription: String? {
    switch self {
    case .usage: "usage: PDFTextRunOCRBenchmark --manifest <path> --output <path>"
    case let .missingManifest(path): "fixture manifest not found: \(path)"
    }
  }
}

private func normalizedText(_ value: String) -> String {
  value
    .precomposedStringWithCanonicalMapping
    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    .trimmingCharacters(in: .whitespacesAndNewlines)
}

private func textHash(_ value: String) -> String {
  let digest = SHA256.hash(data: Data(normalizedText(value).utf8))
  return digest.map { String(format: "%02x", $0) }.joined()
}

private func sourceDigest(_ data: Data) -> String {
  SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func inside(_ bounds: PDFRect, page: PDFRect) -> Bool {
  bounds.x >= page.x - 0.0001
    && bounds.y >= page.y - 0.0001
    && bounds.x + bounds.width <= page.x + page.width + 0.0001
    && bounds.y + bounds.height <= page.y + page.height + 0.0001
}

private func coordinate(pageIndex: Int, rect: PDFRect, rotation: Int) -> PDFPageRegion {
  PDFPageRegion(
    pageIndex: pageIndex,
    rect: rect,
    coordinateSpace: PDFCoordinateSpace(
      unit: .points,
      origin: .lowerLeft,
      pageBox: .crop,
      rotationDegrees: rotation
    )
  )
}

private func makeTextRuns(
  page: PDFPage,
  pageIndex: Int,
  pageBounds: PDFRect,
  sourceDigest: String,
  rotation: Int
) -> [NativeRun] {
  guard let selection = page.selection(for: page.bounds(for: .cropBox)) else { return [] }
  return selection.selectionsByLine().enumerated().compactMap { sequence, line in
    guard let text = line.string else { return nil }
    let value = normalizedText(text)
    guard !value.isEmpty else { return nil }
    let lineBounds = PDFRect(line.bounds(for: page))
    let hash = textHash(value)
    return NativeRun(
      runID: "\(pageIndex):\(sequence):\(hash.prefix(16))",
      pageIndex: pageIndex,
      sequence: sequence,
      textHash: hash,
      characterCount: value.count,
      bounds: lineBounds,
      pageBounds: pageBounds,
      coordinate: coordinate(pageIndex: pageIndex, rect: lineBounds, rotation: rotation),
      geometryStatus: inside(lineBounds, page: pageBounds) ? "insidePage" : "outsidePage",
      origin: "pdfkit.selectionByLine",
      providerID: "pdfkit",
      sourceDigest: sourceDigest,
      hasEOL: true
    )
  }
}

private func makeOCRRuns(
  page: PDFPage,
  pageIndex: Int,
  pageBounds: PDFRect,
  sourceDigest: String,
  rotation: Int,
  provider: VisionOCRProvider
) -> ([NativeOCRRun], String) {
  do {
    let observations = try provider.recognize(page: page, pageIndex: pageIndex, scale: 1.5)
    let runs = observations.enumerated().compactMap { sequence, observation -> NativeOCRRun? in
      let value = normalizedText(observation.text)
      guard !value.isEmpty else { return nil }
      let evidence = observation.toPageSpace(pageBounds: pageBounds, pageIndex: pageIndex)
      let hash = textHash(value)
      return NativeOCRRun(
        runID: "\(pageIndex):ocr:\(sequence):\(hash.prefix(16))",
        pageIndex: pageIndex,
        sequence: sequence,
        textHash: hash,
        characterCount: value.count,
        bounds: evidence.bounds,
        pageBounds: pageBounds,
        coordinate: coordinate(pageIndex: pageIndex, rect: evidence.bounds, rotation: rotation),
        geometryStatus: inside(evidence.bounds, page: pageBounds) ? "insidePage" : "outsidePage",
        origin: "vision.textObservation",
        providerID: "native-vision",
        sourceDigest: sourceDigest,
        hasEOL: true,
        confidence: observation.confidence
      )
    }
    return (runs, "measured")
  } catch {
    return ([], "failed")
  }
}

private func argument(_ name: String, in arguments: [String]) -> String? {
  guard let index = arguments.firstIndex(of: name), arguments.count > index + 1 else { return nil }
  return arguments[index + 1]
}

private func manifestPaths(_ manifestURL: URL) throws -> [String] {
  let contents = try String(contentsOf: manifestURL, encoding: .utf8)
  return contents.split(whereSeparator: \.isNewline).compactMap { line in
    line.split(separator: "`").first(where: { $0.hasSuffix(".pdf") }).map(String.init)
  }
}

private func password(for relativePath: String) -> String? {
  relativePath.contains("encrypted-reader.pdf") || relativePath.contains("encrypted-") ? "reader-password" : nil
}

private func expectedFailure(_ relativePath: String) -> Bool {
  relativePath.contains("truncated-128-bytes.pdf") || relativePath.contains("malformed-")
}

@main
struct PDFTextRunOCRBenchmark {
  static func main() throws {
    let arguments = CommandLine.arguments
    guard let manifestPath = argument("--manifest", in: arguments),
      let outputPath = argument("--output", in: arguments)
    else { throw BenchmarkError.usage }

    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    let manifestURL = URL(fileURLWithPath: manifestPath, relativeTo: root).standardizedFileURL
    guard FileManager.default.fileExists(atPath: manifestURL.path) else {
      throw BenchmarkError.missingManifest(manifestURL.path)
    }
    let outputURL = URL(fileURLWithPath: outputPath, relativeTo: root).standardizedFileURL
    try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

    let provider = PDFKitProvider()
    let ocrProvider = VisionOCRProvider(recognitionLevel: .accurate)
    let paths = try manifestPaths(manifestURL)
    var cases: [NativeCase] = []

    for relativePath in paths {
      let fixtureURL = root.appendingPathComponent(relativePath).standardizedFileURL
      do {
        let data = try Data(contentsOf: fixtureURL, options: [.mappedIfSafe])
        let digest = sourceDigest(data)
        let inspection = try provider.inspect(url: fixtureURL, password: password(for: relativePath))
        guard let document = PDFDocument(data: data) else { throw PDFEditorError.cannotOpen(relativePath) }
        if document.isLocked, let fixturePassword = password(for: relativePath) {
          _ = document.unlock(withPassword: fixturePassword)
        }
        var pages: [NativePage] = []
        for pageIndex in 0..<document.pageCount {
          guard let page = document.page(at: pageIndex) else { continue }
          let inspectionPage = inspection.pages[pageIndex]
          let pageBounds = inspectionPage.bounds
          let textRuns = makeTextRuns(
            page: page,
            pageIndex: pageIndex,
            pageBounds: pageBounds,
            sourceDigest: digest,
            rotation: inspectionPage.rotation
          )
          let shouldRunOCR = !inspectionPage.hasSelectableText || inspectionPage.pageIndex < 2
          let ocr = shouldRunOCR
            ? makeOCRRuns(
              page: page,
              pageIndex: pageIndex,
              pageBounds: pageBounds,
              sourceDigest: digest,
              rotation: inspectionPage.rotation,
              provider: ocrProvider
            )
            : ([], "notRequested")
          pages.append(NativePage(
            pageIndex: pageIndex,
            bounds: pageBounds,
            rotation: inspectionPage.rotation,
            textRuns: textRuns,
            ocrRuns: ocr.0,
            ocrState: ocr.1
          ))
        }
        let firstRun = pages.flatMap(\.textRuns).first
        cases.append(NativeCase(
          fixtureId: fixtureURL.deletingPathExtension().lastPathComponent,
          sourcePath: relativePath,
          sourceDigest: digest,
          status: "measured",
          pageCount: document.pageCount,
          native: NativeProjection(
            providerID: "pdfkit",
            providerVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            pages: pages
          ),
          replacement: NativeReplacement(
            operationKind: "textRunReplacement",
            capabilityState: firstRun == nil ? "noTextRun" : "abstained-unsupported",
            reviewState: "review-required",
            replacementValueRetained: false
          )
        ))
      } catch {
        if expectedFailure(relativePath) {
          cases.append(NativeCase(
            fixtureId: fixtureURL.deletingPathExtension().lastPathComponent,
            sourcePath: relativePath,
            sourceDigest: "",
            status: "inspectionFailed",
            pageCount: 0,
            native: NativeProjection(providerID: "pdfkit", providerVersion: ProcessInfo.processInfo.operatingSystemVersionString, pages: []),
            replacement: NativeReplacement(operationKind: "textRunReplacement", capabilityState: "abstained-no-source", reviewState: "not-applicable", replacementValueRetained: false)
          ))
        } else {
          throw error
        }
      }
    }

    let report = NativeReport(
      contractName: "pdf-editor.text-run-ocr-native",
      version: PDFContractVersion.current,
      corpusManifest: "docs/fixtures/manifest.md",
      generatedAt: ISO8601DateFormatter().string(from: Date()),
      cases: cases
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(report).write(to: outputURL, options: .atomic)
    print(String(data: try encoder.encode(report), encoding: .utf8)!)
  }
}
