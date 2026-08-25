import AppKit
import Foundation
import PDFKit

/// A bounded impact result used by native and browser validation adapters.
///
/// This is deliberately narrower than semantic PDF editing. It answers two
/// questions for a known operation set: did extracted text change outside the
/// authorized page-space regions, and did rendered pixels change outside those
/// regions? It does not prove byte identity, independent-viewer parity, PDF/UA,
/// redaction completeness, or arbitrary text reflow safety.
public struct PDFImpactResult: Sendable, Equatable {
    public let status: ValidationCheckStatus
    public let message: String
    public let changedPageIndices: [Int]
    public let changedPixelCount: Int
    public let comparedPixelCount: Int
    public let maximumChannelDelta: Int

    public init(
        status: ValidationCheckStatus,
        message: String,
        changedPageIndices: [Int] = [],
        changedPixelCount: Int = 0,
        comparedPixelCount: Int = 0,
        maximumChannelDelta: Int = 0
    ) {
        self.status = status
        self.message = message
        self.changedPageIndices = changedPageIndices
        self.changedPixelCount = changedPixelCount
        self.comparedPixelCount = comparedPixelCount
        self.maximumChannelDelta = maximumChannelDelta
    }
}

public enum PDFImpactValidator {
    private static let maximumComparedPixelsPerPage = 4_000_000
    private static let minimumDownsampleScale: CGFloat = 0.25

    public static func compareTextOutsideRegions(
        source: PDFDocument,
        output: PDFDocument,
        operations: [EditOperation]
    ) -> PDFImpactResult {
        guard source.pageCount == output.pageCount else {
            return PDFImpactResult(
                status: .failed,
                message: "Outside-region text comparison could not align documents with different page counts."
            )
        }

        let missingCoordinates = operations.contains { operation in
            operation.coordinate == nil && operation.kind != .metadata
        }
        if missingCoordinates {
            return PDFImpactResult(
                status: .unknown,
                message: "Outside-region text comparison was not completed because an operation has no page-space region."
            )
        }

        var changedPages: [Int] = []
        for pageIndex in 0..<source.pageCount {
            guard let sourcePage = source.page(at: pageIndex),
                  let outputPage = output.page(at: pageIndex) else {
                return PDFImpactResult(
                    status: .failed,
                    message: "Outside-region text comparison could not reopen page \(pageIndex + 1)."
                )
            }
            let regions = operations
                .filter { $0.pageIndex == pageIndex }
                .compactMap { $0.coordinate?.rect.cgRect }
            let sourceText = textOutsideRegions(page: sourcePage, regions: regions)
            let outputText = textOutsideRegions(page: outputPage, regions: regions)
            if sourceText != outputText {
                changedPages.append(pageIndex)
            }
        }

        return PDFImpactResult(
            status: changedPages.isEmpty ? .passed : .failed,
            message: changedPages.isEmpty
                ? "Extracted text outside the authorized operation regions is unchanged."
                : "Extracted text changed outside the authorized operation regions on page(s): \(changedPages.map { $0 + 1 }.map(String.init).joined(separator: ", ")).",
            changedPageIndices: changedPages
        )
    }

    public static func compareRasterOutsideRegions(
        source: PDFDocument,
        output: PDFDocument,
        operations: [EditOperation],
        scale: CGFloat = 1.0,
        channelTolerance: Int = 8,
        maxAllowedOutsidePixelRatio: Double = 0,
        maximumComparedPixelsPerPage: Int = 4_000_000,
        minimumDownsampleScale: CGFloat = 0.2
    ) -> PDFImpactResult {
        guard source.pageCount == output.pageCount else {
            return PDFImpactResult(
                status: .failed,
                message: "Raster comparison could not align documents with different page counts."
            )
        }

        let missingCoordinates = operations.contains { operation in
            operation.coordinate == nil && operation.kind != .metadata
        }
        if missingCoordinates {
            return PDFImpactResult(
                status: .unknown,
                message: "Raster comparison was not completed because an operation has no page-space region."
            )
        }

        var changedPages: [Int] = []
        var changedPixels = 0
        var comparedPixels = 0
        var maximumDelta = 0

        for pageIndex in 0..<source.pageCount {
            enum PageComparisonOutcome {
                case result(PDFImpactResult)
                case pageData(changedPixels: Int, comparedPixels: Int, pageMaxDelta: Int, pageChanged: Bool)
            }

            let outcome: PageComparisonOutcome = autoreleasepool {
                guard let sourcePage = source.page(at: pageIndex),
                      let outputPage = output.page(at: pageIndex) else {
                    return .result(PDFImpactResult(
                        status: .failed,
                        message: "Raster comparison could not reopen page \(pageIndex + 1)."
                    ))
                }
                let sourceDisplayBounds = Self.displayBounds(for: sourcePage)
                let outputDisplayBounds = Self.displayBounds(for: outputPage)
                guard sourceDisplayBounds.size == outputDisplayBounds.size else {
                    return .result(PDFImpactResult(
                        status: .failed,
                        message: "Rendered page dimensions changed on page \(pageIndex + 1)."
                    ))
                }
                let pagePixelCount = Int(ceil(sourceDisplayBounds.width * scale))
                    * Int(ceil(sourceDisplayBounds.height * scale))
                let effectiveScale: CGFloat
                if CGFloat(pagePixelCount) > CGFloat(Self.maximumComparedPixelsPerPage) {
                    let downscale = sqrt(
                        CGFloat(Self.maximumComparedPixelsPerPage) / CGFloat(pagePixelCount))
                    if downscale < Self.minimumDownsampleScale {
                        return .result(PDFImpactResult(
                            status: .unknown,
                            message:
                                "Raster comparison was not completed for page \(pageIndex + 1): it exceeds the pixel budget even at the minimum comparison scale."
                        ))
                    }
                    effectiveScale = scale * downscale
                } else {
                    effectiveScale = scale
                }
                guard let sourceRaster = raster(for: sourcePage, scale: effectiveScale),
                      let outputRaster = raster(for: outputPage, scale: effectiveScale) else {
                    return .result(PDFImpactResult(
                        status: .failed,
                        message:
                            "Raster comparison could not render page \(pageIndex + 1); failing closed rather than passing without evidence."
                    ))
                }
                guard sourceRaster.width == outputRaster.width,
                      sourceRaster.height == outputRaster.height,
                      sourceRaster.samplesPerPixel == outputRaster.samplesPerPixel else {
                    return .result(PDFImpactResult(
                        status: .failed,
                        message: "Rendered page dimensions changed on page \(pageIndex + 1)."
                    ))
                }

                let authorizationPadding = max(1.0 / effectiveScale, 0.5)
                let regions = operations
                    .filter { $0.pageIndex == pageIndex }
                    .compactMap { $0.coordinate?.rect.cgRect.insetBy(dx: -authorizationPadding, dy: -authorizationPadding) }
                let displayHeight = sourceDisplayBounds.height
                let displayToUser = sourcePage.transform(for: .cropBox).inverted()
                var pageChangedPixels = 0
                var pageComparedPixels = 0
                var pageMaxDelta = 0
                for y in 0..<sourceRaster.height {
                    for x in 0..<sourceRaster.width {
                        let rx = CGFloat(x) / effectiveScale
                        let ry = displayHeight - CGFloat(y + 1) / effectiveScale
                        let userPoint = CGPoint(x: rx, y: ry).applying(displayToUser)
                        if regions.contains(where: { $0.contains(userPoint) }) {
                            continue
                        }
                        pageComparedPixels += 1
                        let sourceOffset = y * sourceRaster.bytesPerRow + x * sourceRaster.samplesPerPixel
                        let outputOffset = y * outputRaster.bytesPerRow + x * outputRaster.samplesPerPixel
                        var changed = false
                        for channel in 0..<min(sourceRaster.samplesPerPixel, 4) {
                            let delta = abs(Int(sourceRaster.bytes[sourceOffset + channel]) - Int(outputRaster.bytes[outputOffset + channel]))
                            pageMaxDelta = max(pageMaxDelta, delta)
                            if delta > channelTolerance {
                                changed = true
                            }
                        }
                        if changed {
                            pageChangedPixels += 1
                        }
                    }
                }
                let ratio = pageComparedPixels == 0 ? 0 : Double(pageChangedPixels) / Double(pageComparedPixels)
                let pageChanged = ratio > maxAllowedOutsidePixelRatio
                return .pageData(
                    changedPixels: pageChangedPixels,
                    comparedPixels: pageComparedPixels,
                    pageMaxDelta: pageMaxDelta,
                    pageChanged: pageChanged
                )
            }

            switch outcome {
            case .result(let earlyResult):
                return earlyResult
            case .pageData(let pChanged, let pCompared, let pDelta, let isChanged):
                comparedPixels += pCompared
                changedPixels += pChanged
                maximumDelta = max(maximumDelta, pDelta)
                if isChanged {
                    changedPages.append(pageIndex)
                }
            }
        }

        return PDFImpactResult(
            status: changedPages.isEmpty ? .passed : .failed,
            message: changedPages.isEmpty
                ? "Raster output is unchanged outside the authorized operation regions."
                : "Raster output changed outside the authorized operation regions on page(s): \(changedPages.map { $0 + 1 }.map(String.init).joined(separator: ", ")).",
            changedPageIndices: changedPages,
            changedPixelCount: changedPixels,
            comparedPixelCount: comparedPixels,
            maximumChannelDelta: maximumDelta
        )
    }

    private struct Raster {
        let width: Int
        let height: Int
        let bytesPerRow: Int
        let samplesPerPixel: Int
        let bytes: [UInt8]
    }

    private static func textOutsideRegions(page: PDFPage, regions: [CGRect]) -> String {
        let characters = Array(page.string ?? "")
        var result = String()
        result.reserveCapacity(characters.count)
        for (index, character) in characters.enumerated() {
            let bounds = page.characterBounds(at: index)
            if regions.contains(where: { $0.intersects(bounds) }) {
                continue
            }
            result.append(character)
        }
        return result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Display-space bounds after applying the page's /Rotate transform.
    /// CGPDFPageGetBoxRect applies rotation; the PDFKit fallback assumes 0°.
    private static func displayBounds(for page: PDFPage) -> CGRect {
        if let pageRef = page.pageRef {
            return pageRef.getBoxRect(.cropBox)
        }
        return page.bounds(for: .cropBox)
    }

    private static func raster(for page: PDFPage, scale: CGFloat) -> Raster? {
        // Render in display space: for /Rotate 90/270 the rendered bitmap
        // dimensions are swapped relative to the unrotated crop box.
        let bounds = Self.displayBounds(for: page)
        let width = max(1, Int(ceil(bounds.width * scale)))
        let height = max(1, Int(ceil(bounds.height * scale)))
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bitmapFormat: [],
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.cgContext.setFillColor(NSColor.white.cgColor)
        context.cgContext.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.cgContext.saveGState()
        context.cgContext.scaleBy(x: scale, y: scale)
        page.draw(with: .cropBox, to: context.cgContext)
        context.cgContext.restoreGState()
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        let bytes: [UInt8] = bitmap.bitmapData.map { pointer in
            Array(UnsafeBufferPointer<UInt8>(start: pointer, count: bitmap.bytesPerRow * height))
        } ?? []
        return Raster(
            width: width,
            height: height,
            bytesPerRow: bitmap.bytesPerRow,
            samplesPerPixel: max(1, bitmap.samplesPerPixel),
            bytes: bytes
        )
    }
}
