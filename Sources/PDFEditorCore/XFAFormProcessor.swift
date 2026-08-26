import Foundation

/// XFA (XML Forms Architecture) Detection, Dataset Extraction, and AcroForm Normalization Engine:
/// - Detects dynamic and static XFA streams (/XFA in /AcroForm)
/// - Extracts XML datasets (<xfa:data> and <xfa:template>)
/// - Normalizes XFA key-value data into standard form fields
public struct XFAFormProcessor: Sendable {
  public enum XFAKind: String, Sendable, Codable {
    case absent = "absent"
    case staticXFA = "static_xfa"
    case dynamicXFA = "dynamic_xfa"
    case hybrid = "hybrid"
  }

  public struct XFAInspectionResult: Sendable, Equatable {
    public let kind: XFAKind
    public let packetNames: [String]
    public let extractedFields: [String: String]
    public let requiresFallbackFlattening: Bool

    public init(
      kind: XFAKind,
      packetNames: [String] = [],
      extractedFields: [String: String] = [:],
      requiresFallbackFlattening: Bool = false
    ) {
      self.kind = kind
      self.packetNames = packetNames
      self.extractedFields = extractedFields
      self.requiresFallbackFlattening = requiresFallbackFlattening
    }
  }

  public init() {}

  /// Inspects raw PDF bytes to detect XFA presence, packet streams, and datasets.
  public func inspectXFA(pdfData: Data) -> XFAInspectionResult {
    guard let pdfString = String(data: pdfData, encoding: .ascii) else {
      return XFAInspectionResult(kind: .absent)
    }

    let hasXFAKey = pdfString.contains("/XFA")
    guard hasXFAKey else {
      return XFAInspectionResult(kind: .absent)
    }

    var packets: [String] = []
    if pdfString.contains("template") { packets.append("template") }
    if pdfString.contains("datasets") || pdfString.contains("xfa:data") { packets.append("datasets") }
    if pdfString.contains("config") { packets.append("config") }
    if pdfString.contains("schema") { packets.append("schema") }

    let hasDynamic = pdfString.contains("<dynamicRender") || pdfString.contains("dynamicRender")
    let hasAcroFormFields = pdfString.contains("/Fields [") && !pdfString.contains("/Fields []")

    let kind: XFAKind
    if hasDynamic {
      kind = .dynamicXFA
    } else if hasAcroFormFields {
      kind = .hybrid
    } else {
      kind = .staticXFA
    }

    // Extract basic XML field-value keypairs from <xfa:data>
    var extractedFields: [String: String] = [:]
    if let dataStart = pdfString.range(of: "<xfa:data>"),
       let dataEnd = pdfString.range(of: "</xfa:data>") {
      let dataXML = String(pdfString[dataStart.upperBound..<dataEnd.lowerBound])
      let elementRegex = try? NSRegularExpression(pattern: #"<([a-zA-Z0-9_\-\.]+)>([^<]+)</\1>"#, options: [])
      if let elementRegex = elementRegex {
        let nsData = dataXML as NSString
        let matches = elementRegex.matches(in: dataXML, options: [], range: NSRange(location: 0, length: nsData.length))
        for match in matches {
          if match.numberOfRanges >= 3 {
            let key = nsData.substring(with: match.range(at: 1))
            let val = nsData.substring(with: match.range(at: 2))
            extractedFields[key] = val
          }
        }
      }
    }

    return XFAInspectionResult(
      kind: kind,
      packetNames: packets,
      extractedFields: extractedFields,
      requiresFallbackFlattening: kind == .dynamicXFA
    )
  }
}
