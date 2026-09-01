import AppKit
import PDFEditorCore
import PDFEditorRecovery
import SwiftUI

public enum InspectorTab: String, CaseIterable, Identifiable {
  case focus = "Focus & Edit"
  case understand = "Understand"
  case learn = "Learn"
  case document = "Document"
  case trust = "Trust & Safety"

  public var id: String { rawValue }
  public var symbolName: String {
    switch self {
    case .focus: return "scope"
    case .understand: return "brain.head.profile"
    case .learn: return "book"
    case .document: return "doc.text"
    case .trust: return "lock.shield"
    }
  }

}

public struct ContextualInspectorView: View {
  @Bindable var model: AppModel
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

  // MARK: - Focus & Edit Tab
  private var focusTabContent: some View {
    VStack(alignment: .leading, spacing: 16) {
      // 1. Evidence Rail
      contextEvidenceRail

      // 1a. Explain quiet contextual projections without turning the canvas
      // menu into a disabled command inventory.
      adaptiveCommandStatusSection

      if let mark = selectedAnnotation {
        selectedAnnotationCard(mark)
      }

      // 2. Authoring Toolbar
      authoringToolsPalette

      // 3. Selected Candidate Card
      if let candidate = model.selectedCandidate {
        selectedCandidateCard(candidate)
      }

      // 4. Selected Native Field Card
      if let field = model.selectedField {
        selectedNativeFieldCard(field)
      }

      // 5. Quick Bulk Fill Card
      profileBulkFillCard

      // 6. Active Suggested Areas List
      candidateSuggestionsList

      // 7. Search Matches (if any)
      if !model.searchMatches.isEmpty {
        searchMatchesSection
      }
    }
  }

  @ViewBuilder
  private var contextEvidenceRail: some View {
    if let mark = selectedAnnotation {
      evidenceRail(
        title: "Selected annotation",
        symbol: mark.type.symbolName,
        source: "Page \(mark.pageIndex + 1)",
        provider: "Local annotation sidecar",
        confidence: "User-authored",
        limitation: mark.note.isEmpty
          ? "This mark is stored separately from the source PDF."
          : "The note is commentary and does not change source PDF bytes.",
        nextAction: "Use the contextual menu to inspect this annotation."
      )
    } else if let candidate = model.selectedCandidate {
      let explanation = SuggestionExplainer.explain(candidate)
      evidenceRail(
        title: "Detected suggestion",
        symbol: "scope",
        source: "Page \(candidate.pageIndex + 1)",
        provider: explanation.providerID,
        confidence: confidenceLabel(candidate.score),
        limitation: candidate.fusion?.state == "supported"
          ? "Independent signals agree, but the region still needs your confirmation."
          : "Evidence is mixed or limited; confirm the region before applying it.",
        nextAction: candidate.isDirectlyEditable
          ? "Review the value and place it when ready."
          : "Review the suggested region before marking it."
      )
    } else if let field = model.selectedField {
      evidenceRail(
        title: "Native PDF field",
        symbol: "checkmark.square",
        source: "Page \(field.pageIndex + 1)",
        provider: inspection.provenance.fieldInspector,
        confidence: "Source structure",
        limitation: "Confirm the field value and export behavior before delivery.",
        nextAction: "Use the field editor or Fill mode to complete it."
      )
    } else {
      evidenceRail(
        title: "Document context",
        symbol: "doc.text.magnifyingglass",
        source: inspection.source.fileName,
        provider: inspection.provenance.textExtractor,
        confidence: "Source inspection",
        limitation: inspection.warnings.first ?? "No selected object is being interpreted.",
        nextAction: "Select text, a field, or a suggestion to reveal its evidence."
      )
    }
  }

  private func evidenceRail(
    title: String,
    symbol: String,
    source: String,
    provider: String,
    confidence: String,
    limitation: String,
    nextAction: String
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Image(systemName: symbol)
          .foregroundStyle(.tint)
        Text(title)
          .font(.subheadline.weight(.semibold))
        Spacer()
        Text("EVIDENCE")
          .font(.caption2.weight(.bold).monospaced())
          .foregroundStyle(.secondary)
      }

      HStack(alignment: .top, spacing: 12) {
        evidenceRailMetric("Source", source)
        evidenceRailMetric("Provider", provider)
        evidenceRailMetric("Confidence", confidence)
      }

      Label(limitation, systemImage: "exclamationmark.triangle")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      Label(nextAction, systemImage: "arrow.right.circle")
        .font(.caption.weight(.medium))
        .foregroundStyle(.tint)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(10)
    .background(.thinMaterial)
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 8))
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
    VStack(alignment: .leading, spacing: 8) {
      Text("Authoring Tools")
        .font(.caption.weight(.bold))
        .foregroundStyle(.secondary)

      HStack(spacing: 8) {
        Button {
          model.beginManualTextPlacement()
        } label: {
          Label("Add Text", systemImage: "text.cursor")
            .font(.caption.weight(.medium))
        }
        .buttonStyle(.borderedProminent)
        .disabled(!(model.inspection?.permissions.canAddAnnotations ?? false))
        .help("Click anywhere on the page to place new text overlay.")

        Button {
          model.beginSign(for: nil)
        } label: {
          Label("Sign", systemImage: "signature")
            .font(.caption.weight(.medium))
        }
        .buttonStyle(.bordered)
        .disabled(!(model.inspection?.permissions.canAddAnnotations ?? false))
        .help("Open signature pad to draw, type, or import your signature.")

        Button {
          model.runOCROnSelectedPage()
        } label: {
          Label("OCR Page", systemImage: "text.viewfinder")
            .font(.caption.weight(.medium))
        }
        .buttonStyle(.bordered)
        .disabled(!(model.inspection?.permissions.canCopy ?? false))
        .help("Run local Vision OCR on the selected page.")
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
    .padding(10)
    /* Warm-tinted section background */
    .background(Color.orange.opacity(0.04))
    .clipShape(RoundedRectangle(cornerRadius: 8))
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

      // Deterministic evidence card (R7 baseline): why this suggestion
      // exists and what to double-check before applying it.
      let explanation = SuggestionExplainer.explain(candidate)
      VStack(alignment: .leading, spacing: 3) {
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

      if let profile = model.currentProfile {
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
        VStack(spacing: 4) {
          Image(systemName: "doc.text.magnifyingglass")
            .font(.title3)
            .foregroundStyle(.tertiary)
          Text("No suggestions detected")
            .font(.caption.weight(.medium))
          Text("Switch to Fill mode to detect form fields, or run OCR to extract text regions.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
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
      // Run Analysis button
      if understandResult.summary == nil && !isLoadingUnderstand {
        VStack(alignment: .leading, spacing: 8) {
          Text("Document Analysis")
            .font(.subheadline.weight(.semibold))
          Text("Extract key points, entities, and structure from this document.")
            .font(.caption)
            .foregroundStyle(.secondary)
          Button {
            Task { await runUnderstandAnalysis() }
          } label: {
            Label("Analyze Document", systemImage: "brain.head.profile")
          }
          .buttonStyle(.borderedProminent)
        }
      }

      if isLoadingUnderstand {
        HStack(spacing: 8) {
          ProgressView()
            .controlSize(.small)
          Text("Analyzing...")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      if let error = understandError {
        Label(error, systemImage: "exclamationmark.triangle")
          .font(.caption)
          .foregroundStyle(.red)
      }

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
      // Study Loop Header
      HStack {
        Image(systemName: "book")
          .font(.title2)
          .foregroundColor(.purple)
        VStack(alignment: .leading) {
          Text("Study Your Marks")
            .font(.subheadline.weight(.semibold))
          Text("Active recall from annotation marks")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        Spacer()
      }

      // Annotation marks count
      let visibleMarks = annotationStore.marks.filter { $0.isVisible }
      if visibleMarks.isEmpty {
        VStack(spacing: 12) {
          Image(systemName: "highlighter")
            .font(.title)
            .foregroundColor(.secondary)
          Text("No annotation marks yet")
            .font(.subheadline)
            .foregroundColor(.secondary)
          Text("Select text in the document to create highlights, underlines, or notes. These marks become your study material.")
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
      } else {
        // Quick stats
        VStack(alignment: .leading, spacing: 8) {
          Text("\(visibleMarks.count) mark\(visibleMarks.count == 1 ? "" : "s") available for study")
            .font(.subheadline)

          // Mark type breakdown
          let highlights = visibleMarks.filter { $0.type == .highlight }.count
          let underlines = visibleMarks.filter { $0.type == .underline }.count
          let notes = visibleMarks.filter { $0.type == .note }.count
          let others = visibleMarks.count - highlights - underlines - notes

          HStack(spacing: 12) {
            if highlights > 0 {
              Label("\(highlights) highlight\(highlights == 1 ? "" : "s")", systemImage: "highlighter")
                .font(.caption)
                .foregroundColor(.yellow)
            }
            if underlines > 0 {
              Label("\(underlines) underline\(underlines == 1 ? "" : "s")", systemImage: "underline")
                .font(.caption)
                .foregroundColor(.blue)
            }
            if notes > 0 {
              Label("\(notes) note\(notes == 1 ? "" : "s")", systemImage: "note.text")
                .font(.caption)
                .foregroundColor(.green)
            }
            if others > 0 {
              Label("\(others) other", systemImage: "pencil.line")
                .font(.caption)
                .foregroundColor(.gray)
            }
          }
        }
        .padding(10)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))

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

  // MARK: - Document Tab
  private var documentTabContent: some View {
    VStack(alignment: .leading, spacing: 14) {
      capabilityPassportSection

      Divider()

      // Metadata
      VStack(alignment: .leading, spacing: 6) {
        Text("Document Metadata")
          .font(.subheadline.weight(.semibold))

        LabeledContent("Title", value: inspection.metadata.title.isEmpty ? "Not declared" : inspection.metadata.title)
        LabeledContent("Author", value: inspection.metadata.author.isEmpty ? "Not declared" : inspection.metadata.author)
        LabeledContent("Producer", value: inspection.metadata.producer.isEmpty ? "Not declared" : inspection.metadata.producer)
        LabeledContent("Creator", value: inspection.metadata.creator.isEmpty ? "Not declared" : inspection.metadata.creator)
      }
      .font(.caption)

      Divider()

      // Permissions
      VStack(alignment: .leading, spacing: 6) {
        Text("Permissions & Security")
          .font(.subheadline.weight(.semibold))

        LabeledContent("Encrypted", value: inspection.security.isEncrypted ? "Yes" : "No")
        LabeledContent("Can copy text", value: inspection.permissions.canCopy ? "Yes" : "No")
        LabeledContent("Can modify", value: inspection.permissions.canModify ? "Yes" : "No")
        LabeledContent("Can annotate", value: inspection.permissions.canAddAnnotations ? "Yes" : "No")
      }
      .font(.caption)

      Divider()

      // Outlines / Bookmarks
      if !inspection.outlines.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          Text("Bookmarks & Outline")
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
                  Text("p.\(p + 1)").foregroundStyle(.secondary)
                }
              }
              .padding(.leading, CGFloat(item.level) * 8)
              .font(.caption)
            }
            .buttonStyle(.plain)
          }
        }
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
        Label("Capability Passport", systemImage: "checkmark.seal")
          .font(.subheadline.weight(.semibold))
        Spacer()
        Text("LOCAL")
          .font(.caption2.weight(.bold).monospaced())
          .foregroundStyle(.secondary)
      }

      Text("What this source can support in the current session")
        .font(.caption)
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
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 8))
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

  // MARK: - Trust & Safety Tab
  private var trustTabContent: some View {
    VStack(alignment: .leading, spacing: 14) {
      // Local Posture Card
      HStack {
        Image(systemName: "shield.lefthalf.filled.badge.checkmark")
          .font(.title2)
          .foregroundStyle(.green)
        VStack(alignment: .leading, spacing: 2) {
          Text("Local Privacy & Provenance")
            .font(.subheadline.weight(.semibold))
          Text("Zero network egress · Hardware isolated stores")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        Spacer()
      }
      .padding(10)
      .background(Color.green.opacity(0.08))
      .clipShape(RoundedRectangle(cornerRadius: 8))

      // Preflight Report Card
      if let report = model.preflightReport {
        VStack(alignment: .leading, spacing: 6) {
          Text("Source Preflight")
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)

          Text("Digest: \(report.header.sourceDigest.prefix(16))...")
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)

          HStack(spacing: 8) {
            Text("\(report.payload.summary.findingCount) Findings")
            Text("\(report.payload.summary.metadataFieldCount) Meta")
            Text("\(report.payload.summary.embeddedDataCount) Embeds")
          }
          .font(.caption2)
          .foregroundStyle(.secondary)

          // RG-097: Native preflight parity with web — show sanitization and security
          Text("Sanitization: \(report.payload.sanitization.status)")
            .font(.caption2)
            .foregroundStyle(.secondary)
          Text("External URLs: \(report.payload.networkBoundaries.externalURLCount) (\(report.payload.networkBoundaries.unsafeExternalURLCount) unsafe)")
            .font(.caption2)
            .foregroundStyle(.secondary)
          Text("Encrypted: \(report.payload.security.encrypted ? "Yes" : "No")")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
      }

      // Export Validation Status
      if let exportReport = model.exportReport {
        VStack(alignment: .leading, spacing: 4) {
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
        .padding(10)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
      }

      Divider()

      // Vault Drawer Launcher
      Button {
        isSecurityVaultPresented = true
      } label: {
        HStack {
          Image(systemName: "lock.shield")
          Text("Open Security & Privacy Vault…")
          Spacer()
          Image(systemName: "arrow.up.forward.app")
        }
        .font(.caption.weight(.medium))
        .padding(8)
      }
      .buttonStyle(.bordered)
    }
  }

  private func confidenceLabel(_ score: Double) -> String {
    let percent = Int(score * 100)
    if score >= 0.75 { return "High · \(percent)%" }
    if score >= 0.5 { return "Med · \(percent)%" }
    return "Low · \(percent)%"
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
