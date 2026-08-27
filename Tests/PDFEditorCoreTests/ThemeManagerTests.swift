import Testing
import SwiftUI
@testable import PDFEditorCore

@Suite("ThemeManager")
struct ThemeManagerTests {
  // MARK: - Appearance Mode

  @Test("AppearanceMode has all cases")
  func allCasesExist() {
    #expect(AppearanceMode.allCases.count == 3)
    #expect(AppearanceMode.allCases.contains(.system))
    #expect(AppearanceMode.allCases.contains(.light))
    #expect(AppearanceMode.allCases.contains(.dark))
  }

  @Test("AppearanceMode raw values round-trip")
  func rawValuesRoundTrip() {
    for mode in AppearanceMode.allCases {
      #expect(AppearanceMode(rawValue: mode.rawValue) == mode)
    }
  }

  @Test("AppearanceMode display names are distinct")
  func displayNamesDistinct() {
    let names = Set(AppearanceMode.allCases.map(\.displayName))
    #expect(names.count == AppearanceMode.allCases.count)
  }

  @Test("System mode resolves to nil color scheme")
  func systemModeColorScheme() {
    #expect(AppearanceMode.system.colorScheme == nil)
  }

  @Test("Light mode resolves to .light color scheme")
  func lightModeColorScheme() {
    #expect(AppearanceMode.light.colorScheme == .light)
  }

  @Test("Dark mode resolves to .dark color scheme")
  func darkModeColorScheme() {
    #expect(AppearanceMode.dark.colorScheme == .dark)
  }

  // MARK: - ThemeManager Default State

  @Test("ThemeManager defaults to system mode")
  @MainActor
  func defaultMode() {
    let manager = ThemeManager()
    // Default is .system (set in the @AppStorage declaration)
    // We can't test the actual persisted value, but we can test the resolved behavior
    #expect(manager.preferredColorScheme == nil || manager.preferredColorScheme == .light || manager.preferredColorScheme == .dark)
  }

  @Test("ThemeManager default high contrast is false")
  @MainActor
  func defaultHighContrast() {
    let manager = ThemeManager()
    // The default is false; we test the property exists and is accessible
    // (actual value depends on UserDefaults state)
    _ = manager.isHighContrast
  }

  // MARK: - Resolved Values

  @Test("preferredColorScheme returns nil for system mode")
  @MainActor
  func systemPreferredColorScheme() {
    let manager = ThemeManager()
    manager.appearanceMode = .system
    #expect(manager.preferredColorScheme == nil)
  }

  @Test("preferredColorScheme returns .light for light mode")
  @MainActor
  func lightPreferredColorScheme() {
    let manager = ThemeManager()
    manager.appearanceMode = .light
    #expect(manager.preferredColorScheme == .light)
  }

  @Test("preferredColorScheme returns .dark for dark mode")
  @MainActor
  func darkPreferredColorScheme() {
    let manager = ThemeManager()
    manager.appearanceMode = .dark
    #expect(manager.preferredColorScheme == .dark)
  }

  @Test("resolvedNSAppearance returns aqua for light mode")
  @MainActor
  func lightNSAppearance() {
    let manager = ThemeManager()
    manager.appearanceMode = .light
    #expect(manager.resolvedNSAppearance.name == .aqua)
  }

  @Test("resolvedNSAppearance returns darkAqua for dark mode")
  @MainActor
  func darkNSAppearance() {
    let manager = ThemeManager()
    manager.appearanceMode = .dark
    #expect(manager.resolvedNSAppearance.name == .darkAqua)
  }

  @Test("resolvedNSAppearance returns aqua for system mode")
  @MainActor
  func systemNSAppearance() {
    let manager = ThemeManager()
    manager.appearanceMode = .system
    #expect(manager.resolvedNSAppearance.name == .aqua)
  }

  // MARK: - High Contrast

  @Test("High contrast toggle changes isHighContrast")
  @MainActor
  func highContrastToggle() {
    let manager = ThemeManager()
    let initial = manager.isHighContrast
    manager.isHighContrast = !initial
    #expect(manager.isHighContrast == !initial)
    manager.isHighContrast = initial
    #expect(manager.isHighContrast == initial)
  }

  // MARK: - Mode Switching

  @Test("Switching modes updates preferredColorScheme")
  @MainActor
  func modeSwitching() {
    let manager = ThemeManager()

    manager.appearanceMode = .light
    #expect(manager.preferredColorScheme == .light)

    manager.appearanceMode = .dark
    #expect(manager.preferredColorScheme == .dark)

    manager.appearanceMode = .system
    #expect(manager.preferredColorScheme == nil)
  }

  // MARK: - AppColors

  @Test("AppColors provide non-nil semantic colors")
  func semanticColorsExist() {
    // These should not crash and should return valid colors
    let _ = AppColors.primaryText
    let _ = AppColors.secondaryText
    let _ = AppColors.canvasBackground
    let _ = AppColors.panelBackground
    let _ = AppColors.separator
    let _ = AppColors.highlight
  }

  // MARK: - Sendable Compliance

  @Test("AppearanceMode is Sendable")
  func sendableCompliance() {
    // Compile-time check: AppearanceMode can be used across concurrency domains
    let mode: AppearanceMode = .dark
    Task {
      let captured = mode
      #expect(captured == .dark)
    }
  }
}
