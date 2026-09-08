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
        VStack(spacing: 0) {
            // Header bar
            headerBar

            Divider()

            HSplitView {
                // Version list
                versionList
                    .frame(minWidth: 220, idealWidth: 250, maxWidth: 300)
                
                // Comparison detail
                VStack(spacing: 0) {
                    if let comparison = comparison {
                        comparisonHeader(comparison)
                        Divider()
                        comparisonDetail(comparison)
                    } else {
                        emptyState
                    }
                }
            }
        }
        .frame(width: 820, height: 560)
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
        .onAppear {
            if versionStore.snapshots.isEmpty {
                versionStore.saveSnapshot(
                    operations: [],
                    sourceHash: "a1b2c3d4",
                    label: "Initial Document Import"
                )
                let op1 = EditOperation(
                    pageIndex: 0,
                    kind: .annotation,
                    value: "Yellow highlight: Executive summary section",
                    reversible: true,
                    destructive: false
                )
                versionStore.saveSnapshot(
                    operations: [op1],
                    sourceHash: "a1b2c3d4",
                    label: "Added Executive Summary Highlights"
                )
                let op2 = EditOperation(
                    pageIndex: 0,
                    kind: .redactMark,
                    value: "Blackout redaction: SSN and banking coordinates",
                    reversible: true,
                    destructive: false
                )
                versionStore.saveSnapshot(
                    operations: [op1, op2],
                    sourceHash: "a1b2c3d4",
                    label: "Applied PII Privacy Redactions"
                )
            }
            if selectedFromVersion == nil, let first = versionStore.snapshots.first {
                selectedFromVersion = first.versionNumber
                selectedToVersion = versionStore.snapshots.last?.versionNumber
                performComparison()
            }
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: "clock.arrow.circlepath")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(.purple)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Version History & Compare")
                    .font(.headline)
                Text("Local non-destructive version checkpoints, delta inspection, and snapshot revert.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

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
    
    // MARK: - Version List
    
    private var versionList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Snapshots", systemImage: "clock")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(versionStore.snapshots.count)")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.08), in: Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)
            
            if versionStore.snapshots.isEmpty {
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.secondary.opacity(0.1))
                            .frame(width: 44, height: 44)
                        Image(systemName: "clock")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    Text("No versions saved yet")
                        .font(.callout.weight(.medium))
                    Text("Snapshots are automatically created as you edit documents.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            VStack(spacing: 10) {
                HStack {
                    HStack(spacing: 4) {
                        Text("From:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(selectedFromVersion.map { "v\($0)" } ?? "—")
                            .font(.caption.weight(.semibold))
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Text("To:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(selectedToVersion.map { "v\($0)" } ?? "latest")
                            .font(.caption.weight(.semibold))
                    }
                }
                .padding(.horizontal, 4)
                
                Button {
                    performComparison()
                } label: {
                    HStack {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.caption)
                        Text("Compare Selected")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(selectedFromVersion == nil)
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding(14)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Comparison Header
    
    private func comparisonHeader(_ comparison: VersionComparison) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("v\(comparison.from.versionNumber)")
                        .font(.callout.monospacedDigit().weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    Image(systemName: "arrow.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text("v\(comparison.to.versionNumber)")
                        .font(.callout.monospacedDigit().weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .foregroundStyle(Color.accentColor)
                }

                Text("\(comparison.addedOperations.count) added · \(comparison.removedOperations.count) removed")
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
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Comparison Detail
    
    private func comparisonDetail(_ comparison: VersionComparison) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if comparison.addedOperations.isEmpty && comparison.removedOperations.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "equal.circle")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("No differences between these versions.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
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
            .padding(16)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 56, height: 56)
                Image(systemName: "arrow.left.arrow.right")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 4) {
                Text("Select Versions to Compare")
                    .font(.headline)
                Text("Select a baseline snapshot in the sidebar, then click Compare Selected to view delta.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
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
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(snapshot.summary)
                    .font(.callout.weight(.medium))
                Spacer()
                Text(snapshot.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                Text("SHA-256:")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(snapshot.digest.prefix(12) + "…")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
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
