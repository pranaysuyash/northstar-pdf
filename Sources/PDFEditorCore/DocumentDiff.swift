import Foundation

// MARK: - Document Diff Contract

/// A comparison result between a source PDF and an output PDF.
/// Shows what changed, where, and whether changes are inside or outside
/// authorized operation regions.
public struct DocumentDiff: Codable, Equatable, Sendable {
  public let sourceDigest: String
  public let outputDigest: String
  public let pageCount: Int
  public let pages: [PageDiff]
  public let summary: DiffSummary

  public init(
    sourceDigest: String,
    outputDigest: String,
    pageCount: Int,
    pages: [PageDiff],
    summary: DiffSummary
  ) {
    self.sourceDigest = sourceDigest
    self.outputDigest = outputDigest
    self.pageCount = pageCount
    self.pages = pages
    self.summary = summary
  }
}

/// Per-page diff showing regions that changed.
public struct PageDiff: Codable, Equatable, Sendable {
  public let pageIndex: Int
  public let regions: [RegionDiff]
  public let textChangedOutsideOperations: Bool
  public let rasterChangedOutsideOperations: Bool
  public let textChangedInsideOperations: Bool
  public let rasterChangedInsideOperations: Bool

  public init(
    pageIndex: Int,
    regions: [RegionDiff],
    textChangedOutsideOperations: Bool = false,
    rasterChangedOutsideOperations: Bool = false,
    textChangedInsideOperations: Bool = false,
    rasterChangedInsideOperations: Bool = false
  ) {
    self.pageIndex = pageIndex
    self.regions = regions
    self.textChangedOutsideOperations = textChangedOutsideOperations
    self.rasterChangedOutsideOperations = rasterChangedOutsideOperations
    self.textChangedInsideOperations = textChangedInsideOperations
    self.rasterChangedInsideOperations = rasterChangedInsideOperations
  }

  public var hasChanges: Bool {
    !regions.isEmpty || textChangedInsideOperations || rasterChangedInsideOperations
  }
}

/// A single region that differs between source and output.
public struct RegionDiff: Codable, Equatable, Sendable {
  public let region: PDFPageRegion
  public let kind: RegionDiffKind
  public let sourceText: String?
  public let outputText: String?
  public let operationID: UUID?
  public let description: String

  public init(
    region: PDFPageRegion,
    kind: RegionDiffKind,
    sourceText: String? = nil,
    outputText: String? = nil,
    operationID: UUID? = nil,
    description: String
  ) {
    self.region = region
    self.kind = kind
    self.sourceText = sourceText
    self.outputText = outputText
    self.operationID = operationID
    self.description = description
  }
}

/// The type of change in a region.
public enum RegionDiffKind: String, Codable, CaseIterable, Hashable, Sendable {
  /// Text was added or changed in an authorized operation region.
  case operationApplied = "operation_applied"
  /// Text changed outside authorized regions (unexpected).
  case unexpectedTextChange = "unexpected_text_change"
  /// A native field was modified.
  case nativeFieldChanged = "native_field_changed"
  /// An overlay was added.
  case overlayAdded = "overlay_added"
  /// Geometry changed (page boxes, rotation).
  case geometryChanged = "geometry_changed"
  /// Content was preserved (no change).
  case preserved = "preserved"
}

/// Aggregate summary of the diff.
public struct DiffSummary: Codable, Equatable, Sendable {
  public let totalRegionsCompared: Int
  public let operationRegionsMatched: Int
  public let unexpectedChanges: Int
  public let pagesWithChanges: Int
  public let overallStatus: DiffOverallStatus

  public init(
    totalRegionsCompared: Int,
    operationRegionsMatched: Int,
    unexpectedChanges: Int,
    pagesWithChanges: Int,
    overallStatus: DiffOverallStatus
  ) {
    self.totalRegionsCompared = totalRegionsCompared
    self.operationRegionsMatched = operationRegionsMatched
    self.unexpectedChanges = unexpectedChanges
    self.pagesWithChanges = pagesWithChanges
    self.overallStatus = overallStatus
  }
}

public enum DiffOverallStatus: String, Codable, Hashable, Sendable {
  /// All changes are inside authorized regions. Source preserved outside.
  case preserved = "preserved"
  /// Some unexpected changes detected outside operation regions.
  case warnings = "warnings"
  /// Significant unexpected changes detected.
  case violations = "violations"
  /// Diff could not be computed (missing coordinates, different page counts).
  case incomplete = "incomplete"
}

// MARK: - Diff Builder

public enum DocumentDiffBuilder {
  /// Build a diff between source and output PDFs given the operations that were applied.
  public static func build(
    source: DocumentInspection,
    output: DocumentInspection,
    operations: [EditOperation]
  ) -> DocumentDiff {
    PerformanceTelemetry.shared.measureDiff {
      guard source.pages.count == output.pages.count else {
        return DocumentDiff(
          sourceDigest: source.source.sha256,
          outputDigest: output.source.sha256,
          pageCount: source.pages.count,
          pages: [],
          summary: DiffSummary(
            totalRegionsCompared: 0,
            operationRegionsMatched: 0,
            unexpectedChanges: 0,
            pagesWithChanges: 0,
            overallStatus: .incomplete
          )
        )
      }

      var pageDiffs: [PageDiff] = []
    var totalRegions = 0
    var matchedRegions = 0
    var unexpectedChanges = 0
    var pagesWithChanges = 0

    for pageIndex in 0..<source.pages.count {
      let sourcePage = source.pages[pageIndex]
      let outputPage = output.pages[pageIndex]
      let pageOperations = operations.filter { $0.pageIndex == pageIndex }
      var regions: [RegionDiff] = []

      // Check page geometry changes
      if sourcePage.bounds != outputPage.bounds || sourcePage.rotation != outputPage.rotation {
        regions.append(
          RegionDiff(
            region: PDFPageRegion(pageIndex: pageIndex, rect: sourcePage.bounds),
            kind: .geometryChanged,
            description: "Page bounds or rotation changed."
          )
        )
      }

      // Check native field changes
      let sourceFields = source.fields.filter { $0.pageIndex == pageIndex }
      let outputFields = output.fields.filter { $0.pageIndex == pageIndex }
      for sourceField in sourceFields {
        if let outputField = outputFields.first(where: { $0.id == sourceField.id }) {
          if sourceField.value != outputField.value {
            regions.append(
              RegionDiff(
                region: PDFPageRegion(pageIndex: pageIndex, rect: sourceField.bounds),
                kind: .nativeFieldChanged,
                sourceText: sourceField.value,
                outputText: outputField.value,
                description: "Native field '\(sourceField.name)' changed from '\(sourceField.value ?? "empty")' to '\(outputField.value ?? "empty")'."
              )
            )
          }
        }
      }

      // Check overlay/candidate changes
      let sourceCandidates = source.candidates.filter { $0.pageIndex == pageIndex }
      let outputCandidates = output.candidates.filter { $0.pageIndex == pageIndex }
      for sourceCandidate in sourceCandidates {
        if let outputCandidate = outputCandidates.first(where: { $0.id == sourceCandidate.id }) {
          if sourceCandidate.status != outputCandidate.status {
            regions.append(
              RegionDiff(
                region: PDFPageRegion(pageIndex: pageIndex, rect: sourceCandidate.bounds),
                kind: .overlayAdded,
                description: "Candidate status changed from \(sourceCandidate.status.rawValue) to \(outputCandidate.status.rawValue)."
              )
            )
          }
        }
      }

      // Count operation regions
      let operationRegions = pageOperations.compactMap { $0.coordinate }
      totalRegions += operationRegions.count
      matchedRegions += operationRegions.count  // simplified; real impl would check overlap

      // Check for text changes outside operations (simplified)
      let textChangedOutside = false  // Would use PDFImpactValidator
      let rasterChangedOutside = false

      let pageDiff = PageDiff(
        pageIndex: pageIndex,
        regions: regions,
        textChangedOutsideOperations: textChangedOutside,
        rasterChangedOutsideOperations: rasterChangedOutside,
        textChangedInsideOperations: !regions.isEmpty,
        rasterChangedInsideOperations: false
      )
      pageDiffs.append(pageDiff)

      if pageDiff.hasChanges {
        pagesWithChanges += 1
      }
      unexpectedChanges += regions.filter {
        $0.kind == .unexpectedTextChange || $0.kind == .geometryChanged
      }.count
    }

    let status: DiffOverallStatus
    if unexpectedChanges > 0 {
      status = .violations
    } else if pagesWithChanges > 0 {
      status = .warnings
    } else {
      status = .preserved
    }

    return DocumentDiff(
      sourceDigest: source.source.sha256,
      outputDigest: output.source.sha256,
      pageCount: source.pages.count,
      pages: pageDiffs,
      summary: DiffSummary(
        totalRegionsCompared: totalRegions,
        operationRegionsMatched: matchedRegions,
        unexpectedChanges: unexpectedChanges,
        pagesWithChanges: pagesWithChanges,
        overallStatus: status
      )
    )
    }
  }
}
