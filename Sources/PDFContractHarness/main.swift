import Foundation
import PDFEditorCore

private struct CoordinateEnvelope: Codable {
    let contractName: String
    let version: PDFContractVersion
    let sourceDigest: String
    let generatedAt: Date
    let provider: PDFProviderDescriptor
    let pages: [PageCoordinate]
}

private struct PageCoordinate: Codable {
    let pageIndex: Int
    let region: PDFPageRegion
}

private struct EditSessionEnvelope: Codable {
    let header: PDFContractHeader
    let source: DocumentSource
    let reviews: [CandidateReviewDecision]
    let operations: [EditOperation]
}

private struct ParityBundle: Codable {
    let contractName: String
    let version: PDFContractVersion
    let sourcePath: String
    let expectedFailure: Bool
    let status: String
    let sourceDigest: String?
    let document: PDFDocumentContract?
    let coordinates: CoordinateEnvelope?
    let candidates: [RegionCandidate]?
    let editSession: EditSessionEnvelope?
    let validation: ValidationReport?
    let error: String?
}

private struct SummaryEntry: Codable {
    let sourcePath: String
    let status: String
    let expectedFailure: Bool
    let sourceDigest: String?
    let error: String?
}

private struct HarnessSummary: Codable {
    let harness: String
    let version: PDFContractVersion
    let provider: PDFProviderDescriptor
    let fixtureCount: Int
    let fixtures: [SummaryEntry]
}

private enum HarnessError: Error, LocalizedError {
    case invalidArgument(String)
    case manifestMissing(String)
    case outputUnavailable(String)

    var errorDescription: String? {
        switch self {
        case let .invalidArgument(message), let .manifestMissing(message), let .outputUnavailable(message):
            message
        }
    }
}

private struct Arguments {
    let manifestURL: URL
    let outputDirectory: URL
    let exportDirectory: URL
    let rootURL: URL
}

private let providerDescriptor = PDFProviderDescriptor(
    id: "pdfkit",
    version: ProcessInfo.processInfo.operatingSystemVersionString,
    platform: "macOS",
    capabilities: ["render", "text", "forms", "overlay", "export", "reopen-validation"]
)

private func parseArguments() throws -> Arguments {
    let fileManager = FileManager.default
    let rootURL = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
    let defaultManifest = rootURL.appendingPathComponent("docs/fixtures/manifest.md")
    let defaultOutput = rootURL.appendingPathComponent("benchmark/results/contract-parity-2026-08-24/native", isDirectory: true)
    var manifestURL = defaultManifest
    var outputDirectory = defaultOutput
    var index = 1
    let arguments = CommandLine.arguments
    while index < arguments.count {
        switch arguments[index] {
        case "--manifest":
            guard index + 1 < arguments.count else { throw HarnessError.invalidArgument("--manifest requires a path") }
            manifestURL = URL(fileURLWithPath: arguments[index + 1], relativeTo: rootURL).standardizedFileURL
            index += 2
        case "--output-dir":
            guard index + 1 < arguments.count else { throw HarnessError.invalidArgument("--output-dir requires a path") }
            outputDirectory = URL(fileURLWithPath: arguments[index + 1], relativeTo: rootURL).standardizedFileURL
            index += 2
        default:
            throw HarnessError.invalidArgument("Unknown argument: \(arguments[index])")
        }
    }
    guard fileManager.fileExists(atPath: manifestURL.path) else {
        throw HarnessError.manifestMissing("Fixture manifest was not found: \(manifestURL.path)")
    }
    try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    let exportDirectory = outputDirectory.appendingPathComponent("exports", isDirectory: true)
    try fileManager.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
    return Arguments(manifestURL: manifestURL, outputDirectory: outputDirectory, exportDirectory: exportDirectory, rootURL: rootURL)
}

private func manifestPaths(from url: URL) throws -> [String] {
    let contents = try String(contentsOf: url, encoding: .utf8)
    return contents
        .split(whereSeparator: \.isNewline)
        .compactMap { line in
            let parts = line.split(separator: "`")
            return parts.first(where: { $0.hasSuffix(".pdf") }).map(String.init)
        }
}

private func isExpectedFailure(_ relativePath: String) -> Bool {
    relativePath.contains("truncated-128-bytes.pdf")
}

private func password(for relativePath: String) -> String? {
    relativePath.contains("encrypted-reader.pdf") ? "reader-password" : nil
}

private func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    try encoder.encode(value).write(to: url, options: .atomic)
}

private func makeDocumentContract(_ inspection: DocumentInspection, generatedAt: Date) -> PDFDocumentContract {
    PDFDocumentContract(
        header: PDFContractHeader(
            contractName: "pdf-editor.document",
            version: .current,
            sourceDigest: inspection.source.sha256,
            generatedAt: generatedAt,
            provider: providerDescriptor
        ),
        payload: inspection
    )
}

private func makeCoordinates(_ inspection: DocumentInspection, generatedAt: Date) -> CoordinateEnvelope {
    CoordinateEnvelope(
        contractName: "pdf-editor.coordinates",
        version: .current,
        sourceDigest: inspection.source.sha256,
        generatedAt: generatedAt,
        provider: providerDescriptor,
        pages: inspection.pages.map {
            PageCoordinate(
                pageIndex: $0.pageIndex,
                region: PDFPageRegion(
                    pageIndex: $0.pageIndex,
                    rect: $0.bounds,
                    coordinateSpace: PDFCoordinateSpace(
                        unit: .points,
                        origin: .lowerLeft,
                        pageBox: .crop,
                        rotationDegrees: $0.rotation
                    )
                )
            )
        }
    )
}

private func makeEditSession(_ inspection: DocumentInspection, generatedAt: Date) -> EditSessionEnvelope {
    EditSessionEnvelope(
        header: PDFContractHeader(
            contractName: "pdf-editor.edit-session",
            version: .current,
            sourceDigest: inspection.source.sha256,
            generatedAt: generatedAt,
            provider: providerDescriptor
        ),
        source: inspection.source,
        reviews: [],
        operations: []
    )
}

private func inspectFixture(relativePath: String, arguments: Arguments, provider: PDFKitProvider) -> (ParityBundle, SummaryEntry) {
    let sourceURL = arguments.rootURL.appendingPathComponent(relativePath).standardizedFileURL
    let expectedFailure = isExpectedFailure(relativePath)
    do {
        let inspection = try provider.inspect(url: sourceURL, password: password(for: relativePath))
        let generatedAt = Date()
        let document = makeDocumentContract(inspection, generatedAt: generatedAt)
        let coordinates = makeCoordinates(inspection, generatedAt: generatedAt)
        let editSession = makeEditSession(inspection, generatedAt: generatedAt)
        var validation: ValidationReport?
        var exportError: String?
        let exportFilename = relativePath
            .replacingOccurrences(of: "/", with: "__")
            .replacingOccurrences(of: ".pdf", with: "-native-noop.pdf")
        let outputURL = arguments.exportDirectory.appendingPathComponent(exportFilename)
        try? FileManager.default.removeItem(at: outputURL)
        do {
            validation = try provider.export(url: sourceURL, operations: [], to: outputURL).report
        } catch {
            exportError = error.localizedDescription
            try? FileManager.default.removeItem(at: outputURL)
        }
        let status = exportError == nil ? "inspected" : "inspectedExportFailed"
        let bundle = ParityBundle(
            contractName: "pdf-editor.browser-fixture",
            version: .current,
            sourcePath: relativePath,
            expectedFailure: false,
            status: status,
            sourceDigest: inspection.source.sha256,
            document: document,
            coordinates: coordinates,
            candidates: inspection.candidates,
            editSession: editSession,
            validation: validation,
            error: exportError
        )
        let summary = SummaryEntry(
            sourcePath: relativePath,
            status: status,
            expectedFailure: false,
            sourceDigest: inspection.source.sha256,
            error: exportError
        )
        return (bundle, summary)
    } catch {
        let message = error.localizedDescription
        let bundle = ParityBundle(
            contractName: "pdf-editor.browser-fixture",
            version: .current,
            sourcePath: relativePath,
            expectedFailure: expectedFailure,
            status: "inspectionFailed",
            sourceDigest: nil,
            document: nil,
            coordinates: nil,
            candidates: nil,
            editSession: nil,
            validation: nil,
            error: message
        )
        let summary = SummaryEntry(
            sourcePath: relativePath,
            status: "inspectionFailed",
            expectedFailure: expectedFailure,
            sourceDigest: nil,
            error: message
        )
        return (bundle, summary)
    }
}

@main
struct PDFContractHarness {
    static func main() throws {
        let arguments = try parseArguments()
        let paths = try manifestPaths(from: arguments.manifestURL)
        guard !paths.isEmpty else { throw HarnessError.manifestMissing("Fixture manifest contains no PDF paths") }
        let provider = PDFKitProvider()
        var summaries: [SummaryEntry] = []
        for relativePath in paths {
            let (bundle, summary) = inspectFixture(relativePath: relativePath, arguments: arguments, provider: provider)
            let filename = relativePath
                .replacingOccurrences(of: "/", with: "__")
                .replacingOccurrences(of: ".pdf", with: ".json")
            try writeJSON(bundle, to: arguments.outputDirectory.appendingPathComponent(filename))
            summaries.append(summary)
        }
        let summary = HarnessSummary(
            harness: "pdf-editor-native-contract-parity",
            version: .current,
            provider: providerDescriptor,
            fixtureCount: summaries.count,
            fixtures: summaries
        )
        try writeJSON(summary, to: arguments.outputDirectory.appendingPathComponent("summary.json"))
        let output = try JSONEncoder().encode(summary)
        FileHandle.standardOutput.write(output)
        FileHandle.standardOutput.write(Data([10]))
    }
}
