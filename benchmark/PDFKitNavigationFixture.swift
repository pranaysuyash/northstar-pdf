import Foundation
import PDFKit
import CoreGraphics

enum FixtureError: Error, CustomStringConvertible {
    case usage
    case writeFailed
    var description: String {
        switch self {
        case .usage: return "usage: PDFKitNavigationFixture <output.pdf>"
        case .writeFailed: return "PDFKit could not write the navigation fixture"
        }
    }
}

func addText(_ text: String, to page: PDFPage, at point: CGPoint) {
    let annotation = PDFAnnotation(bounds: CGRect(x: point.x, y: point.y, width: 420, height: 24), forType: .freeText, withProperties: nil)
    annotation.contents = text
    annotation.font = NSFont.systemFont(ofSize: 14)
    annotation.fontColor = .black
    annotation.color = .clear
    page.addAnnotation(annotation)
}

func addLink(to page: PDFPage, bounds: CGRect, action: PDFAction) {
    let annotation = PDFAnnotation(bounds: bounds, forType: .link, withProperties: nil)
    annotation.action = action
    page.addAnnotation(annotation)
}

guard CommandLine.arguments.count == 2 else { throw FixtureError.usage }
let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let document = PDFDocument()
let pageSizes = [CGSize(width: 612, height: 792), CGSize(width: 612, height: 792), CGSize(width: 612, height: 792)]
var pages: [PDFPage] = []

for (index, size) in pageSizes.enumerated() {
    let page = PDFPage()
    page.setBounds(CGRect(origin: .zero, size: size), for: PDFDisplayBox.mediaBox)
    page.setBounds(CGRect(x: 36, y: 36, width: size.width - 72, height: size.height - 72), for: PDFDisplayBox.cropBox)
    if index == 1 {
        page.setBounds(CGRect(x: 54, y: 72, width: 504, height: 648), for: PDFDisplayBox.trimBox)
        page.setBounds(CGRect(x: 18, y: 18, width: 576, height: 756), for: PDFDisplayBox.bleedBox)
    }
    if index == 2 {
        page.setBounds(CGRect(x: 72, y: 90, width: 468, height: 612), for: PDFDisplayBox.artBox)
    }
    addText("Navigation fixture page \(index + 1)", to: page, at: CGPoint(x: 72, y: 700))
    document.insert(page, at: index)
    pages.append(page)
}

addLink(to: pages[0], bounds: CGRect(x: 72, y: 640, width: 180, height: 28), action: PDFActionURL(url: URL(string: "https://example.com/safe")!))
addLink(to: pages[0], bounds: CGRect(x: 72, y: 600, width: 180, height: 28), action: PDFActionURL(url: URL(string: "file:///tmp/unsafe.pdf")!))
addLink(to: pages[0], bounds: CGRect(x: 72, y: 560, width: 180, height: 28), action: PDFActionGoTo(destination: PDFDestination(page: pages[1], at: CGPoint(x: 72, y: 700))))

let root = PDFOutline()
let first = PDFOutline()
first.label = "Introduction"
first.destination = PDFDestination(page: pages[0], at: CGPoint(x: 72, y: 700))
let second = PDFOutline()
second.label = "Details"
second.destination = PDFDestination(page: pages[1], at: CGPoint(x: 72, y: 700))
let nested = PDFOutline()
nested.label = "Nested appendix"
nested.destination = PDFDestination(page: pages[2], at: CGPoint(x: 72, y: 700))
second.insertChild(nested, at: 0)
root.insertChild(first, at: 0)
root.insertChild(second, at: 1)
document.outlineRoot = root
document.documentAttributes = [PDFDocumentAttribute.titleAttribute: "Navigation and metadata fixture"]

guard document.write(to: outputURL) else { throw FixtureError.writeFailed }
