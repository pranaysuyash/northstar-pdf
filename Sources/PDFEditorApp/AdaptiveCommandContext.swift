import PDFEditorCore
import PDFEditorRecovery

/// Native adapter from the document session to the framework-neutral adaptive
/// command policy. Every native command surface uses this mapping so a PDF does
/// not acquire different capabilities merely because the user opened a menu.
@MainActor
enum AdaptiveCommandContext {
  static func input(
    model: AppModel?,
    intent: AdaptiveIntentLens = .read,
    target: AdaptiveInteractionTarget = .documentScrolling
  ) -> AdaptiveCommandPolicyInput {
    guard let model else {
      return AdaptiveCommandPolicyInput(
        intent: intent,
        target: target,
        capabilities: .none
      )
    }

    let permissions = model.inspection?.permissions
    let canCopy = model.liveDocument != nil && (permissions?.canCopy ?? false)
    let canModify = permissions?.canModify ?? false
    let canAddAnnotations = permissions?.canAddAnnotations ?? false
    let history = AdaptiveCommandHistory.shared

    return AdaptiveCommandPolicyInput(
      intent: intent,
      target: target,
      capabilities: AdaptiveCapabilityFacts(
        canSearch: canCopy,
        canAnnotate: canAddAnnotations,
        canEditText: canModify,
        canFillFields: canModify,
        canExtract: canCopy,
        canExport: model.canExportCurrentOperations && (canModify || canAddAnnotations),
        canUndo: model.canUndo,
        canRedo: model.canRedo,
        canOrganizePages: canModify
      ),
      recentCommandIDs: history.isPersonalizationEnabled ? history.recentCommandIDs : [],
      pinnedCommandIDs: history.isPersonalizationEnabled ? history.pinnedCommandIDs : []
    )
  }
}
