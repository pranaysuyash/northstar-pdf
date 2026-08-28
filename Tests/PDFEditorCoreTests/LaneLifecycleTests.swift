import Foundation
import PDFEditorCore
import Testing

@Suite("Lane Lifecycle & Complexity Budget")
struct LaneLifecycleTests {

  // MARK: - Lane Lifecycle Tests

  @Test("Active lane used recently should not be deprecated")
  func activeLaneNotDeprecated() {
    let manager = LaneLifecycleManager()
    let record = LaneLifecycleRecord(
      lane: "native.choice",
      addedAt: Date(timeIntervalSince1970: 0),
      lastUsedAt: Date(), // Used today
      status: .active,
      sourceLines: 100,
      testLines: 50,
      publicTypes: 5
    )

    #expect(!manager.shouldDeprecate(record: record))
  }

  @Test("Active lane not used for 90+ days should be deprecated")
  func unusedLaneDeprecated() {
    let manager = LaneLifecycleManager()
    let ninetyDaysAgo = Calendar.current.date(byAdding: .day, value: -91, to: Date())!
    let record = LaneLifecycleRecord(
      lane: "xfa.forms",
      addedAt: Date(timeIntervalSince1970: 0),
      lastUsedAt: ninetyDaysAgo,
      status: .active,
      sourceLines: 200,
      testLines: 80,
      publicTypes: 10
    )

    #expect(manager.shouldDeprecate(record: record))
  }

  @Test("Deprecated lane 30+ days old should be removed")
  func deprecatedLaneRemoved() {
    let manager = LaneLifecycleManager()
    let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -31, to: Date())!
    let record = LaneLifecycleRecord(
      lane: "old.feature",
      addedAt: Date(timeIntervalSince1970: 0),
      lastUsedAt: Date(timeIntervalSince1970: 0),
      status: .deprecated,
      deprecationDate: thirtyDaysAgo,
      sourceLines: 100,
      testLines: 50,
      publicTypes: 5
    )

    #expect(manager.shouldRemove(record: record))
  }

  @Test("Lane never used should be deprecated")
  func neverUsedDeprecated() {
    let manager = LaneLifecycleManager()
    let record = LaneLifecycleRecord(
      lane: "never.used",
      addedAt: Date(timeIntervalSince1970: 0),
      lastUsedAt: nil, // Never used
      status: .active,
      sourceLines: 50,
      testLines: 20,
      publicTypes: 3
    )

    #expect(manager.shouldDeprecate(record: record))
  }

  @Test("Lifecycle report counts correctly")
  func lifecycleReport() {
    let manager = LaneLifecycleManager()
    let records = [
      LaneLifecycleRecord(lane: "active1", status: .active, sourceLines: 100, testLines: 50, publicTypes: 5),
      LaneLifecycleRecord(lane: "active2", status: .active, sourceLines: 200, testLines: 80, publicTypes: 10),
      LaneLifecycleRecord(lane: "deprecated1", status: .deprecated, sourceLines: 150, testLines: 60, publicTypes: 8),
      LaneLifecycleRecord(lane: "archived1", status: .archived, sourceLines: 80, testLines: 30, publicTypes: 4),
    ]

    let report = manager.report(records: records)

    #expect(report.activeLanes == 2)
    #expect(report.deprecatedLanes == 1)
    #expect(report.archivedLanes == 1)
    #expect(report.totalSourceLines == 530)
    #expect(report.totalTestLines == 220)
    #expect(report.totalPublicTypes == 27)
  }

  // MARK: - Complexity Budget Tests

  @Test("Feature within budget passes check")
  func featureWithinBudget() {
    let budget = ComplexityBudget(
      maxSourceLinesPerFeature: 2000,
      maxTestLinesPerFeature: 500,
      maxPublicTypesPerFeature: 30
    )

    let record = LaneLifecycleRecord(
      lane: "small.feature",
      sourceLines: 500,
      testLines: 100,
      publicTypes: 10
    )

    let violations = budget.checkFeature(record: record)
    #expect(violations.isEmpty)
  }

  @Test("Feature exceeding source lines budget produces violation")
  func featureExceedsSourceBudget() {
    let budget = ComplexityBudget(
      maxSourceLinesPerFeature: 1000,
      maxTestLinesPerFeature: 500,
      maxPublicTypesPerFeature: 30
    )

    let record = LaneLifecycleRecord(
      lane: "large.feature",
      sourceLines: 1500,
      testLines: 100,
      publicTypes: 10
    )

    let violations = budget.checkFeature(record: record)
    #expect(violations.count == 1)
    #expect(violations[0].kind == .sourceLinesExceeded)
    #expect(violations[0].actual == 1500)
    #expect(violations[0].limit == 1000)
  }

  @Test("Feature exceeding multiple budgets produces multiple violations")
  func featureExceedsMultipleBudgets() {
    let budget = ComplexityBudget(
      maxSourceLinesPerFeature: 500,
      maxTestLinesPerFeature: 100,
      maxPublicTypesPerFeature: 5
    )

    let record = LaneLifecycleRecord(
      lane: "massive.feature",
      sourceLines: 1000,
      testLines: 200,
      publicTypes: 15
    )

    let violations = budget.checkFeature(record: record)
    #expect(violations.count == 3)
  }

  @Test("Total codebase budget check")
  func totalBudgetCheck() {
    let budget = ComplexityBudget(
      totalSourceLinesBudget: 1000,
      totalTestLinesBudget: 200
    )

    let records = [
      LaneLifecycleRecord(lane: "a", sourceLines: 600, testLines: 150),
      LaneLifecycleRecord(lane: "b", sourceLines: 600, testLines: 100),
    ]

    let violations = budget.checkTotal(records: records)
    #expect(violations.count == 2) // Both source and test exceeded
  }

  @Test("Violation message is descriptive")
  func violationMessage() {
    let violation = ComplexityViolation(
      lane: "test.lane",
      kind: .sourceLinesExceeded,
      actual: 1500,
      limit: 1000
    )

    #expect(violation.message == "sourceLinesExceeded for test.lane: 1500 > 1000")
  }
}
