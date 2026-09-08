import Testing
import PDFKit
@testable import PDFEditorCore

/// Reproduce: PDFKit annotation-api checkbox write + save/reopen + read
/// on a file produced by the independent pdf-lib lane.
///
/// If PDFKit's `.widgetValue` setter with `document.write` drops the value,
/// that reproduces the RG-134 checkbox failure and tells us it's a
/// save/reopen contract bug, not a corpus-composition artifact.
@MainActor
struct PDFKitCheckboxSaveReopenProbeTests {

    static let pdfBoxNoop = "/Users/pranay/Projects/pdf_editor/benchmark/results/2026-08-25-pdfbox-public-acroform/noop.pdf"
    static let pdfLibLane = "/Users/pranay/Projects/pdf_editor/benchmark/acroform-lane/lane.mjs"

    @Test("pdf-lib writes checkbox Yes; PDFKit annotation API read sees Yes before write")
    func readBeforeWrite() throws {
        guard FileManager.default.fileExists(atPath: Self.pdfBoxNoop) else {
            Issue.record("corpus fixture missing"); return
        }
        guard let doc = PDFDocument(url: URL(fileURLWithPath: Self.pdfBoxNoop)) else {
            Issue.record("PDFKit cannot reopen pdfbox re-encode"); return
        }
        let cb = findCheckbox(named: "applicant.subscribe", in: doc)
        #expect(cb != nil, "applicant.subscribe must be visible to PDFKit before any write")
        if let cb {
            let v = cb.value(forAnnotationKey: .widgetValue) as? String ?? ""
            #expect(v == "Off", "pre-write state must be Off on the pdfbox re-encode")
        }
    }

    @Test("PDFKit annotation API writes checkbox Yes; save/reopen/read loses the value")
    func writeSaveReopenDropsCheckbox() throws {
        guard FileManager.default.fileExists(atPath: Self.pdfBoxNoop) else {
            Issue.record("corpus fixture missing"); return
        }
        guard let doc = PDFDocument(url: URL(fileURLWithPath: Self.pdfBoxNoop)) else {
            Issue.record("PDFKit cannot reopen"); return
        }
        let cb = findCheckbox(named: "applicant.subscribe", in: doc)
        #expect(cb != nil)
        guard let cb else { return }

        cb.setValue("Yes", forAnnotationKey: .widgetValue)
        let tempPath = NSTemporaryDirectory() + "cbprobe-saved.pdf"
        let tempURL = URL(fileURLWithPath: tempPath)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        guard doc.write(to: tempURL) else {
            Issue.record("PDFKit write failed in probe"); return
        }

        guard let reopened = PDFDocument(url: tempURL) else {
            Issue.record("PDFKit cannot reopen its own saved file"); return
        }
        let reread = findCheckbox(named: "applicant.subscribe", in: reopened)
        #expect(reread != nil, "checkbox annotation must survive save")
        if let reread {
            let v = reread.value(forAnnotationKey: .widgetValue) as? String ?? ""
            // The RG-134 hypothesis: the saved bytes carry /Yes, but the
            // reopened widgetValue reads back as Off/nil because PDFKit's
            // annotation-API save does not encode the widget /AS state.
            print("[probe] reopened applicant.subscribe widgetValue = \(v)")
        }
    }

    // Cross-check against the independent lane: pdf-lib's own read-back.
    @Test("pdf-lib own read-back confirms checkbox value survives via lane.mjs")
    func pdfLibOwnReadBack() throws {
        let specPath = NSTemporaryDirectory() + "cbprobe-spec-\(UUID().uuidString).json"
        let outPath = NSTemporaryDirectory() + "cbprobe-out-\(UUID().uuidString).pdf"
        defer {
            try? FileManager.default.removeItem(atPath: specPath)
            try? FileManager.default.removeItem(atPath: outPath)
        }
        // Raw string: backslashes are literal in #…#, so the JSON must carry
        // bare quotes (the previous \" form wrote invalid JSON and the lane
        // rejected the spec with exit 1).
        let spec = #"[{"name":"applicant.subscribe","type":"checkbox","value":"Yes"}]"#
        try spec.write(to: URL(fileURLWithPath: specPath), atomically: true, encoding: .utf8)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/node")
        process.arguments = [
            Self.pdfLibLane, "write",
            Self.pdfBoxNoop, outPath, specPath,
        ]
        let outPipe = Pipe(); let errPipe = Pipe()
        process.standardOutput = outPipe; process.standardError = errPipe
        try process.run()
        process.waitUntilExit()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0 else {
            Issue.record("pdf-lib write failed: \(String(data: errData, encoding: .utf8) ?? "no stderr")")
            return
        }
        #expect(FileManager.default.fileExists(atPath: outPath), "pdf-lib must produce output file")

        guard let doc = PDFDocument(url: URL(fileURLWithPath: outPath)) else {
            Issue.record("PDFKit cannot reopen pdf-lib output"); return
        }
        let cb = findCheckbox(named: "applicant.subscribe", in: doc)
        #expect(cb != nil, "checkbox annotation exists in pdf-lib output")
        if let cb {
            let v = cb.value(forAnnotationKey: .widgetValue) as? String ?? ""
            print("[probe] pdf-lib output applicant.subscribe widgetValue = \(v)")
        }
    }

    // MARK: - helpers

    private func findCheckbox(named partial: String, in doc: PDFDocument) -> PDFAnnotation? {
        for p in 0..<doc.pageCount {
            guard let page = doc.page(at: p) else { continue }
            for a in page.annotations where a.widgetFieldType.rawValue == "/Btn" {
                if let name = a.fieldName, name.hasSuffix(partial) {
                    return a
                }
            }
        }
        return nil
    }
}
