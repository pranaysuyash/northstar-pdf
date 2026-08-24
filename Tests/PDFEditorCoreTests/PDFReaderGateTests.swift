import AppKit
import Foundation
import PDFKit
import Testing

@testable import PDFEditorCore

struct PDFReaderGateTests {
  @Test func rotatedPageInspectionPreservesGeometryAndRotation() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdf-editor-rotation-gate-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let sourceURL = directory.appendingPathComponent("rotated.pdf")
    let document = PDFDocument()
    let page = PDFPage()
    page.rotation = 90
    document.insert(page, at: 0)
    #expect(document.write(to: sourceURL))

    let inspection = try PDFKitProvider().inspect(url: sourceURL)
    #expect(inspection.pages.count == 1)
    #expect(inspection.pages[0].rotation == 90)
    #expect(inspection.pages[0].bounds.width > 0)
    #expect((inspection.pages[0].cropBox?.width ?? 0) > 0)
  }

  @Test func emptyTextInspectionSignalsOcrOrUnavailableText() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdf-editor-ocr-gate-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let sourceURL = directory.appendingPathComponent("image-only.pdf")
    let document = PDFDocument()
    document.insert(PDFPage(), at: 0)
    #expect(document.write(to: sourceURL))

    let inspection = try PDFKitProvider().inspect(url: sourceURL)
    #expect(inspection.pages[0].hasSelectableText == false)
    #expect(inspection.accessibility.hasReadingOrder == false)
    #expect(inspection.accessibility.notes.contains { $0.contains("OCR") })
  }

  @Test func pageCountLimitRejectsResourceStressInputBeforeExport() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdf-editor-page-limit-gate-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let sourceURL = directory.appendingPathComponent("too-many-pages.pdf")
    let document = PDFDocument()
    document.insert(PDFPage(), at: 0)
    document.insert(PDFPage(), at: 1)
    #expect(document.write(to: sourceURL))

    do {
      _ = try PDFKitProvider(limits: .init(maximumPageCount: 1)).inspect(url: sourceURL)
      Issue.record("Page-count limit did not reject the input")
    } catch let error as PDFEditorError {
      guard case .invalidOperation = error else {
        Issue.record("Unexpected page-limit error: \(error.localizedDescription)")
        return
      }
    }
  }

  @Test func unchangedProviderExportCopiesSourceWithoutReserialization() throws {
    let projectRoot = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let sourceURL = projectRoot.appendingPathComponent("benchmark/results/public-sample-form.pdf")
    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: sourceURL.path) else {
      Issue.record("The public AcroForm fixture is required for this provider safety gate")
      return
    }

    let directory = fileManager.temporaryDirectory
      .appendingPathComponent(
        "pdf-editor-export-transaction-gate-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: directory) }

    let outputURL = directory.appendingPathComponent("destination.pdf")
    let result = try PDFKitProvider().export(url: sourceURL, operations: [], to: outputURL)
    #expect(result.report.status != .failed)
    #expect(try Data(contentsOf: outputURL) == Data(contentsOf: sourceURL))
    let stagingFiles = try fileManager.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: nil
    )
    .filter { $0.lastPathComponent.hasPrefix(".pdf-editor-") }
    #expect(stagingFiles.isEmpty)
  }

  @Test func rejectedEditedProviderExportDoesNotPublishOrOverwriteDestination() throws {
    let projectRoot = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let sourceURL = projectRoot.appendingPathComponent("benchmark/results/public-sample-form.pdf")
    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: sourceURL.path) else {
      Issue.record("The public AcroForm fixture is required for this provider safety gate")
      return
    }
    let directory = fileManager.temporaryDirectory
      .appendingPathComponent(
        "pdf-editor-edit-export-transaction-gate-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: directory) }

    let outputURL = directory.appendingPathComponent("destination.pdf")
    let sentinel = Data("existing destination must survive".utf8)
    try sentinel.write(to: outputURL)
    let operation = EditOperation(
      pageIndex: 0, targetID: "applicant.name", kind: .nativeFieldValue, value: "Provider test")

    do {
      _ = try PDFKitProvider().export(url: sourceURL, operations: [operation], to: outputURL)
      Issue.record("The known public AcroForm edited-export failure unexpectedly passed")
    } catch let error as PDFEditorError {
      guard case .exportFailed(let message) = error else {
        Issue.record("Unexpected provider error: \(error.localizedDescription)")
        return
      }
      #expect(message.contains("document-level AcroForm"))
      #expect(message.contains("read-only"))
    }

    #expect(try Data(contentsOf: outputURL) == sentinel)
    let stagingFiles = try fileManager.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: nil
    )
    .filter { $0.lastPathComponent.hasPrefix(".pdf-editor-") }
    #expect(stagingFiles.isEmpty)
  }

  @Test func securityFixturesExercisePasswordMalformedAndPageLimitPaths() throws {
    let projectRoot = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let fixtureRoot = projectRoot.appendingPathComponent("benchmark/results/security-corpus")
    let encryptedURL = fixtureRoot.appendingPathComponent("encrypted-reader.pdf")
    let truncatedURL = fixtureRoot.appendingPathComponent("truncated-128-bytes.pdf")
    let repeatedURL = fixtureRoot.appendingPathComponent("repeated-20-pages.pdf")
    let fileManager = FileManager.default
    for url in [encryptedURL, truncatedURL, repeatedURL] {
      guard fileManager.fileExists(atPath: url.path) else {
        Issue.record("Security fixture is required: \(url.path)")
        return
      }
    }

    do {
      _ = try PDFKitProvider().inspect(url: encryptedURL)
      Issue.record("Encrypted fixture opened without a password")
    } catch let error as PDFEditorError {
      guard case .passwordRequired = error else {
        Issue.record("Unexpected missing-password error: \(error.localizedDescription)")
        return
      }
    }

    do {
      _ = try PDFKitProvider().inspect(url: encryptedURL, password: "wrong-password")
      Issue.record("Encrypted fixture accepted an incorrect password")
    } catch let error as PDFEditorError {
      guard case .passwordIncorrect = error else {
        Issue.record("Unexpected incorrect-password error: \(error.localizedDescription)")
        return
      }
    }

    let unlocked = try PDFKitProvider().inspect(url: encryptedURL, password: "reader-password")
    #expect(unlocked.security.isEncrypted)
    #expect(unlocked.pages.count == 1)

    do {
      _ = try PDFKitProvider().inspect(url: truncatedURL)
      Issue.record("Truncated fixture unexpectedly opened")
    } catch let error as PDFEditorError {
      guard case .cannotOpen = error else {
        Issue.record("Unexpected malformed-input error: \(error.localizedDescription)")
        return
      }
    }

    do {
      _ = try PDFKitProvider(limits: .init(maximumPageCount: 10)).inspect(url: repeatedURL)
      Issue.record("Repeated-page fixture exceeded no page limit")
    } catch let error as PDFEditorError {
      guard case .invalidOperation = error else {
        Issue.record("Unexpected repeated-page error: \(error.localizedDescription)")
        return
      }
    }
  }

  @Test func imageOnlyOcrFixtureRemainsExplicitlyNonSelectable() throws {
    let projectRoot = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let sourceURL = projectRoot.appendingPathComponent(
      "benchmark/results/ocr-corpus/printed-scan.pdf")
    guard FileManager.default.fileExists(atPath: sourceURL.path) else {
      Issue.record("OCR fixture is required: \(sourceURL.path)")
      return
    }
    let inspection = try PDFKitProvider().inspect(url: sourceURL)
    #expect(inspection.pages.count == 1)
    #expect(inspection.pages[0].hasSelectableText == false)
    #expect(inspection.accessibility.hasReadingOrder == false)
    #expect(inspection.accessibility.notes.contains { $0.contains("OCR") })
  }

  @Test func visionOCRFallbackRecognizesTheReviewedRasterFixture() throws {
    let projectRoot = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let sourceURL = projectRoot.appendingPathComponent(
      "benchmark/results/ocr-corpus/printed-scan.pdf")
    guard let document = PDFDocument(url: sourceURL), let page = document.page(at: 0) else {
      Issue.record("OCR fixture is required for the Vision fallback benchmark")
      return
    }
    let observations = try VisionOCRProvider().recognize(page: page, pageIndex: 0, scale: 2)
    let recognizedText = observations.map(\.text).joined(separator: " ").uppercased()
    #expect(recognizedText.contains("OCR"))
    #expect(recognizedText.contains("ADA") || recognizedText.contains("LOVELO"))
  }

  @Test func visionCVFallbackReturnsReviewedRasterGeometryEvidence() throws {
    let size = CGSize(width: 800, height: 500)
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
      let context = CGContext(
        data: nil,
        width: Int(size.width),
        height: Int(size.height),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
    else {
      Issue.record("Could not create a raster CV benchmark image")
      return
    }
    context.setFillColor(NSColor.white.cgColor)
    context.fill(CGRect(origin: .zero, size: size))
    context.setStrokeColor(NSColor.black.cgColor)
    context.setLineWidth(8)
    context.stroke(CGRect(x: 180, y: 120, width: 420, height: 220))
    guard let image = context.makeImage() else {
      Issue.record("Could not create a raster CV benchmark image")
      return
    }
    let observations = try VisionCVProvider().detectRectangles(image: image)
    #expect(!observations.isEmpty)
    #expect(
      observations.allSatisfy {
        $0.normalizedBounds.x >= 0 && $0.normalizedBounds.y >= 0
          && $0.normalizedBounds.x + $0.normalizedBounds.width <= 1.01
          && $0.normalizedBounds.y + $0.normalizedBounds.height <= 1.01
      })
  }
}
