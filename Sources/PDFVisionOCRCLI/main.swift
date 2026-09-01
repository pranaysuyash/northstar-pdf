import AppKit
import Foundation
import Vision

/// Vision OCR CLI — accepts PNG/JPG images or PDF files (converted via pdftoppm).
/// Outputs one JSON line per text region: {"page":0,"text":"...","confidence":0.99}
/// Usage: PDFVisionOCRCLI <path-to-image-or-pdf>

guard CommandLine.arguments.count > 1 else {
  fputs("Usage: PDFVisionOCRCLI <path-to-image-or-pdf>\n", stderr)
  exit(1)
}

let inputPath = CommandLine.arguments[1]
guard FileManager.default.fileExists(atPath: inputPath) else {
  fputs("File not found: \(inputPath)\n", stderr)
  exit(1)
}

func processImage(_ imagePath: String, pageIndex: Int) {
  guard let image = NSImage(contentsOfFile: imagePath),
    let tiffData = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiffData),
    let cgImage = bitmap.cgImage(forProposedRect: nil, context: nil, hints: nil)
  else {
    fputs("Failed to load image: \(imagePath)\n", stderr)
    return
  }

  let semaphore = DispatchSemaphore(value: 0)
  var observations: [VNRecognizedTextObservation] = []
  var requestError: Error?

  let request = VNRecognizeTextRequest { request, error in
    if let error {
      requestError = error
      semaphore.signal()
      return
    }
    observations = (request.results as? [VNRecognizedTextObservation]) ?? []
    semaphore.signal()
  }
  request.recognitionLevel = .accurate
  request.usesLanguageCorrection = true

  let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
  do {
    try handler.perform([request])
  } catch {
    fputs("Vision error on page \(pageIndex): \(error)\n", stderr)
    return
  }
  semaphore.wait()

  if let error = requestError {
    fputs("Vision request error on page \(pageIndex): \(error)\n", stderr)
    return
  }

  for obs in observations {
    if let candidate = obs.topCandidates(1).first {
      let entry: [String: Any] = [
        "page": pageIndex,
        "text": candidate.string,
        "confidence": Double(candidate.confidence),
        "x": obs.boundingBox.origin.x,
        "y": obs.boundingBox.origin.y,
        "w": obs.boundingBox.size.width,
        "h": obs.boundingBox.size.height,
      ]
      if let data = try? JSONSerialization.data(withJSONObject: entry),
        let line = String(data: data, encoding: .utf8)
      {
        print(line)
      }
    }
  }
}

let ext = (inputPath as NSString).pathExtension.lowercased()

if ["png", "jpg", "jpeg", "tiff", "bmp"].contains(ext) {
  // Direct image processing
  processImage(inputPath, pageIndex: 0)
} else if ext == "pdf" {
  // Convert PDF to images via pdftoppm, then process each
  let tmpDir = "/tmp/vision-ocr-\(ProcessInfo.processInfo.processIdentifier)"
  try? FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
  let prefix = "\(tmpDir)/page"

  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/pdftoppm")
  process.arguments = ["-png", "-r", "300", inputPath, prefix]
  try? process.run()
  process.waitUntilExit()

  let fm = FileManager.default
  guard let files = try? fm.contentsOfDirectory(atPath: tmpDir)
    .filter({ $0.hasPrefix("page") && $0.hasSuffix(".png") })
    .sorted()
  else {
    fputs("No page images generated\n", stderr)
    exit(1)
  }

  for (idx, file) in files.enumerated() {
    processImage("\(tmpDir)/\(file)", pageIndex: idx)
  }

  try? fm.removeItem(atPath: tmpDir)
} else {
  fputs("Unsupported file type: \(ext)\n", stderr)
  exit(1)
}
