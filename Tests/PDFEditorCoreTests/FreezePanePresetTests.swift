import Testing
@testable import PDFEditorCore

@Suite("FreezePanePreset")
struct FreezePanePresetTests {
  // MARK: - Preset Properties

  @Test("Spreadsheet preset has correct config")
  func spreadsheetConfig() {
    let preset = FreezePanePreset.spreadsheet
    #expect(preset.config.pinnedRows == 1)
    #expect(preset.config.pinnedColumns == 1)
    #expect(preset.minRows == 3)
    #expect(preset.minColumns == 3)
    #expect(preset.icon == "tablecells")
  }

  @Test("Financial report preset has correct config")
  func financialReportConfig() {
    let preset = FreezePanePreset.financialReport
    #expect(preset.config.pinnedRows == 1)
    #expect(preset.config.pinnedColumns == 2)
    #expect(preset.minRows == 5)
    #expect(preset.minColumns == 4)
  }

  @Test("Invoice preset freezes header only")
  func invoiceConfig() {
    let preset = FreezePanePreset.invoice
    #expect(preset.config.pinnedRows == 1)
    #expect(preset.config.pinnedColumns == 0)
    #expect(preset.maxColumns == 8)
  }

  @Test("Simple list preset freezes header only")
  func simpleListConfig() {
    let preset = FreezePanePreset.simpleList
    #expect(preset.config.pinnedRows == 1)
    #expect(preset.config.pinnedColumns == 0)
    #expect(preset.maxColumns == 4)
  }

  @Test("Wide data preset freezes first column only")
  func wideDataConfig() {
    let preset = FreezePanePreset.wideData
    #expect(preset.config.pinnedRows == 0)
    #expect(preset.config.pinnedColumns == 1)
    #expect(preset.minColumns == 5)
  }

  @Test("None preset has no freeze")
  func noneConfig() {
    let preset = FreezePanePreset.none
    #expect(preset.config == .none)
  }

  // MARK: - Matching

  @Test("Spreadsheet preset matches typical spreadsheet")
  func spreadsheetMatch() {
    let preset = FreezePanePreset.spreadsheet
    let cells = ["Name", "Q1", "Q2", "Q3", "Q4",
                 "Alice", "100", "200", "150", "300",
                 "Bob", "150", "250", "200", "350"]
    let score = preset.matchScore(rows: 10, columns: 5, cellTexts: cells)
    #expect(score > 0.6)
  }

  @Test("Spreadsheet preset rejects too few rows")
  func spreadsheetRejectsTooFewRows() {
    let preset = FreezePanePreset.spreadsheet
    let score = preset.matchScore(rows: 2, columns: 5)
    #expect(score == 0)
  }

  @Test("Financial report matches financial content")
  func financialReportMatch() {
    let preset = FreezePanePreset.financialReport
    let cells = ["Category", "Q1", "Q2", "Q3", "Q4",
                 "Revenue", "1000", "1200", "1100", "1300",
                 "Expenses", "800", "900", "850", "950",
                 "Net Income", "200", "300", "250", "350"]
    let score = preset.matchScore(rows: 10, columns: 5, cellTexts: cells)
    #expect(score > 0.6)
  }

  @Test("Invoice matches price/quantity content")
  func invoiceMatch() {
    let preset = FreezePanePreset.invoice
    let cells = ["Item", "Description", "Qty", "Price", "Amount",
                 "Widget", "Blue widget", "10", "5.00", "50.00",
                 "Gadget", "Red gadget", "5", "10.00", "50.00"]
    let score = preset.matchScore(rows: 5, columns: 5, cellTexts: cells)
    #expect(score > 0.5)
  }

  @Test("Invoice rejects wide tables (> 8 columns)")
  func invoiceRejectsWide() {
    let preset = FreezePanePreset.invoice
    let score = preset.matchScore(rows: 5, columns: 10, cellTexts: ["Item", "Price"])
    #expect(score == 0)
  }

  @Test("Wide data matches 5+ column table")
  func wideDataMatch() {
    let preset = FreezePanePreset.wideData
    let score = preset.matchScore(rows: 5, columns: 6)
    #expect(score > 0.5)
  }

  @Test("Wide data rejects narrow table")
  func wideDataRejectsNarrow() {
    let preset = FreezePanePreset.wideData
    let score = preset.matchScore(rows: 5, columns: 3)
    #expect(score == 0)
  }

  @Test("Simple list matches long list with few columns")
  func simpleListMatch() {
    let preset = FreezePanePreset.simpleList
    let score = preset.matchScore(rows: 20, columns: 3)
    #expect(score > 0.5)
  }

  // MARK: - Matcher

  @Test("Matcher returns ranked results")
  func matcherRanked() {
    let matcher = FreezePanePresetMatcher()
    let cells = ["Name", "Q1", "Q2", "Q3", "Q4",
                 "Alice", "100", "200", "150", "300"]
    let results = matcher.match(rows: 10, columns: 5, cellTexts: cells)
    #expect(results.count >= 1)
    // Results should be sorted by score descending
    for i in 1..<results.count {
      #expect(results[i].score <= results[i - 1].score)
    }
  }

  @Test("Matcher bestMatch returns top result")
  func matcherBestMatch() {
    let matcher = FreezePanePresetMatcher()
    let cells = ["Item", "Description", "Qty", "Price",
                 "Widget", "Blue", "10", "5.00"]
    let best = matcher.bestMatch(rows: 5, columns: 4, cellTexts: cells)
    #expect(best != nil)
  }

  @Test("Matcher returns nil for tiny table")
  func matcherRejectsTiny() {
    let matcher = FreezePanePresetMatcher()
    let best = matcher.bestMatch(rows: 1, columns: 2, threshold: 0.3)
    #expect(best == nil)
  }

  @Test("Matcher respects threshold")
  func matcherThreshold() {
    let matcher = FreezePanePresetMatcher()
    let results = matcher.match(rows: 3, columns: 3, cellTexts: [], threshold: 0.9)
    // With no content hints and minimal structure, score should be below 0.9
    #expect(results.count <= 1)
  }

  // MARK: - All Presets

  @Test("All presets have unique IDs")
  func uniqueIDs() {
    let ids = FreezePanePreset.allPresets.map(\.id)
    #expect(ids.count == Set(ids).count)
  }

  @Test("All presets are Sendable")
  func sendable() async {
    let preset = FreezePanePreset.spreadsheet
    Task {
      let captured = preset
      #expect(captured.name == "Spreadsheet")
    }
  }
}
