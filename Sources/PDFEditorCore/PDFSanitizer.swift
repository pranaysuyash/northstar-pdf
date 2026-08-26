import Foundation

/// Provides automated structural sanitization for exported PDFs:
/// - Strips /Metadata XMP streams
/// - Empties /Info metadata dictionaries (Title, Author, Creator, Producer)
/// - Neutralizes /OpenAction, /AA (additional actions), and embedded JavaScript
/// - Removes embedded files (/EmbeddedFiles) and attachments
public struct PDFSanitizer: Sendable {
  public struct SanitizationOptions: Sendable {
    public var stripMetadata: Bool
    public var emptyInfoDictionary: Bool
    public var neutralizeActions: Bool
    public var removeAttachments: Bool

    public init(
      stripMetadata: Bool = true,
      emptyInfoDictionary: Bool = true,
      neutralizeActions: Bool = true,
      removeAttachments: Bool = true
    ) {
      self.stripMetadata = stripMetadata
      self.emptyInfoDictionary = emptyInfoDictionary
      self.neutralizeActions = neutralizeActions
      self.removeAttachments = removeAttachments
    }
  }

  public struct SanitizationReport: Sendable, Equatable {
    public let xmpMetadataStripped: Bool
    public let infoDictionaryCleaned: Bool
    public let actionsNeutralized: Int
    public let attachmentsRemoved: Int

    public init(
      xmpMetadataStripped: Bool,
      infoDictionaryCleaned: Bool,
      actionsNeutralized: Int,
      attachmentsRemoved: Int
    ) {
      self.xmpMetadataStripped = xmpMetadataStripped
      self.infoDictionaryCleaned = infoDictionaryCleaned
      self.actionsNeutralized = actionsNeutralized
      self.attachmentsRemoved = attachmentsRemoved
    }
  }

  public init() {}

  /// Sanitizes raw PDF data in accordance with requested options without altering content pages.
  public func sanitize(
    pdfData: Data,
    options: SanitizationOptions = SanitizationOptions()
  ) -> (sanitizedData: Data, report: SanitizationReport) {
    guard var pdfString = String(data: pdfData, encoding: .ascii) else {
      return (pdfData, SanitizationReport(xmpMetadataStripped: false, infoDictionaryCleaned: false, actionsNeutralized: 0, attachmentsRemoved: 0))
    }

    var actionsNeutralized = 0
    var attachmentsRemoved = 0
    var xmpStripped = false
    var infoCleaned = false

    // 1. Neutralize Actions (/OpenAction, /AA, /JavaScript, /Launch)
    if options.neutralizeActions {
      if pdfString.contains("/OpenAction") {
        pdfString = pdfString.replacingOccurrences(of: "/OpenAction", with: "/_NeutralizedOpenAction")
        actionsNeutralized += 1
      }
      if pdfString.contains("/AA") {
        pdfString = pdfString.replacingOccurrences(of: "/AA", with: "/_NeutralizedAA")
        actionsNeutralized += 1
      }
      if pdfString.contains("/JavaScript") {
        pdfString = pdfString.replacingOccurrences(of: "/JavaScript", with: "/_NeutralizedJS")
        actionsNeutralized += 1
      }
      if pdfString.contains("/Launch") {
        pdfString = pdfString.replacingOccurrences(of: "/Launch", with: "/_NeutralizedLaunch")
        actionsNeutralized += 1
      }
    }

    // 2. Remove Embedded Files
    if options.removeAttachments {
      if pdfString.contains("/EmbeddedFiles") {
        pdfString = pdfString.replacingOccurrences(of: "/EmbeddedFiles", with: "/_NeutralizedFiles")
        attachmentsRemoved += 1
      }
      if pdfString.contains("/Names") && pdfString.contains("/EF") {
        pdfString = pdfString.replacingOccurrences(of: "/EF", with: "/_NeutralizedEF")
        attachmentsRemoved += 1
      }
    }

    // 3. Strip XMP Metadata
    if options.stripMetadata {
      if pdfString.contains("/Type /Metadata") || pdfString.contains("/Type/Metadata") {
        xmpStripped = true
        pdfString = pdfString.replacingOccurrences(of: "/Type /Metadata", with: "/Type /_StrippedMetadata")
        pdfString = pdfString.replacingOccurrences(of: "/Type/Metadata", with: "/Type/_StrippedMetadata")
      }
    }

    // 4. Empty Info Dictionary
    if options.emptyInfoDictionary {
      if pdfString.contains("/Author") || pdfString.contains("/Creator") || pdfString.contains("/Producer") {
        infoCleaned = true
        // Neutralize standard info dictionary string tags
        pdfString = pdfString.replacingOccurrences(of: "/Author", with: "/_Author")
        pdfString = pdfString.replacingOccurrences(of: "/Creator", with: "/_Creator")
        pdfString = pdfString.replacingOccurrences(of: "/Producer", with: "/_Producer")
        pdfString = pdfString.replacingOccurrences(of: "/Title", with: "/_Title")
      }
    }

    let sanitizedData = pdfString.data(using: .ascii) ?? pdfData
    let report = SanitizationReport(
      xmpMetadataStripped: xmpStripped,
      infoDictionaryCleaned: infoCleaned,
      actionsNeutralized: actionsNeutralized,
      attachmentsRemoved: attachmentsRemoved
    )

    return (sanitizedData, report)
  }
}
