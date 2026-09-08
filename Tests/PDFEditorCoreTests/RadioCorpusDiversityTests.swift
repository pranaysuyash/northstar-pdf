import Foundation
import PDFKit
import Testing
@testable import PDFEditorCore

/// Radio-group diversity hardening (RG-133 evidence, 2026-09-03).
///
/// The parity corpus's base form repeats one radio group (`applicant.contact`)
/// across producer re-encodes. These tests exercise genuinely distinct radio
/// groups that exist elsewhere in the corpus, so the radio claim is not
/// anchored to a single name/vocabulary:
///
/// - `preferredContact` — merged-terminal single-annotation radio, export
///   `/Email`, currently selected (2026-08-23-pdfkit-widgets/mutated.pdf).
///   This is a special encoding: parent+child collapsed into one object.
/// - `status` — proper 2-kid radio with hierarchical parent node, export
///   vocabulary yes/no, selected value `no` (off-token-adjacent export),
///   in 2026-08-23-pdfkit-widgets/native-widgets-filled.pdf.
/// - `applicant+N.contact` (N = 1…19+) — 20 hierarchical groups with an
///   email/phone /Opt-encoding vocabulary on the 40-page hybrid
///   (browser-corpus/large-hybrid-40-pages.pdf; page-bounded probe keeps
///   the harness fast).
@Suite("RadioCorpusDiversity")
struct RadioCorpusDiversityTests {

    private static var projectRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func pdf(_ rel: String) -> URL {
        projectRoot.appendingPathComponent(rel)
    }

    /// Collect all Btn annotations keyed by field name.
    private static func allBtnAnnotations(in doc: PDFDocument) -> [String: [PDFAnnotation]] {
        var groups: [String: [PDFAnnotation]] = [:]
        for p in 0..<min(doc.pageCount, 200) {
            guard let page = doc.page(at: p) else { continue }
            for a in page.annotations where a.widgetFieldType.rawValue == "/Btn" {
                if let name = a.fieldName, !name.isEmpty {
                    groups[name, default: []].append(a)
                }
            }
        }
        return groups
    }

    /// MARK: - Single-annotation merged terminal

    @Test("preferredContact: merged-terminal radio with /Email vocabulary")
    func mergedTerminalEmail() throws {
        let url = Self.pdf("benchmark/results/2026-08-23-pdfkit-widgets/mutated.pdf")
        #expect(FileManager.default.fileExists(atPath: url.path))
        guard let doc = PDFDocument(url: url) else {
            Issue.record("cannot open mutated.pdf"); return
        }
        let all = Self.allBtnAnnotations(in: doc)
        // preferredContact is a merged terminal — parent+child in one object.
        // PDFKit sees exactly 1 annotation for it.
        let contact = all["preferredContact"]
        #expect(contact?.count == 1,
                "preferredContact must be a single-annotation merged terminal")
        #expect(contact?.first?.buttonWidgetStateString == "Email",
                "preferredContact must carry the /Email selection")

        // walkAcroForm confirms: one Btn node, isWidget=true (merged).
        let data = try Data(contentsOf: url)
        let nodes = try PDFIncrementalFormWriter.walkAcroForm(data)
        let preferred = nodes.filter { $0.fullyQualifiedName == "preferredContact" }
        #expect(preferred.count == 1)
        #expect(preferred.first?.fieldType == "Btn")
        #expect(preferred.first?.isWidget == true)
        #expect(preferred.first?.value == "Email")
    }

    /// MARK: - Proper 2-kid radio with off-token-adjacent export

    @Test("status: 2-kid radio with yes/no vocabulary and off-adjacent selected value")
    func hierarchicalYesNo() throws {
        let url = Self.pdf("benchmark/results/2026-08-23-pdfkit-widgets/native-widgets-filled.pdf")
        #expect(FileManager.default.fileExists(atPath: url.path))
        guard let doc = PDFDocument(url: url) else {
            Issue.record("cannot open native-widgets-filled.pdf"); return
        }
        let all = Self.allBtnAnnotations(in: doc)
        // Both kids share the PDFKit field name `status`.
        let statusKids = all["status"]
        #expect(statusKids?.count == 2,
                "status must be a 2-kid radio group via PDFKit annotations")

        let exports = Set(statusKids?.compactMap { $0.buttonWidgetStateString } ?? [])
        #expect(exports == ["yes", "no"],
                "status must have yes/no export vocabulary")

        // The selected kid must be 'no' (off-token-adjacent).
        let selected = statusKids?.filter { $0.buttonWidgetState.rawValue == 1 }
        #expect(selected?.count == 1)
        #expect(selected?.first?.buttonWidgetStateString == "no",
                "status must be selected on 'no' (off-adjacent export)")

        // walkAcroForm sees: parent node (FT=Btn, isWidget=false) + 2 widget kids.
        let data = try Data(contentsOf: url)
        let nodes = try PDFIncrementalFormWriter.walkAcroForm(data)
        let statusParent = nodes.filter {
            $0.fullyQualifiedName == "status" && $0.fieldType == "Btn" && !$0.isWidget
        }
        #expect(statusParent.count == 1, "Must have one parent field node for status")
        #expect(statusParent.first?.value == "no", "Parent node /V must be 'no'")

        let statusKids2 = nodes.filter {
            $0.fullyQualifiedName == "status" && $0.isWidget && $0.fieldType == nil
        }
        #expect(statusKids2.count == 2, "Must have 2 widget kids for status")
        let onKids = statusKids2.filter { $0.appearanceState == "no" }
        #expect(onKids.count == 1, "Exactly one kid with AS=no")
    }

    /// MARK: - IncrementalWriter on yes/no vocabulary

    @Test("IncrementalWriter switches status from no → yes")
    func incrementalSwitchYesNo() throws {
        let url = Self.pdf("benchmark/results/2026-08-23-pdfkit-widgets/native-widgets-filled.pdf")
        let data = try Data(contentsOf: url)
        let nodes = try PDFIncrementalFormWriter.walkAcroForm(data)
        let plan = try PDFIncrementalFormWriter.resolveEditPlan(
            nodes: nodes, targetFieldName: "status",
            requestedValue: "yes", source: data)
        let updated = try PDFIncrementalFormWriter.incrementalFieldUpdate(
            data, edits: plan.objectEdits, newObjects: plan.newObjectBodies)
        let tempPath = NSTemporaryDirectory() + "diversity-switch-\(UUID().uuidString).pdf"
        try updated.write(to: URL(fileURLWithPath: tempPath))
        defer { try? FileManager.default.removeItem(atPath: tempPath) }

        // PDFKit cross-read: exactly the 'yes' kid must now be on.
        guard let reopened = PDFDocument(url: URL(fileURLWithPath: tempPath)) else {
            Issue.record("reopen failed"); return
        }
        let all = Self.allBtnAnnotations(in: reopened)
        let kids = all["status"] ?? []
        let selected = kids.filter { $0.buttonWidgetState.rawValue == 1 }
        #expect(selected.count == 1, "Exactly one kid selected after the switch")
        #expect(selected.first?.buttonWidgetStateString == "yes",
                "The 'yes' selection must survive (no/yes vocabulary)")

        // Structural read-back.
        #expect(AcroFormParityExperiment.verifyRadioSelectionStructurally(
            data: updated, groupName: "status", expected: "yes"),
            "Field /V + widget /AS must encode the 'yes' selection")
    }

    /// MARK: - IncrementalWriter on merged terminal

    @Test("IncrementalWriter preserves the merged-terminal /Email group")
    func singleOptionEmailPreserved() throws {
        let url = Self.pdf("benchmark/results/2026-08-23-pdfkit-widgets/mutated.pdf")
        let data = try Data(contentsOf: url)
        let nodes = try PDFIncrementalFormWriter.walkAcroForm(data)
        let plan = try PDFIncrementalFormWriter.resolveEditPlan(
            nodes: nodes, targetFieldName: "preferredContact",
            requestedValue: "Email", source: data)
        let updated = try PDFIncrementalFormWriter.incrementalFieldUpdate(
            data, edits: plan.objectEdits, newObjects: plan.newObjectBodies)
        let tempPath = NSTemporaryDirectory() + "diversity-email-\(UUID().uuidString).pdf"
        try updated.write(to: URL(fileURLWithPath: tempPath))
        defer { try? FileManager.default.removeItem(atPath: tempPath) }

        guard let reopened = PDFDocument(url: URL(fileURLWithPath: tempPath)) else {
            Issue.record("reopen failed"); return
        }
        let all = Self.allBtnAnnotations(in: reopened)
        let kids = all["preferredContact"] ?? []
        let selected = kids.filter { $0.buttonWidgetState.rawValue == 1 }
        #expect(selected.count == 1, "preferredContact must still be selected")
        #expect(selected.first?.buttonWidgetStateString == "Email",
                "Export vocabulary /Email must survive the write")
    }

    /// MARK: - Cross-engine: pdf-lib round-trip on yes/no vocabulary

    @Test("pdf-lib round-trips the yes/no vocabulary group (own read-back)")
    func pdfLibYesNoRoundTrip() throws {
        guard AcroFormExternalEngines.pdfLibAvailable else {
            Issue.record("pdf-lib lane not installed (npm install --prefix benchmark/acroform-lane)")
            return
        }
        let url = Self.pdf("benchmark/results/2026-08-23-pdfkit-widgets/native-widgets-filled.pdf")
        // pdf-lib resolves the full name as `status.undefined` (field-tree nesting).
        guard let report = AcroFormExternalEngines.pdfLibInspect(url.path),
              let radio = (report.fields ?? []).first(where: {
                  $0.name == "status.undefined" && $0.type == "radio"
              }) else {
            Issue.record("pdf-lib must detect status.undefined as a radio group")
            return
        }
        #expect(radio.value == "no", "pdf-lib must read the current 'no' selection")

        let out = NSTemporaryDirectory() + "diversity-pdflib-\(UUID().uuidString).pdf"
        defer { try? FileManager.default.removeItem(atPath: out) }
        guard let write = AcroFormExternalEngines.pdfLibWrite(
            input: url.path, output: out,
            spec: [["name": "status.undefined", "type": "radio", "value": "yes"]]),
            write.ok else {
            Issue.record("pdf-lib write failed"); return
        }

        // pdf-lib's own read-back.
        let reread = AcroFormExternalEngines.pdfLibRead(out)
        let value = reread?.fields?.first { $0.name == "status.undefined" }?.value
        #expect(value == "yes", "pdf-lib must read its own 'yes' selection back")

        // Cross-engine: PDFKit cross-read is NOT expected for yes/no flattened
        // groups — pdf-lib creates new annotation objects (57/58) with correct
        // /AS but doesn't update the parent's /Kids or /V. PDFKit reads radio
        // kids through the parent's /Kids array, so it still sees the old state.
        // This is a known pdf-lib limitation with flattened radio groups.
        // The IncrementalWriter lane (above) handles this correctly because it
        // updates the parent /V and kid /AS in-place.
    }

    /// MARK: - Cross-engine: pdf-lib round-trip on merged terminal

    @Test("pdf-lib round-trips the merged-terminal /Email group")
    func pdfLibEmailRoundTrip() throws {
        guard AcroFormExternalEngines.pdfLibAvailable else {
            Issue.record("pdf-lib lane not installed")
            return
        }
        let url = Self.pdf("benchmark/results/2026-08-23-pdfkit-widgets/mutated.pdf")
        guard let report = AcroFormExternalEngines.pdfLibInspect(url.path),
              let radio = (report.fields ?? []).first(where: {
                  $0.name == "preferredContact" && $0.type == "radio"
              }) else {
            Issue.record("pdf-lib must detect preferredContact as a radio group")
            return
        }
        #expect(radio.value == "Email", "pdf-lib must read the current /Email selection")

        let out = NSTemporaryDirectory() + "diversity-pdflib-email-\(UUID().uuidString).pdf"
        defer { try? FileManager.default.removeItem(atPath: out) }
        guard let write = AcroFormExternalEngines.pdfLibWrite(
            input: url.path, output: out,
            spec: [["name": "preferredContact", "type": "radio", "value": "Email"]]),
            write.ok else {
            Issue.record("pdf-lib write failed"); return
        }

        let reread = AcroFormExternalEngines.pdfLibRead(out)
        let value = reread?.fields?.first { $0.name == "preferredContact" }?.value
        #expect(value == "Email", "pdf-lib must read /Email back after write")

        if let reopened = PDFDocument(url: URL(fileURLWithPath: out)) {
            let all = Self.allBtnAnnotations(in: reopened)
            let kids = all["preferredContact"] ?? []
            let selected = kids.filter { $0.buttonWidgetState.rawValue == 1 }
            #expect(selected.first?.buttonWidgetStateString == "Email",
                    "PDFKit must see the pdf-lib-written /Email selection")
        }
    }

    /// MARK: - Hierarchical groups on large hybrid

    @Test("40-page hybrid carries hierarchical applicant+N.contact groups")
    func hierarchicalGroupsOnLargeHybrid() throws {
        let url = Self.pdf("benchmark/results/browser-corpus/large-hybrid-40-pages.pdf")
        guard let doc = PDFDocument(url: url) else {
            Issue.record("cannot open large-hybrid-40-pages.pdf"); return
        }
        // Page-bounded probe (pages 0..<5) to keep the harness fast.
        var hierarchical: [String] = []
        for p in 0..<min(doc.pageCount, 5) {
            guard let page = doc.page(at: p) else { continue }
            var seenOnPage = Set<String>()
            for a in page.annotations where a.widgetFieldType.rawValue == "/Btn" {
                if let name = a.fieldName, !name.isEmpty, name.hasPrefix("applicant+") {
                    seenOnPage.insert(name)
                }
            }
            hierarchical.append(contentsOf: seenOnPage)
        }
        #expect(!hierarchical.isEmpty,
                "Page-bounded probe must find applicant+N.contact hierarchical groups")
        #expect(hierarchical.contains { $0 == "applicant+1.contact" } ||
                hierarchical.contains { $0 == "applicant+2.contact" })
    }
}
