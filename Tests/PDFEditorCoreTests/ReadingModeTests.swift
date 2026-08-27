import Testing
import SwiftUI
@testable import PDFEditorCore

@Suite("ReadingMode")
struct ReadingModeTests {
  // MARK: - Enum

  @Test("ReadingMode has all 4 cases")
  func allCasesExist() {
    #expect(ReadingMode.allCases.count == 4)
    #expect(ReadingMode.allCases.contains(.study))
    #expect(ReadingMode.allCases.contains(.skim))
    #expect(ReadingMode.allCases.contains(.reference))
    #expect(ReadingMode.allCases.contains(.review))
  }

  @Test("ReadingMode raw values round-trip")
  func rawValuesRoundTrip() {
    for mode in ReadingMode.allCases {
      #expect(ReadingMode(rawValue: mode.rawValue) == mode)
    }
  }

  @Test("ReadingMode display names match raw values")
  func displayNames() {
    #expect(ReadingMode.study.displayName == "Study")
    #expect(ReadingMode.skim.displayName == "Skim")
    #expect(ReadingMode.reference.displayName == "Reference")
    #expect(ReadingMode.review.displayName == "Review")
  }

  @Test("ReadingMode symbol names are distinct")
  func symbolNamesDistinct() {
    let symbols = Set(ReadingMode.allCases.map(\.symbolName))
    #expect(symbols.count == ReadingMode.allCases.count)
  }

  @Test("ReadingMode help text is non-empty")
  func helpTextNonEmpty() {
    for mode in ReadingMode.allCases {
      #expect(!mode.helpText.isEmpty)
    }
  }

  // MARK: - Display Parameters

  @Test("Study mode: annotations visible, inspector on, dense text")
  func studyParams() {
    let p = ReadingDisplayParams.params(for: .study)
    #expect(p.showAnnotations == true)
    #expect(p.showInspector == true)
    #expect(p.showThumbnailRail == true)
    #expect(p.showToolbar == true)
    #expect(p.showChangeTracking == false)
    #expect(p.textSpacingMultiplier > 1.0)
    #expect(p.continuousScroll == true)
    #expect(p.showProgress == true)
  }

  @Test("Skim mode: minimal chrome, no inspector, no annotations")
  func skimParams() {
    let p = ReadingDisplayParams.params(for: .skim)
    #expect(p.showInspector == false)
    #expect(p.showThumbnailRail == false)
    #expect(p.showToolbar == false)
    #expect(p.showAnnotations == false)
    #expect(p.showChangeTracking == false)
    #expect(p.textSpacingMultiplier == 1.0)
    #expect(p.continuousScroll == true)
    #expect(p.showPageNumbers == true)
  }

  @Test("Reference mode: inspector on, annotations on, slight spacing")
  func referenceParams() {
    let p = ReadingDisplayParams.params(for: .reference)
    #expect(p.showInspector == true)
    #expect(p.showThumbnailRail == true)
    #expect(p.showAnnotations == true)
    #expect(p.textSpacingMultiplier > 1.0)
    #expect(p.textSpacingMultiplier < 1.2)
    #expect(p.backgroundOpacity > 0)
    #expect(p.showProgress == false)
  }

  @Test("Review mode: change tracking on, all chrome visible")
  func reviewParams() {
    let p = ReadingDisplayParams.params(for: .review)
    #expect(p.showChangeTracking == true)
    #expect(p.showAnnotations == true)
    #expect(p.showInspector == true)
    #expect(p.showThumbnailRail == true)
    #expect(p.showToolbar == true)
    #expect(p.showProgress == true)
  }

  @Test("Each mode produces unique params")
  func uniqueParams() {
    let allParams = ReadingMode.allCases.map { ReadingDisplayParams.params(for: $0) }
    // At least skim should differ from study (no inspector, no toolbar)
    let study = ReadingDisplayParams.params(for: .study)
    let skim = ReadingDisplayParams.params(for: .skim)
    #expect(skim.showInspector != study.showInspector)
    #expect(skim.showToolbar != study.showToolbar)
    #expect(skim.showAnnotations != study.showAnnotations)
  }

  // MARK: - Sendable

  @Test("ReadingMode is Sendable")
  func sendableCompliance() {
    let mode: ReadingMode = .reference
    Task {
      let captured = mode
      #expect(captured == .reference)
    }
  }

  @Test("ReadingDisplayParams is Sendable")
  func paramsSendable() {
    let params = ReadingDisplayParams.params(for: .study)
    Task {
      let captured = params
      #expect(captured.showInspector == true)
    }
  }
}
