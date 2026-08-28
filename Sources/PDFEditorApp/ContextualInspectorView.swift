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
  @State private var understandResult: (summary: DocumentSummary?, entities: EntityRecognitionResult?, keyPoints: KeyPointExtractionResult?) = (nil, nil, nil)
  @State private var understandError: String?
  @State private var isLoadingUnderstand = false
  @State private var fieldDraft = ""
  @State private var overlayDraft = ""
  @State private var choiceCellIndex = 0
  @State private var isRenamingCandidate = false
  @State private var renameDraft = ""
  @State private var templateDisplayName = "Reviewed local layout"

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
  }

  // MARK: - Focus & Edit Tab
  private var focusTabContent: some View {
    VStack(alignment: .leading, spacing: 16) {
      // 1. Authoring Toolbar
      authoringToolsPalette

      // 2. Selected Candidate Card
      if let candidate = model.selectedCandidate {
        selectedCandidateCard(candidate)
      }

      // 3. Selected Native Field Card
      if let field = model.selectedField {
        selectedNativeFieldCard(field)
      }

      // 4. Quick Bulk Fill Card
      profileBulkFillCard

      // 5. Active Suggested Areas List
      candidateSuggestionsList

      // 6. Search Matches (if any)
      if !model.searchMatches.isEmpty {
        searchMatchesSection
      }
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
    }
  }

  @MainActor
  private func runUnderstandAnalysis() async {
    isLoadingUnderstand = true
    understandError = nil
    defer { isLoadingUnderstand = false }

    do {
      let result = try renderingPipeline.understand()
      understandResult = (result.summary, result.entities, result.keyPoints)
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
}
