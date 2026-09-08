import SwiftUI
import PDFEditorCore

/// Corpus browser view — J13 ORGANIZE job.
/// Shows all indexed documents with tag management, folder grouping,
/// corpus search, and dedup detection.
struct DocumentBrowserView: View {
    @ObservedObject var documentIndex: DocumentIndex
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedTag: String?
    @State private var selectedFolder: String?
    @State private var showTagManager = false
    @State private var showDedupReport = false
    @State private var sortBy: SortOption = .recentAccess
    
    enum SortOption: String, CaseIterable {
        case recentAccess = "Recent"
        case alphabetical = "A–Z"
        case rating = "Rating"
        case size = "Size"
        case pageCount = "Pages"
    }
    
    var filteredDocuments: [DocumentIndexEntry] {
        var results = documentIndex.entries
        
        if !searchText.isEmpty {
            let search = CorpusSearch()
            results = search.search(searchText, in: documentIndex)
        }
        
        if let tag = selectedTag {
            results = results.filter { $0.tags.contains(tag) }
        }
        
        if let folder = selectedFolder {
            results = results.filter { $0.folder == folder }
        }
        
        switch sortBy {
        case .recentAccess:
            results.sort { $0.lastAccessedAt > $1.lastAccessedAt }
        case .alphabetical:
            results.sort { $0.fileName.localizedCaseInsensitiveCompare($1.fileName) == .orderedAscending }
        case .rating:
            results.sort { $0.rating > $1.rating }
        case .size:
            results.sort { $0.fileSize > $1.fileSize }
        case .pageCount:
            results.sort { $0.pageCount > $1.pageCount }
        }
        
        return results
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            headerBar

            Divider()

            HSplitView {
                // Sidebar — tags and folders
                sidebar
                    .frame(minWidth: 200, idealWidth: 220, maxWidth: 260)
                
                // Main content
                VStack(spacing: 0) {
                    toolbar
                    Divider()
                    documentContentArea
                }
            }
        }
        .frame(width: 820, height: 560)
        .sheet(isPresented: $showTagManager) {
            TagManagerView(documentIndex: documentIndex)
        }
        .sheet(isPresented: $showDedupReport) {
            DedupReportView(documentIndex: documentIndex)
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: "books.vertical.fill")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Document Corpus Browser")
                    .font(.headline)
                Text("Local document catalog, cross-document search, tags, and dedup audit.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Search field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Search title, author, tags…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.callout)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .frame(width: 240)

            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Sidebar
    
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Corpus stats card
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Corpus Overview", systemImage: "chart.bar.doc.horizontal")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(documentIndex.entries.count)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                        .foregroundStyle(Color.accentColor)
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(documentIndex.totalPages)")
                            .font(.subheadline.weight(.semibold))
                        Text("Pages")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Divider()
                        .frame(height: 20)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(ByteCountFormatter.string(fromByteCount: documentIndex.totalSize, countStyle: .file))
                            .font(.subheadline.weight(.semibold))
                        Text("Total Size")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .padding(12)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Folders
                    if !documentIndex.allFolders.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("FOLDERS")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                            
                            ForEach(Array(documentIndex.allFolders.sorted()), id: \.self) { folder in
                                Button {
                                    selectedFolder = selectedFolder == folder ? nil : folder
                                } label: {
                                    HStack {
                                        Label(folder, systemImage: "folder")
                                            .font(.callout)
                                        Spacer()
                                        Text("\(documentIndex.documents(in: folder).count)")
                                            .font(.caption2.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(selectedFolder == folder ? Color.accentColor.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // Tags
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("TAGS")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                showTagManager = true
                            } label: {
                                Image(systemName: "plus.circle")
                                    .font(.caption)
                                    .foregroundStyle(Color.accentColor)
                            }
                            .buttonStyle(.plain)
                            .help("Manage tags")
                        }
                        .padding(.horizontal, 4)
                        
                        if documentIndex.allTags.isEmpty {
                            Text("No tags yet")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                        } else {
                            ForEach(Array(documentIndex.allTags.sorted()), id: \.self) { tag in
                                Button {
                                    selectedTag = selectedTag == tag ? nil : tag
                                } label: {
                                    HStack {
                                        Text("#\(tag)")
                                            .font(.callout)
                                        Spacer()
                                        Text("\(documentIndex.documents(withTag: tag).count)")
                                            .font(.caption2.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(selectedTag == tag ? Color.accentColor.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(12)
            }
            
            Spacer()
            
            // Dedup button
            Divider()
            Button {
                showDedupReport = true
            } label: {
                HStack {
                    Label("Duplicates Report", systemImage: "doc.on.doc")
                        .font(.callout)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(12)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Toolbar
    
    private var toolbar: some View {
        HStack {
            HStack(spacing: 6) {
                Text("\(filteredDocuments.count) documents")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                if selectedTag != nil || selectedFolder != nil {
                    Button {
                        selectedTag = nil
                        selectedFolder = nil
                    } label: {
                        HStack(spacing: 3) {
                            Text("Reset filter")
                            Image(systemName: "xmark")
                        }
                        .font(.caption2)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }
            
            Spacer()
            
            Picker("Sort", selection: $sortBy) {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 260)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Document List / Empty State
    
    @ViewBuilder
    private var documentContentArea: some View {
        if filteredDocuments.isEmpty {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.secondary.opacity(0.1))
                        .frame(width: 56, height: 56)
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 4) {
                    Text(searchText.isEmpty ? "No Documents Indexed" : "No Matching Documents")
                        .font(.headline)
                    Text(searchText.isEmpty ? "Documents opened or imported into Northstar are indexed locally with zero cloud egress." : "Try adjusting your search query or clearing active filters.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                }

                if !searchText.isEmpty || selectedTag != nil || selectedFolder != nil {
                    Button("Clear Filters") {
                        searchText = ""
                        selectedTag = nil
                        selectedFolder = nil
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))
        } else {
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredDocuments) { entry in
                        DocumentRowView(entry: entry, index: documentIndex)
                    }
                }
                .padding(12)
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
    }
}

// MARK: - Document Row

struct DocumentRowView: View {
    let entry: DocumentIndexEntry
    @ObservedObject var index: DocumentIndex
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            // File icon in tinted container
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 38, height: 42)
                Image(systemName: "doc.text.fill")
                    .font(.title3)
                    .foregroundStyle(.red.opacity(0.85))
            }
            
            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.fileName)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Label("\(entry.pageCount) pages", systemImage: "doc.plaintext")
                    Text("·")
                    Text(ByteCountFormatter.string(fromByteCount: entry.fileSize, countStyle: .file))
                    if !entry.author.isEmpty {
                        Text("·")
                        Label(entry.author, systemImage: "person")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                
                // Tags
                if !entry.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(entry.tags.prefix(3)), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.1), in: Capsule())
                                .foregroundStyle(Color.accentColor)
                        }
                        if entry.tags.count > 3 {
                            Text("+\(entry.tags.count - 3)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 1)
                }
            }
            
            Spacer()
            
            // Rating
            if entry.rating > 0 {
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= entry.rating ? "star.fill" : "star")
                            .font(.caption2)
                            .foregroundStyle(star <= entry.rating ? .yellow : .secondary.opacity(0.3))
                    }
                }
            }
            
            // Star
            Button {
                index.toggleStar(entryID: entry.id)
            } label: {
                Image(systemName: entry.isStarred ? "star.fill" : "star")
                    .font(.callout)
                    .foregroundStyle(entry.isStarred ? .yellow : .secondary.opacity(0.4))
            }
            .buttonStyle(.plain)
            .help(entry.isStarred ? "Unstar document" : "Star document")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isHovering ? Color.primary.opacity(0.05) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isHovering ? Color.primary.opacity(0.08) : Color.clear, lineWidth: 1)
        )
        .onHover { isHovering = $0 }
    }
}

// MARK: - Tag Manager

struct TagManagerView: View {
    @ObservedObject var documentIndex: DocumentIndex
    @State private var newTagName = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Manage Tags")
                .font(.headline)
            
            HStack {
                TextField("New tag name", text: $newTagName)
                Button("Add") {
                    guard !newTagName.isEmpty else { return }
                    // Tags are added per-document, but we track known tags
                    newTagName = ""
                }
                .disabled(newTagName.isEmpty)
            }
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(documentIndex.allTags.sorted()), id: \.self) { tag in
                        HStack {
                            Text("#\(tag)")
                            Spacer()
                            Text("\(documentIndex.documents(withTag: tag).count) docs")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                    }
                }
            }
            
            Button("Done") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(20)
        .frame(width: 300, height: 400)
    }
}

// MARK: - Dedup Report

struct DedupReportView: View {
    @ObservedObject var documentIndex: DocumentIndex
    @Environment(\.dismiss) private var dismiss
    
    private var dedupGroups: [[DocumentIndexEntry]] {
        DedupDetector().findDuplicates(in: documentIndex)
    }
    
    private var wastedSpace: Int64 {
        DedupDetector().wastedSpace(in: documentIndex)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Duplicate Report")
                .font(.headline)
            
            if dedupGroups.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.green)
                    Text("No duplicates found")
                        .font(.title3)
                }
                .frame(maxHeight: .infinity)
            } else {
                Text("\(dedupGroups.count) duplicate groups · \(ByteCountFormatter.string(fromByteCount: wastedSpace, countStyle: .file)) wasted")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(dedupGroups.enumerated()), id: \.offset) { index, group in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Group \(index + 1)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                ForEach(group) { entry in
                                    HStack {
                                        Image(systemName: "doc.fill")
                                            .foregroundStyle(.secondary)
                                        Text(entry.fileName)
                                        Spacer()
                                        Text(ByteCountFormatter.string(fromByteCount: entry.fileSize, countStyle: .file))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(10)
                            .background(Color.orange.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
            
            Button("Done") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(20)
        .frame(width: 500, height: 400)
    }
}
