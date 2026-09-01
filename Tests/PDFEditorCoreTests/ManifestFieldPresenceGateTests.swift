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
    "/Users/pranay/Projects/pdf_editor/benchmark/results/corpus-sweep-2026-08-25/manifest.json")
  private static let fixtureDir = "/Users/pranay/Projects/pdf_editor/benchmark/results/corpus-sweep-2026-08-25"

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

  @Test("All fixtures match manifest field presence expectations")
  func fieldPresenceMatchesManifest() throws {
    let data = try Data(contentsOf: Self.manifestURL)
    let manifest = try JSONDecoder().decode(Manifest.self, from: data)

    var mismatches: [String] = []

    for (name, entry) in manifest.fixtures {
      let path = "\(Self.fixtureDir)/\(name)"
      guard FileManager.default.fileExists(atPath: path),
            let doc = PDFDocument(url: URL(fileURLWithPath: path)) else {
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

      // Widgets
      let expectedWidgets = expected.widgetCount ?? expected.acroFormFieldCount
      if let expectedWidgets, liveWidgets != expectedWidgets {
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
