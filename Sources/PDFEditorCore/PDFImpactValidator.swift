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
        maxAllowedOutsidePixelRatio: Double = 0
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
            guard let sourcePage = source.page(at: pageIndex),
                  let outputPage = output.page(at: pageIndex) else {
                return PDFImpactResult(
                    status: .failed,
                    message: "Raster comparison could not reopen page (pageIndex + 1)."
                )
            }
            let sourceRaster = raster(for: sourcePage, scale: scale)
            let outputRaster = raster(for: outputPage, scale: scale)
            guard sourceRaster.width == outputRaster.width,
                  sourceRaster.height == outputRaster.height,
                  sourceRaster.samplesPerPixel == outputRaster.samplesPerPixel else {
                return PDFImpactResult(
                    status: .failed,
                    message: "Rendered page dimensions changed on page (pageIndex + 1)."
                )
            }

            let regions = operations
                .filter { $0.pageIndex == pageIndex }
                .compactMap { $0.coordinate?.rect.cgRect }
            let pageBounds = sourcePage.bounds(for: .cropBox)
            var pageChangedPixels = 0
            var pageComparedPixels = 0
            for y in 0..<sourceRaster.height {
                for x in 0..<sourceRaster.width {
                    let point = CGPoint(
                        x: pageBounds.minX + CGFloat(x) / scale,
                        y: pageBounds.maxY - CGFloat(y + 1) / scale
                    )
                    if regions.contains(where: { $0.contains(point) }) {
                        continue
                    }
                    pageComparedPixels += 1
                    let sourceOffset = y * sourceRaster.bytesPerRow + x * sourceRaster.samplesPerPixel
                    let outputOffset = y * outputRaster.bytesPerRow + x * outputRaster.samplesPerPixel
                    var changed = false
                    for channel in 0..<min(sourceRaster.samplesPerPixel, 4) {
                        let delta = abs(Int(sourceRaster.bytes[sourceOffset + channel]) - Int(outputRaster.bytes[outputOffset + channel]))
                        maximumDelta = max(maximumDelta, delta)
                        if delta > channelTolerance {
                            changed = true
                        }
                    }
                    if changed {
                        pageChangedPixels += 1
                    }
                }
            }
            comparedPixels += pageComparedPixels
            changedPixels += pageChangedPixels
            let ratio = pageComparedPixels == 0 ? 0 : Double(pageChangedPixels) / Double(pageComparedPixels)
            if ratio > maxAllowedOutsidePixelRatio {
                changedPages.append(pageIndex)
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

    private static func raster(for page: PDFPage, scale: CGFloat) -> Raster {
        let bounds = page.bounds(for: .cropBox)
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
            return Raster(width: 0, height: 0, bytesPerRow: 0, samplesPerPixel: 0, bytes: [])
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
