import Foundation

/// Batch processing for READ — extract text, entities, summaries across
/// multiple PDFs with per-item outcome reporting.
///
/// First principle: batch is a multiplier, not a feature. It applies the
/// same per-document operation to a set of documents, with per-item
/// success/failure reporting (never all-or-nothing).
///
/// Doctrine alignment:
/// - §3: Do things smartly — parallel extraction, serial reporting
/// - §5: Evidence-based — per-item outcomes with timing
/// - §8: Capability activation — batch is opt-in, not default

// MARK: - Batch Job Type

/// Types of batch read operations.
public enum BatchReadJobType: String, Sendable, CaseIterable, Identifiable {
  case extractText = "extract_text"
  case recognizeEntities = "recognize_entities"
  case summarize = "summarize"
  case extractKeyPoints = "extract_key_points"

  public var id: String { rawValue }
  public var displayName: String {
    switch self {
    case .extractText: return "Extract Text"
    case .recognizeEntities: return "Recognize Entities"
    case .summarize: return "Summarize"
    case .extractKeyPoints: return "Extract Key Points"
    }
  }
}

// MARK: - Batch Item Result

/// Result of processing a single item in a batch.
public struct BatchItemResult: Sendable {
  /// The document file name.
  public let fileName: String
  /// Whether processing succeeded.
  public let success: Bool
  /// Error message if failed.
  public let error: String?
  /// Processing time in seconds.
  public let processingTimeSeconds: Double
  /// Output summary (character count, entity count, etc.).
  public let outputSummary: String

  public init(
    fileName: String, success: Bool, error: String? = nil,
    processingTimeSeconds: Double, outputSummary: String
  ) {
    self.fileName = fileName
    self.success = success
    self.error = error
    self.processingTimeSeconds = processingTimeSeconds
    self.outputSummary = outputSummary
  }
}

// MARK: - Batch Job Report

/// Complete report for a batch processing job.
public struct BatchJobReport: Sendable {
  /// The job type.
  public let jobType: BatchReadJobType
  /// When the job started.
  public let startedAt: Date
  /// When the job completed.
  public let completedAt: Date
  /// Total number of items processed.
  public let totalItems: Int
  /// Number of successful items.
  public let successCount: Int
  /// Number of failed items.
  public let failureCount: Int
  /// Per-item results.
  public let results: [BatchItemResult]
  /// Total processing time.
  public var totalTimeSeconds: Double {
    completedAt.timeIntervalSince(startedAt)
  }
  /// Success rate (0.0–1.0).
  public var successRate: Double {
    guard totalItems > 0 else { return 0 }
    return Double(successCount) / Double(totalItems)
  }

  public var summary: String {
    "\(jobType.displayName): \(successCount)/\(totalItems) succeeded (\(Int(successRate * 100))%) in \(String(format: "%.1f", totalTimeSeconds))s"
  }
}

// MARK: - Batch Read Processor

/// Processes multiple PDFs with a chosen operation.
///
/// Usage:
/// ```swift
/// let processor = BatchReadProcessor()
/// let report = processor.process(
///   files: pdfURLs,
///   jobType: .extractText
/// )
/// ```
public struct BatchReadProcessor {

  /// Process a set of PDF files with the specified job type.
  public func process(
    files: [URL],
    jobType: BatchReadJobType
  ) -> BatchJobReport {
    let startedAt = Date()
    var results: [BatchItemResult] = []

    for file in files {
      let itemStarted = CFAbsoluteTimeGetCurrent()
      let result = processFile(file, jobType: jobType)
      let itemTime = CFAbsoluteTimeGetCurrent() - itemStarted
      results.append(BatchItemResult(
        fileName: file.lastPathComponent,
        success: result.success,
        error: result.error,
        processingTimeSeconds: itemTime,
        outputSummary: result.summary
      ))
    }

    let successCount = results.filter(\.success).count

    return BatchJobReport(
      jobType: jobType,
      startedAt: startedAt,
      completedAt: Date(),
      totalItems: files.count,
      successCount: successCount,
      failureCount: files.count - successCount,
      results: results
    )
  }

  // MARK: - Per-File Processing

  private func processFile(_ url: URL, jobType: BatchReadJobType) -> (success: Bool, error: String?, summary: String) {
    guard let data = try? Data(contentsOf: url) else {
      return (false, "Could not read file", "")
    }

    let pipeline = RenderingPipeline()

    switch jobType {
    case .extractText:
      do {
        let result = try pipeline.extractText()
        return (true, nil, "\(result.fullText.count) characters, \(result.blocks.count) blocks")
      } catch {
        return (false, error.localizedDescription, "")
      }

    case .recognizeEntities:
      do {
        let result = try pipeline.recognizeEntities()
        return (true, nil, "\(result.totalCount) entities, \(result.typeCount) types")
      } catch {
        return (false, error.localizedDescription, "")
      }

    case .summarize:
      do {
        let result = try pipeline.summarize()
        return (true, nil, "Key points: \(result.keyPoints.count)")
      } catch {
        return (false, error.localizedDescription, "")
      }

    case .extractKeyPoints:
      do {
        let result = try pipeline.extractKeyPoints()
        return (true, nil, "\(result.totalCount) key points")
      } catch {
        return (false, error.localizedDescription, "")
      }
    }
  }
}
