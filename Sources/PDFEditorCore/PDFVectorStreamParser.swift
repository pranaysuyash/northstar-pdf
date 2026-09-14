import CoreGraphics
import Foundation

public struct VectorPathElement: Sendable, Equatable {
    public enum ElementKind: Sendable, Equatable {
        case rectangle(CGRect)
        case line(start: CGPoint, end: CGPoint)
        case horizontalRule(y: CGFloat, minX: CGFloat, maxX: CGFloat)
    }

    public let kind: ElementKind
    public let pageIndex: Int
    public let bounds: CGRect
    public let isStroked: Bool
    public let isFilled: Bool

    public init(kind: ElementKind, pageIndex: Int, bounds: CGRect, isStroked: Bool, isFilled: Bool) {
        self.kind = kind
        self.pageIndex = pageIndex
        self.bounds = bounds
        self.isStroked = isStroked
        self.isFilled = isFilled
    }
}

public final class PDFVectorStreamParser: @unchecked Sendable {
    public struct ParsedPageGeometry: Sendable {
        public let pageIndex: Int
        public let mediaBox: CGRect
        public let rectangles: [CGRect]
        public let horizontalLines: [CGRect]
        public let potentialInputBoxes: [PDFRect]
        public let potentialUnderlines: [PDFRect]
        public let potentialCheckboxes: [PDFRect]

        public init(
            pageIndex: Int,
            mediaBox: CGRect,
            rectangles: [CGRect],
            horizontalLines: [CGRect],
            potentialInputBoxes: [PDFRect],
            potentialUnderlines: [PDFRect],
            potentialCheckboxes: [PDFRect]
        ) {
            self.pageIndex = pageIndex
            self.mediaBox = mediaBox
            self.rectangles = rectangles
            self.horizontalLines = horizontalLines
            self.potentialInputBoxes = potentialInputBoxes
            self.potentialUnderlines = potentialUnderlines
            self.potentialCheckboxes = potentialCheckboxes
        }
    }

    private final class ScannerContext {
        var pageIndex: Int = 0
        var mediaBox: CGRect = .zero
        var ctmStack: [CGAffineTransform] = [CGAffineTransform.identity]
        var currentPath: [CGPoint] = []
        var currentRects: [CGRect] = []
        var detectedRectangles: [CGRect] = []
        var detectedLines: [CGRect] = []

        var currentCTM: CGAffineTransform {
            ctmStack.last ?? .identity
        }
    }

    public static func parse(documentURL: URL) -> [ParsedPageGeometry] {
        PerformanceTelemetry.shared.measureVectorParse {
            guard let doc = CGPDFDocument(documentURL as CFURL), doc.numberOfPages > 0 else { return [] }
            return (1...doc.numberOfPages).compactMap { pageNumber in
                autoreleasepool {
                    guard let page = doc.page(at: pageNumber) else { return nil }
                    return parse(page: page, pageIndex: pageNumber - 1)
                }
            }
        }
    }

    public static func parse(data: Data) -> [ParsedPageGeometry] {
        PerformanceTelemetry.shared.measureVectorParse {
            guard let provider = CGDataProvider(data: data as CFData),
                  let doc = CGPDFDocument(provider), doc.numberOfPages > 0 else { return [] }
            return (1...doc.numberOfPages).compactMap { pageNumber in
                autoreleasepool {
                    guard let page = doc.page(at: pageNumber) else { return nil }
                    return parse(page: page, pageIndex: pageNumber - 1)
                }
            }
        }
    }

    public static func parse(page: CGPDFPage, pageIndex: Int) -> ParsedPageGeometry {
        let mediaBox = page.getBoxRect(.mediaBox)
        let context = ScannerContext()
        context.pageIndex = pageIndex
        context.mediaBox = mediaBox

        let contentStream = CGPDFContentStreamCreateWithPage(page)

        let opTable = CGPDFOperatorTableCreate()!

        // Save graphics state
        CGPDFOperatorTableSetCallback(opTable, "q") { _, info in
            guard let info else { return }
            let ctx = Unmanaged<ScannerContext>.fromOpaque(info).takeUnretainedValue()
            ctx.ctmStack.append(ctx.currentCTM)
        }

        // Restore graphics state
        CGPDFOperatorTableSetCallback(opTable, "Q") { _, info in
            guard let info else { return }
            let ctx = Unmanaged<ScannerContext>.fromOpaque(info).takeUnretainedValue()
            if ctx.ctmStack.count > 1 {
                ctx.ctmStack.removeLast()
            }
        }

        // Concat matrix: a b c d e f cm
        CGPDFOperatorTableSetCallback(opTable, "cm") { scanner, info in
            guard let info else { return }
            let ctx = Unmanaged<ScannerContext>.fromOpaque(info).takeUnretainedValue()
            var a: CGPDFReal = 0, b: CGPDFReal = 0, c: CGPDFReal = 0, d: CGPDFReal = 0, e: CGPDFReal = 0, f: CGPDFReal = 0
            guard CGPDFScannerPopNumber(scanner, &f),
                  CGPDFScannerPopNumber(scanner, &e),
                  CGPDFScannerPopNumber(scanner, &d),
                  CGPDFScannerPopNumber(scanner, &c),
                  CGPDFScannerPopNumber(scanner, &b),
                  CGPDFScannerPopNumber(scanner, &a) else { return }
            let transform = CGAffineTransform(a: a, b: b, c: c, d: d, tx: e, ty: f)
            let updated = transform.concatenating(ctx.currentCTM)
            if !ctx.ctmStack.isEmpty {
                ctx.ctmStack[ctx.ctmStack.count - 1] = updated
            }
        }

        // Append rectangle: x y w h re
        CGPDFOperatorTableSetCallback(opTable, "re") { scanner, info in
            guard let info else { return }
            let ctx = Unmanaged<ScannerContext>.fromOpaque(info).takeUnretainedValue()
            var x: CGPDFReal = 0, y: CGPDFReal = 0, w: CGPDFReal = 0, h: CGPDFReal = 0
            guard CGPDFScannerPopNumber(scanner, &h),
                  CGPDFScannerPopNumber(scanner, &w),
                  CGPDFScannerPopNumber(scanner, &y),
                  CGPDFScannerPopNumber(scanner, &x) else { return }
            let rawRect = CGRect(x: x, y: y, width: w, height: h)
            let transformed = rawRect.applying(ctx.currentCTM).standardized
            ctx.currentRects.append(transformed)
        }

        // Move to: x y m
        CGPDFOperatorTableSetCallback(opTable, "m") { scanner, info in
            guard let info else { return }
            let ctx = Unmanaged<ScannerContext>.fromOpaque(info).takeUnretainedValue()
            var x: CGPDFReal = 0, y: CGPDFReal = 0
            guard CGPDFScannerPopNumber(scanner, &y),
                  CGPDFScannerPopNumber(scanner, &x) else { return }
            let pt = CGPoint(x: x, y: y).applying(ctx.currentCTM)
            ctx.currentPath.removeAll(keepingCapacity: true)
            ctx.currentPath.append(pt)
        }

        // Line to: x y l
        CGPDFOperatorTableSetCallback(opTable, "l") { scanner, info in
            guard let info else { return }
            let ctx = Unmanaged<ScannerContext>.fromOpaque(info).takeUnretainedValue()
            var x: CGPDFReal = 0, y: CGPDFReal = 0
            guard CGPDFScannerPopNumber(scanner, &y),
                  CGPDFScannerPopNumber(scanner, &x) else { return }
            let pt = CGPoint(x: x, y: y).applying(ctx.currentCTM)
            if let last = ctx.currentPath.last {
                let rect = CGRect(
                    x: min(last.x, pt.x),
                    y: min(last.y, pt.y),
                    width: max(abs(pt.x - last.x), 1.0),
                    height: max(abs(pt.y - last.y), 1.0)
                ).standardized
                ctx.detectedLines.append(rect)
            }
            ctx.currentPath.append(pt)
        }

        // Close subpath: h
        CGPDFOperatorTableSetCallback(opTable, "h") { _, info in
            guard let info else { return }
            let ctx = Unmanaged<ScannerContext>.fromOpaque(info).takeUnretainedValue()
            if let first = ctx.currentPath.first, let last = ctx.currentPath.last, first != last {
                let rect = CGRect(
                    x: min(last.x, first.x),
                    y: min(last.y, first.y),
                    width: max(abs(first.x - last.x), 1.0),
                    height: max(abs(first.y - last.y), 1.0)
                ).standardized
                ctx.detectedLines.append(rect)
                ctx.currentPath.append(first)
            }
        }

        // Stroke or fill commit operators
        let commitCallback: CGPDFOperatorCallback = { _, info in
            guard let info else { return }
            let ctx = Unmanaged<ScannerContext>.fromOpaque(info).takeUnretainedValue()
            ctx.detectedRectangles.append(contentsOf: ctx.currentRects)
            ctx.currentRects.removeAll(keepingCapacity: true)

            // Reconstruct rectangles from closed orthogonal paths (e.g. m l l l h / S)
            let pts = ctx.currentPath
            if (pts.count == 4 || pts.count == 5) {
                let xs = pts.map(\.x)
                let ys = pts.map(\.y)
                if let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() {
                    let w = maxX - minX
                    let h = maxY - minY
                    // Check orthogonality: all points must be on the bounding box corners
                    let tolerance: CGFloat = 2.0
                    let isRectangular = pts.allSatisfy { pt in
                        (abs(pt.x - minX) <= tolerance || abs(pt.x - maxX) <= tolerance) &&
                        (abs(pt.y - minY) <= tolerance || abs(pt.y - maxY) <= tolerance)
                    }
                    if isRectangular && w >= 6 && h >= 6 {
                        ctx.detectedRectangles.append(CGRect(x: minX, y: minY, width: w, height: h))
                    }
                }
            }

            ctx.currentPath.removeAll(keepingCapacity: true)
        }

        CGPDFOperatorTableSetCallback(opTable, "S", commitCallback)
        CGPDFOperatorTableSetCallback(opTable, "s", commitCallback)
        CGPDFOperatorTableSetCallback(opTable, "f", commitCallback)
        CGPDFOperatorTableSetCallback(opTable, "F", commitCallback)
        CGPDFOperatorTableSetCallback(opTable, "f*", commitCallback)
        CGPDFOperatorTableSetCallback(opTable, "B", commitCallback)
        CGPDFOperatorTableSetCallback(opTable, "B*", commitCallback)
        CGPDFOperatorTableSetCallback(opTable, "b", commitCallback)
        CGPDFOperatorTableSetCallback(opTable, "b*", commitCallback)
        CGPDFOperatorTableSetCallback(opTable, "n", commitCallback)

        let unmanaged = Unmanaged.passUnretained(context)
        let scanner = CGPDFScannerCreate(contentStream, opTable, unmanaged.toOpaque())
        CGPDFScannerScan(scanner)
        CGPDFScannerRelease(scanner)
        CGPDFOperatorTableRelease(opTable)
        CGPDFContentStreamRelease(contentStream)

        return processRawGeometry(context: context)
    }

    private static func reconstructStrokedGridsAndBoxes(
        lines: [CGRect]
    ) -> (cells: [CGRect], consumedLineIndices: Set<Int>) {
        var cells: [CGRect] = []
        var consumed = Set<Int>()

        var horizontalLines: [(index: Int, rect: CGRect)] = []
        var verticalLines: [(index: Int, rect: CGRect)] = []

        for (idx, line) in lines.enumerated() {
            if line.height <= 3.0 && line.width >= 8.0 {
                horizontalLines.append((idx, line))
            } else if line.width <= 3.0 && line.height >= 8.0 {
                verticalLines.append((idx, line))
            }
        }

        horizontalLines.sort { $0.rect.minY < $1.rect.minY }

        for i in 0..<horizontalLines.count {
            let h1 = horizontalLines[i]
            for j in (i + 1)..<horizontalLines.count {
                let h2 = horizontalLines[j]
                let rowHeight = h2.rect.minY - h1.rect.minY
                if rowHeight > 36.0 { break }
                guard rowHeight >= 8.0 else { continue }

                let overlapMinX = max(h1.rect.minX, h2.rect.minX)
                let overlapMaxX = min(h1.rect.maxX, h2.rect.maxX)
                guard overlapMaxX - overlapMinX >= 8.0 else { continue }

                var dividerXPositions: [CGFloat] = []
                var dividerIndices: [Int] = []

                for v in verticalLines {
                    let vRect = v.rect
                    if vRect.midX >= overlapMinX - 3.0 && vRect.midX <= overlapMaxX + 3.0 {
                        if vRect.minY <= h1.rect.minY + 4.0 && vRect.maxY >= h2.rect.minY - 4.0 {
                            dividerXPositions.append(vRect.midX)
                            dividerIndices.append(v.index)
                        }
                    }
                }

                guard dividerXPositions.count >= 2 else { continue }

                dividerXPositions.sort()
                var uniqueX: [CGFloat] = []
                for x in dividerXPositions {
                    if let last = uniqueX.last {
                        if abs(x - last) > 2.0 {
                            uniqueX.append(x)
                        }
                    } else {
                        uniqueX.append(x)
                    }
                }

                guard uniqueX.count >= 2 else { continue }

                var widths: [CGFloat] = []
                for k in 0..<(uniqueX.count - 1) {
                    widths.append(uniqueX[k + 1] - uniqueX[k])
                }

                // Case A: Multi-cell Grid (>= 3 cells with uniform width, e.g. BLOCK LETTERS, DOB, Mobile)
                if widths.count >= 3 {
                    let minW = widths.min() ?? 0
                    let maxW = widths.max() ?? 0
                    if minW >= 8.0 && maxW <= 36.0 && (maxW - minW <= 5.0 || maxW / max(minW, 1.0) <= 1.35) {
                        for k in 0..<widths.count {
                            cells.append(CGRect(x: uniqueX[k], y: h1.rect.minY, width: widths[k], height: rowHeight))
                        }
                        consumed.insert(h1.index)
                        consumed.insert(h2.index)
                        for dIdx in dividerIndices { consumed.insert(dIdx) }
                    }
                }
                // Case B: Standalone Square Checkbox (1 cell where width ≈ height ≈ 8-24pt)
                else if widths.count == 1 {
                    let w = widths[0]
                    if w >= 8.0 && w <= 24.0 && abs(w - rowHeight) <= 4.0 {
                        if h1.rect.width <= w + 6.0 && h2.rect.width <= w + 6.0 {
                            cells.append(CGRect(x: uniqueX[0], y: h1.rect.minY, width: w, height: rowHeight))
                            consumed.insert(h1.index)
                            consumed.insert(h2.index)
                            for dIdx in dividerIndices { consumed.insert(dIdx) }
                        }
                    }
                }
            }
        }

        return (cells, consumed)
    }

    private static func processRawGeometry(context: ScannerContext) -> ParsedPageGeometry {
        let mediaBox = context.mediaBox
        let pageArea = max(mediaBox.width * mediaBox.height, 1.0)

        // Reconstruct character grid cells and square checkboxes from stroked lines
        let (strokedCells, consumedLines) = reconstructStrokedGridsAndBoxes(lines: context.detectedLines)

        // Combine directly detected rectangles with reconstructed cells
        var allRectangles = context.detectedRectangles
        allRectangles.append(contentsOf: strokedCells)

        // Filter out whole-page background boxes and tiny point noise
        var cleanRects: [CGRect] = []
        var inputBoxes: [PDFRect] = []
        var checkboxes: [PDFRect] = []
        let rectangleReserveHint = min(allRectangles.count, 64)
        cleanRects.reserveCapacity(rectangleReserveHint)
        inputBoxes.reserveCapacity(rectangleReserveHint)
        checkboxes.reserveCapacity(rectangleReserveHint)

        for rect in allRectangles {
            let area = rect.width * rect.height
            // Exclude full-page container (e.g. >95% page area) and zero-size artifacts
            if area > pageArea * 0.95 || rect.width < 3 || rect.height < 3 {
                continue
            }
            cleanRects.append(rect)

            // Detect checkboxes: small square-ish boxes (8pt to 32pt)
            let isSquare = abs(rect.width - rect.height) <= max(rect.width * 0.25, 3.0)
            if isSquare && rect.width >= 8 && rect.width <= 32 {
                checkboxes.append(PDFRect(rect))
            } else if rect.height >= 12 && rect.height <= 300 && rect.width >= 24 && rect.width <= mediaBox.width * 0.92 {
                // Potential field box or cell
                inputBoxes.append(PDFRect(rect))
            }
        }

        // Filter horizontal lines (underlines): width >= 24, height <= 4
        // Exclude lines consumed by stroked grid/box reconstruction
        var underlines: [PDFRect] = []
        underlines.reserveCapacity(min(context.detectedLines.count, 64))
        for (idx, line) in context.detectedLines.enumerated() {
            if !consumedLines.contains(idx) && line.width >= 24 && line.height <= 4.0 {
                underlines.append(PDFRect(line))
            }
        }

        return ParsedPageGeometry(
            pageIndex: context.pageIndex,
            mediaBox: mediaBox,
            rectangles: cleanRects,
            horizontalLines: context.detectedLines,
            potentialInputBoxes: inputBoxes,
            potentialUnderlines: underlines,
            potentialCheckboxes: checkboxes
        )
    }
}
