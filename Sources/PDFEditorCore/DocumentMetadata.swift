import Foundation
import PDFKit

/// Rich metadata extracted from a PDF document.
///
/// First principle: metadata is the document's identity — who made it, when,
/// what it's about, what you can do with it. A basic file info panel is not enough.
///
/// Doctrine alignment:
/// - §3: Do things smartly — show what matters, hide what doesn't
/// - §5: Evidence-based — extract from the actual PDF, not猜测

public struct DocumentMetadata: Sendable {
  public let fileName: String
  public let fileSize: Int
  public let pageCount: Int
  public let title: String
  public let author: String
  public let subject: String
  public let creator: String
  public let producer: String
  public let creationDate: Date?
  public let modificationDate: Date?
  public let isEncrypted: Bool
  public let permissions: Permissions?

  public struct Permissions: Sendable {
    public let canPrint: Bool
    public let canCopy: Bool
    public let canModify: Bool
    public let canAddAnnotations: Bool
  }

  public init(
    fileName: String,
    fileSize: Int,
    pageCount: Int,
    title: String = "Unknown",
    author: String = "Unknown",
    subject: String = "",
    creator: String = "",
    producer: String = "",
    creationDate: Date? = nil,
    modificationDate: Date? = nil,
    isEncrypted: Bool = false,
    permissions: Permissions? = nil
  ) {
    self.fileName = fileName
    self.fileSize = fileSize
    self.pageCount = pageCount
    self.title = title
    self.author = author
    self.subject = subject
    self.creator = creator
    self.producer = producer
    self.creationDate = creationDate
    self.modificationDate = modificationDate
    self.isEncrypted = isEncrypted
    self.permissions = permissions
  }

  /// Extract metadata from a PDF document and file URL.
  public static func extract(from document: PDFDocument, url: URL? = nil) -> DocumentMetadata {
    let attributes = url.flatMap { try? FileManager.default.attributesOfItem(atPath: $0.path) }
    let fileSize = attributes?[.size] as? Int ?? 0
    let fileName = url?.lastPathComponent ?? "Unknown"

    let docAttributes = document.documentAttributes
    let title = docAttributes?[PDFDocumentAttribute.titleAttribute] as? String ?? "Unknown"
    let author = docAttributes?[PDFDocumentAttribute.authorAttribute] as? String ?? "Unknown"
    let subject = docAttributes?[PDFDocumentAttribute.subjectAttribute] as? String ?? ""
    let creator = docAttributes?[PDFDocumentAttribute.creatorAttribute] as? String ?? ""
    let producer = docAttributes?[PDFDocumentAttribute.producerAttribute] as? String ?? ""
    let creationDate = docAttributes?[PDFDocumentAttribute.creationDateAttribute] as? Date
    let modDate = docAttributes?[PDFDocumentAttribute.modificationDateAttribute] as? Date

    let permissions: Permissions? = document.isEncrypted ? Permissions(
      canPrint: document.allowsPrinting,
      canCopy: document.allowsCopying,
      canModify: document.allowsDocumentChanges,
      canAddAnnotations: true // PDFKit doesn't expose this directly
    ) : nil

    return DocumentMetadata(
      fileName: fileName,
      fileSize: fileSize,
      pageCount: document.pageCount,
      title: title,
      author: author,
      subject: subject,
      creator: creator,
      producer: producer,
      creationDate: creationDate,
      modificationDate: modDate,
      isEncrypted: document.isEncrypted,
      permissions: permissions
    )
  }

  /// Human-readable file size.
  public var formattedFileSize: String {
    ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
  }

  /// Human-readable creation date.
  public var formattedCreationDate: String {
    guard let date = creationDate else { return "Unknown" }
    return DateFormatter.mediumStyle.string(from: date)
  }

  /// Human-readable modification date.
  public var formattedModificationDate: String {
    guard let date = modificationDate else { return "Unknown" }
    return DateFormatter.mediumStyle.string(from: date)
  }
}

// MARK: - DateFormatter Extension

extension DateFormatter {
  static let mediumStyle: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .short
    return f
  }()
}
