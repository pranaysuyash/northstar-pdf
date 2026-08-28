import Testing
import CoreGraphics
@testable import PDFEditorCore

@Suite("ComicMode")
struct ComicModeTests {
  // MARK: - ComicPanel

  @Test("ComicPanel creates with correct fields")
  func panelCreation() {
    let panel = ComicPanel(pageIndex: 2, bounds: CGRect(x: 0, y: 0, width: 100, height: 200), index: 1)
    #expect(panel.pageIndex == 2)
    #expect(panel.index == 1)
    #expect(panel.bounds.width == 100)
    #expect(panel.id == "2-1")
  }

  // MARK: - ComicModeConfig

  @Test("Default config is LTR with panel detection")
  func defaultConfig() {
    let config = ComicModeConfig()
    #expect(config.isRTL == false)
    #expect(config.autoDetectPanels == true)
    #expect(config.showPageNumbers == true)
  }

  @Test("Manga config is RTL")
  func mangaConfig() {
    let config = ComicModeConfig.manga
    #expect(config.isRTL == true)
    #expect(config.autoDetectPanels == true)
  }

  @Test("Western config is LTR")
  func westernConfig() {
    let config = ComicModeConfig.western
    #expect(config.isRTL == false)
  }

  @Test("FullPage config disables panel detection")
  func fullPageConfig() {
    let config = ComicModeConfig.fullPage
    #expect(config.autoDetectPanels == false)
  }

  // MARK: - PanelDetector

  @Test("PanelDetector creates")
  func detectorCreation() {
    let detector = PanelDetector()
    // Just verify it doesn't crash
    _ = detector
  }

  // MARK: - ComicReadingState

  @Test("Reading state sorts panels LTR by default")
  func stateLTROrder() {
    let panels = [
      ComicPanel(pageIndex: 1, bounds: .zero, index: 2),
      ComicPanel(pageIndex: 0, bounds: .zero, index: 1),
      ComicPanel(pageIndex: 0, bounds: .zero, index: 0),
      ComicPanel(pageIndex: 1, bounds: .zero, index: 0),
    ]
    let state = ComicReadingState(panels: panels)
    #expect(state.panels.count == 4)
    // LTR: page 0 first, then page 1; within page, index 0 first
    #expect(state.panels[0].pageIndex == 0)
    #expect(state.panels[0].index == 0)
    #expect(state.panels[1].pageIndex == 0)
    #expect(state.panels[1].index == 1)
    #expect(state.panels[2].pageIndex == 1)
    #expect(state.panels[2].index == 0)
    #expect(state.panels[3].pageIndex == 1)
    #expect(state.panels[3].index == 2)
  }

  @Test("Reading state sorts panels RTL")
  func stateRTLOrder() {
    let panels = [
      ComicPanel(pageIndex: 0, bounds: .zero, index: 0),
      ComicPanel(pageIndex: 0, bounds: .zero, index: 1),
      ComicPanel(pageIndex: 1, bounds: .zero, index: 0),
      ComicPanel(pageIndex: 1, bounds: .zero, index: 1),
    ]
    let state = ComicReadingState(panels: panels, config: ComicModeConfig.manga)
    #expect(state.panels.count == 4)
    // RTL: page 1 first, then page 0; within page, index 1 first
    #expect(state.panels[0].pageIndex == 1)
    #expect(state.panels[0].index == 1)
    #expect(state.panels[1].pageIndex == 1)
    #expect(state.panels[1].index == 0)
    #expect(state.panels[2].pageIndex == 0)
    #expect(state.panels[2].index == 1)
    #expect(state.panels[3].pageIndex == 0)
    #expect(state.panels[3].index == 0)
  }

  @Test("Advance moves forward")
  func stateAdvance() {
    let panels = [
      ComicPanel(pageIndex: 0, bounds: .zero, index: 0),
      ComicPanel(pageIndex: 0, bounds: .zero, index: 1),
      ComicPanel(pageIndex: 1, bounds: .zero, index: 0),
    ]
    var state = ComicReadingState(panels: panels)
    #expect(state.currentPanel?.index == 0)
    #expect(state.advance() == true)
    #expect(state.currentPanel?.index == 1)
    #expect(state.advance() == true)
    #expect(state.currentPanel?.pageIndex == 1)
    #expect(state.advance() == false) // at end
  }

  @Test("GoBack moves backward")
  func stateGoBack() {
    let panels = [
      ComicPanel(pageIndex: 0, bounds: .zero, index: 0),
      ComicPanel(pageIndex: 0, bounds: .zero, index: 1),
    ]
    var state = ComicReadingState(panels: panels)
    state.advance()
    #expect(state.goBack() == true)
    #expect(state.currentPanel?.index == 0)
    #expect(state.goBack() == false) // at start
  }

  @Test("Jump to panel")
  func stateJump() {
    let panels = [
      ComicPanel(pageIndex: 0, bounds: .zero, index: 0),
      ComicPanel(pageIndex: 0, bounds: .zero, index: 1),
      ComicPanel(pageIndex: 1, bounds: .zero, index: 0),
    ]
    var state = ComicReadingState(panels: panels)
    state.jumpTo(panelIndex: 2)
    #expect(state.currentPanel?.pageIndex == 1)
  }

  @Test("Progress calculation")
  func stateProgress() {
    let panels = [
      ComicPanel(pageIndex: 0, bounds: .zero, index: 0),
      ComicPanel(pageIndex: 0, bounds: .zero, index: 1),
      ComicPanel(pageIndex: 0, bounds: .zero, index: 2),
    ]
    var state = ComicReadingState(panels: panels)
    #expect(state.progress > 0)
    state.advance()
    state.advance()
    #expect(state.progress == 1.0)
  }

  @Test("Total panels count")
  func stateTotalPanels() {
    let panels = [
      ComicPanel(pageIndex: 0, bounds: .zero, index: 0),
      ComicPanel(pageIndex: 1, bounds: .zero, index: 0),
    ]
    let state = ComicReadingState(panels: panels)
    #expect(state.totalPanels == 2)
  }

  @Test("Empty panels")
  func stateEmpty() {
    let state = ComicReadingState(panels: [])
    #expect(state.totalPanels == 0)
    #expect(state.currentPanel == nil)
    #expect(state.progress == 0)
  }

  // MARK: - Sendable

  @Test("ComicPanel is Sendable")
  func panelSendable() {
    let panel = ComicPanel(pageIndex: 0, bounds: .zero, index: 0)
    Task {
      let captured = panel
      #expect(captured.pageIndex == 0)
    }
  }

  @Test("ComicModeConfig is Sendable")
  func configSendable() {
    let config = ComicModeConfig.manga
    Task {
      let captured = config
      #expect(captured.isRTL == true)
    }
  }
}
