import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreGraphics
import ImageIO

/// Native Swift signature extraction built from first principles — no external
/// dependency and not a port of any prior v1. A photo or scan of a signature is:
///   1. (optionally) deskewed: document-rectangle perspective correction, then a
///      PCA stroke-angle rotation so tilted handwriting straightens,
///   2. binarized: a *local* (adaptive) threshold for opaque photos/scans so
///      uneven lighting, shadows, and color ink (black/blue/red) all extract
///      cleanly; an *alpha-channel* path for already-transparent graphics,
///   3. speck-filtered to drop sensor noise,
///   4. tight-cropped to the ink,
/// and returned as a transparent PNG preserving the original ink color.
public enum SignatureExtractionError: Error, Sendable {
  case invalidImage
  case processingFailed
}

/// A free-hand erase stroke in normalized [0,1] image coordinates (origin top-left,
/// y-down) so it is resolution-independent.
public struct EraseStroke: Sendable {
  public var points: [CGPoint]
  public init(points: [CGPoint]) { self.points = points }
}

public struct SignatureExtractor {
  /// Window (as a fraction of the larger dimension) used for the local mean in
  /// adaptive thresholding. Smaller = more local; larger = more robust to big
  /// lighting gradients.
  public var adaptiveWindowFraction: Double = 1.0 / 22.0
  /// How strongly a pixel must be darker than its local neighborhood to count
  /// as ink. Smaller = more aggressive extraction.
  public var inkContrast: Double = 0.20
  /// Attempt deskew (document rectangle + PCA stroke-angle rotation).
  public var deskew: Bool = true
  /// Minimum (normalised) brush radius for the erase tool.
  public var eraseBrush: CGFloat = 0.04

  public init() {}

  public func clean(_ inputData: Data) throws -> Data {
    guard let cg = makeCGImage(from: inputData) else { throw SignatureExtractionError.invalidImage }
    var ci = CIImage(cgImage: cg)

    if deskew, let corrected = deskewIfRectangular(ci) {
      ci = corrected
    }

    if deskew,
       let workForAngle = CIContext().createCGImage(ci, from: ci.extent),
       let angle = signatureRotation(from: workForAngle) {
      ci = ci.transformed(by: CGAffineTransform(rotationAngle: angle))
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

  /// PCA over ink pixels: if the ink forms a clearly elongated shape, rotate so
  /// its principal axis is horizontal. Returns the CI rotation angle (radians),
  /// or nil when there is no stable orientation to correct.
  private func signatureRotation(from workCG: CGImage) -> Double? {
    let width = workCG.width
    let height = workCG.height
    guard width > 0, height > 0 else { return nil }
    guard let ctx = CGContext(
      data: nil, width: width, height: height,
      bitsPerComponent: 8, bytesPerRow: width * 4,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    ctx.draw(workCG, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard let raw = ctx.data else { return nil }
    let ptr = raw.bindMemory(to: UInt8.self, capacity: width * height * 4)

    var pts: [(Double, Double)] = []
    pts.reserveCapacity(width * height / 20)
    for y in 0..<height {
      for x in 0..<width {
        if ptr[(y * width + x) * 4 + 3] > 128 { pts.append((Double(x), Double(y))) }
      }
    }
    guard pts.count > 200 else { return nil }

    let n = Double(pts.count)
    let mx = pts.reduce(0) { $0 + $1.0 } / n
    let my = pts.reduce(0) { $0 + $1.1 } / n
    var cxx = 0.0, cyy = 0.0, cxy = 0.0
    for (x, y) in pts {
      let dx = x - mx, dy = y - my
      cxx += dx * dx; cyy += dy * dy; cxy += dx * dy
    }
    cxx /= n; cyy /= n; cxy /= n

    let tr = cxx + cyy
    let disc = sqrt(max(0, tr * tr / 4 - (cxx * cyy - cxy * cxy)))
    let l1 = tr / 2 + disc
    let l2 = tr / 2 - disc
    guard l1 > 0, l1 / (l2 + 1e-9) > 1.5 else { return nil } // needs a clear long axis

    // Principal axis angle in y-down pixel space (atan2 convention), normalised.
    var theta = 0.5 * atan2(2 * cxy, cxx - cyy)
    if theta > .pi / 2 { theta -= .pi } else if theta < -.pi / 2 { theta += .pi }
    // A CI rotation by `theta` straightens a y-down principal axis to horizontal.
    guard abs(theta) > 3 * .pi / 180 else { return nil }
    return theta
  }

  // MARK: - Adaptive extraction

  /// Read pixels, classify ink (alpha path for graphics, adaptive-luminance path
  /// for photos), speck-filter, tight-crop, and write a premultiplied RGBA PNG.
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

    var luma = [Double](repeating: 0, count: width * height)
    var alpha = [Double](repeating: 0, count: width * height)
    var maxA = 0, minA = 255

    for y in 0..<height {
      for x in 0..<width {
        let i = (y * width + x) * 4
        let a0 = ptr[i + 3]
        maxA = max(maxA, Int(a0)); minA = min(minA, Int(a0))
        let r = Double(ptr[i]), g = Double(ptr[i + 1]), b = Double(ptr[i + 2])
        let a01 = Double(a0) / 255
        if a01 > 0 {
          luma[y * width + x] = 0.299 * (r / a01) + 0.587 * (g / a01) + 0.114 * (b / a01)
        } else {
          luma[y * width + x] = 255 // transparent -> treat as paper
        }
        alpha[y * width + x] = a01
      }
    }

    // Classify ink: graphics already carry an alpha mask; photos need adaptive
    // luminance thresholding.
    let hasTransparency = minA < 250
    var ink = [Bool](repeating: false, count: width * height)
    if hasTransparency {
      for idx in 0..<alpha.count { ink[idx] = alpha[idx] > 0.5 }
    } else {
      let radius = max(4, Int(Double(max(width, height)) * adaptiveWindowFraction))
      let localMean = localMean(luma: luma, width: width, height: height, radius: radius)
      // Global background estimate. Keeps solid dark regions (stamps, filled
      // blobs) whose interior would otherwise read delta ~ 0 under a purely
      // local window. The local term still handles uneven lighting/shadows.
      let globalMean = luma.reduce(0, +) / Double(luma.count)
      let scale = inkContrast * 255
      for idx in 0..<luma.count {
        let delta = max(localMean[idx] - luma[idx], globalMean - luma[idx])
        let a = delta > 0 ? min(1, delta / scale) : 0
        alpha[idx] = a
        ink[idx] = a > 0.5
      }
    }

    removeSpecks(&ink, width: width, height: height, minNeighbors: 2)

    guard let box = boundingBox(of: ink, width: width, height: height, pad: 4) else {
      throw SignatureExtractionError.processingFailed
    }

    // Write premultiplied RGBA with the extracted alpha, in place.
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

  // MARK: - Erase tool

  /// Zero out (make transparent) the pixels covered by the erase strokes.
  /// Strokes use normalized [0,1] coordinates (top-left origin, y-down).
  public func applyingErase(_ inputData: Data, strokes: [EraseStroke], brush: CGFloat? = nil) throws -> Data {
    guard let cg = makeCGImage(from: inputData) else { throw SignatureExtractionError.invalidImage }
    let width = cg.width, height = cg.height
    guard width > 0, height > 0 else { throw SignatureExtractionError.processingFailed }
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
      data: nil, width: width, height: height,
      bitsPerComponent: 8, bytesPerRow: width * 4,
      space: colorSpace,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { throw SignatureExtractionError.processingFailed }
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard let raw = ctx.data else { throw SignatureExtractionError.processingFailed }
    let ptr = raw.bindMemory(to: UInt8.self, capacity: width * height * 4)
    let r = max(1, Int((brush ?? eraseBrush) * Double(min(width, height))))

    for stroke in strokes {
      let pts = stroke.points
      guard !pts.isEmpty else { continue }
      if pts.count == 1 {
        stampErase(ptr: ptr, width: width, height: height, nx: pts[0].x, ny: pts[0].y, radius: r)
      } else {
        for i in 0..<pts.count - 1 {
          rasterEraseSegment(ptr: ptr, width: width, height: height, from: pts[i], to: pts[i + 1], radius: r)
        }
      }
    }

    guard let outCG = ctx.makeImage() else { throw SignatureExtractionError.processingFailed }
    return try encodePNG(outCG)
  }

  private func stampErase(ptr: UnsafeMutablePointer<UInt8>, width: Int, height: Int, nx: CGFloat, ny: CGFloat, radius: Int) {
    let cx = Int(nx * CGFloat(width))
    let cy = Int(ny * CGFloat(height))
    for dy in -radius...radius {
      for dx in -radius...radius where dx * dx + dy * dy <= radius * radius {
        let px = cx + dx, py = cy + dy
        if px >= 0, px < width, py >= 0, py < height {
          let i = (py * width + px) * 4
          ptr[i] = 0; ptr[i + 1] = 0; ptr[i + 2] = 0; ptr[i + 3] = 0
        }
      }
    }
  }

  private func rasterEraseSegment(ptr: UnsafeMutablePointer<UInt8>, width: Int, height: Int, from: CGPoint, to: CGPoint, radius: Int) {
    let x0 = from.x * CGFloat(width), y0 = from.y * CGFloat(height)
    let x1 = to.x * CGFloat(width), y1 = to.y * CGFloat(height)
    let dist = hypot(x1 - x0, y1 - y0)
    let steps = max(1, Int(dist))
    for s in 0...steps {
      let t = Double(s) / Double(steps)
      stampErase(ptr: ptr, width: width, height: height, nx: CGFloat(x0 + (x1 - x0) * CGFloat(t)) / CGFloat(width), ny: CGFloat(y0 + (y1 - y0) * CGFloat(t)) / CGFloat(height), radius: radius)
    }
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
