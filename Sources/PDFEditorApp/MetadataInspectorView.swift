import PDFEditorCore
import PDFKit
import SwiftUI

/// Rich metadata inspector panel showing document properties, permissions,
/// fonts, security info, and document statistics.
///
/// First principle: metadata is the document's identity — who made it, when,
/// what it contains, and what you can do with it. Surfaces hidden information
/// that affects trust and usability.
///
/// Doctrine alignment:
/// - §5: Evidence-based — all metadata comes from the PDF itself, not assumptions
/// - §8: Capability routing — metadata is available when document is loaded
/// - Long-term: Foundation for document comparison, provenance tracking

// MARK: - Metadata Inspector View

/// Rich metadata inspector showing document properties, permissions, and stats.
public struct MetadataInspectorView: View {
  let inspection: DocumentInspection?
  let documentURL: URL?
  let pageCount: Int
  let annotationCount: Int
  let formFieldCount: Int

  @State private var selectedTab: MetadataTab = .properties

  public enum MetadataTab: String, CaseIterable {
    case properties = "Properties"
    case permissions = "Permissions"
    case fonts = "Fonts"
    case security = "Security"
    case statistics = "Statistics"
  }

  public init(
    inspection: DocumentInspection?,
    documentURL: URL?,
    pageCount: Int = 0,
    annotationCount: Int = 0,
    formFieldCount: Int = 0
  ) {
    self.inspection = inspection
    self.documentURL = documentURL
    self.pageCount = pageCount
    self.annotationCount = annotationCount
    self.formFieldCount = formFieldCount
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Tab picker
      Picker("", selection: $selectedTab) {
        ForEach(MetadataTab.allCases, id: \.self) { tab in
          Text(tab.rawValue).tag(tab)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .padding(.horizontal, 8)
      .padding(.vertical, 6)

      Divider()

      // Tab content
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          switch selectedTab {
          case .properties:
            propertiesTab
          case .permissions:
            permissionsTab
          case .fonts:
            fontsTab
          case .security:
            securityTab
          case .statistics:
            statisticsTab
          }
        }
        .padding(12)
      }
    }
    .frame(width: 260)
  }

  // MARK: - Properties Tab

  private var propertiesTab: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionHeader("Document Info")

      if let url = documentURL {
        metadataRow("File", url.lastPathComponent)
        metadataRow("Path", url.deletingLastPathComponent().path)
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int {
          metadataRow("Size", ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
        }
      }

      if let inspection {
        metadataRow("Title", inspection.metadata.title.isEmpty ? "Untitled" : inspection.metadata.title)
        metadataRow("Author", inspection.metadata.author.isEmpty ? "Unknown" : inspection.metadata.author)
        metadataRow("Creator", inspection.metadata.creator.isEmpty ? "Unknown" : inspection.metadata.creator)
        metadataRow("Producer", inspection.metadata.producer.isEmpty ? "Unknown" : inspection.metadata.producer)
        metadataRow("Pages", "\(inspection.pages.count)")
        metadataRow("Created", inspection.metadata.creationDate.isEmpty ? "Unknown" : inspection.metadata.creationDate)
        metadataRow("Modified", inspection.metadata.modificationDate.isEmpty ? "Unknown" : inspection.metadata.modificationDate)
      }
    }
  }

  // MARK: - Permissions Tab

  private var permissionsTab: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionHeader("Document Permissions")

      if let inspection {
        permissionRow("Printing", inspection.permissions.canPrint)
        permissionRow("Copy Text", inspection.permissions.canCopy)
        permissionRow("Modify", inspection.permissions.canModify)
        permissionRow("Add Annotations", inspection.permissions.canAddAnnotations)
        permissionRow("Read Only", inspection.permissions.isReadOnly)
      }

      Divider()

      sectionHeader("Capability Status")

      if let inspection {
        let status = inspection.permissions.isReadOnly ? "Read-Only" : "Full Access"
        let color: Color = inspection.permissions.isReadOnly ? .orange : .green
        HStack {
          Circle().fill(color).frame(width: 8, height: 8)
          Text(status)
            .font(.caption)
        }
      }
    }
  }

  // MARK: - Fonts Tab

  private var fontsTab: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionHeader("Document Fonts")

      Text("Font information is available through the PDF inspection pipeline.")
        .font(.caption)
        .foregroundStyle(.secondary)

      if let inspection {
        let totalPages = inspection.pages.count
        let selectablePages = inspection.pages.filter { $0.hasSelectableText }.count
        metadataRow("Pages with Text", "\(selectablePages) / \(totalPages)")
      }
    }
  }

  // MARK: - Security Tab

  private var securityTab: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionHeader("Security")

      if let inspection {
        metadataRow("Encrypted", inspection.security.isEncrypted ? "Yes" : "No")
        if inspection.security.isEncrypted {
          metadataRow("Password Required", inspection.security.requiresPassword ? "Yes" : "No")
          metadataRow("Locked", inspection.security.isLocked ? "Yes" : "No")
        }

        Divider()

        sectionHeader("Digital Signatures")

        let hasSigs = inspection.annotationTypeCounts["signature", default: 0] > 0
        metadataRow("Signed", hasSigs ? "Yes" : "No")
        if !hasSigs {
          Text("This document has no digital signatures.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  // MARK: - Statistics Tab

  private var statisticsTab: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionHeader("Document Statistics")

      metadataRow("Pages", "\(pageCount)")
      metadataRow("Annotations", "\(annotationCount)")
      metadataRow("Form Fields", "\(formFieldCount)")

      if let inspection {
        Divider()
        sectionHeader("Content")
        metadataRow("Fields", "\(inspection.fields.count)")
        metadataRow("Links", "\(inspection.links.count)")
        metadataRow("Outlines", "\(inspection.outlines.count)")
        metadataRow("Attachments", "\(inspection.attachments.count)")
      }
    }
  }

  // MARK: - Helpers

  private func sectionHeader(_ title: String) -> some View {
    Text(title)
      .font(.caption)
      .fontWeight(.semibold)
      .foregroundStyle(.secondary)
      .textCase(.uppercase)
  }

  private func metadataRow(_ label: String, _ value: String) -> some View {
    HStack(alignment: .top) {
      Text(label)
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(width: 80, alignment: .trailing)
      Text(value)
        .font(.caption)
      Spacer()
    }
  }

  private func permissionRow(_ label: String, _ allowed: Bool) -> some View {
    HStack {
      Image(systemName: allowed ? "checkmark.circle.fill" : "xmark.circle.fill")
        .foregroundColor(allowed ? .green : .red)
        .font(.caption)
      Text(label)
        .font(.caption)
      Spacer()
      Text(allowed ? "Allowed" : "Denied")
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
  }

  private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }
}
