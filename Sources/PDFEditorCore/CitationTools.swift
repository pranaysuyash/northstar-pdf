import Foundation

/// Citation tools — generate formatted citations and bibliographies from PDF metadata.
///
/// First principle: citing a document should be as easy as copying its title.
/// The tool extracts metadata and formats it into standard citation styles.
///
/// Supported styles:
/// - APA 7th edition
/// - MLA 9th edition
/// - Chicago 17th edition
/// - IEEE
/// - Harvard
///
/// Doctrine alignment:
/// - §3: Do things smartly — extract metadata once, format many ways
/// - §5: Evidence-based — citations include retrieval date and URL

// MARK: - Citation Style

/// Supported citation styles.
public enum CitationStyle: String, CaseIterable, Sendable, Identifiable {
  case apa = "APA"
  case mla = "MLA"
  case chicago = "Chicago"
  case ieee = "IEEE"
  case harvard = "Harvard"

  public var id: String { rawValue }
  public var displayName: String { rawValue }

  public var helpText: String {
    switch self {
    case .apa: return "American Psychological Association, 7th edition"
    case .mla: return "Modern Language Association, 9th edition"
    case .chicago: return "Chicago Manual of Style, 17th edition"
    case .ieee: return "Institute of Electrical and Electronics Engineers"
    case .harvard: return "Harvard Referencing Style"
    }
  }
}

// MARK: - Citation

/// A formatted citation for a document.
public struct Citation: Sendable {
  /// The formatted citation text.
  public let text: String
  /// The citation style used.
  public let style: CitationStyle
  /// The document title.
  public let title: String
  /// The author (if known).
  public let author: String?
  /// The publication date (if known).
  public let date: String?
  /// The source URL (if available).
  public let url: String?
  /// When the citation was generated.
  public let generatedAt: Date

  /// Plain text representation.
  public var plainText: String { text }

  /// Markdown-formatted citation.
  public var markdown: String {
    if let url, !url.isEmpty {
      return "[\(text)](\(url))"
    }
    return text
  }
}

// MARK: - Citation Generator

/// Generates formatted citations from document metadata.
public struct CitationGenerator {

  /// Generate a citation in the specified style.
  public static func generate(
    title: String,
    author: String? = nil,
    date: String? = nil,
    url: String? = nil,
    style: CitationStyle
  ) -> Citation {
    let text: String

    switch style {
    case .apa:
      text = generateAPA(title: title, author: author, date: date, url: url)
    case .mla:
      text = generateMLA(title: title, author: author, date: date, url: url)
    case .chicago:
      text = generateChicago(title: title, author: author, date: date, url: url)
    case .ieee:
      text = generateIEEE(title: title, author: author, date: date, url: url)
    case .harvard:
      text = generateHarvard(title: title, author: author, date: date, url: url)
    }

    return Citation(
      text: text, style: style, title: title,
      author: author, date: date, url: url,
      generatedAt: Date()
    )
  }

  // MARK: - APA 7th Edition

  private static func generateAPA(
    title: String, author: String?, date: String?, url: String?
  ) -> String {
    var parts: [String] = []

    if let author {
      parts.append("\(author)")
    } else {
      parts.append("Unknown Author")
    }

    let year = date ?? "n.d."
    parts.append("(\(year)).")

    parts.append("*\(title)*.")

    if let url, !url.isEmpty {
      parts.append(url)
    }

    return parts.joined(separator: " ")
  }

  // MARK: - MLA 9th Edition

  private static func generateMLA(
    title: String, author: String?, date: String?, url: String?
  ) -> String {
    var parts: [String] = []

    if let author {
      parts.append("\(author).")
    }

    parts.append("\"\(title).\"")

    if let date {
      parts.append(date + ".")
    }

    if let url, !url.isEmpty {
      parts.append("Web.")
    }

    return parts.joined(separator: " ")
  }

  // MARK: - Chicago 17th Edition

  private static func generateChicago(
    title: String, author: String?, date: String?, url: String?
  ) -> String {
    var parts: [String] = []

    if let author {
      parts.append("\(author).")
    }

    parts.append("\"\(title).\"")

    if let date {
      parts.append(date + ".")
    }

    if let url, !url.isEmpty {
      parts.append(url)
    }

    return parts.joined(separator: " ")
  }

  // MARK: - IEEE

  private static func generateIEEE(
    title: String, author: String?, date: String?, url: String?
  ) -> String {
    var parts: [String] = []

    if let author {
      parts.append("\(author),")
    }

    parts.append("\"\(title),\"")

    if let date {
      parts.append(date + ".")
    }

    if let url, !url.isEmpty {
      parts.append("Available: \(url)")
    }

    return parts.joined(separator: " ")
  }

  // MARK: - Harvard

  private static func generateHarvard(
    title: String, author: String?, date: String?, url: String?
  ) -> String {
    var parts: [String] = []

    if let author {
      parts.append("\(author)")
    }

    let year = date ?? "n.d."
    parts.append("(\(year)).")

    parts.append("*\(title)*.")

    if let url, !url.isEmpty {
      parts.append("Available at: \(url)")
    }

    return parts.joined(separator: " ")
  }

  // MARK: - Bibliography

  /// Generate a bibliography (multiple citations sorted by author).
  public static func bibliography(
    entries: [(title: String, author: String?, date: String?, url: String?)],
    style: CitationStyle
  ) -> String {
    let citations = entries.map { entry in
      generate(
        title: entry.title, author: entry.author,
        date: entry.date, url: entry.url, style: style
      )
    }

    // Sort by author (or title if no author)
    let sorted = citations.sorted { a, b in
      let aKey = a.author ?? a.title
      let bKey = b.author ?? b.title
      return aKey.localizedCaseInsensitiveCompare(bKey) == .orderedAscending
    }

    return sorted.map(\.text).joined(separator: "\n\n")
  }
}
