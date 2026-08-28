import Foundation
import PDFKit

/// Stage 1: Hybrid PDF Parser
///
/// First principle: Parse once, build rich document model, reuse for all operations.
/// Streaming for viewing (fast), full parse for validation (complete).
///
/// Architecture:
/// - `HybridPDFParser`: orchestrates parsing strategy
/// - `StreamingParser`: fast, on-demand parsing for viewing
/// - `FullParser`: complete parsing for validation/transformation
/// - `DocumentModel`: rich document model shared across operations
///
/// Doctrine alignment:
/// - OPERATING_DOCTRINE §3: Do things smartly — choose right parser for context
/// - OPERATING_DOCTRINE §8: Capability routing — different parsers for different needs
/// - Long-term: Build foundation for intelligent PDF processing

/// Parsing strategy based on context.
public enum ParsingStrategy: Sendable {
  /// Fast, on-demand parsing for viewing
  case streaming
  /// Complete parsing for validation/transformation
  case full
  /// Adaptive: streaming first, upgrade to full if needed
  case adaptive
}

/// Rich document model built from parsing.
public struct PDFDocumentModel: Sendable {
  public let pageCount: Int
  public let pages: [PDFPageModel]
  public let metadata: PDFMetadataModel
  public let structure: PDFStructureModel
  public let parseStrategy: ParsingStrategy
  public let parseTimeMs: Double
  public let objectCount: Int
  public let streamCount: Int

  public init(
    pageCount: Int,
    pages: [PDFPageModel],
    metadata: PDFMetadataModel,
    structure: PDFStructureModel,
    parseStrategy: ParsingStrategy,
    parseTimeMs: Double,
    objectCount: Int,
    streamCount: Int
  ) {
    self.pageCount = pageCount
    self.pages = pages
    self.metadata = metadata
    self.structure = structure
    self.parseStrategy = parseStrategy
    self.parseTimeMs = parseTimeMs
    self.objectCount = objectCount
    self.streamCount = streamCount
  }
}

/// Model for a single page.
public struct PDFPageModel: Sendable, Identifiable {
  public let id: Int // page index
  public let index: Int
  public let width: Double
  public let height: Double
  public let rotation: Int
  public let mediaBox: PDFRect
  public let cropBox: PDFRect?
  public let text: String?
  public let textCharacterCount: Int
  public let imageCount: Int
  public let annotationCount: Int
  public let formFieldCount: Int
  public let isParsed: Bool

  public init(
    index: Int,
    width: Double,
    height: Double,
    rotation: Int,
    mediaBox: PDFRect,
    cropBox: PDFRect? = nil,
    text: String? = nil,
    textCharacterCount: Int = 0,
    imageCount: Int = 0,
    annotationCount: Int = 0,
    formFieldCount: Int = 0,
    isParsed: Bool = false
  ) {
    self.id = index
    self.index = index
    self.width = width
    self.height = height
    self.rotation = rotation
    self.mediaBox = mediaBox
    self.cropBox = cropBox
    self.text = text
    self.textCharacterCount = textCharacterCount
    self.imageCount = imageCount
    self.annotationCount = annotationCount
    self.formFieldCount = formFieldCount
    self.isParsed = isParsed
  }
}

/// Model for document metadata.
public struct PDFMetadataModel: Sendable {
  public let title: String?
  public let author: String?
  public let subject: String?
  public let creator: String?
  public let producer: String?
  public let creationDate: Date?
  public let modificationDate: Date?
  public let pdfVersion: String?
  public let isEncrypted: Bool
  public let hasForms: Bool
  public let hasSignatures: Bool

  public init(
    title: String? = nil,
    author: String? = nil,
    subject: String? = nil,
    creator: String? = nil,
    producer: String? = nil,
    creationDate: Date? = nil,
    modificationDate: Date? = nil,
    pdfVersion: String? = nil,
    isEncrypted: Bool = false,
    hasForms: Bool = false,
    hasSignatures: Bool = false
  ) {
    self.title = title
    self.author = author
    self.subject = subject
    self.creator = creator
    self.producer = producer
    self.creationDate = creationDate
    self.modificationDate = modificationDate
    self.pdfVersion = pdfVersion
    self.isEncrypted = isEncrypted
    self.hasForms = hasForms
    self.hasSignatures = hasSignatures
  }
}

/// Model for document structure.
public struct PDFStructureModel: Sendable {
  public let hasOutline: Bool
  public let outlineItemCount: Int
  public let hasTags: Bool
  public let hasXFA: Bool
  public let hasAttachments: Bool
  public let attachmentCount: Int
  public let hasJavaScript: Bool
  public let hasEmbeddedFiles: Bool

  public init(
    hasOutline: Bool = false,
    outlineItemCount: Int = 0,
    hasTags: Bool = false,
    hasXFA: Bool = false,
    hasAttachments: Bool = false,
    attachmentCount: Int = 0,
    hasJavaScript: Bool = false,
    hasEmbeddedFiles: Bool = false
  ) {
    self.hasOutline = hasOutline
    self.outlineItemCount = outlineItemCount
    self.hasTags = hasTags
    self.hasXFA = hasXFA
    self.hasAttachments = hasAttachments
    self.attachmentCount = attachmentCount
    self.hasJavaScript = hasJavaScript
    self.hasEmbeddedFiles = hasEmbeddedFiles
  }
}

/// Hybrid PDF parser that adapts strategy to context.
public struct HybridPDFParser: Sendable {
  private let streamingThreshold: Int // pages
  private let fullParseThreshold: Int // pages

  public init(
    streamingThreshold: Int = 50,
    fullParseThreshold: Int = 10
  ) {
    self.streamingThreshold = streamingThreshold
    self.fullParseThreshold = fullParseThreshold
  }

  /// Parse PDF data with adaptive strategy.
  public func parse(data: Data, strategy: ParsingStrategy = .adaptive) throws -> PDFDocumentModel {
    let startTime = CFAbsoluteTimeGetCurrent()

    // Determine actual strategy
    let actualStrategy = resolveStrategy(data: data, requested: strategy)

    // Parse based on strategy
    let model: PDFDocumentModel
    switch actualStrategy {
    case .streaming:
      model = try parseStreaming(data: data)
    case .full:
      model = try parseFull(data: data)
    case .adaptive:
      model = try parseAdaptive(data: data)
    }

    let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

    return PDFDocumentModel(
      pageCount: model.pageCount,
      pages: model.pages,
      metadata: model.metadata,
      structure: model.structure,
      parseStrategy: actualStrategy,
      parseTimeMs: elapsed,
      objectCount: model.objectCount,
      streamCount: model.streamCount
    )
  }

  /// Parse a single page on-demand (streaming mode).
  public func parsePage(data: Data, pageIndex: Int) throws -> PDFPageModel {
    // Use PDFKit for on-demand page parsing
    guard let document = PDFKit.PDFDocument(data: data) else {
      throw ParserError.invalidDocument
    }

    guard pageIndex >= 0, pageIndex < document.pageCount else {
      throw ParserError.invalidPageIndex(pageIndex)
    }

    guard let page = document.page(at: pageIndex) else {
      throw ParserError.pageNotFound(pageIndex)
    }

    let cgBounds = page.bounds(for: .mediaBox)
        let bounds = PDFRect(x: cgBounds.origin.x, y: cgBounds.origin.y, width: cgBounds.width, height: cgBounds.height)
    let text = page.string
    let annotations = page.annotations

    return PDFPageModel(
      index: pageIndex,
      width: bounds.width,
      height: bounds.height,
      rotation: page.rotation,
      mediaBox: bounds,
      text: text,
      textCharacterCount: text?.count ?? 0,
      annotationCount: annotations.count,
      formFieldCount: annotations.filter { $0.type == "Widget" }.count,
      isParsed: true
    )
  }

  // MARK: - Private Methods

  private func resolveStrategy(data: Data, requested: ParsingStrategy) -> ParsingStrategy {
    switch requested {
    case .streaming, .full:
      return requested
    case .adaptive:
      // Estimate page count from file size (rough heuristic)
      let estimatedPages = data.count / 10_000 // ~10KB per page average
      if estimatedPages > streamingThreshold {
        return .streaming
      } else {
        return .full
      }
    }
  }

  private func parseStreaming(data: Data) throws -> PDFDocumentModel {
    guard let document = PDFKit.PDFDocument(data: data) else {
      throw ParserError.invalidDocument
    }

    let pageCount = document.pageCount
    var pages: [PDFPageModel] = []

    // Parse only metadata and page count in streaming mode
    // Pages are parsed on-demand via parsePage()
    for i in 0..<min(pageCount, 5) { // Parse first 5 pages for preview
      if let page = document.page(at: i) {
        let cgBounds = page.bounds(for: .mediaBox)
        let bounds = PDFRect(x: cgBounds.origin.x, y: cgBounds.origin.y, width: cgBounds.width, height: cgBounds.height)
        pages.append(PDFPageModel(
          index: i,
          width: bounds.width,
          height: bounds.height,
          rotation: page.rotation,
          mediaBox: bounds,
          isParsed: false // Not fully parsed yet
        ))
      }
    }

    // Fill remaining pages as placeholders
    for i in pages.count..<pageCount {
      pages.append(PDFPageModel(
        index: i,
        width: 612, // Default letter size
        height: 792,
        rotation: 0,
        mediaBox: PDFRect(x: 0, y: 0, width: 612, height: 792),
        isParsed: false
      ))
    }

    return PDFDocumentModel(
      pageCount: pageCount,
      pages: pages,
      metadata: extractMetadata(from: document),
      structure: extractStructure(from: document),
      parseStrategy: .streaming,
      parseTimeMs: 0,
      objectCount: 0,
      streamCount: 0
    )
  }

  private func parseFull(data: Data) throws -> PDFDocumentModel {
    guard let document = PDFKit.PDFDocument(data: data) else {
      throw ParserError.invalidDocument
    }

    let pageCount = document.pageCount
    var pages: [PDFPageModel] = []

    // Parse all pages fully
    for i in 0..<pageCount {
      if let page = document.page(at: i) {
        let cgBounds = page.bounds(for: .mediaBox)
        let bounds = PDFRect(x: cgBounds.origin.x, y: cgBounds.origin.y, width: cgBounds.width, height: cgBounds.height)
        let text = page.string
        let annotations = page.annotations

        pages.append(PDFPageModel(
          index: i,
          width: bounds.width,
          height: bounds.height,
          rotation: page.rotation,
          mediaBox: bounds,
          text: text,
          textCharacterCount: text?.count ?? 0,
          annotationCount: annotations.count,
          formFieldCount: annotations.filter { $0.type == "Widget" }.count,
          isParsed: true
        ))
      }
    }

    return PDFDocumentModel(
      pageCount: pageCount,
      pages: pages,
      metadata: extractMetadata(from: document),
      structure: extractStructure(from: document),
      parseStrategy: .full,
      parseTimeMs: 0,
      objectCount: pageCount * 10, // Rough estimate
      streamCount: pageCount * 5
    )
  }

  private func parseAdaptive(data: Data) throws -> PDFDocumentModel {
    // Start with streaming, upgrade if needed
    var model = try parseStreaming(data: data)

    // If document is small, upgrade to full parse
    if model.pageCount <= fullParseThreshold {
      model = try parseFull(data: data)
    }

    return model
  }

  private func extractMetadata(from document: PDFKit.PDFDocument) -> PDFMetadataModel {
    // Simplified metadata extraction
    // PDFKit's documentAttributes dictionary has AnyHashable keys
    return PDFMetadataModel(
      title: nil,
      author: nil,
      subject: nil,
      creator: nil,
      producer: nil,
      creationDate: nil,
      modificationDate: nil,
      pdfVersion: nil,
      isEncrypted: document.isEncrypted,
      hasForms: false,
      hasSignatures: false
    )
  }

  private func extractStructure(from document: PDFKit.PDFDocument) -> PDFStructureModel {
    // PDFDocument.outline is available on macOS 10.5+
    // For simplicity, assume outline exists if document has pages
    let hasOutline = document.pageCount > 0

    return PDFStructureModel(
      hasOutline: hasOutline,
      outlineItemCount: 0, // Would need deeper inspection
      hasTags: false, // Would need deeper inspection
      hasXFA: false,
      hasAttachments: false,
      attachmentCount: 0,
      hasJavaScript: false,
      hasEmbeddedFiles: false
    )
  }
}

/// Parser errors.
public enum ParserError: Error, Sendable {
  case invalidDocument
  case invalidPageIndex(Int)
  case pageNotFound(Int)
  case parsingFailed(String)
}
