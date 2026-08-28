import Foundation

/// Form validation rules — validate form fields against defined rules.
///
/// First principle: catch errors before they become problems. Validation
/// rules check form fields against constraints (required, type, range, pattern)
/// and report issues with clear messages.
///
/// Doctrine alignment:
/// - §3: Do things smartly — validate at entry, not at export
/// - §5: Evidence-based — every validation result includes the field, rule, and message

// MARK: - Validation Rule

/// A single validation rule for a form field.
public enum ValidationRule: Codable, Sendable {
  /// Field must not be empty.
  case required
  /// Field must be a valid email address.
  case email
  /// Field must be a valid URL.
  case url
  /// Field must be a valid phone number (digits, spaces, dashes, parens).
  case phone
  /// Field must be a number within a range.
  case numberRange(min: Double, max: Double)
  /// Field must match a regex pattern.
  case pattern(String)
  /// Field must have at least this many characters.
  case minLength(Int)
  /// Field must have at most this many characters.
  case maxLength(Int)
  /// Field must be one of the allowed values.
  case oneOf([String])

  public var description: String {
    switch self {
    case .required: return "Required"
    case .email: return "Must be a valid email"
    case .url: return "Must be a valid URL"
    case .phone: return "Must be a valid phone number"
    case .numberRange(let min, let max): return "Must be between \(min) and \(max)"
    case .pattern(let p): return "Must match pattern: \(p)"
    case .minLength(let n): return "Must be at least \(n) characters"
    case .maxLength(let n): return "Must be at most \(n) characters"
    case .oneOf(let values): return "Must be one of: \(values.joined(separator: ", "))"
    }
  }
}

// MARK: - Validation Result

/// Result of validating a single field.
public struct FieldValidationResult: Sendable, Identifiable {
  public let id = UUID()
  /// The field name/identifier.
  public let fieldName: String
  /// The field value that was validated.
  public let fieldValue: String
  /// Whether validation passed.
  public let isValid: Bool
  /// The rule that was applied.
  public let rule: ValidationRule
  /// Error message if validation failed.
  public let message: String?

  public init(fieldName: String, fieldValue: String, isValid: Bool, rule: ValidationRule, message: String? = nil) {
    self.fieldName = fieldName
    self.fieldValue = fieldValue
    self.isValid = isValid
    self.rule = rule
    self.message = message
  }
}

// MARK: - Form Validation Report

/// Complete report for form validation.
public struct FormValidationReport: Sendable {
  /// All field validation results.
  public let results: [FieldValidationResult]
  /// Number of valid fields.
  public let validCount: Int
  /// Number of invalid fields.
  public let invalidCount: Int
  /// Total fields checked.
  public let totalCount: Int

  /// Whether all fields passed validation.
  public var allValid: Bool { invalidCount == 0 }

  /// Human-readable summary.
  public var summary: String {
    if allValid {
      return "All \(totalCount) fields valid"
    }
    return "\(invalidCount) of \(totalCount) fields invalid"
  }

  /// Invalid fields only.
  public var errors: [FieldValidationResult] {
    results.filter { !$0.isValid }
  }
}

// MARK: - Form Validator

/// Validates form fields against defined rules.
public struct FormValidator {

  /// Validate a single field value against a set of rules.
  public static func validate(
    fieldName: String,
    value: String,
    rules: [ValidationRule]
  ) -> [FieldValidationResult] {
    rules.map { rule in
      validateField(fieldName: fieldName, value: value, rule: rule)
    }
  }

  /// Validate multiple fields with their rules.
  public static func validateForm(
    fields: [(name: String, value: String, rules: [ValidationRule])]
  ) -> FormValidationReport {
    var results: [FieldValidationResult] = []

    for field in fields {
      let fieldResults = validate(fieldName: field.name, value: field.value, rules: field.rules)
      results.append(contentsOf: fieldResults)
    }

    let validCount = results.filter(\.isValid).count
    let invalidCount = results.filter { !$0.isValid }.count

    return FormValidationReport(
      results: results,
      validCount: validCount,
      invalidCount: invalidCount,
      totalCount: results.count
    )
  }

  // MARK: - Single Field Validation

  private static func validateField(
    fieldName: String,
    value: String,
    rule: ValidationRule
  ) -> FieldValidationResult {
    let isValid: Bool
    var message: String?

    switch rule {
    case .required:
      isValid = !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      if !isValid { message = "\(fieldName) is required" }

    case .email:
      let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
      isValid = value.range(of: emailRegex, options: .regularExpression) != nil
      if !isValid { message = "\(fieldName) must be a valid email address" }

    case .url:
      if let url = URL(string: value), let scheme = url.scheme, !scheme.isEmpty {
        isValid = ["http", "https", "ftp"].contains(scheme.lowercased())
      } else {
        isValid = false
      }
      if !isValid { message = "\(fieldName) must be a valid URL with http/https/ftp scheme" }

    case .phone:
      let phoneRegex = "^[+]?[\\d\\s\\-()]{7,}$"
      isValid = value.range(of: phoneRegex, options: .regularExpression) != nil
      if !isValid { message = "\(fieldName) must be a valid phone number" }

    case .numberRange(let min, let max):
      if let num = Double(value) {
        isValid = num >= min && num <= max
        if !isValid { message = "\(fieldName) must be between \(min) and \(max)" }
      } else {
        isValid = false
        message = "\(fieldName) must be a number"
      }

    case .pattern(let pattern):
      isValid = value.range(of: pattern, options: .regularExpression) != nil
      if !isValid { message = "\(fieldName) does not match the required pattern" }

    case .minLength(let n):
      isValid = value.count >= n
      if !isValid { message = "\(fieldName) must be at least \(n) characters" }

    case .maxLength(let n):
      isValid = value.count <= n
      if !isValid { message = "\(fieldName) must be at most \(n) characters" }

    case .oneOf(let values):
      isValid = values.contains(value)
      if !isValid { message = "\(fieldName) must be one of: \(values.joined(separator: ", "))" }
    }

    return FieldValidationResult(
      fieldName: fieldName, fieldValue: value,
      isValid: isValid, rule: rule, message: message
    )
  }
}
