import AppKit
import CoreGraphics
import Foundation
import PDFKit
import Vision

public struct OCRObservation: Equatable, Hashable, Sendable {
  public let text: String
  /// Vision uses a normalized lower-left coordinate space (0...1).
  public let normalizedBounds: PDFRect
  public let confidence: Double

  public init(text: String, normalizedBounds: PDFRect, confidence: Double) {
    self.text = text
    self.normalizedBounds = normalizedBounds
    self.confidence = confidence
  }

  public func toPageSpace(pageBounds: PDFRect, pageIndex: Int) -> TextLineEvidence {
    let x = pageBounds.x + normalizedBounds.x * pageBounds.width
    let y = pageBounds.y + normalizedBounds.y * pageBounds.height
    let width = normalizedBounds.width * pageBounds.width
    let height = normalizedBounds.height * pageBounds.height
    return TextLineEvidence(
      pageIndex: pageIndex,
      text: text,
      bounds: PDFRect(x: x, y: y, width: width, height: height)
    )
  }
}

public protocol OCRProvider: Sendable {
  func recognize(image: CGImage) throws -> [OCRObservation]
}

/// Hybrid OCR routing: detects scanned vs digital documents and routes accordingly.
/// Adopted from invoice-intelligence pattern for capability routing (OPERATING_DOCTRINE §8).
public struct HybridOCRRouter {
  /// Minimum text length to consider a document "digital" (has extractable text)
  private let digitalTextThreshold: Int
  /// Confidence threshold for OCR results
  private let ocrConfidenceThreshold: Double

  public init(
    digitalTextThreshold: Int = 50,
    ocrConfidenceThreshold: Double = 0.7
  ) {
    self.digitalTextThreshold = digitalTextThreshold
    self.ocrConfidenceThreshold = ocrConfidenceThreshold
  }

  /// Route a document to the appropriate extraction method.
  /// - Parameters:
  ///   - text: Extracted text from the document (may be empty for scanned PDFs)
  ///   - pageCount: Number of pages in the document
  /// - Returns: The recommended processing route
  public func route(text: String, pageCount: Int) -> ProcessingRoute {
    let hasText = text.count >= digitalTextThreshold
    
    if hasText {
      return .digital
    } else {
      return .scanned(recommendedEngine: .vision)
    }
  }

  /// Check if a document is probably scanned based on text content.
  public func isProbablyScanned(text: String) -> Bool {
    return text.count < digitalTextThreshold
  }
}

/// Processing route for hybrid document handling.
public enum ProcessingRoute: Sendable, Equatable {
  /// Document has extractable text — use text-based processing
  case digital
  /// Document is scanned — use OCR
  case scanned(recommendedEngine: OCREngine)
  /// Document has mixed content — use both
  case mixed
}

/// Available OCR engines.
public enum OCREngine: String, Sendable, CaseIterable {
  case vision = "Vision"
  case tesseract = "Tesseract"
  case paddle = "PaddleOCR"
  
  public var displayName: String {
    switch self {
    case .vision: return "Apple Vision"
    case .tesseract: return "Tesseract CLI"
    case .paddle: return "PaddleOCR"
    }
  }
}

public struct CVRectangleObservation: Equatable, Hashable, Sendable {
  /// Vision normalized coordinates use a lower-left origin, matching the PDF contract.
  public let normalizedBounds: PDFRect
  public let confidence: Double

  public init(normalizedBounds: PDFRect, confidence: Double) {
    self.normalizedBounds = normalizedBounds
    self.confidence = confidence
  }
}

public protocol CVGeometryProvider: Sendable {
  func detectRectangles(image: CGImage) throws -> [CVRectangleObservation]
}

/// Conservative raster fallback for image-only or geometry-poor forms.
/// Results are evidence only and must be reviewed before becoming edits.
public struct VisionCVProvider: CVGeometryProvider {
  public let minimumConfidence: Float

  public init(minimumConfidence: Float = 0.35) {
    self.minimumConfidence = minimumConfidence
  }

  public func detectRectangles(image: CGImage) throws -> [CVRectangleObservation] {
    var requestError: Error?
    var observations: [CVRectangleObservation] = []
    let request = VNDetectRectanglesRequest { request, error in
      requestError = error
      guard error == nil,
        let results = request.results as? [VNRectangleObservation]
      else { return }
      observations =
        results
        .filter { $0.confidence >= minimumConfidence }
        .map {
          CVRectangleObservation(
            normalizedBounds: PDFRect($0.boundingBox),
            confidence: Double($0.confidence)
          )
        }
    }
    request.minimumConfidence = minimumConfidence
    request.maximumObservations = 64
    request.minimumAspectRatio = 0.05
    request.maximumAspectRatio = 1.0
    let handler = VNImageRequestHandler(cgImage: image, options: [:])
    try handler.perform([request])
    if let requestError {
      throw requestError
    }
    return observations
  }
}

public struct VisionOCRProvider: OCRProvider {
  public let recognitionLevel: VNRequestTextRecognitionLevel

  public init(recognitionLevel: VNRequestTextRecognitionLevel = .accurate) {
    self.recognitionLevel = recognitionLevel
  }

  public func recognize(image: CGImage) throws -> [OCRObservation] {
    try PerformanceTelemetry.shared.measureOCR {
      try autoreleasepool {
        var requestError: Error?
        var observations: [OCRObservation] = []
        let request = VNRecognizeTextRequest { request, error in
          requestError = error
          guard error == nil,
            let results = request.results as? [VNRecognizedTextObservation]
          else { return }
          observations = results.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return OCRObservation(
              text: candidate.string,
              normalizedBounds: PDFRect(observation.boundingBox),
              confidence: Double(candidate.confidence)
            )
          }
        }
        request.recognitionLevel = recognitionLevel
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        if let requestError {
          throw requestError
        }
        return observations
      }
    }
  }

  public func recognize(page: PDFPage, pageIndex: Int, scale: CGFloat = 2.0) throws
    -> [OCRObservation]
  {
    try autoreleasepool {
      let bounds = page.bounds(for: .mediaBox)
      let pixelSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)
      guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
        let context = CGContext(
          data: nil,
          width: Int(pixelSize.width),
          height: Int(pixelSize.height),
          bitsPerComponent: 8,
          bytesPerRow: 0,
          space: colorSpace,
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
      else {
        return []
      }

      context.setFillColor(NSColor.white.cgColor)
      context.fill(CGRect(origin: .zero, size: pixelSize))
      context.scaleBy(x: scale, y: scale)
      page.draw(with: .mediaBox, to: context)

      guard let image = context.makeImage() else { return [] }
      return try recognize(image: image)
    }
  }
}
