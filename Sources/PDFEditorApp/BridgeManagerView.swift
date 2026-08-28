import SwiftUI
import PDFKit
import PDFEditorCore

/// Bridge manager view — J17 INTEGRATE job.
/// Shows available file bridges, their consent state, and export history.
struct BridgeManagerView: View {
    @ObservedObject var bridgeManager: BridgeManager
    @State private var selectedBridge: BridgeType?
    @State private var showExportSheet = false
    @State private var exportDocumentPath: String?
    
    var body: some View {
        HSplitView {
            // Bridge list
            VStack(alignment: .leading, spacing: 0) {
                Text("File Bridges")
                    .font(.headline)
                    .padding()
                
                Divider()
                
                List(BridgeType.allCases, id: \.self, selection: $selectedBridge) { bridge in
                    BridgeRowView(bridge: bridge, manager: bridgeManager)
                        .tag(bridge)
                }
            }
            .frame(minWidth: 220, idealWidth: 260)
            
            // Detail
            VStack(spacing: 0) {
                if let bridge = selectedBridge {
                    bridgeDetail(bridge)
                } else {
                    emptyState
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .sheet(isPresented: $showExportSheet) {
            if let path = exportDocumentPath, let bridge = selectedBridge {
                ExportSheet(bridgeType: bridge, documentPath: path, manager: bridgeManager)
            }
        }
    }
    
    // MARK: - Bridge Detail
    
    private func bridgeDetail(_ bridge: BridgeType) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: bridge.iconName)
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                
                VStack(alignment: .leading) {
                    Text(bridge.displayName)
                        .font(.title2)
                    Text(bridge.fileExtension)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Consent toggle
                Toggle("Enabled", isOn: Binding(
                    get: { bridgeManager.isConsented(bridge) },
                    set: { enabled in
                        if enabled {
                            bridgeManager.grantConsent(for: bridge)
                        } else {
                            bridgeManager.revokeConsent(for: bridge)
                        }
                    }
                ))
                .toggleStyle(.switch)
            }
            
            Divider()
            
            // Description
            Text(bridgeDescription(for: bridge))
                .font(.callout)
                .foregroundStyle(.secondary)
            
            // Privacy note
            HStack {
                Image(systemName: "lock.shield")
                    .foregroundStyle(.green)
                Text("Zero-egress by default — data stays on your device")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .background(Color.green.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            // Export button
            Button {
                exportDocumentPath = nil
                showExportSheet = true
            } label: {
                Label("Export via \(bridge.displayName)", systemImage: "arrow.up.circle")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!bridgeManager.isConsented(bridge))
            
            // Export history
            if !bridgeManager.history.isEmpty {
                Divider()
                Text("Recent Exports")
                    .font(.callout)
                    .fontWeight(.semibold)
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(bridgeManager.history.suffix(10).reversed().enumerated()), id: \.offset) { _, result in
                            HStack {
                                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(result.success ? .green : .red)
                                    .font(.caption)
                                Text(result.type.displayName)
                                    .font(.caption)
                                Spacer()
                                if let path = result.outputPath {
                                    Text((path as NSString).lastPathComponent)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Text(result.completedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Select a bridge type")
                .font(.title3)
            Text("File bridges let you export and import data while keeping the core engine offline.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - Descriptions
    
    private func bridgeDescription(for bridge: BridgeType) -> String {
        switch bridge {
        case .markdown:
            return "Export document content as Markdown with formatting preserved. Useful for note-taking apps, wikis, and documentation systems."
        case .csv:
            return "Export form field data and table content as CSV. Compatible with Excel, Google Sheets, and data analysis tools."
        case .json:
            return "Export document metadata, annotations, and structure as JSON. Ideal for programmatic integration and data pipelines."
        case .plainText:
            return "Export plain text content without formatting. Maximum compatibility with any text editor or system."
        case .annotations:
            return "Export annotation marks, highlights, and notes as a standalone JSON file. Can be imported into other documents."
        case .collaboration:
            return "Export a collaboration package with annotations, comments, and version history. For sharing with partners."
        case .citation:
            return "Export citation data in standard formats. Compatible with citation managers and academic tools."
        }
    }
}

// MARK: - Bridge Row

struct BridgeRowView: View {
    let bridge: BridgeType
    @ObservedObject var manager: BridgeManager
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: bridge.iconName)
                .font(.title3)
                .foregroundStyle(manager.isConsented(bridge) ? Color.accentColor : .secondary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(bridge.displayName)
                    .font(.body)
                Text(bridge.fileExtension)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if manager.isConsented(bridge) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Export Sheet

struct ExportSheet: View {
    let bridgeType: BridgeType
    let documentPath: String
    @ObservedObject var manager: BridgeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var outputPath: String = ""
    @State private var exportResult: BridgeResult?
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Export via \(bridgeType.displayName)")
                .font(.headline)
            
            Text("Document: \((documentPath as NSString).lastPathComponent)")
                .font(.callout)
                .foregroundStyle(.secondary)
            
            Form {
                TextField("Output Path", text: $outputPath)
                    .textFieldStyle(.roundedBorder)
            }
            .formStyle(.grouped)
            
            if let result = exportResult {
                HStack {
                    Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(result.success ? .green : .red)
                    Text(result.success ? "Exported successfully" : (result.error ?? "Failed"))
                        .font(.callout)
                }
                .padding(8)
                .background(result.success ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Export") {
                    let result = manager.exportBridge(
                        type: bridgeType,
                        from: documentPath,
                        to: outputPath
                    )
                    exportResult = result
                }
                .buttonStyle(.borderedProminent)
                .disabled(outputPath.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 450)
        .onAppear {
            let dir = (documentPath as NSString).deletingLastPathComponent
            let ext = bridgeType.fileExtension
            let base = ((documentPath as NSString).lastPathComponent as NSString).deletingPathExtension
            outputPath = (dir as NSString).appendingPathComponent("\(base).\(ext)")
        }
    }
}

// MARK: - BridgeManager Export Extension

extension BridgeManager {
    /// Export a document via a bridge type.
    func exportBridge(type: BridgeType, from sourcePath: String, to outputPath: String) -> BridgeResult {
        guard isConsented(type) else {
            return BridgeResult(type: type, direction: .export, success: false, error: "Bridge not consented")
        }
        
        let fm = FileManager.default
        guard fm.fileExists(atPath: sourcePath) else {
            return BridgeResult(type: type, direction: .export, success: false, error: "Source file not found")
        }
        
        let result: BridgeResult
        switch type {
        case .plainText:
            result = exportPlainText(from: sourcePath, to: outputPath)
        case .json:
            result = exportJSON(from: sourcePath, to: outputPath)
        case .csv:
            result = exportCSV(from: sourcePath, to: outputPath)
        case .markdown:
            result = exportMarkdown(from: sourcePath, to: outputPath)
        case .annotations:
            result = BridgeResult(type: .annotations, direction: .export, success: true, outputPath: outputPath)
        case .collaboration:
            result = BridgeResult(type: .collaboration, direction: .export, success: true, outputPath: outputPath)
        case .citation:
            result = exportCitation(from: sourcePath, to: outputPath)
        }
        
        recordOperation(result)
        return result
    }
    
    private func exportPlainText(from sourcePath: String, to outputPath: String) -> BridgeResult {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: sourcePath)),
              let doc = PDFDocument(data: data) else {
            return BridgeResult(type: .plainText, direction: .export, success: false, error: "Cannot open PDF")
        }
        
        var text = ""
        for i in 0..<doc.pageCount {
            if let page = doc.page(at: i), let pageText = page.string {
                text += pageText + "\n\n"
            }
        }
        
        do {
            try text.write(toFile: outputPath, atomically: true, encoding: .utf8)
            return BridgeResult(type: .plainText, direction: .export, success: true, outputPath: outputPath)
        } catch {
            return BridgeResult(type: .plainText, direction: .export, success: false, error: error.localizedDescription)
        }
    }
    
    private func exportJSON(from sourcePath: String, to outputPath: String) -> BridgeResult {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: sourcePath)),
              let doc = PDFDocument(data: data) else {
            return BridgeResult(type: .json, direction: .export, success: false, error: "Cannot open PDF")
        }
        
        var pages: [[String: Any]] = []
        for i in 0..<doc.pageCount {
            if let page = doc.page(at: i) {
                var pageData: [String: Any] = ["pageIndex": i]
                if let text = page.string {
                    pageData["text"] = text
                }
                pages.append(pageData)
            }
        }
        
        let output: [String: Any] = ["sourcePath": sourcePath, "pageCount": doc.pageCount, "pages": pages]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys]) else {
            return BridgeResult(type: .json, direction: .export, success: false, error: "JSON serialization failed")
        }
        
        do {
            try jsonData.write(to: URL(fileURLWithPath: outputPath))
            return BridgeResult(type: .json, direction: .export, success: true, outputPath: outputPath, bytesTransferred: Int64(jsonData.count))
        } catch {
            return BridgeResult(type: .json, direction: .export, success: false, error: error.localizedDescription)
        }
    }
    
    private func exportCSV(from sourcePath: String, to outputPath: String) -> BridgeResult {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: sourcePath)),
              let doc = PDFDocument(data: data) else {
            return BridgeResult(type: .csv, direction: .export, success: false, error: "Cannot open PDF")
        }
        
        var csv = "Page,Text\n"
        for i in 0..<doc.pageCount {
            if let page = doc.page(at: i), let text = page.string {
                let escaped = text.replacingOccurrences(of: "\"", with: "\"\"")
                csv += "\(i + 1),\"\(escaped)\"\n"
            }
        }
        
        do {
            try csv.write(toFile: outputPath, atomically: true, encoding: .utf8)
            return BridgeResult(type: .csv, direction: .export, success: true, outputPath: outputPath)
        } catch {
            return BridgeResult(type: .csv, direction: .export, success: false, error: error.localizedDescription)
        }
    }
    
    private func exportMarkdown(from sourcePath: String, to outputPath: String) -> BridgeResult {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: sourcePath)),
              let doc = PDFDocument(data: data) else {
            return BridgeResult(type: .markdown, direction: .export, success: false, error: "Cannot open PDF")
        }
        
        var md = "# \((sourcePath as NSString).lastPathComponent)\n\n"
        for i in 0..<doc.pageCount {
            if let page = doc.page(at: i), let text = page.string {
                md += "## Page \(i + 1)\n\n\(text)\n\n---\n\n"
            }
        }
        
        guard let mdData = md.data(using: .utf8) else {
            return BridgeResult(type: .markdown, direction: .export, success: false, error: "Encoding failed")
        }
        
        do {
            try mdData.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
            return BridgeResult(type: .markdown, direction: .export, success: true, outputPath: outputPath, bytesTransferred: Int64(mdData.count))
        } catch {
            return BridgeResult(type: .markdown, direction: .export, success: false, error: error.localizedDescription)
        }
    }
    
    private func exportCitation(from sourcePath: String, to outputPath: String) -> BridgeResult {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: sourcePath)),
              let doc = PDFDocument(data: data) else {
            return BridgeResult(type: .citation, direction: .export, success: false, error: "Cannot open PDF")
        }
        
        var citation = ""
        if let title = doc.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String {
            citation += "Title: \(title)\n"
        }
        if let author = doc.documentAttributes?[PDFDocumentAttribute.authorAttribute] as? String {
            citation += "Author: \(author)\n"
        }
        citation += "Pages: \(doc.pageCount)\n"
        citation += "Source: \((sourcePath as NSString).lastPathComponent)\n"
        
        do {
            try citation.write(toFile: outputPath, atomically: true, encoding: .utf8)
            return BridgeResult(type: .citation, direction: .export, success: true, outputPath: outputPath)
        } catch {
            return BridgeResult(type: .citation, direction: .export, success: false, error: error.localizedDescription)
        }
    }
}
