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
    VStack(alignment: .leading, spacing: 16) {
      // Security Posture Cards
      HStack(spacing: 12) {
        securityStatusCard(
          title: "Profile Vault",
          icon: model.isProfileVaultUnlocked ? "lock.open.fill" : "lock.fill",
          color: model.isProfileVaultUnlocked ? .green : .orange,
          status: model.isProfileVaultUnlocked ? "Unlocked" : "Locked",
          details: "\(model.availableProfiles.count) local profile(s)"
        )

        securityStatusCard(
          title: "Template Vault",
          icon: model.isTemplateVaultUnlocked ? "lock.open.fill" : "lock.fill",
          color: model.isTemplateVaultUnlocked ? .green : .orange,
          status: model.isTemplateVaultUnlocked ? "Unlocked" : "Locked",
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

      // Preflight Summary Card
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Label("Active Document Preflight", systemImage: "doc.badge.gearshape")
            .font(.subheadline.weight(.semibold))
          Spacer()
          if let report = model.preflightReport {
            Text("\(report.header.sourceDigest.prefix(12))…")
              .font(.caption2.monospaced())
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
              .foregroundStyle(.secondary)
          }
        }

        if let report = model.preflightReport {
          HStack(spacing: 8) {
            Label("\(report.payload.summary.findingCount) Findings", systemImage: "magnifyingglass")
              .font(.caption2.weight(.medium))
              .padding(.horizontal, 8)
              .padding(.vertical, 3)
              .background(Color.blue.opacity(0.1), in: Capsule())
              .foregroundStyle(.blue)

            Label("\(report.payload.summary.metadataFieldCount) Metadata", systemImage: "doc.text")
              .font(.caption2.weight(.medium))
              .padding(.horizontal, 8)
              .padding(.vertical, 3)
              .background(Color.purple.opacity(0.1), in: Capsule())
              .foregroundStyle(.purple)

            Label("\(report.payload.summary.embeddedDataCount) Embedded", systemImage: "paperclip")
              .font(.caption2.weight(.medium))
              .padding(.horizontal, 8)
              .padding(.vertical, 3)
              .background(Color.secondary.opacity(0.12), in: Capsule())
              .foregroundStyle(.secondary)

            Label("0 Network Calls", systemImage: "network.slash")
              .font(.caption2.weight(.medium))
              .padding(.horizontal, 8)
              .padding(.vertical, 3)
              .background(Color.green.opacity(0.1), in: Capsule())
              .foregroundStyle(.green)
          }
        } else {
          Text("Open a PDF document to generate an automated privacy preflight report.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .padding(14)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
      )

      HStack {
        Button {
          model.refreshLocalPersistenceHealth()
        } label: {
          Label("Refresh Store Health & Diagnostics", systemImage: "arrow.clockwise")
            .font(.caption.weight(.medium))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)

        Spacer()
      }
    }
  }

  private func securityStatusCard(title: String, icon: String, color: Color, status: String, details: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        ZStack {
          Circle()
            .fill(color.opacity(0.15))
            .frame(width: 28, height: 28)
          Image(systemName: icon)
            .font(.caption.weight(.bold))
            .foregroundStyle(color)
        }
        Spacer()
        Text(status)
          .font(.caption2.weight(.bold))
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(color.opacity(0.12), in: Capsule())
          .foregroundStyle(color)
      }

      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.caption.weight(.semibold))
        Text(details)
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .strokeBorder(color.opacity(0.18), lineWidth: 1)
    )
  }

  private var profilesTab: some View {
    VStack(alignment: .leading, spacing: 14) {
      vaultSectionHeader(
        title: "Encrypted Profile Vault",
        subtitle: "Profiles store autofill values (Name, Address, Tax IDs) protected with AES-GCM and stored in the macOS Keychain.",
        icon: "person.crop.circle.badge.checkmark",
        isUnlocked: model.isProfileVaultUnlocked,
        onToggleLock: {
          if model.isProfileVaultUnlocked {
            model.lockProfileVault()
          } else {
            model.unlockProfileVault()
          }
        }
      )

      Text("Recovery & Backup Tools")
        .font(.subheadline.weight(.semibold))

      HStack(spacing: 10) {
        backupActionCard(
          title: "Recovery Envelope",
          subtitle: "Single-file bundle",
          icon: "envelope.badge.shield.half.filled",
          exportAction: { model.exportProfileRecoveryEnvelope() },
          importAction: { model.importProfileRecoveryEnvelope() },
          exportDisabled: !model.isProfileVaultUnlocked
        )

        backupActionCard(
          title: "Encrypted Backup",
          subtitle: "Key derivation export",
          icon: "archivebox.fill",
          exportAction: { model.exportProfileVaultBackup() },
          importAction: { model.importProfileVaultBackup() },
          exportDisabled: !model.isProfileVaultUnlocked
        )

        backupActionCard(
          title: "Cross-Device Sync",
          subtitle: "Transfer payload",
          icon: "laptopcomputer.and.iphone",
          exportAction: { model.exportProfileCrossDeviceRecovery() },
          importAction: { model.importProfileCrossDeviceRecovery() },
          exportDisabled: !model.isProfileVaultUnlocked
        )
      }

      dangerZoneCard(
        title: "Delete All Profile Records",
        description: "Permanently erase all local profile values from Keychain.",
        buttonLabel: "Wipe Profile Store",
        onAction: { model.deleteAllProfileVaultRecords() },
        disabled: !model.isProfileVaultUnlocked
      )
    }
  }

  private var templatesTab: some View {
    VStack(alignment: .leading, spacing: 14) {
      vaultSectionHeader(
        title: "Encrypted Template Store",
        subtitle: "Templates store document layout geometry fingerprints and semantic field associations without saving source PDF bytes.",
        icon: "doc.viewfinder.fill",
        isUnlocked: model.isTemplateVaultUnlocked,
        onToggleLock: {
          if model.isTemplateVaultUnlocked {
            model.lockTemplateVault()
          } else {
            model.unlockTemplateVault()
          }
        }
      )

      Text("Backup & Recovery Tools")
        .font(.subheadline.weight(.semibold))

      HStack(spacing: 10) {
        backupActionCard(
          title: "Template Envelope",
          subtitle: "Layout signature bundle",
          icon: "envelope.badge.shield.half.filled",
          exportAction: { model.exportTemplateRecoveryEnvelope() },
          importAction: { model.importTemplateRecoveryEnvelope() },
          exportDisabled: !model.isTemplateVaultUnlocked
        )

        backupActionCard(
          title: "Vault Backup",
          subtitle: "Encrypted archive",
          icon: "archivebox.fill",
          exportAction: { model.exportTemplateVaultBackup() },
          importAction: { model.importTemplateVaultBackup() },
          exportDisabled: !model.isTemplateVaultUnlocked
        )

        backupActionCard(
          title: "Cross-Device Sync",
          subtitle: "Layout transfer",
          icon: "laptopcomputer.and.iphone",
          exportAction: { model.exportTemplateCrossDeviceRecovery() },
          importAction: { model.importTemplateCrossDeviceRecovery() },
          exportDisabled: !model.isTemplateVaultUnlocked
        )
      }

      dangerZoneCard(
        title: "Delete All Template Records",
        description: "Permanently erase learned document layout fingerprints.",
        buttonLabel: "Wipe Template Store",
        onAction: { model.deleteAllTemplateVaultRecords() },
        disabled: !model.isTemplateVaultUnlocked
      )
    }
  }

  private var auditTrailTab: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text("Value-Free Privacy Audit Ledger")
            .font(.headline)
          Text("Immutable log of cryptographic store operations without logging user secrets.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        HStack(spacing: 6) {
          Label("\(cachedSortedEvents.count) Events", systemImage: "list.bullet.rectangle")
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.primary.opacity(0.06), in: Capsule())

          Label("Zero Egress", systemImage: "checkmark.shield.fill")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.green)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.green.opacity(0.12), in: Capsule())
        }
      }

      if cachedSortedEvents.isEmpty {
        VStack(spacing: 8) {
          Image(systemName: "doc.text.magnifyingglass")
            .font(.largeTitle)
            .foregroundStyle(.secondary)
          Text("No audit events recorded in this session yet.")
            .font(.callout.weight(.medium))
          Text("Store operations like unlocking, exporting, or importing generate verified ledger entries here.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
      } else {
        ScrollView {
          VStack(spacing: 6) {
            ForEach(cachedSortedEvents, id: \.id) { event in
              HStack(spacing: 10) {
                ZStack {
                  Circle()
                    .fill(event.outcome == .succeeded ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                    .frame(width: 28, height: 28)
                  Image(systemName: event.outcome == .succeeded ? "checkmark" : "exclamationmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(event.outcome == .succeeded ? .green : .orange)
                }

                VStack(alignment: .leading, spacing: 2) {
                  Text(event.action.rawValue.capitalized)
                    .font(.caption.weight(.semibold))
                  Text("\(event.state.rawValue) · \(event.reasonCode ?? "ok")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Text(event.outcome.rawValue)
                  .font(.caption2.weight(.semibold))
                  .padding(.horizontal, 6)
                  .padding(.vertical, 2)
                  .background(
                    (event.outcome == .succeeded ? Color.green : Color.orange).opacity(0.12),
                    in: Capsule()
                  )
                  .foregroundStyle(event.outcome == .succeeded ? .green : .orange)
              }
              .padding(.horizontal, 10)
              .padding(.vertical, 6)
              .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
              .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                  .strokeBorder(Color.primary.opacity(0.04), lineWidth: 1)
              )
            }
          }
        }
        .frame(height: 220)
      }
    }
    .onAppear { refreshCachedEvents() }
    .onChange(of: model.templateAuditEvents) { _, _ in refreshCachedEvents() }
    .onChange(of: model.profileAuditEvents) { _, _ in refreshCachedEvents() }
  }

  private func vaultSectionHeader(
    title: String,
    subtitle: String,
    icon: String,
    isUnlocked: Bool,
    onToggleLock: @escaping () -> Void
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        ZStack {
          Circle()
            .fill((isUnlocked ? Color.green : Color.orange).opacity(0.15))
            .frame(width: 30, height: 30)
          Image(systemName: isUnlocked ? "lock.open.fill" : "lock.fill")
            .font(.caption.weight(.bold))
            .foregroundStyle(isUnlocked ? .green : .orange)
        }

        VStack(alignment: .leading, spacing: 1) {
          Text(title)
            .font(.headline)
          HStack(spacing: 4) {
            Circle()
              .fill(isUnlocked ? Color.green : Color.orange)
              .frame(width: 6, height: 6)
            Text(isUnlocked ? "Unlocked & Ready" : "Hardware Locked")
              .font(.caption2.weight(.bold))
              .foregroundStyle(isUnlocked ? .green : .orange)
          }
        }

        Spacer()

        if isUnlocked {
          Button("Lock Vault", systemImage: "lock") {
            onToggleLock()
          }
          .buttonStyle(.bordered)
          .controlSize(.small)
        } else {
          Button("Unlock with Keychain", systemImage: "key.fill") {
            onToggleLock()
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.small)
        }
      }

      Text(subtitle)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(12)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .strokeBorder((isUnlocked ? Color.green : Color.orange).opacity(0.18), lineWidth: 1)
    )
  }

  private func backupActionCard(
    title: String,
    subtitle: String,
    icon: String,
    exportAction: @escaping () -> Void,
    importAction: @escaping () -> Void,
    exportDisabled: Bool
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 6) {
        Image(systemName: icon)
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        Text(title)
          .font(.caption.weight(.semibold))
          .lineLimit(1)
      }

      Text(subtitle)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)

      HStack(spacing: 6) {
        Button {
          exportAction()
        } label: {
          Label("Export", systemImage: "arrow.up.doc")
            .font(.caption2.weight(.medium))
        }
        .buttonStyle(.bordered)
        .controlSize(.mini)
        .disabled(exportDisabled)

        Button {
          importAction()
        } label: {
          Label("Import", systemImage: "arrow.down.doc")
            .font(.caption2.weight(.medium))
        }
        .buttonStyle(.bordered)
        .controlSize(.mini)
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
    )
  }

  private func dangerZoneCard(
    title: String,
    description: String,
    buttonLabel: String,
    onAction: @escaping () -> Void,
    disabled: Bool
  ) -> some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.caption.weight(.semibold))
          .foregroundStyle(.red)
        Text(description)
          .font(.caption2)
          .foregroundStyle(.secondary)
      }

      Spacer()

      Button(role: .destructive) {
        onAction()
      } label: {
        Label(buttonLabel, systemImage: "trash")
          .font(.caption.weight(.medium))
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
      .tint(.red)
      .disabled(disabled)
    }
    .padding(10)
    .background(Color.red.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .strokeBorder(Color.red.opacity(0.18), lineWidth: 1)
    )
  }

  private func refreshCachedEvents() {
    cachedSortedEvents = (model.templateAuditEvents + model.profileAuditEvents)
      .sorted(by: { $0.createdAt > $1.createdAt })
  }
}

