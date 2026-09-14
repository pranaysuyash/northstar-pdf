import Foundation
import Testing
import PDFKit
@testable import PDFEditorCore

/// CI gate: verifies that the corpus-sweep manifest's field presence
/// expectations match what PDFKit actually sees in each fixture.
///
/// This catches name-vs-structure inference errors (the class of bug where
/// a fixture's expected fields were inferred from its filename rather than
/// its actual PDF structure). Every assertion here is backed by live PDFKit
/// inspection of the on-disk fixture.
///
/// Doctrine alignment:
/// - §2 Truth taxonomy — expected values are Verified by live inspection
/// - §5 Evidence-based — gate fails on any structural mismatch
/// - §10 Failure — hard negatives and structural mismatches are the constraint
@Suite("Manifest Field Presence Gate")
struct ManifestFieldPresenceGate {

  private static let manifestURL = URL(fileURLWithPath:
    "\(TestRepoRoot.prefix)benchmark/results/corpus-sweep-2026-08-25/manifest.json")
  private static let fixtureDir = "\(TestRepoRoot.prefix)benchmark/results/corpus-sweep-2026-08-25"

  private struct ManifestFixture: Decodable {
    let expected: Expected?
    struct Expected: Decodable {
      let pages: Int?
      let acroFormFieldCount: Int?
      let widgetCount: Int?
      let annotationCount: Int?
      let textChars: Int?
    }
  }

  private struct Manifest: Decodable {
    let fixtures: [String: ManifestFixture]
  }

  /// Counts AcroForm field-tree entries with pikepdf semantics: every
  /// indirect ref in /Fields, recursing into /Kids, cycle-safe. This is the
  /// quantity the manifest's `acroFormFieldCount` records (the mjs generator
  /// computes it from `af.get('/Fields')` via pikepdf).
  private static func acroFormFieldTreeCount(_ data: Data) -> Int? {
    guard let xrefOffset = try? PDFIncrementalFormWriter.findLastStartxrefOffset(data),
          let xref = try? PDFIncrementalFormWriter.parseXref(data, offset: xrefOffset),
          let rootToken = xref.trailer["/Root"],
          let catalogNumber = PDFIncrementalFormWriter.refObjectNumber(rootToken),
          let (_, catalogText) = try? PDFIncrementalFormWriter.objectSpan(
            data, xref: xref, objectNumber: catalogNumber),
          let acroFormToken = PDFIncrementalFormWriter.valueOfKey("/AcroForm", in: catalogText),
          let acroFormNumber = PDFIncrementalFormWriter.refObjectNumber(acroFormToken),
          let (_, acroFormText) = try? PDFIncrementalFormWriter.objectSpan(
            data, xref: xref, objectNumber: acroFormNumber),
          let fieldsToken = PDFIncrementalFormWriter.valueOfKey("/Fields", in: acroFormText)
    else { return nil }
    var count = 0
    var visited: Set<Int> = []
    func countField(_ objectNumber: Int) {
      guard !visited.contains(objectNumber) else { return }
      visited.insert(objectNumber)
      count += 1
      guard let (_, text) = try? PDFIncrementalFormWriter.objectSpan(
        data, xref: xref, objectNumber: objectNumber),
        let kidsToken = PDFIncrementalFormWriter.valueOfKey("/Kids", in: text)
      else { return }
      for kid in PDFIncrementalFormWriter.arrayRefs(kidsToken) {
        if let kidNumber = PDFIncrementalFormWriter.refObjectNumber(kid) {
          countField(kidNumber)
        }
      }
    }
    for ref in PDFIncrementalFormWriter.arrayRefs(fieldsToken) {
      if let number = PDFIncrementalFormWriter.refObjectNumber(ref) {
        countField(number)
      }
    }
    return count
  }

  @Test("All fixtures match manifest field presence expectations")
  func fieldPresenceMatchesManifest() throws {
    let data = try Data(contentsOf: Self.manifestURL)
    let manifest = try JSONDecoder().decode(Manifest.self, from: data)

    var mismatches: [String] = []

    for (name, entry) in manifest.fixtures {
      let path = "\(Self.fixtureDir)/\(name)"
      guard FileManager.default.fileExists(atPath: path),
            let doc = PDFDocument(url: URL(fileURLWithPath: path)),
            let fixtureData = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
        mismatches.append("\(name): cannot open")
        continue
      }

      guard let expected = entry.expected else { continue }

      // Count live widgets and annotations
      var liveWidgets = 0
      var liveAnnotations = 0
      var liveChars = 0
      for pi in 0..<doc.pageCount {
        guard let page = doc.page(at: pi) else { continue }
        for annotation in page.annotations {
          if (annotation.type ?? "") == "Widget" {
            liveWidgets += 1
          } else {
            liveAnnotations += 1
          }
        }
        liveChars += page.numberOfCharacters
      }

      // Pages
      if let expectedPages = expected.pages, doc.pageCount != expectedPages {
        mismatches.append("\(name): pages expected=\(expectedPages) actual=\(doc.pageCount)")
      }

      // AcroForm field count: pikepdf field-tree semantics (the quantity the
      // generator records), NOT the PDFKit page-widget count. On fixtures
      // whose AcroForm was rebuilt over the base form (Observed: xfa-hybrid,
      // /Fields = [hybridField]), page annotations survive as widgets the
      // field tree no longer references — comparing across those semantics
      // produced a permanent phantom mismatch (widgets expected=1 actual=6).
      if let expectedFields = expected.acroFormFieldCount {
        let actualFields = Self.acroFormFieldTreeCount(fixtureData)
        if actualFields != expectedFields {
          mismatches.append(
            "\(name): acroFormFieldCount expected=\(expectedFields) "
            + "actual=\(actualFields.map(String.init) ?? "unparseable") (field-tree semantics)")
        }
      }

      // Widgets: only compared when the manifest states an explicit
      // widgetCount — acroFormFieldCount is a different quantity.
      if let expectedWidgets = expected.widgetCount, liveWidgets != expectedWidgets {
        mismatches.append("\(name): widgets expected=\(expectedWidgets) actual=\(liveWidgets)")
      }

      // Annotations
      if let expectedAnnots = expected.annotationCount, liveAnnotations != expectedAnnots {
        mismatches.append("\(name): annotations expected=\(expectedAnnots) actual=\(liveAnnotations)")
      }

      // Text chars (approximate — allow ±10% tolerance for encoding differences)
      if let expectedChars = expected.textChars, expectedChars > 0 {
        let ratio = Double(liveChars) / Double(expectedChars)
        if ratio < 0.9 || ratio > 1.1 {
          mismatches.append("\(name): textChars expected≈\(expectedChars) actual=\(liveChars)")
        }
      }
    }

    if !mismatches.isEmpty {
      for m in mismatches {
        Issue.record("Field presence mismatch: \(m)")
      }
    }
    #expect(mismatches.isEmpty, "Manifest field presence gate: \(mismatches.count) mismatches")
  }
}
