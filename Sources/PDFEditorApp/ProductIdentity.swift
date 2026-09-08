import Foundation

/// User-facing identity for the native product. Technical target and executable
/// names remain PDFEditor until a separate migration is justified.
enum ProductIdentity {
    static let displayName = "Northstar"
    static let descriptor = "Local-first PDF workbench"
    static let bundleIdentifier = "com.northstar.pdf"
}
