import Foundation
import CryptoKit
import PDFKit

/// File-level COLLABORATE tier — bundles a PDF with its annotation sidecar
/// into a portable collaboration package that can be shared with partners.
///
/// First principle: collaboration is file-level, not server-level.
/// No cloud sync, no real-time co-editing. Just two people exchanging
/// annotated copies and merging the results. The package is self-contained:
/// PDF + annotations + metadata + integrity hash.
///
/// Package format (JSON manifest + PDF + sidecar):
/// ```
/// package/
///   manifest.json      — metadata, document identity, integrity hash
///   document.pdf       — the PDF (copied or symlinked)
///   annotations.json   — the annotation sidecar
/// ```
///
/// Doctrine alignment:
/// - §3: Do things smartly — file-level = no server, no account, no sync
/// - §5: Evidence-based — integrity hash verifies package hasn't been tampered
/// - §8: Capability activation — COLLABORATE is opt-in, packages are explicit
/// - §12: Privacy stays value-free — package contains marks, not document content

// MARK: - Collaboration Package

/// A self-contained bundle of PDF + annotations for sharing with a partner.
public struct CollaborationPackage: Codable, Sendable {
  /// Package format version (for forward compatibility).
  public let formatVersion: Int
  /// When this package was created.
  public let createdAt: Date
  /// Who created this package.
  public let authorName: String
  /// Optional note from the author.
  public let authorNote: String

  /// Identity of the base document.
  public let documentIdentity: DocumentIdentity

  /// The annotation marks being shared.
  public let annotations: [AnnotationMark]

  /// Integrity hash of the PDF bytes (SHA-256).
  public let pdfIntegrityHash: String

  /// Summary statistics.
  public var summary: PackageSummary {
    PackageSummary(
      markCount: annotations.count,
      pageCount: Set(annotations.map(\.pageIndex)).count,
      typeBreakdown: Dictionary(grouping: annotations, by: \.type).mapValues(\.count)
    )
  }

  public init(
    authorName: String,
    authorNote: String = "",
    documentIdentity: DocumentIdentity,
    annotations: [AnnotationMark],
    pdfIntegrityHash: String
  ) {
    self.formatVersion = 1
    self.createdAt = Date()
    self.authorName = authorName
    self.authorNote = authorNote
    self.documentIdentity = documentIdentity
    self.annotations = annotations
    self.pdfIntegrityHash = pdfIntegrityHash
  }
}

// MARK: - Document Identity

/// Identity of a PDF document, used to verify two packages refer to the same base document.
public struct DocumentIdentity: Codable, Sendable {
  /// SHA-256 hash of the PDF bytes.
  public let contentHash: String
  /// Original file name.
  public let fileName: String
  /// Number of pages.
  public let pageCount: Int
  /// File size in bytes.
  public let fileSize: Int
  /// Optional title from PDF metadata.
  public let title: String?
  /// Optional author from PDF metadata.
  public let pdfAuthor: String?

  public init(
    contentHash: String,
    fileName: String,
    pageCount: Int,
    fileSize: Int,
    title: String? = nil,
    pdfAuthor: String? = nil
  ) {
    self.contentHash = contentHash
    self.fileName = fileName
    self.pageCount = pageCount
    self.fileSize = fileSize
    self.title = title
    self.pdfAuthor = pdfAuthor
  }

  /// Two documents are the same if their content hashes match.
  /// File name and metadata may differ (renamed copies, etc.).
  public func isSameDocument(as other: DocumentIdentity) -> Bool {
    contentHash == other.contentHash
  }

  /// Human-readable identity string.
  public var displayIdentity: String {
    let name = title ?? fileName
    return "\(name) (\(pageCount) pages, \(pdfShortHash))"
  }

  private var pdfShortHash: String {
    String(contentHash.prefix(12))
  }
}

// MARK: - Package Summary

/// Quick stats about a collaboration package.
public struct PackageSummary: Sendable {
  public let markCount: Int
  public let pageCount: Int
  public let typeBreakdown: [AnnotationType: Int]

  public var description: String {
    let types = typeBreakdown.map { "\($0.value) \($0.key.displayName.lowercased())" }.joined(separator: ", ")
    return "\(markCount) marks across \(pageCount) pages (\(types))"
  }
}

// MARK: - Package Integrity

/// Result of verifying a collaboration package's integrity.
public enum PackageIntegrity: Sendable {
  /// Package is valid and document matches.
  case valid
  /// Document content hashes don't match — this package was created from a different PDF.
  case documentMismatch(expected: String, actual: String)
  /// PDF integrity hash doesn't match the bundled PDF.
  case pdfTampered
  /// Package format is too new for this version.
  case unsupportedVersion(Int)
  /// Package is structurally invalid.
  case invalidPackage(String)

  public var isOk: Bool {
    if case .valid = self { return true }
    return false
  }

  public var description: String {
    switch self {
    case .valid: return "Package is valid"
    case .documentMismatch(let expected, let actual):
      return "Document mismatch: expected hash \(String(expected.prefix(12)))…, got \(String(actual.prefix(12)))…"
    case .pdfTampered: return "PDF integrity hash does not match"
    case .unsupportedVersion(let v): return "Unsupported format version \(v)"
    case .invalidPackage(let reason): return "Invalid package: \(reason)"
    }
  }
}

// MARK: - Package Builder

/// Builds a collaboration package from a local PDF + annotations.
public struct CollaborationPackageBuilder {

  /// Build a package from a PDF file URL and annotation marks.
  public static func build(
    pdfURL: URL,
    marks: [AnnotationMark],
    authorName: String,
    authorNote: String = ""
  ) throws -> CollaborationPackage {
    let pdfData = try Data(contentsOf: pdfURL)
    let identity = try DocumentIdentityBuilder.build(from: pdfData, url: pdfURL)
    let hash = SHA256.hash(data: pdfData)
    let hashString = hash.map { String(format: "%02x", $0) }.joined()

    return CollaborationPackage(
      authorName: authorName,
      authorNote: authorNote,
      documentIdentity: identity,
      annotations: marks,
      pdfIntegrityHash: hashString
    )
  }

  /// Build a package and write it to a directory.
  public static func buildAndWrite(
    pdfURL: URL,
    marks: [AnnotationMark],
    authorName: String,
    authorNote: String = "",
    outputDirectory: URL
  ) throws -> CollaborationPackage {
    let pkg = try build(
      pdfURL: pdfURL,
      marks: marks,
      authorName: authorName,
      authorNote: authorNote
    )

    let fm = FileManager.default
    try fm.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

    // Write manifest
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let manifestData = try encoder.encode(pkg)
    try manifestData.write(to: outputDirectory.appendingPathComponent("manifest.json"))

    // Copy PDF
    let destPDF = outputDirectory.appendingPathComponent("document.pdf")
    try? fm.removeItem(at: destPDF)
    try fm.copyItem(at: pdfURL, to: destPDF)

    // Write annotations sidecar
    let sidecarEncoder = JSONEncoder()
    sidecarEncoder.dateEncodingStrategy = .iso8601
    sidecarEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let sidecarData = try sidecarEncoder.encode(marks)
    try sidecarData.write(to: outputDirectory.appendingPathComponent("annotations.json"))

    return pkg
  }
}

// MARK: - Package Reader

/// Reads and validates a collaboration package from a directory.
public struct CollaborationPackageReader {

  /// Read a package from a directory.
  public static func read(from directory: URL) throws -> (package: CollaborationPackage, pdfData: Data, annotations: [AnnotationMark]) {
    let manifestURL = directory.appendingPathComponent("manifest.json")
    let pdfURL = directory.appendingPathComponent("document.pdf")
    let sidecarURL = directory.appendingPathComponent("annotations.json")

    guard FileManager.default.fileExists(atPath: manifestURL.path) else {
      throw CollaborationError.missingManifest
    }
    guard FileManager.default.fileExists(atPath: pdfURL.path) else {
      throw CollaborationError.missingPDF
    }

    let manifestData = try Data(contentsOf: manifestURL)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let package = try decoder.decode(CollaborationPackage.self, from: manifestData)

    let pdfData = try Data(contentsOf: pdfURL)

    // Read annotations from sidecar (preferred) or from manifest
    let annotations: [AnnotationMark]
    if FileManager.default.fileExists(atPath: sidecarURL.path) {
      let sidecarData = try Data(contentsOf: sidecarURL)
      annotations = try decoder.decode([AnnotationMark].self, from: sidecarData)
    } else {
      annotations = package.annotations
    }

    return (package, pdfData, annotations)
  }

  /// Verify package integrity against a known document identity.
  public static func verify(
    package: CollaborationPackage,
    pdfData: Data,
    expectedIdentity: DocumentIdentity
  ) -> PackageIntegrity {
    // Version check
    guard package.formatVersion <= 1 else {
      return .unsupportedVersion(package.formatVersion)
    }

    // PDF hash check
    let actualHash = SHA256.hash(data: pdfData)
    let actualHashString = actualHash.map { String(format: "%02x", $0) }.joined()
    guard actualHashString == package.pdfIntegrityHash else {
      return .pdfTampered
    }

    // Document identity check
    guard package.documentIdentity.isSameDocument(as: expectedIdentity) else {
      return .documentMismatch(
        expected: expectedIdentity.contentHash,
        actual: package.documentIdentity.contentHash
      )
    }

    return .valid
  }
}

// MARK: - Errors

public enum CollaborationError: LocalizedError {
  case missingManifest
  case missingPDF
  case missingAnnotations
  case documentMismatch
  case mergeConflict(String)

  public var errorDescription: String? {
    switch self {
    case .missingManifest: return "Package missing manifest.json"
    case .missingPDF: return "Package missing document.pdf"
    case .missingAnnotations: return "Package missing annotations"
    case .documentMismatch: return "Packages are from different base documents"
    case .mergeConflict(let detail): return "Merge conflict: \(detail)"
    }
  }
}

// MARK: - Document Identity Builder

/// Builds a DocumentIdentity from PDF data.
public struct DocumentIdentityBuilder {
  public static func build(from pdfData: Data, url: URL) throws -> DocumentIdentity {
    let hash = SHA256.hash(data: pdfData)
    let hashString = hash.map { String(format: "%02x", $0) }.joined()

    let pdfDocument = PDFDocument(data: pdfData)
    let pageCount = pdfDocument?.pageCount ?? 0
    let title = pdfDocument?.documentAttributes?[PDFDocumentAttribute.titleAttribute.rawValue] as? String
      ?? url.deletingPathExtension().lastPathComponent

    return DocumentIdentity(
      contentHash: hashString,
      fileName: url.lastPathComponent,
      pageCount: pageCount,
      fileSize: pdfData.count,
      title: title
    )
  }
}
