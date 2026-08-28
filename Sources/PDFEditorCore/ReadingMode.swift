import SwiftUI

/// Reading modes that optimize the presentation for the reader's context.
///
/// First principle: the same document needs different presentations depending
/// on *why* the user is reading it. A student studying wants dense text with
/// annotations visible; a reviewer skimming wants minimal chrome and fast
/// navigation; a reference reader wants stable headers and side notes.
///
/// Doctrine alignment:
/// - §3: Do things smartly — match presentation to intent
/// - §8: Capability routing — different mode = different feature set
/// - Long-term: Foundation for adaptive reading, content-aware routing
///
/// Each mode defines a bundle of display parameters, not a single toggle.
/// The view layer reads these parameters and applies them — modes are
/// data, not behavior.

// MARK: - Reading Mode

/// The four reading modes.
public enum ReadingMode: String, CaseIterable, Sendable, Identifiable {
  /// Deep reading with annotations, highlights, and dense text.
  case study = "Study"
  /// Fast scanning with minimal chrome and large navigation.
  case skim = "Skim"
  /// Stable reference layout with pinned context.
  case reference = "Reference"
  /// Review-focused with change tracking and comments prominent.
  case review = "Review"

  public var id: String { rawValue }
  public var displayName: String { rawValue }

  public var symbolName: String {
    switch self {
    case .study: return "book"
    case .skim: return "forward.frame"
    case .reference: return "pin"
    case .review: return "checkmark.circle"
    }
  }

  public var helpText: String {
    switch self {
    case .study:
      return "Deep reading — annotations visible, dense text, study aids enabled"
    case .skim:
      return "Fast scanning — minimal chrome, large page overview, quick navigation"
    case .reference:
      return "Reference layout — pinned headers, stable context, side notes visible"
    case .review:
      return "Review mode — change tracking prominent, comments visible, edit history"
    }
  }
}

// MARK: - Display Parameters

/// Concrete display parameters derived from a reading mode.
///
/// The view layer applies these directly — no mode-specific branching
/// in the UI code. This keeps the system extensible (new modes = new
/// parameter sets, no view changes).
public struct ReadingDisplayParams: Sendable {
  /// Whether to show the inspector sidebar.
  public let showInspector: Bool
  /// Whether to show the page thumbnail rail.
  public let showThumbnailRail: Bool
  /// Whether to show the toolbar.
  public let showToolbar: Bool
  /// Whether annotations/highlights are visible.
  public let showAnnotations: Bool
  /// Whether change tracking overlays are visible.
  public let showChangeTracking: Bool
  /// Extra text spacing multiplier (1.0 = normal).
  public let textSpacingMultiplier: CGFloat
  /// Background opacity for the reading area (0 = transparent, 1 = solid).
  public let backgroundOpacity: Double
  /// Whether continuous scrolling is enabled (false = page-by-page).
  public let continuousScroll: Bool
  /// Whether to show page numbers prominently.
  public let showPageNumbers: Bool
  /// Whether to show a reading progress indicator.
  public let showProgress: Bool

  // MARK: - Zoom & Navigation

  /// Default zoom level when switching to this mode (0 = fit width, >0 = absolute scale).
  public let defaultZoomLevel: Double
  /// Page fit mode on mode switch.
  public let pageFitMode: PageFitMode
  /// Scroll speed multiplier (1.0 = normal, >1 = faster, <1 = slower).
  public let scrollSpeedMultiplier: Double
  /// Whether kinetic scrolling is enabled.
  public let kineticScrolling: Bool

  // MARK: - Font Rendering

  /// Font weight adjustment (-1.0 to 1.0, 0 = normal).
  public let fontWeightAdjustment: Double
  /// Whether to use subpixel anti-aliasing.
  public let subpixelAntialiasing: Bool
  /// Minimum font size override (nil = use document default).
  public let minimumFontSize: Double?
  /// Line height multiplier independent of textSpacingMultiplier.
  public let lineHeightMultiplier: Double

  /// Derive display parameters from a reading mode.
  public static func params(for mode: ReadingMode) -> ReadingDisplayParams {
    switch mode {
    case .study:
      return ReadingDisplayParams(
        showInspector: true,
        showThumbnailRail: true,
        showToolbar: true,
        showAnnotations: true,
        showChangeTracking: false,
        textSpacingMultiplier: 1.15,
        backgroundOpacity: 0.0,
        continuousScroll: true,
        showPageNumbers: true,
        showProgress: true,
        defaultZoomLevel: 0,
        pageFitMode: .fitWidth,
        scrollSpeedMultiplier: 1.0,
        kineticScrolling: true,
        fontWeightAdjustment: 0,
        subpixelAntialiasing: true,
        minimumFontSize: nil,
        lineHeightMultiplier: 1.3
      )
    case .skim:
      return ReadingDisplayParams(
        showInspector: false,
        showThumbnailRail: false,
        showToolbar: false,
        showAnnotations: false,
        showChangeTracking: false,
        textSpacingMultiplier: 1.0,
        backgroundOpacity: 0.0,
        continuousScroll: true,
        showPageNumbers: true,
        showProgress: true,
        defaultZoomLevel: 0,
        pageFitMode: .fitPage,
        scrollSpeedMultiplier: 2.0,
        kineticScrolling: true,
        fontWeightAdjustment: 0.1,
        subpixelAntialiasing: false,
        minimumFontSize: nil,
        lineHeightMultiplier: 1.0
      )
    case .reference:
      return ReadingDisplayParams(
        showInspector: true,
        showThumbnailRail: true,
        showToolbar: true,
        showAnnotations: true,
        showChangeTracking: false,
        textSpacingMultiplier: 1.05,
        backgroundOpacity: 0.02,
        continuousScroll: true,
        showPageNumbers: true,
        showProgress: false,
        defaultZoomLevel: 0,
        pageFitMode: .fitWidth,
        scrollSpeedMultiplier: 0.8,
        kineticScrolling: false,
        fontWeightAdjustment: 0,
        subpixelAntialiasing: true,
        minimumFontSize: nil,
        lineHeightMultiplier: 1.2
      )
    case .review:
      return ReadingDisplayParams(
        showInspector: true,
        showThumbnailRail: true,
        showToolbar: true,
        showAnnotations: true,
        showChangeTracking: true,
        textSpacingMultiplier: 1.0,
        backgroundOpacity: 0.0,
        continuousScroll: true,
        showPageNumbers: true,
        showProgress: true,
        defaultZoomLevel: 0,
        pageFitMode: .fitWidth,
        scrollSpeedMultiplier: 1.0,
        kineticScrolling: true,
        fontWeightAdjustment: 0,
        subpixelAntialiasing: true,
        minimumFontSize: nil,
        lineHeightMultiplier: 1.25
      )
    }
  }
}

// MARK: - Page Fit Mode

/// How pages fit in the viewport.
public enum PageFitMode: String, Codable, Sendable, CaseIterable {
  /// Zoom to fill the viewport width.
  case fitWidth
  /// Zoom to fit the entire page.
  case fitPage
  /// Zoom to a specific scale (use defaultZoomLevel).
  case absolute
  /// Zoom to fill height (for landscape pages).
  case fitHeight

  public var displayName: String {
    switch self {
    case .fitWidth: return "Fit Width"
    case .fitPage: return "Fit Page"
    case .absolute: return "Actual Size"
    case .fitHeight: return "Fit Height"
    }
  }

  public var symbolName: String {
    switch self {
    case .fitWidth: return "rectangle.righthalf.inward.filled"
    case .fitPage: return "rectangle.inset.filled"
    case .absolute: return "1.magnifyingglass"
    case .fitHeight: return "rectangle.bottomhalf.inward.filled"
    }
  }
}
