import SwiftUI
import PDFEditorCore

/// Governance dashboard — J12 GOVERN job.
/// Shows policy rules, violations, compliance status, and allows rule management.
struct GovernanceDashboardView: View {
    @ObservedObject var engine: GovernanceEngine
    @State private var selectedTab: Tab = .overview
    @State private var showAddRule = false
    @State private var showResolvedViolations = false
    
    enum Tab: String, CaseIterable {
        case overview = "Overview"
        case rules = "Rules"
        case violations = "Violations"
        case audit = "Audit Log"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with compliance score
            header
            
            // Tab bar
            Picker("Tab", selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            // Tab content
            switch selectedTab {
            case .overview:
                overviewTab
            case .rules:
                rulesTab
            case .violations:
                violationsTab
            case .audit:
                auditTab
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .sheet(isPresented: $showAddRule) {
            AddRuleSheet(engine: engine)
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        let summary = engine.complianceSummary
        
        return HStack(spacing: 24) {
            VStack(alignment: .leading) {
                Text("Governance")
                    .font(.title2)
                Text("\(summary.activeRules) active rules")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Compliance score
            VStack {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                        .frame(width: 60, height: 60)
                    Circle()
                        .trim(from: 0, to: summary.complianceScore)
                        .stroke(summary.isCompliant ? Color.green : Color.orange, lineWidth: 8)
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(summary.complianceScore * 100))%")
                        .font(.caption)
                        .fontWeight(.bold)
                }
                Text("Compliance")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            // Violation counts
            HStack(spacing: 16) {
                if summary.criticalViolations > 0 {
                    ViolationBadge(count: summary.criticalViolations, color: .red, label: "Critical")
                }
                if summary.warningViolations > 0 {
                    ViolationBadge(count: summary.warningViolations, color: .orange, label: "Warning")
                }
                if summary.infoViolations > 0 {
                    ViolationBadge(count: summary.infoViolations, color: .blue, label: "Info")
                }
                if summary.resolvedViolations > 0 {
                    ViolationBadge(count: summary.resolvedViolations, color: .green, label: "Resolved")
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Overview Tab
    
    private var overviewTab: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                // Quick stats
                HStack(spacing: 16) {
                    StatCard(title: "Total Rules", value: "\(engine.rules.count)", icon: "list.bullet")
                    StatCard(title: "Active Rules", value: "\(engine.rules.filter(\.isEnabled).count)", icon: "checkmark.circle")
                    StatCard(title: "Open Violations", value: "\(engine.violations.filter { !$0.isResolved }.count)", icon: "exclamationmark.triangle")
                    StatCard(title: "Resolved", value: "\(engine.violations.filter(\.isResolved).count)", icon: "checkmark.seal")
                }
                
                // Recent violations
                if !engine.violations.isEmpty {
                    Text("Recent Violations")
                        .font(.headline)
                    ForEach(engine.violations.prefix(5)) { violation in
                        ViolationRowView(violation: violation, engine: engine)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Rules Tab
    
    private var rulesTab: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(engine.rules.count) rules")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showAddRule = true
                } label: {
                    Label("Add Rule", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            
            Divider()
            
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(engine.rules) { rule in
                        RuleRowView(rule: rule, engine: engine)
                    }
                }
                .padding(8)
            }
        }
    }
    
    // MARK: - Violations Tab
    
    private var violationsTab: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(engine.violations.filter { !$0.isResolved }.count) open violations")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle("Show resolved", isOn: $showResolvedViolations)
                    .toggleStyle(.switch)
            }
            .padding()
            
            Divider()
            
            ScrollView {
                LazyVStack(spacing: 1) {
                    let violations = showResolvedViolations ? engine.violations : engine.violations.filter { !$0.isResolved }
                    ForEach(violations) { violation in
                        ViolationRowView(violation: violation, engine: engine)
                    }
                }
                .padding(8)
            }
        }
    }
    
    // MARK: - Audit Tab
    
    private var auditTab: some View {
        VStack(spacing: 16) {
            Text("Audit Log")
                .font(.headline)
            Text("Value-free audit trail — records what happened, never document content.")
                .font(.callout)
                .foregroundStyle(.secondary)
            
            if engine.violations.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.shield")
                        .font(.largeTitle)
                        .foregroundStyle(.green)
                    Text("No violations recorded")
                        .font(.callout)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(engine.violations) { violation in
                            HStack {
                                Circle()
                                    .fill(violation.severity == .critical ? .red : violation.severity == .warning ? .orange : .blue)
                                    .frame(width: 8, height: 8)
                                Text(violation.detectedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .monospaced()
                                Text(violation.ruleName)
                                    .font(.callout)
                                Spacer()
                                Text(violation.isResolved ? "Resolved" : "Open")
                                    .font(.caption)
                                    .foregroundStyle(violation.isResolved ? .green : .secondary)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 100)
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Violation Badge

struct ViolationBadge: View {
    let count: Int
    let color: Color
    let label: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Rule Row

struct RuleRowView: View {
    let rule: PolicyRule
    @ObservedObject var engine: GovernanceEngine
    
    var body: some View {
        HStack(spacing: 12) {
            // Severity indicator
            Circle()
                .fill(rule.severity == .critical ? .red : rule.severity == .warning ? .orange : .blue)
                .frame(width: 10, height: 10)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.name)
                    .font(.body)
                Text(rule.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(rule.type.displayName)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .clipShape(Capsule())
            
            Toggle("", isOn: Binding(
                get: { rule.isEnabled },
                set: { _ in engine.toggleRule(id: rule.id) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}

// MARK: - Violation Row

struct ViolationRowView: View {
    let violation: PolicyViolation
    @ObservedObject var engine: GovernanceEngine
    
    var body: some View {
        HStack(spacing: 12) {
            // Severity indicator
            Circle()
                .fill(violation.severity == .critical ? .red : violation.severity == .warning ? .orange : .blue)
                .frame(width: 10, height: 10)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(violation.ruleName)
                    .font(.body)
                Text(violation.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if let path = violation.documentPath {
                Text((path as NSString).lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Text(violation.detectedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            if !violation.isResolved {
                Button("Resolve") {
                    engine.resolveViolation(id: violation.id)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}

// MARK: - Add Rule Sheet

struct AddRuleSheet: View {
    @ObservedObject var engine: GovernanceEngine
    @State private var ruleType: PolicyRuleType = .size
    @State private var ruleName = ""
    @State private var ruleDescription = ""
    @State private var severity: ViolationSeverity = .warning
    @State private var parameterKey = ""
    @State private var parameterValue = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Add Policy Rule")
                .font(.headline)
            
            Form {
                Picker("Type", selection: $ruleType) {
                    ForEach(PolicyRuleType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                
                TextField("Rule Name", text: $ruleName)
                TextField("Description", text: $ruleDescription)
                
                Picker("Severity", selection: $severity) {
                    ForEach(ViolationSeverity.allCases, id: \.self) { sev in
                        Text(sev.rawValue.capitalized).tag(sev)
                    }
                }
                
                Section("Parameters") {
                    HStack {
                        TextField("Key", text: $parameterKey)
                        TextField("Value", text: $parameterValue)
                    }
                }
            }
            .formStyle(.grouped)
            
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add Rule") {
                    let rule = PolicyRule(
                        type: ruleType,
                        name: ruleName,
                        description: ruleDescription,
                        severity: severity,
                        parameters: parameterKey.isEmpty ? [:] : [parameterKey: parameterValue]
                    )
                    engine.addRule(rule)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(ruleName.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
}
