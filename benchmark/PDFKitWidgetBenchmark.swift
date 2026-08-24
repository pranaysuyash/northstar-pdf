import AppKit
import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers

private struct Arguments {
    let outputDirectory: URL

    init(arguments: [String]) throws {
        guard arguments.count == 1 else {
            throw BenchmarkError.usage("usage: PDFKitWidgetBenchmark <output-directory>")
        }
        outputDirectory = URL(fileURLWithPath: arguments[0], isDirectory: true)
    }
}

private struct WidgetSnapshot: Encodable {
    let type: String
    let fieldName: String
    let fieldType: String
    let value: String
    let bounds: String
}

private struct BenchmarkResult: Encodable {
    let provider: String
    let fixtureSHA256: String
    let widgetCount: Int
    let expectedFieldNames: [String]
    let observedFieldNames: [String]
    let fixtureReopen: Bool
    let filledReopen: Bool
    let textValueRoundTrip: Bool
    let checkboxStateRoundTrip: Bool
    let radioStateRoundTrip: Bool
    let choiceValueRoundTrip: Bool
    let signatureFieldRoundTrip: Bool
    let fixtureUnchanged: Bool
    let widgets: [WidgetSnapshot]
}

private enum BenchmarkError: Error, CustomStringConvertible {
    case usage(String)
    case failed(String)

    var description: String {
        switch self {
        case let .usage(message), let .failed(message):
            return message
        }
    }
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else { throw BenchmarkError.failed(message) }
}

private func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func controlType(_ rawValue: Int) -> PDFWidgetControlType {
    guard let value = PDFWidgetControlType(rawValue: rawValue) else {
        fatalError("unsupported PDFKit widget control type: \(rawValue)")
    }
    return value
}

private func cellState(_ rawValue: Int) -> PDFWidgetCellState {
    guard let value = PDFWidgetCellState(rawValue: rawValue) else {
        fatalError("unsupported PDFKit widget cell state: \(rawValue)")
    }
    return value
}

private func widget(
    bounds: CGRect,
    fieldType: PDFAnnotationWidgetSubtype,
    fieldName: String
) -> PDFAnnotation {
    let annotation = PDFAnnotation(
        bounds: bounds,
        forType: PDFAnnotationSubtype.widget,
        withProperties: nil
    )
    annotation.widgetFieldType = fieldType
    annotation.fieldName = fieldName
    annotation.backgroundColor = NSColor(calibratedWhite: 0.96, alpha: 1)
    annotation.border = PDFBorder()
    annotation.border?.lineWidth = 1
    return annotation
}

private func makeFixture() throws -> PDFDocument {
    let document = PDFDocument()
    let page = PDFPage()
    document.insert(page, at: 0)

    let text = widget(
        bounds: CGRect(x: 72, y: 680, width: 220, height: 28),
        fieldType: PDFAnnotationWidgetSubtype.text,
        fieldName: "fullName"
    )
    text.widgetStringValue = "Ada Lovelace"
    page.addAnnotation(text)

    let checkbox = widget(
        bounds: CGRect(x: 72, y: 625, width: 24, height: 24),
        fieldType: PDFAnnotationWidgetSubtype.button,
        fieldName: "consent"
    )
    checkbox.widgetControlType = controlType(2)
    checkbox.buttonWidgetStateString = "Yes"
    checkbox.buttonWidgetState = cellState(1)
    page.addAnnotation(checkbox)

    let radioYes = widget(
        bounds: CGRect(x: 72, y: 570, width: 24, height: 24),
        fieldType: PDFAnnotationWidgetSubtype.button,
        fieldName: "status"
    )
    radioYes.widgetControlType = controlType(1)
    radioYes.buttonWidgetStateString = "yes"
    radioYes.buttonWidgetState = cellState(1)
    page.addAnnotation(radioYes)

    let radioNo = widget(
        bounds: CGRect(x: 112, y: 570, width: 24, height: 24),
        fieldType: PDFAnnotationWidgetSubtype.button,
        fieldName: "status"
    )
    radioNo.widgetControlType = controlType(1)
    radioNo.buttonWidgetStateString = "no"
    radioNo.buttonWidgetState = cellState(0)
    page.addAnnotation(radioNo)

    let choice = widget(
        bounds: CGRect(x: 72, y: 510, width: 220, height: 28),
        fieldType: PDFAnnotationWidgetSubtype.choice,
        fieldName: "country"
    )
    choice.choices = ["India", "Other"]
    choice.widgetStringValue = "India"
    page.addAnnotation(choice)

    let signature = widget(
        bounds: CGRect(x: 72, y: 420, width: 220, height: 56),
        fieldType: PDFAnnotationWidgetSubtype.signature,
        fieldName: "signature"
    )
    page.addAnnotation(signature)

    return document
}

private func widgetAnnotations(in document: PDFDocument) -> [PDFAnnotation] {
    document.page(at: 0)?.annotations.filter {
        ($0.type ?? "") == "Widget"
    } ?? []
}

private func snapshots(_ annotations: [PDFAnnotation]) -> [WidgetSnapshot] {
    annotations.map {
        WidgetSnapshot(
            type: $0.type ?? "",
            fieldName: $0.fieldName ?? "",
            fieldType: String(describing: $0.widgetFieldType),
            value: $0.widgetStringValue ?? "",
            bounds: NSStringFromRect($0.bounds)
        )
    }
}

private func run(arguments: Arguments) throws -> BenchmarkResult {
    let fileManager = FileManager.default
    try fileManager.createDirectory(at: arguments.outputDirectory, withIntermediateDirectories: true)

    let fixture = try makeFixture()
    let fixtureURL = arguments.outputDirectory.appendingPathComponent("native-widgets.pdf")
    guard fixture.write(to: fixtureURL) else {
        throw BenchmarkError.failed("could not write native widget fixture")
    }

    let fixtureData = try Data(contentsOf: fixtureURL)
    let fixtureDigest = sha256(fixtureData)
    guard let reopenedFixture = PDFDocument(url: fixtureURL) else {
        throw BenchmarkError.failed("could not reopen native widget fixture")
    }
    let initialWidgets = widgetAnnotations(in: reopenedFixture)
    let expectedNames = ["fullName", "consent", "status", "status", "country", "signature"]
    let observedNames = initialWidgets.map { $0.fieldName ?? "" }
    try require(initialWidgets.count == expectedNames.count, "expected six native widgets")
    try require(observedNames.sorted() == expectedNames.sorted(), "native field names did not round-trip")

    guard let filledDocument = PDFDocument(url: fixtureURL),
          let filledPage = filledDocument.page(at: 0) else {
        throw BenchmarkError.failed("could not load fixture for filling")
    }
    let filledWidgets = filledPage.annotations.filter {
        ($0.type ?? "") == "Widget"
    }
    let byName = Dictionary(grouping: filledWidgets, by: { $0.fieldName ?? "" })
    byName["fullName"]?.first?.widgetStringValue = "Grace Hopper"
    byName["consent"]?.first?.buttonWidgetState = cellState(0)
    byName["status"]?.first?.buttonWidgetState = cellState(0)
    byName["status"]?.dropFirst().first?.buttonWidgetState = cellState(1)
    byName["country"]?.first?.widgetStringValue = "Other"

    let filledURL = arguments.outputDirectory.appendingPathComponent("native-widgets-filled.pdf")
    guard filledDocument.write(to: filledURL) else {
        throw BenchmarkError.failed("could not write filled native widget fixture")
    }
    guard let reopenedFilled = PDFDocument(url: filledURL) else {
        throw BenchmarkError.failed("could not reopen filled native widget fixture")
    }
    let reopenedWidgets = widgetAnnotations(in: reopenedFilled)
    let reopenedByName = Dictionary(grouping: reopenedWidgets, by: { $0.fieldName ?? "" })
    let textRoundTrip = reopenedByName["fullName"]?.first?.widgetStringValue == "Grace Hopper"
    let checkboxRoundTrip = reopenedByName["consent"]?.first?.buttonWidgetState == cellState(0)
    let radioWidgets = reopenedByName["status"] ?? []
    let radioYes = radioWidgets.filter { $0.buttonWidgetStateString == "yes" }.first
    let radioNo = radioWidgets.filter { $0.buttonWidgetStateString == "no" }.first
    let radioRoundTrip = radioWidgets.count == 2
        && radioYes?.buttonWidgetState == cellState(0)
        && radioNo?.buttonWidgetState == cellState(1)
    let choiceRoundTrip = reopenedByName["country"]?.first?.widgetStringValue == "Other"
    let signatureRoundTrip = reopenedByName["signature"]?.first?.widgetFieldType == PDFAnnotationWidgetSubtype.signature
    try require(textRoundTrip, "text widget value did not round-trip")
    try require(checkboxRoundTrip, "checkbox state did not round-trip")
    try require(radioRoundTrip, "radio group state did not round-trip")
    try require(choiceRoundTrip, "choice widget value did not round-trip")
    try require(signatureRoundTrip, "signature widget did not round-trip")

    let finalFixtureDigest = sha256(try Data(contentsOf: fixtureURL))
    let fixtureUnchanged = finalFixtureDigest == fixtureDigest
    try require(fixtureUnchanged, "fixture digest changed during native widget fill")

    return BenchmarkResult(
        provider: "PDFKit",
        fixtureSHA256: fixtureDigest,
        widgetCount: initialWidgets.count,
        expectedFieldNames: expectedNames,
        observedFieldNames: observedNames,
        fixtureReopen: true,
        filledReopen: true,
        textValueRoundTrip: textRoundTrip,
        checkboxStateRoundTrip: checkboxRoundTrip,
        radioStateRoundTrip: radioRoundTrip,
        choiceValueRoundTrip: choiceRoundTrip,
        signatureFieldRoundTrip: signatureRoundTrip,
        fixtureUnchanged: fixtureUnchanged,
        widgets: snapshots(reopenedWidgets)
    )
}

do {
    let arguments = try Arguments(arguments: Array(CommandLine.arguments.dropFirst()))
    let result = try run(arguments: arguments)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    FileHandle.standardOutput.write(try encoder.encode(result))
    FileHandle.standardOutput.write(Data("\n".utf8))
} catch {
    FileHandle.standardError.write(Data("PDFKit widget benchmark failed: \(error)\n".utf8))
    exit(EXIT_FAILURE)
}
