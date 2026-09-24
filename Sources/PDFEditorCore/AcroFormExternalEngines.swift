import Foundation

/// Runners for the genuinely independent AcroForm engines measured by the
/// cross-provider parity experiment.
///
/// Until these were wired, the experiment's "PDF.js" and "qpdf" rows ran the
/// *same PDFKit code path* under different labels — the cross-provider claim
/// was inferred, not measured. This type shells out to:
///
/// - **pdf-lib** (pure-JS, no shared code with PDFKit) via the committed lane
///   `benchmark/acroform-lane/lane.mjs`, and
/// - **qpdf** (independent structural tool) via `qpdf --json`.
///
/// Doctrine alignment: §5 Evidence-based — every provider row is now backed by
/// an independently executed engine; §2 Truth taxonomy — the artifact records
/// which engine produced which number.
public enum AcroFormExternalEngines {

    /// A field as the external engine sees it (its own model, not PDFKit's).
    public struct Field: Codable, Sendable, Equatable {
        public let name: String
        public let type: String       // radio | checkbox | choice | text
        public let value: String?     // selection / text / Yes-Off / null
        public let options: [String]? // radio export values / choice options
        /// Multi-select listbox selections (array /V). nil for single-valued
        /// fields so single vs multi shape stays observable across engines.
        public let values: [String]?

        private enum CodingKeys: String, CodingKey {
            case name, type, value, options, values
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = try c.decode(String.self, forKey: .name)
            type = try c.decode(String.self, forKey: .type)
            value = try c.decodeIfPresent(String.self, forKey: .value)
            options = try c.decodeIfPresent([String].self, forKey: .options)
            values = try c.decodeIfPresent([String].self, forKey: .values)
        }
    }

    public struct InspectReport: Codable, Sendable {
        public let ok: Bool
        public let engine: String?
        public let error: String?
        public let fieldCount: Int?
        public let fields: [Field]?
    }

    public struct WriteReport: Codable, Sendable {
        public let ok: Bool
        public let error: String?
        public let applied: [WriteOutcome]?

        public struct WriteOutcome: Codable, Sendable {
            public let name: String
            public let type: String
            public let value: String?
            public let ok: Bool
            public let error: String?
        }
    }

    /// A qpdf `acroform.fields` entry (qpdf's own normalized view).
    ///
    /// qpdf v12 nests the widget appearance state under
    /// `annotation.appearancestate` (e.g. "/0"). In tree layouts the group /V
    /// is echoed on every kid, so radio *selection* must be read from the
    /// appearance state, never from /V alone.
    public struct QpdfField: Decodable, Sendable {
        public let fullname: String?
        public let fieldtype: String?
        public let isradiobutton: Bool?
        public let ischeckbox: Bool?
        public let ischoice: Bool?
        public let istext: Bool?
        public let value: String?
        public let appearancestate: String?
        public let options: [String]?

        public init(from decoder: Decoder) throws {
            // qpdf emits both a top-level value and, for widgets, a nested
            // annotation dict. Decode the nested form by flattening JSON first
            // so both top-level and annotation.appearancestate are readable.
            let c = try decoder.container(keyedBy: CodingKeys.self)
            fullname = try c.decodeIfPresent(String.self, forKey: .fullname)
            fieldtype = try c.decodeIfPresent(String.self, forKey: .fieldtype)
            isradiobutton = try c.decodeIfPresent(Bool.self, forKey: .isradiobutton)
            ischeckbox = try c.decodeIfPresent(Bool.self, forKey: .ischeckbox)
            ischoice = try c.decodeIfPresent(Bool.self, forKey: .ischoice)
            istext = try c.decodeIfPresent(Bool.self, forKey: .istext)
            if let nested = try? c.nestedContainer(keyedBy: CodingKeys.self, forKey: .annotation) {
                appearancestate = try nested.decodeIfPresent(String.self, forKey: .appearancestate)
            } else {
                appearancestate = try c.decodeIfPresent(String.self, forKey: .appearancestate)
            }
            // value can be a string ("/Yes", "/1", "text") or null.
            if let s = try? c.decodeIfPresent(String.self, forKey: .value) {
                value = s
            } else if let arr = try? c.decodeIfPresent([String].self, forKey: .value) {
                value = arr.first
            } else {
                value = nil
            }
            if let arr = try? c.decodeIfPresent([String].self, forKey: .options) {
                options = arr
            } else {
                options = nil
            }
        }

        enum CodingKeys: String, CodingKey {
            case fullname, fieldtype, isradiobutton, ischeckbox, ischoice, istext
            case value, options
            case annotation, appearancestate
        }
    }

    // MARK: - Engine discovery

    /// Project root, resolved from this source file's location
    /// (Sources/PDFEditorCore/… -> repo root is three levels up).
    public static var projectRoot: URL {
        if let override = ProcessInfo.processInfo.environment["PDF_EDITOR_PROJECT_ROOT"] {
            return URL(fileURLWithPath: override)
        }
        return URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    public static var acroformLaneDir: URL {
        if let override = ProcessInfo.processInfo.environment["PDF_EDITOR_ACROFORM_LANE_DIR"] {
            return URL(fileURLWithPath: override)
        }
        return projectRoot.appendingPathComponent("benchmark/acroform-lane")
    }

    /// pdf-lib lane is available when the lane script and its node_modules
    /// dependency are installed (`npm install --prefix benchmark/acroform-lane`).
    public static var pdfLibAvailable: Bool {
        let fm = FileManager.default
        let lane = acroformLaneDir.appendingPathComponent("lane.mjs")
        let dep = acroformLaneDir.appendingPathComponent("node_modules/pdf-lib/package.json")
        return fm.fileExists(atPath: lane.path) && fm.fileExists(atPath: dep.path)
    }

    public static var qpdfAvailable: Bool {
        findExecutable("qpdf") != nil
    }

    private static func findExecutable(_ name: String) -> String? {
        var candidates = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)",
        ]
        // Keg-only Homebrew installs (e.g. node@24) are not linked into
        // /opt/homebrew/bin; discover them under /opt/homebrew/opt.
        if let opt = try? FileManager.default.contentsOfDirectory(atPath: "/opt/homebrew/opt") {
            for dir in opt where dir.hasPrefix(name) {
                candidates.append("/opt/homebrew/opt/\(dir)/bin/\(name)")
            }
        }
        for c in candidates where FileManager.default.isExecutableFile(atPath: c) {
            return c
        }
        // PATH probe (works when the host keeps PATH, e.g. CLI runs)
        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            for dir in pathEnv.split(separator: ":") {
                let full = "\(dir)/\(name)"
                if FileManager.default.isExecutableFile(atPath: full) {
                    return full
                }
            }
        }
        return nil
    }

    // MARK: - Process runner

    /// Runs a process, returning (status, stdout, stderr). Never blocks longer
    /// than `timeout`.
    private static func run(
        _ launchPath: String,
        args: [String],
        cwd: URL? = nil
    ) -> (status: Int32, stdout: String, stderr: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = args
        if let cwd { process.currentDirectoryURL = cwd }
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        do {
            try process.run()
        } catch {
            return (-1, "", "cannot launch \(launchPath): \(error.localizedDescription)")
        }
        // Enforce a hard timeout so a hung engine can never stall the gate:
        // schedule a terminate; waitUntilExit returns promptly for a healthy
        // engine and only blocks (≤60s) while a genuinely hung one is reaped.
        let deadline = DispatchTime.now() + .seconds(60)
        DispatchQueue.global().asyncAfter(deadline: deadline) {
            if process.isRunning {
                process.terminate()
            }
        }
        var outData = Data()
        var errData = Data()
        let group = DispatchGroup()

        group.enter()
        DispatchQueue.global().async {
            outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }

        group.enter()
        DispatchQueue.global().async {
            errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }

        process.waitUntilExit()
        group.wait()
        return (
            process.terminationStatus,
            String(data: outData, encoding: .utf8) ?? "",
            String(data: errData, encoding: .utf8) ?? ""
        )
    }

    // MARK: - pdf-lib lane

    /// Runs `node lane.mjs …` against the pdf-lib lane. Node is resolved by
    /// absolute path: xctest environments strip PATH, so `/usr/bin/env node`
    /// fails even when node is on the user's shell PATH.
    private static func runLane(_ args: [String]) -> (status: Int32, stdout: String, stderr: String) {
        guard let node = findExecutable("node") else {
            return (-1, "", "node not found (needed by the pdf-lib AcroForm lane)")
        }
        return run(node, args: ["lane.mjs"] + args, cwd: acroformLaneDir)
    }

    /// Inspect fields of a PDF as pdf-lib sees them.
    public static func pdfLibInspect(_ pdfPath: String) -> InspectReport? {
        let (status, out, _) = runLane(["inspect", pdfPath])
        guard status == 0, let data = out.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(InspectReport.self, from: data)
    }

    /// Write values with pdf-lib into `outputPath` and report per-field
    /// application outcomes. Returns nil when the engine cannot run.
    public static func pdfLibWrite(
        input: String, output: String, spec: [[String: String]]
    ) -> WriteReport? {
        let specPath = NSTemporaryDirectory() + "pdf-lib-spec-\(UUID().uuidString).json"
        let specData = (try? JSONSerialization.data(withJSONObject: spec)) ?? Data()
        guard (try? specData.write(to: URL(fileURLWithPath: specPath))) != nil else { return nil }
        defer { try? FileManager.default.removeItem(atPath: specPath) }
        let (status, out, _) = runLane(["write", input, output, specPath])
        guard status == 0, let data = out.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(WriteReport.self, from: data)
    }

    /// Re-read values of an output file with pdf-lib (independent of PDFKit).
    public static func pdfLibRead(_ pdfPath: String) -> InspectReport? {
        let (status, out, _) = runLane(["read", pdfPath])
        guard status == 0, let data = out.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(InspectReport.self, from: data)
    }

    // MARK: - qpdf

    /// Parsed `acroform.fields` from `qpdf --json` (qpdf's independent view).
    public static func qpdfFields(_ pdfPath: String) -> [QpdfField]? {
        guard let qpdf = findExecutable("qpdf") else { return nil }
        let (status, out, _) = run(qpdf, args: ["--json", pdfPath])
        // qpdf exits 0 on clean success, and 3 on success with non-fatal warnings
        // (such as repairing a missing page-level Resources dict). Both produce valid JSON.
        guard (status == 0 || status == 3), let data = out.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let acro = root["acroform"] as? [String: Any],
              let rawFields = acro["fields"] as? [[String: Any]]
        else { return nil }
        // Decode each field through our tolerant Codable path.
        var decoded: [QpdfField] = []
        for raw in rawFields {
            if let d = try? JSONSerialization.data(withJSONObject: raw),
               let field = try? JSONDecoder().decode(QpdfField.self, from: d) {
                decoded.append(field)
            }
        }
        return decoded
    }
}
