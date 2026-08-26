import AppKit
import PDFEditorCore
import PDFEditorRecovery
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

public struct BatchMergeSheet: View {
  @Bindable var model: AppModel
  @Environment(\.dismiss) private var dismiss

  @State private var sourceFiles: [URL] = []
  @State private var isTargetedForDrop: Bool = false
  @State private var isMerging: Bool = false

  public init(model: AppModel) {
    self.model = model
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Header
      HStack {
        VStack(alignment: .leading, spacing: 3) {
          HStack(spacing: 8) {
            Image(systemName: "doc.on.doc.fill")
              .font(.title2)
              .foregroundStyle(.tint)
            Text("Batch Merge Documents")
              .font(.title2.weight(.semibold))
          }
          Text("Combine multiple PDF files sequentially into a single target document.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Button("Cancel") {
          dismiss()
        }
        .keyboardShortcut(.cancelAction)
      }
      .padding([.horizontal, .top], 20)
      .padding(.bottom, 14)

      Divider()

      // Drop Zone / File List
      if sourceFiles.isEmpty {
        emptyDropZone
      } else {
        fileListView
      }

      Divider()

      // Footer
      HStack {
        Button("Add Files…", systemImage: "plus") {
          chooseFiles()
        }
        .buttonStyle(.bordered)

        Spacer()

        let totalPages = sourceFiles.compactMap { PDFDocument(url: $0)?.pageCount }.reduce(0, +)
        if totalPages > 0 {
          Text("\(sourceFiles.count) files · \(totalPages) total pages")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Button("Merge & Save…", systemImage: "arrow.down.doc") {
          performMerge()
        }
        .buttonStyle(.borderedProminent)
        .disabled(sourceFiles.isEmpty || isMerging)
      }
      .padding(16)
    }
    .frame(minWidth: 540, minHeight: 400)
    .onDrop(of: [.fileURL], isTargeted: $isTargetedForDrop) { providers in
      handleDrop(providers: providers)
    }
  }

  private var emptyDropZone: some View {
    VStack(spacing: 12) {
      Image(systemName: isTargetedForDrop ? "arrow.down.doc.fill" : "doc.badge.plus")
        .font(.system(size: 40))
        .foregroundStyle(isTargetedForDrop ? Color.accentColor : Color.secondary.opacity(0.6))
      Text("Drag & drop PDF files here")
        .font(.headline)
        .foregroundStyle(.secondary)
      Button("Choose Files…") {
        chooseFiles()
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.small)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(isTargetedForDrop ? Color.accentColor.opacity(0.08) : Color.clear)
  }

  private var fileListView: some View {
    List {
      ForEach(Array(sourceFiles.enumerated()), id: \.offset) { index, url in
        HStack(spacing: 12) {
          Text("\(index + 1)")
            .font(.caption.monospacedDigit().weight(.bold))
            .foregroundStyle(.secondary)
            .frame(width: 20)

          Image(systemName: "doc.fill")
            .foregroundStyle(.secondary)

          VStack(alignment: .leading, spacing: 2) {
            Text(url.lastPathComponent)
              .font(.body.weight(.medium))
              .lineLimit(1)
            let pageCount = PDFDocument(url: url)?.pageCount ?? 0
            Text("\(pageCount) page\(pageCount == 1 ? "" : "s")")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }

          Spacer()

          Button {
            sourceFiles.remove(at: index)
          } label: {
            Image(systemName: "xmark.circle.fill")
              .foregroundStyle(.secondary)
          }
          .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
      }
      .onMove { indices, newOffset in
        sourceFiles.move(fromOffsets: indices, toOffset: newOffset)
      }
    }
  }

  private func chooseFiles() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.pdf]
    panel.allowsMultipleSelection = true
    panel.canChooseDirectories = false
    panel.begin { response in
      if response == .OK {
        for url in panel.urls where !sourceFiles.contains(url) {
          sourceFiles.append(url)
        }
      }
    }
  }

  private func handleDrop(providers: [NSItemProvider]) -> Bool {
    for provider in providers {
      _ = provider.loadObject(ofClass: URL.self) { url, _ in
        if let url, url.pathExtension.lowercased() == "pdf" {
          DispatchQueue.main.async {
            if !sourceFiles.contains(url) {
              sourceFiles.append(url)
            }
          }
        }
      }
    }
    return true
  }

  private func performMerge() {
    let savePanel = NSSavePanel()
    savePanel.allowedContentTypes = [.pdf]
    savePanel.nameFieldStringValue = "Merged-Document.pdf"
    savePanel.begin { response in
      if response == .OK, let destURL = savePanel.url {
        isMerging = true
        let success = model.mergePDFs(sources: sourceFiles, destination: destURL)
        isMerging = false
        if success {
          dismiss()
        }
      }
    }
  }
}
