import AppKit
import CryptoKit
import Foundation
import PDFKit
import Testing
@testable import PDFEditorCore

struct ContractMutationTests {
    @Test func staleSourceDigestIsRejectedBeforeMutationAndPublication() throws {
        let context = try makeExportContext()
        let bounds = PDFRect(x: 72, y: 700, width: 120, height: 22)
        let operation = EditOperation(
            pageIndex: 0,
            kind: .overlayText,
            value: "Stale source must not apply",
            bounds: bounds,
            sourceDigest: String(repeating: "f", count: 64),
            coordinate: PDFPageRegion(pageIndex: 0, rect: bounds)
        )

        try expectInvalidOperation(
            operation,
            context: context,
            message: "source digest"
        )
    }

    @Test func unsupportedOperationIsRejectedAndDiagnosticNamesKind() throws {
        let context = try makeExportContext()
        let operation = EditOperation(pageIndex: 0, kind: .sanitize, value: "")

        try expectInvalidOperation(
            operation,
            context: context,
            message: "sanitize"
        )
    }

    @Test func destructiveFlagIsRejectedUntilProviderPolicyExists() throws {
        let context = try makeExportContext()
        let bounds = PDFRect(x: 72, y: 700, width: 120, height: 22)
        let operation = EditOperation(
            pageIndex: 0,
            kind: .overlayText,
            value: "Destructive overlays require policy",
            bounds: bounds,
            sourceDigest: context.sourceDigest,
            coordinate: PDFPageRegion(pageIndex: 0, rect: bounds),
            destructive: true
        )

        try expectInvalidOperation(
            operation,
            context: context,
            message: "explicit provider policy"
        )
    }

    @Test func coordinatePageMismatchIsRejectedBeforeMutation() throws {
        let context = try makeExportContext()
        let bounds = PDFRect(x: 72, y: 700, width: 120, height: 22)
        let operation = EditOperation(
            pageIndex: 0,
            kind: .overlayText,
            value: "Wrong page coordinate",
            bounds: bounds,
            sourceDigest: context.sourceDigest,
            coordinate: PDFPageRegion(pageIndex: 1, rect: bounds)
        )

        try expectInvalidOperation(
            operation,
            context: context,
            message: "coordinate page"
        )
    }

    @Test func coordinateBoundsMismatchIsRejectedBeforeMutation() throws {
        let context = try makeExportContext()
        let operation = EditOperation(
            pageIndex: 0,
            kind: .overlayText,
            value: "Wrong coordinate bounds",
            bounds: PDFRect(x: 72, y: 700, width: 120, height: 22),
            sourceDigest: context.sourceDigest,
            coordinate: PDFPageRegion(
                pageIndex: 0,
                rect: PDFRect(x: 80, y: 700, width: 120, height: 22)
            )
        )

        try expectInvalidOperation(
            operation,
            context: context,
            message: "bounds"
        )
    }

    @Test func unknownValidationStateRemainsUnknownAndFutureStateFailsClosed() throws {
        let checkID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
        let unknownJSONString = """
        {
          "id": "\(checkID.uuidString)",
          "kind": "sourceDigest",
          "status": "unknown",
          "message": "The source digest check was not run.",
          "region": null,
          "operationIDs": []
        }
        """
        let unknownJSON = Data(unknownJSONString.utf8)

        let unknownCheck = try JSONDecoder().decode(ValidationCheck.self, from: unknownJSON)
        #expect(unknownCheck.status == .unknown)
        #expect(unknownCheck.status != .passed)

        let futureJSON = unknownJSONString.replacingOccurrences(of: "unknown", with: "future")
        do {
            _ = try JSONDecoder().decode(ValidationCheck.self, from: Data(futureJSON.utf8))
            Issue.record("An unknown future validation state was silently accepted")
        } catch {
            #expect(error is DecodingError)
        }
    }

    private struct ExportContext {
        let sourceURL: URL
        let outputURL: URL
        let directory: URL
        let sourceDigest: String
    }

    private func makeExportContext() throws -> ExportContext {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pdf-editor-contract-mutation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let sourceURL = directory.appendingPathComponent("source.pdf")
        let outputURL = directory.appendingPathComponent("destination.pdf")
        let document = PDFDocument()
        document.insert(PDFPage(), at: 0)
        #expect(document.write(to: sourceURL))

        let sourceData = try Data(contentsOf: sourceURL)
        let sourceDigest = SHA256.hash(data: sourceData)
            .map { String(format: "%02x", $0) }
            .joined()
        return ExportContext(
            sourceURL: sourceURL,
            outputURL: outputURL,
            directory: directory,
            sourceDigest: sourceDigest
        )
    }

    private func expectInvalidOperation(
        _ operation: EditOperation,
        context: ExportContext,
        message: String
    ) throws {
        defer { try? FileManager.default.removeItem(at: context.directory) }
        let sentinel = Data("destination must remain untouched".utf8)
        try sentinel.write(to: context.outputURL)

        do {
            _ = try PDFKitProvider().export(
                url: context.sourceURL,
                operations: [operation],
                to: context.outputURL
            )
            Issue.record("Invalid operation unexpectedly exported")
        } catch let error as PDFEditorError {
            guard case let .invalidOperation(detail) = error else {
                Issue.record("Unexpected PDF editor error: \(error.localizedDescription)")
                return
            }
            #expect(detail.localizedCaseInsensitiveContains(message))
        }

        #expect(try Data(contentsOf: context.outputURL) == sentinel)
        let stagingFiles = try FileManager.default.contentsOfDirectory(
            at: context.directory,
            includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.hasPrefix(".pdf-editor-") }
        #expect(stagingFiles.isEmpty)
    }
}
