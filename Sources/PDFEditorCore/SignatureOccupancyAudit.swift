import CoreGraphics
import Foundation
import PDFKit

/// Review-only evidence about expected signer slots on a page.
///
/// Salvaged from the Fieldroom reference pipeline
/// (docs/research/form-field-lab-salvage-assessment-2026-09-21.md, Medpiper
/// lesson): existing ink is *document evidence*, while an editable signature
/// target is a separate action the user chooses. Observations never become
/// fields, never enter the fill pipeline, and never auto-accept — a missing
/// signature is surfaced as an actionable audit finding instead.
public struct SignatureObservation: Equatable, Identifiable, Sendable {
  public enum Status: String, Sendable {
    case present
    case missing
    case uncertain
  }

  public let id: String
  public let pageIndex: Int
  public let signer: String?
  public let role: String
  public let bounds: PDFRect
  public let status: Status
  public let confidence: Double
  public let evidence: [String]

  public init(
    id: String,
    pageIndex: Int,
    signer: String?,
    role: String,
    bounds: PDFRect,
    status: Status,
    confidence: Double,
    evidence: [String]
  ) {
    self.id = id
    self.pageIndex = pageIndex
    self.signer = signer
    self.role = role
    self.bounds = bounds
    self.status = status
    self.confidence = confidence
    self.evidence = evidence
  }
}

/// An expected signer slot localized from printed role text.
///
/// All bounds use PDF page space (origin bottom-left), matching
/// `TextLineEvidence`.
public struct SignatureSlot: Equatable, Sendable {
  public let pageIndex: Int
  public let role: String
  public let signer: String?
  public let bounds: PDFRect

  public init(pageIndex: Int, role: String, signer: String?, bounds: PDFRect) {
    self.pageIndex = pageIndex
    self.role = role
    self.signer = signer
    self.bounds = bounds
  }
}

/// Conservative, review-only signature-slot occupancy audit.
///
/// Printed role text in the lower page band is the expected-slot anchor; ink
/// inside the bounded slot is occupancy evidence. Like the reference lane, a
/// page must show a multi-signer block (two or more role lines) before any
/// slot is proposed — single signature lines abstain rather than risk
/// promoting ordinary page furniture. A financial-statement page therefore
/// produces zero observations (the Medpiper hard-negative lesson) while a
/// genuine signing block yields one observation per role.
public enum SignatureOccupancyAudit {
  /// Words that mark a signer role line. Matched as whole tokens only.
  public static let roleWords: Set<String> = [
    "partner", "director", "trustee", "proprietor", "secretary", "chairperson",
    "authorized", "authorised", "signatory", "accountant", "deponent", "witness",
  ]

  /// Slot geometry, in points, mirroring the reference lane's calibrated
  /// extents: a 105pt-wide, 38pt-tall writable band above the role line.
  private static let slotWidth: Double = 105
  private static let slotHeight: Double = 38
  private static let slotXInset: Double = 5
  /// PDFKit selection bounds carry ~2.5pt of padding per edge, so the
  /// reference lane's 18pt printed-name gap widens to 22pt here.
  private static let signerSearchGap: Double = 22
  private static let signerMaxOffset: Double = 105

  /// Ink thresholds over the rendered slot crop, ported from the reference
  /// lane's calibrated values: near-empty crops read as missing, visible ink
  /// as present, and the narrow band between as uncertain.
  static let presentDarkRatio: Double = 0.003
  static let missingDarkRatio: Double = 0.0005

  /// Pure slot detection from text-line evidence. `pageHeights` maps page
  /// index to page height in points; `pageWidths` clamps slot extents.
  /// Slots only anchor in the lower 45% of a page, and a page needs at least
  /// two role lines before any slot exists.
  public static func roleSlots(
    lines: [TextLineEvidence],
    pageHeights: [Int: Double],
    pageWidths: [Int: Double] = [:]
  ) -> [SignatureSlot] {
    var slotsByPage: [Int: [SignatureSlot]] = [:]
    for line in lines
    where line.bounds.width > 0 && line.bounds.height > 0
      && roleWords.contains(roleToken(in: line.text))
    {
      guard let pageHeight = pageHeights[line.pageIndex],
        line.bounds.y <= pageHeight * 0.45
      else { continue }

      let role = roleToken(in: line.text).capitalized
      let signer = signerLine(above: line, candidates: lines)
      let bandTop = max(signer.map { $0.bounds.y + $0.bounds.height } ?? line.bounds.y + line.bounds.height, line.bounds.y + line.bounds.height)
      let slot = PDFRect(
        x: max(0, line.bounds.x - slotXInset),
        y: bandTop + 2,
        width: min(slotWidth, pageWidths[line.pageIndex] ?? slotWidth),
        height: slotHeight
      )
      slotsByPage[line.pageIndex, default: []].append(
        SignatureSlot(pageIndex: line.pageIndex, role: role, signer: signer?.text, bounds: slot)
      )
    }

    var result: [SignatureSlot] = []
    for pageIndex in slotsByPage.keys.sorted() {
      guard let pageSlots = slotsByPage[pageIndex], pageSlots.count >= 2 else { continue }
      result.append(contentsOf: pageSlots)
    }
    return result
  }

  /// Pure occupancy classification from a dark-pixel ratio (0…1) of the
  /// rendered slot crop.
  public static func classify(darkRatio: Double) -> (
    status: SignatureObservation.Status, confidence: Double, detail: String
  ) {
    if darkRatio >= presentDarkRatio {
      let confidence = min(0.86, 0.58 + darkRatio * 2.0)
      return (
        .present,
        confidence,
        String(format: "expected signer slot contains raster ink; dark-pixel ratio=%.4f", darkRatio)
      )
    }
    if darkRatio <= missingDarkRatio {
      return (.missing, 0.93, "printed signer slot is empty in the rendered page")
    }
    return (
      .uncertain,
      0.55,
      String(format: "slot occupancy is ambiguous; dark-pixel ratio=%.4f", darkRatio)
    )
  }

  /// Full audit: localize slots per page, render each page, and classify ink
  /// occupancy. Returns observations in page order; pages without a
  /// multi-signer block contribute none. `pageLimit` bounds the raster work
  /// (the reference lane's resource-budget lesson).
  public static func observations(
    in document: PDFDocument,
    dpi: Int = 144,
    pageLimit: Int = .max
  ) -> [SignatureObservation] {
    var result: [SignatureObservation] = []
    let scale = CGFloat(max(72, min(300, dpi))) / 72.0
    // Rendering goes through CoreGraphics (deterministic page-space mapping);
    // PDFKit is used only for text lines and selection geometry.
    let cgDocument: CGPDFDocument? = document.dataRepresentation()
      .flatMap { CGDataProvider(data: $0 as CFData) }
      .flatMap { CGPDFDocument($0) }
    for pageIndex in 0..<min(document.pageCount, max(0, pageLimit)) {
      guard let page = document.page(at: pageIndex) else { continue }
      let pageBounds = page.bounds(for: .mediaBox)
      let lines = textLines(for: page, pageIndex: pageIndex)
      let slots = roleSlots(
        lines: lines,
        pageHeights: [pageIndex: Double(pageBounds.height)],
        pageWidths: [pageIndex: Double(pageBounds.width)]
      )
      guard !slots.isEmpty else { continue }
      guard let cgPage = cgDocument?.page(at: pageIndex + 1),
        let raster = renderGray(cgPage: cgPage, pageBounds: pageBounds, scale: scale)
      else { continue }

      for (index, slot) in slots.enumerated() {
        let ratio = darkRatio(slot: slot.bounds, raster: raster, scale: scale)
        let verdict = classify(darkRatio: ratio)
        result.append(
          SignatureObservation(
            id: String(format: "signature-%d-%02d", pageIndex + 1, index + 1),
            pageIndex: pageIndex,
            signer: slot.signer,
            role: slot.role,
            bounds: slot.bounds,
            status: verdict.status,
            confidence: verdict.confidence,
            evidence: [verdict.detail]
          )
        )
      }
    }
    return result
  }

  // MARK: - Internals

  /// The role word if this line contains exactly one role token, else nil.
  private static func roleToken(in text: String) -> String {
    let words = Set(
      text.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init))
    let matches = words.intersection(roleWords)
    guard matches.count == 1, let role = matches.first else { return "" }
    return role
  }

  /// Closest line above the role line whose geometry matches the reference
  /// lane's printed-name association: the line ends within an 18pt gap above
  /// the role line's top edge, inside the role line's ±105pt horizontal
  /// corridor. Page space is bottom-origin.
  private static func signerLine(
    above roleLine: TextLineEvidence,
    candidates: [TextLineEvidence]
  ) -> TextLineEvidence? {
    let roleTop = roleLine.bounds.y + roleLine.bounds.height
    return candidates
      .filter { line in
        line.pageIndex == roleLine.pageIndex
          && line.bounds.y >= roleTop - 1.5
          && line.bounds.y - roleTop <= signerSearchGap
          && line.bounds.x >= roleLine.bounds.x - 7
          && line.bounds.x <= roleLine.bounds.x + signerMaxOffset
          && !line.text.trimmingCharacters(in: .whitespaces).isEmpty
      }
      .min { lhs, rhs in
        let lhsGap = lhs.bounds.y - roleTop
        let rhsGap = rhs.bounds.y - roleTop
        return lhsGap < rhsGap
      }
  }

  /// Text lines for one page via PDFKit selection geometry, with a plain
  /// newline fallback whose bounds are explicitly approximate.
  static func textLines(for page: PDFPage, pageIndex: Int) -> [TextLineEvidence] {
    var lines: [TextLineEvidence] = []
    if let bounds = page.selection(for: page.bounds(for: .mediaBox)) {
      for line in bounds.selectionsByLine() {
        guard let text = line.string?.trimmingCharacters(in: .whitespacesAndNewlines),
          !text.isEmpty
        else { continue }
        lines.append(
          TextLineEvidence(
            pageIndex: pageIndex,
            text: text,
            bounds: PDFRect(line.bounds(for: page))
          ))
      }
    } else if let pageString = page.string {
      for text in pageString.components(separatedBy: .newlines) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { continue }
        lines.append(
          TextLineEvidence(
            pageIndex: pageIndex,
            text: trimmed,
            bounds: PDFRect(x: 0, y: 0, width: 0, height: 0)
          ))
      }
    }
    return lines
  }

  /// Rasterize one page into an 8-bit grayscale buffer (0 = black) with
  /// bottom-up rows matching PDF page space: buffer row 0 is the bottom of
  /// the page. Drawing stays inside `withUnsafeMutableBytes` so the context
  /// never outlives the buffer.
  static func renderGray(
    cgPage: CGPDFPage,
    pageBounds: CGRect,
    scale: CGFloat
  ) -> (bytes: [UInt8], width: Int, height: Int)? {
    let width = max(1, Int(pageBounds.width * scale))
    let height = max(1, Int(pageBounds.height * scale))
    var bytes = [UInt8](repeating: 255, count: width * height)
    let drew = bytes.withUnsafeMutableBytes { raw -> Bool in
      guard let rawBase = raw.baseAddress,
        let context = CGContext(
          data: rawBase,
          width: width,
          height: height,
          bitsPerComponent: 8,
          bytesPerRow: width,
          space: CGColorSpaceCreateDeviceGray(),
          bitmapInfo: CGImageAlphaInfo.none.rawValue
        )
      else { return false }
      context.setFillColor(CGColor(gray: 1.0, alpha: 1.0))
      context.fill(CGRect(origin: .zero, size: pageBounds.size))
      context.saveGState()
      context.scaleBy(x: scale, y: scale)
      context.drawPDFPage(cgPage)
      context.restoreGState()
      return true
    }
    guard drew else { return nil }
    return (bytes, width, height)
  }

  /// Dark-pixel ratio of the slot crop, with pixels clamped to the raster.
  /// Page space is bottom-origin, but CoreGraphics bitmap memory is
  /// top-down (memory row 0 is the top of the image), so each page row is
  /// remapped explicitly.
  static func darkRatio(
    slot: PDFRect,
    raster: (bytes: [UInt8], width: Int, height: Int),
    scale: CGFloat
  ) -> Double {
    let x0 = max(0, Int((slot.x * scale).rounded(.down)))
    let x1 = min(raster.width, Int(ceil((slot.x + slot.width) * scale)))
    let y0 = max(0, Int((slot.y * scale).rounded(.down)))
    let y1 = min(raster.height, Int(ceil((slot.y + slot.height) * scale)))
    guard x1 > x0, y1 > y0 else { return 0 }

    var dark = 0
    var total = 0
    for row in y0..<y1 {
      // Page row (from bottom) -> memory row (from top).
      let bufferRow = (raster.height - 1 - row) * raster.width
      for column in x0..<x1 {
        total += 1
        if raster.bytes[bufferRow + column] < 190 { dark += 1 }
      }
    }
    guard total > 0 else { return 0 }
    return Double(dark) / Double(total)
  }
}
