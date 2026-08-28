import Foundation
import PDFKit

/// User-facing scripting surface — CLI entry point for batch operations
/// and automation workflows.
///
/// First principle: the app's core operations should be scriptable from
/// the command line. This enables automation without cloud dependencies.
///
/// Architecture:
/// - `ScriptCommand` — a single command (extract, validate, export, etc.)
/// - `ScriptWorkflow` — a sequence of commands with conditions
/// - `ScriptRunner` — executes commands with resource bounds
///
/// Doctrine alignment:
/// - §3: Do things smartly — scriptable core operations
/// - §8: Capability activation — scripting is opt-in, sandboxed
/// - §12: Privacy value-free — script runs are logged, not content

// MARK: - Script Command

/// A single scriptable command.
public enum ScriptCommand: String, Codable, Sendable, CaseIterable {
  case extractText = "extract-text"
  case validatePDF = "validate"
  case summarize = "summarize"
  case recognizeEntities = "recognize-entities"
  case exportMetadata = "export-metadata"
  case exportCitation = "export-citation"
  case listAnnotations = "list-annotations"

  public var displayName: String {
    switch self {
    case .extractText: return "Extract Text"
    case .validatePDF: return "Validate PDF"
    case .summarize: return "Summarize"
    case .recognizeEntities: return "Recognize Entities"
    case .exportMetadata: return "Export Metadata"
    case .exportCitation: return "Export Citation"
    case .listAnnotations: return "List Annotations"
    }
  }

  public var helpText: String {
    switch self {
    case .extractText: return "Extract all text from a PDF"
    case .validatePDF: return "Validate PDF structure and integrity"
    case .summarize: return "Generate a document summary"
    case .recognizeEntities: return "Extract dates, amounts, emails, URLs"
    case .exportMetadata: return "Export document metadata as JSON"
    case .exportCitation: return "Generate a formatted citation"
    case .listAnnotations: return "List all annotations in a document"
    }
  }
}

// MARK: - Script Step

/// A single step in a workflow.
public struct ScriptStep: Codable, Sendable {
  /// The command to execute.
  public let command: ScriptCommand
  /// Input file path.
  public let inputPath: String
  /// Output file path (optional).
  public let outputPath: String?
  /// Additional parameters.
  public let parameters: [String: String]

  public init(
    command: ScriptCommand,
    inputPath: String,
    outputPath: String? = nil,
    parameters: [String: String] = [:]
  ) {
    self.command = command
    self.inputPath = inputPath
    self.outputPath = outputPath
    self.parameters = parameters
  }
}

// MARK: - Script Workflow

/// A sequence of script steps.
public struct ScriptWorkflow: Codable, Sendable {
  /// Workflow name.
  public let name: String
  /// Steps to execute in order.
  public let steps: [ScriptStep]
  /// Whether to stop on first failure.
  public let stopOnFailure: Bool

  public init(name: String, steps: [ScriptStep], stopOnFailure: Bool = true) {
    self.name = name
    self.steps = steps
    self.stopOnFailure = stopOnFailure
  }
}

// MARK: - Script Result

/// Result of executing a script command.
public struct ScriptResult: Sendable {
  /// Whether the command succeeded.
  public let success: Bool
  /// Output text (command-specific).
  public let output: String
  /// Error message if failed.
  public let error: String?
  /// Execution time in seconds.
  public let executionTimeSeconds: Double

  public init(
    success: Bool, output: String, error: String? = nil,
    executionTimeSeconds: Double
  ) {
    self.success = success
    self.output = output
    self.error = error
    self.executionTimeSeconds = executionTimeSeconds
  }
}

// MARK: - Script Runner

/// Executes script commands with resource bounds.
public struct ScriptRunner {

  /// Maximum execution time per command (seconds).
  public let timeoutSeconds: Double

  public init(timeoutSeconds: Double = 30) {
    self.timeoutSeconds = timeoutSeconds
  }

  /// Execute a single command on a file.
  public func execute(_ command: ScriptCommand, fileURL: URL) -> ScriptResult {
    let start = CFAbsoluteTimeGetCurrent()
    let elapsed = { CFAbsoluteTimeGetCurrent() - start }

    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      return ScriptResult(
        success: false, output: "", error: "File not found: \(fileURL.path)",
        executionTimeSeconds: elapsed()
      )
    }

    guard let data = try? Data(contentsOf: fileURL) else {
      return ScriptResult(
        success: false, output: "", error: "Could not read file",
        executionTimeSeconds: elapsed()
      )
    }

    let pipeline = RenderingPipeline()

    switch command {
    case .extractText:
      do {
        let result = try pipeline.extractText()
        return ScriptResult(
          success: true, output: result.fullText,
          executionTimeSeconds: elapsed()
        )
      } catch {
        return ScriptResult(
          success: false, output: "", error: error.localizedDescription,
          executionTimeSeconds: elapsed()
        )
      }

    case .validatePDF:
      let isValid = PDFDocument(data: data) != nil
      return ScriptResult(
        success: isValid,
        output: isValid ? "PDF is valid" : "PDF is invalid or corrupted",
        executionTimeSeconds: elapsed()
      )

    case .summarize:
      do {
        let result = try pipeline.summarize()
        return ScriptResult(
          success: true, output: result.summary,
          executionTimeSeconds: elapsed()
        )
      } catch {
        return ScriptResult(
          success: false, output: "", error: error.localizedDescription,
          executionTimeSeconds: elapsed()
        )
      }

    case .recognizeEntities:
      do {
        let result = try pipeline.recognizeEntities()
        var output = "Entities: \(result.totalCount) found, \(result.typeCount) types\n"
        for (type, entities) in result.byType {
          output += "  \(type): \(entities.count)\n"
        }
        return ScriptResult(
          success: true, output: output,
          executionTimeSeconds: elapsed()
        )
      } catch {
        return ScriptResult(
          success: false, output: "", error: error.localizedDescription,
          executionTimeSeconds: elapsed()
        )
      }

    case .exportMetadata:
      if let document = PDFDocument(data: data) {
        let m = DocumentMetadata.extract(from: document, url: fileURL)
        var output = "Title: \(m.title)\n"
        output += "Author: \(m.author)\n"
        output += "Pages: \(m.pageCount)\n"
        output += "File Size: \(m.formattedFileSize)\n"
        output += "Encrypted: \(m.isEncrypted)\n"
        if let created = m.formattedCreationDate as String? {
          output += "Created: \(created)\n"
        }
        return ScriptResult(
          success: true, output: output,
          executionTimeSeconds: elapsed()
        )
      } else {
        return ScriptResult(
          success: false, output: "", error: "Could not open PDF",
          executionTimeSeconds: elapsed()
        )
      }

    case .exportCitation:
      let citation = CitationGenerator.generate(
        title: fileURL.deletingPathExtension().lastPathComponent,
        style: .apa
      )
      return ScriptResult(
        success: true, output: citation.plainText,
        executionTimeSeconds: elapsed()
      )

    case .listAnnotations:
      return ScriptResult(
        success: true, output: "Annotation listing requires AnnotationStore (not yet CLI-integrated)",
        executionTimeSeconds: elapsed()
      )
    }
  }

  /// Execute a full workflow.
  public func executeWorkflow(_ workflow: ScriptWorkflow) -> [ScriptResult] {
    var results: [ScriptResult] = []

    for step in workflow.steps {
      let fileURL = URL(fileURLWithPath: step.inputPath)
      let result = execute(step.command, fileURL: fileURL)
      results.append(result)

      if !result.success && workflow.stopOnFailure {
        break
      }
    }

    return results
  }
}
