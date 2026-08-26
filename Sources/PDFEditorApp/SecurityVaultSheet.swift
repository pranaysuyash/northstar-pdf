import AppKit
import PDFEditorCore
import PDFEditorRecovery
import SwiftUI

public struct SecurityVaultSheet: View {
  @Bindable var model: AppModel
  @Environment(\.dismiss) private var dismiss
  @State private var selectedTab = 0
  // Performance: cache sorted audit events to avoid re-sorting on every body evaluation
  @State private var cachedSortedEvents: [PDFLocalStoreAuditEvent] = []

  public init(model: AppModel) {
    self.model = model
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Header
      HStack {
        VStack(alignment: .leading, spacing: 3) {
          HStack(spacing: 8) {
            Image(systemName: "lock.shield.fill")
              .font(.title2)
              .foregroundStyle(.tint)
              .accessibilityHidden(true)
            Text("Security & Privacy Vault")
              .font(.title2.weight(.semibold))
          }
          Text("Hardware-isolated encrypted local stores, zero network egress, and recovery envelope administration.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Button("Done") {
          dismiss()
        }
        .keyboardShortcut(.defaultAction)
        .buttonStyle(.borderedProminent)
      }
      .padding([.horizontal, .top], 24)
      .padding(.bottom, 16)

      Divider()

      // Tabs
      Picker("Vault Category", selection: $selectedTab) {
        Text("Overview & Health").tag(0)
        Text("Profiles & Keys").tag(1)
        Text("Templates").tag(2)
        Text("Audit Trail").tag(3)
      }
      .pickerStyle(.segmented)
      .padding(.horizontal, 24)
      .padding(.vertical, 12)

      Divider()

      // Tab Content
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          if selectedTab == 0 {
            overviewTab
          } else if selectedTab == 1 {
            profilesTab
          } else if selectedTab == 2 {
            templatesTab
          } else {
            auditTrailTab
          }
        }
        .padding(24)
      }
      .frame(height: 380)

      Divider()

      // Footer notice
      HStack {
        Image(systemName: "checkmark.shield")
          .foregroundStyle(.green)
        Text("All operations run in local process space. No cloud transmission, no analytics tracking.")
          .font(.caption2)
          .foregroundStyle(.secondary)
        Spacer()
      }
      .padding(.horizontal, 24)
      .padding(.vertical, 10)
      /* Warm-tinted header */
      .background(Color.orange.opacity(0.04))
    }
    .frame(width: 640)
  }

  private var overviewTab: some View {
    VStack(alignment: .leading, spacing: 14) {
      // Security Posture Cards
      HStack(spacing: 12) {
        securityStatusCard(
          title: "Profile Vault",
          icon: model.isProfileVaultUnlocked ? "lock.open.fill" : "lock.fill",
          color: model.isProfileVaultUnlocked ? .green : .orange,
          status: model.isProfileVaultUnlocked ? "Unlocked (Keychain)" : "Locked",
          details: "\(model.availableProfiles.count) local profile(s)"
        )

        securityStatusCard(
          title: "Template Vault",
          icon: model.isTemplateVaultUnlocked ? "lock.open.fill" : "lock.fill",
          color: model.isTemplateVaultUnlocked ? .green : .orange,
          status: model.isTemplateVaultUnlocked ? "Unlocked (Keychain)" : "Locked",
          details: "\(model.templateStoreHealth?.recordCount ?? 0) record(s)"
        )

        securityStatusCard(
          title: "Processing Mode",
          icon: "antenna.radiowaves.left.and.right.slash",
          color: .blue,
          status: "Zero-Egress",
          details: "100% Local PDFKit"
        )
      }

      Divider()

      // Preflight Summary
      VStack(alignment: .leading, spacing: 8) {
        Text("Active Document Preflight")
          .font(.headline)

        if let report = model.preflightReport {
          Text("Source Digest: \(report.header.sourceDigest.prefix(16))...")
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)

          HStack(spacing: 16) {
            Label("\(report.payload.summary.findingCount) Findings", systemImage: "magnifyingglass")
            Label("\(report.payload.summary.metadataFieldCount) Metadata", systemImage: "doc.text")
            Label("\(report.payload.summary.embeddedDataCount) Embedded", systemImage: "paperclip")
            Label("0 Network Calls", systemImage: "network.slash")
          }
          .font(.caption)
          .foregroundStyle(.secondary)
        } else {
          Text("Open a PDF document to generate an automated privacy preflight report.")
            .font(.callout)
            .foregroundStyle(.secondary)
        }
      }
      .padding(12)
      /* Warm-tinted section */
      .background(Color.orange.opacity(0.05))
      .clipShape(RoundedRectangle(cornerRadius: 8))

      Button("Refresh Store Health & Diagnostics") {
        model.refreshLocalPersistenceHealth()
      }
      .buttonStyle(.bordered)
      .font(.caption)
    }
  }

  private func securityStatusCard(title: String, icon: String, color: Color, status: String, details: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Image(systemName: icon)
          .foregroundStyle(color)
        Text(title)
          .font(.caption.weight(.semibold))
      }
      Text(status)
        .font(.subheadline.weight(.medium))
        .foregroundStyle(color)
      Text(details)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    /* Warm-tinted section */
    .background(Color.orange.opacity(0.05))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }

  private var profilesTab: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Text("Encrypted Profile Vault")
          .font(.headline)
        Spacer()
        if model.isProfileVaultUnlocked {
          Button("Lock Vault", systemImage: "lock") {
            model.lockProfileVault()
          }
          .buttonStyle(.bordered)
          .font(.caption)
        } else {
          Button("Unlock with Keychain", systemImage: "lock.open") {
            model.unlockProfileVault()
          }
          .buttonStyle(.borderedProminent)
          .font(.caption)
        }
      }

      Text("Profiles store autofill values (Name, Address, Tax IDs) protected with AES-GCM and stored in the macOS Keychain.")
        .font(.caption)
        .foregroundStyle(.secondary)

      Divider()

      Text("Recovery & Backup Tools")
        .font(.subheadline.weight(.semibold))

      HStack(spacing: 8) {
        Button("Export Recovery Envelope") { model.exportProfileRecoveryEnvelope() }
          .buttonStyle(.bordered)
          .disabled(!model.isProfileVaultUnlocked)
        Button("Import Recovery Envelope") { model.importProfileRecoveryEnvelope() }
          .buttonStyle(.bordered)
      }
      .font(.caption)

      HStack(spacing: 8) {
        Button("Export Encrypted Backup") { model.exportProfileVaultBackup() }
          .buttonStyle(.bordered)
          .disabled(!model.isProfileVaultUnlocked)
        Button("Import Encrypted Backup") { model.importProfileVaultBackup() }
          .buttonStyle(.bordered)
        Button("Cross-Device Export") { model.exportProfileCrossDeviceRecovery() }
          .buttonStyle(.bordered)
          .disabled(!model.isProfileVaultUnlocked)
        Button("Cross-Device Import") { model.importProfileCrossDeviceRecovery() }
          .buttonStyle(.bordered)
      }
      .font(.caption)

      Divider()

      Button("Delete All Profile Records", role: .destructive) {
        model.deleteAllProfileVaultRecords()
      }
      .buttonStyle(.bordered)
      .font(.caption)
      .disabled(!model.isProfileVaultUnlocked)
    }
  }

  private var templatesTab: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Text("Encrypted Template Store")
          .font(.headline)
        Spacer()
        if !model.isTemplateVaultUnlocked {
          Button("Unlock Vault", systemImage: "lock.open") {
            model.unlockTemplateVault()
          }
          .buttonStyle(.borderedProminent)
          .font(.caption)
        }
      }

      Text("Templates store document layout geometry fingerprints and semantic field associations without saving source PDF bytes.")
        .font(.caption)
        .foregroundStyle(.secondary)

      Divider()

      Text("Backup & Recovery Tools")
        .font(.subheadline.weight(.semibold))

      HStack(spacing: 8) {
        Button("Export Template Envelope") { model.exportTemplateRecoveryEnvelope() }
          .buttonStyle(.bordered)
          .disabled(!model.isTemplateVaultUnlocked)
        Button("Import Template Envelope") { model.importTemplateRecoveryEnvelope() }
          .buttonStyle(.bordered)
      }
      .font(.caption)

      HStack(spacing: 8) {
        Button("Export Vault Backup") { model.exportTemplateVaultBackup() }
          .buttonStyle(.bordered)
          .disabled(!model.isTemplateVaultUnlocked)
        Button("Import Vault Backup") { model.importTemplateVaultBackup() }
          .buttonStyle(.bordered)
        Button("Cross-Device Export") { model.exportTemplateCrossDeviceRecovery() }
          .buttonStyle(.bordered)
          .disabled(!model.isTemplateVaultUnlocked)
        Button("Cross-Device Import") { model.importTemplateCrossDeviceRecovery() }
          .buttonStyle(.bordered)
      }
      .font(.caption)

      Divider()

      Button("Delete All Template Records", role: .destructive) {
        model.deleteAllTemplateVaultRecords()
      }
      .buttonStyle(.bordered)
      .font(.caption)
      .disabled(!model.isTemplateVaultUnlocked)
    }
  }

  private var auditTrailTab: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Value-Free Privacy Audit Ledger")
        .font(.headline)
      Text("Immutable log of cryptographic store operations. Audit records verify lifecycle events without logging confidential field values or user secrets.")
        .font(.caption)
        .foregroundStyle(.secondary)

      if cachedSortedEvents.isEmpty {
        Text("No audit events recorded in this session yet.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .padding(.vertical, 20)
      } else {
        List(cachedSortedEvents, id: \.id) { event in
          HStack {
            VStack(alignment: .leading, spacing: 2) {
              Text(event.action.rawValue.capitalized)
                .font(.caption.weight(.semibold))
              Text("\(event.state.rawValue) · \(event.reasonCode ?? "ok")")
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Text(event.outcome.rawValue)
              .font(.caption2.weight(.medium))
              .foregroundStyle(event.outcome == .succeeded ? Color.green : Color.orange)
          }
          .padding(.vertical, 2)
        }
        .listStyle(.plain)
        .frame(height: 220)
      }
    }
    .onAppear { refreshCachedEvents() }
    .onChange(of: model.templateAuditEvents) { _, _ in refreshCachedEvents() }
    .onChange(of: model.profileAuditEvents) { _, _ in refreshCachedEvents() }
  }

  private func refreshCachedEvents() {
    cachedSortedEvents = (model.templateAuditEvents + model.profileAuditEvents)
      .sorted(by: { $0.createdAt > $1.createdAt })
  }
}
