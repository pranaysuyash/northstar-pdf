import AppKit
import PDFEditorCore
import PDFEditorRecovery
import SwiftUI

public enum InspectorTab: String, CaseIterable, Identifiable {
  // Raw values are the canonical DESIGN.md modes: Reader, Understand,
  // Complete, Organize, Review. Case names stay stable to limit churn.
  case focus = "Complete"
  case understand = "Understand"
  case learn = "Organize"
  case document = "Reader"
  case trust = "Review"

  public var id: String { rawValue }
  public var symbolName: String {
    switch self {
    case .focus: return "pencil.and.list.clipboard"
    case .understand: return "brain.head.profile"
    case .learn: return "rectangle.stack"
    case .document: return "book"
    case .trust: return "checkmark.seal"
    }
  }

}

public struct ContextualInspectorView: View {
  @Bindable var model: AppModel
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let inspection: DocumentInspection
  let renderingPipeline: RenderingPipeline
  @Binding var isSecurityVaultPresented: Bool
  @ObservedObject var annotationStore: AnnotationStore
  @State private var selectedTab: InspectorTab = .focus
  // UNDERSTAND tab state
  @State private var understandResult: (summary: DocumentSummary?, entities: EntityRecognitionResult?, keyPoints: KeyPointExtractionResult?, nerEntities: NERResult?, tables: TableExtractionResult?, enhancedSummary: EnhancedSummary?) = (nil, nil, nil, nil, nil, nil)
  @State private var understandError: String?
  @State private var isLoadingUnderstand = false
  @State private var fieldDraft = ""
  @State private var overlayDraft = ""
  @State private var choiceCellIndex = 0
  @State private var isRenamingCandidate = false
  @State private var renameDraft = ""
  @State private var templateDisplayName = "Reviewed local layout"
  @State private var isDiscardingExportPresented = false
  @State private var isReceiptCopied = false
  @State private var evidenceQueryDraft = ""
  @State private var groundedQueryResult: GroundedQueryResult?
  @State private var signatureObservations: [SignatureObservation] = []

  public init(
    model: AppModel,
    inspection: DocumentInspection,
    renderingPipeline: RenderingPipeline,
    isSecurityVaultPresented: Binding<Bool>,
    annotationStore: AnnotationStore
  ) {
    self.model = model
    self.inspection = inspection
    self.renderingPipeline = renderingPipeline
    self._isSecurityVaultPresented = isSecurityVaultPresented
    self.annotationStore = annotationStore
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Inspector Tab Bar
      Picker("Inspector Section", selection: $selectedTab) {
        ForEach(InspectorTab.allCases) { tab in
          Label(tab.rawValue, systemImage: tab.symbolName).tag(tab)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .padding(.horizontal, 14)
      .padding(.top, 12)
      .padding(.bottom, 8)

      Divider()

      // Tab Content
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          switch selectedTab {
          case .focus:
            focusTabContent
          case .understand:
            understandTabContent
          case .learn:
            learnTabContent
          case .document:
            documentTabContent
          case .trust:
            trustTabContent
          }
        }
        .padding(14)
      }
    }
    /* Apple Design §12: light material for content panel */
    .background(.regularMaterial)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Document inspector")
    .accessibilityIdentifier("pdfEditor.documentInspector")
    .onChange(of: model.selectedFieldID, initial: true) { _, _ in
      fieldDraft = model.selectedField.map { model.currentValue(for: $0) } ?? ""
      if model.selectedFieldID != nil {
        selectedTab = .focus
      }
    }
    .onChange(of: model.selectedCandidateID, initial: true) { _, _ in
      overlayDraft = ""
      choiceCellIndex = 0
      if model.selectedCandidateID != nil {
        selectedTab = .focus
      }
    }
    .onChange(of: model.selectedTextSelection?.text, initial: true) { _, newText in
      if newText != nil {
        selectedTab = .focus
      }
    }
    .onChange(of: model.selectedTable?.id, initial: true) { _, newTableID in
      if newTableID != nil {
        selectedTab = .focus
      }
    }
    .confirmationDialog(
      "Discard the derived export copy?",
      isPresented: $isDiscardingExportPresented,
      titleVisibility: .visible
    ) {
      Button("Discard Copy", role: .destructive) {
        _ = model.discardLastExport()
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("The source file and live document operations will remain unchanged.")
    }
  }

  // MARK: - Complete Tab (case focus; raw value "Complete")
  private var focusTabContent: some View {
    VStack(alignment: .leading, spacing: 16) {
      if let xfa = model.xfaInspectionResult, xfa.kind != .absent {
        xfaFormBanner(xfa)
      }

      if let table = model.selectedTable {
        // Selection Scope: Table Object
        selectedTableContextCard(table)
      } else if let selection = model.selectedTextSelection {
        // Selection Scope: Text / Clause
        selectedTextContextCard(selection)
      } else if let mark = selectedAnnotation {
        // Selection Scope: Annotation
        selectedAnnotationContextCard(mark)
        selectedAnnotationCard(mark)
      } else if let candidate = model.selectedCandidate {
        // Selection Scope: Candidate Region
        selectedCandidateContextCard(candidate)
        selectedCandidateCard(candidate)
      } else if let field = model.selectedField {
        // Selection Scope: Native Form Field
        selectedNativeFieldContextCard(field)
        selectedNativeFieldCard(field)
      } else {
        // Document Scope: No entity selected
        documentOverviewCard
        authoringToolsPalette
        detectedFieldsNavigator
        profileBulkFillCard
        candidateSuggestionsList
        signatureAuditCard
      }

      // Explain quiet contextual projections without turning the canvas
      // menu into a disabled command inventory.
      adaptiveCommandStatusSection

      // Search Matches (if any)
      if !model.searchMatches.isEmpty {
        searchMatchesSection
      }
    }
    .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82), value: model.selectedFieldID)
    .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82), value: model.selectedCandidateID)
    .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82), value: model.selectedAnnotationID)
    .task(id: model.sourceURL) {
      // Review-only signature occupancy audit. Bounded to the first pages so
      // opening the inspector never pays a full-document raster cost.
      signatureObservations = []
      guard let document = model.liveDocument else { return }
      let observations = SignatureOccupancyAudit.observations(in: document, pageLimit: 12)
      if !Task.isCancelled { signatureObservations = observations }
    }
  }

  private func xfaFormBanner(_ xfa: XFAFormProcessor.XFAInspectionResult) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Image(systemName: "doc.text.below.ecg")
          .foregroundStyle(Color.orange)
        Text("XFA Form Detected (\(xfa.kind.rawValue))")
          .font(.subheadline.weight(.semibold))
        Spacer()
        if xfa.requiresFallbackFlattening {
          Text("Dynamic")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.orange.opacity(0.15), in: Capsule())
            .foregroundStyle(Color.orange)
        }
      }

      Text("Contains \(xfa.packetNames.joined(separator: ", ")) packets with \(xfa.extractedFields.count) XML dataset entries.")
        .font(.caption)
        .foregroundStyle(.secondary)

      if !xfa.extractedFields.isEmpty {
        DisclosureGroup("Extracted Field Data (\(xfa.extractedFields.count))") {
          VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(xfa.extractedFields.keys.sorted().prefix(8)), id: \.self) { key in
              HStack {
                Text(key)
                  .font(.caption2.monospaced())
                  .foregroundStyle(.secondary)
                Spacer()
                Text(xfa.extractedFields[key] ?? "")
                  .font(.caption2.weight(.medium))
                  .lineLimit(1)
              }
            }
            if xfa.extractedFields.count > 8 {
              Text("+ \(xfa.extractedFields.count - 8) more fields in XML dataset")
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
          }
          .padding(.top, 4)
        }
        .font(.caption)

        Button {
          let datasetText = xfa.extractedFields.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(datasetText, forType: .string)
          model.statusMessage = "Copied XFA dataset to clipboard."
        } label: {
          Label("Copy Form Dataset", systemImage: "doc.on.clipboard")
            .font(.caption.weight(.medium))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
      }
    }
    .padding(12)
    .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .strokeBorder(Color.orange.opacity(0.25), lineWidth: 1)
    )
  }

  @ViewBuilder
  private var contextEvidenceRail: some View {
    if let mark = selectedAnnotation {
      selectedAnnotationContextCard(mark)
    } else if let candidate = model.selectedCandidate {
      selectedCandidateContextCard(candidate)
    } else if let field = model.selectedField {
      selectedNativeFieldContextCard(field)
    } else {
      documentOverviewCard
    }
  }

  private var documentOverviewCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Image(systemName: "doc.text")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(Color.accentColor)
        Text(inspection.source.fileName)
          .font(.subheadline.weight(.semibold))
          .lineLimit(1)
        Spacer()
        Text("DOCUMENT")
          .font(.system(size: 9, weight: .bold, design: .monospaced))
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(Color.primary.opacity(0.06), in: Capsule())
          .foregroundStyle(.secondary)
      }

      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 2) {
          Text("PAGES")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.tertiary)
          Text("\(inspection.pages.count)")
            .font(.caption.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        VStack(alignment: .leading, spacing: 2) {
          Text("FILLABLE")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.tertiary)
          Text(inspection.fields.isEmpty ? "None" : "\(inspection.fields.count) field\(inspection.fields.count == 1 ? "" : "s")")
            .font(.caption.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        VStack(alignment: .leading, spacing: 2) {
          Text("STATUS")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.tertiary)
          HStack(spacing: 3) {
            Circle()
              .fill(Color.green)
              .frame(width: 6, height: 6)
            Text("Opened")
              .font(.caption.weight(.medium))
              .foregroundStyle(Color.primary)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding(12)
    .background(.thinMaterial)
    .overlay(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    .shadow(color: Color.black.opacity(0.04), radius: 4, y: 1)
  }

  private var detectedFieldsNavigator: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Label("Detected Fields", systemImage: "list.bullet.rectangle")
          .font(.caption.weight(.bold))
          .foregroundStyle(.secondary)
        Spacer()
        if let label = model.fillProgressLabel {
          Text(label)
            .font(.caption2.weight(.medium))
            .foregroundStyle(Color.accentColor)
        }
      }

      if inspection.fields.isEmpty {
        Text("No interactive form fields detected in this document.")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .padding(.vertical, 4)
      } else {
        VStack(spacing: 4) {
          ForEach(inspection.fields) { field in
            let isFilled = !model.currentValue(for: field).isEmpty
            Button {
              model.selectedFieldID = field.id
              model.selectedCandidateID = nil
              model.selectedAnnotationID = nil
              model.jumpToPage(field.pageIndex)
            } label: {
              HStack(spacing: 8) {
                Image(systemName: isFilled ? "checkmark.circle.fill" : "circle")
                  .font(.system(size: 11))
                  .foregroundStyle(isFilled ? Color.green : Color.secondary)

                VStack(alignment: .leading, spacing: 1) {
                  Text(field.name.isEmpty ? "Unnamed Field" : field.name)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .foregroundStyle(Color.primary)
                  Text("p.\(field.pageIndex + 1) · \(field.kind.rawValue)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                }

                Spacer()

                if isFilled {
                  Text(model.currentValue(for: field))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 80, alignment: .trailing)
                } else {
                  Text("Unfilled")
                    .font(.system(size: 9, weight: .medium))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.06), in: Capsule())
                    .foregroundStyle(.secondary)
                }

                Image(systemName: "chevron.right")
                  .font(.system(size: 9, weight: .semibold))
                  .foregroundStyle(.tertiary)
              }
              .padding(.horizontal, 8)
              .padding(.vertical, 6)
              .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                  .fill(model.selectedFieldID == field.id ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.03))
              )
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
    .padding(12)
    .background(.thinMaterial)
    .overlay(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    .shadow(color: Color.black.opacity(0.04), radius: 4, y: 1)
  }

  private func selectedAnnotationContextCard(_ mark: AnnotationMark) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Button {
          model.selectedAnnotationID = nil
        } label: {
          HStack(spacing: 4) {
            Image(systemName: "chevron.left")
              .font(.system(size: 10, weight: .semibold))
            Text("Document")
              .font(.caption2.weight(.medium))
          }
          .padding(.horizontal, 6)
          .padding(.vertical, 3)
          .background(Color.primary.opacity(0.06), in: Capsule())
        }
        .buttonStyle(.plain)
        .help("Return to document overview")

        Spacer()

        Text("PAGE \(mark.pageIndex + 1)")
          .font(.system(size: 9, weight: .bold, design: .monospaced))
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(Color.accentColor.opacity(0.12), in: Capsule())
          .foregroundStyle(Color.accentColor)
      }

      HStack(spacing: 8) {
        Image(systemName: mark.type.symbolName)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(Color.accentColor)
        Text(mark.type.displayName)
          .font(.subheadline.weight(.semibold))
      }

      if !mark.selectedText.isEmpty {
        Text("\"\(mark.selectedText)\"")
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
    }
    .padding(12)
    .background(.thinMaterial)
    .overlay(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    .shadow(color: Color.black.opacity(0.04), radius: 4, y: 1)
  }

  private func selectedCandidateContextCard(_ candidate: RegionCandidate) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Button {
          model.selectedCandidateID = nil
        } label: {
          HStack(spacing: 4) {
            Image(systemName: "chevron.left")
              .font(.system(size: 10, weight: .semibold))
            Text("Document")
              .font(.caption2.weight(.medium))
          }
          .padding(.horizontal, 6)
          .padding(.vertical, 3)
          .background(Color.primary.opacity(0.06), in: Capsule())
        }
        .buttonStyle(.plain)
        .help("Return to document overview")

        Spacer()

        Text("PAGE \(candidate.pageIndex + 1)")
          .font(.system(size: 9, weight: .bold, design: .monospaced))
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(Color.orange.opacity(0.12), in: Capsule())
          .foregroundStyle(Color.orange)
      }

      HStack(spacing: 8) {
        Image(systemName: "scope")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(Color.orange)
        Text(candidate.effectiveDisplayName.isEmpty ? "Detected Region" : candidate.effectiveDisplayName)
          .font(.subheadline.weight(.semibold))
      }

      Text(candidate.isDirectlyEditable ? "Click to type into this field, or accept suggestion." : "Suggested region for marking or signing.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(12)
    .background(.thinMaterial)
    .overlay(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    .shadow(color: Color.black.opacity(0.04), radius: 4, y: 1)
  }

  private func selectedNativeFieldContextCard(_ field: NativeField) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Button {
          model.selectedFieldID = nil
        } label: {
          HStack(spacing: 4) {
            Image(systemName: "chevron.left")
              .font(.system(size: 10, weight: .semibold))
            Text("Document")
              .font(.caption2.weight(.medium))
          }
          .padding(.horizontal, 6)
          .padding(.vertical, 3)
          .background(Color.primary.opacity(0.06), in: Capsule())
        }
        .buttonStyle(.plain)
        .help("Return to document overview")

        Spacer()

        Text("PAGE \(field.pageIndex + 1)")
          .font(.system(size: 9, weight: .bold, design: .monospaced))
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(Color.blue.opacity(0.12), in: Capsule())
          .foregroundStyle(Color.blue)
      }

      HStack(spacing: 8) {
        Image(systemName: "checkmark.square")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(Color.blue)
        Text(field.name.isEmpty ? "Form Field" : field.name)
          .font(.subheadline.weight(.semibold))
      }

      Text("Native form field ready for input or autofill.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(12)
    .background(.thinMaterial)
    .overlay(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    .shadow(color: Color.black.opacity(0.04), radius: 4, y: 1)
  }

  private func evidenceRailMetric(_ label: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(label.uppercased())
        .font(.caption2.weight(.bold))
        .foregroundStyle(.tertiary)
      Text(value)
        .font(.caption)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func selectedTextContextCard(_ selection: (text: String, bounds: PDFRect, pageIndex: Int)) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 8) {
        Image(systemName: "text.quote")
          .foregroundStyle(Color.accentColor)
        Text("Selected Text / Clause")
          .font(.subheadline.weight(.semibold))
        Spacer()
        Text("PAGE \(selection.pageIndex + 1)")
          .font(.system(size: 9, weight: .bold, design: .monospaced))
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(Color.primary.opacity(0.06), in: Capsule())
          .foregroundStyle(.secondary)
      }

      Text("\"\(selection.text)\"")
        .font(.callout)
        .lineLimit(5)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.textBackgroundColor).opacity(0.6), in: RoundedRectangle(cornerRadius: 6))

      HStack(spacing: 12) {
        Text("\(selection.text.split(separator: " ").count) words")
          .font(.caption2)
          .foregroundStyle(.secondary)
        Text("\(selection.text.count) characters")
          .font(.caption2)
          .foregroundStyle(.secondary)
        Spacer()
        Text("● On-device (Neural Engine)")
          .font(.caption2.weight(.medium))
          .foregroundStyle(.green)
      }

      VStack(spacing: 8) {
        HStack(spacing: 8) {
          Button {
            model.redactSelectedText()
          } label: {
            Label("Redact Selection", systemImage: "eye.slash")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .tint(.red)

          Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(selection.text, forType: .string)
            model.statusMessage = "Copied text to clipboard."
          } label: {
            Label("Copy Text", systemImage: "doc.on.doc")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
        }
      }
    }
    .padding(12)
    .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
    )
  }

  private func selectedTableContextCard(_ table: ExtractedTable) -> some View {
    let mathReport = TableExtractor().verifyMath(in: table)

    return VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 8) {
        Image(systemName: "tablecells.badge.ellipsis")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Color.accentColor)
        Text("Selected Table (\(table.rows)×\(table.columns))")
          .font(.subheadline.weight(.semibold))
        Spacer()
        Text("PAGE \(table.pageIndex + 1)")
          .font(.system(size: 9, weight: .bold, design: .monospaced))
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(Color.primary.opacity(0.06), in: Capsule())
          .foregroundStyle(.secondary)

        Button {
          model.selectedTable = nil
        } label: {
          Image(systemName: "xmark.circle.fill")
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
      }

      // Math Verification & Anomaly Status Card
      VStack(alignment: .leading, spacing: 6) {
        if mathReport.hasAnomalies {
          HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
              .foregroundStyle(.orange)
            Text("Calculation Discrepancy Detected")
              .font(.caption.weight(.bold))
              .foregroundStyle(.orange)
            Spacer()
            Text("\(mathReport.totalDiscrepancies) Anomaly")
              .font(.system(size: 9, weight: .bold))
              .padding(.horizontal, 5)
              .padding(.vertical, 1)
              .background(Color.orange.opacity(0.15), in: Capsule())
              .foregroundStyle(.orange)
          }

          ForEach(mathReport.summaries.filter { !$0.isVerified }) { summary in
            VStack(alignment: .leading, spacing: 2) {
              Text(summary.columnName)
                .font(.caption2.weight(.semibold))
              HStack {
                Text("Computed Sum: \(String(format: "%.2f", summary.computedSum))")
                  .font(.system(size: 10, design: .monospaced))
                Spacer()
                Text("Reported: \(String(format: "%.2f", summary.reportedTotal ?? 0))")
                  .font(.system(size: 10, design: .monospaced))
                  .foregroundStyle(.red)
              }
            }
            .padding(6)
            .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
          }
        } else if mathReport.hasTotalsRow {
          HStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill")
              .foregroundStyle(.green)
            Text("Column Totals Verified")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.green)
            Spacer()
            Text("PASSED")
              .font(.system(size: 9, weight: .bold))
              .padding(.horizontal, 5)
              .padding(.vertical, 1)
              .background(Color.green.opacity(0.15), in: Capsule())
              .foregroundStyle(.green)
          }
          Text("All reported totals match computed column values without discrepancies.")
            .font(.caption2)
            .foregroundStyle(.secondary)
        } else if !mathReport.summaries.isEmpty {
          HStack(spacing: 6) {
            Image(systemName: "function")
              .foregroundStyle(Color.accentColor)
            Text("Computed Column Totals")
              .font(.caption.weight(.semibold))
          }
          ForEach(mathReport.summaries) { summary in
            HStack {
              Text(summary.columnName)
                .font(.caption2)
                .foregroundStyle(.secondary)
              Spacer()
              Text(String(format: "%.2f", summary.computedSum))
                .font(.caption2.monospacedDigit().weight(.medium))
            }
          }
        }
      }
      .padding(8)
      .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 6))

      // Focus & Navigation Actions
      HStack(spacing: 8) {
        Button {
          model.flashEvidenceAnchor(pageIndex: table.pageIndex, bounds: table.bounds)
        } label: {
          Label("Focus on Canvas", systemImage: "target")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
      }

      // Export Buttons
      HStack(spacing: 6) {
        Button {
          let csv = TableExtractor().exportCSV(table)
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(csv, forType: .string)
          model.statusMessage = "Copied table CSV to clipboard."
        } label: {
          Label("Copy CSV", systemImage: "doc.on.doc")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)

        Button {
          let md = TableExtractor().exportMarkdown(table)
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(md, forType: .string)
          model.statusMessage = "Copied table Markdown to clipboard."
        } label: {
          Label("Markdown", systemImage: "tablecells")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)

        Button {
          if let json = TableExtractor().exportJSON(table),
             let jsonStr = String(data: json, encoding: .utf8) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(jsonStr, forType: .string)
            model.statusMessage = "Copied table JSON to clipboard."
          }
        } label: {
          Label("JSON", systemImage: "curlybraces")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
      }

      // Preview (first 4 rows)
      VStack(alignment: .leading, spacing: 4) {
        Text("DATA PREVIEW")
          .font(.system(size: 9, weight: .bold))
          .foregroundStyle(.secondary)

        ScrollView(.horizontal, showsIndicators: false) {
          VStack(alignment: .leading, spacing: 1) {
            if let headers = table.headers {
              HStack(spacing: 0) {
                ForEach(headers, id: \.self) { header in
                  Text(header)
                    .font(.caption2.weight(.semibold))
                    .frame(minWidth: 64, alignment: .leading)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.08))
                }
              }
            }

            ForEach(Array(table.dataRows.prefix(4).enumerated()), id: \.offset) { _, row in
              HStack(spacing: 0) {
                ForEach(row, id: \.self) { cell in
                  Text(cell)
                    .font(.caption2)
                    .frame(minWidth: 64, alignment: .leading)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                }
              }
            }
          }
        }
      }
    }
    .padding(12)
    .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
    )
  }

  private var selectedAnnotation: AnnotationMark? {
    guard let id = model.selectedAnnotationID else { return nil }
    return annotationStore.marks.first { $0.id == id }
  }

  private func selectedAnnotationCard(_ mark: AnnotationMark) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Label(mark.type.displayName, systemImage: mark.type.symbolName)
          .font(.subheadline.weight(.semibold))
        Spacer()
        Text("SIDECAR")
          .font(.caption2.weight(.bold).monospaced())
          .foregroundStyle(.secondary)
      }

      Text(mark.selectedText.isEmpty ? "No marked text" : mark.selectedText)
        .font(.caption)
        .foregroundStyle(mark.selectedText.isEmpty ? .secondary : .primary)
        .fixedSize(horizontal: false, vertical: true)

      if !mark.note.isEmpty {
        Label(mark.note, systemImage: "note.text")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      HStack(spacing: 8) {
        Button("Hide") {
          annotationStore.toggleVisibility(id: mark.id)
          model.selectedAnnotationID = nil
        }
        .buttonStyle(.bordered)
        .controlSize(.small)

        Button("Copy Text") {
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(mark.selectedText, forType: .string)
          model.statusMessage = "Copied the selected annotation text."
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(mark.selectedText.isEmpty)
      }
    }
    .padding(10)
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Selected \(mark.type.displayName.lowercased()) annotation on page \(mark.pageIndex + 1)")
  }

  @ViewBuilder
  private var adaptiveCommandStatusSection: some View {
    let target: AdaptiveInteractionTarget = model.selectedField == nil
      ? .documentScrolling
      : .formField
    let decisions = AdaptiveCommandPolicy.standard
      .assess(AdaptiveCommandContext.input(model: model, intent: .review, target: target))
      .filter { $0.state != .available && !$0.reasons.isEmpty }

    if !decisions.isEmpty {
      DisclosureGroup {
        VStack(alignment: .leading, spacing: 7) {
          ForEach(decisions.prefix(4), id: \.command.id) { decision in
            VStack(alignment: .leading, spacing: 2) {
              Text(decision.command.title)
                .font(.caption.weight(.medium))
              Text(decision.reasons.map(adaptiveReasonLabel).joined(separator: " · "))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
          }

          if decisions.count > 4 {
            Text("More actions remain available from the menu bar and Command-K.")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
        .padding(.top, 6)
      } label: {
        Label("Why actions are quiet", systemImage: "questionmark.circle")
          .font(.caption.weight(.medium))
      }
      .accessibilityHint("Explains why some contextual commands are unavailable or need review.")
    }

    if let denial = model.lastActionDenial {
      VStack(alignment: .leading, spacing: 5) {
        Label("Action unavailable", systemImage: "hand.raised")
          .font(.caption.weight(.medium))
        Text(denial.explanation)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        if let requirement = denial.requirementName {
          Text("Required: \(requirement)")
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
      }
      .padding(9)
      .background(Color.orange.opacity(0.09))
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .accessibilityElement(children: .combine)
      .accessibilityLabel("Action unavailable for \(denial.actionName)")
      .accessibilityValue(denial.explanation)
    }
  }

  private func adaptiveReasonLabel(_ reason: AdaptiveCommandAvailabilityReason) -> String {
    switch reason {
    case .requiresSearchPermission: return "Text access is unavailable"
    case .requiresAnnotationPermission: return "Annotation permission is unavailable"
    case .requiresModifyPermission: return "Document modification is unavailable"
    case .requiresFillCapability: return "This document has no fill capability"
    case .requiresTextSelection: return "Select text first"
    case .requiresFormFieldContext: return "Select a form field first"
    case .requiresAnnotationContext: return "Select an annotation first"
    case .requiresImageContext: return "Select an image or object first"
    case .requiresPageContext: return "Choose a page first"
    case .requiresUndoHistory: return "There is no accepted operation to undo"
    case .requiresRedoHistory: return "There is no operation to redo"
    case .requiresExportableOperation: return "No exportable operation is ready"
    case .capabilityUnsupported: return "The current provider does not support this"
    case .capabilityRevoked: return "This capability was revoked"
    case .capabilityNeedsReview: return "Provider evidence needs review"
    case .capabilityBlocked: return "Provider evidence is blocked"
    case .targetNeedsConfirmation: return "Confirm the detected target first"
    }
  }

  private var authoringToolsPalette: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("Authoring Tools")
          .font(.caption.weight(.bold))
          .foregroundStyle(.secondary)
        Spacer()
      }

      HStack(spacing: 8) {
        authoringToolButton(
          title: "Add Text",
          systemImage: "text.cursor",
          action: { model.beginManualTextPlacement() },
          isEnabled: model.inspection?.permissions.canAddAnnotations ?? false,
          help: "Click anywhere on the page to place new text overlay."
        )

        authoringToolButton(
          title: "Sign",
          systemImage: "signature",
          action: { model.beginSign(for: nil) },
          isEnabled: model.inspection?.permissions.canAddAnnotations ?? false,
          help: "Open signature pad to draw, type, or import your signature."
        )

        authoringToolButton(
          title: "OCR Page",
          systemImage: "text.viewfinder",
          action: { model.runOCROnSelectedPage() },
          isEnabled: model.inspection?.permissions.canCopy ?? false,
          help: "Run local Vision OCR on the selected page."
        )
      }

      let markedRedactions = model.redactionMarkCount
      if markedRedactions > 0 {
        HStack(spacing: 8) {
          Label("\(markedRedactions) area(s) marked for redaction", systemImage: "eye.slash")
            .font(.caption)
            .foregroundStyle(.red)
          Spacer()
          Button("Commit Redactions", systemImage: "trash") {
            model.isRedactionCommitPresented = true
          }
          .buttonStyle(.borderedProminent)
          .tint(.red)
          .font(.caption)
        }
        .padding(8)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
      }
    }
    .padding(12)
    .background(Color.primary.opacity(0.025))
    .overlay(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .stroke(Color.primary.opacity(0.07), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
  }

  private func authoringToolButton(
    title: String,
    systemImage: String,
    action: @escaping () -> Void,
    isEnabled: Bool,
    help: String
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 6) {
        Image(systemName: systemImage)
          .font(.system(size: 13, weight: .semibold))
        Text(title)
          .font(.caption.weight(.medium))
      }
      .frame(maxWidth: .infinity, minHeight: 32)
    }
    .buttonStyle(.bordered)
    .controlSize(.regular)
    .disabled(!isEnabled)
    .help(help)
  }

  private func selectedCandidateCard(_ candidate: RegionCandidate) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        if isRenamingCandidate {
          TextField("Suggestion name", text: $renameDraft)
            .font(.subheadline.weight(.semibold))
            .textFieldStyle(.roundedBorder)
            .onSubmit { commitRename(candidate) }
        } else {
          Label(candidate.effectiveDisplayName, systemImage: "scope")
            .font(.subheadline.weight(.semibold))
        }
        Button {
          if isRenamingCandidate {
            commitRename(candidate)
          } else {
            renameDraft = candidate.effectiveDisplayName
            isRenamingCandidate = true
          }
        } label: {
          Image(systemName: isRenamingCandidate ? "checkmark.circle" : "pencil")
            .font(.caption)
        }
        .buttonStyle(.plain)
        .help(isRenamingCandidate ? "Save name" : "Rename this suggestion")
        .accessibilityLabel(isRenamingCandidate ? "Save suggestion name" : "Rename suggestion")
        Spacer()
        HStack(spacing: 4) {
          Image(systemName: "sparkles")
          Text("Tier 2 · Suggestion")
        }
        .font(.caption2.weight(.medium))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.yellow.opacity(0.18))
        .clipShape(Capsule())

        Text(confidenceLabel(candidate.score))
          .font(.caption2.monospacedDigit())
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(Color.orange.opacity(0.15))
          .foregroundStyle(Color.orange)
          .clipShape(Capsule())
      }

      Text("Page \(candidate.pageIndex + 1) · \(candidateEntryLabel(candidate))")
        .font(.caption)
        .foregroundStyle(.secondary)

      if let labelText = candidate.labelText, !labelText.isEmpty {
        Text("Label: \(labelText)")
          .font(.caption.weight(.medium))
      }

      // Progressive disclosure for advanced spatial geometry and evidence breakdown
      let explanation = SuggestionExplainer.explain(candidate)
      DisclosureGroup("Advanced Geometry & Evidence") {
        VStack(alignment: .leading, spacing: 3) {
          Text("Bounds: (\(Int(candidate.bounds.x)), \(Int(candidate.bounds.y)), \(Int(candidate.bounds.width))×\(Int(candidate.bounds.height)))")
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
          Text("Confidence Tier: \(candidate.confidenceTier.rawValue.capitalized)")
            .font(.caption2)
            .foregroundStyle(.secondary)
          ForEach(explanation.reasons, id: \.self) { reason in
            Label(reason, systemImage: "checkmark.circle")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
          ForEach(explanation.cautions, id: \.self) { caution in
            Label(caution, systemImage: "exclamationmark.triangle")
              .font(.caption2)
              .foregroundStyle(.orange)
          }
        }
        .padding(.top, 2)
      }
      .font(.caption)

      if candidate.isDirectlyEditable {
        TextField("Enter value to place here", text: $overlayDraft)
          .textFieldStyle(.roundedBorder)
          .onSubmit {
            model.applyOverlay(overlayDraft)
            overlayDraft = ""
          }

        if !model.lastValueSuggestions.isEmpty {
          HStack(spacing: 6) {
            ForEach(model.lastValueSuggestions, id: \.self) { suggestion in
              Button {
                overlayDraft = suggestion
                model.applyOverlay(suggestion)
                overlayDraft = ""
              } label: {
                Text(suggestion)
                  .font(.caption2)
                  .lineLimit(1)
                  .padding(.horizontal, 8)
                  .padding(.vertical, 3)
                  .background(Color.blue.opacity(0.10))
                  .clipShape(Capsule())
              }
              .buttonStyle(.plain)
              .help("Use suggested value")
            }
          }
        }

        HStack {
          Button("Place Text") {
            model.applyOverlay(overlayDraft)
            overlayDraft = ""
          }
          .buttonStyle(.borderedProminent)
          .disabled(overlayDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

          Button("Synthesize Field") {
            model.synthesizeNativeField()
          }
          .buttonStyle(.bordered)

          Button("Dismiss", role: .destructive) {
            model.rejectSelectedCandidate()
            overlayDraft = ""
          }
          .buttonStyle(.bordered)
        }
        .font(.caption)
      } else if [.checkbox, .radioGroup].contains(candidate.entryMode) {
        let optionNames = namedOptions(for: candidate)
        Picker("Choice Box", selection: $choiceCellIndex) {
          ForEach(candidate.memberBounds.indices, id: \.self) { index in
            Text(optionNames[index]).tag(index)
          }
        }
        .pickerStyle(.menu)

        HStack {
          Button("Mark Box", systemImage: "checkmark") {
            model.applyStaticChoiceMark(cellIndex: choiceCellIndex)
          }
          .buttonStyle(.borderedProminent)
          .font(.caption)

          Button("Dismiss", role: .destructive) {
            model.rejectSelectedCandidate()
          }
          .buttonStyle(.bordered)
          .font(.caption)
        }
      }

      Divider()
      Button {
        _ = model.teachNorthstarWorkflow(name: candidate.effectiveDisplayName)
      } label: {
        Label("Teach Northstar This Pattern", systemImage: "sparkles")
          .font(.caption)
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .help("Save candidate geometry and type associations as a reusable workflow pattern")
    }
    .padding(12)
    .background(Color.accentColor.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
    )
  }

  private func selectedNativeFieldCard(_ field: NativeField) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Label(field.name, systemImage: "checkmark.square")
          .font(.subheadline.weight(.semibold))
        Spacer()
        Text("Page \(field.pageIndex + 1) · \(field.kind.rawValue)")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }

      if field.kind == .button {
        let options = model.buttonOptions(for: field)
        if options.count > 1 {
          Picker("Option", selection: $fieldDraft) {
            ForEach(options, id: \.self) { option in
              Text(option).tag(option)
            }
          }
          .pickerStyle(.menu)
        } else {
          Toggle("Checked", isOn: Binding(
            get: { ["1", "true", "yes", "on", "checked"].contains(fieldDraft.lowercased()) },
            set: { fieldDraft = $0 ? (options.first ?? "Yes") : "false" }
          ))
        }
      } else if field.kind == .choice && !field.choices.isEmpty {
        Picker("Choice", selection: $fieldDraft) {
          Text("—").tag("")
          ForEach(field.choices, id: \.self) { option in
            Text(option).tag(option)
          }
        }
        .pickerStyle(.menu)
      } else {
        TextField("Field value", text: $fieldDraft)
          .textFieldStyle(.roundedBorder)
          .onSubmit {
            model.applyFieldValue(fieldDraft)
          }

        if !model.lastValueSuggestions.isEmpty {
          HStack(spacing: 6) {
            ForEach(model.lastValueSuggestions, id: \.self) { suggestion in
              Button {
                fieldDraft = suggestion
                model.applyFieldValue(suggestion)
              } label: {
                Text(suggestion)
                  .font(.caption2)
                  .lineLimit(1)
                  .padding(.horizontal, 8)
                  .padding(.vertical, 3)
                  .background(Color.blue.opacity(0.10))
                  .clipShape(Capsule())
              }
              .buttonStyle(.plain)
              .help("Use suggested value")
            }
          }
        }
      }

      Button("Apply Field Value") {
        model.applyFieldValue(fieldDraft)
      }
      .buttonStyle(.borderedProminent)
      .font(.caption)
      .disabled(field.kind == .signature)
    }
    .padding(12)
    .background(Color.blue.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .contextMenu {
      fieldContextMenu(field)
    }
  }

  @ViewBuilder
  private func fieldContextMenu(_ field: NativeField) -> some View {
    let decisions = AdaptiveCommandPolicy.standard.assess(fieldPolicyInput)
    let supportedCommands = decisions
      .filter { decision in
        switch decision.command.id {
        case .fillForm, .export, .undo, .redo:
          return decision.state.isActionable
        default:
          return false
        }
      }

    ForEach(supportedCommands, id: \.command.id) { decision in
      Button {
        AdaptiveCommandHistory.shared.record(decision.command.id)
        performFieldCommand(decision.command.id)
      } label: {
        Label(decision.command.title, systemImage: fieldCommandSymbol(decision.command.id))
      }
    }
  }

  private var fieldPolicyInput: AdaptiveCommandPolicyInput {
    AdaptiveCommandContext.input(model: model, intent: .complete, target: .formField)
  }

  private func performFieldCommand(_ command: AdaptiveCommandID) {
    switch command {
    case .fillForm:
      model.setEditorMode(.fill)
    case .export:
      model.presentExportReview()
    case .undo:
      model.undo()
    case .redo:
      model.redo()
    default:
      break
    }
  }

  private func fieldCommandSymbol(_ command: AdaptiveCommandID) -> String {
    switch command {
    case .fillForm: return "character.cursor.ibeam"
    case .export: return "square.and.arrow.up"
    case .undo: return "arrow.uturn.backward"
    case .redo: return "arrow.uturn.forward"
    default: return "circle"
    }
  }

  private var profileBulkFillCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Label("Profile Autofill", systemImage: "person.crop.circle")
          .font(.subheadline.weight(.semibold))
        Spacer()
        if let profile = model.currentProfile {
          Text(profile.displayName)
            .font(.caption.weight(.medium))
            .foregroundStyle(Color.accentColor)
        }
      }

      if model.currentProfile != nil {
        HStack(spacing: 8) {
          Button("Preview Fill") {
            model.previewBulkFill()
          }
          .buttonStyle(.bordered)

          if let result = model.bulkFillResult, result.totalMatches > 0 {
            Button("Apply \(result.totalMatches) Field(s)") {
              model.applyBulkFill()
            }
            .buttonStyle(.borderedProminent)
          }
        }
        .font(.caption)

        if let result = model.bulkFillResult {
          Text("\(result.totalMatches) matched · \(result.unmatchedFields.count) unmatched")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      } else {
        Text("Unlock local profile vault to match and auto-populate known personal data.")
          .font(.caption)
          .foregroundStyle(.secondary)

        Button("Unlock Profile Vault") {
          model.unlockProfileVault()
        }
        .buttonStyle(.bordered)
        .font(.caption)
      }
    }
    .padding(10)
    /* Warm-tinted section background */
    .background(Color.orange.opacity(0.04))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }

  /// Review-only signature occupancy audit (lab-salvaged). Existing ink is
  /// document evidence; a missing signature is an actionable finding. This
  /// card never appears on pages without a multi-signer block, and its
  /// observations never become fillable fields.
  private var signatureAuditCard: some View {
    Group {
      if !signatureObservations.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Label("Signature Audit", systemImage: "signature")
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
          Text("Review-only document evidence — observations never become fields.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
          ForEach(signatureObservations) { observation in
            HStack(spacing: 10) {
              signatureStatusChip(observation.status)
              VStack(alignment: .leading, spacing: 2) {
                Text(observation.signer.map { "\($0) — \(observation.role)" } ?? observation.role)
                  .font(.caption.weight(.medium))
                  .lineLimit(1)
                Text("Page \(observation.pageIndex + 1) · \(Int((observation.confidence * 100).rounded()))% confidence")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              }
              Spacer()
            }
            .padding(8)
            .background(Color.primary.opacity(0.02), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
          }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
      }
    }
  }

  private func signatureStatusChip(_ status: SignatureObservation.Status) -> some View {
    let (label, color): (String, Color) = {
      switch status {
      case .present: return ("PRESENT", .green)
      case .missing: return ("MISSING", .orange)
      case .uncertain: return ("UNCERTAIN", .secondary)
      }
    }()
    return Text(label)
      .font(.system(size: 9, weight: .bold, design: .monospaced))
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(color.opacity(0.15), in: Capsule())
      .foregroundStyle(color)
  }

  private var candidateSuggestionsList: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text("Suggestions (\(model.activeCandidates.count))")
          .font(.caption.weight(.bold))
          .foregroundStyle(.secondary)
        Spacer()
        if !model.activeCandidates.isEmpty {
          Button("Prev", systemImage: "chevron.left") { model.selectPreviousCandidate() }
            .buttonStyle(.plain)
            .font(.caption)
            .accessibilityLabel("Previous suggestion")
          Button("Next", systemImage: "chevron.right") { model.selectNextCandidate() }
            .buttonStyle(.plain)
            .font(.caption)
            .accessibilityLabel("Next suggestion")
        }
      }

      if model.activeCandidates.isEmpty {
        VStack(spacing: 8) {
          Image(systemName: "doc.text.magnifyingglass")
            .font(.system(size: 22))
            .foregroundStyle(.tertiary)
          Text("No suggestions detected")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
          Text("The detector may have abstained: a region needs both a field-like label and nearby geometry. Switch to Fill mode to detect form fields, or run OCR to extract text regions.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

          Button {
            model.runOCROnSelectedPage()
          } label: {
            Label("Scan Page with OCR", systemImage: "text.viewfinder")
              .font(.caption.weight(.medium))
          }
          .buttonStyle(.bordered)
          .controlSize(.small)
          .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.primary.opacity(0.02))
        )
        .overlay(
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.08), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        )
      } else {
        ForEach(model.rankedActiveCandidates.prefix(6)) { candidate in
          Button {
            model.selectedCandidateID = candidate.id
            model.selectedFieldID = nil
            model.jumpToPage(candidate.pageIndex)
          } label: {
            HStack {
              Image(systemName: model.selectedCandidateID == candidate.id ? "scope" : "circle.dotted")
                .foregroundStyle(model.selectedCandidateID == candidate.id ? Color.accentColor : Color.secondary)
              Text(candidate.effectiveDisplayName)
                .font(.caption)
                .lineLimit(1)
              Spacer()
              Text("p.\(candidate.pageIndex + 1)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
              Text(confidenceLabel(candidate.score))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
            }
            .padding(6)
            .background(model.selectedCandidateID == candidate.id ? Color.accentColor.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 4))
          }
          .buttonStyle(.plain)
          .accessibilityLabel("\(candidate.effectiveDisplayName), page \(candidate.pageIndex + 1), \(confidenceLabel(candidate.score))")
          .accessibilityHint(model.selectedCandidateID == candidate.id ? "Currently selected" : "Selects this suggestion")
          .accessibilityAddTraits(model.selectedCandidateID == candidate.id ? .isSelected : [])
        }
      }
    }
  }

  private var searchMatchesSection: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Search Hits (\(model.searchMatches.count))")
        .font(.caption.weight(.bold))
        .foregroundStyle(.secondary)

      ForEach(Array(model.searchMatches.prefix(5).enumerated()), id: \.element.id) { offset, match in
        Button {
          model.setSearchMatch(offset)
        } label: {
          VStack(alignment: .leading, spacing: 2) {
            Text("Page \(match.pageIndex + 1): \(match.snippet)")
              .font(.caption)
              .lineLimit(2)
          }
          .padding(6)
          .background(model.selectedSearchMatchIndex == offset ? Color.accentColor.opacity(0.12) : Color.clear)
          .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Search result page \(match.pageIndex + 1): \(match.snippet)")
        .accessibilityHint(model.selectedSearchMatchIndex == offset ? "Currently selected" : "Jump to this result")
        .accessibilityAddTraits(model.selectedSearchMatchIndex == offset ? .isSelected : [])
      }
    }
  }

  // MARK: - Understand Tab
  private var understandTabContent: some View {
    VStack(alignment: .leading, spacing: 14) {
      // Grounded Evidence Q&A (TASK-B2)
      groundedEvidenceQASection

      // ── Empty / Pre-analysis state ──────────────────────────────────────────
      if understandResult.summary == nil && !isLoadingUnderstand {
        VStack(spacing: 20) {
          // Illustrated icon cluster
          ZStack {
            Circle()
              .fill(Color.accentColor.opacity(0.08))
              .frame(width: 72, height: 72)
            Image(systemName: "brain.head.profile")
              .font(.system(size: 32, weight: .light))
              .foregroundStyle(Color.accentColor.opacity(0.7))
          }
          .padding(.top, 16)

          VStack(spacing: 6) {
            Text("Document Analysis")
              .font(.headline.weight(.semibold))
            Text("Extract structure, key points, entities, and semantic meaning from this document.")
              .font(.caption)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
          }

          // Feature bullets
          VStack(alignment: .leading, spacing: 8) {
            understandFeatureBullet("Summary & Structure", systemImage: "doc.text.magnifyingglass", color: .blue)
            understandFeatureBullet("Named Entities & People", systemImage: "person.2", color: .purple)
            understandFeatureBullet("Key Points by Type", systemImage: "lightbulb.max", color: .orange)
            understandFeatureBullet("Tables & Data", systemImage: "tablecells", color: .green)
          }
          .padding(.horizontal, 8)

          Button {
            Task { await runUnderstandAnalysis() }
          } label: {
            Label("Analyze Document", systemImage: "brain.head.profile")
              .font(.callout.weight(.semibold))
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
          .padding(.horizontal, 4)
          .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
      }

      // ── Loading state ────────────────────────────────────────────────────────
      if isLoadingUnderstand {
        VStack(spacing: 12) {
          ProgressView()
            .controlSize(.regular)
            .scaleEffect(1.2)
          VStack(spacing: 4) {
            Text("Analyzing document…")
              .font(.caption.weight(.medium))
            Text("Extracting entities, key points, and structure")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
      }

      // ── Error state ──────────────────────────────────────────────────────────
      if let error = understandError {
        HStack(spacing: 10) {
          Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(.red)
          VStack(alignment: .leading, spacing: 2) {
            Text("Analysis failed")
              .font(.caption.weight(.semibold))
            Text(error)
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
          Spacer()
          Button("Retry") {
            Task { await runUnderstandAnalysis() }
          }
          .font(.caption.weight(.medium))
          .buttonStyle(.borderless)
          .foregroundStyle(Color.accentColor)
        }
        .padding(10)
        .background(Color.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.red.opacity(0.15), lineWidth: 1))
      }

      // ── Results ──────────────────────────────────────────────────────────────
      if let summary = understandResult.summary {
        understandSummarySection(summary)
      }

      if let entities = understandResult.entities, entities.totalCount > 0 {
        understandEntitiesSection(entities)
      }

      if let keyPoints = understandResult.keyPoints, keyPoints.totalCount > 0 {
        understandKeyPointsSection(keyPoints)
      }

      if let nerEntities = understandResult.nerEntities, nerEntities.totalCount > 0 {
        understandNERSection(nerEntities)
      }

      if let tables = understandResult.tables, tables.totalTables > 0 {
        understandTablesSection(tables)
      }

      // Re-run button after results are shown
      if understandResult.summary != nil && !isLoadingUnderstand {
        Button {
          Task { await runUnderstandAnalysis() }
        } label: {
          Label("Re-run Analysis", systemImage: "arrow.clockwise")
            .font(.caption.weight(.medium))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .frame(maxWidth: .infinity, alignment: .trailing)
      }
    }
  }

  // MARK: - Grounded Evidence Q&A Section [TASK-B2, TASK-B3]
  private var groundedEvidenceQASection: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 6) {
        Image(systemName: "quote.opening")
          .foregroundStyle(Color.accentColor)
        Text("Grounded Evidence Q&A")
          .font(.subheadline.weight(.semibold))
        Spacer()
        Text("● Zero Egress")
          .font(.caption2.weight(.medium))
          .foregroundStyle(.green)
      }

      Text("Ask questions anchored directly to verifiable document coordinates.")
        .font(.caption)
        .foregroundStyle(.secondary)

      HStack(spacing: 6) {
        TextField("e.g. 'applicant name', 'table', 'date'…", text: $evidenceQueryDraft)
          .textFieldStyle(.roundedBorder)
          .onSubmit {
            runEvidenceQuery()
          }

        Button {
          runEvidenceQuery()
        } label: {
          Image(systemName: "arrow.right.circle.fill")
            .font(.title3)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
        .disabled(evidenceQueryDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }

      if let result = groundedQueryResult {
        VStack(alignment: .leading, spacing: 8) {
          Text(result.answer)
            .font(.callout)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))

          if !result.citations.isEmpty {
            Text("EVIDENCE ANCHORS (\(result.citations.count))")
              .font(.caption2.weight(.bold))
              .foregroundStyle(.secondary)

            ForEach(result.citations) { citation in
              citationRowView(for: citation)
            }
          }
        }
      }
    }
    .padding(12)
    .background(Color.primary.opacity(0.02), in: RoundedRectangle(cornerRadius: 10))
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
    )
  }

  private func runEvidenceQuery() {
    guard !evidenceQueryDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    let query = evidenceQueryDraft
    let tables = understandResult.tables?.tables ?? []
    let ner = understandResult.nerEntities?.entities ?? []
    let graph = model.getOrBuildEvidenceGraph(tables: tables, nerEntities: ner)
    groundedQueryResult = graph?.queryEvidence(query: query)
  }

  private func citationRowView(for citation: EvidenceCitation) -> some View {
    Button {
      model.flashEvidenceAnchor(pageIndex: citation.pageIndex, bounds: citation.bounds)
    } label: {
      HStack {
        Image(systemName: "target")
          .foregroundStyle(Color.accentColor)
        VStack(alignment: .leading, spacing: 2) {
          Text(citation.excerpt)
            .font(.caption.weight(.medium))
            .lineLimit(1)
          Text("Page \(citation.pageIndex + 1) · Score \(citationScorePercent(citation))%")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Image(systemName: "arrow.right")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      .padding(8)
      .background(Color.accentColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
    }
    .buttonStyle(.plain)
  }

  private func citationScorePercent(_ citation: EvidenceCitation) -> Int {
    Int(citation.relevanceScore * 100)
  }

  private func understandFeatureBullet(_ label: String, systemImage: String, color: Color) -> some View {
    HStack(spacing: 10) {
      Image(systemName: systemImage)
        .font(.caption.weight(.medium))
        .foregroundStyle(color)
        .frame(width: 20)
      Text(label)
        .font(.caption)
        .foregroundStyle(.secondary)
      Spacer()
    }
  }

  @MainActor
  private func runUnderstandAnalysis() async {
    isLoadingUnderstand = true
    understandError = nil
    defer { isLoadingUnderstand = false }

    do {
      let result = try renderingPipeline.understand()
      understandResult = (result.summary, result.entities, result.keyPoints, result.nerEntities, result.tables, result.enhancedSummary)
    } catch {
      understandError = "Analysis failed: \(error.localizedDescription)"
    }
  }

  private func understandSummarySection(_ summary: DocumentSummary) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Summary", systemImage: "doc.text")
        .font(.subheadline.weight(.semibold))

      Text(summary.summary)
        .font(.caption)
        .fixedSize(horizontal: false, vertical: true)

      // Stats
      HStack(spacing: 12) {
        LabeledContent("Sentences", value: "\(summary.totalSentences)")
        LabeledContent("Key points", value: "\(summary.keyPoints.count)")
      }
      .font(.caption2)

      // Structure
      if !summary.structure.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Text("Structure")
            .font(.caption.weight(.semibold))
          ForEach(summary.structure) { section in
            HStack {
              Text(String(repeating: "  ", count: section.level))
              + Text(section.title)
                .font(.caption)
              Spacer()
              Text("p\(section.pageIndex + 1)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
          }
        }
      }
    }
    .padding(8)
    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
  }

  private func understandEntitiesSection(_ entities: EntityRecognitionResult) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Entities", systemImage: "magnifyingglass")
        .font(.subheadline.weight(.semibold))

      Text("\(entities.totalCount) found across \(entities.typeCount) types")
        .font(.caption)
        .foregroundStyle(.secondary)

      ForEach(EntityType.allCases.filter { entities.byType[$0]?.isEmpty == false }, id: \.self) { type in
        let ofType = entities.byType[type] ?? []
        VStack(alignment: .leading, spacing: 4) {
          Text(type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
            .font(.caption.weight(.semibold))
          ForEach(ofType.prefix(5)) { entity in
            HStack {
              Text(entity.value)
                .font(.caption)
              Spacer()
              Text("p\(entity.sourcePageIndex + 1)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
          }
          if ofType.count > 5 {
            Text("+ \(ofType.count - 5) more")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
    .padding(8)
    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
  }

  private func understandKeyPointsSection(_ keyPoints: KeyPointExtractionResult) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Key Points", systemImage: "lightbulb.max")
        .font(.subheadline.weight(.semibold))

      Text("\(keyPoints.totalCount) found across \(keyPoints.typeCount) types")
        .font(.caption)
        .foregroundStyle(.secondary)

      ForEach(KeyPointType.allCases.filter { keyPoints.byType[$0]?.isEmpty == false }, id: \.self) { type in
        let ofType = keyPoints.byType[type] ?? []
        VStack(alignment: .leading, spacing: 4) {
          Text(type.rawValue.capitalized)
            .font(.caption.weight(.semibold))
          ForEach(ofType.prefix(3)) { kp in
            HStack(alignment: .top) {
              Text(kp.text)
                .font(.caption)
                .lineLimit(3)
              Spacer()
              Text(String(format: "%.0f%%", kp.importance * 100))
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
          }
          if ofType.count > 3 {
            Text("+ \(ofType.count - 3) more")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
    .padding(8)
    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
  }

  // MARK: - NER Section
  private func understandNERSection(_ nerEntities: NERResult) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Named Entities", systemImage: "person.2.fill")
        .font(.subheadline.weight(.semibold))

      Text("\(nerEntities.totalCount) found across \(nerEntities.typeCount) types")
        .font(.caption)
        .foregroundStyle(.secondary)

      ForEach(NEREntityType.allCases.filter { nerEntities.byType[$0]?.isEmpty == false }, id: \.self) { type in
        let ofType = nerEntities.byType[type] ?? []
        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Text(type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
              .font(.caption.weight(.semibold))
            Text("(\(ofType.count))")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
          ForEach(ofType.prefix(5)) { entity in
            HStack(alignment: .top) {
              Text(entity.value)
                .font(.caption)
              Spacer()
              Text(String(format: "%.0f%%", entity.confidence * 100))
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
          }
          if ofType.count > 5 {
            Text("+ \(ofType.count - 5) more")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
    .padding(8)
    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
  }

  // MARK: - Tables Section
  private func understandTablesSection(_ tables: TableExtractionResult) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Tables", systemImage: "tablecells")
        .font(.subheadline.weight(.semibold))

      Text("\(tables.totalTables) table(s) detected")
        .font(.caption)
        .foregroundStyle(.secondary)

      ForEach(tables.tables) { table in
        VStack(alignment: .leading, spacing: 6) {
          HStack {
            Text("Table (\(table.rows)x\(table.columns))")
              .font(.caption.weight(.semibold))
            Text("Page \(table.pageIndex + 1)")
              .font(.caption2)
              .foregroundStyle(.secondary)
            Spacer()
            Text(String(format: "%.0f%%", table.confidence * 100))
              .font(.caption2)
              .foregroundStyle(.secondary)
          }

          Button {
            model.selectedTable = table
            model.flashEvidenceAnchor(pageIndex: table.pageIndex, bounds: table.bounds)
          } label: {
            Label("Select & Verify Table", systemImage: "tablecells.badge.ellipsis")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.small)

          // Table preview (first 4 rows)
          ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 1) {
              // Header row
              if let headers = table.headers {
                HStack(spacing: 0) {
                  ForEach(headers, id: \.self) { header in
                    Text(header)
                      .font(.caption2.weight(.semibold))
                      .frame(minWidth: 60, alignment: .leading)
                      .padding(.horizontal, 4)
                      .padding(.vertical, 2)
                      .background(.quaternary)
                  }
                }
              }

              // Data rows (max 4)
              ForEach(Array(table.dataRows.prefix(4).enumerated()), id: \.offset) { _, row in
                HStack(spacing: 0) {
                  ForEach(row, id: \.self) { cell in
                    Text(cell)
                      .font(.caption2)
                      .frame(minWidth: 60, alignment: .leading)
                      .padding(.horizontal, 4)
                      .padding(.vertical, 2)
                  }
                }
              }

              if table.dataRows.count > 4 {
                Text("+ \(table.dataRows.count - 4) more rows")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .padding(.top, 2)
              }
            }
          }

          // Export buttons
          HStack(spacing: 8) {
            Button {
              if let json = TableExtractor().exportJSON(table) {
                let panel = NSSavePanel()
                panel.allowedContentTypes = [.json]
                panel.nameFieldStringValue = "table-\(table.id.prefix(8)).json"
                panel.begin { response in
                  if response == .OK, let url = panel.url {
                    try? json.write(to: url)
                  }
                }
              }
            } label: {
              Label("JSON", systemImage: "doc.badge.gearshape")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
              let csv = TableExtractor().exportCSV(table)
              if let data = csv.data(using: .utf8) {
                let panel = NSSavePanel()
                panel.allowedContentTypes = [.commaSeparatedText]
                panel.nameFieldStringValue = "table-\(table.id.prefix(8)).csv"
                panel.begin { response in
                  if response == .OK, let url = panel.url {
                    try? data.write(to: url)
                  }
                }
              }
            } label: {
              Label("CSV", systemImage: "doc.text")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
              let md = TableExtractor().exportMarkdown(table)
              NSPasteboard.general.clearContents()
              NSPasteboard.general.setString(md, forType: .string)
            } label: {
              Label("Copy Markdown", systemImage: "doc.on.clipboard")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
          }
        }
        .padding(8)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
      }
    }
    .padding(8)
    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
  }

  // MARK: - Learn Tab (Study Loop)
  private var learnTabContent: some View {
    VStack(alignment: .leading, spacing: 14) {
      // ── Section header ───────────────────────────────────────────────────────
      HStack(spacing: 10) {
        ZStack {
          Circle()
            .fill(Color.purple.opacity(0.12))
            .frame(width: 36, height: 36)
          Image(systemName: "book.closed.fill")
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(Color.purple)
        }
        VStack(alignment: .leading, spacing: 2) {
          Text("Study Your Marks")
            .font(.subheadline.weight(.semibold))
          Text("Active recall from annotation marks")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        Spacer()
      }

      // ── Annotation marks ─────────────────────────────────────────────────────
      let visibleMarks = annotationStore.marks.filter { $0.isVisible }
      if visibleMarks.isEmpty {
        // Illustrated empty state
        VStack(spacing: 16) {
          ZStack {
            Circle()
              .fill(Color.purple.opacity(0.08))
              .frame(width: 64, height: 64)
            Image(systemName: "highlighter")
              .font(.system(size: 28, weight: .light))
              .foregroundStyle(Color.purple.opacity(0.6))
          }
          .padding(.top, 12)

          VStack(spacing: 6) {
            Text("No annotation marks yet")
              .font(.subheadline.weight(.semibold))
            Text("Create highlights, underlines, or notes in the document to build your study material.")
              .font(.caption)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
          }

          // How-to steps
          VStack(alignment: .leading, spacing: 8) {
            learnHowToStep(number: "1", text: "Select text on the canvas", color: .purple)
            learnHowToStep(number: "2", text: "Choose Highlight, Underline, or Note", color: .purple)
            learnHowToStep(number: "3", text: "Your marks appear here for review", color: .purple)
          }
          .padding(.horizontal, 8)
          .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(Color.purple.opacity(0.12), lineWidth: 1)
        )
      } else {
        // ── Stats row ──────────────────────────────────────────────────────────
        let highlights = visibleMarks.filter { $0.type == .highlight }.count
        let underlines = visibleMarks.filter { $0.type == .underline }.count
        let notes = visibleMarks.filter { $0.type == .note }.count
        let others = visibleMarks.count - highlights - underlines - notes

        VStack(alignment: .leading, spacing: 6) {
          Text("\(visibleMarks.count) mark\(visibleMarks.count == 1 ? "" : "s") ready for study")
            .font(.caption.weight(.semibold))

          HStack(spacing: 6) {
            if highlights > 0 {
              learnMarkPill("\(highlights) highlight\(highlights == 1 ? "" : "s")", icon: "highlighter", color: .yellow)
            }
            if underlines > 0 {
              learnMarkPill("\(underlines) underline\(underlines == 1 ? "" : "s")", icon: "underline", color: .blue)
            }
            if notes > 0 {
              learnMarkPill("\(notes) note\(notes == 1 ? "" : "s")", icon: "note.text", color: .green)
            }
            if others > 0 {
              learnMarkPill("\(others) other", icon: "pencil.line", color: .gray)
            }
          }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(Color.purple.opacity(0.12), lineWidth: 1)
        )

        // Study Loop View
        StudyLoopView(
          documentID: annotationStore.documentID,
          marks: visibleMarks,
          annotationStore: annotationStore
        )
        .frame(minHeight: 300)
      }
    }
  }

  private func learnHowToStep(number: String, text: String, color: Color) -> some View {
    HStack(spacing: 10) {
      ZStack {
        Circle()
          .fill(color.opacity(0.15))
          .frame(width: 22, height: 22)
        Text(number)
          .font(.caption2.weight(.bold))
          .foregroundStyle(color)
      }
      Text(text)
        .font(.caption)
        .foregroundStyle(.secondary)
      Spacer()
    }
  }

  private func learnMarkPill(_ label: String, icon: String, color: Color) -> some View {
    Label(label, systemImage: icon)
      .font(.caption2.weight(.medium))
      .foregroundStyle(color)
      .padding(.horizontal, 7)
      .padding(.vertical, 3)
      .background(color.opacity(0.1), in: Capsule())
  }

  // MARK: - Document Tab
  private var documentTabContent: some View {
    VStack(alignment: .leading, spacing: 14) {
      capabilityPassportSection

      // Metadata Card
      VStack(alignment: .leading, spacing: 8) {
        Label("Document Metadata", systemImage: "info.circle")
          .font(.subheadline.weight(.semibold))

        VStack(spacing: 6) {
          LabeledContent("Title", value: inspection.metadata.title.isEmpty ? "Not declared" : inspection.metadata.title)
          LabeledContent("Author", value: inspection.metadata.author.isEmpty ? "Not declared" : inspection.metadata.author)
          LabeledContent("Producer", value: inspection.metadata.producer.isEmpty ? "Not declared" : inspection.metadata.producer)
          LabeledContent("Creator", value: inspection.metadata.creator.isEmpty ? "Not declared" : inspection.metadata.creator)
        }
        .font(.caption)
      }
      .padding(10)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
      )

      // Permissions Card
      VStack(alignment: .leading, spacing: 8) {
        Label("Permissions & Security", systemImage: "lock.shield")
          .font(.subheadline.weight(.semibold))

        VStack(spacing: 6) {
          HStack {
            Text("Encrypted")
            Spacer()
            Text(inspection.security.isEncrypted ? "Yes" : "No")
              .foregroundStyle(inspection.security.isEncrypted ? Color.orange : Color.secondary)
              .fontWeight(inspection.security.isEncrypted ? .semibold : .regular)
          }
          HStack {
            Text("Can copy text")
            Spacer()
            Text(inspection.permissions.canCopy ? "Allowed" : "Restricted")
              .foregroundStyle(inspection.permissions.canCopy ? Color.green : Color.red)
          }
          HStack {
            Text("Can modify")
            Spacer()
            Text(inspection.permissions.canModify ? "Allowed" : "Restricted")
              .foregroundStyle(inspection.permissions.canModify ? Color.green : Color.red)
          }
          HStack {
            Text("Can annotate")
            Spacer()
            Text(inspection.permissions.canAddAnnotations ? "Allowed" : "Restricted")
              .foregroundStyle(inspection.permissions.canAddAnnotations ? Color.green : Color.red)
          }
        }
        .font(.caption)
      }
      .padding(10)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
      )

      // Outlines / Bookmarks
      if !inspection.outlines.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Label("Bookmarks & Outline", systemImage: "bookmark")
            .font(.subheadline.weight(.semibold))

          ForEach(inspection.outlines) { item in
            Button {
              if let page = item.destinationPageIndex {
                model.jumpToPage(page)
              }
            } label: {
              HStack {
                Text(item.title)
                Spacer()
                if let p = item.destinationPageIndex {
                  Text("p.\(p + 1)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
              }
              .padding(.vertical, 2)
              .padding(.leading, CGFloat(item.level) * 8)
              .font(.caption)
            }
            .buttonStyle(.plain)
          }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
      }
    }
  }

  private var capabilityPassportSection: some View {
    let input = AdaptiveCommandContext.input(
      model: model,
      intent: .review,
      target: .documentScrolling
    )
    let canExport = AdaptiveCommandPolicy.standard
      .resolve(input)
      .allValidCommands
      .contains { $0.id == .export }
    let passport = DocumentCapabilityPassport.make(
      inspection: inspection,
      canExport: canExport,
      hasPreflightReport: model.preflightReport != nil
    )

    return VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Label("Capability Passport", systemImage: "checkmark.seal.fill")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Color.accentColor)
        Spacer()
        Text("LOCAL")
          .font(.caption2.weight(.bold).monospaced())
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(Color.secondary.opacity(0.12), in: Capsule())
      }

      Text("What this source can support in the current session")
        .font(.caption2)
        .foregroundStyle(.secondary)

      ForEach(passport.entries) { entry in
        HStack(alignment: .top, spacing: 8) {
          Image(systemName: passportSymbol(for: entry.state))
            .foregroundStyle(passportColor(for: entry.state))
            .frame(width: 16)
          VStack(alignment: .leading, spacing: 2) {
            Text(entry.title)
              .font(.caption.weight(.medium))
            Text(entry.detail)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }
    }
    .padding(10)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .strokeBorder(Color.accentColor.opacity(0.12), lineWidth: 1)
    )
  }

  private func passportSymbol(for state: DocumentCapabilityState) -> String {
    switch state {
    case .available: return "checkmark.circle.fill"
    case .pending: return "clock"
    case .needsReview: return "exclamationmark.triangle.fill"
    case .blocked: return "nosign"
    case .notApplicable: return "minus.circle"
    }
  }

  private func passportColor(for state: DocumentCapabilityState) -> Color {
    switch state {
    case .available: return .green
    case .pending: return .secondary
    case .needsReview: return .orange
    case .blocked: return .red
    case .notApplicable: return .secondary
    }
  }

  // MARK: - Review Tab (case trust; raw value "Review")
  private var trustTabContent: some View {
    VStack(alignment: .leading, spacing: 14) {
      // Local Posture Card
      HStack(spacing: 12) {
        ZStack {
          Circle()
            .fill(Color.green.opacity(0.15))
            .frame(width: 40, height: 40)
          Image(systemName: "shield.lefthalf.filled.badge.checkmark")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Color.green)
        }
        VStack(alignment: .leading, spacing: 2) {
          Text("Local Privacy & Provenance")
            .font(.subheadline.weight(.semibold))
          Text("No network egress by local execution paths · stores on-device")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        Spacer()
      }
      .padding(12)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .strokeBorder(Color.green.opacity(0.2), lineWidth: 1)
      )

      // Preflight Report Card
      if let report = model.preflightReport {
        VStack(alignment: .leading, spacing: 8) {
          Label("Source Preflight", systemImage: "doc.badge.gearshape")
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)

          HStack {
            Text("Digest")
              .font(.caption2)
              .foregroundStyle(.secondary)
            Spacer()
            Text("\(report.header.sourceDigest.prefix(16))…")
              .font(.caption2.monospaced())
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
          }

          HStack(spacing: 8) {
            Text("\(report.payload.summary.findingCount) Findings")
              .font(.caption2.weight(.medium))
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color.blue.opacity(0.1), in: Capsule())
              .foregroundStyle(Color.blue)

            Text("\(report.payload.summary.metadataFieldCount) Meta")
              .font(.caption2.weight(.medium))
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color.purple.opacity(0.1), in: Capsule())
              .foregroundStyle(Color.purple)

            Text("\(report.payload.summary.embeddedDataCount) Embeds")
              .font(.caption2.weight(.medium))
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color.secondary.opacity(0.12), in: Capsule())
              .foregroundStyle(.secondary)
          }

          Divider()

          // Sanitization & Security details
          VStack(spacing: 4) {
            HStack {
              Text("Sanitization")
              Spacer()
              Text(report.payload.sanitization.status.rawValue)
                .foregroundStyle(.secondary)
            }
            HStack {
              Text("External URLs")
              Spacer()
              Text("\(report.payload.networkBoundaries.externalURLCount)")
                .foregroundStyle(report.payload.networkBoundaries.unsafeExternalURLCount > 0 ? Color.red : Color.secondary)
            }
            HStack {
              Text("Encrypted")
              Spacer()
              Text(report.payload.security.encrypted ? "Yes" : "No")
                .foregroundStyle(report.payload.security.encrypted ? Color.orange : Color.secondary)
            }
          }
          .font(.caption2)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
      }

      // Digital Signature & Cryptographic Integrity Section (PL-D12)
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Label("Digital Signatures", systemImage: "signature")
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
          Spacer()
          Button {
            model.verifyDigitalSignatures()
          } label: {
            Image(systemName: "arrow.clockwise")
              .font(.caption2)
          }
          .buttonStyle(.plain)
          .help("Re-verify digital signatures")
          .accessibilityLabel("Re-verify digital signatures")
        }

        if let sig = model.signatureVerificationResult {
          HStack(spacing: 8) {
            switch sig.status {
            case .validAndTrusted:
              Label("Valid & Trusted", systemImage: "checkmark.seal.fill")
                .foregroundStyle(.green)
            case .validDigestUntrustedCert:
              Label("Valid Digest (Self-Signed)", systemImage: "checkmark.seal")
                .foregroundStyle(.blue)
            case .digestMismatch:
              Label("Digest Mismatch", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            case .invalidByteRange:
              Label("Invalid ByteRange", systemImage: "xmark.octagon.fill")
                .foregroundStyle(.red)
            case .unsigned:
              Label("Unsigned Document", systemImage: "doc")
                .foregroundStyle(.secondary)
            }
            Spacer()
            if sig.isAlteredAfterSigning {
              Text("Altered Post-Signing")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.red.opacity(0.15), in: Capsule())
                .foregroundStyle(Color.red)
            }
          }
          .font(.caption.weight(.medium))

          if let signer = sig.signerName, !signer.isEmpty {
            HStack {
              Text("Signer:")
                .font(.caption2)
                .foregroundStyle(.secondary)
              Spacer()
              Text(signer)
                .font(.caption2.weight(.medium))
            }
          }

          if let reason = sig.signatureReason, !reason.isEmpty {
            HStack {
              Text("Reason:")
                .font(.caption2)
                .foregroundStyle(.secondary)
              Spacer()
              Text(reason)
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
          }

          if let digest = sig.computedSHA256 {
            HStack {
              Text("SHA-256:")
                .font(.caption2)
                .foregroundStyle(.secondary)
              Spacer()
              Text("\(digest.prefix(16))…")
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
            }
          }
        } else {
          Button {
            model.verifyDigitalSignatures()
          } label: {
            Label("Verify Signatures", systemImage: "signature")
              .font(.caption.weight(.medium))
          }
          .buttonStyle(.bordered)
          .controlSize(.small)
        }
      }
      .padding(12)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
      )

      // Engine & Execution Provenance Card
      VStack(alignment: .leading, spacing: 8) {
        Label("Engine & Execution Provenance", systemImage: "cpu")
          .font(.caption.weight(.bold))
          .foregroundStyle(.secondary)

        HStack {
          Text("Rendering Provider")
            .font(.caption2)
            .foregroundStyle(.secondary)
          Spacer()
          Text(model.usePipelineRendering ? "Custom Metal/CoreGraphics Pipeline" : "Apple PDFKit Native Engine")
            .font(.caption2.weight(.medium))
        }

        HStack {
          Text("Pipeline Mode")
            .font(.caption2)
            .foregroundStyle(.secondary)
          Spacer()
          Text(model.usePipelineRendering ? "Direct Pipeline" : "Standard Bridge")
            .font(.caption2.monospaced())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
        }

        HStack {
          Text("Native Form Fields")
            .font(.caption2)
            .foregroundStyle(.secondary)
          Spacer()
          Text("\(inspection.fields.count) parsed via AcroForm")
            .font(.caption2)
        }

        HStack {
          Text("Detected Candidates")
            .font(.caption2)
            .foregroundStyle(.secondary)
          Spacer()
          Text("\(model.activeCandidates.count) region(s)")
            .font(.caption2)
        }
      }
      .padding(12)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
      )

      // Execution Receipt Card (TASK-A2 / D-085)
      let receipt = model.currentExecutionReceipt()
      VStack(alignment: .leading, spacing: 10) {
        HStack(spacing: 8) {
          Label("Execution Receipt", systemImage: "checkmark.seal.fill")
            .font(.caption.weight(.bold))
            .foregroundStyle(Color.accentColor)

          Spacer()

          Text(receipt.isSuccess ? "VERIFIED" : "ATTENTION")
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(receipt.isSuccess ? Color.green.opacity(0.15) : Color.orange.opacity(0.15), in: Capsule())
            .foregroundStyle(receipt.isSuccess ? Color.green : Color.orange)
        }

        Text(receipt.actionName)
          .font(.subheadline.weight(.semibold))

        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Text("Route")
              .font(.caption2)
              .foregroundStyle(.secondary)
            Spacer()
            Text(receipt.executionRoute)
              .font(.caption2.weight(.medium))
          }

          HStack {
            Text("Source SHA")
              .font(.caption2)
              .foregroundStyle(.secondary)
            Spacer()
            Text(String(receipt.sourceDigest.prefix(12)) + "…")
              .font(.caption2.monospaced())
              .padding(.horizontal, 4)
              .padding(.vertical, 1)
              .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 3))
          }

          HStack {
            Text("Target SHA")
              .font(.caption2)
              .foregroundStyle(.secondary)
            Spacer()
            Text(String(receipt.targetDigest.prefix(12)) + "…")
              .font(.caption2.monospaced())
              .padding(.horizontal, 4)
              .padding(.vertical, 1)
              .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 3))
          }
        }

        Divider()

        // Verification Checks
        VStack(alignment: .leading, spacing: 4) {
          Text("INVARIANT VERIFICATION")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.secondary)

          ForEach(receipt.verificationChecks) { check in
            HStack(alignment: .top, spacing: 6) {
              Image(systemName: check.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(check.passed ? Color.green : Color.red)
                .padding(.top, 1)
              VStack(alignment: .leading, spacing: 1) {
                Text(check.name)
                  .font(.caption2.weight(.medium))
                Text(check.detail)
                  .font(.system(size: 10))
                  .foregroundStyle(.secondary)
              }
            }
          }
        }

        Divider()

        HStack(spacing: 8) {
          Button {
            let plainText = receipt.exportAsPlainText()
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(plainText, forType: .string)
            isReceiptCopied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
              isReceiptCopied = false
            }
          } label: {
            HStack(spacing: 4) {
              Image(systemName: isReceiptCopied ? "checkmark" : "doc.on.clipboard")
              Text(isReceiptCopied ? "Copied!" : "Copy Receipt")
            }
            .font(.caption2.weight(.medium))
          }
          .buttonStyle(.bordered)
          .controlSize(.small)

          Button {
            let panel = NSSavePanel()
            panel.title = "Export Execution Receipt"
            panel.nameFieldStringValue = "Execution-Receipt-\(receipt.id.uuidString.prefix(8)).txt"
            panel.allowedContentTypes = [.plainText]
            if panel.runModal() == .OK, let url = panel.url {
              try? receipt.exportAsPlainText().write(to: url, atomically: true, encoding: .utf8)
            }
          } label: {
            HStack(spacing: 4) {
              Image(systemName: "square.and.arrow.down")
              Text("Export .txt")
            }
            .font(.caption2.weight(.medium))
          }
          .buttonStyle(.bordered)
          .controlSize(.small)

          Button {
            let panel = NSSavePanel()
            panel.title = "Export Execution Receipt (JSON)"
            panel.nameFieldStringValue = "Execution-Receipt-\(receipt.id.uuidString.prefix(8)).json"
            panel.allowedContentTypes = [.json]
            if panel.runModal() == .OK, let url = panel.url {
              let encoder = JSONEncoder()
              encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
              if let data = try? encoder.encode(receipt) {
                try? data.write(to: url)
              }
            }
          } label: {
            HStack(spacing: 4) {
              Image(systemName: "doc.badge.gearshape")
              Text("Export .json")
            }
            .font(.caption2.weight(.medium))
          }
          .buttonStyle(.bordered)
          .controlSize(.small)
        }
      }
      .padding(12)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .strokeBorder(Color.accentColor.opacity(0.18), lineWidth: 1)
      )

      // Export Validation Status
      if let exportReport = model.exportReport {
        VStack(alignment: .leading, spacing: 6) {
          Text("Export Validation")
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)

          HStack {
            Image(systemName: exportReport.status == .validated ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
              .foregroundStyle(exportReport.status == .validated ? Color.green : Color.orange)
            Text(exportReport.status.rawValue.capitalized)
              .font(.caption.weight(.semibold))
          }

          ForEach(exportReport.messages.prefix(3), id: \.self) { msg in
            Text(msg)
              .font(.caption2)
              .foregroundStyle(.secondary)
          }

          exportDispositionControls
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
      }

      // Vault Drawer Launcher Button
      Button {
        isSecurityVaultPresented = true
      } label: {
        HStack {
          Label("Open Security & Privacy Vault…", systemImage: "lock.shield.fill")
            .font(.callout.weight(.medium))
          Spacer()
          Image(systemName: "arrow.up.forward.app")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.regular)
      .tint(Color.accentColor)
    }
  }

  private func confidenceLabel(_ score: Double) -> String {
    // D-067: evidence strength, never calibrated probability.
    if score >= 0.75 { return "Review required · Strong evidence" }
    if score >= 0.5 { return "Review required · Medium evidence" }
    return "Review required · Limited evidence"
  }

  private func candidateEntryLabel(_ candidate: RegionCandidate) -> String {
    switch candidate.entryMode {
    case .singleText: return "Text entry"
    case .characterGrid: return "Grid (\(candidate.groupMemberCount) cells)"
    case .checkbox: return "Checkbox"
    case .radioGroup: return "Choice group"
    case .signature: return "Signature"
    case .unknown: return "Entry region"
    }
  }

  private func commitRename(_ candidate: RegionCandidate) {
    model.renameCandidate(candidate.id, to: renameDraft)
    isRenamingCandidate = false
  }

  /// Per-cell choice names extracted from adjacent document text, falling
  /// back to positional naming only when no option text was found.
  private func namedOptions(for candidate: RegionCandidate) -> [String] {
    let named = candidate.effectiveOptionLabels
    return candidate.memberBounds.indices.map { index in
      let name = index < named.count ? named[index] : ""
      return name.isEmpty ? "Option \(index + 1)" : name
      }
    }

  @ViewBuilder
  private var exportDispositionControls: some View {
    let options = model.exportDispositionOptions
    if options.canRework || options.canAcceptAsVariance || options.canDiscard {
      HStack(spacing: 8) {
        if options.canRework {
          Button("Rework") {
            model.reworkLastExport()
          }
          .buttonStyle(.bordered)
          .help("Discard this derived copy and return to the live document operations.")
        }

        if options.canAcceptAsVariance {
          Button("Accept Variance") {
            _ = model.acceptLastExportAsVariance()
          }
          .buttonStyle(.bordered)
          .help("Retain the copy while keeping its validation warnings visible.")
        }

        if options.canDiscard {
          Button("Discard Copy", role: .destructive) {
            isDiscardingExportPresented = true
          }
          .buttonStyle(.bordered)
        }
      }
      .font(.caption)
    }
  }
}
