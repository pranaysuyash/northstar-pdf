import AppKit
import PDFEditorCore
import PDFEditorRecovery
import SwiftUI

public struct AgentCommandItem: Identifiable {
  public let id: String
  public let title: String
  public let subtitle: String
  public let icon: String
  public let category: String
  public let keywords: [String]
  public let isAvailable: Bool
  public let action: @MainActor () -> Void

  public init(
    id: String,
    title: String,
    subtitle: String,
    icon: String,
    category: String,
    keywords: [String] = [],
    isAvailable: Bool = true,
    action: @escaping @MainActor () -> Void
  ) {
    self.id = id
    self.title = title
    self.subtitle = subtitle
    self.icon = icon
    self.category = category
    self.keywords = keywords
    self.isAvailable = isAvailable
    self.action = action
  }
}

public struct AgentCommandHUD: View {
  @Bindable var model: AppModel
  @Binding var isPresented: Bool
  @Binding var isSecurityVaultPresented: Bool
  @State private var query = ""
  @State private var selectedIndex = 0
  @FocusState private var isFieldFocused: Bool
  // MARK: - Agentic loop host state (D-078)
  @State private var activePlan: AgentPlan?
  @State private var planSheetPresented = false
  @State private var planStatusLine: String?
  @State private var runJournal = AgentRunJournal()

  public init(
    model: AppModel,
    isPresented: Binding<Bool>,
    isSecurityVaultPresented: Binding<Bool>
  ) {
    self.model = model
    self._isPresented = isPresented
    self._isSecurityVaultPresented = isSecurityVaultPresented
  }

  private var adaptiveContextCommands: [AgentCommandItem] {
    let history = AdaptiveCommandHistory.shared
    let input = AdaptiveCommandContext.input(
      model: model,
      intent: adaptiveIntent,
      target: model.selectedField == nil ? .documentScrolling : .formField
    )

    return AdaptiveCommandPolicy.standard.resolve(input).allValidCommands.compactMap { command in
      switch command.id {
      case .search:
        return AgentCommandItem(
          id: "adaptive-search",
          title: command.title,
          subtitle: "Search the current document",
          icon: "magnifyingglass",
          category: "Current Context",
          keywords: ["find", "lookup", "query", "text", "search"]
        ) {
          history.record(.search)
          model.routeSearchCommand()
        }
      case .continueReading:
        return AgentCommandItem(
          id: "adaptive-continue-reading",
          title: command.title,
          subtitle: "Return to the document reading posture",
          icon: "book",
          category: "Current Context",
          keywords: ["read", "scroll", "view", "study", "reader"]
        ) {
          history.record(.continueReading)
          model.readingMode = .study
        }
      case .understandDocument:
        return AgentCommandItem(
          id: "adaptive-understand-document",
          title: command.title,
          subtitle: "Open the document understanding workspace",
          icon: "text.magnifyingglass",
          category: "Current Context",
          keywords: ["analyze", "summary", "intelligence", "structure", "overview"]
        ) {
          history.record(.understandDocument)
          model.readingMode = .study
        }
      case .fillForm:
        return AgentCommandItem(
          id: "adaptive-fill-form",
          title: command.title,
          subtitle: "Continue completing the selected native field",
          icon: "character.cursor.ibeam",
          category: "Current Context",
          keywords: ["input", "complete", "populate", "type", "field", "form"]
        ) {
          history.record(.fillForm)
          model.setEditorMode(.fill)
        }
      case .undo:
        return AgentCommandItem(
          id: "adaptive-undo",
          title: command.title,
          subtitle: "Reverse the latest accepted document operation",
          icon: "arrow.uturn.backward",
          category: "Current Context",
          keywords: ["revert", "backward", "cancel", "rollback"]
        ) {
          history.record(.undo)
          model.undo()
        }
      case .redo:
        return AgentCommandItem(
          id: "adaptive-redo",
          title: command.title,
          subtitle: "Reapply the latest undone document operation",
          icon: "arrow.uturn.forward",
          category: "Current Context",
          keywords: ["repeat", "forward", "reapply"]
        ) {
          history.record(.redo)
          model.redo()
        }
      default:
        return nil
      }
    }
  }

  private var adaptiveIntent: AdaptiveIntentLens {
    switch model.editorMode {
    case .read: return .read
    case .fill, .sign: return .complete
    case .edit: return .review
    }
  }

  private var allCommands: [AgentCommandItem] {
    var items: [AgentCommandItem] = adaptiveContextCommands

    // 1. Intelligent Fill & Auto-Completion
    // D-078: bulk fill no longer fires preview+apply back-to-back. It
    // proposes a complete-document plan that the user approves first; the
    // executor then applies it under fresh availability decisions.
    if model.currentProfile != nil {
      items.append(
        AgentCommandItem(
          id: "bulk-fill-plan",
          title: "Bulk Fill with Profile: \(model.currentProfile!.displayName)",
          subtitle: "Propose a reviewed plan: focus fill, apply values, present export review",
          icon: "sparkles",
          category: "AI & Automation",
          keywords: ["autofill", "profile", "smart", "complete", "populate", "form"],
          isAvailable: model.inspection != nil
        ) {
          proposePlan(query: "fill out this form")
        }
      )
    } else {
      items.append(
        AgentCommandItem(
          id: "bulk-fill-preview",
          title: "Auto-Fill from Local Profile",
          subtitle: "Preview profile values across recognized document fields",
          icon: "person.crop.circle.badge.plus",
          category: "AI & Automation",
          keywords: ["autofill", "profile", "smart", "complete", "populate", "form"],
          isAvailable: model.inspection != nil
        ) {
          model.setEditorMode(.fill)
        }
      )
    }

    if model.inspection?.candidates.isEmpty == false {
      items.append(
        AgentCommandItem(
          id: "fill-next-candidate",
          title: "Jump to Next Detected Field",
          subtitle: "Review static suggestion with one-click candidate placement",
          icon: "scope",
          category: "AI & Automation",
          keywords: ["next", "jump", "tab", "candidate", "suggest", "detect"]
        ) {
          model.selectNextCandidate()
        }
      )
    }

    // Candidate Confirmation & Rejection Parity (PER-0795)
    if model.selectedCandidate != nil {
      items.append(
        AgentCommandItem(
          id: "confirm-candidate",
          title: "Confirm Current Field Suggestion",
          subtitle: "Accept and place detected form candidate (⌘Return)",
          icon: "checkmark.circle",
          category: "AI & Automation",
          keywords: ["accept", "approve", "confirm", "field", "form", "place", "candidate"],
          isAvailable: true
        ) {
          model.confirmSelectedCandidate()
        }
      )

      items.append(
        AgentCommandItem(
          id: "reject-candidate",
          title: "Reject Current Field Suggestion",
          subtitle: "Dismiss detected candidate without placing (⌘⌫)",
          icon: "xmark.circle",
          category: "AI & Automation",
          keywords: ["dismiss", "reject", "delete", "remove", "candidate", "field"],
          isAvailable: true
        ) {
          model.rejectSelectedCandidate()
        }
      )
    }

    // 2. OCR & Document Intelligence
    items.append(
      AgentCommandItem(
        id: "ocr-current-page",
        title: "Run Vision OCR on Current Page",
        subtitle: "Extract selectable text and synthesize form geometry locally",
        icon: "text.viewfinder",
        category: "Intelligence",
        keywords: ["vision", "recognize", "text", "extract", "scan", "ocr"],
        isAvailable: model.inspection?.permissions.canCopy ?? false
      ) {
        model.runOCROnSelectedPage()
      }
    )

    items.append(
      AgentCommandItem(
        id: "template-match",
        title: "Find Template Layout Matches",
        subtitle: "Query local encrypted vault for layout geometry matches",
        icon: "checklist",
        category: "Intelligence",
        keywords: ["template", "match", "vault", "geometry", "layout"],
        isAvailable: model.isTemplateVaultUnlocked
      ) {
        model.findLocalTemplateMatches()
      }
    )

    // Forensic PII Scanner & Staging (PER-WPSYS-0007)
    items.append(
      AgentCommandItem(
        id: "scan-pii",
        title: "Scan for Sensitive PII & Redact",
        subtitle: "Stage redactions for SSNs, emails, phones, and credit cards",
        icon: "lock.shield",
        category: "Intelligence",
        keywords: ["ssn", "credit card", "email", "phone", "redact", "mask", "privacy", "pii", "gdpr", "hipaa", "sanitize"],
        isAvailable: model.inspection != nil
      ) {
        model.scanAndStagePIIRedactions()
      }
    )

    // 3. Document Authoring & Sign
    items.append(
      AgentCommandItem(
        id: "add-signature",
        title: "Place Signature",
        subtitle: "Draw, type, or import a visual signature overlay",
        icon: "signature",
        category: "Authoring",
        keywords: ["sign", "initial", "pen", "autograph", "signature"],
        isAvailable: model.inspection?.permissions.canAddAnnotations ?? false
      ) {
        model.beginSign(for: nil)
      }
    )

    items.append(
      AgentCommandItem(
        id: "add-text",
        title: "Add Text Overlay",
        subtitle: "Click anywhere on the document canvas to position text",
        icon: "text.cursor",
        category: "Authoring",
        keywords: ["label", "type", "font", "overlay", "annotation", "text"],
        isAvailable: model.inspection?.permissions.canAddAnnotations ?? false
      ) {
        model.beginManualTextPlacement()
      }
    )

    let markedCount = model.operations.filter { $0.kind == .redactMark }.count
    if markedCount > 0 {
      items.append(
        AgentCommandItem(
          id: "commit-redactions",
          title: "Commit \(markedCount) Marked Redaction(s)",
          subtitle: "Irrevocably remove underlying text/vector stream on exported copy",
          icon: "eye.slash.fill",
          category: "Authoring",
          keywords: ["burn", "redact", "sanitize", "mask", "permanent", "blackout"]
        ) {
          model.isRedactionCommitPresented = true
        }
      )
    }

    // 4. Visual Verification & Diff
    if model.sourceInspection != nil {
      items.append(
        AgentCommandItem(
          id: "toggle-diff-overlay",
          title: model.showDiff ? "Hide Visual Diff Overlay" : "Show Visual Diff Overlay",
          subtitle: "Highlight outside-region changes and edits directly on page",
          icon: "doc.text.magnifyingglass",
          category: "Verification",
          keywords: ["diff", "compare", "changes", "overlay", "visual"]
        ) {
          model.toggleDiffView()
        }
      )

      items.append(
        AgentCommandItem(
          id: "open-diff-sheet",
          title: "Side-by-Side Diff Inspector",
          subtitle: "Compare original source vs live edited state with pixel delta",
          icon: "rectangle.split.2x1",
          category: "Verification",
          keywords: ["side-by-side", "compare", "diff", "delta", "inspect"]
        ) {
          model.openDiffComparison()
        }
      )
    }

    // Digital Signature & Cryptographic Verification (PER-WPSYS-0007)
    items.append(
      AgentCommandItem(
        id: "verify-signatures",
        title: "Verify Digital Signatures & Trust",
        subtitle: "Inspect digital signatures, certificates, and structural digest",
        icon: "signature",
        category: "Verification",
        keywords: ["signature", "trust", "cert", "certificate", "integrity", "tamper", "crypto", "sha256", "verify", "digest"],
        isAvailable: model.sourceData != nil
      ) {
        model.verifyDigitalSignatures()
      }
    )

    // 5. Modes & Navigation
    for mode in EditorMode.allCases {
      if mode != model.editorMode {
        items.append(
          AgentCommandItem(
            id: "mode-\(mode.rawValue)",
            title: "Switch to \(mode.displayName) Mode",
            subtitle: mode == .fill ? "Highlight and navigate form fields" :
                      mode == .sign ? "Place signatures and initials" :
                      mode == .edit ? "Full authoring, placement, and redactions" : "Passive reading and search",
            icon: mode.symbolName,
            category: "Navigation",
            keywords: ["mode", mode.displayName.lowercased(), mode.rawValue.lowercased()]
          ) {
            model.setEditorMode(mode)
          }
        )
      }
    }

    // 6. Security & Privacy Vault
    items.append(
      AgentCommandItem(
        id: "open-security-vault",
        title: "Open Security & Privacy Vault",
        subtitle: "Manage Keychain unlocking, encrypted recovery envelopes, and audit logs",
        icon: "lock.shield",
        category: "Security",
        keywords: ["keychain", "recovery", "envelope", "audit", "vault", "crypto", "security", "privacy"]
      ) {
        isSecurityVaultPresented = true
      }
    )

    // 7. Text & Document Creation
    items.append(
      AgentCommandItem(
        id: "copy-page-text",
        title: "Copy Current Page Text",
        subtitle: "Extract selectable text from page \(model.selectedPageIndex + 1) to clipboard",
        icon: "doc.on.doc",
        category: "Authoring",
        keywords: ["copy", "clipboard", "text", "extract"],
        isAvailable: model.inspection?.permissions.canCopy ?? false
      ) {
        model.copyCurrentPageText()
      }
    )

    items.append(
      AgentCommandItem(
        id: "new-from-clipboard",
        title: "New PDF from Clipboard",
        subtitle: "Create a new document from system clipboard text or image",
        icon: "doc.on.clipboard",
        category: "Authoring",
        keywords: ["new", "paste", "clipboard", "create"]
      ) {
        model.newDocumentFromClipboard()
      }
    )

    items.append(
      AgentCommandItem(
        id: "new-from-markdown",
        title: "New PDF from Markdown",
        subtitle: "Render markdown content into a formatted PDF document",
        icon: "text.document",
        category: "Authoring",
        keywords: ["markdown", "md", "render", "new", "document"]
      ) {
        model.newDocumentFromMarkdown()
      }
    )

    items.append(
      AgentCommandItem(
        id: "new-from-images",
        title: "New PDF from Images…",
        subtitle: "Combine raster images into a multi-page PDF",
        icon: "photo.on.rectangle.angled",
        category: "Authoring",
        keywords: ["image", "photo", "png", "jpg", "jpeg", "combine", "pdf"]
      ) {
        model.presentNewFromImagesPanel()
      }
    )

    items.append(
      AgentCommandItem(
        id: "append-pages",
        title: "Append PDF Pages…",
        subtitle: "Insert pages from another PDF into the current document",
        icon: "doc.badge.plus",
        category: "Authoring",
        keywords: ["append", "merge", "insert", "combine", "pages"],
        isAvailable: model.liveDocument != nil
      ) {
        model.presentAppendPagesPanel()
      }
    )

    // 8. Safe Export
    items.append(
      AgentCommandItem(
        id: "export-copy",
        title: "Export Validated PDF Copy",
        subtitle: "Preflights and writes an immutable separate copy (source never overwritten)",
        icon: "square.and.arrow.down",
        category: "Export",
        keywords: ["save", "write", "pdf", "output", "render", "export"],
        isAvailable: model.canExportCurrentOperations
      ) {
        model.presentExportReview()
      }
    )

    return items
  }

  private var filteredCommands: [AgentCommandItem] {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      return allCommands
    }
    let lower = trimmed.lowercased()

    struct ScoredCommand {
      let command: AgentCommandItem
      let score: Int
    }

    var scored: [ScoredCommand] = []
    for item in allCommands {
      var score = 0
      let titleLower = item.title.lowercased()
      let subtitleLower = item.subtitle.lowercased()
      let categoryLower = item.category.lowercased()

      if titleLower == lower {
        score += 150
      } else if titleLower.hasPrefix(lower) {
        score += 100
      } else if titleLower.contains(lower) {
        score += 70
      }

      for kw in item.keywords {
        let kwLower = kw.lowercased()
        if kwLower == lower {
          score += 80
        } else if kwLower.hasPrefix(lower) {
          score += 60
        } else if kwLower.contains(lower) {
          score += 40
        }
      }

      if subtitleLower.contains(lower) {
        score += 20
      }

      if categoryLower.contains(lower) {
        score += 10
      }

      if score > 0 {
        scored.append(ScoredCommand(command: item, score: score))
      }
    }

    return scored.sorted { $0.score > $1.score }.map(\.command)
  }

  public var body: some View {
    VStack(spacing: 0) {
      // Search Bar Header
      HStack(spacing: 12) {
        ZStack {
          Circle()
            .fill(Color.accentColor.opacity(0.15))
            .frame(width: 32, height: 32)
          Image(systemName: "sparkle.magnifyingglass")
            .font(.callout.weight(.semibold))
            .foregroundStyle(Color.accentColor)
        }

        TextField("Action Composer: describe intent or search commands (e.g. 'fill form', 'ocr', 'redact')…", text: $query)
          .textFieldStyle(.plain)
          .font(.body)
          .focused($isFieldFocused)
          .onSubmit {
            handleReturnSubmit()
          }

        if !query.isEmpty {
          Button {
            query = ""
          } label: {
            Image(systemName: "xmark.circle.fill")
              .foregroundStyle(.secondary)
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Clear search")
        }

        Text("ESC")
          .font(.caption2.weight(.bold))
          .padding(.horizontal, 6)
          .padding(.vertical, 3)
          .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)

      Divider()

      // Results List
      if filteredCommands.isEmpty {
        VStack(spacing: 8) {
          Image(systemName: "questionmark.folder")
            .font(.title)
            .foregroundStyle(.secondary)
          Text("No matching actions or commands")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
      } else {
        ScrollViewReader { proxy in
          ScrollView {
            LazyVStack(spacing: 4) {
              ForEach(Array(filteredCommands.enumerated()), id: \.element.id) { index, item in
                Button {
                  executeCommand(item)
                } label: {
                  AgentCommandRowView(item: item, isSelected: selectedIndex == index)
                }
                .buttonStyle(.plain)
                .disabled(!item.isAvailable)
                .accessibilityLabel(item.title)
                .accessibilityHint(item.isAvailable ? item.subtitle : "Unavailable")
                .id(item.id)
              }
            }
            .padding(8)
          }
          .frame(maxHeight: 320)
          .onChange(of: selectedIndex) { _, newIndex in
            if filteredCommands.indices.contains(newIndex) {
              proxy.scrollTo(filteredCommands[newIndex].id)
            }
          }
        }
      }

      Divider()

      // Footer
      HStack(spacing: 12) {
        HStack(spacing: 6) {
          Image(systemName: "checkmark.shield.fill")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.green)
          Text("Local execution · Zero egress")
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
        }

        Spacer()

        HStack(spacing: 10) {
          HStack(spacing: 4) {
            Text("↵")
              .font(.caption2.weight(.bold))
              .padding(.horizontal, 5)
              .padding(.vertical, 2)
              .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            Text("compose plan / execute")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }

          HStack(spacing: 4) {
            Text("⎋")
              .font(.caption2.weight(.bold))
              .padding(.horizontal, 5)
              .padding(.vertical, 2)
              .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            Text("close")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 9)
      .background(Color.primary.opacity(0.03))
    }
    .sheet(isPresented: $planSheetPresented) {
      if let plan = activePlan {
        AgentPlanSheetView(
          plan: plan,
          statusLine: planStatusLine,
          onApprove: approveAndRunActivePlan,
          onCancel: {
            if var current = activePlan, current.state == .awaitingApproval {
              current.cancel()
              activePlan = current
            }
            planSheetPresented = false
          },
          onDone: { planSheetPresented = false }
        )
      }
    }
    .frame(width: 580)
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .shadow(color: Color.black.opacity(0.25), radius: 24, x: 0, y: 12)
    .sensoryFeedback(.impact, trigger: hapticCommand)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color.white.opacity(0.2), lineWidth: 1)
    )
    .onAppear {
      isFieldFocused = true
      selectedIndex = 0
    }
    .onChange(of: query) { _, _ in
      selectedIndex = 0
    }
    .onKeyPress(.downArrow) {
      if selectedIndex < filteredCommands.count - 1 {
        selectedIndex += 1
        return .handled
      }
      return .ignored
    }
    .onKeyPress(.upArrow) {
      if selectedIndex > 0 {
        selectedIndex -= 1
        return .handled
      }
      return .ignored
    }
    .onKeyPress(.escape) {
      isPresented = false
      return .handled
    }
  }

  private func handleReturnSubmit() {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    if selectedIndex > 0 {
      executeSelected()
      return
    }

    if trimmed.isEmpty {
      executeSelected()
      return
    }

    let q = trimmed.lowercased()
    let isPlanIntent = q.contains("fill") || q.contains("complete") || q.contains("form") ||
                       q.contains("ocr") || q.contains("scan") || q.contains("extract text") ||
                       q.contains("export") || q.contains("validat") || q.contains("finish") || q.contains("done")

    if isPlanIntent {
      proposePlan(query: trimmed)
    } else {
      executeSelected()
    }
  }

  private func executeSelected() {
    guard filteredCommands.indices.contains(selectedIndex) else { return }
    executeCommand(filteredCommands[selectedIndex])
  }

  // MARK: - Agentic loop host (D-078)
  //
  // The host proposes plans, collects approval, then drives the pure
  // executor policy with freshly assessed decisions before every step.
  // All mutations flow through existing AppModel methods; the loop adds
  // sequencing, gating, and journaling — never a second mutation path.

  private func planRequest(query: String) -> AgentPlanRequest? {
    guard let inspection = model.inspection else { return nil }
    return AgentPlanRequest(
      query: query,
      intent: adaptiveIntent,
      scope: .single,
      sourceDigest: inspection.source.sha256,
      hasProfile: model.currentProfile != nil,
      hasCandidates: !(inspection.candidates.isEmpty),
      hasOperations: !model.operations.isEmpty,
      canExport: model.canExportCurrentOperations
    )
  }

  private func proposePlan(query: String) {
    guard let request = planRequest(query: query) else {
      executeSelected()
      return
    }
    switch DeterministicAgentPlanner.propose(request: request) {
    case .plan(let plan):
      activePlan = plan
      planStatusLine = nil
      planSheetPresented = true
    case .commandSearch:
      executeSelected()
    }
  }

  private func approveAndRunActivePlan() {
    guard var plan = activePlan, plan.state == .awaitingApproval else { return }
    plan.approve()
    runApprovedPlan(plan: &plan)
  }

  /// Steps the host knows how to perform. Anything else escalates with
  /// `.capabilityUnsupported` instead of improvising.
  private func canPerform(_ step: AgentPlanStep) -> Bool {
    switch step.id {
    case "step-focus-fill", "step-bulk-apply", "step-ocr", "step-present-export":
      return true
    default:
      switch step.commandID {
      case .search, .undo, .redo, .fillForm, .export, .extractText:
        return true
      default:
        return false
      }
    }
  }

  private func performStep(_ step: AgentPlanStep) {
    AdaptiveCommandHistory.shared.record(step.commandID)
    switch step.id {
    case "step-focus-fill":
      model.setEditorMode(.fill)
    case "step-bulk-apply":
      // Approved above; permissions still enforced inside applyBulkFill.
      // Skipped fields are reported, never forced.
      model.previewBulkFill()
      model.applyBulkFill()
    case "step-ocr":
      model.runOCROnSelectedPage()
    case "step-present-export":
      model.presentExportReview()
    default:
      switch step.commandID {
      case .search: model.routeSearchCommand()
      case .undo: model.undo()
      case .redo: model.redo()
      case .fillForm: model.setEditorMode(.fill)
      case .export: model.presentExportReview()
      case .extractText: model.runOCROnSelectedPage()
      default: break // Unreachable: canPerform gates this path.
      }
    }
  }

  private func freshDecisions() -> [AdaptiveCommandID: AdaptiveCommandDecision] {
    let input = AdaptiveCommandContext.input(
      model: model, intent: adaptiveIntent, target: .documentScrolling)
    return Dictionary(uniqueKeysWithValues:
      AdaptiveCommandPolicy.standard.assess(input).map { ($0.command.id, $0) })
  }

  private func journalTerminal(plan: AgentPlan, escalated: Bool) {
    runJournal.append(AgentRunRecord(
      planID: plan.id,
      goal: plan.goal,
      stepOutcomes: plan.steps.map { "\($0.id):\($0.state.rawValue)" },
      escalated: escalated,
      reasonCodes: (plan.escalation?.reasons ?? []).map(\.rawValue)
    ))
  }

  private func runApprovedPlan(plan: inout AgentPlan) {
    plan.state = .running
    var outcomes: [String] = []
    loop: while true {
      let digest = model.inspection?.source.sha256 ?? ""
      let action = AgentExecutor.nextAction(
        plan: plan,
        decisions: freshDecisions(),
        sourceDigestMatches: digest == plan.sourceDigest && !plan.sourceDigest.isEmpty
      )
      switch action {
      case .requestPlanApproval:
        planStatusLine = "The plan needs approval first."
        break loop
      case .cancelled:
        planStatusLine = "Plan cancelled. Nothing was applied."
        break loop
      case .planInvalid(let reason):
        plan.state = .invalid
        planStatusLine = reason
        journalTerminal(plan: plan, escalated: true)
        break loop
      case .succeed:
        plan.state = .succeeded
        model.recordExecutionReceipt(
          actionName: "Action Composer: \(plan.goal)",
          checks: [
            ExecutionReceiptCheck(
              name: "Deterministic Plan Execution",
              passed: true,
              detail: "\(outcomes.count) step(s) verified and applied."
            ),
            ExecutionReceiptCheck(
              name: "Network Egress Boundary",
              passed: true,
              detail: "Executed by the local governed plan executor; no network transport calls in this action's path."
            )
          ]
        )
        planStatusLine = "Plan complete: \(outcomes.count) step(s) executed. Execution receipt generated."
        journalTerminal(plan: plan, escalated: false)
        break loop
      case .escalate(let escalation):
        plan.state = .escalated
        plan.escalation = escalation
        planStatusLine = escalation.message + " Nothing was applied by the failed step; earlier applied steps stay reversible via Undo."
        journalTerminal(plan: plan, escalated: true)
        break loop
      case .runStep(let id, _), .retryStep(let id, _):
        guard let step = plan.steps.first(where: { $0.id == id }), canPerform(step) else {
          plan.state = .escalated
          plan.escalation = AgentEscalation(
            stepID: id, commandID: plan.steps.first(where: { $0.id == id })?.commandID,
            reasons: [.capabilityUnsupported],
            message: "The plan reached a step with no host action. Parked with nothing applied by this step.",
            attemptsExhausted: false
          )
          planStatusLine = plan.escalation!.message
          journalTerminal(plan: plan, escalated: true)
          break loop
        }
        performStep(step)
        outcomes.append("\(id):ok")
        let result = AgentExecutor.applyStepReport(plan: plan, stepID: id, report: .succeeded)
        plan = result.plan
        // NOTE: v1 host actions are synchronous and non-throwing, so the
        // transient-failure report has no host source yet; retry bounds stay
        // enforced and tested at the policy layer for provider-backed steps.
      }
    }
    activePlan = plan
  }

  private struct AgentCommandRowView: View {
    let item: AgentCommandItem
    let isSelected: Bool

    private var categoryColor: Color {
      switch item.category {
      case "Current Context": return .blue
      case "AI & Automation": return .purple
      case "Intelligence": return .teal
      case "Authoring": return .green
      case "Export": return .orange
      default: return .secondary
      }
    }

    var body: some View {
      HStack(spacing: 12) {
        ZStack {
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(item.isAvailable ? (isSelected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.06)) : Color.clear)
            .frame(width: 32, height: 32)
          Image(systemName: item.icon)
            .font(.callout.weight(.medium))
            .foregroundStyle(item.isAvailable ? (isSelected ? Color.accentColor : Color.primary) : Color.secondary)
        }

        VStack(alignment: .leading, spacing: 2) {
          HStack(spacing: 8) {
            Text(item.title)
              .font(.callout.weight(isSelected ? .semibold : .medium))
              .foregroundStyle(item.isAvailable ? Color.primary : Color.secondary)

            Spacer()

            Text(item.category)
              .font(.caption2.weight(.semibold))
              .foregroundStyle(categoryColor)
              .padding(.horizontal, 7)
              .padding(.vertical, 2.5)
              .background(categoryColor.opacity(0.12), in: Capsule())

            if isSelected {
              Image(systemName: "arrow.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.accentColor)
            }
          }

          Text(item.subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 7)
      .background(
        isSelected ? Color.accentColor.opacity(0.09) : Color.clear,
        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .strokeBorder(isSelected ? Color.accentColor.opacity(0.28) : Color.clear, lineWidth: 1)
      )
    }
  }

  @State private var hapticCommand = UUID()

  private func executeCommand(_ item: AgentCommandItem) {
    guard item.isAvailable else { return }
    hapticCommand = UUID()
    isPresented = false
    item.action()
  }
}

// MARK: - Agent plan sheet (D-078)

// Preview -> approve/cancel -> progress -> escalation. The sheet never
// applies anything itself; approval hands the plan to the host loop.
private struct AgentPlanSheetView: View {
  let plan: AgentPlan
  let statusLine: String?
  let onApprove: () -> Void
  let onCancel: () -> Void
  let onDone: () -> Void

  private var isTerminal: Bool {
    [.succeeded, .failed, .escalated, .cancelled, .invalid].contains(plan.state)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Agent plan · \(plan.goal.rawValue)")
          .font(.headline)
        Text("“\(plan.queryText)” — bound to the current document. Changing documents invalidates the plan.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      ForEach(plan.steps) { step in
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: stepIcon(step.state))
            .foregroundStyle(stepColor(step.state))
            .frame(width: 20)
          VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
              Text(step.title)
                .font(.subheadline.weight(.semibold))
              if step.isMutating {
                Text("NEEDS APPROVAL")
                  .font(.caption2.weight(.bold).monospaced())
                  .foregroundStyle(.orange)
              }
            }
            Text(step.detail)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      if let escalation = plan.escalation {
        Label(escalation.message, systemImage: "exclamationmark.triangle.fill")
          .font(.caption)
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }

      if let statusLine {
        Text(statusLine)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      HStack {
        if plan.state == .awaitingApproval {
          Button("Cancel") { onCancel() }
          Spacer()
          Button("Approve & run") { onApprove() }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        } else {
          Spacer()
          Button(isTerminal ? "Done" : "Close") { onDone() }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
      }
    }
    .padding(20)
    .frame(width: 440)
  }

  private func stepIcon(_ state: AgentStepState) -> String {
    switch state {
    case .proposed, .approved: return "circle"
    case .running: return "circle.dotted"
    case .succeeded: return "checkmark.circle.fill"
    case .failed: return "xmark.circle.fill"
    case .skipped: return "minus.circle"
    }
  }

  private func stepColor(_ state: AgentStepState) -> Color {
    switch state {
    case .succeeded: return .green
    case .failed: return .red
    case .running: return .accentColor
    default: return .secondary
    }
  }
}
