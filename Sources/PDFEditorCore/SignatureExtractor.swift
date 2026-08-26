import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreGraphics
import ImageIO

/// Native Swift signature extraction built from first principles — no external
/// dependency and not a port of any prior v1. A photo or scan of a signature
/// is:
///   1. (optionally) deskewed via document-rectangle detection + perspective correction,
///   2. binarized with a *local* (adaptive) threshold so uneven phone lighting,
///      shadows, and color ink (black/blue/red) all extract cleanly,
///   3. speck-filtered to drop sensor noise,
///   4. tight-cropped to the ink,
/// and returned as a transparent PNG preserving the original ink color.
public enum SignatureExtractionError: Error, Sendable {
  case invalidImage
  case processingFailed
}

public struct SignatureExtractor {
  /// Window (as a fraction of the larger dimension) used for the local mean in
  /// adaptive thresholding. Smaller = more local; larger = more robust to big
  /// lighting gradients.
  public var adaptiveWindowFraction: Double = 1.0 / 22.0
  /// How strongly a pixel must be darker than its local neighborhood to count
  /// as ink. Smaller = more aggressive extraction.
  public var inkContrast: Double = 0.20
  /// Attempt perspective deskew when a document rectangle is confidently found.
  public var deskew: Bool = true

  public init() {}

  public func clean(_ inputData: Data) throws -> Data {
    guard let cg = makeCGImage(from: inputData) else { throw SignatureExtractionError.invalidImage }
    var ci = CIImage(cgImage: cg)

    if deskew, let corrected = deskewIfRectangular(ci) {
      ci = corrected
    }

    guard let workCG = CIContext().createCGImage(ci, from: ci.extent) else {
      throw SignatureExtractionError.processingFailed
    }

    return try extract(from: workCG)
  }

  // MARK: - Deskew

  private func deskewIfRectangular(_ image: CIImage) -> CIImage? {
    let detector = CIDetector(
      ofType: CIDetectorTypeRectangle,
      context: nil,
      options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
    )
    guard let features = detector?.features(in: image) as? [CIRectangleFeature],
          let rect = features.max(by: { $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height })
    else { return nil }

    let correction = CIFilter.perspectiveCorrection()
    correction.inputImage = image
    correction.topLeft = rect.topLeft
    correction.topRight = rect.topRight
    correction.bottomLeft = rect.bottomLeft
    correction.bottomRight = rect.bottomRight
    return correction.outputImage
  }

  // MARK: - Adaptive extraction

  /// Read pixels, compute a lighting-robust ink alpha via a local-mean
  /// (integral-image box blur) threshold, speck-filter, tight-crop, and write a
  /// premultiplied RGBA PNG.
  private func extract(from workCG: CGImage) throws -> Data {
    let width = workCG.width
    let height = workCG.height
    guard width > 0, height > 0 else { throw SignatureExtractionError.processingFailed }

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
      data: nil, width: width, height: height,
      bitsPerComponent: 8, bytesPerRow: width * 4,
      space: colorSpace,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { throw SignatureExtractionError.processingFailed }

    ctx.draw(workCG, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard let raw = ctx.data else { throw SignatureExtractionError.processingFailed }
    let ptr = raw.bindMemory(to: UInt8.self, capacity: width * height * 4)

    // 1. Per-pixel luminance.
    var luma = [Double](repeating: 0, count: width * height)
    for y in 0..<height {
      for x in 0..<width {
        let i = (y * width + x) * 4
        let r = Double(ptr[i]), g = Double(ptr[i + 1]), b = Double(ptr[i + 2])
        luma[y * width + x] = 0.299 * r + 0.587 * g + 0.114 * b
      }
    }

    // 2. Local mean via integral image (O(n)).
    let radius = max(4, Int(Double(max(width, height)) * adaptiveWindowFraction))
    let localMean = localMean(luma: luma, width: width, height: height, radius: radius)

    // 3. Ink alpha = how much darker than the local neighborhood.
    var alpha = [Double](repeating: 0, count: width * height)
    for idx in 0..<luma.count {
      let delta = localMean[idx] - luma[idx]
      alpha[idx] = delta > 0 ? min(1, delta / (inkContrast * 255)) : 0
    }

    // 4. Speck removal: drop isolated ink pixels (< 2 ink neighbors).
    var ink = alpha.map { $0 > 0.5 }
    removeSpecks(&ink, width: width, height: height, minNeighbors: 2)

    // 5. Tight crop to ink bounding box.
    guard let box = boundingBox(of: ink, width: width, height: height, pad: 4) else {
      throw SignatureExtractionError.processingFailed
    }

    // 6. Write premultiplied RGBA with the extracted alpha, in place.
    for y in box.y..<(box.y + box.h) {
      for x in box.x..<(box.x + box.w) {
        let i = (y * width + x) * 4
        let a = ink[y * width + x] ? alpha[y * width + x] : 0
        ptr[i] = UInt8(Double(ptr[i]) * a)
        ptr[i + 1] = UInt8(Double(ptr[i + 1]) * a)
        ptr[i + 2] = UInt8(Double(ptr[i + 2]) * a)
        ptr[i + 3] = UInt8(a * 255)
      }
    }

    guard let outCG = ctx.makeImage()?.cropping(to: CGRect(x: box.x, y: box.y, width: box.w, height: box.h)),
          let finalCG = outCG.copy(colorSpace: colorSpace) else {
      throw SignatureExtractionError.processingFailed
    }
    return try encodePNG(finalCG)
  }

  /// Integral-image based box-blur mean. Clamps at image borders.
  private func localMean(luma: [Double], width: Int, height: Int, radius: Int) -> [Double] {
    // Integral image (1-indexed padding).
    var integral = [Double](repeating: 0, count: (width + 1) * (height + 1))
    for y in 0..<height {
      var rowSum = 0.0
      for x in 0..<width {
        rowSum += luma[y * width + x]
        integral[(y + 1) * (width + 1) + (x + 1)] = integral[y * (width + 1) + (x + 1)] + rowSum
      }
    }
    func sum(x0: Int, y0: Int, x1: Int, y1: Int) -> Double {
      let x0 = max(0, x0), y0 = max(0, y0)
      let x1 = min(width, x1), y1 = min(height, y1)
      let a = integral[y1 * (width + 1) + x1]
      let b = integral[y0 * (width + 1) + x1]
      let c = integral[y1 * (width + 1) + x0]
      let d = integral[y0 * (width + 1) + x0]
      return a - b - c + d
    }
    var mean = [Double](repeating: 0, count: width * height)
    for y in 0..<height {
      for x in 0..<width {
        let area = (min(width, x + radius + 1) - max(0, x - radius)) *
                   (min(height, y + radius + 1) - max(0, y - radius))
        mean[y * width + x] = sum(x0: x - radius, y0: y - radius, x1: x + radius + 1, y1: y + radius + 1) / Double(max(1, area))
      }
    }
    return mean
  }

  private func removeSpecks(_ ink: inout [Bool], width: Int, height: Int, minNeighbors: Int) {
    let copy = ink
    for y in 0..<height {
      for x in 0..<width {
        guard copy[y * width + x] else { continue }
        var neighbors = 0
        for dy in -1...1 {
          for dx in -1...1 where !(dx == 0 && dy == 0) {
            let nx = x + dx, ny = y + dy
            if nx >= 0, nx < width, ny >= 0, ny < height, copy[ny * width + nx] {
              neighbors += 1
            }
          }
        }
        if neighbors < minNeighbors {
          ink[y * width + x] = false
        }
      }
    }
  }

  private func boundingBox(of ink: [Bool], width: Int, height: Int, pad: Int) -> (x: Int, y: Int, w: Int, h: Int)? {
    var minX = width, minY = height, maxX = 0, maxY = 0, found = false
    for y in 0..<height {
      for x in 0..<width where ink[y * width + x] {
        found = true
        minX = min(minX, x); maxX = max(maxX, x)
        minY = min(minY, y); maxY = max(maxY, y)
      }
    }
    guard found else { return nil }
    let x = max(0, minX - pad)
    let y = max(0, minY - pad)
    let w = min(width, maxX + pad) - x
    let h = min(height, maxY + pad) - y
    return (x, y, w, h)
  }

  // MARK: - Helpers

  private func makeCGImage(from data: Data) -> CGImage? {
    guard let src = CGImageSourceCreateWithData(data as CFData, nil),
          let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
    return cg
  }

  private func encodePNG(_ cg: CGImage) throws -> Data {
    let data = NSMutableData()
    guard let dest = CGImageDestinationCreateWithData(data as CFMutableData, kUTTypePNG, 1, nil) else {
      throw SignatureExtractionError.processingFailed
    }
    CGImageDestinationAddImage(dest, cg, nil)
    guard CGImageDestinationFinalize(dest) else { throw SignatureExtractionError.processingFailed }
    return data as Data
  }
}
