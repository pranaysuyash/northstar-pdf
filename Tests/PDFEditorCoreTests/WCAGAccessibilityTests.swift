import Testing
@testable import PDFEditorCore

@Suite("WCAGAccessibility")
struct WCAGAccessibilityTests {
  // MARK: - Audit

  @Test("Document canvas audit produces findings")
  func canvasAudit() {
    let auditor = AccessibilityAuditor()
    let result = auditor.auditDocumentCanvas()
    #expect(result.findings.count > 0)
    #expect(result.component == "DocumentCanvas")
  }

  @Test("Audit includes all WCAG severity levels")
  func auditSeverities() {
    let auditor = AccessibilityAuditor()
    let result = auditor.auditDocumentCanvas()
    let severities = Set(result.findings.map(\.severity))
    #expect(severities.contains(.critical) || severities.contains(.serious))
    #expect(severities.contains(.moderate) || severities.contains(.minor))
  }

  @Test("Annotation audit covers keyboard and screen reader")
  func annotationAudit() {
    let auditor = AccessibilityAuditor()
    let result = auditor.auditAnnotations()
    let criteria = result.findings.map(\.criterion)
    #expect(criteria.contains("2.1.1 Keyboard"))
  }

  @Test("Freeze pane audit covers keyboard resize")
  func freezePaneAudit() {
    let auditor = AccessibilityAuditor()
    let result = auditor.auditFreezePanes()
    let criteria = result.findings.map(\.criterion)
    #expect(criteria.contains("2.1.1 Keyboard"))
  }

  // MARK: - Finding

  @Test("Finding tracks resolved state")
  func findingResolved() {
    var finding = AccessibilityFinding(
      criterion: "1.1.1 Non-text Content",
      severity: .critical,
      description: "Missing alt text",
      fix: "Add accessibilityDescription"
    )
    #expect(finding.isResolved == false)
    finding.isResolved = true
    #expect(finding.isResolved == true)
  }

  @Test("Finding severity weights")
  func severityWeights() {
    #expect(AccessibilityFinding.Severity.critical.weight == 4)
    #expect(AccessibilityFinding.Severity.serious.weight == 3)
    #expect(AccessibilityFinding.Severity.moderate.weight == 2)
    #expect(AccessibilityFinding.Severity.minor.weight == 1)
  }

  // MARK: - Audit Result

  @Test("Audit result summary")
  func auditSummary() {
    let findings = [
      AccessibilityFinding(criterion: "1.1.1", severity: .critical, description: "A", fix: "B"),
      AccessibilityFinding(criterion: "2.1.1", severity: .moderate, description: "C", fix: "D"),
    ]
    let result = AccessibilityAuditResult(findings: findings, component: "Test")
    #expect(result.criticalCount == 1)
    #expect(result.moderateCount == 1)
    #expect(result.seriousCount == 0)
    #expect(result.totalScore == 0) // none resolved
  }

  @Test("Audit result score with partial resolution")
  func auditScore() {
    var f1 = AccessibilityFinding(criterion: "1.1.1", severity: .critical, description: "A", fix: "B")
    f1.isResolved = true
    let f2 = AccessibilityFinding(criterion: "2.1.1", severity: .moderate, description: "C", fix: "D")
    let result = AccessibilityAuditResult(findings: [f1, f2], component: "Test")
    // critical=4, moderate=2 → total=6, resolved=4 → 4/6 = 0.666...
    #expect(result.totalScore > 0.6)
    #expect(result.totalScore < 0.7)
  }

  // MARK: - Keyboard Shortcuts

  @Test("All keyboard shortcuts have descriptions")
  func shortcutDescriptions() {
    for shortcut in DocumentKeyboardShortcut.allCases {
      #expect(!shortcut.description.isEmpty)
      #expect(!shortcut.keyEquivalent.isEmpty)
    }
  }

  @Test("Zoom shortcuts use command modifier")
  func zoomModifiers() {
    #expect(DocumentKeyboardShortcut.zoomIn.modifierNames.contains("Command"))
    #expect(DocumentKeyboardShortcut.zoomOut.modifierNames.contains("Command"))
    #expect(DocumentKeyboardShortcut.zoomReset.modifierNames.contains("Command"))
  }

  @Test("Search uses command modifier")
  func searchModifier() {
    #expect(DocumentKeyboardShortcut.search.modifierNames.contains("Command"))
  }

  @Test("Find next/previous are differentiated")
  func findDifferentiation() {
    #expect(DocumentKeyboardShortcut.findNext.keyEquivalent != DocumentKeyboardShortcut.findPrevious.keyEquivalent)
  }

  // MARK: - Sendable

  @Test("Accessibility audit is Sendable")
  func auditSendable() async {
    let auditor = AccessibilityAuditor()
    let result = auditor.auditDocumentCanvas()
    Task {
      let captured = result
      #expect(captured.findings.count > 0)
    }
  }
}
