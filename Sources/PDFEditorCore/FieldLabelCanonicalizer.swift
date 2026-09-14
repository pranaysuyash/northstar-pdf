import Foundation

public enum SemanticFieldTaxonomy: String, CaseIterable, Sendable {
  case personFullName = "person.name.full"
  case personFirstName = "person.name.first"
  case personLastName = "person.name.last"
  case personMiddleName = "person.name.middle"
  case identitySSN = "identity.national_id.ssn"
  case identityTaxID = "identity.national_id.tax_id"
  case identityPassport = "identity.national_id.passport"
  case contactPhone = "contact.telephony.phone"
  case contactMobile = "contact.telephony.mobile"
  case contactEmail = "contact.electronic.email"
  case contactAddress = "contact.postal.address"
  case contactCity = "contact.postal.city"
  case contactState = "contact.postal.state"
  case contactZipCode = "contact.postal.zip"
  case dateOfBirth = "identity.demographic.birth_date"
  case financialIBAN = "financial.payment.iban"
  case financialRouting = "financial.payment.routing"
  case financialAccount = "financial.payment.account"
}

/// A human-facing name derived from raw document text near a fillable region.
public struct CanonicalLabel: Equatable, Hashable, Sendable {
  public let displayName: String
  public let confidence: Double
  public let semanticKey: String?

  public init(displayName: String, confidence: Double, semanticKey: String? = nil) {
    self.displayName = displayName
    self.confidence = confidence
    self.semanticKey = semanticKey
  }
}

/// Turns raw label text such as `"1. FULL NAME:_______"` into a reviewable
/// display name (`"Full Name"`).
///
/// The canonicalizer is deliberately deterministic and value-free: it never
/// observes document values, only the static label string already held in
/// `TextLineEvidence` or OCR output. Generic layout words remain hard
/// negatives so section headers do not become suggestion names.
public enum FieldLabelCanonicalizer {
  /// Words that describe layout, never a field. A label consisting solely of
  /// these (after cleanup) yields no display name.
  private static let genericTokens: Set<String> = [
    "section", "note", "notes", "page", "please", "print", "for", "of",
    "the", "and", "or", "to", "use", "only", "office", "official",
    "continued", "form", "rev", "date", "here", "hereby", "applicant's",
  ]

  /// Small words kept lowercase in title case unless they open the name.
  private static let titleCaseMinorWords: Set<String> = [
    "of", "the", "and", "or", "to", "in", "on", "at", "a", "an",
  ]

  public static func canonicalize(_ raw: String) -> CanonicalLabel? {
    var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return nil }

    var adjusted = false

    // Strip leading enumeration markers: "1.", "1)", "(a)", "a.", "i.".
    if let range = text.range(
      of: #"^\(?[ivx]+[\.\)]\s+"#,
      options: [.regularExpression, .caseInsensitive]
    ) {
      text = String(text[range.upperBound...])
      adjusted = true
    } else if let range = text.range(
      of: #"^\(?[a-z][\.\)]\s+"#,
      options: [.regularExpression, .caseInsensitive]
    ) {
      text = String(text[range.upperBound...])
      adjusted = true
    } else if let range = text.range(
      of: #"^\d{1,3}[\.\)]\s+"#,
      options: .regularExpression
    ) {
      text = String(text[range.upperBound...])
      adjusted = true
    }

    // Replace blank-marker runs with spaces and collapse whitespace.
    if text.range(of: "_{2,}", options: .regularExpression) != nil {
      adjusted = true
    }
    text = text.replacingOccurrences(
      of: "_+", with: " ", options: .regularExpression)
    text = text.replacingOccurrences(
      of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespaces)

    // Trim trailing delimiters and punctuation runs.
    while let last = text.last,
      last == ":" || last == "." || last == "*" || last == "-"
        || last == "\u{2014}" || last == "\u{2013}"
    {
      text = String(text.dropLast())
      adjusted = true
    }
    text = text.trimmingCharacters(in: .whitespaces)

    guard text.count >= 2 && text.count <= 50 else { return nil }

    // A name made only of generic layout tokens or containing long prose is not a field name.
    let words = text.split(separator: " ").map(String.init)
    guard words.count <= 8 else { return nil }
    let meaningful = words.filter { !genericTokens.contains($0.lowercased()) }
    if meaningful.isEmpty { return nil }
    if words.count > meaningful.count { adjusted = true }

    // ALL-CAPS source text reads as shouting; normalize to Title Case.
    let letters = text.filter { $0.isLetter }
    if letters.count >= 3 {
      let uppercaseCount = text.filter { $0.isUppercase }.count
      if uppercaseCount >= Int(Double(letters.count) * 0.8) {
        text = titleCase(text)
        adjusted = true
      }
    }

    let confidence: Double = adjusted ? 0.7 : 0.95
    let semanticKey = inferSemanticKey(from: text)
    return CanonicalLabel(displayName: text, confidence: confidence, semanticKey: semanticKey)
  }

  public static func inferSemanticKey(from text: String) -> String? {
    let lower = text.lowercased()
    if lower.contains("full name") || lower.contains("applicant name") || lower.contains("legal name") || lower == "name" {
      return SemanticFieldTaxonomy.personFullName.rawValue
    }
    if lower.contains("first name") || lower.contains("given name") {
      return SemanticFieldTaxonomy.personFirstName.rawValue
    }
    if lower.contains("last name") || lower.contains("surname") || lower.contains("family name") {
      return SemanticFieldTaxonomy.personLastName.rawValue
    }
    if lower.contains("middle name") || lower.contains("middle initial") {
      return SemanticFieldTaxonomy.personMiddleName.rawValue
    }
    if lower.contains("ssn") || lower.contains("social security") {
      return SemanticFieldTaxonomy.identitySSN.rawValue
    }
    if lower.contains("tax id") || lower.contains("tin") || lower.contains("ein") || lower.contains("itin") {
      return SemanticFieldTaxonomy.identityTaxID.rawValue
    }
    if lower.contains("passport") {
      return SemanticFieldTaxonomy.identityPassport.rawValue
    }
    if lower.contains("mobile") || lower.contains("cell") {
      return SemanticFieldTaxonomy.contactMobile.rawValue
    }
    if lower.contains("phone") || lower.contains("telephone") || lower.contains("tel") {
      return SemanticFieldTaxonomy.contactPhone.rawValue
    }
    if lower.contains("email") || lower.contains("e-mail") {
      return SemanticFieldTaxonomy.contactEmail.rawValue
    }
    if lower.contains("address") || lower.contains("street") {
      return SemanticFieldTaxonomy.contactAddress.rawValue
    }
    if lower.contains("city") || lower.contains("town") {
      return SemanticFieldTaxonomy.contactCity.rawValue
    }
    if lower.contains("state") || lower.contains("province") {
      return SemanticFieldTaxonomy.contactState.rawValue
    }
    if lower.contains("zip") || lower.contains("postal") {
      return SemanticFieldTaxonomy.contactZipCode.rawValue
    }
    if lower.contains("birth") || lower.contains("dob") {
      return SemanticFieldTaxonomy.dateOfBirth.rawValue
    }
    if lower.contains("iban") {
      return SemanticFieldTaxonomy.financialIBAN.rawValue
    }
    if lower.contains("routing") {
      return SemanticFieldTaxonomy.financialRouting.rawValue
    }
    if lower.contains("account") {
      return SemanticFieldTaxonomy.financialAccount.rawValue
    }
    return nil
  }

  /// Best display name for a candidate from its stored fields, matching the
  /// fallback chain used across UI surfaces.
  public static func displayName(
    labelText: String?,
    fieldType: SuggestedFieldType?,
    entryMode: CandidateEntryMode,
    groupMemberCount: Int
  ) -> String {
    if let labelText, let canonical = canonicalize(labelText) {
      return canonical.displayName
    }
    switch fieldType {
    case .signature: return "Signature"
    case .date: return "Date"
    case .number: return "Number"
    case .checkbox: return "Checkbox"
    case .radio: return "Choice"
    case .choice: return "Choice"
    case .text, .unknown, nil:
      switch entryMode {
      case .singleText: return "Text entry"
      case .characterGrid: return "Grid (\(groupMemberCount) cells)"
      case .checkbox: return "Checkbox"
      case .radioGroup: return "Choice group"
      case .signature: return "Signature"
      case .unknown: return "Entry region"
      }
    }
  }

  private static func titleCase(_ value: String) -> String {
    let words = value.split(separator: " ", omittingEmptySubsequences: true)
    var result: [String] = []
    for (index, word) in words.enumerated() {
      let lower = word.lowercased()
      if index > 0 && titleCaseMinorWords.contains(lower) {
        result.append(lower)
      } else if let first = lower.first {
        result.append(first.uppercased() + lower.dropFirst())
      } else {
        result.append(lower)
      }
    }
    return result.joined(separator: " ")
  }
}
