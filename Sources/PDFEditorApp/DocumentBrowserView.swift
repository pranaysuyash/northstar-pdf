import SwiftUI
import PDFEditorCore

/// Corpus browser view — J13 ORGANIZE job.
/// Shows all indexed documents with tag management, folder grouping,
/// corpus search, and dedup detection.
struct DocumentBrowserView: View {
    @ObservedObject var documentIndex: DocumentIndex
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
        HSplitView {
            // Sidebar — tags and folders
            sidebar
                .frame(minWidth: 180, idealWidth: 220)
            
            // Main content
            VStack(spacing: 0) {
                toolbar
                documentList
            }
        }
        .searchable(text: $searchText, prompt: "Search documents by title, author, tags…")
        .sheet(isPresented: $showTagManager) {
            TagManagerView(documentIndex: documentIndex)
        }
        .sheet(isPresented: $showDedupReport) {
            DedupReportView(documentIndex: documentIndex)
        }
    }
    
    // MARK: - Sidebar
    
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Corpus stats
            VStack(alignment: .leading, spacing: 4) {
                Label("Corpus", systemImage: "books.vertical")
                    .font(.headline)
                Text("\(documentIndex.entries.count) documents · \(documentIndex.totalPages) pages")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(ByteCountFormatter.string(fromByteCount: documentIndex.totalSize, countStyle: .file))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            
            Divider()
            
            // Folders
            if !documentIndex.allFolders.isEmpty {
                Text("Folders")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                ForEach(Array(documentIndex.allFolders.sorted()), id: \.self) { folder in
                    Button {
                        selectedFolder = selectedFolder == folder ? nil : folder
                    } label: {
                        HStack {
                            Label(folder, systemImage: "folder")
                                .font(.callout)
                            Spacer()
                            Text("\(documentIndex.documents(in: folder).count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(selectedFolder == folder ? Color.accentColor.opacity(0.15) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                
                Divider()
            }
            
            // Tags
            HStack {
                Text("Tags")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showTagManager = true
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            ForEach(Array(documentIndex.allTags.sorted()), id: \.self) { tag in
                Button {
                    selectedTag = selectedTag == tag ? nil : tag
                } label: {
                    HStack {
                        Text("#\(tag)")
                            .font(.callout)
                        Spacer()
                        Text("\(documentIndex.documents(withTag: tag).count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(selectedTag == tag ? Color.accentColor.opacity(0.15) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Dedup button
            Divider()
            Button {
                showDedupReport = true
            } label: {
                Label("Duplicates", systemImage: "doc.on.doc")
                    .font(.callout)
            }
            .buttonStyle(.plain)
            .padding()
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Toolbar
    
    private var toolbar: some View {
        HStack {
            Text("\(filteredDocuments.count) documents")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Picker("Sort", selection: $sortBy) {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 300)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Document List
    
    private var documentList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(filteredDocuments) { entry in
                    DocumentRowView(entry: entry, index: documentIndex)
                }
            }
            .padding(8)
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
            // File icon
            Image(systemName: "doc.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 32)
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.fileName)
                    .font(.body)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text("\(entry.pageCount) pages")
                    Text(ByteCountFormatter.string(fromByteCount: entry.fileSize, countStyle: .file))
                    if !entry.author.isEmpty {
                        Text(entry.author)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                
                // Tags
                if !entry.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(entry.tags.prefix(3)), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        if entry.tags.count > 3 {
                            Text("+\(entry.tags.count - 3)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Rating
            if entry.rating > 0 {
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= entry.rating ? "star.fill" : "star")
                            .font(.caption)
                            .foregroundStyle(star <= entry.rating ? .yellow : .secondary)
                    }
                }
            }
            
            // Star
            Button {
                index.toggleStar(entryID: entry.id)
            } label: {
                Image(systemName: entry.isStarred ? "star.fill" : "star")
                    .foregroundStyle(entry.isStarred ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(isHovering ? Color.accentColor.opacity(0.05) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
