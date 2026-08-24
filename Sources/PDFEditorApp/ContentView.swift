import PDFEditorCore
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
  @Bindable var model: AppModel

  init(model: AppModel) {
    self.model = model
  }

  var body: some View {
    Group {
      if let inspection = model.inspection {
        EditorView(model: model, inspection: inspection)
      } else {
        WelcomeView {
          model.isImporterPresented = true
        }
      }
    }
    .toolbar {
      ToolbarItemGroup {
        Button("Open", systemImage: "folder") {
          model.isImporterPresented = true
        }
        Button("Undo", systemImage: "arrow.uturn.backward") {
          model.undoLastEdit()
        }
        .disabled(!model.canUndo)
        Button("Redo", systemImage: "arrow.uturn.forward") {
          model.redoLastEdit()
        }
        .disabled(!model.canRedo)
        Button("Export", systemImage: "square.and.arrow.down") {
          model.export()
        }
        .disabled(!model.canExportCurrentOperations)
      }
      ToolbarItem {
        Picker(
          "Reader mode",
          selection: Binding(
            get: { model.readerViewMode },
            set: { model.setReaderViewMode($0) }
          )
        ) {
          Text("Single").tag(ReaderViewMode.singlePage)
          Text("Continuous").tag(ReaderViewMode.continuous)
          Text("Two-page").tag(ReaderViewMode.twoPage)
        }
        .pickerStyle(.segmented)
        .frame(width: 220)
      }
      ToolbarItem {
        Picker(
          "Scale",
          selection: Binding(
            get: { model.readerScaleMode },
            set: { model.setReaderScaleMode($0) }
          )
        ) {
          Text("Fit width").tag(ReaderScaleMode.fitWidth)
          Text("Fit page").tag(ReaderScaleMode.fitPage)
          Text("Zoom").tag(ReaderScaleMode.zoom)
        }
        .pickerStyle(.menu)
        .frame(width: 140)
      }
      ToolbarItem(placement: .status) {
        Text(model.statusMessage ?? "Ready")
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
    .fileImporter(
      isPresented: $model.isImporterPresented,
      allowedContentTypes: [.pdf],
      allowsMultipleSelection: false
    ) { result in
      switch result {
      case .success(let urls):
        if let url = urls.first {
          model.open(url: url)
        }
      case .failure(let error):
        model.alertMessage = error.localizedDescription
      }
    }
    .alert(
      "PDF Editor",
      isPresented: Binding(
        get: { model.alertMessage != nil },
        set: { isPresented in
          if !isPresented { model.alertMessage = nil }
        }
      )
    ) {
      Button("OK") {
        model.alertMessage = nil
      }
    } message: {
      Text(model.alertMessage ?? "")
    }
    .sheet(isPresented: $model.isPasswordSheetPresented) {
      PasswordPromptView(model: model)
    }
    .sheet(isPresented: $model.isManualTextSheetPresented) {
      ManualTextSheet(model: model)
    }
  }
}

private struct WelcomeView: View {
  let open: () -> Void

  var body: some View {
    VStack(spacing: 18) {
      Image(systemName: "doc.text.magnifyingglass")
        .font(.system(size: 54, weight: .light))
        .foregroundStyle(.tint)
      Text("Complete PDFs without disturbing the source")
        .font(.title2.weight(.semibold))
      Text(
        "Open a PDF, review native fields and suggestions, and run reading/navigation workflows with bounded local export."
      )
      .foregroundStyle(.secondary)
      .multilineTextAlignment(.center)
      .frame(maxWidth: 520)
      Button("Open a PDF…", action: open)
        .keyboardShortcut(.defaultAction)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(40)
  }
}

private struct PasswordPromptView: View {
  @Bindable var model: AppModel

  var body: some View {
    VStack(spacing: 16) {
      Text("PDF password")
        .font(.headline)
      Text("This file is encrypted. Enter a password to open it.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
      SecureField("Password", text: $model.passwordAttempt)
        .textFieldStyle(.roundedBorder)
        .onSubmit {
          model.submitPassword()
        }
        .frame(width: 320)
      HStack(spacing: 12) {
        Button("Cancel") {
          model.dismissPasswordPrompt()
        }
        Button("Open") {
          model.submitPassword()
        }
        .keyboardShortcut(.defaultAction)
        .buttonStyle(.borderedProminent)
      }
    }
    .padding(24)
  }
}

private struct ManualTextSheet: View {
  @Bindable var model: AppModel

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Add text to the document")
        .font(.title3.weight(.semibold))
      Text(
        "This creates a reversible overlay in the selected area. It does not claim that the source PDF contains a native form field."
      )
      .font(.callout)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
      TextField("Text to place", text: $model.manualTextDraft)
        .textFieldStyle(.roundedBorder)
        .onSubmit { model.applyManualText() }
      HStack {
        Button("Cancel") {
          model.cancelManualTextPlacement()
        }
        Spacer()
        Button("Add text") {
          model.applyManualText()
        }
        .buttonStyle(.borderedProminent)
        .disabled(model.manualTextDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }
    .padding(24)
    .frame(width: 420)
  }
}

private struct EditorView: View {
  let model: AppModel
  let inspection: DocumentInspection

  var body: some View {
    VStack(spacing: 10) {
      ReaderControlBar(model: model)
      HSplitView {
        PageList(model: model, inspection: inspection)
          .frame(minWidth: 200, idealWidth: 230, maxWidth: 280)
        PDFKitView(
          document: model.liveDocument,
          pageIndex: model.selectedPageIndex,
          viewMode: model.readerViewMode,
          scaleMode: model.readerScaleMode,
          zoom: model.readerZoom,
          rotation: model.readerRotation,
          selectedSearchMatch: model.selectedSearchMatch,
          selectedCandidate: model.selectedCandidate,
          selectedField: model.selectedField,
          isManualPlacementMode: model.isManualPlacementMode,
          onManualPlacement: { pageIndex, point in
            model.receiveManualPlacement(pageIndex: pageIndex, point: point)
          },
          onDirectEdit: { pageIndex, point in
            model.beginDirectTextPlacement(pageIndex: pageIndex, point: point)
          }
        )
        .frame(minWidth: 520)
        InspectorView(model: model, inspection: inspection)
          .frame(minWidth: 320, idealWidth: 360, maxWidth: 460)
      }
      .padding(.horizontal, 8)
    }
  }
}

private struct ReaderControlBar: View {
  @Bindable var model: AppModel

  var body: some View {
    VStack(spacing: 10) {
      HStack {
        Text("Page")
        TextField("Page", text: $model.pageJumpInput)
          .textFieldStyle(.roundedBorder)
          .frame(width: 72)
          .onSubmit { model.runPageJump() }
        Button("Go") {
          model.runPageJump()
        }
        Spacer()
        Text("Zoom")
        Slider(
          value: Binding(
            get: { model.readerZoom },
            set: { model.setZoom($0) }
          ),
          in: 0.25...3.0
        )
        .frame(width: 160)
        Text(model.readerZoom, format: .number.precision(.fractionLength(2)))
          .frame(width: 52, alignment: .trailing)
          .monospacedDigit()
        Button("−") {
          model.setZoom(model.readerZoom - 0.1)
        }
        Button("+") {
          model.setZoom(model.readerZoom + 0.1)
        }
        Button("Rotate ⟲") {
          model.rotateLeft()
        }
        Button("Rotate ⟳") {
          model.rotateRight()
        }
        Button("Copy page text") {
          model.copyCurrentPageText()
        }
      }
      HStack {
        SearchField(model: model)
        Spacer()
        Text("Labels and access")
          .foregroundStyle(.secondary)
          .font(.callout)
      }
      Divider()
    }
    .padding(.horizontal, 10)
    .padding(.top, 8)
  }
}

private struct SearchField: View {
  @Bindable var model: AppModel

  var body: some View {
    HStack(spacing: 8) {
      TextField("Search in document", text: $model.searchQuery)
        .textFieldStyle(.roundedBorder)
        .onSubmit { model.runSearch() }
      Button("Find") {
        model.runSearch()
      }
      if model.canClearSearch {
        Button("Clear") {
          model.clearSearch()
        }
      }
      if !model.searchMatches.isEmpty {
        Text("\(model.searchMatches.count) matches")
          .font(.caption)
          .foregroundStyle(.secondary)
        Button("Prev") { model.selectPreviousSearchMatch() }
        Button("Next") { model.selectNextSearchMatch() }
        if let selected = model.selectedSearchMatchIndex {
          Text("#\(selected + 1)")
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
      }
    }
  }
}

private struct PageList: View {
  let model: AppModel
  let inspection: DocumentInspection

  var body: some View {
    List {
      Section("Pages (thumbnails)") {
        ForEach(inspection.pages) { page in
          Button {
            model.selectedPageIndex = page.pageIndex
          } label: {
            HStack {
              Image(systemName: model.selectedPageIndex == page.pageIndex ? "doc.fill" : "doc")
              VStack(alignment: .leading) {
                Text("Page \(page.pageLabel)")
                Text("\(page.characterCount) chars")
                  .font(.caption)
                  .foregroundStyle(.secondary)
                Text("Media: \(Int(page.bounds.width))x\(Int(page.bounds.height))")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .monospacedDigit()
                if let crop = page.cropBox {
                  Text("Crop: \(Int(crop.width))x\(Int(crop.height))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                }
              }
              Spacer()
              if page.hasSelectableText {
                Image(systemName: "text.alignleft")
                  .foregroundStyle(.secondary)
                  .help("Selectable text available")
              }
            }
          }
          .buttonStyle(.plain)
          .padding(.vertical, 2)
          .accessibilityElement(children: .combine)
          .accessibilityLabel("Page \(page.pageLabel), \(page.characterCount) characters, \(page.hasSelectableText ? "has selectable text" : "no selectable text")")
          .accessibilityHint("Selects page \(page.pageLabel)")
          .accessibilityAddTraits(model.selectedPageIndex == page.pageIndex ? [.isSelected, .isButton] : [.isButton])
        }
      }
      Section("Session") {
        LabeledContent("Native fields", value: "\(inspection.fields.count)")
        LabeledContent("Suggestions", value: "\(inspection.candidates.count)")
        LabeledContent("Edits", value: "\(model.operations.count)")
        LabeledContent("Current page", value: "\(model.selectedPageLabel)")
      }
      Section("Security") {
        LabeledContent("Encrypted", value: inspection.security.isEncrypted ? "Yes" : "No")
        LabeledContent("Locked", value: inspection.security.isLocked ? "Yes" : "No")
        if inspection.security.isLocked {
          LabeledContent(
            "Password flow", value: inspection.security.requiresPassword ? "Required" : "Open")
        }
      }
    }
    .listStyle(.sidebar)
  }
}

private struct InspectorView: View {
  let model: AppModel
  let inspection: DocumentInspection
  @State private var fieldDraft = ""
  @State private var overlayDraft = ""
  @State private var choiceCellIndex = 0

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        Text("Review and edit")
          .font(.title3.weight(.semibold))

        profileSection
        fieldSection
        candidateSection
        searchSection
        linkAndOutlineSection
        metadataSection
        validationSection
      }
      .padding(16)
    }
    .onChange(of: model.selectedFieldID, initial: true) { _, _ in
      fieldDraft = model.selectedField.map { model.currentValue(for: $0) } ?? ""
    }
    .onChange(of: model.selectedCandidateID, initial: true) { _, _ in
      overlayDraft = ""
      choiceCellIndex = 0
    }
  }

  private var profileSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label("Profile & Bulk Fill", systemImage: "person.crop.circle")
        .font(.headline)

      if let profile = model.currentProfile {
        // Active profile
        HStack {
          Text(profile.displayName)
            .font(.subheadline.weight(.medium))
          Spacer()
          Button("Switch") {
            model.currentProfile = nil
          }
          .font(.caption)
        }
        .padding(8)
        .background(Color.blue.opacity(0.06))
        .cornerRadius(6)

        // Profile fields
        ForEach(StandardSemanticKey.allCases, id: \.self) { key in
          let value = profile.value(for: key.rawValue) ?? ""
          HStack {
            Text(key.displayName)
              .font(.caption)
              .frame(width: 80, alignment: .trailing)
              .foregroundStyle(.secondary)
            TextField("—", text: Binding(
              get: { value },
              set: { model.updateProfileValue($0, for: key.rawValue) }
            ))
            .textFieldStyle(.roundedBorder)
            .font(.caption)
          }
        }

        Divider()

        // Bulk fill actions
        HStack {
          Button("Preview Fill") {
            model.previewBulkFill()
          }
          .buttonStyle(.bordered)
          .disabled(model.inspection == nil)

          if let result = model.bulkFillResult, result.totalMatches > 0 {
            Button("Apply \(result.totalMatches) Field(s)") {
              model.applyBulkFill()
            }
            .buttonStyle(.borderedProminent)
          }
        }

        if let result = model.bulkFillResult {
          Text("\(result.totalMatches) matched · \(result.unmatchedFields.count) unmatched")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Button("Save Profile") {
          model.saveCurrentProfile()
        }
        .font(.caption)

      } else {
        // No profile selected — show list or create
        if model.availableProfiles.isEmpty {
          Text("No profiles yet. Create one to enable bulk fill.")
            .font(.callout)
            .foregroundStyle(.secondary)
        } else {
          ForEach(model.availableProfiles) { profile in
            Button {
              model.loadProfile(profileID: profile.profileID)
            } label: {
              HStack {
                Image(systemName: "person.circle")
                Text(profile.displayName)
                Spacer()
                Text("\(profile.values.count) fields")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
            .buttonStyle(.plain)
          }
        }

        Divider()

        NewProfileButton { name in
          model.createProfile(displayName: name)
        }
      }
    }
  }

  private var fieldSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label("Native fields", systemImage: "checkmark.square")
        .font(.headline)
      if inspection.fields.isEmpty {
        Text("No native fields were found. This PDF may use static entry regions only.")
          .font(.callout)
          .foregroundStyle(.secondary)
      } else {
        ForEach(inspection.fields) { field in
          Button {
            model.selectedFieldID = field.id
          } label: {
            HStack {
              Image(
                systemName: model.selectedFieldID == field.id ? "checkmark.circle.fill" : "circle")
              VStack(alignment: .leading) {
                Text(field.name)
                Text("Page \(field.pageIndex + 1) · \(field.kind.rawValue)")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              Spacer()
            }
          }
          .buttonStyle(.plain)
        }
        if let field = model.selectedField {
          if field.kind == .button {
            let options = model.buttonOptions(for: field)
            if options.count > 1 {
              Picker("Selected option", selection: $fieldDraft) {
                ForEach(options, id: \.self) { option in
                  Text(option).tag(option)
                }
              }
              .pickerStyle(.menu)
            } else {
              Toggle(
                "Checked",
                isOn: Binding(
                  get: { ["1", "true", "yes", "on", "checked"].contains(fieldDraft.lowercased()) },
                  set: { fieldDraft = $0 ? (options.first ?? "Yes") : "false" }
                ))
            }
          } else if field.kind == .choice && !field.choices.isEmpty {
            Picker("Selected option", selection: $fieldDraft) {
              Text("Empty").tag("")
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
          }
          Button("Apply native field") {
            model.applyFieldValue(fieldDraft)
          }
          .disabled(field.kind == .signature)
        }
      }
    }
  }

  private var candidateSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Label("Suggested areas (\(model.activeCandidates.count))", systemImage: "scope")
          .font(.headline)
        Spacer()
        Button("OCR Page") {
          model.runOCROnSelectedPage()
        }
        .font(.caption)
        .buttonStyle(.bordered)
      }
      Text(
        "These are interpreted regions, not guaranteed fields. Review the label and geometry before applying text. Double-click the page to place text directly."
      )
      .font(.callout)
      .foregroundStyle(.secondary)
      HStack(spacing: 8) {
        Button("Add text manually", systemImage: "plus.circle") {
          model.beginManualTextPlacement()
        }
        .buttonStyle(.borderedProminent)
        if model.isManualPlacementMode {
          Button("Cancel placement") {
            model.cancelManualTextPlacement()
          }
          .buttonStyle(.bordered)
        }
      }
      if !model.activeCandidates.isEmpty {
        HStack(spacing: 8) {
          Button("Previous", systemImage: "chevron.left") {
            model.selectPreviousCandidate()
          }
          .font(.caption)
          .keyboardShortcut("[", modifiers: .command)
          Button("Next", systemImage: "chevron.right") {
            model.selectNextCandidate()
          }
          .font(.caption)
          .keyboardShortcut("]", modifiers: .command)
        }
      }
      if model.activeCandidates.isEmpty {
        Text("No active suggestions. You can add text manually or run OCR on this page.")
          .foregroundStyle(.secondary)
      } else {
        if let candidate = model.selectedCandidate {
          selectedCandidateCard(candidate)
        }
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 4) {
            ForEach(model.activeCandidates) { candidate in
              candidateRow(candidate)
            }
          }
        }
        .frame(maxHeight: 250)
      }
      if !model.dismissedCandidates.isEmpty {
        DisclosureGroup("Dismissed (\(model.dismissedCandidates.count))") {
          ForEach(model.dismissedCandidates) { candidate in
            HStack {
              Text(
                "Page \(candidate.pageIndex + 1) · \(candidate.suggestedFieldType?.rawValue ?? "text")"
              )
              .font(.caption)
              Spacer()
              Button("Restore") {
                model.restoreCandidate(candidate.id)
              }
              .font(.caption)
            }
          }
        }
        .font(.caption)
      }
    }
  }

  private func candidateRow(_ candidate: RegionCandidate) -> some View {
    Button {
      model.selectedCandidateID = candidate.id
      model.selectedFieldID = nil
      model.jumpToPage(candidate.pageIndex)
    } label: {
      HStack(alignment: .top, spacing: 8) {
        Image(systemName: model.selectedCandidateID == candidate.id ? "scope" : "circle.dotted")
          .foregroundStyle(
            model.selectedCandidateID == candidate.id ? Color.accentColor : Color.secondary)
        VStack(alignment: .leading, spacing: 3) {
          HStack {
            Text("Page \(candidate.pageIndex + 1) · \(candidateEntryLabel(candidate))")
              .fontWeight(model.selectedCandidateID == candidate.id ? .semibold : .regular)
            Spacer()
            Text(confidenceLabel(candidate.score))
              .font(.caption.monospacedDigit())
              .foregroundStyle(.secondary)
          }
          Text(candidate.evidence.first ?? "Detected from document structure")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
      }
      .padding(8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        model.selectedCandidateID == candidate.id ? Color.accentColor.opacity(0.12) : Color.clear
      )
      .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Page \(candidate.pageIndex + 1), \(candidateEntryLabel(candidate)), confidence \(confidenceLabel(candidate.score)), \(candidate.evidence.first ?? "Detected from document structure")")
    .accessibilityHint("Selects this suggestion for editing or dismissal")
    .accessibilityAddTraits(model.selectedCandidateID == candidate.id ? [.isSelected, .isButton] : [.isButton])
  }

  private func selectedCandidateCard(_ candidate: RegionCandidate) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Label("Review this area", systemImage: "scope")
          .font(.subheadline.weight(.semibold))
        Spacer()
        Text(confidenceLabel(candidate.score))
          .font(.caption.monospacedDigit())
          .foregroundStyle(.secondary)
      }
      Text("Page \(candidate.pageIndex + 1) · \(candidateEntryLabel(candidate))")
        .font(.caption)
        .foregroundStyle(.secondary)
      if let labelText = candidate.labelText, !labelText.isEmpty {
        Text("Label: \(labelText)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Text(candidate.evidence.first ?? "Detected from document structure")
        .font(.caption)
        .foregroundStyle(.secondary)
      if candidate.isDirectlyEditable {
        TextField(
          candidate.entryMode == .characterGrid
            ? "Enter the full value for this region" : "Enter text to place here",
          text: $overlayDraft
        )
        .textFieldStyle(.roundedBorder)
        .onSubmit {
          model.applyOverlay(overlayDraft)
          overlayDraft = ""
        }
        HStack {
          Button("Add text here", systemImage: "text.cursor") {
            model.applyOverlay(overlayDraft)
            overlayDraft = ""
          }
          .buttonStyle(.borderedProminent)
          .disabled(overlayDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          Button("Create native field", systemImage: "rectangle.and.pencil.and.ellipsis") {
            model.synthesizeNativeField()
          }
          .buttonStyle(.bordered)
          Button("Dismiss", role: .destructive) {
            model.rejectSelectedCandidate()
            overlayDraft = ""
          }
          .buttonStyle(.bordered)
        }
      } else {
        if [.checkbox, .radioGroup].contains(candidate.entryMode), !candidate.memberBounds.isEmpty {
          Label(
            candidate.entryMode == .radioGroup
              ? "Choose one detected option" : "Choose a detected box",
            systemImage: "checkmark.square"
          )
          .font(.callout.weight(.medium))
          .foregroundStyle(.orange)
          Picker("Choice cell", selection: $choiceCellIndex) {
            ForEach(candidate.memberBounds.indices, id: \.self) { index in
              Text("Option (index + 1)").tag(index)
            }
          }
          HStack {
            Button("Mark selected box", systemImage: "checkmark") {
              model.applyStaticChoiceMark(cellIndex: choiceCellIndex)
            }
            .buttonStyle(.borderedProminent)
          }
          Text(
            "This places a reversible visual mark. It is not an AcroForm checkbox or radio widget until the source template is explicitly modeled."
          )
          .font(.caption)
          .foregroundStyle(.secondary)
        } else {
          Label("Detected, but not directly editable yet", systemImage: "hand.raised")
            .font(.callout.weight(.medium))
            .foregroundStyle(.orange)
          Text(
            "Review the geometry, then use Add text manually or dismiss it. Choice regions require a selected option before marking."
          )
          .font(.caption)
          .foregroundStyle(.secondary)
        }
        HStack {
          if candidate.isDirectlyEditable {
            Button("Create native field", systemImage: "rectangle.and.pencil.and.ellipsis") {
              model.synthesizeNativeField()
            }
            .buttonStyle(.bordered)
          }
          Button("Dismiss", role: .destructive) {
            model.rejectSelectedCandidate()
            overlayDraft = ""
          }
          .buttonStyle(.bordered)
        }
      }
    }
    .padding(12)
    .background(Color.accentColor.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 10))
  }

  private func confidenceLabel(_ score: Double) -> String {
    let percent = Int(score * 100)
    if score >= 0.75 { return "High · \(percent)%" }
    if score >= 0.5 { return "Medium · \(percent)%" }
    return "Low · \(percent)%"
  }

  private func candidateEntryLabel(_ candidate: RegionCandidate) -> String {
    switch candidate.entryMode {
    case .singleText:
      return "Text entry region"
    case .characterGrid:
      return "Character-entry region · \(candidate.groupMemberCount) cells"
    case .checkbox:
      return "Checkbox pattern · review only"
    case .radioGroup:
      return "Choice pattern · review only"
    case .signature:
      return "Signature region"
    case .unknown:
      return "Unclassified entry region"
    }
  }

  private var searchSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label("Search matches", systemImage: "magnifyingglass")
        .font(.headline)
      if model.searchMatches.isEmpty {
        Text("No matches yet. Use the search bar above to discover hits.")
          .font(.callout)
          .foregroundStyle(.secondary)
      } else {
        ForEach(Array(model.searchMatches.enumerated()), id: \.offset) { offset, match in
          Button {
            model.setSearchMatch(offset)
          } label: {
            VStack(alignment: .leading, spacing: 4) {
              HStack {
                Text("Page \(match.pageIndex + 1)")
                  .font(.caption)
                  .fontWeight(.semibold)
                Text("(\(offset + 1)/\(model.searchMatches.count))")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              }
              Text(match.snippet)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
          .buttonStyle(.plain)
          .padding(.vertical, 2)
        }
      }
    }
  }

  private var linkAndOutlineSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label("Navigation and structure", systemImage: "list.bullet.indent")
        .font(.headline)

      if inspection.outlines.isEmpty {
        Text("No outline/bookmark tree found in this document.")
          .font(.callout)
          .foregroundStyle(.secondary)
      } else {
        ForEach(inspection.outlines) { item in
          Button {
            if let pageIndex = item.destinationPageIndex {
              model.jumpToPage(pageIndex)
            } else if let first = item.children.first {
              if let pageIndex = first.destinationPageIndex {
                model.jumpToPage(pageIndex)
              }
            }
          } label: {
            HStack {
              Text(item.title)
                .font(.caption)
              Spacer()
              if let pageIndex = item.destinationPageIndex {
                Text("p \(pageIndex + 1)")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              }
            }
            .padding(.leading, CGFloat(item.level) * 8)
          }
          .buttonStyle(.plain)
        }
      }

      if inspection.links.isEmpty {
        Text("No navigable links were collected.")
          .font(.callout)
          .foregroundStyle(.secondary)
      } else {
        VStack(alignment: .leading, spacing: 8) {
          Text("Links")
            .font(.subheadline.weight(.semibold))
          ForEach(inspection.links, id: \.id) { link in
            VStack(alignment: .leading, spacing: 4) {
              Text(link.label)
                .font(.caption)
                .foregroundStyle(.secondary)
              HStack {
                Button(link.destination ?? "Open destination") {
                  model.openLink(link)
                }
                if link.kind == .externalURL {
                  Image(systemName: link.isSafeExternal ? "lock.open" : "exclamationmark.shield")
                    .foregroundStyle(link.isSafeExternal ? .green : .red)
                }
              }
            }
          }
        }
      }
    }
  }

  private var metadataSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label("Document details", systemImage: "doc.on.doc")
        .font(.headline)

      DisclosureGroup("Metadata") {
        LabeledContent(
          "Title",
          value: inspection.metadata.title.isEmpty ? "Not declared" : inspection.metadata.title)
        LabeledContent(
          "Author",
          value: inspection.metadata.author.isEmpty ? "Not declared" : inspection.metadata.author)
        LabeledContent(
          "Producer",
          value: inspection.metadata.producer.isEmpty
            ? "Not declared" : inspection.metadata.producer)
        LabeledContent(
          "Creator",
          value: inspection.metadata.creator.isEmpty ? "Not declared" : inspection.metadata.creator)
      }

      DisclosureGroup("Permissions") {
        LabeledContent("Can print", value: inspection.permissions.canPrint ? "Yes" : "No")
        LabeledContent("Can copy text", value: inspection.permissions.canCopy ? "Yes" : "No")
        LabeledContent("Can modify", value: inspection.permissions.canModify ? "Yes" : "No")
        LabeledContent(
          "Can annotate", value: inspection.permissions.canAddAnnotations ? "Yes" : "No")
      }

      DisclosureGroup("Attachments") {
        if inspection.attachments.isEmpty {
          Text("No embedded attachments discovered in this lane.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          ForEach(inspection.attachments, id: \.self) { attachment in
            Text(attachment)
              .font(.caption)
          }
        }
      }

      DisclosureGroup("Accessibility and safety notes") {
        LabeledContent(
          "Tagged content",
          value: inspection.accessibility.hasTaggedContent ? "Observed" : "Unknown")
        LabeledContent(
          "Reading-order hints",
          value: inspection.accessibility.hasReadingOrder ? "Observed" : "Not guaranteed")
        ForEach(inspection.accessibility.notes, id: \.self) { note in
          Text(note)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  private var validationSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Export validation", systemImage: "checkmark.shield")
        .font(.headline)
      if let report = model.exportReport {
        Text(
          report.status.rawValue.replacingOccurrences(
            of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression
          ).capitalized
        )
        .foregroundStyle(report.status == .failed ? .red : .green)
        ForEach(report.messages, id: \.self) { message in
          Text(message)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      } else {
        Text(
          "Export creates a new copy, reopens it, and checks geometry, fields, text, and applied edits."
        )
        .font(.callout)
        .foregroundStyle(.secondary)
      }
    }
  }
}

private struct PDFPresentationHighlight {
  enum Kind {
    case candidate
    case field
    case search
  }

  let kind: Kind
  let page: PDFPage
  let bounds: CGRect
}

private final class PDFPresentationOverlayView: NSView {
  var highlights: [PDFPresentationHighlight] = [] {
    didSet { needsDisplay = true }
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    nil
  }

  override func draw(_ dirtyRect: NSRect) {
    guard let pdfView = superview as? PDFView else { return }

    for highlight in highlights {
      let pdfViewBounds = pdfView.convert(highlight.bounds, from: highlight.page)
      let overlayBounds = convert(pdfViewBounds, from: pdfView)
      guard overlayBounds.intersects(dirtyRect) else { continue }

      let fillColor: NSColor
      let strokeColor: NSColor
      switch highlight.kind {
      case .candidate:
        fillColor = NSColor.systemBlue.withAlphaComponent(0.18)
        strokeColor = NSColor.controlAccentColor
      case .field:
        fillColor = NSColor.systemGreen.withAlphaComponent(0.16)
        strokeColor = NSColor.systemGreen
      case .search:
        fillColor = NSColor.systemYellow.withAlphaComponent(0.28)
        strokeColor = NSColor.systemOrange
      }

      fillColor.setFill()
      strokeColor.setStroke()
      let path = NSBezierPath(
        roundedRect: overlayBounds,
        xRadius: 3,
        yRadius: 3
      )
      path.lineWidth = 2
      path.fill()
      path.stroke()
    }
  }
}

private final class InteractivePDFView: PDFView {
  var isManualPlacementMode = false
  var onManualPlacement: ((Int, CGPoint) -> Void)?
  var onDirectEdit: ((Int, CGPoint) -> Void)?
  var requestedScaleMode: ReaderScaleMode = .fitWidth
  var requestedRowWidth: CGFloat = 612
  var requestedZoom: CGFloat = 1

  override var acceptsFirstResponder: Bool { true }

  override func becomeFirstResponder() -> Bool {
    true
  }

  override func layout() {
    super.layout()
    applyRequestedScale()
  }

  func applyRequestedScale() {
    guard bounds.width > 0 else { return }
    switch requestedScaleMode {
    case .fitWidth:
      let availableWidth = max(240, bounds.width - 28)
      scaleFactor = min(3.0, max(0.25, availableWidth / requestedRowWidth))
    case .fitPage:
      scaleFactor = scaleFactorForSizeToFit * 0.95
    case .zoom:
      scaleFactor = requestedZoom
    }
  }

  override func mouseDown(with event: NSEvent) {
    window?.makeFirstResponder(self)
    guard let document,
      let page = page(for: convert(event.locationInWindow, from: nil), nearest: true)
    else {
      super.mouseDown(with: event)
      return
    }
    let viewPoint = convert(event.locationInWindow, from: nil)
    let pagePoint = convert(viewPoint, to: page)
    let pageIndex = document.index(for: page)
    if isManualPlacementMode {
      onManualPlacement?(pageIndex, pagePoint)
    } else if event.clickCount >= 2 {
      onDirectEdit?(pageIndex, pagePoint)
    } else {
      super.mouseDown(with: event)
    }
  }

  override func keyDown(with event: NSEvent) {
    guard isManualPlacementMode,
      event.keyCode == 36 || event.keyCode == 49,
      let document,
      let page = currentPage
    else {
      super.keyDown(with: event)
      return
    }

    let pageBounds = page.bounds(for: displayBox)
    onManualPlacement?(
      document.index(for: page),
      CGPoint(x: pageBounds.midX, y: pageBounds.midY)
    )
  }
}

private struct PDFKitView: NSViewRepresentable {
  let document: PDFDocument?
  let pageIndex: Int
  let viewMode: ReaderViewMode
  let scaleMode: ReaderScaleMode
  let zoom: Double
  let rotation: Int
  let selectedSearchMatch: SearchMatch?
  let selectedCandidate: RegionCandidate?
  let selectedField: NativeField?
  let isManualPlacementMode: Bool
  let onManualPlacement: (Int, CGPoint) -> Void
  let onDirectEdit: (Int, CGPoint) -> Void

  final class Coordinator {
    weak var sourceDocument: PDFDocument?
    var presentationDocument: PDFDocument?
    var presentationRotation: Int?
    weak var overlayView: PDFPresentationOverlayView?
    var lastNavigatedPageIndex: Int?
    var lastSearchSignature: String?
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  func makeNSView(context: Context) -> InteractivePDFView {
    let view = InteractivePDFView()
    view.autoScales = false
    view.displayMode = .singlePageContinuous
    view.displayBox = .cropBox
    view.backgroundColor = .windowBackgroundColor
    view.onManualPlacement = onManualPlacement
    view.onDirectEdit = onDirectEdit

    let overlayView = PDFPresentationOverlayView(frame: view.bounds)
    overlayView.autoresizingMask = [.width, .height]
    overlayView.wantsLayer = true
    view.addSubview(overlayView)
    context.coordinator.overlayView = overlayView
    return view
  }

  func updateNSView(_ view: InteractivePDFView, context: Context) {
    if context.coordinator.sourceDocument !== document
      || context.coordinator.presentationRotation != rotation
    {
      context.coordinator.sourceDocument = document
      context.coordinator.presentationRotation = rotation
      context.coordinator.lastNavigatedPageIndex = nil
      context.coordinator.lastSearchSignature = nil

      if let document,
        let presentationDocument = document.copy() as? PDFDocument
      {
        for pageNumber in 0..<presentationDocument.pageCount {
          presentationDocument.page(at: pageNumber)?.rotation = rotation
        }
        context.coordinator.presentationDocument = presentationDocument
        view.document = presentationDocument
      } else {
        context.coordinator.presentationDocument = document
        view.document = document
      }
    } else if view.document !== context.coordinator.presentationDocument {
      view.document = context.coordinator.presentationDocument
    }

    view.isManualPlacementMode = isManualPlacementMode
    view.onManualPlacement = onManualPlacement
    view.onDirectEdit = onDirectEdit
    view.needsLayout = true
    view.layoutSubtreeIfNeeded()

    switch viewMode {
    case .singlePage:
      view.displayMode = .singlePage
    case .continuous:
      view.displayMode = .singlePageContinuous
    case .twoPage:
      view.displayMode = .twoUp
    }

    view.autoScales = false
    let pageWidth = document?.page(at: pageIndex)?.bounds(for: .cropBox).width ?? 612
    view.requestedScaleMode = scaleMode
    view.requestedRowWidth = viewMode == .twoPage ? pageWidth * 2 + 18 : pageWidth
    view.requestedZoom = CGFloat(zoom)
    view.applyRequestedScale()

    var highlights: [PDFPresentationHighlight] = []
    if let selectedCandidate,
      let page = view.document?.page(at: selectedCandidate.pageIndex)
    {
      highlights.append(
        PDFPresentationHighlight(
          kind: .candidate,
          page: page,
          bounds: selectedCandidate.bounds.cgRect
        )
      )
    } else if let selectedField,
      let page = view.document?.page(at: selectedField.pageIndex)
    {
      highlights.append(
        PDFPresentationHighlight(
          kind: .field,
          page: page,
          bounds: selectedField.bounds.cgRect
        )
      )
    }

    if let document = view.document {
      if context.coordinator.lastNavigatedPageIndex != pageIndex,
        let page = document.page(at: pageIndex)
      {
        view.go(to: page)
        context.coordinator.lastNavigatedPageIndex = pageIndex
      }

      if let selectedSearchMatch,
        let selection = document.findString(
          selectedSearchMatch.query, withOptions: [.caseInsensitive]
        )
        .first(where: {
          $0.pages.contains(where: { $0 === document.page(at: selectedSearchMatch.pageIndex) })
        })
      {
        let signature = "\(selectedSearchMatch.query)|\(selectedSearchMatch.pageIndex)"
        if context.coordinator.lastSearchSignature != signature {
          view.setCurrentSelection(selection, animate: true)
          context.coordinator.lastSearchSignature = signature
        }
        if let page = document.page(at: selectedSearchMatch.pageIndex) {
          highlights.append(
            PDFPresentationHighlight(
              kind: .search,
              page: page,
              bounds: selection.bounds(for: page)
            )
          )
        }
      } else {
        if context.coordinator.lastSearchSignature != nil {
          view.currentSelection = nil
          context.coordinator.lastSearchSignature = nil
        }
      }
    } else {
      context.coordinator.lastNavigatedPageIndex = nil
      context.coordinator.lastSearchSignature = nil
    }

    context.coordinator.overlayView?.highlights = highlights
  }

}

struct SettingsView: View {
  var body: some View {
    Form {
      Section {
        LabeledContent("Processing", value: "On this Mac")
        LabeledContent("Source files", value: "Never overwritten")
        LabeledContent("Provider", value: "PDFKit evaluation lane")
      } header: {
        Text("Safety")
      } footer: {
        Text("Provider adoption remains subject to the native/web parity and provider gates.")
      }
    }
    .formStyle(.grouped)
    .scenePadding()
    .frame(width: 420)
  }
}

private struct NewProfileButton: View {
  let onCreate: (String) -> Void
  @State private var isPresented = false
  @State private var name = ""

  var body: some View {
    Button {
      isPresented = true
    } label: {
      Label("New Profile", systemImage: "plus")
        .font(.subheadline)
    }
    .sheet(isPresented: $isPresented) {
      VStack(spacing: 16) {
        Text("Create Profile")
          .font(.headline)
        TextField("Profile name", text: $name)
          .textFieldStyle(.roundedBorder)
          .frame(width: 240)
        HStack {
          Button("Cancel") { isPresented = false }
          Button("Create") {
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
              onCreate(trimmed)
              isPresented = false
              name = ""
            }
          }
          .buttonStyle(.borderedProminent)
          .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
      }
      .padding(24)
    }
  }
}
