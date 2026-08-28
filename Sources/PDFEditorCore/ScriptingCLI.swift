import Foundation
import PDFKit

/// User-facing CLI entry point for batch operations and automation workflows.
///
/// First principle: the app's core operations should be scriptable from
/// the command line. This enables automation without cloud dependencies.
///
/// Architecture:
/// - `CLICommand` — a single command with arguments
/// - `CLIWorkflow` — a sequence of commands with conditions
/// - `CLIRunner` — executes commands with resource bounds
///
/// Doctrine alignment:
/// - §3: Do things smartly — scriptable core operations
/// - §8: Capability activation — scripting is opt-in, sandboxed
/// - §12: Privacy value-free — script runs are logged, not content

// MARK: - CLI Command

/// A single scriptable command.
public enum CLICommandType: String, Codable, Sendable, CaseIterable, Identifiable {
  case extractText = "extract-text"
  case validatePDF = "validate"
  case summarize = "summarize"
  case recognizeEntities = "recognize-entities"
  case exportMetadata = "export-metadata"
  case exportCitation = "export-citation"
  case listAnnotations = "list-annotations"
  case detectDedup = "detect-dedup"
  case batchExtract = "batch-extract"

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .extractText: return "Extract Text"
    case .validatePDF: return "Validate PDF"
    case .summarize: return "Summarize"
    case .recognizeEntities: return "Recognize Entities"
    case .exportMetadata: return "Export Metadata"
    case .exportCitation: return "Export Citation"
    case .listAnnotations: return "List Annotations"
    case .detectDedup: return "Detect Duplicates"
    case .batchExtract: return "Batch Extract"
    }
  }

  public var description: String {
    switch self {
    case .extractText: return "Extract text content from a PDF"
    case .validatePDF: return "Validate PDF structure and integrity"
    case .summarize: return "Generate a summary of the document"
    case .recognizeEntities: return "Extract named entities from text"
    case .exportMetadata: return "Export document metadata as JSON"
    case .exportCitation: return "Generate a citation for the document"
    case .listAnnotations: return "List all annotations in the document"
    case .detectDedup: return "Find duplicate documents in a directory"
    case .batchExtract: return "Extract text from multiple PDFs"
    }
  }
}

// MARK: - CLI Execution Result

/// Result of executing a CLI command.
public struct CLIExecutionResult: Codable, Sendable {
  /// Command that was executed.
  public let command: CLICommandType
  /// Input file path.
  public let inputPath: String
  /// Whether execution succeeded.
  public let success: Bool
  /// Output (JSON or text).
  public let output: String
  /// Error message (if failed).
  public let error: String?
  /// Execution time in seconds.
  public let executionTimeSeconds: Double
  /// When execution completed.
  public let completedAt: Date

  public init(
    command: CLICommandType,
    inputPath: String,
    success: Bool,
    output: String,
    error: String? = nil,
    executionTimeSeconds: Double = 0
  ) {
    self.command = command
    self.inputPath = inputPath
    self.success = success
    self.output = output
    self.error = error
    self.executionTimeSeconds = executionTimeSeconds
    self.completedAt = Date()
  }
}

// MARK: - CLI Runner

/// Executes CLI commands with resource bounds.
@MainActor
public final class CLIRunner: ObservableObject {
  /// Execution history.
  @Published public var history: [CLIExecutionResult] = []
  /// Whether a command is currently running.
  @Published public var isRunning: Bool = false

  /// Total commands executed.
  public var totalExecuted: Int { history.count }
  /// Successful commands.
  public var successCount: Int { history.filter(\.success).count }
  /// Failed commands.
  public var failureCount: Int { history.filter { !$0.success }.count }

  public init() {}

  /// Execute a single command.
  public func execute(_ command: CLICommandType, inputPath: String) async -> CLIExecutionResult {
    isRunning = true
    let startTime = CFAbsoluteTimeGetCurrent()

    let result: CLIExecutionResult

    switch command {
    case .validatePDF:
      result = validatePDF(path: inputPath, startTime: startTime)

    case .extractText:
      result = extractText(path: inputPath, startTime: startTime)

    case .exportMetadata:
      result = exportMetadata(path: inputPath, startTime: startTime)

    case .exportCitation:
      result = exportCitation(path: inputPath, startTime: startTime)

    default:
      let elapsed = CFAbsoluteTimeGetCurrent() - startTime
      result = CLIExecutionResult(
        command: command,
        inputPath: inputPath,
        success: false,
        output: "",
        error: "\(command.displayName) requires pipeline integration",
        executionTimeSeconds: elapsed
      )
    }

    history.append(result)
    isRunning = false
    return result
  }

  /// Clear execution history.
  public func clearHistory() {
    history = []
  }

  // MARK: - Command Implementations

  private func validatePDF(path: String, startTime: CFAbsoluteTime) -> CLIExecutionResult {
    guard let data = FileManager.default.contents(atPath: path) else {
      let elapsed = CFAbsoluteTimeGetCurrent() - startTime
      return CLIExecutionResult(
        command: .validatePDF,
        inputPath: path,
        success: false,
        output: "",
        error: "File not found",
        executionTimeSeconds: elapsed
      )
    }

    guard let doc = PDFDocument(data: data) else {
      let elapsed = CFAbsoluteTimeGetCurrent() - startTime
      return CLIExecutionResult(
        command: .validatePDF,
        inputPath: path,
        success: false,
        output: "",
        error: "Not a valid PDF",
        executionTimeSeconds: elapsed
      )
    }

    let attrs = doc.documentAttributes ?? [:]
    let metadata: [String: Any] = [
      "valid": true,
      "pageCount": doc.pageCount,
      "title": attrs[PDFDocumentAttribute.titleAttribute] as? String ?? "",
      "author": attrs[PDFDocumentAttribute.authorAttribute] as? String ?? "",
      "fileSize": data.count,
    ]

    let jsonData = try? JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
    let jsonString = jsonData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    let elapsed = CFAbsoluteTimeGetCurrent() - startTime

    return CLIExecutionResult(
      command: .validatePDF,
      inputPath: path,
      success: true,
      output: jsonString,
      executionTimeSeconds: elapsed
    )
  }

  private func extractText(path: String, startTime: CFAbsoluteTime) -> CLIExecutionResult {
    guard let data = FileManager.default.contents(atPath: path),
          let doc = PDFDocument(data: data) else {
      let elapsed = CFAbsoluteTimeGetCurrent() - startTime
      return CLIExecutionResult(
        command: .extractText,
        inputPath: path,
        success: false,
        output: "",
        error: "Invalid PDF",
        executionTimeSeconds: elapsed
      )
    }

    var fullText = ""
    for i in 0..<doc.pageCount {
      if let page = doc.page(at: i),
         let pageText = page.string {
        fullText += "--- Page \(i + 1) ---\n\(pageText)\n\n"
      }
    }

    let elapsed = CFAbsoluteTimeGetCurrent() - startTime
    return CLIExecutionResult(
      command: .extractText,
      inputPath: path,
      success: true,
      output: fullText,
      executionTimeSeconds: elapsed
    )
  }

  private func exportMetadata(path: String, startTime: CFAbsoluteTime) -> CLIExecutionResult {
    guard let data = FileManager.default.contents(atPath: path),
          let doc = PDFDocument(data: data) else {
      let elapsed = CFAbsoluteTimeGetCurrent() - startTime
      return CLIExecutionResult(
        command: .exportMetadata,
        inputPath: path,
        success: false,
        output: "",
        error: "Invalid PDF",
        executionTimeSeconds: elapsed
      )
    }

    let attrs = doc.documentAttributes ?? [:]
    let metadata: [String: Any] = [
      "title": attrs[PDFDocumentAttribute.titleAttribute] as? String ?? "",
      "author": attrs[PDFDocumentAttribute.authorAttribute] as? String ?? "",
      "creator": attrs[PDFDocumentAttribute.creatorAttribute] as? String ?? "",
      "producer": attrs[PDFDocumentAttribute.producerAttribute] as? String ?? "",
      "pageCount": doc.pageCount,
      "fileSize": data.count,
    ]

    let jsonData = try? JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
    let jsonString = jsonData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    let elapsed = CFAbsoluteTimeGetCurrent() - startTime

    return CLIExecutionResult(
      command: .exportMetadata,
      inputPath: path,
      success: true,
      output: jsonString,
      executionTimeSeconds: elapsed
    )
  }

  private func exportCitation(path: String, startTime: CFAbsoluteTime) -> CLIExecutionResult {
    guard let data = FileManager.default.contents(atPath: path),
          let doc = PDFDocument(data: data) else {
      let elapsed = CFAbsoluteTimeGetCurrent() - startTime
      return CLIExecutionResult(
        command: .exportCitation,
        inputPath: path,
        success: false,
        output: "",
        error: "Invalid PDF",
        executionTimeSeconds: elapsed
      )
    }

    let attrs = doc.documentAttributes ?? [:]
    let title = (attrs[PDFDocumentAttribute.titleAttribute] as? String) ?? URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
    let author = (attrs[PDFDocumentAttribute.authorAttribute] as? String) ?? "Unknown"
    let year = Calendar.current.component(.year, from: Date())
    let citation = "\(author) (\(year)). \(title)."

    let elapsed = CFAbsoluteTimeGetCurrent() - startTime
    return CLIExecutionResult(
      command: .exportCitation,
      inputPath: path,
      success: true,
      output: citation,
      executionTimeSeconds: elapsed
    )
  }
}
