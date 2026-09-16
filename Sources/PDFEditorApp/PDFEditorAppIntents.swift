import AppIntents
import Foundation
import PDFEditorCore

// MARK: - Native macOS App Intents Substrate [TASK-B5]

@available(macOS 15.0, *)
public struct SanitizePDFIntent: AppIntent {
  public static var title: LocalizedStringResource { "Sanitize PDF" }
  public static var description: IntentDescription {
    IntentDescription(
      "Strips metadata, removes hidden tracks, and exports a verified clean PDF copy without modifying the source."
    )
  }

  @Parameter(title: "Source PDF File")
  public var fileURL: URL

  public init() {
    self.fileURL = URL(fileURLWithPath: "/")
  }

  public init(fileURL: URL) {
    self.fileURL = fileURL
  }

  public func perform() async throws -> some IntentResult & ReturnsValue<String> {
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      return .result(value: "Source file not found at \(fileURL.path)")
    }
    do {
      let data = try Data(contentsOf: fileURL)
      let sanitizer = PDFSanitizer()
      let (sanitizedData, report) = sanitizer.sanitize(pdfData: data)
      let parentDir = fileURL.deletingLastPathComponent()
      let baseName = fileURL.deletingPathExtension().lastPathComponent
      let ext = fileURL.pathExtension.isEmpty ? "pdf" : fileURL.pathExtension
      let outputURL = parentDir.appendingPathComponent("\(baseName)-sanitized.\(ext)")
      try sanitizedData.write(to: outputURL, options: .atomic)
      let details = "Stripped XMP: \(report.xmpMetadataStripped), Cleaned Info: \(report.infoDictionaryCleaned), Neutralized Actions: \(report.actionsNeutralized), Removed Attachments: \(report.attachmentsRemoved)"
      return .result(value: "PDF Sanitized successfully on-device (Zero Network Egress). \(details). Output saved to: \(outputURL.path)")
    } catch {
      return .result(value: "Sanitization failed: \(error.localizedDescription)")
    }
  }
}

@available(macOS 15.0, *)
public struct ExtractTableCSVIntent: AppIntent {
  public static var title: LocalizedStringResource { "Extract Tables as CSV" }
  public static var description: IntentDescription {
    IntentDescription(
      "Detects tabular data in a PDF and extracts it as structured CSV directly on-device."
    )
  }

  @Parameter(title: "Source PDF File")
  public var fileURL: URL

  public init() {
    self.fileURL = URL(fileURLWithPath: "/")
  }

  public init(fileURL: URL) {
    self.fileURL = fileURL
  }

  public func perform() async throws -> some IntentResult & ReturnsValue<String> {
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      return .result(value: "Source file not found at \(fileURL.path)")
    }
    do {
      let data = try Data(contentsOf: fileURL)
      let textExtractor = ImprovedTextExtractor()
      let extraction = try textExtractor.extract(data: data)
      let tableExtractor = TableExtractor()
      let result = tableExtractor.extract(extraction: extraction)
      if result.tables.isEmpty {
        return .result(value: "No tables detected in \(fileURL.lastPathComponent) across \(extraction.pageCount) page(s).")
      }
      let csvContent = tableExtractor.exportAllCSV(result)
      let outputURL = fileURL.deletingPathExtension().appendingPathExtension("csv")
      try csvContent.write(to: outputURL, atomically: true, encoding: .utf8)
      let avgConf = String(format: "%.1f%%", result.averageConfidence * 100)
      return .result(value: "Extracted \(result.totalTables) table(s) across \(result.totalPages) page(s) (Avg confidence: \(avgConf)). CSV exported to: \(outputURL.path)")
    } catch {
      return .result(value: "Table extraction failed: \(error.localizedDescription)")
    }
  }
}

@available(macOS 15.0, *)
public struct ComparePDFVersionsIntent: AppIntent {
  public static var title: LocalizedStringResource { "Compare PDF Versions" }
  public static var description: IntentDescription {
    IntentDescription(
      "Runs pixel-level and structural diff between two PDF versions."
    )
  }

  @Parameter(title: "Original PDF")
  public var originalURL: URL

  @Parameter(title: "Modified PDF")
  public var modifiedURL: URL

  public init() {
    self.originalURL = URL(fileURLWithPath: "/")
    self.modifiedURL = URL(fileURLWithPath: "/")
  }

  public func perform() async throws -> some IntentResult & ReturnsValue<String> {
    guard FileManager.default.fileExists(atPath: originalURL.path) else {
      return .result(value: "Original file not found at \(originalURL.path)")
    }
    guard FileManager.default.fileExists(atPath: modifiedURL.path) else {
      return .result(value: "Modified file not found at \(modifiedURL.path)")
    }
    do {
      let provider = PDFKitProvider()
      let sourceInspection = try provider.inspect(url: originalURL, password: nil)
      let modifiedInspection = try provider.inspect(url: modifiedURL, password: nil)
      let diff = DocumentDiffBuilder.build(
        source: sourceInspection,
        output: modifiedInspection,
        operations: []
      )
      let summary = diff.summary
      return .result(value: "Diff comparison complete. Pages: \(diff.pageCount), Pages with changes: \(summary.pagesWithChanges), Unexpected changes: \(summary.unexpectedChanges), Matched operations: \(summary.operationRegionsMatched), Overall status: \(summary.overallStatus).")
    } catch {
      return .result(value: "Diff comparison failed: \(error.localizedDescription)")
    }
  }
}

@available(macOS 15.0, *)
public struct NorthstarShortcutsProvider: AppShortcutsProvider {
  public static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: SanitizePDFIntent(),
      phrases: [
        "Sanitize PDF with \(.applicationName)",
        "Strip PDF metadata using \(.applicationName)"
      ],
      shortTitle: "Sanitize PDF",
      systemImageName: "lock.shield"
    )
  }
}
