import PDFEditorCore
import PDFEditorRecovery
import SwiftUI

/// COMMIT flow sheet: shows binding text, verifies integrity, records audit.
///
/// Replaces the basic "Add your signature" sheet with a structured signing flow:
/// 1. Show what you're binding to (document identity)
/// 2. Verify document integrity (pre-sign check)
/// 3. Sign (draw/type/image/saved)
/// 4. Record audit entry
struct CommitFlowSheet: View {
  @Bindable var model: AppModel
  @StateObject private var commitManager = CommitFlowManager()
  @State private var selectedTab = 0
  @State private var typedName = ""
  @State private var selectedFontIndex = 0

  private let scriptFonts = ["Zapfino", "Snell Roundhand", "Bradley Hand"]

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Header
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text("Sign Document")
            .font(.title3.weight(.semibold))
          Text("You are binding yourself to this document.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Button("Cancel") {
          commitManager.cancel()
          model.isSignatureSheetPresented = false
          model.pendingSignatureRegion = nil
        }
      }
      .padding([.horizontal, .top], 24)
      .padding(.bottom, 12)

      Divider()

      switch commitManager.state {
      case .verifying:
        verifyingView

      case .ready(let binding, let integrity):
        readyView(binding: binding, integrity: integrity)

      case .integrityWarning(let binding, let integrity):
        integrityWarningView(binding: binding, integrity: integrity)

      case .signing:
        signingView

      case .complete(let entry):
        completeView(entry: entry)
      }
    }
    .frame(width: 540)
    .onAppear {
      beginVerification()
    }
  }

  // MARK: - Verifying State

  private var verifyingView: some View {
    VStack(spacing: 16) {
      Spacer()
      ProgressView()
        .progressViewStyle(.circular)
      Text("Verifying document integrity...")
        .font(.caption)
        .foregroundStyle(.secondary)
      Spacer()
    }
    .frame(height: 300)
  }

  // MARK: - Ready State

  private func readyView(binding: CommitBindingInfo, integrity: CommitIntegrityCheck) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      // Binding info
      bindingInfoSection(binding: binding)

      Divider().padding(.vertical, 8)

      // Integrity status
      integritySection(integrity: integrity)

      Divider().padding(.vertical, 8)

      // Signer identity
      signerSection

      Divider().padding(.vertical, 8)

      // Signature method picker + sign button
      signatureMethodSection
    }
  }

  // MARK: - Integrity Warning State

  private func integrityWarningView(binding: CommitBindingInfo, integrity: CommitIntegrityCheck) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      // Binding info
      bindingInfoSection(binding: binding)

      Divider()

      // Warning banner
      HStack(spacing: 12) {
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.title2)
          .foregroundStyle(.orange)

        VStack(alignment: .leading, spacing: 4) {
          Text("Document Integrity Warning")
            .font(.headline)
          Text(integrity.statusMessage)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .padding(12)
      .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

      Text("The document may have been modified after a previous signature. Signing now may invalidate existing signatures.")
        .font(.caption)
        .foregroundStyle(.secondary)

      HStack {
        Button("Cancel") {
          commitManager.cancel()
          model.isSignatureSheetPresented = false
        }
        .buttonStyle(.bordered)

        Spacer()

        Button("I understand — proceed") {
          commitManager.acknowledgeWarning()
        }
        .buttonStyle(.borderedProminent)
        .tint(.orange)
      }
    }
    .padding(24)
  }

  // MARK: - Signing State

  private var signingView: some View {
    VStack(spacing: 16) {
      Spacer()
      ProgressView()
        .progressViewStyle(.circular)
      Text("Signing document...")
        .font(.caption)
        .foregroundStyle(.secondary)
      Spacer()
    }
    .frame(height: 300)
  }

  // MARK: - Complete State

  private func completeView(entry: CommitAuditEntry) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 12) {
        Image(systemName: "checkmark.circle.fill")
          .font(.title)
          .foregroundStyle(.green)
        VStack(alignment: .leading) {
          Text("Signed Successfully")
            .font(.headline)
          Text("Your signature has been placed and an audit entry has been recorded.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      Divider()

      // Audit entry summary
      VStack(alignment: .leading, spacing: 6) {
        Text("Audit Record")
          .font(.caption.weight(.semibold))
        Text(entry.summary)
          .font(.caption)
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
      }
      .padding(12)
      .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))

      Spacer()

      HStack {
        Spacer()
        Button("Done") {
          model.isSignatureSheetPresented = false
          model.pendingSignatureRegion = nil
        }
        .buttonStyle(.borderedProminent)
      }
    }
    .padding(24)
  }

  // MARK: - Sections

  private func bindingInfoSection(binding: CommitBindingInfo) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("What you're signing", systemImage: "doc.text")
        .font(.caption.weight(.semibold))

      VStack(alignment: .leading, spacing: 4) {
        LabeledContent("Document", value: binding.documentTitle.isEmpty ? binding.fileName : binding.documentTitle)
        LabeledContent("Author", value: binding.documentAuthor)
        LabeledContent("Pages", value: "\(binding.pageCount)")
        LabeledContent("Size", value: ByteCountFormatter.string(fromByteCount: Int64(binding.fileSize), countStyle: .file))
        LabeledContent("Hash", value: String(binding.documentHash.prefix(16)) + "...")
      }
      .font(.caption)
    }
    .padding(16)
    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
  }

  private func integritySection(integrity: CommitIntegrityCheck) -> some View {
    HStack(spacing: 12) {
      Image(systemName: integrity.isSafeToSign ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
        .foregroundStyle(integrity.isSafeToSign ? .green : .orange)

      VStack(alignment: .leading, spacing: 2) {
        Text("Document Integrity")
          .font(.caption.weight(.semibold))
        Text(integrity.statusMessage)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(12)
    .background(
      (integrity.isSafeToSign ? Color.green : Color.orange).opacity(0.08),
      in: RoundedRectangle(cornerRadius: 8)
    )
  }

  private var signerSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Your identity", systemImage: "person")
        .font(.caption.weight(.semibold))

      TextField("Your name (required for audit record)", text: $commitManager.signerName)
        .textFieldStyle(.roundedBorder)

      TextField("Reason for signing (optional)", text: $commitManager.signingReason)
        .textFieldStyle(.roundedBorder)
    }
    .padding(16)
    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
  }

  private var signatureMethodSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label("Signature method", systemImage: "pencil.and.ruler")
        .font(.caption.weight(.semibold))

      Picker("Method", selection: $selectedTab) {
        Text("Draw").tag(0)
        Text("Type").tag(1)
        Text("Image").tag(2)
        if !model.savedSignatures.isEmpty {
          Text("Saved").tag(3)
        }
      }
      .pickerStyle(.segmented)

      Group {
        if selectedTab == 0 {
          SignatureDrawTab(onApply: { commitSign($0, source: "drawn") })
        } else if selectedTab == 1 {
          SignatureTypeTab(
            typedName: $typedName,
            selectedFontIndex: $selectedFontIndex,
            fontNames: scriptFonts,
            onApply: { commitSign(renderTypedSignature(), source: "typed") }
          )
        } else if selectedTab == 2 {
          SignatureImageTab(onApply: { data, _ in commitSign(data, source: "image") })
        } else {
          SignatureSavedTab(
            signatures: model.savedSignatures,
            onApply: { sig in
              if let data = sig.signatureImageData {
                commitSign(data, source: "saved-\(sig.label)")
              }
            },
            onDelete: { model.deleteSignatureFromVault(id: $0) },
            onExport: { _ in }
          )
        }
      }
      .frame(height: 160)
    }
    .padding(16)
    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
  }

  // MARK: - Actions

  private func beginVerification() {
    guard let inspection = model.inspection,
          let data = model.sourceData else { return }

    let docTitle = inspection.source.fileName
    let docAuthor = ""

    commitManager.begin(
      fileName: inspection.source.fileName,
      documentData: data,
      pageCount: inspection.pages.count,
      documentTitle: docTitle,
      documentAuthor: docAuthor
    )
  }

  private func commitSign(_ imageData: Data, source: String) {
    guard let inspection = model.inspection,
      let pageIndex = model.pendingSignatureRegion?.pageIndex ?? inspection.pages.first?.pageIndex,
      let bounds = signaturePlacementBounds()
    else { return }

    model.applySignature(imageData, to: bounds, on: pageIndex)

    commitManager.recordSign(pageIndex: pageIndex, method: source)
  }

  private func renderTypedSignature() -> Data {
    let font = NSFont(name: scriptFonts[selectedFontIndex], size: 48)
      ?? NSFont.systemFont(ofSize: 48, weight: .light)
    let attrs: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: NSColor.black
    ]
    let str = NSAttributedString(string: typedName.isEmpty ? "Signature" : typedName, attributes: attrs)
    let size = str.size()
    let image = NSImage(size: NSSize(width: size.width + 20, height: size.height + 12))
    image.lockFocus()
    str.draw(at: NSPoint(x: 10, y: 6))
    image.unlockFocus()
    return image.pngData ?? Data()
  }

  private func signaturePlacementBounds() -> PDFRect? {
    guard let inspection = model.inspection else { return nil }
    if let region = model.pendingSignatureRegion {
      return region.bounds
    }
    let page = inspection.pages.indices.contains(model.selectedPageIndex)
      ? inspection.pages[model.selectedPageIndex] : inspection.pages[0]
    let w = page.bounds.width * 0.35
    let h = 60.0
    return PDFRect(x: page.bounds.x + (page.bounds.width - w) / 2,
                   y: page.bounds.y + 60,
                   width: w, height: h)
  }
}
