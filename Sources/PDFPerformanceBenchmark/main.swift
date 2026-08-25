import Darwin
import Foundation
import CoreGraphics
import PDFKit
import PDFEditorCore

private struct BenchmarkManifest: Decodable {
  let fixtures: [ManifestFixture]
}

private struct ManifestFixture: Decodable {
  let id: String
  let path: String
  let passwordEnvironmentVariable: String?
}

private struct FixtureInput {
  let id: String
  let url: URL
  let passwordEnvironmentVariable: String?
}

private struct Arguments {
  var fixturePaths: [String] = []
  var manifestPath: String?
  var passwordEnvironmentVariable: String?
  var shouldInspect = false
  var shouldExport = false
  var exportOutputDirectory: String?
  var renderPageIndex: Int?
  var shouldSampleMemory = false
}

private enum HarnessError: Error {
  case help
  case invalidArgument(String)
  case missingArgumentValue(String)
  case manifestUnreadable
  case manifestInvalid
  case exportOutputDirectoryRequired
  case exportOutputDirectoryUnavailable
  case renderPageUnavailable
}

private struct RunMetadata: Codable {
  let startedAt: String?
  let finishedAt: String?
  let operatingSystem: String?
  let architecture: String?
  let swiftVersion: String?
  let packageRevision: String?
  let warmupPolicy: String?
  let coldWarmPolicy: String?
  let corpusManifest: String?
}

private struct InspectionSummary: Codable {
  let pageCount: Int
  let fieldCount: Int
  let candidateCount: Int
  let linkCount: Int
  let outlineCount: Int
  let attachmentCount: Int
  let warningCount: Int
}

private struct ExportSummary: Codable {
  let status: String
  let validationPassed: Bool?
  let outputReopenable: Bool?
}

private struct RenderSummary: Codable {
  let status: String
}

private struct MemorySummary: Codable {
  let before: NativeMemorySnapshot?
  let after: NativeMemorySnapshot?
}

private struct FixtureSummary: Codable {
  let fixtureID: String
  let status: String
  let inspection: InspectionSummary?
  let export: ExportSummary?
  let render: RenderSummary?
  let memory: MemorySummary?
  let errorCode: String?

  private enum CodingKeys: String, CodingKey {
    case fixtureID
    case status
    case inspection
    case export
    case render
    case memory
    case errorCode
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(fixtureID, forKey: .fixtureID)
    try container.encode(status, forKey: .status)
    try container.encode(inspection, forKey: .inspection)
    try container.encode(export, forKey: .export)
    try container.encode(render, forKey: .render)
    if let memory {
      try container.encode(memory, forKey: .memory)
    }
    try container.encode(errorCode, forKey: .errorCode)
  }
}

private struct BenchmarkReport: Codable {
  let schema: String
  let status: String
  let requestedOperations: [String]
  let runMetadata: RunMetadata
  let fixtures: [FixtureSummary]
  let telemetry: [PerformanceSummary]
}

private func usage() -> String {
  """
  usage: PDFPerformanceBenchmark (--fixture <path>... | --manifest <path>) [options]

  options:
    --inspect                         request provider inspection
    --render-page <index>             request one native PDFKit page render (zero-based)
    --export                          request provider export with zero operations
    --export-output-directory <path>  required with --export; output is not reported
    --password-env <name>             read one password from this environment variable
    --memory                          sample native process memory around requested work
    --help                            print this message

  Manifest format:
    {"fixtures":[{"id":"fixture-label","path":"relative/or/absolute.pdf","passwordEnvironmentVariable":"PDF_PASSWORD"}]}
  """
}

private func parseArguments(_ rawArguments: [String]) throws -> Arguments {
  var parsed = Arguments()
  var index = 0

  while index < rawArguments.count {
    let argument = rawArguments[index]
    switch argument {
    case "--help", "-h":
      throw HarnessError.help
    case "--fixture":
      guard index + 1 < rawArguments.count else {
        throw HarnessError.missingArgumentValue(argument)
      }
      parsed.fixturePaths.append(rawArguments[index + 1])
      index += 2
    case "--manifest":
      guard index + 1 < rawArguments.count else {
        throw HarnessError.missingArgumentValue(argument)
      }
      guard parsed.manifestPath == nil else {
        throw HarnessError.invalidArgument("--manifest may be supplied only once")
      }
      parsed.manifestPath = rawArguments[index + 1]
      index += 2
    case "--password-env":
      guard index + 1 < rawArguments.count else {
        throw HarnessError.missingArgumentValue(argument)
      }
      parsed.passwordEnvironmentVariable = rawArguments[index + 1]
      index += 2
    case "--inspect":
      parsed.shouldInspect = true
      index += 1
    case "--export":
      parsed.shouldExport = true
      index += 1
    case "--export-output-directory":
      guard index + 1 < rawArguments.count else {
        throw HarnessError.missingArgumentValue(argument)
      }
      parsed.exportOutputDirectory = rawArguments[index + 1]
      index += 2
    case "--render-page":
      guard index + 1 < rawArguments.count else {
        throw HarnessError.missingArgumentValue(argument)
      }
      guard parsed.renderPageIndex == nil else {
        throw HarnessError.invalidArgument("--render-page may be supplied only once")
      }
      guard let pageIndex = Int(rawArguments[index + 1]), pageIndex >= 0 else {
        throw HarnessError.invalidArgument("--render-page requires a non-negative page index")
      }
      parsed.renderPageIndex = pageIndex
      index += 2
    case "--memory":
      parsed.shouldSampleMemory = true
      index += 1
    default:
      throw HarnessError.invalidArgument(argument)
    }
  }

  guard !parsed.fixturePaths.isEmpty || parsed.manifestPath != nil else {
    throw HarnessError.invalidArgument("one of --fixture or --manifest is required")
  }
  guard parsed.fixturePaths.isEmpty || parsed.manifestPath == nil else {
    throw HarnessError.invalidArgument("use --fixture or --manifest, not both")
  }
  guard !parsed.shouldExport || parsed.exportOutputDirectory != nil else {
    throw HarnessError.exportOutputDirectoryRequired
  }
  guard parsed.shouldExport || parsed.exportOutputDirectory == nil else {
    throw HarnessError.invalidArgument("--export-output-directory requires --export")
  }

  return parsed
}

private func safeErrorCode(_ error: Error) -> String {
  if case HarnessError.renderPageUnavailable = error {
    return "render_page_unavailable"
  }
  if error is PDFEditorError {
    return "provider_error"
  }
  return "operation_failed"
}

private func fixtures(for arguments: Arguments) throws -> [FixtureInput] {
  if let manifestPath = arguments.manifestPath {
    let manifestURL = URL(fileURLWithPath: manifestPath).standardizedFileURL
    let data: Data
    do {
      data = try Data(contentsOf: manifestURL, options: [.mappedIfSafe])
    } catch {
      throw HarnessError.manifestUnreadable
    }

    let manifest: BenchmarkManifest
    do {
      manifest = try JSONDecoder().decode(BenchmarkManifest.self, from: data)
    } catch {
      throw HarnessError.manifestInvalid
    }

    let baseURL = manifestURL.deletingLastPathComponent()
    return manifest.fixtures.map { fixture in
      FixtureInput(
        id: fixture.id,
        url: URL(fileURLWithPath: fixture.path, relativeTo: baseURL).standardizedFileURL,
        passwordEnvironmentVariable: fixture.passwordEnvironmentVariable
          ?? arguments.passwordEnvironmentVariable
      )
    }
  }

  return arguments.fixturePaths.enumerated().map { index, path in
    FixtureInput(
      id: "fixture-\(index + 1)",
      url: URL(fileURLWithPath: path).standardizedFileURL,
      passwordEnvironmentVariable: arguments.passwordEnvironmentVariable
    )
  }
}

private func password(for fixture: FixtureInput) -> String? {
  guard let variable = fixture.passwordEnvironmentVariable, !variable.isEmpty else {
    return nil
  }
  return ProcessInfo.processInfo.environment[variable]
}

private func inspectionSummary(_ inspection: DocumentInspection) -> InspectionSummary {
  InspectionSummary(
    pageCount: inspection.pages.count,
    fieldCount: inspection.fields.count,
    candidateCount: inspection.candidates.count,
    linkCount: inspection.links.count,
    outlineCount: inspection.outlines.count,
    attachmentCount: inspection.attachments.count,
    warningCount: inspection.warnings.count
  )
}

private func exportSummary(_ result: ExportResult) -> ExportSummary {
  ExportSummary(
    status: result.report.status == .failed ? "failed" : "completed",
    validationPassed: result.report.status == .failed ? false : true,
    outputReopenable: result.report.outputReopenable
  )
}

private func renderPage(
  fixture: FixtureInput,
  pageIndex: Int,
  telemetry: PerformanceTelemetry
) throws {
  guard let document = PDFDocument(url: fixture.url) else {
    throw HarnessError.renderPageUnavailable
  }

  if document.isLocked {
    guard let fixturePassword = password(for: fixture), document.unlock(withPassword: fixturePassword) else {
      throw HarnessError.renderPageUnavailable
    }
  }

  guard let page = document.page(at: pageIndex) else {
    throw HarnessError.renderPageUnavailable
  }

  let bounds = page.bounds(for: .mediaBox)
  let sourceWidth = bounds.width
  let sourceHeight = bounds.height
  let maximumDimension: CGFloat = 2048
  let largestSourceDimension = max(sourceWidth, sourceHeight)
  guard sourceWidth.isFinite, sourceHeight.isFinite,
        sourceWidth > 0, sourceHeight > 0,
        largestSourceDimension.isFinite else {
    throw HarnessError.renderPageUnavailable
  }

  let scale = min(1, maximumDimension / largestSourceDimension)
  let pixelWidth = max(1, min(Int(ceil(sourceWidth * scale)), 2048))
  let pixelHeight = max(1, min(Int(ceil(sourceHeight * scale)), 2048))
  let colorSpace = CGColorSpaceCreateDeviceRGB()
  guard let context = CGContext(
    data: nil,
    width: pixelWidth,
    height: pixelHeight,
    bitsPerComponent: 8,
    bytesPerRow: pixelWidth * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
  ) else {
    throw HarnessError.renderPageUnavailable
  }

  context.scaleBy(x: scale, y: scale)
  context.translateBy(x: -bounds.minX, y: -bounds.minY)
  PDFPerformancePageRenderer.draw(
    page: page,
    in: context,
    box: .mediaBox,
    telemetry: telemetry
  )
}

private func report(
  arguments: Arguments,
  fixtures: [FixtureInput]
) throws -> BenchmarkReport {
  let hasRequestedWork = arguments.shouldInspect
    || arguments.shouldExport
    || arguments.renderPageIndex != nil
  let telemetry = PerformanceTelemetry(capacity: 512, enabled: hasRequestedWork)
  let provider = PDFKitProvider()
  let fileManager = FileManager.default

  var outputDirectoryURL: URL?
  if let outputDirectory = arguments.exportOutputDirectory {
    let url = URL(fileURLWithPath: outputDirectory).standardizedFileURL
    do {
      try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    } catch {
      throw HarnessError.exportOutputDirectoryUnavailable
    }
    outputDirectoryURL = url
  }

  var fixtureReports: [FixtureSummary] = []
  for (index, fixture) in fixtures.enumerated() {
    guard fileManager.fileExists(atPath: fixture.url.path) else {
      fixtureReports.append(
        FixtureSummary(
          fixtureID: fixture.id,
          status: "blocked",
          inspection: nil,
          export: nil,
          render: nil,
          memory: nil,
          errorCode: "input_missing"
        )
      )
      continue
    }

    guard hasRequestedWork else {
      fixtureReports.append(
        FixtureSummary(
          fixtureID: fixture.id,
          status: "not_requested",
          inspection: nil,
          export: nil,
          render: nil,
          memory: nil,
          errorCode: nil
        )
      )
      continue
    }

    let memoryBefore = arguments.shouldSampleMemory
      ? NativeMemoryTelemetry.snapshot(enabled: true)
      : nil
    var inspection: InspectionSummary?
    var export: ExportSummary?
    var render: RenderSummary?
    var errorCode: String?
    var didFail = false

    if arguments.shouldInspect {
      do {
        let result = try telemetry.measure(.openLoad) {
          try provider.inspect(url: fixture.url, password: password(for: fixture))
        }
        inspection = inspectionSummary(result)
      } catch {
        didFail = true
        errorCode = safeErrorCode(error)
      }
    }

    if let pageIndex = arguments.renderPageIndex {
      do {
        try renderPage(fixture: fixture, pageIndex: pageIndex, telemetry: telemetry)
        render = RenderSummary(status: "completed")
      } catch {
        didFail = true
        errorCode = errorCode ?? safeErrorCode(error)
        render = RenderSummary(status: "failed")
      }
    }

    if arguments.shouldExport, let outputDirectoryURL {
      let outputURL = outputDirectoryURL.appendingPathComponent(
        "fixture-\(index + 1)-export.pdf",
        isDirectory: false
      )
      if fileManager.fileExists(atPath: outputURL.path) {
        didFail = true
        errorCode = errorCode ?? "output_exists"
        export = ExportSummary(status: "blocked", validationPassed: nil, outputReopenable: nil)
      } else {
        do {
          let result = try telemetry.measure(.save) {
            try provider.export(url: fixture.url, operations: [], to: outputURL)
          }
          export = exportSummary(result)
          if result.report.status == .failed {
            didFail = true
            errorCode = errorCode ?? "export_validation_failed"
          }
        } catch {
          didFail = true
          errorCode = errorCode ?? safeErrorCode(error)
          export = ExportSummary(status: "failed", validationPassed: false, outputReopenable: nil)
        }
      }
    }

    let memoryAfter = arguments.shouldSampleMemory
      ? NativeMemoryTelemetry.snapshot(enabled: true)
      : nil

    fixtureReports.append(
      FixtureSummary(
        fixtureID: fixture.id,
        status: didFail ? "failed" : "measured",
        inspection: inspection,
        export: export,
        render: render,
        memory: arguments.shouldSampleMemory
          ? MemorySummary(before: memoryBefore, after: memoryAfter)
          : nil,
        errorCode: errorCode
      )
    )
  }

  let requestedOperations = [
    arguments.shouldInspect ? "inspect" : nil,
    arguments.renderPageIndex != nil ? "render_page" : nil,
    arguments.shouldExport ? "export" : nil
  ].compactMap { $0 }

  return BenchmarkReport(
    schema: "pdf-editor.performance-benchmark.v1",
    status: fixtureReports.contains(where: { $0.status == "failed" }) ? "failed" : "completed",
    requestedOperations: requestedOperations,
    runMetadata: RunMetadata(
      startedAt: nil,
      finishedAt: nil,
      operatingSystem: nil,
      architecture: nil,
      swiftVersion: nil,
      packageRevision: nil,
      warmupPolicy: nil,
      coldWarmPolicy: nil,
      corpusManifest: nil
    ),
    fixtures: fixtureReports,
    telemetry: telemetry.summaries()
  )
}

private func writeError(_ message: String, exitCode: Int32) -> Never {
  FileHandle.standardError.write(Data((message + "\n").utf8))
  Darwin.exit(exitCode)
}

let rawArguments = Array(CommandLine.arguments.dropFirst())
do {
  let arguments = try parseArguments(rawArguments)
  let fixtureInputs = try fixtures(for: arguments)
  let result = try report(arguments: arguments, fixtures: fixtureInputs)
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
  let data = try encoder.encode(result)
  FileHandle.standardOutput.write(data)
  FileHandle.standardOutput.write(Data("\n".utf8))
} catch HarnessError.help {
  print(usage())
} catch HarnessError.invalidArgument(let argument) {
  writeError("invalid argument: \(argument)\n\n\(usage())", exitCode: 2)
} catch HarnessError.missingArgumentValue(let argument) {
  writeError("missing value for \(argument)\n\n\(usage())", exitCode: 2)
} catch HarnessError.manifestUnreadable {
  writeError("manifest could not be read", exitCode: 2)
} catch HarnessError.manifestInvalid {
  writeError("manifest is invalid", exitCode: 2)
} catch HarnessError.exportOutputDirectoryRequired {
  writeError("--export-output-directory is required with --export", exitCode: 2)
} catch HarnessError.exportOutputDirectoryUnavailable {
  writeError("export output directory could not be created", exitCode: 2)
} catch {
  writeError("benchmark harness failed before producing a report", exitCode: 2)
}
