import Foundation
import PDFEditorCore
import Testing

/// Enrollment tests for the D-071/D-072/D-073 deferred surfaces (D-071
/// addendum 2026-09-07). Sensitivity: S1 — new behavior, passing on a
/// correct registry. The load-bearing property is structural: every
/// deferral the decisions claim must exist here with owner, decision ref,
/// trigger, and cost, or "retained under tracking" is an empty pointer.
@Suite("Deferred Surface Registry")
struct DeferredSurfaceRegistryTests {

  /// The deferral set named by D-071/D-072/D-073. The registry must cover
  /// at least this set; it may grow as new deferrals are enrolled.
  private let requiredIDs = [
    "split-view-surface", "metadata-inspector", "authoring-canvas",
    "comic-mode", "collaboration-cluster",
    "scripting-surface", "accepted-variance-registry", "shadow-multiengine",
    "ai-summarizer", "citation-tools", "content-router", "reading-analytics",
    "batch-read", "pdfua-tagging", "table-text-exporters",
    "work-coordinator-contracts", "profilestore-family",
    "incremental-form-writer", "browser-guard-cluster",
  ]

  @Test("Registry covers every deferral named by D-071, D-072, D-073")
  func coversNamedDeferrals() {
    let ids = Set(DeferredSurfaceRegistry.enrolled.map(\.id))
    for required in requiredIDs {
      #expect(ids.contains(required), "missing enrollment: \(required)")
    }
  }

  @Test("IDs are unique; every entry carries owner, decision, trigger, cost")
  func entriesAreComplete() {
    let enrolled = DeferredSurfaceRegistry.enrolled
    #expect(Set(enrolled.map(\.id)).count == enrolled.count, "duplicate lane ids")
    for surface in enrolled {
      #expect(!surface.title.isEmpty, "\(surface.id) needs a title")
      #expect(!surface.owner.isEmpty, "\(surface.id) needs an owner")
      #expect(["D-071", "D-072", "D-073"].contains(surface.decisionRef),
              "\(surface.id) must cite its deferring decision")
      #expect(!surface.revisitTrigger.isEmpty, "\(surface.id) needs a revisit trigger")
      #expect(!surface.sourceFiles.isEmpty, "\(surface.id) needs source files")
      #expect(surface.sourceLines > 0, "\(surface.id) needs measured cost")
    }
  }

  @Test("Lifecycle projection keeps deferral as active with an explicit clock start")
  func projectionIsActiveWithClockStart() {
    for surface in DeferredSurfaceRegistry.enrolled {
      let record = surface.lifecycleRecord()
      #expect(record.status == .active, "\(surface.id): deferral is execution sequence, not deprecation")
      #expect(record.lastUsedAt != nil, "\(surface.id): enrollment date must start the L10 clock")
    }
  }

  @Test("Total cost equals the sum of enrolled surfaces")
  func totalCostIsConsistent() {
    #expect(DeferredSurfaceRegistry.totalSourceLines
      == DeferredSurfaceRegistry.enrolled.reduce(0) { $0 + $1.sourceLines })
    // Tripwire: docs/decisions.md D-071 addendum cites this total. Update
    // both together when enrolling or retiring a surface.
    #expect(DeferredSurfaceRegistry.totalSourceLines == 9_552)
  }

  @Test("L10 report runs over the enrolled set without flagging fresh deferrals")
  func reportRunsCleanOnEnrollmentDate() {
    let report = DeferredSurfaceRegistry.report(now: DeferredSurfaceRegistry.enrollmentDate)
    #expect(report.lanesNeedingDeprecation.isEmpty,
            "freshly enrolled deferrals must not be immediately flaggable")
    #expect(report.activeLanes == DeferredSurfaceRegistry.enrolled.count)
  }

  @Test("L10 clock bites honestly: 91 days of silence flags every entry")
  func clockBitesAfterSilence() {
    let late = Calendar.current.date(byAdding: .day, value: 91,
                                     to: DeferredSurfaceRegistry.enrollmentDate)!
    let report = DeferredSurfaceRegistry.report(now: late)
    #expect(report.lanesNeedingDeprecation.count == DeferredSurfaceRegistry.enrolled.count,
            "unenforced deferral must surface as deprecation candidates, not rot silently")
  }
}
