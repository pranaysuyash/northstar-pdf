import SwiftUI
import PDFEditorCore

/// Version comparison and revert view — J14 VERSION job.
/// Shows version history, allows comparing any two versions, and reverting.
struct VersionCompareView: View {
    @ObservedObject var versionStore: VersionStore
    @State private var selectedFromVersion: Int?
    @State private var selectedToVersion: Int?
    @State private var comparison: VersionComparison?
    @State private var showRevertConfirm = false
    @State private var revertTarget: VersionSnapshot?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        HSplitView {
            // Version list
            versionList
                .frame(minWidth: 200, idealWidth: 250)
            
            // Comparison detail
            VStack(spacing: 0) {
                if let comparison = comparison {
                    comparisonHeader(comparison)
                    comparisonDetail(comparison)
                } else {
                    emptyState
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .alert("Revert to Version?", isPresented: $showRevertConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Revert", role: .destructive) {
                if let target = revertTarget {
                    performRevert(to: target)
                }
            }
        } message: {
            if let target = revertTarget {
                Text("This will revert to \(target.summary). The operations that were added after this version will be undone.")
            }
        }
    }
    
    // MARK: - Version List
    
    private var versionList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Version History")
                .font(.headline)
                .padding()
            
            if versionStore.snapshots.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No versions saved yet")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                List(versionStore.snapshots.reversed(), selection: $selectedFromVersion) { snapshot in
                    VersionRowView(snapshot: snapshot)
                        .tag(snapshot.versionNumber)
                        .contextMenu {
                            Button("Compare from here") {
                                selectedFromVersion = snapshot.versionNumber
                            }
                            Button("Revert to this version") {
                                revertTarget = snapshot
                                showRevertConfirm = true
                            }
                        }
                }
            }
            
            Divider()
            
            // Compare controls
            VStack(spacing: 8) {
                HStack {
                    Text("From:")
                        .font(.caption)
                    Text(selectedFromVersion.map { "v\($0)" } ?? "—")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("To:")
                        .font(.caption)
                    Text(selectedToVersion.map { "v\($0)" } ?? "latest")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Button("Compare") {
                    performComparison()
                }
                .disabled(selectedFromVersion == nil)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Comparison Header
    
    private func comparisonHeader(_ comparison: VersionComparison) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text("v\(comparison.from.versionNumber) → v\(comparison.to.versionNumber)")
                    .font(.title3)
                Text("\(comparison.addedOperations.count) added, \(comparison.removedOperations.count) removed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if comparison.hasChanges {
                Button("Revert to v\(comparison.from.versionNumber)") {
                    revertTarget = comparison.from
                    showRevertConfirm = true
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Comparison Detail
    
    private func comparisonDetail(_ comparison: VersionComparison) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if comparison.addedOperations.isEmpty && comparison.removedOperations.isEmpty {
                    Text("No differences between these versions.")
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    // Added operations
                    if !comparison.addedOperations.isEmpty {
                        SectionHeader(title: "Added Operations", count: comparison.addedOperations.count, color: .green)
                        ForEach(comparison.addedOperations) { op in
                            OperationRowView(operation: op, isAdded: true)
                        }
                    }
                    
                    // Removed operations
                    if !comparison.removedOperations.isEmpty {
                        SectionHeader(title: "Removed Operations", count: comparison.removedOperations.count, color: .red)
                        ForEach(comparison.removedOperations) { op in
                            OperationRowView(operation: op, isAdded: false)
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Select two versions to compare")
                .font(.title3)
            Text("Click a version in the list, then click Compare")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func performComparison() {
        guard let from = selectedFromVersion else { return }
        let to = selectedToVersion ?? (versionStore.latestSnapshot?.versionNumber ?? from)
        comparison = versionStore.compare(from: from, to: to)
    }
    
    private func performRevert(to snapshot: VersionSnapshot) {
        // In production: apply revert operations to the document
        // For now, just dismiss
        dismiss()
    }
}

// MARK: - Version Row

struct VersionRowView: View {
    let snapshot: VersionSnapshot
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(snapshot.summary)
                    .font(.body)
                Spacer()
                Text(snapshot.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(snapshot.digest.prefix(12) + "…")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .monospaced()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.callout)
                .fontWeight(.semibold)
            Text("(\(count))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Operation Row

struct OperationRowView: View {
    let operation: EditOperation
    let isAdded: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isAdded ? "plus.circle.fill" : "minus.circle.fill")
                .foregroundStyle(isAdded ? .green : .red)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(operation.kind.rawValue)
                    .font(.callout)
                Text("Page \(operation.pageIndex + 1)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if !operation.value.isEmpty {
                Text(operation.value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 200)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isAdded ? Color.green.opacity(0.05) : Color.red.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Persistent Version Store

extension VersionStore {
    /// Persistence URL for version snapshots.
    private func persistenceURL(for documentID: String) -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("PDFEditor/Versions", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(documentID).versions.json")
    }
    
    /// Load snapshots from disk.
    public func loadFromDisk(documentID: String) {
        let url = persistenceURL(for: documentID)
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([VersionSnapshot].self, from: data) else { return }
        snapshots = decoded
    }
    
    /// Save snapshots to disk.
    public func saveToDisk(documentID: String) {
        let url = persistenceURL(for: documentID)
        guard let data = try? JSONEncoder().encode(snapshots) else { return }
        try? data.write(to: url, options: .atomic)
    }
    
    /// Save a snapshot and persist to disk.
    @discardableResult
    public func saveAndPersist(
        documentID: String,
        operations: [EditOperation],
        sourceHash: String = "",
        label: String = ""
    ) -> VersionSnapshot {
        let snapshot = saveSnapshot(operations: operations, sourceHash: sourceHash, label: label)
        saveToDisk(documentID: documentID)
        return snapshot
    }
    
    /// Revert to a specific version and persist.
    public func revertToVersion(_ versionNumber: Int, documentID: String) -> [EditOperation]? {
        guard let ops = operationsForRevert(from: 0, to: versionNumber) else { return nil }
        // Clear snapshots after the target version
        snapshots.removeAll { $0.versionNumber > versionNumber }
        saveToDisk(documentID: documentID)
        return ops
    }
}
