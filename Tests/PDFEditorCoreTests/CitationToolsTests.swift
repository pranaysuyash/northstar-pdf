import Foundation
import Testing
@testable import PDFEditorCore

@Suite("R-11 CitationTools")
struct CitationToolsTests {
    @Test("APA citation format")
    func apaFormat() {
        let citation = CitationGenerator.generate(
            title: "Sample Paper", author: "John Smith", date: "2024", style: .apa
        )
        #expect(citation.text.contains("Smith"))
        #expect(citation.text.contains("2024"))
        #expect(citation.text.contains("Sample Paper"))
        #expect(citation.style == .apa)
    }

    @Test("MLA citation format")
    func mlaFormat() {
        let citation = CitationGenerator.generate(
            title: "My Paper", author: "Jane Doe", date: "2023", style: .mla
        )
        #expect(citation.text.contains("Doe"))
        #expect(citation.text.contains("My Paper"))
        #expect(citation.style == .mla)
    }

    @Test("Citation with no author")
    func noAuthor() {
        let citation = CitationGenerator.generate(title: "Anonymous Work", style: .apa)
        #expect(citation.text.contains("Unknown Author"))
    }

    @Test("Citation with URL")
    func withURL() {
        let citation = CitationGenerator.generate(
            title: "Web Doc", author: "A. Author", url: "https://example.com", style: .apa
        )
        #expect(citation.markdown.contains("https://example.com"))
        #expect(citation.markdown.contains("["))
    }

    @Test("All citation styles produce output")
    func allStyles() {
        for style in CitationStyle.allCases {
            let citation = CitationGenerator.generate(title: "Test", style: style)
            #expect(!citation.text.isEmpty, "\(style.rawValue) produced empty citation")
        }
    }

    @Test("Bibliography sorts by author")
    func bibliography() {
        let entries: [(title: String, author: String?, date: String?, url: String?)] = [
            ("Z Paper", "Zoe Author", "2024", nil),
            ("A Paper", "Alice Author", "2023", nil),
            ("M Paper", "Mike Author", "2022", nil),
        ]
        let bib = CitationGenerator.bibliography(entries: entries, style: .apa)
        let alicePos = bib.range(of: "Alice")!.lowerBound
        let zoePos = bib.range(of: "Zoe")!.lowerBound
        #expect(alicePos < zoePos)
    }
}
