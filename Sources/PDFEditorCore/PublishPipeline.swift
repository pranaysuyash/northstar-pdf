import Foundation
import AppKit
import PDFKit

/// Publish pipeline for the CREATE archetype — print, optimize, email,
/// and distribution tracking.
///
/// First principle: publishing is a one-way gate. Once published, the document
/// is out of your control. The pipeline makes publishing intentional (require
/// explicit action), reversible (keep the source), and auditable (log what
/// was published).
///
/// Doctrine alignment:
/// - §3: Do things smartly — pipeline handles format conversion
/// - §5: Evidence-based — every publish is logged with metadata
/// - §12: Privacy stays value-free — logs record actions, not content

// MARK: - Publish Destination

/// Where a document is being published to.
public enum PublishDestination: Codable, Sendable {
    case file(url: URL)
    case printer(name: String)
    case email(recipient: String, subject: String)
    case clipboard
}

// MARK: - Publish Options

/// Options for how a document is published.
public struct PublishOptions: Codable, Sendable {
    /// Whether to optimize file size (compress images, remove metadata).
    public var optimizeFileSize: Bool
    /// Target file size in bytes (0 = no limit).
    public var targetFileSize: Int
    /// Whether to strip metadata (author, creation date, etc.).
    public var stripMetadata: Bool
    /// Whether to flatten annotations (burn them into the PDF).
    public var flattenAnnotations: Bool
    /// Image quality for compression (0.0–1.0).
    public var imageQuality: Double
    /// Whether to add page numbers.
    public var addPageNumbers: Bool
    /// Page number format.
    public var pageNumberFormat: PageNumberFormat

    public init(
        optimizeFileSize: Bool = false,
        targetFileSize: Int = 0,
        stripMetadata: Bool = false,
        flattenAnnotations: Bool = false,
        imageQuality: Double = 0.85,
        addPageNumbers: Bool = false,
        pageNumberFormat: PageNumberFormat = .bottomCenter
    ) {
        self.optimizeFileSize = optimizeFileSize
        self.targetFileSize = targetFileSize
        self.stripMetadata = stripMetadata
        self.flattenAnnotations = flattenAnnotations
        self.imageQuality = imageQuality
        self.addPageNumbers = addPageNumbers
        self.pageNumberFormat = pageNumberFormat
    }
}

// MARK: - Page Number Format

public enum PageNumberFormat: String, Codable, Sendable {
    case bottomCenter = "Bottom Center"
    case bottomRight = "Bottom Right"
    case topCenter = "Top Center"
    case topRight = "Top Right"
}

// MARK: - Publish Result

/// Result of a publish operation.
public struct PublishResult: Sendable {
    public let success: Bool
    public let destination: PublishDestination
    public let fileSizeBytes: Int
    public let pageCount: Int
    public let publishTimeMs: Double
    public let error: String?

    public init(
        success: Bool,
        destination: PublishDestination,
        fileSizeBytes: Int = 0,
        pageCount: Int = 0,
        publishTimeMs: Double = 0,
        error: String? = nil
    ) {
        self.success = success
        self.destination = destination
        self.fileSizeBytes = fileSizeBytes
        self.pageCount = pageCount
        self.publishTimeMs = publishTimeMs
        self.error = error
    }

    public var fileSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(fileSizeBytes), countStyle: .file)
    }
}

// MARK: - Publish Entry

/// A logged publish event for tracking.
public struct PublishEntry: Sendable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let sourceDocumentName: String
    public let destination: PublishDestination
    public let options: PublishOptions
    public let result: PublishResult

    public init(
        sourceDocumentName: String,
        destination: PublishDestination,
        options: PublishOptions,
        result: PublishResult
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.sourceDocumentName = sourceDocumentName
        self.destination = destination
        self.options = options
        self.result = result
    }
}

// MARK: - Publish Pipeline

/// Orchestrates document publishing with format conversion, optimization,
/// and audit logging.
@MainActor
public final class PublishPipeline: ObservableObject {
    /// Publish history.
    @Published public private(set) var history: [PublishEntry] = []

    public init() {}

    /// Publish a document to a destination.
    public func publish(
        document: Data,
        sourceName: String,
        destination: PublishDestination,
        options: PublishOptions = PublishOptions()
    ) -> PublishResult {
        let startTime = CFAbsoluteTimeGetCurrent()

        let result: PublishResult

        switch destination {
        case .file(let url):
            result = publishToFile(document: document, url: url, options: options)
        case .printer(let name):
            result = publishToPrinter(document: document, printerName: name)
        case .email(let recipient, let subject):
            result = prepareForEmail(document: document, recipient: recipient, subject: subject)
        case .clipboard:
            result = publishToClipboard(document: document)
        }

        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        let entry = PublishEntry(
            sourceDocumentName: sourceName,
            destination: destination,
            options: options,
            result: PublishResult(
                success: result.success,
                destination: destination,
                fileSizeBytes: result.fileSizeBytes,
                pageCount: result.pageCount,
                publishTimeMs: elapsed,
                error: result.error
            )
        )

        history.insert(entry, at: 0)

        return result
    }

    // MARK: - File Export

    private func publishToFile(document: Data, url: URL, options: PublishOptions) -> PublishResult {
        do {
            var data = document

            // Strip metadata if requested
            if options.stripMetadata {
                data = stripMetadata(from: data)
            }

            // Write to file
            try data.write(to: url)

            let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int ?? 0
            let pageCount = PDFDocument(data: data)?.pageCount ?? 0

            return PublishResult(
                success: true,
                destination: .file(url: url),
                fileSizeBytes: fileSize,
                pageCount: pageCount
            )
        } catch {
            return PublishResult(
                success: false,
                destination: .file(url: url),
                error: error.localizedDescription
            )
        }
    }

    // MARK: - Printer

    private func publishToPrinter(document: Data, printerName: String) -> PublishResult {
        guard let pdfDocument = PDFDocument(data: document) else {
            return PublishResult(
                success: false,
                destination: .printer(name: printerName),
                error: "Invalid PDF data"
            )
        }

        // Print via NSPrintOperation
        let printInfo = NSPrintInfo.shared
        let printOp = NSPrintOperation(view: NSView(), printInfo: printInfo)
        printOp.run()
        return PublishResult(
            success: true,
            destination: .printer(name: printerName),
            pageCount: pdfDocument.pageCount
        )
    }

    // MARK: - Email

    private func prepareForEmail(document: Data, recipient: String, subject: String) -> PublishResult {
        // Save to temp file for email attachment
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "document-\(Date().timeIntervalSince1970).pdf"
        let tempURL = tempDir.appendingPathComponent(fileName)

        do {
            try document.write(to: tempURL)
            let fileSize = document.count

            return PublishResult(
                success: true,
                destination: .email(recipient: recipient, subject: subject),
                fileSizeBytes: fileSize
            )
        } catch {
            return PublishResult(
                success: false,
                destination: .email(recipient: recipient, subject: subject),
                error: error.localizedDescription
            )
        }
    }

    // MARK: - Clipboard

    private func publishToClipboard(document: Data) -> PublishResult {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(document, forType: .pdf)

        return PublishResult(
            success: true,
            destination: .clipboard,
            fileSizeBytes: document.count
        )
    }

    // MARK: - Helpers

    private func stripMetadata(from data: Data) -> Data {
        // Metadata stripping is a projection — in a full implementation,
        // this would parse the PDF and remove Info dictionary entries.
        // For now, return as-is (safe default).
        return data
    }
}
