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

  // MARK: - Annotation Overlay Gating

  @Test("Skim mode hides annotations overlay")
  func skimHidesAnnotations() {
    let p = ReadingDisplayParams.params(for: .skim)
    #expect(p.showAnnotations == false)
    // All other modes show annotations
    for mode in ReadingMode.allCases where mode != .skim {
      let params = ReadingDisplayParams.params(for: mode)
      #expect(params.showAnnotations == true, "\(mode.displayName) should show annotations")
    }
  }

  @Test("Text spacing varies by mode")
  func textSpacingByMode() {
    let study = ReadingDisplayParams.params(for: .study)
    let skim = ReadingDisplayParams.params(for: .skim)
    let reference = ReadingDisplayParams.params(for: .reference)
    let review = ReadingDisplayParams.params(for: .review)
    #expect(study.textSpacingMultiplier == 1.15)
    #expect(skim.textSpacingMultiplier == 1.0)
    #expect(reference.textSpacingMultiplier == 1.05)
    #expect(review.textSpacingMultiplier == 1.0)
  }

  // MARK: - Zoom & Navigation Presets

  @Test("Skim mode uses fit page and fast scroll")
  func skimZoomPreset() {
    let p = ReadingDisplayParams.params(for: .skim)
    #expect(p.pageFitMode == .fitPage)
    #expect(p.scrollSpeedMultiplier == 2.0)
    #expect(p.kineticScrolling == true)
  }

  @Test("Reference mode uses fit width and slow scroll")
  func referenceZoomPreset() {
    let p = ReadingDisplayParams.params(for: .reference)
    #expect(p.pageFitMode == .fitWidth)
    #expect(p.scrollSpeedMultiplier == 0.8)
    #expect(p.kineticScrolling == false)
  }

  @Test("Study mode uses fit width and normal scroll")
  func studyZoomPreset() {
    let p = ReadingDisplayParams.params(for: .study)
    #expect(p.pageFitMode == .fitWidth)
    #expect(p.scrollSpeedMultiplier == 1.0)
    #expect(p.kineticScrolling == true)
  }

  // MARK: - Font Rendering Presets

  @Test("Skim mode uses heavier font and no subpixel")
  func skimFontPreset() {
    let p = ReadingDisplayParams.params(for: .skim)
    #expect(p.fontWeightAdjustment > 0)
    #expect(p.subpixelAntialiasing == false)
    #expect(p.lineHeightMultiplier == 1.0)
  }

  @Test("Study mode uses expanded line height")
  func studyFontPreset() {
    let p = ReadingDisplayParams.params(for: .study)
    #expect(p.lineHeightMultiplier == 1.3)
    #expect(p.fontWeightAdjustment == 0)
  }

  @Test("All modes use fit-width except skim")
  func pageFitModeConsistency() {
    for mode in ReadingMode.allCases {
      let p = ReadingDisplayParams.params(for: mode)
      if mode == .skim {
        #expect(p.pageFitMode == .fitPage)
      } else {
        #expect(p.pageFitMode == .fitWidth, "\(mode.displayName) should use fitWidth")
      }
    }
  }

  @Test("All modes have scroll speed multiplier > 0")
  func scrollSpeedPositive() {
    for mode in ReadingMode.allCases {
      let p = ReadingDisplayParams.params(for: mode)
      #expect(p.scrollSpeedMultiplier > 0, "\(mode.displayName) scroll speed must be positive")
    }
  }

  // MARK: - PageFitMode

  @Test("PageFitMode has all cases")
  func pageFitModeCases() {
    #expect(PageFitMode.allCases.count == 4)
    #expect(PageFitMode.fitWidth.displayName == "Fit Width")
    #expect(PageFitMode.fitPage.displayName == "Fit Page")
    #expect(PageFitMode.absolute.displayName == "Actual Size")
    #expect(PageFitMode.fitHeight.displayName == "Fit Height")
  }

  @Test("Reference mode has yellow background tint")
  func referenceBackgroundTint() {
    let p = ReadingDisplayParams.params(for: .reference)
    #expect(p.backgroundOpacity > 0)
    // Other modes have no background
    for mode in ReadingMode.allCases where mode != .reference {
      let params = ReadingDisplayParams.params(for: mode)
      #expect(params.backgroundOpacity == 0.0, "\(mode.displayName) should have no background tint")
    }
  }

  @Test("Reference mode hides progress bar")
  func referenceHidesProgress() {
    let p = ReadingDisplayParams.params(for: .reference)
    #expect(p.showProgress == false)
    // All other modes show progress
    for mode in ReadingMode.allCases where mode != .reference {
      let params = ReadingDisplayParams.params(for: mode)
      #expect(params.showProgress == true, "\(mode.displayName) should show progress")
    }
  }

  // MARK: - Keyboard Shortcut Mapping

  @Test("Reading modes have defined shortcut order")
  func shortcutOrder() {
    let modes = ReadingMode.allCases
    #expect(modes.count == 4)
    // Cmd+1=Study, Cmd+2=Skim, Cmd+3=Reference, Cmd+4=Review
    #expect(modes[0] == .study)
    #expect(modes[1] == .skim)
    #expect(modes[2] == .reference)
    #expect(modes[3] == .review)
  }
}
