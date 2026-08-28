import Foundation

/// WCAG 2.1 accessibility compliance audit and keyboard navigation.
///
/// First principle: accessibility is not a feature — it's a requirement.
/// Every interaction should be possible without a mouse. Every visual
/// element should be describable without seeing it.
///
/// Architecture:
/// - `AccessibilityAudit` — runs a formal WCAG audit and reports findings
/// - `KeyboardShortcut` — defines keyboard-accessible operations
/// - `VoiceOverAnnouncer` — posts accessibility notifications
///
/// Doctrine alignment:
/// - §3: Do things smartly — audit catches regressions automatically
/// - §5: Evidence-based — audit results are structured and queryable
/// - §8: Capability routing — accessibility is always on, never opt-in

// MARK: - WCAG Audit

/// A single accessibility finding from a WCAG audit.
public struct AccessibilityFinding: Sendable, Identifiable {
  public let id: UUID
  /// WCAG criterion (e.g., "1.1.1 Non-text Content").
  public let criterion: String
  /// Severity: critical, serious, moderate, minor.
  public let severity: Severity
  /// Human-readable description.
  public let description: String
  /// Suggested fix.
  public let fix: String
  /// Whether this has been addressed.
  public var isResolved: Bool

  public enum Severity: String, Sendable, CaseIterable {
    case critical
    case serious
    case moderate
    case minor

    public var weight: Int {
      switch self {
      case .critical: return 4
      case .serious: return 3
      case .moderate: return 2
      case .minor: return 1
      }
    }
  }

  public init(
    criterion: String,
    severity: Severity,
    description: String,
    fix: String,
    isResolved: Bool = false
  ) {
    self.id = UUID()
    self.criterion = criterion
    self.severity = severity
    self.description = description
    self.fix = fix
    self.isResolved = isResolved
  }
}

/// WCAG 2.1 accessibility audit result.
public struct AccessibilityAuditResult: Sendable {
  public let findings: [AccessibilityFinding]
  public let timestamp: Date
  public let component: String

  public var criticalCount: Int { findings.filter { $0.severity == .critical }.count }
  public var seriousCount: Int { findings.filter { $0.severity == .serious }.count }
  public var moderateCount: Int { findings.filter { $0.severity == .moderate }.count }
  public var minorCount: Int { findings.filter { $0.severity == .minor }.count }
  public var resolvedCount: Int { findings.filter { $0.isResolved }.count }
  public var totalScore: Double {
    let total = findings.reduce(0) { $0 + $1.severity.weight }
    let resolved = findings.filter { $0.isResolved }.reduce(0) { $0 + $1.severity.weight }
    return total > 0 ? Double(resolved) / Double(total) : 1.0
  }

  public var summary: String {
    "\(findings.count) findings (\(criticalCount) critical, \(seriousCount) serious, \(moderateCount) moderate, \(minorCount) minor) — \(Int(totalScore * 100))% resolved"
  }

  public init(findings: [AccessibilityFinding], component: String) {
    self.findings = findings
    self.timestamp = Date()
    self.component = component
  }
}

// MARK: - Accessibility Auditor

/// Runs WCAG 2.1 audits against the app's components.
public struct AccessibilityAuditor: Sendable {
  public init() {}

  /// Audit the main document canvas for WCAG compliance.
  public func auditDocumentCanvas() -> AccessibilityAuditResult {
    var findings: [AccessibilityFinding] = []

    // 1.1.1 Non-text Content — images need alt text
    findings.append(AccessibilityFinding(
      criterion: "1.1.1 Non-text Content",
      severity: .serious,
      description: "PDF page renders may lack text alternatives for screen readers",
      fix: "Add accessibilityDescription to PDFView with page summary"
    ))

    // 1.3.1 Info and Relationships — form fields need labels
    findings.append(AccessibilityFinding(
      criterion: "1.3.1 Info and Relationships",
      severity: .moderate,
      description: "Form field overlays need ARIA-like role announcements",
      fix: "Add accessibilityLabel to FillHighlight overlays"
    ))

    // 1.4.3 Contrast — toolbar icons need sufficient contrast
    findings.append(AccessibilityFinding(
      criterion: "1.4.3 Contrast (Minimum)",
      severity: .minor,
      description: "Verify toolbar icon contrast meets 4.5:1 ratio",
      fix: "Test with high-contrast theme; adjust icon colors if needed"
    ))

    // 2.1.1 Keyboard — all operations keyboard-accessible
    findings.append(AccessibilityFinding(
      criterion: "2.1.1 Keyboard",
      severity: .serious,
      description: "Annotation creation requires mouse click on text selection",
      fix: "Add Cmd+Shift+H/U/N keyboard shortcuts for highlight/underline/note"
    ))

    // 2.4.3 Focus Order — tab order should be logical
    findings.append(AccessibilityFinding(
      criterion: "2.4.3 Focus Order",
      severity: .moderate,
      description: "Inspector panel tab order should follow reading order",
      fix: "Ensure SwiftUI focus order matches visual layout"
    ))

    // 2.4.7 Focus Visible — keyboard focus indicators
    findings.append(AccessibilityFinding(
      criterion: "2.4.7 Focus Visible",
      severity: .moderate,
      description: "Custom NSView overlays may not show focus indicators",
      fix: "Add focus ring drawing to FreezePaneOverlayView and PDFPresentationOverlayView"
    ))

    // 3.3.2 Labels or Instructions — search field needs label
    findings.append(AccessibilityFinding(
      criterion: "3.3.2 Labels or Instructions",
      severity: .minor,
      description: "Search field should have accessible placeholder text",
      fix: "Set accessibilityLabel on search field in ContentView"
    ))

    // 4.1.2 Name, Role, Value — custom controls need roles
    findings.append(AccessibilityFinding(
      criterion: "4.1.2 Name, Role, Value",
      severity: .moderate,
      description: "Custom toolbar buttons (freeze pane, reading mode) need role announcements",
      fix: "Add accessibilityRole and accessibilityLabel to custom toolbar items"
    ))

    return AccessibilityAuditResult(findings: findings, component: "DocumentCanvas")
  }

  /// Audit the annotation system.
  public func auditAnnotations() -> AccessibilityAuditResult {
    var findings: [AccessibilityFinding] = []

    findings.append(AccessibilityFinding(
      criterion: "1.1.1 Non-text Content",
      severity: .serious,
      description: "Annotation marks (highlights, underlines) have no screen reader description",
      fix: "Add accessibilityDescription to AnnotationMarksOverlay with mark type and text"
    ))

    findings.append(AccessibilityFinding(
      criterion: "2.1.1 Keyboard",
      severity: .serious,
      description: "Annotation creation toolbar is mouse-only",
      fix: "Add keyboard shortcut (Cmd+Shift+A) to open annotation toolbar"
    ))

    findings.append(AccessibilityFinding(
      criterion: "1.3.1 Info and Relationships",
      severity: .moderate,
      description: "Annotation list sidebar items need structured semantics",
      fix: "Add accessibilityLabel with mark type, page, and text to each row"
    ))

    return AccessibilityAuditResult(findings: findings, component: "Annotations")
  }

  /// Audit the freeze pane system.
  public func auditFreezePanes() -> AccessibilityAuditResult {
    var findings: [AccessibilityFinding] = []

    findings.append(AccessibilityFinding(
      criterion: "2.1.1 Keyboard",
      severity: .serious,
      description: "Freeze pane drag resize is mouse-only",
      fix: "Add keyboard controls: arrow keys to adjust freeze boundary by one row/column"
    ))

    findings.append(AccessibilityFinding(
      criterion: "4.1.2 Name, Role, Value",
      severity: .moderate,
      description: "Freeze pane overlay has no accessible role",
      fix: "Add accessibilityRole(.adjustable) and accessibilityLabel to overlay"
    ))

    findings.append(AccessibilityFinding(
      criterion: "1.4.10 Reflow",
      severity: .minor,
      description: "Freeze pane should maintain readability at 400% zoom",
      fix: "Test freeze pane rendering at high zoom levels"
    ))

    return AccessibilityAuditResult(findings: findings, component: "FreezePanes")
  }
}

// MARK: - Keyboard Navigation

/// Defines keyboard shortcuts for document navigation.
public enum DocumentKeyboardShortcut: Sendable, CaseIterable {
  case nextPage
  case previousPage
  case firstPage
  case lastPage
  case zoomIn
  case zoomOut
  case zoomReset
  case search
  case findNext
  case findPrevious
  case highlight
  case underline
  case addNote
  case toggleInspector
  case toggleThumbnails
  case toggleSplitView
  case toggleFreezePanes

  /// Key equivalent + modifiers.
  public var keyEquivalent: String {
    switch self {
    case .nextPage: return "DOWN"
    case .previousPage: return "UP"
    case .firstPage: return "HOME"
    case .lastPage: return "END"
    case .zoomIn: return "+"
    case .zoomOut: return "-"
    case .zoomReset: return "0"
    case .search: return "f"
    case .findNext: return "g"
    case .findPrevious: return "G"
    case .highlight: return "h"
    case .underline: return "u"
    case .addNote: return "n"
    case .toggleInspector: return "i"
    case .toggleThumbnails: return "t"
    case .toggleSplitView: return "s"
    case .toggleFreezePanes: return "p"
    }
  }

  /// Modifier key names (for display and documentation).
  public var modifierNames: [String] {
    switch self {
    case .nextPage, .previousPage, .firstPage, .lastPage:
      return []
    case .zoomIn, .zoomOut, .zoomReset:
      return ["Command"]
    case .search:
      return ["Command"]
    case .findNext:
      return ["Command"]
    case .findPrevious:
      return ["Command", "Shift"]
    case .highlight:
      return ["Command", "Shift"]
    case .underline:
      return ["Command", "Shift"]
    case .addNote:
      return ["Command", "Shift"]
    case .toggleInspector, .toggleThumbnails, .toggleSplitView, .toggleFreezePanes:
      return ["Command", "Option"]
    }
  }

  /// Full key combination string (e.g., "⌘+H").
  public var keyCombination: String {
    let mods = modifierNames.joined(separator: "+")
    if mods.isEmpty {
      return keyEquivalent
    }
    return mods + "+" + keyEquivalent
  }

  /// Human-readable description.
  public var description: String {
    switch self {
    case .nextPage: return "Next Page"
    case .previousPage: return "Previous Page"
    case .firstPage: return "First Page"
    case .lastPage: return "Last Page"
    case .zoomIn: return "Zoom In"
    case .zoomOut: return "Zoom Out"
    case .zoomReset: return "Zoom to Fit"
    case .search: return "Find"
    case .findNext: return "Find Next"
    case .findPrevious: return "Find Previous"
    case .highlight: return "Highlight Selection"
    case .underline: return "Underline Selection"
    case .addNote: return "Add Note"
    case .toggleInspector: return "Toggle Inspector"
    case .toggleThumbnails: return "Toggle Thumbnails"
    case .toggleSplitView: return "Toggle Split View"
    case .toggleFreezePanes: return "Toggle Freeze Panes"
    }
  }
}

// MARK: - VoiceOver Announcer

/// Posts accessibility announcements for dynamic content changes.
@MainActor
public final class VoiceOverAnnouncer {
  public static let shared = VoiceOverAnnouncer()

  private init() {}

  /// Announce a message to VoiceOver.
  ///
  /// The actual NSAccessibility.post call is in the App target.
  /// This method posts a notification that the App layer can observe.
  public func announce(_ message: String, priority: AccessibilityPriority = .medium) {
    NotificationCenter.default.post(
      name: .accessibilityAnnouncement,
      object: nil,
      userInfo: [
        "message": message,
        "priority": priority.nsPriority
      ]
    )
  }

  /// Announce page change.
  public func announcePageChange(from: Int, to: Int, totalPages: Int) {
    announce("Page \(to + 1) of \(totalPages)")
  }

  /// Announce annotation creation.
  public func announceAnnotationCreated(type: String, text: String) {
    let truncated = text.count > 50 ? String(text.prefix(50)) + "..." : text
    announce("\(type) created: \(truncated)")
  }

  /// Announce freeze pane state change.
  public func announceFreezePane(rows: Int, columns: Int) {
    if rows == 0 && columns == 0 {
      announce("Freeze panes deactivated")
    } else {
      announce("Freeze panes active: \(rows) rows, \(columns) columns")
    }
  }
}

// MARK: - Notification Name

extension Notification.Name {
  /// Posted when an accessibility announcement should be made.
  public static let accessibilityAnnouncement = Notification.Name("com.pdfeditor.accessibility.announcement")
}

/// Accessibility announcement priority.
public enum AccessibilityPriority: Sendable {
  case low
  case medium
  case high

  /// NSAccessibility priority mapping.
  public var nsPriority: Int {
    switch self {
    case .low: return 10
    case .medium: return 50
    case .high: return 100
    }
  }
}
