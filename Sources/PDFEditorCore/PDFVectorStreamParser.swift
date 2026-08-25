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

        // Stroke or fill commit operators
        let commitCallback: CGPDFOperatorCallback = { _, info in
            guard let info else { return }
            let ctx = Unmanaged<ScannerContext>.fromOpaque(info).takeUnretainedValue()
            ctx.detectedRectangles.append(contentsOf: ctx.currentRects)
            ctx.currentRects.removeAll(keepingCapacity: true)
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

    private static func processRawGeometry(context: ScannerContext) -> ParsedPageGeometry {
        let mediaBox = context.mediaBox
        let pageArea = max(mediaBox.width * mediaBox.height, 1.0)

        // Filter out whole-page background boxes and tiny point noise
        var cleanRects: [CGRect] = []
        var inputBoxes: [PDFRect] = []
        var checkboxes: [PDFRect] = []
        let rectangleReserveHint = min(context.detectedRectangles.count, 64)
        cleanRects.reserveCapacity(rectangleReserveHint)
        inputBoxes.reserveCapacity(rectangleReserveHint)
        checkboxes.reserveCapacity(rectangleReserveHint)

        for rect in context.detectedRectangles {
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
        var underlines: [PDFRect] = []
        underlines.reserveCapacity(min(context.detectedLines.count, 64))
        for line in context.detectedLines {
            if line.width >= 24 && line.height <= 4.0 {
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
