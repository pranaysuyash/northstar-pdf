import AppKit
import SwiftUI

/// App-wide appearance management.
///
/// First principle: respect the user's system setting by default, let them
/// override per-app.  High-contrast mode is orthogonal to light/dark — it
/// thickens borders, raises contrast ratios, and adds focus indicators.
///
/// Doctrine alignment:
/// - §3: Do things smartly — follow the system, don't fight it
/// - §5: Evidence-based — store preference, report resolved appearance
/// - §8: Capability routing — appearance is a capability the user activates
///
/// Persistence: `@AppStorage` keyed to `UserDefaults`, survives relaunch.

// MARK: - Appearance Mode

/// User-selectable appearance preference.
public enum AppearanceMode: String, CaseIterable, Sendable {
  /// Follow system appearance (default).
  case system
  /// Force light appearance.
  case light
  /// Force dark appearance.
  case dark

  public var displayName: String {
    switch self {
    case .system: return "System"
    case .light:  return "Light"
    case .dark:   return "Dark"
    }
  }

  /// Resolved SwiftUI `ColorScheme`, or `nil` for system (let SwiftUI decide).
  public var colorScheme: ColorScheme? {
    switch self {
    case .system: return nil
    case .light:  return .light
    case .dark:   return .dark
    }
  }
}

// MARK: - Theme Manager

/// Centralized theme state, observable from SwiftUI views.
///
/// Usage:
/// ```swift
/// @EnvironmentObject var themeManager: ThemeManager
/// ```
///
/// Persistence:
/// - `appearanceMode`: stored in `UserDefaults` via `@AppStorage`
/// - `isHighContrast`: stored in `UserDefaults` via `@AppStorage`
///
/// Both properties are `@Published` so views update reactively.
@MainActor
public final class ThemeManager: ObservableObject {
  // MARK: - Published State

  /// User's appearance preference.
  @AppStorage("appearanceMode") public var appearanceMode: AppearanceMode = .system {
    didSet { objectWillChange.send() }
  }

  /// Whether high-contrast mode is active (thicker borders, stronger focus rings).
  @AppStorage("isHighContrast") public var isHighContrast: Bool = false {
    didSet { objectWillChange.send() }
  }

  // MARK: - Resolved Values

  /// The `ColorScheme?` to apply via `.preferredColorScheme()`.
  /// `nil` means "follow system".
  public var preferredColorScheme: ColorScheme? {
    appearanceMode.colorScheme
  }

  /// The resolved `NSAppearance` for AppKit surfaces that need it.
  public var resolvedNSAppearance: NSAppearance {
    switch appearanceMode {
    case .system:
      return NSAppearance(named: .aqua)!
    case .light:
      return NSAppearance(named: .aqua)!
    case .dark:
      return NSAppearance(named: .darkAqua)!
    }
  }

  /// Whether the current effective appearance is dark.
  ///
  /// For system mode, queries the current effective appearance of the
  /// main screen. For manual modes, returns based on the selection.
  public var isDarkMode: Bool {
    switch appearanceMode {
    case .dark:
      return true
    case .light:
      return false
    case .system:
      return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
  }

  // MARK: - Initialization

  public init() {}
}

// MARK: - SwiftUI View Extension

// MARK: - Custom Environment Key

private struct IsHighContrastThemeKey: EnvironmentKey {
  static let defaultValue = false
}

extension EnvironmentValues {
  /// Whether high-contrast theme mode is active.
  public var isHighContrastTheme: Bool {
    get { self[IsHighContrastThemeKey.self] }
    set { self[IsHighContrastThemeKey.self] = newValue }
  }
}

extension View {
  /// Apply the app's theme (color scheme + high contrast).
  ///
  /// Call this once on the root view:
  /// ```swift
  /// ContentView()
  ///   .environmentObject(ThemeManager.shared)
  ///   .applyTheme()
  /// ```
  @MainActor
  @ViewBuilder
  public func applyTheme(using themeManager: ThemeManager) -> some View {
    self
      .preferredColorScheme(themeManager.preferredColorScheme)
      .environment(\.isHighContrastTheme, themeManager.isHighContrast)
  }
}

// MARK: - Hardcoded Color Fix

/// Semantic colors that adapt to light/dark automatically.
///
/// Use these instead of `NSColor.black` / `NSColor.white` in rendering code.
public enum AppColors {
  /// Primary text color (adapts to light/dark).
  public static var primaryText: NSColor {
    .labelColor
  }

  /// Secondary text color.
  public static var secondaryText: NSColor {
    .secondaryLabelColor
  }

  /// Background color for the canvas.
  public static var canvasBackground: NSColor {
    .windowBackgroundColor
  }

  /// Background color for panels / inspectors.
  public static var panelBackground: NSColor {
    .controlBackgroundColor
  }

  /// Separator / border color.
  public static var separator: NSColor {
    .separatorColor
  }

  /// Fill for search highlights, selection backgrounds.
  public static var highlight: NSColor {
    .controlAccentColor.withAlphaComponent(0.2)
  }
}
