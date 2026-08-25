import AppKit
import Foundation
import PDFEditorCore

struct OCRInput: Codable {
  let fixtureId: String
  let imagePath: String
  let groundTruthPath: String
}

struct OCRInputManifest: Codable {
  let inputs: [OCRInput]
}

struct OCRResult: Codable {
  let fixtureId: String
  let providerId: String
  let status: String
  let observationCount: Int
  let requiredAnchorCount: Int
  let matchedAnchorCount: Int
  let anchorRecall: Double
  let latencyMilliseconds: Double?
  let confidenceMean: Double?
  let confidenceMinimum: Double?
  let confidenceMaximum: Double?
  let coordinateSpace: String?
  let boundsValidCount: Int
  let boundsUnion: PDFRect?
  let errorCode: String?
}

private func boundsSummary(_ observations: [OCRObservation]) -> (space: String, validCount: Int, union: PDFRect?) {
  let observationBounds = observations.map { $0.normalizedBounds }
  let valid = observationBounds.filter { bounds in
    bounds.x >= 0 && bounds.y >= 0 && bounds.width > 0 && bounds.height > 0
      && bounds.x + bounds.width <= 1.0001 && bounds.y + bounds.height <= 1.0001
  }
  guard let first = valid.first else {
    return ("normalizedLowerLeft", 0, nil)
  }
  let union = valid.dropFirst().reduce(first.cgRect) { partial, bounds in
    partial.union(bounds.cgRect)
  }
  return ("normalizedLowerLeft", valid.count, PDFRect(union))
}

private func normalized(_ value: String) -> String {
  value
    .lowercased()
    .unicodeScalars
    .map { scalar in
      CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
    }
    .map(String.init)
    .joined()
    .split(whereSeparator: \ .isWhitespace)
    .joined(separator: " ")
}

private func anchors(at path: String) -> [String] {
  guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
  return content
    .split(whereSeparator: \ .isNewline)
    .map { normalized(String($0)) }
    .filter { !$0.isEmpty }
}

private func image(at path: String) -> CGImage? {
  guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else { return nil }
  return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

private func result(
  input: OCRInput,
  status: String,
  observationCount: Int = 0,
  requiredAnchorCount: Int = 0,
  matchedAnchorCount: Int = 0,
  latencyMilliseconds: Double? = nil,
  confidenceMean: Double? = nil,
  confidenceMinimum: Double? = nil,
  confidenceMaximum: Double? = nil,
  coordinateSpace: String? = nil,
  boundsValidCount: Int = 0,
  boundsUnion: PDFRect? = nil,
  errorCode: String? = nil
) -> OCRResult {
  OCRResult(
    fixtureId: input.fixtureId,
    providerId: "native-vision",
    status: status,
    observationCount: observationCount,
    requiredAnchorCount: requiredAnchorCount,
    matchedAnchorCount: matchedAnchorCount,
    anchorRecall: requiredAnchorCount == 0 ? 0 : Double(matchedAnchorCount) / Double(requiredAnchorCount),
    latencyMilliseconds: latencyMilliseconds,
    confidenceMean: confidenceMean,
    confidenceMinimum: confidenceMinimum,
    confidenceMaximum: confidenceMaximum,
    coordinateSpace: coordinateSpace,
    boundsValidCount: boundsValidCount,
    boundsUnion: boundsUnion,
    errorCode: errorCode
  )
}

let arguments = CommandLine.arguments
guard let manifestIndex = arguments.firstIndex(of: "--inputs"), arguments.count > manifestIndex + 1 else {
  FileHandle.standardError.write(Data("usage: PDFOCRBenchmark --inputs <manifest.json>\n".utf8))
  exit(2)
}

let manifestPath = arguments[manifestIndex + 1]
let manifest: OCRInputManifest
do {
  manifest = try JSONDecoder().decode(OCRInputManifest.self, from: Data(contentsOf: URL(fileURLWithPath: manifestPath)))
} catch {
  FileHandle.standardError.write(Data("invalid-input-manifest\n".utf8))
  exit(2)
}

let provider = VisionOCRProvider(recognitionLevel: .accurate)
let results = manifest.inputs.map { input -> OCRResult in
  let expected = anchors(at: input.groundTruthPath)
  guard let sourceImage = image(at: input.imagePath) else {
    return result(input: input, status: "blocked", requiredAnchorCount: expected.count, errorCode: "image-unreadable")
  }

  let start = ProcessInfo.processInfo.systemUptime
  do {
    let observations = try provider.recognize(image: sourceImage)
    let observed = observations.map { normalized($0.text) }
    let matched = expected.filter { anchor in
      observed.contains { candidate in candidate.contains(anchor) || anchor.contains(candidate) }
    }.count
    let confidences = observations.map(\.confidence)
    let mean = confidences.isEmpty ? nil : confidences.reduce(0, +) / Double(confidences.count)
    let bounds = boundsSummary(observations)
    return result(
      input: input,
      status: "measured",
      observationCount: observations.count,
      requiredAnchorCount: expected.count,
      matchedAnchorCount: matched,
      latencyMilliseconds: (ProcessInfo.processInfo.systemUptime - start) * 1000,
      confidenceMean: mean,
      confidenceMinimum: confidences.min(),
      confidenceMaximum: confidences.max(),
      coordinateSpace: bounds.space,
      boundsValidCount: bounds.validCount,
      boundsUnion: bounds.union
    )
  } catch {
    return result(input: input, status: "failed", requiredAnchorCount: expected.count, errorCode: "vision-request-failed")
  }
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]
print(String(data: try! encoder.encode(results), encoding: .utf8)!)
