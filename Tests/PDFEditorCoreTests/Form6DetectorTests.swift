import CoreGraphics
import Darwin
import Foundation
import PDFKit
import Testing
@testable import PDFEditorCore

@Suite("Form 6 Detector Gate")
struct Form6DetectorTests {

  private let formURL = URL(fileURLWithPath: "/Users/pranay/Projects/pdf_editor/benchmark/results/form6-voter-application.pdf")
  private let provider = PDFKitProvider()

  @Test("Form 6 suppresses table rules slicing printed text in Section 7(b)")
  func tableRulesSuppressed() throws {
    guard FileManager.default.fileExists(atPath: formURL.path) else {
      Issue.record("Form 6 fixture not found at \(formURL.path)")
      return
    }
    let inspection = try provider.inspect(url: formURL, password: nil)
    #expect(inspection.pages.count == 2)

    let page0Candidates = inspection.candidates.filter { $0.pageIndex == 0 }

    // Verify no candidates slice horizontally through Section 7(b) table text
    let badTableKeywords = [
      "birth certificate issued",
      "competent local body",
      "pan card",
      "indian passport"
    ]


    for candidate in page0Candidates {
      let label = (candidate.labelText ?? "").lowercased()
      for bad in badTableKeywords {
        #expect(!label.contains(bad), "Candidate should not slice through table row: '\(bad)'")
      }
    }
  }

  @Test("Form 6 suppresses statutory declaration sentences from suggestions")
  func statutoryProseSuppressed() throws {
    guard FileManager.default.fileExists(atPath: formURL.path) else { return }
    let inspection = try provider.inspect(url: formURL, password: nil)

    for candidate in inspection.candidates {
      let text = candidate.labelText ?? ""
      #expect(text.count <= 55, "Candidate label should be concise, not prose: '\(text)'")
      let lower = text.lowercased()
      #expect(!lower.hasPrefix("i submit"), "Declaration prose must not be a field label: '\(text)'")
      #expect(!lower.contains("electoral roll"), "Declaration prose must not be a field label: '\(text)'")
      #expect(!lower.contains("punishable under"), "Disclaimer prose must not be a field label: '\(text)'")
    }
  }

  @Test("Form 6 reconstructs stroked character grids and checkboxes")
  func characterGridsAndCheckboxesReconstructed() throws {
    guard FileManager.default.fileExists(atPath: formURL.path) else { return }
    let inspection = try provider.inspect(url: formURL, password: nil)

    let page0Candidates = inspection.candidates.filter { $0.pageIndex == 0 }

    // Verify presence of characterGrid candidate(s)
    let gridCandidates = page0Candidates.filter { $0.entryMode == CandidateEntryMode.characterGrid }
    #expect(!gridCandidates.isEmpty, "Form 6 must detect character grid candidates from stroked lines")

    // Verify presence of checkbox candidate(s)
    let checkboxCandidates = page0Candidates.filter { $0.entryMode == CandidateEntryMode.checkbox }
    #expect(!checkboxCandidates.isEmpty, "Form 6 must detect checkbox candidates")

    for cb in checkboxCandidates {
      let w = Double(cb.bounds.width)
      let h = Double(cb.bounds.height)
      let diff = fabs(w - h)
      let maxAllowed = max(w * 0.45, 4.0)
      #expect(diff <= maxAllowed, "Checkbox candidate bounds must anchor to square")
    }
  }
}
