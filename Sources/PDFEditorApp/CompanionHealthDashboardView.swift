import PDFEditorCore
import SwiftUI

/// Companion health check dashboard.
/// Shows provider status, egress connections, bridge state, contract health,
/// and recent log entries.
struct CompanionHealthDashboardView: View {
    @ObservedObject var health: CompanionHealthCheck
    @State private var selectedTab: Tab = .overview
    @State private var showLogDetail = false
    @State private var selectedProviderID: String?

    enum Tab: String, CaseIterable {
        case overview = "Overview"
        case providers = "Providers"
        case egress = "Egress"
        case log = "Log"
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            tabBar
            Divider()
            tabContent
        }
        .frame(minWidth: 680, minHeight: 520)
        .task { await health.refresh() }
        .sheet(isPresented: $showLogDetail) {
            LogDetailSheet(entries: health.recentLogEntries)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Companion Health")
                    .font(.title2)
                if let date = health.lastRefreshedAt {
                    Text("Updated \(date.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Overall health badge
            HealthBadge(level: health.overallHealth, label: "Overall")

            // Quick counts
            HStack(spacing: 16) {
                MiniStat(
                    icon: "person.2.fill",
                    value: "\(health.enabledProviderCount)",
                    label: "Providers",
                    color: .blue
                )
                MiniStat(
                    icon: "network",
                    value: "\(health.egressStatus.connectionCount)",
                    label: "Connections",
                    color: .purple
                )
                MiniStat(
                    icon: "doc.text",
                    value: "\(health.bridgeStatus.totalLogEntries)",
                    label: "Log Entries",
                    color: .secondary
                )
            }

            Button {
                Task { await health.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh health status")
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        Picker("Tab", selection: $selectedTab) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .overview:
            overviewTab
        case .providers:
            providersTab
        case .egress:
            egressTab
        case .log:
            logTab
        }
    }

    // MARK: - Overview Tab

    private var overviewTab: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                // Bridge status card
                SectionCard(title: "Bridge Status", icon: "point.3.connected.trianglepath.dotted") {
                    HStack(spacing: 20) {
                        HealthBadge(level: bridgeHealthLevel, label: bridgeStatus.state.rawValue)
                        VStack(alignment: .leading, spacing: 4) {
                            LabeledRow(label: "Authenticated", value: health.bridgeStatus.isAuthenticated ? "Yes" : "No")
                            LabeledRow(label: "Transport", value: health.bridgeStatus.isTransportConnected ? "Connected" : "Disconnected")
                            LabeledRow(label: "Pending Requests", value: "\(health.bridgeStatus.pendingRequests)")
                        }
                        Spacer()
                    }
                }

                // Egress status card
                SectionCard(title: "Network Egress", icon: "network") {
                    HStack(spacing: 20) {
                        HealthBadge(
                            level: health.egressStatus.isEnabled ? .healthy : .disabled,
                            label: health.egressStatus.stateLabel
                        )
                        VStack(alignment: .leading, spacing: 4) {
                            LabeledRow(label: "Active Connections", value: "\(health.egressStatus.connectionCount)")
                            if !health.egressStatus.activeConnections.isEmpty {
                                ForEach(health.egressStatus.activeConnections, id: \.self) { conn in
                                    Text("• \(conn)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        Spacer()
                    }
                }

                // Contract status card
                SectionCard(title: "Contracts", icon: "doc.plaintext") {
                    HStack(spacing: 20) {
                        HealthBadge(
                            level: health.contractStatus.staleHandshakes > 0 ? .warning : .healthy,
                            label: "\(health.contractStatus.freshHandshakes)/\(health.contractStatus.totalHandshakes) fresh"
                        )
                        VStack(alignment: .leading, spacing: 4) {
                            LabeledRow(label: "Total Handshakes", value: "\(health.contractStatus.totalHandshakes)")
                            LabeledRow(label: "Fresh (< 1h)", value: "\(health.contractStatus.freshHandshakes)")
                            LabeledRow(label: "Stale", value: "\(health.contractStatus.staleHandshakes)")
                        }
                        Spacer()
                    }
                }

                // Provider summary
                SectionCard(title: "Providers", icon: "person.2.fill") {
                    if health.providerStatuses.isEmpty {
                        Text("No providers registered")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        VStack(spacing: 1) {
                            ForEach(health.providerStatuses.prefix(6)) { provider in
                                ProviderSummaryRow(status: provider)
                            }
                            if health.providerStatuses.count > 6 {
                                Text("+ \(health.providerStatuses.count - 6) more")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 4)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Providers Tab

    private var providersTab: some View {
        VStack(spacing: 0) {
            // Summary bar
            HStack {
                Text("\(health.providerStatuses.count) providers • \(health.healthyProviderCount) healthy")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 6)

            Divider()

            if health.providerStatuses.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.slash")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No providers registered")
                        .font(.callout)
                    Text("Providers appear here after handshake negotiation.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(health.providerStatuses) { provider in
                            ProviderDetailRow(
                                status: provider,
                                isSelected: selectedProviderID == provider.id,
                                onTap: {
                                    selectedProviderID = selectedProviderID == provider.id ? nil : provider.id
                                }
                            )
                        }
                    }
                    .padding(8)
                }
            }
        }
    }

    // MARK: - Egress Tab

    private var egressTab: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Image(systemName: health.egressStatus.isEnabled ? "network" : "lock.shield")
                    .font(.system(size: 40))
                    .foregroundStyle(health.egressStatus.isEnabled ? .green : .secondary)

                Text(health.egressStatus.isEnabled ? "Network Egress Enabled" : "Network Egress Disabled")
                    .font(.headline)

                Text(health.egressStatus.isEnabled
                    ? "Connections are permitted. Review active connections below."
                    : "Zero-egress mode active. No network connections are allowed.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()

            Divider()

            if health.egressStatus.activeConnections.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.title2)
                        .foregroundStyle(.green)
                    Text("No active connections")
                        .font(.callout)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(health.egressStatus.activeConnections, id: \.self) { connection in
                        HStack {
                            Image(systemName: "point.3.connected.trianglepath.dotted")
                                .foregroundStyle(.purple)
                            Text(connection)
                                .font(.body)
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    // MARK: - Log Tab

    private var logTab: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(health.recentLogEntries.count) recent entries")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Export…") { showLogDetail = true }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("Clear Log") { Task { await health.clearLog() } }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)

            Divider()

            if health.recentLogEntries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No log entries")
                        .font(.callout)
                    Text("Bridge requests are logged here (value-free).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let entries = health.recentLogEntries
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(Array(entries.enumerated().reversed()), id: \.element.id) { _, entry in
                            LogEntryRow(entry: entry)
                        }
                    }
                    .padding(8)
                }
            }
        }
    }

    // MARK: - Helpers

    private var bridgeHealthLevel: HealthLevel {
        switch health.bridgeStatus.state {
        case .connected: return .healthy
        case .unauthenticated: return .warning
        case .disconnected: return .critical
        }
    }

    private var bridgeStatus: BridgeStatus { health.bridgeStatus }
}

// MARK: - Section Card

private struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Health Badge

struct HealthBadge: View {
    let level: HealthLevel
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: level.symbolName)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    private var color: Color {
        switch level {
        case .healthy: return .green
        case .warning, .stale: return .orange
        case .critical, .failed: return .red
        case .degraded: return .yellow
        case .disabled: return .gray
        }
    }
}

// MARK: - Mini Stat

private struct MiniStat: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color)
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Labeled Row

private struct LabeledRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Provider Summary Row

private struct ProviderSummaryRow: View {
    let status: ProviderHealthStatus

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: status.health.symbolName)
                .foregroundStyle(healthColor)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(status.name)
                    .font(.body)
                Text("\(status.version) • \(status.license.rawValue)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(status.capabilities.count) caps")
                .font(.caption)
                .foregroundStyle(.secondary)

            if status.failureCount > 0 {
                Text("\(status.failureCount) fails")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var healthColor: Color {
        switch status.health {
        case .healthy: return .green
        case .warning, .stale: return .orange
        case .critical, .failed: return .red
        case .degraded: return .yellow
        case .disabled: return .gray
        }
    }
}

// MARK: - Provider Detail Row

private struct ProviderDetailRow: View {
    let status: ProviderHealthStatus
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: status.health.symbolName)
                    .foregroundStyle(healthColor)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(status.name)
                            .font(.body)
                            .fontWeight(.medium)
                        Text(status.version)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(status.license.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    HStack(spacing: 12) {
                        Text(status.health.displayName)
                            .font(.caption)
                            .foregroundStyle(healthColor)
                        Text("Handshake: \(status.handshakeDisplay)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Failures: \(status.displayFailureCount)")
                            .font(.caption)
                            .foregroundStyle(status.failureCount > 0 ? .red : .secondary)
                        Text("Max pages: \(status.maxPages)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "chevron.up")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)

            // Expanded detail
            if isSelected {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("Capabilities")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    FlowLayout(spacing: 4) {
                        ForEach(status.capabilities, id: \.rawValue) { cap in
                            Text(cap.displayName)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                    HStack(spacing: 16) {
                        LabeledRow(label: "Handshake Fresh", value: status.handshakeIsFresh ? "Yes" : "No")
                        LabeledRow(label: "Enabled", value: status.isEnabled ? "Yes" : "No")
                        LabeledRow(label: "Max Input", value: ByteCountFormatter.string(fromByteCount: Int64(status.maxInputBytes), countStyle: .file))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(isSelected ? Color.accentColor.opacity(0.05) : Color.clear)
    }

    private var healthColor: Color {
        switch status.health {
        case .healthy: return .green
        case .warning, .stale: return .orange
        case .critical, .failed: return .red
        case .degraded: return .yellow
        case .disabled: return .gray
        }
    }
}

// MARK: - Log Entry Row

private struct LogEntryRow: View {
    let entry: RequestLogEntry

    var body: some View {
        HStack(spacing: 10) {
            // Success/failure indicator
            Image(systemName: entry.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(entry.success ? .green : .red)
                .frame(width: 16)

            // Kind badge
            Text(entry.kind.rawValue.uppercased())
                .font(.caption2)
                .fontWeight(.semibold)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(kindColor.opacity(0.15))
                .clipShape(Capsule())

            // Provider
            Text(entry.providerID)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            // Error
            if let error = entry.error {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(1)
                    .frame(maxWidth: 200, alignment: .trailing)
            }

            // Timestamp
            Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospaced()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }

    private var kindColor: Color {
        switch entry.kind {
        case .handshake: return .blue
        case .request: return .purple
        case .response: return .green
        case .cancellation: return .orange
        }
    }
}

// MARK: - Log Detail Sheet

private struct LogDetailSheet: View {
    let entries: [RequestLogEntry]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Bridge Log — \(entries.count) entries")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(entries.enumerated().reversed()), id: \.element.id) { _, entry in
                        HStack(alignment: .top, spacing: 8) {
                            Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .monospaced()
                                .foregroundStyle(.secondary)
                                .frame(width: 140, alignment: .leading)

                            Text(entry.kind.rawValue.uppercased())
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .frame(width: 50, alignment: .leading)

                            Text(entry.providerID)
                                .font(.caption)
                                .frame(width: 120, alignment: .leading)

                            Image(systemName: entry.success ? "checkmark" : "xmark")
                                .foregroundStyle(entry.success ? .green : .red)
                                .frame(width: 12)

                            if let error = entry.error {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 3)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

// MARK: - Flow Layout (for capability tags)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}
