import Foundation
import PDFKit

/// Generates a standalone PDF report comparing the original and edited
/// document with color-coded annotations for changed regions.
///
/// Report structure per changed page:
/// - Header with page number and status
/// - Side-by-side rendering: original (left) vs edited (right)
/// - Color-coded rectangles overlaid on the edited rendering
/// - Footer with region count and operation details
///
/// Colors:
/// - Green: change inside an authorized operation region
/// - Red: change outside authorized regions (unexpected)
/// - Dashed green: preserved (unchanged) regions
public enum DocumentDiffReport {

  /// Errors that can occur during report generation.
  public enum ReportError: Error, LocalizedError, Equatable {
    case noDocument
    case noChanges
    case renderFailed(String)

    public var errorDescription: String? {
      switch self {
      case .noDocument:
        return "No document is available for diff report generation."
      case .noChanges:
        return "No changes detected. The diff report requires at least one page with changes."
      case .renderFailed(let message):
        return "Diff report generation failed: \(message)"
      }
    }
  }

  /// Generate a diff report PDF comparing source and output inspections.
  ///
  /// - Parameters:
  ///   - sourceDocument: The original PDF document (pre-edit).
  ///   - currentDocument: The edited PDF document.
  ///   - diff: The computed document diff.
  ///   - operations: The operations that were applied.
  /// - Returns: Data containing the generated PDF report.
  public static func generate(
    sourceDocument: PDFDocument,
    currentDocument: PDFDocument,
    diff: DocumentDiff,
    operations: [EditOperation]
  ) throws -> Data {
    let changedPages = diff.pages.filter { $0.hasChanges }
    guard !changedPages.isEmpty else {
      throw ReportError.noChanges
    }

    let report = PDFDocument()
    let pageWidth: CGFloat = 1224  // 17" landscape at 72 dpi
    let pageHeight: CGFloat = 792  // 11"
    let margin: CGFloat = 36

    // --- Cover page ---
    let coverPage = PDFPage()
    report.insert(coverPage, at: 0)
    guard let coverContext = createPDFContext(page: coverPage, width: pageWidth, height: pageHeight) else {
      throw ReportError.renderFailed("Could not create PDF context for cover page.")
    }
    drawCoverPage(
      context: coverContext,
      diff: diff,
      operations: operations,
      pageWidth: pageWidth,
      pageHeight: pageHeight,
      margin: margin
    )
    coverPage.setBounds(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight), for: .mediaBox)

    // --- Diff pages ---
    var insertIndex = 1
    for pageDiff in changedPages {
      let originalPage = sourceDocument.page(at: pageDiff.pageIndex)
      let editedPage = currentDocument.page(at: pageDiff.pageIndex)

      let diffPage = PDFPage()
      report.insert(diffPage, at: insertIndex)
      guard let context = createPDFContext(page: diffPage, width: pageWidth, height: pageHeight) else {
        continue
      }

      drawDiffPage(
        context: context,
        pageDiff: pageDiff,
        originalPage: originalPage,
        editedPage: editedPage,
        pageWidth: pageWidth,
        pageHeight: pageHeight,
        margin: margin
      )

      diffPage.setBounds(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight), for: .mediaBox)
      insertIndex += 1
    }

    guard let data = report.dataRepresentation() else {
      throw ReportError.renderFailed("Could not serialize the report PDF.")
    }
    return data
  }

  // MARK: - Private Drawing

  private static func createPDFContext(
    page: PDFPage, width: CGFloat, height: CGFloat
  ) -> CGContext? {
    // PDFKit draws into a flipped context for page rendering.
    // We use UIGraphicsPDFRenderer-style direct PDF context creation.
    var mediaBox = CGRect(x: 0, y: 0, width: width, height: height)
    guard let consumer = CGDataConsumer(data: NSMutableData() as CFMutableData) else { return nil }
    let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
    return context
  }

  // MARK: - Cover Page

  private static func drawCoverPage(
    context: CGContext,
    diff: DocumentDiff,
    operations: [EditOperation],
    pageWidth: CGFloat,
    pageHeight: CGFloat,
    margin: CGFloat
  ) {
    context.saveGState()

    // Background
    context.setFillColor(CGColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

    // Title
    let titleAttrs: [NSAttributedString.Key: Any] = [
      .font: NSFont.boldSystemFont(ofSize: 28),
      .foregroundColor: NSColor.labelColor,
    ]
    let title = "Visual Diff Report" as NSString
    title.draw(at: CGPoint(x: margin, y: pageHeight - margin - 40), withAttributes: titleAttrs)

    // Subtitle
    let subtitleAttrs: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 14),
      .foregroundColor: NSColor.secondaryLabelColor,
    ]
    let subtitle = "Original vs Filled Document Comparison" as NSString
    subtitle.draw(at: CGPoint(x: margin, y: pageHeight - margin - 65), withAttributes: subtitleAttrs)

    // Summary box
    let summaryY = pageHeight - margin - 120
    let summaryRect = CGRect(x: margin, y: summaryY, width: pageWidth - 2 * margin, height: 200)
    context.setStrokeColor(CGColor(red: 0.85, green: 0.85, blue: 0.87, alpha: 1))
    context.setLineWidth(1)
    context.stroke(summaryRect)

    let statusColor: NSColor
    switch diff.summary.overallStatus {
    case .preserved: statusColor = .systemGreen
    case .warnings: statusColor = .systemOrange
    case .violations: statusColor = .systemRed
    case .incomplete: statusColor = .secondaryLabelColor
    }

    let statusAttrs: [NSAttributedString.Key: Any] = [
      .font: NSFont.boldSystemFont(ofSize: 18),
      .foregroundColor: statusColor,
    ]
    let statusText: String
    switch diff.summary.overallStatus {
    case .preserved: statusText = "✓ All changes inside authorized regions"
    case .warnings: statusText = "⚠ Some unexpected changes detected"
    case .violations: statusText = "✗ Unexpected changes outside operation regions"
    case .incomplete: statusText = "? Diff could not be fully computed"
    }
    (statusText as NSString).draw(at: CGPoint(x: margin + 12, y: summaryY + 160), withAttributes: statusAttrs)

    let detailAttrs: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 13),
      .foregroundColor: NSColor.labelColor,
    ]

    let details = [
      "Pages with changes: \(diff.summary.pagesWithChanges)",
      "Total regions compared: \(diff.summary.totalRegionsCompared)",
      "Operation regions matched: \(diff.summary.operationRegionsMatched)",
      "Unexpected changes: \(diff.summary.unexpectedChanges)",
      "Operations applied: \(operations.count)",
    ]
    var detailY = summaryY + 135
    for detail in details {
      (detail as NSString).draw(at: CGPoint(x: margin + 20, y: detailY), withAttributes: detailAttrs)
      detailY -= 20
    }

    // Legend
    let legendY = summaryY - 60
    drawLegend(
      context: context,
      origin: CGPoint(x: margin + 12, y: legendY),
      detailAttrs: detailAttrs
    )

    // Footer
    let footerAttrs: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 10),
      .foregroundColor: NSColor.tertiaryLabelColor,
    ]
    let formatter = ISO8601DateFormatter()
    let dateStr = formatter.string(from: Date())
    let footer = "Generated by PDF Editor · \(dateStr) · \(diff.sourceDigest.prefix(16))..." as NSString
    footer.draw(at: CGPoint(x: margin, y: margin), withAttributes: footerAttrs)

    context.restoreGState()
  }

  // MARK: - Diff Page

  private static func drawDiffPage(
    context: CGContext,
    pageDiff: PageDiff,
    originalPage: PDFPage?,
    editedPage: PDFPage?,
    pageWidth: CGFloat,
    pageHeight: CGFloat,
    margin: CGFloat
  ) {
    context.saveGState()

    // Background
    context.setFillColor(CGColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

    // Header
    let headerAttrs: [NSAttributedString.Key: Any] = [
      .font: NSFont.boldSystemFont(ofSize: 16),
      .foregroundColor: NSColor.labelColor,
    ]
    let pageLabel = "Page \(pageDiff.pageIndex + 1)" as NSString
    pageLabel.draw(at: CGPoint(x: margin, y: pageHeight - margin - 25), withAttributes: headerAttrs)

    // Status badge
    let statusAttrs: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 12),
      .foregroundColor: pageDiff.textChangedOutsideOperations || pageDiff.rasterChangedOutsideOperations
        ? NSColor.systemRed : NSColor.systemGreen,
    ]
    let changeCount = pageDiff.regions.count
    let statusLabel = "\(changeCount) region(s) changed" as NSString
    statusLabel.draw(at: CGPoint(x: margin + 100, y: pageHeight - margin - 23), withAttributes: statusAttrs)

    // Side-by-side rendering area
    let renderY: CGFloat = margin
    let renderHeight = pageHeight - margin - 50
    let halfWidth = (pageWidth - 3 * margin) / 2

    // Original panel
    let originalRect = CGRect(x: margin, y: renderY, width: halfWidth, height: renderHeight)
    drawRenderedPage(
      context: context,
      page: originalPage,
      in: originalRect,
      label: "Original",
      borderColor: CGColor(red: 0.85, green: 0.85, blue: 0.87, alpha: 1)
    )

    // Edited panel
    let editedRect = CGRect(
      x: margin + halfWidth + margin,
      y: renderY,
      width: halfWidth,
      height: renderHeight
    )
    drawRenderedPage(
      context: context,
      page: editedPage,
      in: editedRect,
      label: "Edited",
      borderColor: CGColor(red: 0.85, green: 0.85, blue: 0.87, alpha: 1)
    )

    // Draw diff regions on the edited panel
    drawDiffRegions(
      context: context,
      regions: pageDiff.regions,
      in: editedRect,
      pageIndex: pageDiff.pageIndex
    )

    // Footer
    let footerAttrs: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 9),
      .foregroundColor: NSColor.tertiaryLabelColor,
    ]
    let regionSummary = pageDiff.regions.map { $0.kind.rawValue }.joined(separator: ", ") as NSString
    regionSummary.draw(at: CGPoint(x: margin, y: margin - 14), withAttributes: footerAttrs)

    context.restoreGState()
  }

  // MARK: - Page Rendering

  private static func drawRenderedPage(
    context: CGContext,
    page: PDFPage?,
    in rect: CGRect,
    label: String,
    borderColor: CGColor
  ) {
    // Border
    context.setStrokeColor(borderColor)
    context.setLineWidth(1)
    context.stroke(rect)

    // Label
    let labelAttrs: [NSAttributedString.Key: Any] = [
      .font: NSFont.boldSystemFont(ofSize: 10),
      .foregroundColor: NSColor.secondaryLabelColor,
    ]
    (label as NSString).draw(at: CGPoint(x: rect.minX + 4, y: rect.maxY - 14), withAttributes: labelAttrs)

    guard let page else {
      let noPageAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 11),
        .foregroundColor: NSColor.tertiaryLabelColor,
      ]
      ("Page unavailable" as NSString).draw(
        at: CGPoint(x: rect.midX - 40, y: rect.midY - 6),
        withAttributes: noPageAttrs
      )
      return
    }

    // Render the page into the available area
    let pageBounds = page.bounds(for: .cropBox)
    let availWidth = rect.width - 8
    let availHeight = rect.height - 24
    let scaleX = availWidth / max(pageBounds.width, 1)
    let scaleY = availHeight / max(pageBounds.height, 1)
    let scale = min(scaleX, scaleY)

    let drawWidth = pageBounds.width * scale
    let drawHeight = pageBounds.height * scale
    let offsetX = rect.minX + (availWidth - drawWidth) / 2 + 4
    let offsetY = rect.minY + (availHeight - drawHeight) / 2

    context.saveGState()
    context.translateBy(x: offsetX, y: offsetY + drawHeight)
    context.scaleBy(x: scale, y: scale)
    page.draw(with: .cropBox, to: context)
    context.restoreGState()
  }

  // MARK: - Diff Region Drawing

  private static func drawDiffRegions(
    context: CGContext,
    regions: [RegionDiff],
    in rect: CGRect,
    pageIndex: Int
  ) {
    // We need the page bounds to convert PDF coordinates to view coordinates.
    // Use a standard letter page as fallback.
    let pageW: CGFloat = 612
    let pageH: CGFloat = 792
    let availWidth = rect.width - 8
    let availHeight = rect.height - 24
    let scaleX = availWidth / max(pageW, 1)
    let scaleY = availHeight / max(pageH, 1)
    let scale = min(scaleX, scaleY)
    let offsetX = rect.minX + (availWidth - pageW * scale) / 2 + 4
    let offsetY = rect.minY + (availHeight - pageH * scale) / 2

    for region in regions where region.region.pageIndex == pageIndex {
      let pdfRect = region.region.rect
      let x = pdfRect.x * scale + offsetX
      let y = (pageH - (pdfRect.y + pdfRect.height)) * scale + offsetY
      let w = pdfRect.width * scale
      let h = pdfRect.height * scale
      let viewRect = CGRect(x: x, y: y, width: w, height: h)

      switch region.kind {
      case .unexpectedTextChange, .geometryChanged:
        // Red: outside authorized region
        context.setFillColor(CGColor(red: 1, green: 0.27, blue: 0.27, alpha: 0.18))
        context.fill(viewRect)
        context.setStrokeColor(CGColor(red: 0.94, green: 0.27, blue: 0.27, alpha: 0.8))
        context.setLineWidth(2.5)
        context.stroke(viewRect)

      case .operationApplied, .nativeFieldChanged, .overlayAdded:
        // Green: inside authorized region
        context.setFillColor(CGColor(red: 0.13, green: 0.77, blue: 0.37, alpha: 0.14))
        context.fill(viewRect)
        context.setStrokeColor(CGColor(red: 0.13, green: 0.77, blue: 0.37, alpha: 0.8))
        context.setLineWidth(1.5)
        context.stroke(viewRect)

      case .preserved:
        // Dashed green outline
        context.setStrokeColor(CGColor(red: 0.13, green: 0.77, blue: 0.37, alpha: 0.5))
        context.setLineWidth(1)
        context.setLineDash(phase: 0, lengths: [4, 3])
        context.stroke(viewRect)
        context.setLineDash(phase: 0, lengths: [])
      }

      // Label for the region
      if w > 40 && h > 12 {
        let labelAttrs: [NSAttributedString.Key: Any] = [
          .font: NSFont.systemFont(ofSize: 7),
          .foregroundColor: NSColor.secondaryLabelColor,
        ]
        let kindLabel: String
        switch region.kind {
        case .unexpectedTextChange: kindLabel = "⚠ Outside"
        case .geometryChanged: kindLabel = "⚠ Geometry"
        case .operationApplied: kindLabel = "✓ Operation"
        case .nativeFieldChanged: kindLabel = "✓ Field"
        case .overlayAdded: kindLabel = "✓ Overlay"
        case .preserved: kindLabel = "✓ Preserved"
        }
        (kindLabel as NSString).draw(
          at: CGPoint(x: x + 2, y: y + h - 9),
          withAttributes: labelAttrs
        )
      }
    }
  }

  // MARK: - Legend

  private static func drawLegend(
    context: CGContext,
    origin: CGPoint,
    detailAttrs: [NSAttributedString.Key: Any]
  ) {
    let items: [(String, CGColor, Bool)] = [
      ("Inside operation region", CGColor(red: 0.13, green: 0.77, blue: 0.37, alpha: 0.8), false),
      ("Outside operation region", CGColor(red: 0.94, green: 0.27, blue: 0.27, alpha: 0.8), false),
      ("Preserved region", CGColor(red: 0.13, green: 0.77, blue: 0.37, alpha: 0.5), true),
    ]

    var x = origin.x
    let boxSize: CGFloat = 12
    let spacing: CGFloat = 16

    for (label, color, dashed) in items {
      // Color swatch
      context.setFillColor(color)
      let box = CGRect(x: x, y: origin.y, width: boxSize, height: boxSize)
      context.fill(box)

      if dashed {
        context.setStrokeColor(color)
        context.setLineWidth(1.5)
        context.setLineDash(phase: 0, lengths: [3, 2])
        context.stroke(box)
        context.setLineDash(phase: 0, lengths: [])
      }

      // Label
      (label as NSString).draw(
        at: CGPoint(x: x + boxSize + 4, y: origin.y),
        withAttributes: detailAttrs
      )
      x += boxSize + 4 + (label as NSString).size(withAttributes: detailAttrs).width + spacing
    }
  }
}
