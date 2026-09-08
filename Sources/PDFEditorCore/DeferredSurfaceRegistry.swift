import Foundation

// MARK: - Deferred surface enrollment (D-071 addendum, D-072, D-073)
//
// D-071 deferred complete-but-unwired surfaces "under Lane Lifecycle
// tracking" — but `LaneLifecycleManager` only consumes caller-supplied
// records, and no enrollment existed in-tree. An unenrolled deferral is
// invisible rot, not governance. This registry is the enrollment: one
// canonical record per deferred surface with owner, decision ref, revisit
// trigger, and measured cost. The 90-day L10 clock starts at the deferral
// decision date (2026-09-07), which counts as the lifecycle touch: a dated,
// reviewed decision is a use of the governance kind. Runtime exercise still
// counts separately — nothing here claims these surfaces are exercised.
//
// Doctrine alignment:
// - Canonical path: this file is the single enrollment source. Doc tables
//   elsewhere must cite it, not duplicate it.
// - Semantic salvage: enrollment preserves the surfaces with provenance
//   until wire/retire; deletion requires its own supersession record.
// - Truth taxonomy: `sourceLines` are measured file lengths at enrollment
//   (see tests); they are cost evidence, not quality claims.

// MARK: - Deferred surface

/// One deferred surface and the terms of its deferral.
public struct DeferredSurface: Hashable, Sendable, Codable {
  /// Stable lane id, e.g. "split-view-surface".
  public let id: String
  public let title: String
  /// Owning lane, e.g. "native", "core", "web".
  public let owner: String
  /// Decision that deferred it, e.g. "D-071".
  public let decisionRef: String
  /// The named condition that reopens the decision.
  public let revisitTrigger: String
  /// Source files constituting the surface, repo-relative.
  public let sourceFiles: [String]
  /// Measured total lines across `sourceFiles` at enrollment.
  public let sourceLines: Int
  /// The deferral decision date; doubles as the L10 clock start.
  public let enrolledAt: Date

  public init(
    id: String,
    title: String,
    owner: String,
    decisionRef: String,
    revisitTrigger: String,
    sourceFiles: [String],
    sourceLines: Int,
    enrolledAt: Date
  ) {
    self.id = id
    self.title = title
    self.owner = owner
    self.decisionRef = decisionRef
    self.revisitTrigger = revisitTrigger
    self.sourceFiles = sourceFiles
    self.sourceLines = sourceLines
    self.enrolledAt = enrolledAt
  }

  /// Projects this surface into the lifecycle machine. `lastUsedAt` is the
  /// enrollment date by construction (see file header): the deferral review
  /// is the recorded touch. Status stays `.active` — deferral is an
  /// execution-sequence state, not deprecation.
  public func lifecycleRecord() -> LaneLifecycleRecord {
    LaneLifecycleRecord(
      lane: id,
      addedAt: enrolledAt,
      lastUsedAt: enrolledAt,
      status: .active,
      sourceLines: sourceLines
    )
  }
}

// MARK: - Registry

public enum DeferredSurfaceRegistry {
  /// Deferral decision date: the L10 clock start for every entry.
  public static var enrollmentDate: Date {
    ISO8601DateFormatter().date(from: "2026-09-07T00:00:00Z")!
  }

  /// The complete enrolled set. Adding a deferral means adding an entry
  /// here with owner, decision ref, and trigger — never a bare doc note.
  public static var enrolled: [DeferredSurface] {
    let d = enrollmentDate
    return [
      DeferredSurface(
        id: "split-view-surface", title: "DocumentSplitView side-by-side surface",
        owner: "native", decisionRef: "D-071",
        revisitTrigger: "P4.3 compare-job design activates (wiring the raw surface first would pre-empt it)",
        sourceFiles: ["Sources/PDFEditorApp/DocumentSplitView.swift"], sourceLines: 241,
        enrolledAt: d
      ),
      DeferredSurface(
        id: "metadata-inspector", title: "MetadataInspectorView",
        owner: "native", decisionRef: "D-071",
        revisitTrigger: "Fonts/Statistics views actually wanted (inspector Reader tab covers current need)",
        sourceFiles: ["Sources/PDFEditorApp/MetadataInspectorView.swift"], sourceLines: 254,
        enrolledAt: d
      ),
      DeferredSurface(
        id: "authoring-canvas", title: "AuthoringCanvasView",
        owner: "native", decisionRef: "D-071",
        revisitTrigger: "CREATE archetype activation",
        sourceFiles: ["Sources/PDFEditorApp/AuthoringCanvasView.swift"], sourceLines: 598,
        enrolledAt: d
      ),
      DeferredSurface(
        id: "comic-mode", title: "ComicPanelZoomView + ComicMode",
        owner: "native", decisionRef: "D-071",
        revisitTrigger: "CREATE archetype activation",
        sourceFiles: ["Sources/PDFEditorApp/ComicPanelZoomView.swift", "Sources/PDFEditorCore/ComicMode.swift"],
        sourceLines: 563, enrolledAt: d
      ),
      DeferredSurface(
        id: "collaboration-cluster", title: "Collaboration views + Core cluster",
        owner: "native", decisionRef: "D-071",
        revisitTrigger: "Collaboration archetype activation",
        sourceFiles: [
          "Sources/PDFEditorApp/CollaborationDashboardView.swift",
          "Sources/PDFEditorApp/CollaborationHistoryView.swift",
          "Sources/PDFEditorApp/CollaborationMergeView.swift",
          "Sources/PDFEditorCore/CollaborationManager.swift",
          "Sources/PDFEditorCore/CollaborationApproval.swift",
          "Sources/PDFEditorCore/CollaborationHistory.swift",
          "Sources/PDFEditorCore/CollaborationPackage.swift",
        ], sourceLines: 2598, enrolledAt: d
      ),
      DeferredSurface(
        id: "scripting-surface", title: "ScriptingCLI + ScriptingSurface + UserScriptRunner",
        owner: "core", decisionRef: "D-073",
        revisitTrigger: "Agent-Desk spine work starts (D-078 agent loop is the first consumer candidate)",
        sourceFiles: [
          "Sources/PDFEditorCore/ScriptingCLI.swift",
          "Sources/PDFEditorCore/ScriptingSurface.swift",
          "Sources/PDFEditorCore/UserScriptRunner.swift",
        ], sourceLines: 1220, enrolledAt: d
      ),
      DeferredSurface(
        id: "accepted-variance-registry", title: "AcceptedVarianceRegistry (orphan gate)",
        owner: "core", decisionRef: "D-073",
        revisitTrigger: "Real review rounds produce accepted-variance data",
        sourceFiles: ["Sources/PDFEditorCore/AcceptedVarianceRegistry.swift"], sourceLines: 505,
        enrolledAt: d
      ),
      DeferredSurface(
        id: "shadow-multiengine", title: "ShadowMode + MultiEngineValidator (CI-evidence-only)",
        owner: "core", decisionRef: "D-073",
        revisitTrigger: "None pending: value is agreement measurement, not runtime routing. Revisit only if runtime multi-engine routing is proposed.",
        sourceFiles: ["Sources/PDFEditorCore/ShadowMode.swift", "Sources/PDFEditorCore/MultiEngineValidator.swift"],
        sourceLines: 348, enrolledAt: d
      ),
      DeferredSurface(
        id: "ai-summarizer", title: "AISummarizer (deterministic TF-IDF/TextRank)",
        owner: "core", decisionRef: "D-073",
        revisitTrigger: "Model-backed summary lane with its own quality harness",
        sourceFiles: ["Sources/PDFEditorCore/AISummarizer.swift"], sourceLines: 287,
        enrolledAt: d
      ),
      DeferredSurface(
        id: "citation-tools", title: "CitationTools",
        owner: "core", decisionRef: "D-073",
        revisitTrigger: "Export-citations consumer demands runtime use",
        sourceFiles: ["Sources/PDFEditorCore/CitationTools.swift"], sourceLines: 252,
        enrolledAt: d
      ),
      DeferredSurface(
        id: "content-router", title: "ContentRouter",
        owner: "core", decisionRef: "D-073",
        revisitTrigger: "A runtime routing consumer with an evidence gate",
        sourceFiles: ["Sources/PDFEditorCore/ContentRouter.swift"], sourceLines: 199,
        enrolledAt: d
      ),
      DeferredSurface(
        id: "reading-analytics", title: "ReadingAnalytics",
        owner: "core", decisionRef: "D-073",
        revisitTrigger: "Analytics consumer with a privacy review",
        sourceFiles: ["Sources/PDFEditorCore/ReadingAnalytics.swift"], sourceLines: 211,
        enrolledAt: d
      ),
      DeferredSurface(
        id: "batch-read", title: "BatchReadProcessor",
        owner: "core", decisionRef: "D-073",
        revisitTrigger: "Batch lane activation",
        sourceFiles: ["Sources/PDFEditorCore/BatchReadProcessor.swift"], sourceLines: 186,
        enrolledAt: d
      ),
      DeferredSurface(
        id: "pdfua-tagging", title: "PDFUATaggingEngine",
        owner: "core", decisionRef: "D-073",
        revisitTrigger: "PDF/UA authoring lane activation",
        sourceFiles: ["Sources/PDFEditorCore/PDFUATaggingEngine.swift"], sourceLines: 133,
        enrolledAt: d
      ),
      DeferredSurface(
        id: "table-text-exporters", title: "TableExporter + TextExporter",
        owner: "core", decisionRef: "D-073",
        revisitTrigger: "Export-citations consumer demands runtime use",
        sourceFiles: ["Sources/PDFEditorCore/TableExporter.swift", "Sources/PDFEditorCore/TextExporter.swift"],
        sourceLines: 351, enrolledAt: d
      ),
      DeferredSurface(
        id: "work-coordinator-contracts", title: "PDFWorkCoordinatorContracts (contract, no coordinator)",
        owner: "native", decisionRef: "D-073",
        revisitTrigger: "Agent-Desk spine work starts (D-078 agent loop is the first consumer candidate)",
        sourceFiles: ["Sources/PDFEditorApp/PDFWorkCoordinatorContracts.swift"], sourceLines: 84,
        enrolledAt: d
      ),
      DeferredSurface(
        id: "profilestore-family", title: "ProfileStore protocol family",
        owner: "core", decisionRef: "D-073",
        revisitTrigger: "A shipped surface adopts the protocols (zero App/Recovery consumers verified 2026-09-07)",
        sourceFiles: ["Sources/PDFEditorCore/ProfileStore.swift"], sourceLines: 859,
        enrolledAt: d
      ),
      DeferredSurface(
        id: "incremental-form-writer", title: "pdf-incremental-form-writer (contract/parity lane)",
        owner: "web", decisionRef: "D-072",
        revisitTrigger: "Not deferred-awaiting-wiring: active in its lane. Revisit only if the export path changes owner.",
        sourceFiles: ["web/pdf-incremental-form-writer.mjs"], sourceLines: 322,
        enrolledAt: d
      ),
      DeferredSurface(
        id: "browser-guard-cluster", title: "Browser guard modules (sanitize, action-neutralize, attachment-scanner, hidden-revision-analyzer)",
        owner: "web", decisionRef: "D-072",
        revisitTrigger: "Browser export-preflight rebuild (D-058 React cutover); not retrofitted into app.js",
        sourceFiles: [
          "web/pdf-sanitize.mjs", "web/pdf-action-neutralize.mjs",
          "web/pdf-attachment-scanner.mjs", "web/pdf-hidden-revision-analyzer.mjs",
        ], sourceLines: 341, enrolledAt: d
      ),
    ]
  }

  /// Total enrolled cost surface in source lines.
  public static var totalSourceLines: Int {
    enrolled.reduce(0) { $0 + $1.sourceLines }
  }

  /// Projection into the lifecycle machine.
  public static func lifecycleRecords() -> [LaneLifecycleRecord] {
    enrolled.map { $0.lifecycleRecord() }
  }

  /// L10 report over the enrolled set.
  public static func report(now: Date = Date()) -> LaneLifecycleReport {
    LaneLifecycleManager().report(records: lifecycleRecords(), now: now)
  }
}
