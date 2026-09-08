import Foundation
import PDFKit
import Testing
@testable import PDFEditorCore

/// Generated radio-fixture hardening (2026-09-03).
///
/// `benchmark/datasets/generate_radio_fixtures.py` produces 8 single-page PDFs
/// whose radio groups cover genuinely distinct export vocabularies and
/// hierarchical dotted field names — beyond the single `applicant.contact`
/// group in the base parity corpus:
///
///   1. yes_no.pdf           — agree: Yes/No
///   2. on_off.pdf           — enable_feature: On/Off  ⚠️ DEGENERATE (see below)
///   3. email_phone.pdf      — contact_method: Email/Phone/Mail
///   4. hierarchical.pdf     — applicant.contact (Email/Phone) +
///                             applicant.preference (Morning/Afternoon/Evening)
///   5. multi_group.pdf      — priority High/Medium/Low, status Active/Inactive/Pending,
///                             visibility Public/Private (3 groups, one page)
///   6. single_option.pdf    — confirm: Yes (degenerate 1-kid group)
///   7. numeric_vocabulary.pdf — rating: 0/1/2/3 (numeric export names)
///   8. off_adjacent.pdf     — choice: 0/1 (off-token-adjacent export "1")
///
/// Each fixture uses proper tree structure: parent holds /T, /FT=/Btn,
/// /Ff=32768 (radio), /V; kids hold /AS + /AP and an empty /T (inherited).
/// Export vocabulary lives in the kid /AS + /AP state names — the standard
/// radio encoding (PDF 32000-1 §12.7.4.2.2). (`/Opt` applies to Choice
/// fields, not radio buttons; these fixtures exercise the radio equivalent.)
///
/// ⚠️ on_off.pdf is a DEGENERATE vocabulary fixture, kept deliberately: the
/// export value "Off" collides with the reserved unselected-state name /Off
/// (PDF 32000-1 §12.7.5.3). A group whose export includes "Off" can never be
/// visually or structurally distinguished from "nothing selected" — the
/// writer is spec-literal (parent /V=/Off, every kid /AS=/Off) and the
/// verifier FAILS CLOSED rather than falsely certifying. This mirrors a real
/// producer bug pattern documented by pdfscripting.com ("this radio button
/// will always show as selected because its export value is the Off value").
/// The round-trip tests therefore exclude the reserved "Off" target and a
/// dedicated test asserts the fail-closed behavior.
///
/// These tests assert the production claim end-to-end: structural read
/// (walkAcroForm + verifyRadioSelectionStructurally), the IncrementalWriter
/// write path with PDFKit cross-read after reopen, and the pdf-lib lane where
/// the npm dependency is installed.
@Suite("GeneratedRadioFixtures")
struct GeneratedRadioFixtureTests {

    private static var projectRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func fixtureURL(_ name: String) -> URL {
        projectRoot.appendingPathComponent("benchmark/datasets/radio-fixtures/\(name)")
    }

    /// (fixture file, group name, current selection, all exports).
    /// Matches the generator's `main()` exactly — a mismatch here means the
    /// generator was edited without updating this table.
    static let fixtures: [(file: String, group: String, selected: String, exports: [String])] = [
        ("yes_no.pdf", "agree", "Yes", ["Yes", "No"]),
        ("on_off.pdf", "enable_feature", "On", ["On", "Off"]),
        ("email_phone.pdf", "contact_method", "Email", ["Email", "Phone", "Mail"]),
        ("hierarchical.pdf", "applicant.contact", "Phone", ["Email", "Phone"]),
        ("hierarchical.pdf", "applicant.preference", "Morning", ["Morning", "Afternoon", "Evening"]),
        ("multi_group.pdf", "priority", "Medium", ["High", "Medium", "Low"]),
        ("multi_group.pdf", "status", "Active", ["Active", "Inactive", "Pending"]),
        ("multi_group.pdf", "visibility", "Private", ["Public", "Private"]),
        ("single_option.pdf", "confirm", "Yes", ["Yes"]),
        ("numeric_vocabulary.pdf", "rating", "2", ["0", "1", "2", "3"]),
        ("off_adjacent.pdf", "choice", "1", ["0", "1"]),
    ]

    /// The reserved unselected-state name (PDF 32000-1 §12.7.5.3). A radio
    /// export value of "Off" is degenerate: selection is indistinguishable
    /// from no selection, so no round-trip claim can be made for it.
    private static let reservedOff = "Off"

    /// Targets that are valid, distinct round-trip values for a group.
    private static func validTargets(_ fixture: (file: String, group: String, selected: String, exports: [String])) -> [String] {
        fixture.exports.filter { $0 != fixture.selected && $0 != reservedOff }
    }

    // MARK: - Presence

    @Test("All 8 generated radio fixtures exist on disk")
    func fixturesPresent() {
        let files = Set(Self.fixtures.map(\.file))
        for file in files {
            #expect(
                FileManager.default.fileExists(atPath: Self.fixtureURL(file).path),
                "missing generated fixture \(file) — rerun benchmark/datasets/generate_radio_fixtures.py"
            )
        }
        #expect(files.count >= 5, "must have 5+ distinct radio fixtures")
    }

    // MARK: - Structural read (walkAcroForm + verifyRadioSelectionStructurally)

    @Test("walkAcroForm + verifyRadioSelectionStructurally agree with generator state")
    func structuralReadMatchesGenerator() throws {
        var checked = 0
        for fixture in Self.fixtures {
            let url = Self.fixtureURL(fixture.file)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            let data = try Data(contentsOf: url)
            let nodes = try PDFIncrementalFormWriter.walkAcroForm(data)

            // Parent field node: Btn, non-widget, /V == current selection.
            let parent = nodes.filter {
                $0.fullyQualifiedName == fixture.group && $0.fieldType == "Btn" && !$0.isWidget
            }
            #expect(parent.count == 1,
                    "\(fixture.file) \(fixture.group): exactly one parent field node")
            if parent.count == 1 {
                #expect(parent[0].value == fixture.selected,
                        "\(fixture.file) \(fixture.group): /V must be '\(fixture.selected)'")
            }

            // Widget kids: one per export, exactly one /AS == selection.
            let kids = nodes.filter {
                $0.isWidget && $0.fullyQualifiedName == fixture.group
            }
            #expect(kids.count == fixture.exports.count,
                    "\(fixture.file) \(fixture.group): kid count must equal export count")
            let onKids = kids.filter { $0.appearanceState == fixture.selected }
            #expect(onKids.count == 1,
                    "\(fixture.file) \(fixture.group): exactly one kid /AS == selection")
            let offKids = kids.filter { $0.appearanceState != fixture.selected }
            #expect(offKids.allSatisfy { $0.appearanceState == "Off" },
                    "\(fixture.file) \(fixture.group): all other kids must be /Off")

            #expect(AcroFormParityExperiment.verifyRadioSelectionStructurally(
                data: data, groupName: fixture.group, expected: fixture.selected),
                "\(fixture.file) \(fixture.group): structural verifier must pass on the generator state")
            checked += 1
        }
        #expect(checked == Self.fixtures.count, "must structurally verify every fixture row")
    }

    // MARK: - IncrementalWriter write + PDFKit cross-read

    @Test("IncrementalWriter switches every non-reserved export and PDFKit reads it back")
    func incrementalSwitchAcrossVocabularies() throws {
        var verified = 0
        var skippedDegenerate = 0
        for fixture in Self.fixtures {
            let url = Self.fixtureURL(fixture.file)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            let data = try Data(contentsOf: url)

            // Switch to a distinct, non-reserved export. Groups whose only
            // alternative is the reserved "Off" (on_off.pdf.enable_feature) are
            // covered by the dedicated fail-closed test below — skip them here.
            let targets = Self.validTargets(fixture)
            guard let target = targets.first else {
                skippedDegenerate += 1
                continue
            }

            let nodes = try PDFIncrementalFormWriter.walkAcroForm(data)
            let plan = try PDFIncrementalFormWriter.resolveEditPlan(
                nodes: nodes, targetFieldName: fixture.group,
                requestedValue: target, source: data)
            let updated = try PDFIncrementalFormWriter.incrementalFieldUpdate(
                data, edits: plan.objectEdits, newObjects: plan.newObjectBodies)
            let tempPath = NSTemporaryDirectory() + "genradio-\(fixture.group.replacingOccurrences(of: ".", with: "-"))-\(UUID().uuidString).pdf"
            try updated.write(to: URL(fileURLWithPath: tempPath))
            defer { try? FileManager.default.removeItem(atPath: tempPath) }

            // Structural read-back: /V + exactly one kid /AS == target.
            #expect(AcroFormParityExperiment.verifyRadioSelectionStructurally(
                data: updated, groupName: fixture.group, expected: target),
                "\(fixture.file) \(fixture.group): structural read-back after write to '\(target)'")

            // PDFKit cross-read: exactly one kid selected, with the target export.
            guard let reopened = PDFDocument(url: URL(fileURLWithPath: tempPath)) else {
                Issue.record("\(fixture.file) \(fixture.group): reopen failed after write")
                continue
            }
            var kids: [PDFAnnotation] = []
            for p in 0..<reopened.pageCount {
                guard let page = reopened.page(at: p) else { continue }
                for a in page.annotations where a.widgetFieldType.rawValue == "/Btn" {
                    if a.fieldName == fixture.group { kids.append(a) }
                }
            }
            #expect(!kids.isEmpty, "\(fixture.file) \(fixture.group): PDFKit must see the group")
            let selected = kids.filter { $0.buttonWidgetState.rawValue == 1 }
            #expect(selected.count == 1,
                    "\(fixture.file) \(fixture.group): exactly one selected kid after switch")
            if selected.count == 1 {
                #expect(selected[0].buttonWidgetStateString == target,
                        "\(fixture.file) \(fixture.group): PDFKit must read '\(target)' after write")
            }
            verified += 1
        }
        // Rows whose only non-selected export is "Off" are the degenerate
        // "Off as export value" vocabulary (PDF 32000-1 §12.7.5.3): they
        // cannot round-trip and are covered by the dedicated fail-closed test.
        // Every remaining row must write and survive cross-read.
        let nonDegenerate = Self.fixtures.filter { !Self.validTargets($0).isEmpty }.count
        #expect(verified == nonDegenerate,
                "must write+reopen every non-degenerate fixture row")
    }

    /// The degenerate case: a radio group whose export vocabulary includes the
    /// reserved /Off name cannot round-trip, and the pipeline must FAIL CLOSED
    /// rather than certify an unreadable selection.
    @Test("Degenerate 'Off' export (on_off.pdf) fails closed: writer spec-literal, verifier refuses")
    func degenerateOffExportFailsClosed() throws {
        let url = Self.fixtureURL("on_off.pdf")
        let data = try Data(contentsOf: url)
        let nodes = try PDFIncrementalFormWriter.walkAcroForm(data)
        let plan = try PDFIncrementalFormWriter.resolveEditPlan(
            nodes: nodes, targetFieldName: "enable_feature",
            requestedValue: "Off", source: data)
        let updated = try PDFIncrementalFormWriter.incrementalFieldUpdate(
            data, edits: plan.objectEdits, newObjects: plan.newObjectBodies)

        // Writer is spec-literal: parent /V=/Off, every kid /AS=/Off.
        let after = try PDFIncrementalFormWriter.walkAcroForm(updated)
        let group = after.filter { $0.fullyQualifiedName == "enable_feature" }
        #expect(group.contains { !$0.isWidget && $0.value == "Off" },
                "writer must set parent /V to the requested export")
        #expect(group.filter(\.isWidget).allSatisfy { $0.appearanceState == "Off" },
                "all kids must be /AS=/Off — the reserved state for 'Off' export")

        // Verifier fails closed: it must NOT certify either selection.
        #expect(!AcroFormParityExperiment.verifyRadioSelectionStructurally(
            data: updated, groupName: "enable_feature", expected: "Off"),
            "verifier must refuse to certify the reserved 'Off' export")
        #expect(!AcroFormParityExperiment.verifyRadioSelectionStructurally(
            data: updated, groupName: "enable_feature", expected: "On"),
            "after switching to 'Off', 'On' must no longer verify either")

        // PDFKit cross-read: 0 selected — /Off is the unselected state.
        let tempPath = NSTemporaryDirectory() + "genradio-degenerate-\(UUID().uuidString).pdf"
        try updated.write(to: URL(fileURLWithPath: tempPath))
        defer { try? FileManager.default.removeItem(atPath: tempPath) }
        if let reopened = PDFDocument(url: URL(fileURLWithPath: tempPath)) {
            var kids: [PDFAnnotation] = []
            for p in 0..<reopened.pageCount {
                guard let page = reopened.page(at: p) else { continue }
                for a in page.annotations where a.widgetFieldType.rawValue == "/Btn" {
                    if a.fieldName == "enable_feature" { kids.append(a) }
                }
            }
            #expect(kids.filter { $0.buttonWidgetState.rawValue == 1 }.isEmpty,
                    "PDFKit must see 0 selected kids for the reserved 'Off' export")
        }
    }

    // MARK: - Cross-engine: pdf-lib round-trip

    @Test("pdf-lib reads and writes non-degenerate generated fixtures (own read-back)")
    func pdfLibRoundTripOnGeneratedFixtures() throws {
        guard AcroFormExternalEngines.pdfLibAvailable else {
            Issue.record("pdf-lib lane not installed (npm install --prefix benchmark/acroform-lane)")
            return
        }
        var checked = 0
        for fixture in Self.fixtures {
            let url = Self.fixtureURL(fixture.file)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            guard let report = AcroFormExternalEngines.pdfLibInspect(url.path),
                  let radio = (report.fields ?? []).first(where: {
                      $0.name == fixture.group && $0.type == "radio"
                  }) else {
                Issue.record("pdf-lib must detect \(fixture.group) in \(fixture.file) as a radio group")
                continue
            }
            #expect(radio.value == fixture.selected,
                    "pdf-lib must read the generator selection '\(fixture.selected)' for \(fixture.group)")

            let targets = Self.validTargets(fixture)
            guard let target = targets.first else { continue } // reserved-Off groups: covered above
            let out = NSTemporaryDirectory() + "genradio-pdflib-\(fixture.group.replacingOccurrences(of: ".", with: "-"))-\(UUID().uuidString).pdf"
            defer { try? FileManager.default.removeItem(atPath: out) }
            guard let write = AcroFormExternalEngines.pdfLibWrite(
                input: url.path, output: out,
                spec: [["name": fixture.group, "type": "radio", "value": target]]),
                write.ok else {
                Issue.record("pdf-lib write failed for \(fixture.group)")
                continue
            }
            let reread = AcroFormExternalEngines.pdfLibRead(out)
            let value = reread?.fields?.first { $0.name == fixture.group }?.value
            #expect(value == target,
                    "pdf-lib must read its own '\(target)' selection back for \(fixture.group)")
            checked += 1
        }
        #expect(checked >= 5, "pdf-lib round-trip must cover 5+ generated groups")
    }

    // MARK: - Vocabulary diversity

    @Test("Generated fixtures expose 5+ distinct export vocabularies beyond applicant.contact")
    func vocabularyDiversity() {
        var vocabularies = Set<Set<String>>()
        for fixture in Self.fixtures {
            vocabularies.insert(Set(fixture.exports))
        }
        #expect(vocabularies.count >= 5,
                "must have 5+ distinct export vocabularies across generated fixtures")
        // At least one hierarchical dotted name beyond the corpus's applicant.contact.
        let dotted = Self.fixtures.map(\.group).filter { $0.contains(".") }
        #expect(dotted.contains("applicant.preference"),
                "hierarchical fixture must include a dotted name beyond applicant.contact")
        // Numeric exports are part of the diversity (off-token-adjacent "1").
        #expect(Self.fixtures.contains { $0.exports.contains("1") },
                "numeric/off-adjacent vocabulary must be present")
    }
}