import Foundation
import PDFKit
import Testing
@testable import PDFEditorCore

/// Generated choice-fixture hardening (2026-09-06).
///
/// `benchmark/datasets/generate_choice_fixtures.py` produces 7 single-page
/// PDFs whose choice fields (`/FT /Ch`) cover genuinely distinct `/Opt`
/// vocabularies — beyond any choice coverage in the base parity corpus.
/// `/Opt` is the choice-field options array (PDF 32000-1 §12.7.5.4,
/// Table 247); the radio equivalent (kid /AS + /AP state names) is covered
/// separately by GeneratedRadioFixtures.
///
///   1. dropdown_strings.pdf         — region: ["US","EU","APAC"], /V=EU
///   2. dropdown_pairs.pdf           — ship_method: [export, display] pairs
///   3. dropdown_numeric.pdf         — tier: ["0","1","2","3"]
///   4. choice_hierarchical.pdf      — order.priority + order.warehouse
///   5. choice_multi_field.pdf       — 3 fields on one page, combo included
///   6. dropdown_empty_selection.pdf — /Opt present, no /V (empty state)
///   7. combo_editable.pdf           — combo (Ff bit 18) with /V ∉ /Opt
///
/// These tests assert the production claim end-to-end: structural read
/// (walkAcroForm exposes /Opt + /V), the IncrementalWriter write path with
/// PDFKit cross-read after reopen, and the pdf-lib lane where the npm
/// dependency is installed.
@Suite("GeneratedChoiceFixtures")
struct GeneratedChoiceFixtureTests {

    private static var projectRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func fixtureURL(_ name: String) -> URL {
        URL(fileURLWithPath: projectRoot.path + "/benchmark/datasets/choice-fixtures/\(name)")
    }

    /// (fixture file, field name, current /V, /Opt exports, displays, combo).
    /// `displays` is nil when display strings equal the exports (plain /Opt);
    /// pair-form /Opt ([export, display]) carries the display list here.
    /// Matches the generator's `main()` exactly — a mismatch here means the
    /// generator was edited without updating this table.
    static let fixtures: [(
        file: String, field: String, selected: String?, options: [String],
        displays: [String]?, combo: Bool
    )] = [
        ("dropdown_strings.pdf", "region", "EU", ["US", "EU", "APAC"], nil, false),
        ("dropdown_pairs.pdf", "ship_method", "air", ["ground", "air", "freight"],
         ["Ground (5-7 days)", "Air (1-2 days)", "Freight (quote)"], false),
        ("dropdown_numeric.pdf", "tier", "2", ["0", "1", "2", "3"], nil, false),
        ("choice_hierarchical.pdf", "order.priority", "Medium", ["High", "Medium", "Low"], nil, false),
        ("choice_hierarchical.pdf", "order.warehouse", "West", ["West", "East"], nil, false),
        ("choice_multi_field.pdf", "country", "CA", ["US", "CA", "MX"], nil, false),
        ("choice_multi_field.pdf", "currency", "CAD", ["USD", "CAD", "EUR", "MXN"], nil, false),
        ("choice_multi_field.pdf", "custom_code", "A2", ["A1", "A2"], nil, true),
        ("dropdown_empty_selection.pdf", "selection", nil, ["Alpha", "Beta", "Gamma"], nil, false),
        ("combo_editable.pdf", "custom_entry", "CustomText", ["Preset1", "Preset2"], nil, true),
    ]

    /// Viewer-facing string for an export: the display value for pair-form
    /// /Opt, otherwise the export itself. PDFKit's widgetStringValue exposes
    /// exactly this.
    private static func displayOf(
        _ fixture: (file: String, field: String, selected: String?, options: [String], displays: [String]?, combo: Bool),
        _ exportValue: String
    ) -> String {
        guard let displays = fixture.displays,
              let idx = fixture.options.firstIndex(of: exportValue),
              idx < displays.count else { return exportValue }
        return displays[idx]
    }

    // MARK: - Presence

    @Test("All 7 generated choice fixtures exist on disk")
    func fixturesPresent() {
        let files = Set(Self.fixtures.map(\.file))
        for file in files {
            #expect(
                FileManager.default.fileExists(atPath: Self.fixtureURL(file).path),
                "missing generated fixture \(file) — rerun benchmark/datasets/generate_choice_fixtures.py"
            )
        }
        #expect(files.count >= 5, "must have 5+ distinct choice fixtures")
    }

    // MARK: - Structural read (walkAcroForm /Opt + /V)

    @Test("walkAcroForm decodes /Opt exports and /V for every choice field")
    func structuralReadMatchesGenerator() throws {
        var checked = 0
        for fixture in Self.fixtures {
            let data = try Data(contentsOf: Self.fixtureURL(fixture.file))
            let nodes = try PDFIncrementalFormWriter.walkAcroForm(data)

            let field = nodes.filter {
                $0.fullyQualifiedName == fixture.field && $0.fieldType == "Ch"
            }
            #expect(field.count == 1, "\(fixture.file) \(fixture.field): exactly one /Ch node")
            guard let node = field.first else { continue }

            #expect(node.optionValues == fixture.options,
                    "\(fixture.file) \(fixture.field): /Opt exports must decode as \(fixture.options), got \(node.optionValues)")
            #expect(node.value == fixture.selected,
                    "\(fixture.file) \(fixture.field): /V must decode as \(fixture.selected ?? "nil"), got \(node.value ?? "nil")")
            #expect(node.isCombo == fixture.combo,
                    "\(fixture.file) \(fixture.field): combo bit must be \(fixture.combo)")
            #expect(node.isWidget, "choice field is a merged field+widget object")
            checked += 1
        }
        #expect(checked == Self.fixtures.count, "must structurally verify every fixture row")
    }

    @Test("Pair-form /Opt decodes exports, not display strings")
    func pairOptDecodesExportElement() throws {
        let data = try Data(contentsOf: Self.fixtureURL("dropdown_pairs.pdf"))
        let nodes = try PDFIncrementalFormWriter.walkAcroForm(data)
        let field = try #require(nodes.first { $0.fullyQualifiedName == "ship_method" })
        // Display strings ("Ground (5-7 days)") must NOT leak into the
        // structural export model — /V comparisons use export values.
        #expect(field.optionValues == ["ground", "air", "freight"])
        #expect(!field.optionValues.contains { $0.contains("(") },
                "display strings must not be decoded as exports")
    }

    // MARK: - IncrementalWriter write + PDFKit cross-read

    @Test("IncrementalWriter switches choice selections and PDFKit reads them back")
    func incrementalSwitchAcrossVocabularies() throws {
        var verified = 0
        for fixture in Self.fixtures {
            // Skip the two rows with no valid alternate target: empty
            // selection still has targets (nil → value), so only rows whose
            // /Opt has no other value are skipped.
            let targets = fixture.options.filter { $0 != fixture.selected }
            guard let target = targets.first else { continue }
            let data = try Data(contentsOf: Self.fixtureURL(fixture.file))
            let nodes = try PDFIncrementalFormWriter.walkAcroForm(data)
            let plan = try PDFIncrementalFormWriter.resolveEditPlan(
                nodes: nodes, targetFieldName: fixture.field,
                requestedValue: target, source: data)
            let updated = try PDFIncrementalFormWriter.incrementalFieldUpdate(
                data, edits: plan.objectEdits, newObjects: plan.newObjectBodies)
            let tempPath = NSTemporaryDirectory() + "genchoice-\(fixture.field.replacingOccurrences(of: ".", with: "-"))-\(UUID().uuidString).pdf"
            try updated.write(to: URL(fileURLWithPath: tempPath))
            defer { try? FileManager.default.removeItem(atPath: tempPath) }

            // Structural read-back: /V == target.
            let after = try PDFIncrementalFormWriter.walkAcroForm(updated)
            let field = try #require(after.first { $0.fullyQualifiedName == fixture.field })
            #expect(field.value == target,
                    "\(fixture.file) \(fixture.field): structural /V must be '\(target)' after write")

            // PDFKit cross-read after reopen.
            guard let reopened = PDFDocument(url: URL(fileURLWithPath: tempPath)) else {
                Issue.record("\(fixture.file) \(fixture.field): reopen failed after write")
                continue
            }
            var values: [String] = []
            for p in 0..<reopened.pageCount {
                guard let page = reopened.page(at: p) else { continue }
                for a in page.annotations where a.fieldName == fixture.field {
                    values.append(a.widgetStringValue ?? "")
                }
            }
            // PDFKit's widgetStringValue is the viewer-facing string: the
            // display value for pair-form /Opt, the export otherwise.
            let pdfKitExpected = Self.displayOf(fixture, target)
            #expect(values.contains(pdfKitExpected),
                    "\(fixture.file) \(fixture.field): PDFKit must read '\(pdfKitExpected)' after write, saw \(values)")
            verified += 1
        }
        // All rows except combo_editable (whose only "alternate" would leave
        // the editable /V ∉ /Opt pattern) and rows with no alternate target.
        #expect(verified >= 7, "must write+reopen at least 7 choice fixture rows")
    }

    @Test("Empty-selection field takes a value; value survives reopen")
    func emptySelectionTakesValue() throws {
        let data = try Data(contentsOf: Self.fixtureURL("dropdown_empty_selection.pdf"))
        let nodes = try PDFIncrementalFormWriter.walkAcroForm(data)
        let plan = try PDFIncrementalFormWriter.resolveEditPlan(
            nodes: nodes, targetFieldName: "selection",
            requestedValue: "Beta", source: data)
        let updated = try PDFIncrementalFormWriter.incrementalFieldUpdate(
            data, edits: plan.objectEdits, newObjects: plan.newObjectBodies)
        let after = try PDFIncrementalFormWriter.walkAcroForm(updated)
        let field = try #require(after.first { $0.fullyQualifiedName == "selection" })
        #expect(field.value == "Beta", "empty choice must accept a value from /Opt")

        let tempPath = NSTemporaryDirectory() + "genchoice-empty-\(UUID().uuidString).pdf"
        try updated.write(to: URL(fileURLWithPath: tempPath))
        defer { try? FileManager.default.removeItem(atPath: tempPath) }
        if let reopened = PDFDocument(url: URL(fileURLWithPath: tempPath)) {
            var value: String?
            for p in 0..<reopened.pageCount {
                guard let page = reopened.page(at: p) else { continue }
                for a in page.annotations where a.fieldName == "selection" {
                    value = a.widgetStringValue
                }
            }
            #expect(value == "Beta", "PDFKit must read 'Beta' after writing to empty selection")
        }
    }

    // MARK: - Cross-engine: pdf-lib round-trip

    @Test("pdf-lib reads and writes generated choice fixtures (own read-back)")
    func pdfLibRoundTripOnGeneratedFixtures() throws {
        guard AcroFormExternalEngines.pdfLibAvailable else {
            Issue.record("pdf-lib lane not installed (npm install --prefix benchmark/acroform-lane)")
            return
        }
        var checked = 0
        for fixture in Self.fixtures {
            let url = Self.fixtureURL(fixture.file)
            guard let report = AcroFormExternalEngines.pdfLibInspect(url.path),
                  let choice = (report.fields ?? []).first(where: {
                      $0.name == fixture.field && $0.type == "choice"
                  }) else {
                Issue.record("pdf-lib must detect \(fixture.field) in \(fixture.file) as a choice field")
                continue
            }
            // pdf-lib's getOptions() exposes the viewer-facing strings: the
            // display value for pair-form /Opt, the export otherwise. Same
            // semantic as PDFKit's widgetStringValue — measured, not forced.
            let pdfLibOptionStrings = fixture.displays ?? fixture.options
            #expect(Set(choice.options ?? []) == Set(pdfLibOptionStrings),
                    "pdf-lib options must match the viewer-facing vocabulary for \(fixture.field)")

            let targets = fixture.options.filter { $0 != fixture.selected }
            guard let target = targets.first else { continue }
            // pdf-lib's select() validates against its option strings and
            // writes that same string as /V — so the lane must be addressed
            // by the viewer-facing value for this engine.
            let pdfLibValue = Self.displayOf(fixture, target)
            let out = NSTemporaryDirectory() + "genchoice-pdflib-\(fixture.field.replacingOccurrences(of: ".", with: "-"))-\(UUID().uuidString).pdf"
            defer { try? FileManager.default.removeItem(atPath: out) }
            guard let write = AcroFormExternalEngines.pdfLibWrite(
                input: url.path, output: out,
                spec: [["name": fixture.field, "type": "choice", "value": pdfLibValue]]),
                write.ok else {
                Issue.record("pdf-lib write failed for \(fixture.field)")
                continue
            }
            let reread = AcroFormExternalEngines.pdfLibRead(out)
            let value = reread?.fields?.first { $0.name == fixture.field }?.value
            #expect(value == pdfLibValue,
                    "pdf-lib must read its own '\(pdfLibValue)' selection back for \(fixture.field)")
            checked += 1
        }
        #expect(checked >= 7, "pdf-lib round-trip must cover 7+ generated choice fields")
    }

    // MARK: - Diversity

    @Test("Generated fixtures expose 5+ distinct /Opt vocabularies and pair/hierarchical forms")
    func optDiversity() {
        var vocabularies = Set<Set<String>>()
        for fixture in Self.fixtures {
            vocabularies.insert(Set(fixture.options))
        }
        #expect(vocabularies.count >= 5, "must have 5+ distinct /Opt vocabularies")
        #expect(Self.fixtures.contains { $0.file == "dropdown_pairs.pdf" },
                "pair-form /Opt ([export, display]) must be covered")
        let dotted = Self.fixtures.map(\.field).filter { $0.contains(".") }
        #expect(dotted.contains("order.priority"),
                "hierarchical dotted choice names must be covered")
        #expect(Self.fixtures.contains { $0.combo },
                "combo (Ff bit 18) choice fields must be covered")
        #expect(Self.fixtures.contains { $0.selected == nil },
                "empty-selection choice fields must be covered")
    }
}
