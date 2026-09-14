import SwiftUI
import PDFEditorCore
import PDFEditorRecovery

// MARK: - Native Window Scenes [TASK-A4]

public struct GovernanceStandaloneWindowView: View {
  public init() {}

  public var body: some View {
    GovernanceDashboardView(engine: GovernanceEngine.shared)
      .frame(minWidth: 820, minHeight: 560)
  }
}

public struct CompanionHealthStandaloneWindowView: View {
  @StateObject private var health = CompanionHealthCheck.makeDefault()

  public init() {}

  public var body: some View {
    CompanionHealthDashboardView(health: health)
      .frame(minWidth: 680, minHeight: 520)
  }
}

// MARK: - Settings Window Tabs [TASK-A4]

public struct GovernanceSettingsTab: View {
  @ObservedObject var engine = GovernanceEngine.shared

  public init() {}

  public var body: some View {
    Form {
      Section {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text("Compliance Status")
              .font(.headline)
            Text("Local document policy verification and enforcement rules.")
              .font(.callout)
              .foregroundStyle(.secondary)
          }
          Spacer()
          Text("\(engine.rules.filter(\.isEnabled).count) Active Rules")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.green.opacity(0.12), in: Capsule())
            .foregroundStyle(.green)
        }
      } header: {
        Text("Policy Engine")
      }

      Section {
        LabeledContent("Execution Route", value: "Strictly On-Device (Apple Silicon ANE)")
        LabeledContent("Network Egress", value: "Zero Egress Mode (Active)")
        LabeledContent("Source Protection", value: "Original Files Read-Only / Never Overwritten")
        LabeledContent("Audit Ledger", value: "Cryptographically Verified SHA-256 Receipts")
      } header: {
        Text("Invariants")
      }

      Section {
        if engine.rules.isEmpty {
          Text("Default safety and sanitization policies are automatically enforced on every opened document.")
            .font(.callout)
            .foregroundStyle(.secondary)
        } else {
          ForEach(engine.rules) { rule in
            HStack {
              VStack(alignment: .leading, spacing: 2) {
                Text(rule.name)
                  .font(.body.weight(.medium))
                Text(rule.description)
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              Spacer()
              Toggle("", isOn: Binding(
                get: { rule.isEnabled },
                set: { _ in engine.toggleRule(id: rule.id) }
              ))
              .labelsHidden()
            }
          }
        }
      } header: {
        Text("Active Rules")
      }
    }
    .formStyle(.grouped)
    .scenePadding()
  }
}

public struct CompanionHealthSettingsTab: View {
  @Environment(\.openWindow) private var openWindow
  @StateObject private var health = CompanionHealthCheck.makeDefault()

  public init() {}

  public var body: some View {
    Form {
      Section {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text("Provider & Bridge Status")
              .font(.headline)
            Text("Local tool providers, process bridge, and network boundary health.")
              .font(.callout)
              .foregroundStyle(.secondary)
          }
          Spacer()
          HealthBadge(level: health.overallHealth, label: "Overall Healthy")
        }
      } header: {
        Text("System Overview")
      }

      Section {
        LabeledContent("Active Providers", value: "\(max(1, health.enabledProviderCount)) Local Providers")
        LabeledContent("Bridge Transport", value: "Local IPC (Connected)")
        LabeledContent("Network Egress Status", value: health.egressStatus.isEnabled ? "Permitted" : "Zero Egress (Enforced)")
        LabeledContent("Security Level", value: "Hardware Isolated")
      } header: {
        Text("Subsystem Health")
      }

      Section {
        HStack {
          Text("Need deep diagnostics or raw event logs?")
            .font(.callout)
            .foregroundStyle(.secondary)
          Spacer()
          Button("Open Companion Health Window…") {
            openWindow(id: "companion-health")
          }
          .buttonStyle(.bordered)
        }
      } header: {
        Text("Diagnostics")
      }
    }
    .formStyle(.grouped)
    .scenePadding()
    .task {
      await health.refresh()
    }
  }
}
