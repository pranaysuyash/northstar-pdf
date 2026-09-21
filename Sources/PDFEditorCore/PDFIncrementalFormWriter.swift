import Compression
import CoreGraphics
import Foundation
import ImageIO

/// Source-preserving incremental form writer for the native lane (RG-001).
///
/// Mirrors the verified web-lane semantics (`web/pdf-incremental-form-writer.mjs`,
/// RG-002): changed field objects are re-defined at the end of the file with the
/// same object number and generation, and a new xref section is appended with
/// `/Prev` chaining to the original xref. The original byte stream is a
/// byte-exact prefix of the output, so source integrity (RG-017/RG-018) holds
/// by construction and is additionally asserted after every write.
///
/// Bounded by design:
/// - Classic xref tables and xref streams are parsed; field objects inside
///   compressed object streams are refused (fail closed), not shadowed.
/// - Encrypted documents are refused.
/// - Native field-value edits (`/V`, `/AS`) and image stamp annotations
///   (`/Subtype /Stamp` with authored `/AP`) are emitted; field appearance
///   streams are never regenerated, matching the web lane's verified oracle
///   (value-level independent reopen via pikepdf/Poppler, `qpdf --check`).
public enum PDFIncrementalFormWriter {
  // MARK: - Public types

  public struct ObjectEdit {
    public let objectNumber: Int
    public var pairs: [(key: String, value: String)]

    public init(objectNumber: Int, pairs: [(key: String, value: String)]) {
      self.objectNumber = objectNumber
      self.pairs = pairs
    }
  }

  public enum WriterError: Error, LocalizedError {
    case missingStartxref
    case unsupportedXref(String)
    case encryptedUnsupported
    case compressedObject(Int)
    case objectNotFound(Int)
    case malformedStructure(String)
    case fieldNotFound(String)
    case requestedStateUnavailable(field: String, state: String)

    public var errorDescription: String? {
      switch self {
      case .missingStartxref:
        "Incremental update failed: the source has no startxref marker."
      case let .unsupportedXref(detail):
        "Incremental update failed: unsupported cross-reference structure (\(detail))."
      case .encryptedUnsupported:
        "Incremental update failed: encrypted documents require an explicit decrypt policy."
      case let .compressedObject(objectNumber):
        "Incremental update failed: field object \(objectNumber) lives in a compressed object stream; the source must be normalized first."
      case let .objectNotFound(objectNumber):
        "Incremental update failed: object \(objectNumber) is missing from the source xref."
      case let .malformedStructure(detail):
        "Incremental update failed: malformed PDF structure (\(detail))."
      case let .fieldNotFound(name):
        "Incremental update failed: native field \(name) was not found in the AcroForm tree."
      case let .requestedStateUnavailable(field: field, state: state):
        "Incremental update failed: field \(field) has no state named \(state)."
      }
    }
  }

  // MARK: - Latin1 helpers (bijective byte<->char, mirroring the web lane)

  static func latin1(_ bytes: ArraySlice<UInt8>) -> String {
    String(bytes.map { Character(UnicodeScalar($0)) })
  }

  static func latin1(_ bytes: [UInt8]) -> String {
    String(bytes.map { Character(UnicodeScalar($0)) })
  }

  static func latin1Bytes(_ string: String) -> [UInt8] {
    string.map { UInt8($0.unicodeScalars.first!.value) }
  }

  static func isPdfWhitespace(_ ch: Character) -> Bool {
    ch == " " || ch == "\n" || ch == "\r" || ch == "\t" || ch == "\u{0C}" || ch == "\u{00}"
  }

  // MARK: - startxref resolution

  static func findLastStartxrefOffset(_ data: Data) throws -> Int {
    let bytes = [UInt8](data)
    let needle = Array("startxref".utf8)
    var last: Int?
    var i = 0
    let limit = bytes.count - needle.count
    while i <= limit {
      if bytes[i] == needle[0], Array(bytes[i..<i + needle.count]) == needle {
        last = i
        i += needle.count
      } else {
        i += 1
      }
    }
    guard let marker = last else { throw WriterError.missingStartxref }
    var q = marker + needle.count
    let n = bytes.count
    while q < n, isPdfWhitespace(Character(UnicodeScalar(bytes[q]))) { q += 1 }
    var digits = ""
    while q < n, bytes[q] >= 0x30, bytes[q] <= 0x39 {
      digits.append(Character(UnicodeScalar(bytes[q])))
      q += 1
    }
    guard let offset = Int(digits), offset > 0, offset < n else {
      throw WriterError.missingStartxref
    }
    return offset
  }

  // MARK: - Xref parsing

  struct XrefInfo {
    var entries: [Int: (offset: Int, generation: Int)]
    /// Type-2 xref entries: object number → (object-stream object number,
    /// index of the object within that stream's header). Objects living in
    /// compressed object streams are RESOLVED through this map (2026-09-07:
    /// objectSpan inflates the ObjStm and extracts the object body) — the
    /// former fail-closed `compressedObject` rejection on any walk targeting
    /// a compressed object is retired; the error case now reports only
    /// genuinely undecodable object streams.
    var objectStreams: [Int: (stream: Int, index: Int)]
    /// Every object number that lives inside an object stream (derived).
    var compressedObjects: Set<Int> { Set(objectStreams.keys) }
    var trailer: [String: String]
    var size: Int
  }

  static func parseXref(_ data: Data, offset: Int) throws -> XrefInfo {
    let bytes = [UInt8](data)
    guard offset < bytes.count else { throw WriterError.unsupportedXref("offset out of range") }
    // Incremental files carry several xref sections chained by /Prev. The
    // parser must merge them (later sections win) or it cannot re-read its own
    // incrementalFieldUpdate output — object references to untouched original
    // objects would throw objectNotFound.
    var mergedEntries: [Int: (offset: Int, generation: Int)] = [:]
    var mergedObjectStreams: [Int: (stream: Int, index: Int)] = [:]
    var size = 0
    var trailer: [String: String] = [:]
    var sectionOffset = offset
    var seen = Set<Int>()
    while sectionOffset > 0, !seen.contains(sectionOffset), sectionOffset < bytes.count {
      seen.insert(sectionOffset)
      let head = latin1(bytes[sectionOffset..<min(bytes.count, sectionOffset + 5)])
      let info: XrefInfo
      if head.hasPrefix("xref") {
        info = try parseClassicXref(bytes, offset: sectionOffset)
      } else {
        info = try parseXrefStream(bytes, offset: sectionOffset)
      }
      // Newest-wins per OBJECT, not per table: an object's classification
      // (type-1 offset vs type-2 ObjStm member) is decided by the NEWEST
      // section that mentions it. Without the cross-guard, an older section's
      // stale type-1 offset could shadow a newer type-2 record (or
      // vice-versa) and objectSpan would read the wrong revision.
      for (number, entry) in info.entries
      where mergedEntries[number] == nil && mergedObjectStreams[number] == nil {
        mergedEntries[number] = entry
      }
      for (number, location) in info.objectStreams
      where mergedObjectStreams[number] == nil && mergedEntries[number] == nil {
        mergedObjectStreams[number] = location
      }
      size = max(size, info.size)
      // Keep the NEWEST section's trailer (/Root, /AcroForm, /Encrypt…): it
      // describes the current revision. The oldest section's trailer can be
      // partial or superseded (Observed: a synthetic-producer re-encode whose
      // original trailer lacks a usable /Root).
      if trailer.isEmpty { trailer = info.trailer }
      guard let prevToken = info.trailer["/Prev"],
        let prev = Int(prevToken.trimmingCharacters(in: .whitespaces)), prev > 0
      else { break }
      sectionOffset = prev
    }
    return XrefInfo(
      entries: mergedEntries, objectStreams: mergedObjectStreams,
      trailer: trailer, size: size)
  }

  private static func parseClassicXref(_ bytes: [UInt8], offset: Int) throws -> XrefInfo {
    let text = latin1(bytes[offset...])
    var entries: [Int: (offset: Int, generation: Int)] = [:]
    var size = 0
    var p = text.index(text.startIndex, offsetBy: 4)
    var trailer: [String: String] = [:]
    var sawTrailer = false
    while p < text.endIndex {
      while p < text.endIndex, isPdfWhitespace(text[p]) { p = text.index(after: p) }
      if p >= text.endIndex { break }
      if text[p...].hasPrefix("trailer") {
        p = text.index(p, offsetBy: 7)
        while p < text.endIndex, isPdfWhitespace(text[p]) { p = text.index(after: p) }
        guard p < text.endIndex, text[p] == "<" else {
          throw WriterError.malformedStructure("trailer dict")
        }
        let close = skipValue(text, p)
        let dict = String(text[p..<close])
        trailer = extractTrailerKeys(
          dict, keys: ["/Root", "/Encrypt", "/Info", "/ID", "/Size", "/Prev"])
        sawTrailer = true
        break
      }
      let startStart = p
      while p < text.endIndex, text[p].isNumber { p = text.index(after: p) }
      guard p > startStart, p < text.endIndex, isPdfWhitespace(text[p]) else {
        throw WriterError.unsupportedXref("classic subsection header")
      }
      guard let start = Int(text[startStart..<p]) else {
        throw WriterError.unsupportedXref("subsection start")
      }
      while p < text.endIndex, isPdfWhitespace(text[p]) { p = text.index(after: p) }
      let countStart = p
      while p < text.endIndex, text[p].isNumber { p = text.index(after: p) }
      guard let count = Int(text[countStart..<p]) else {
        throw WriterError.unsupportedXref("subsection count")
      }
      while p < text.endIndex, text[p] != "\n" { p = text.index(after: p) }
      if p < text.endIndex { p = text.index(after: p) }
      for i in 0..<count {
        guard p < text.endIndex else { throw WriterError.unsupportedXref("truncated entries") }
        let entryEnd = text.index(p, offsetBy: 20, limitedBy: text.endIndex) ?? text.endIndex
        let entry = String(text[p..<entryEnd])
        p = entryEnd
        let cleaned = entry.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = cleaned.split(separator: " ").map(String.init)
        if parts.count == 3, parts[2] == "n",
          let objOffset = Int(parts[0]), let gen = Int(parts[1])
        {
          entries[start + i] = (objOffset, gen)
          if start + i + 1 > size { size = start + i + 1 }
        }
      }
    }
    guard sawTrailer else { throw WriterError.unsupportedXref("no trailer") }
    let declaredSize = Int(trailer["/Size"]?.trimmingCharacters(in: .whitespaces) ?? "0") ?? size
    return XrefInfo(
        entries: entries, objectStreams: [:], trailer: trailer,
        size: max(size, declaredSize))
  }

  static func extractTrailerKeys(_ dict: String, keys: [String]) -> [String: String] {
    var result: [String: String] = [:]
    let entries = topLevelEntries(dict)
    for key in keys {
      if let match = entries.first(where: { $0.key == key }) {
        result[key] = String(dict[match.valueRange])
          .trimmingCharacters(in: .whitespacesAndNewlines)
      }
    }
    return result
  }

  

  /// RG-001: find the closing >> of the outermost dict, accounting for nested
  /// << >> pairs (e.g. /DecodeParms << /Columns 4 /Predictor 12 >>).
  /// The original first-">>" search truncates at the inner >>, silently losing
  /// /W, /Index, /Root, /Size; we track nesting depth instead.
  /// Returns the String.Index of the first character after the outermost >>,
  /// or nil if the dict close cannot be found.
  private static func dictCloseRange(_ region: String, before streamEnd: String.Index) -> String.Index? {
    var depth = 0
    var i = region.startIndex
    while i < streamEnd {
      if let openRange = region.range(of: "<<", range: i..<streamEnd) {
        depth += 1
        i = openRange.upperBound
      } else if let closeRange = region.range(of: ">>", range: i..<streamEnd) {
        depth -= 1
        if depth == 0 {
          return closeRange.upperBound
        }
        i = closeRange.upperBound
      } else {
        break
      }
    }
    return nil
  }

private static func parseXrefStream(_ bytes: [UInt8], offset: Int) throws -> XrefInfo {
    let region = latin1(bytes[offset...])
    guard let streamMarker = region.range(of: "stream") else {
      throw WriterError.unsupportedXref("xref stream has no stream keyword")
    }
    // Depth-matched dict extraction: nested dicts (/DecodeParms etc.) close
    // with the first ">>", so a naive first-match search truncates the dict
    // before /W, /Index, /Root, and /Size.
    guard let dictOpen = region.range(
      of: "<<", range: region.startIndex..<streamMarker.lowerBound)
    else { throw WriterError.unsupportedXref("xref stream dict") }
    let dictEnd = skipValue(region, dictOpen.lowerBound)
    let dict = String(region[dictOpen.lowerBound..<dictEnd])
    let trailer = extractTrailerKeys(
      dict, keys: ["/Root", "/Encrypt", "/Info", "/ID", "/Size", "/Prev"])
    guard trailer["/Encrypt"] == nil else { throw WriterError.encryptedUnsupported }
    guard dict.contains("/FlateDecode") else {
      throw WriterError.unsupportedXref("only FlateDecode xref streams are supported")
    }

    var dataStart = streamMarker.upperBound
    while dataStart < region.endIndex, region[dataStart] == "\r" || region[dataStart] == "\n" {
      dataStart = region.index(after: dataStart)
    }
    guard let endStream = region.range(of: "endstream", range: dataStart..<region.endIndex) else {
      throw WriterError.unsupportedXref("xref stream has no endstream")
    }
    let startIdx = offset + region.distance(from: region.startIndex, to: dataStart)
    let endIdx = offset + region.distance(from: region.startIndex, to: endStream.lowerBound)
    guard endIdx > startIdx, endIdx <= bytes.count else {
      throw WriterError.unsupportedXref("xref stream bounds")
    }
    guard let inflated = inflateZlib(Array(bytes[startIdx..<endIdx])) else {
      throw WriterError.unsupportedXref("xref stream inflate failed")
    }

    var widths = [1, 1, 1]
    if let wRange = dict.range(of: "/W") {
      let after = String(dict[wRange.upperBound...])
      if let open = after.firstIndex(of: "[") {
        let close = after.firstIndex(of: "]") ?? after.endIndex
        let nums = after[after.index(after: open)..<close]
          .split(whereSeparator: { isPdfWhitespace($0) }).compactMap { Int($0) }
        if nums.count == 3 { widths = nums }
      }
    }
    var indexPairs: [(Int, Int)] = []
    if let idxRange = dict.range(of: "/Index") {
      let after = String(dict[idxRange.upperBound...])
      if let open = after.firstIndex(of: "[") {
        let close = after.firstIndex(of: "]") ?? after.endIndex
        let nums = after[after.index(after: open)..<close]
          .split(whereSeparator: { isPdfWhitespace($0) }).compactMap { Int($0) }
        var i = 0
        while i + 1 < nums.count {
          indexPairs.append((nums[i], nums[i + 1]))
          i += 2
        }
      }
    } else {
      let size = Int(trailer["/Size"]?.trimmingCharacters(in: .whitespaces) ?? "0") ?? 0
      indexPairs = [(0, size)]
    }

    // /DecodeParms: PNG predictor undo. qpdf and most writers emit
    // /Predictor 12 (Up) with /Columns = sum(/W); without undo the inflated
    // bytes are filter deltas, not entry values.
    var entryBytes = inflated
    if let parmsToken = valueOfKey("/DecodeParms", in: dict), parmsToken.hasPrefix("<<") {
      let predictor =
        Int(
          valueOfKey("/Predictor", in: parmsToken)?
            .trimmingCharacters(in: .whitespaces) ?? "0") ?? 0
      if predictor >= 10 {
        guard let columnsToken = valueOfKey("/Columns", in: parmsToken),
          let parsedColumns = Int(columnsToken.trimmingCharacters(in: .whitespaces)),
          parsedColumns > 0
        else {
          throw WriterError.unsupportedXref("predictor stream without /Columns")
        }
        guard let unfiltered = applyPngUpPredictor(entryBytes, columns: parsedColumns) else {
          throw WriterError.unsupportedXref("xref stream predictor undo failed")
        }
        entryBytes = unfiltered
      } else if predictor > 0 && predictor < 10 {
        throw WriterError.unsupportedXref("unsupported TIFF predictor \(predictor)")
      }
    }

    var entries: [Int: (offset: Int, generation: Int)] = [:]
    var objectStreams: [Int: (stream: Int, index: Int)] = [:]
    var size = 0
    var pos = 0
    func readInt(_ at: Int, _ len: Int) -> Int {
      var v = 0
      for i in 0..<len where at + i < entryBytes.count {
        v = (v << 8) | Int(entryBytes[at + i])
      }
      return v
    }
    for (start, count) in indexPairs {
      for i in 0..<count {
        let type = widths[0] > 0 ? readInt(pos, widths[0]) : 1
        pos += widths[0]
        let f1 = widths[1] > 0 ? readInt(pos, widths[1]) : 0
        pos += widths[1]
        let f2 = widths[2] > 0 ? readInt(pos, widths[2]) : 0
        pos += widths[2]
        if type == 1 {
          entries[start + i] = (f1, f2)
          if start + i + 1 > size { size = start + i + 1 }
        } else if type == 2 {
          // Object lives in object stream f1 at header index f2. Resolution
          // happens on demand in objectSpan (inflate the ObjStm, walk the
          // header pairs, extract the body).
          objectStreams[start + i] = (f1, f2)
        }
      }
    }
    let declaredSize = Int(trailer["/Size"]?.trimmingCharacters(in: .whitespaces) ?? "0") ?? size
    return XrefInfo(
      entries: entries, objectStreams: objectStreams, trailer: trailer,
      size: max(size, declaredSize))
  }

  static func inflateZlib(_ bytes: [UInt8]) -> [UInt8]? {
    guard bytes.count > 6 else { return nil }
    // §7.3.8.1: the EOL preceding "endstream" is NOT part of the stream
    // data. Callers slice up to "endstream" so a trailing \r\n (or both)
    // can ride along; for compressed streams those bytes land after the
    // Adler-32 and corrupt a strict raw-DEFLATE decode (Observed
    // 2026-09-07: PDFBox-produced xref stream, 121 raw bytes → 110
    // instead of 156 decoded — every xref entry after the first 27 was
    // silently dropped). Strip them before unwrapping.
    var payload = bytes
    while let last = payload.last, last == 0x0A || last == 0x0D {
      payload.removeLast()
    }
    guard payload.count > 6 else { return nil }
    // zlib wrapper: 2-byte header + 4-byte Adler-32; COMPRESSION_ZLIB is raw
    // DEFLATE, so strip the wrapper before inflating.
    let raw = Array(payload[2..<(payload.count - 4)])
    var capacity = max(4096, raw.count * 4)
    while capacity <= 1 << 30 {
      var destination = [UInt8](repeating: 0, count: capacity)
      let written = destination.withUnsafeMutableBytes { dstBuffer -> Int in
        raw.withUnsafeBytes { srcBuffer -> Int in
          compression_decode_buffer(
            dstBuffer.bindMemory(to: UInt8.self).baseAddress!, capacity,
            srcBuffer.bindMemory(to: UInt8.self).baseAddress!, raw.count,
            nil, COMPRESSION_ZLIB)
        }
      }
      if written > 0, written < capacity {
        destination.removeSubrange(written...)
        return destination
      }
      capacity *= 2
    }
    return nil
  }

  /// Undoes PNG row filters (None = 0, Up = 2) from a predicted xref stream.
  /// Each row is one filter byte followed by `columns` data bytes. Sub/
  /// Average/Paeth rows are refused (fail closed) rather than misdecoded.
  static func applyPngUpPredictor(_ data: [UInt8], columns: Int) -> [UInt8]? {
    let rowSize = columns + 1
    guard columns > 0, rowSize > 1, !data.isEmpty, data.count % rowSize == 0 else {
      return nil
    }
    var result = [UInt8]()
    result.reserveCapacity(data.count / rowSize * columns)
    var previous = [UInt8](repeating: 0, count: columns)
    var i = 0
    while i + rowSize <= data.count {
      let filter = data[i]
      let row = Array(data[(i + 1)..<(i + rowSize)])
      switch filter {
      case 0:
        result.append(contentsOf: row)
        previous = row
      case 2:
        var unfiltered = [UInt8]()
        unfiltered.reserveCapacity(columns)
        for (index, byte) in row.enumerated() {
          unfiltered.append(byte &+ previous[index])
        }
        result.append(contentsOf: unfiltered)
        previous = unfiltered
      default:
        return nil
      }
      i += rowSize
    }
    return result
  }

  // MARK: - Object access

  static func objectSpan(
    _ data: Data, xref: XrefInfo, objectNumber: Int
  ) throws -> (generation: Int, text: String) {
    // Type-2 entry: the object lives compressed inside an object stream.
    // Inflate the ObjStm, parse its header pairs (objNum offset …), and
    // extract the object body as classic "N 0 obj … endobj" text so every
    // downstream consumer (walker, dict editor, edit resolver) is byte-shape
    // identical to the uncompressed path — no caller changes.
    if let location = xref.objectStreams[objectNumber] {
      return try extractFromObjectStream(
        data, xref: xref, objectNumber: objectNumber, streamObject: location.stream,
        headerIndex: location.index)
    }
    guard let entry = xref.entries[objectNumber] else {
      throw WriterError.objectNotFound(objectNumber)
    }
    let bytes = [UInt8](data)
    guard entry.offset >= 0, entry.offset < bytes.count else {
      throw WriterError.objectNotFound(objectNumber)
    }
    let region = latin1(bytes[entry.offset...])
    guard let endObj = region.range(of: "endobj") else {
      throw WriterError.malformedStructure("object \(objectNumber) has no endobj")
    }
    return (entry.generation, String(region[region.startIndex..<endObj.upperBound]))
  }

  /// Resolves a type-2 xref entry by inflating its containing object stream
  /// and slicing out one object body. The ObjStm itself is located through
  /// `xref` (it may live in an OLDER revision's type-1 table, or in a newer
  /// incremental section — both are covered by the merged XrefInfo).
  private static func extractFromObjectStream(
    _ data: Data, xref: XrefInfo, objectNumber: Int, streamObject: Int, headerIndex: Int
  ) throws -> (generation: Int, text: String) {
    // The ObjStm object itself must be an uncompressed type-1 object (object
    // streams may not nest). Guard anyway and report precisely if a source
    // violates that.
    guard let streamEntry = xref.entries[streamObject] else {
      throw WriterError.malformedStructure(
        "object stream \(streamObject) for object \(objectNumber) has no xref entry")
    }
    let bytes = [UInt8](data)
    guard streamEntry.offset >= 0, streamEntry.offset < bytes.count else {
      throw WriterError.malformedStructure(
        "object stream \(streamObject) offset out of range")
    }
    let region = latin1(bytes[streamEntry.offset...])
    guard let streamMarker = region.range(of: "stream") else {
      throw WriterError.malformedStructure(
        "object stream \(streamObject) has no stream keyword")
    }
    guard let dictOpen = region.range(
      of: "<<", range: region.startIndex..<streamMarker.lowerBound)
    else {
      throw WriterError.malformedStructure("object stream \(streamObject) dict missing")
    }
    let dictEnd = skipValue(region, dictOpen.lowerBound)
    let dict = String(region[dictOpen.lowerBound..<dictEnd])

    // Filter policy: FlateDecode only. The xref-stream parser enforces the
    // same policy; fail closed with a precise diagnostic on anything else
    // (LZW, RunLength, crypt filters) rather than emitting garbage.
    guard dict.contains("/FlateDecode"), !dict.contains("/Crypt") else {
      throw WriterError.unsupportedXref(
        "object stream \(streamObject) uses a filter other than FlateDecode")
    }

    var dataStart = streamMarker.upperBound
    while dataStart < region.endIndex, region[dataStart] == "\r" || region[dataStart] == "\n" {
      dataStart = region.index(after: dataStart)
    }
    guard let endStream = region.range(of: "endstream", range: dataStart..<region.endIndex)
    else {
      throw WriterError.malformedStructure(
        "object stream \(streamObject) has no endstream")
    }
    let startIdx = streamEntry.offset + region.distance(from: region.startIndex, to: dataStart)
    let endIdx = streamEntry.offset + region.distance(from: region.startIndex, to: endStream.lowerBound)
    guard endIdx > startIdx, endIdx <= bytes.count else {
      throw WriterError.malformedStructure(
        "object stream \(streamObject) content out of bounds")
    }
    guard let inflated = inflateZlib(Array(bytes[startIdx..<endIdx])) else {
      throw WriterError.unsupportedXref(
        "object stream \(streamObject) inflate failed")
    }
    let content = latin1(inflated)

    // /N: object count. /First: byte offset of the stream DATA after the
    // header. Header format: alternating <objNum> <relativeOffset> pairs.
    var objectCount = 0
    var firstOffset = 0
    if let nToken = valueOfKey("/N", in: dict),
      let n = Int(nToken.trimmingCharacters(in: .whitespaces))
    {
      objectCount = n
    }
    if let firstToken = valueOfKey("/First", in: dict),
      let first = Int(firstToken.trimmingCharacters(in: .whitespaces))
    {
      firstOffset = first
    }
    guard objectCount > 0, firstOffset > 0, firstOffset <= content.count else {
      throw WriterError.malformedStructure(
        "object stream \(streamObject) has unusable /N /First")
    }
    guard headerIndex >= 0, headerIndex < objectCount else {
      throw WriterError.malformedStructure(
        "object \(objectNumber) index \(headerIndex) out of range for object stream \(streamObject)")
    }

    // Parse exactly headerIndex+1 pairs (stop early once we have the one we
    // need — avoids quadratic scans on large ObjStms). The header is plain
    // ASCII "objNum relOffset" pairs, so a single integer cursor over the
    // inflated bytes is both simpler and safe.
    let header = Array(inflated[0..<min(firstOffset, inflated.count)])
    var cursor = 0
    var targetStart = -1
    var targetEnd = -1
    var position = 0
    func scanInt() -> Int? {
      while cursor < header.count, isPdfWhitespace(Character(UnicodeScalar(header[cursor]))) {
        cursor += 1
      }
      let begin = cursor
      while cursor < header.count, header[cursor] >= 0x30, header[cursor] <= 0x39 { cursor += 1 }
      guard cursor > begin else { return nil }
      var value = 0
      for b in header[begin..<cursor] { value = value * 10 + Int(b - 0x30) }
      return value
    }
    while true {
      guard let objNum = scanInt(), let relOffset = scanInt() else {
        // Header exhausted: if this is the LAST object in the stream its
        // body legitimately runs to end-of-data (handled below); reaching
        // the wanted index without a pair is malformed.
        break
      }
      // The pair at headerIndex identifies the requested object; its offset
      // marks the body start, and the NEXT pair's offset marks the body end.
      if position == headerIndex {
        guard objNum == objectNumber else {
          throw WriterError.malformedStructure(
            "object stream \(streamObject) header index \(headerIndex) holds object \(objNum), expected \(objectNumber) — xref/ObjStm mismatch")
        }
        targetStart = relOffset
      } else if position == headerIndex + 1 {
        targetEnd = relOffset
        break
      }
      position += 1
    }
    // Body end: the next pair's offset when present, otherwise end-of-data
    // (the last object in the stream runs to the end). Offsets are relative
    // to /First.
    if targetEnd < 0 { targetEnd = content.count - firstOffset }
    let bodyStart = firstOffset + targetStart
    let bodyEnd = min(firstOffset + targetEnd, content.count)
    guard bodyStart < bodyEnd, bodyEnd <= content.count else {
      throw WriterError.malformedStructure(
        "object \(objectNumber) has empty/oversized body in object stream \(streamObject)")
    }
    let bodyBegin = content.index(content.startIndex, offsetBy: bodyStart)
    let bodyFinish = content.index(content.startIndex, offsetBy: bodyEnd)
    let body = String(content[bodyBegin..<bodyFinish])
    // Render as a classic indirect object so downstream byte-shape consumers
    // (topLevelEntries, insertIntoDict, refObjectNumber) work unchanged.
    let text = "\(objectNumber) 0 obj\n\(body)\nendobj"
    return (0, text)
  }

  // MARK: - Dictionary scanning

  struct DictEntry {
    let key: String
    let valueRange: Range<String.Index>
    /// Span of just the key token (e.g. "/V") — removal edits delete from
    /// here through value end so no orphan whitespace/leaf remains.
    let keyRange: Range<String.Index>
  }

  /// Top-level key/value spans of the first PDF dictionary in `text`.
  static func topLevelEntries(_ text: String) -> [DictEntry] {
    var entries: [DictEntry] = []
    guard let open = text.range(of: "<<") else { return entries }
    var p = open.upperBound
    var depth = 1
    while p < text.endIndex {
      if text[p...].hasPrefix("<<") {
        depth += 1
        p = text.index(p, offsetBy: 2)
        continue
      }
      if text[p...].hasPrefix(">>") {
        depth -= 1
        p = text.index(p, offsetBy: 2)
        if depth == 0 { break }
        continue
      }
      if depth == 1, text[p] == "/" {
        let keyStart = p
        p = text.index(after: p)
        while p < text.endIndex,
          !isPdfWhitespace(text[p]), text[p] != ">", text[p] != "]", text[p] != "/"
        {
          p = text.index(after: p)
        }
        let key = String(text[keyStart..<p])
        let valueStart = p
        let valueEnd = skipValue(text, p)
        entries.append(
          DictEntry(key: key, valueRange: valueStart..<valueEnd, keyRange: keyStart..<p))
        p = valueEnd
        continue
      }
      p = text.index(after: p)
    }
    return entries
  }

  /// Consumes exactly one PDF value starting at `q`; returns the index just
  /// past it (port of the web lane's readValue).
  static func skipValue(_ text: String, _ q: String.Index) -> String.Index {
    var p = q
    let n = text.endIndex
    while p < n, isPdfWhitespace(text[p]) { p = text.index(after: p) }
    guard p < n else { return p }
    if text[p...].hasPrefix("<<") {
      var depth = 1
      p = text.index(p, offsetBy: 2)
      while p < n {
        if text[p...].hasPrefix("<<") {
          depth += 1
          p = text.index(p, offsetBy: 2)
          continue
        }
        if text[p...].hasPrefix(">>") {
          depth -= 1
          p = text.index(p, offsetBy: 2)
          if depth == 0 { return p }
          continue
        }
        if text[p] == "(" {
          p = skipString(text, p)
          continue
        }
        p = text.index(after: p)
      }
      return p
    }
    switch text[p] {
    case "[":
      var depth = 1
      p = text.index(after: p)
      while p < n {
        switch text[p] {
        case "[":
          depth += 1
        case "]":
          depth -= 1
          if depth == 0 { return text.index(after: p) }
        case "(":
          p = skipString(text, p)
          continue
        default:
          break
        }
        p = text.index(after: p)
      }
      return p
    case "(":
      return skipString(text, p)
    case "<" where text[p...].hasPrefix("<<"):
      return skipValue(text, p)
    case "<":
      p = text.index(after: p)
      while p < n, text[p] != ">" { p = text.index(after: p) }
      return p < n ? text.index(after: p) : p
    case "/":
      p = text.index(after: p)
      while p < n, !isPdfWhitespace(text[p]), text[p] != ">", text[p] != "]" {
        p = text.index(after: p)
      }
      return p
    default:
      while p < n, !isPdfWhitespace(text[p]), text[p] != ">", text[p] != "]" {
        p = text.index(after: p)
      }
      // Check for indirect reference pattern: "N G R" or "N 0 R"
      var r = p
      while r < n, isPdfWhitespace(text[r]) { r = text.index(after: r) }
      var r2 = r
      while r2 < n, text[r2].isNumber { r2 = text.index(after: r2) }
      var r3 = r2
      while r3 < n, isPdfWhitespace(text[r3]) { r3 = text.index(after: r3) }
      if r3 < n, text[r3] == "R", r2 > r {
        // This is an indirect reference: number number R
        p = text.index(after: r3)  // consume R
        return p
      }
      return p
    }
  }

  private static func skipString(_ text: String, _ q: String.Index) -> String.Index {
    var p = text.index(after: q)
    let n = text.endIndex
    while p < n {
      if text[p] == "\\" {
        p = text.index(p, offsetBy: 2, limitedBy: n) ?? n
        continue
      }
      if text[p] == ")" { return text.index(after: p) }
      p = text.index(after: p)
    }
    return p
  }

  /// Inserts or replaces top-level dict entries, preserving all other bytes.
  static func insertIntoDict(
    _ objectText: String, pairs: [(key: String, value: String)]
  ) -> String {
    guard let open = objectText.range(of: "<<") else { return objectText }
    var depth = 1
    var close = open.upperBound
    while close < objectText.endIndex {
      if objectText[close...].hasPrefix("<<") {
        depth += 1
        close = objectText.index(close, offsetBy: 2)
        continue
      }
      if objectText[close...].hasPrefix(">>") {
        depth -= 1
        if depth == 0 { break }
        close = objectText.index(close, offsetBy: 2)
        continue
      }
      if objectText[close] == "(" {
        close = skipString(objectText, close)
        continue
      }
      close = objectText.index(after: close)
    }
    guard depth == 0, close < objectText.endIndex else { return objectText }
    let base = String(objectText[objectText.startIndex..<close])
    let tail = String(objectText[close...])
    let entries = topLevelEntries(base)
    // Removals (value == removeKeySentinel) delete the whole "key value"
    // span (key start through value end) — removals and replacements both
    // mutate spans, so they must be applied in one DESCENDING position pass.
    var result = base
    var spanEdits: [(range: Range<String.Index>, text: String?)] = []
    for pair in pairs {
      guard let existing = entries.first(where: { $0.key == pair.key }) else {
        if pair.value == removeKeySentinel {
          spanEdits.append((base.startIndex..<base.startIndex, nil))
        }
        continue
      }
      let removal = pair.value == removeKeySentinel
      // Replacement edits span ONLY the value (the value span starts at the
      // whitespace after the key and the replacement re-supplies its own
      // leading space below — the original byte-preserving behavior).
      // Removal edits span key start → value end so the whole "key value"
      // leaf disappears without orphan whitespace.
      let from: String.Index =
        removal ? existing.keyRange.lowerBound : existing.valueRange.lowerBound
      let to: String.Index = existing.valueRange.upperBound
      spanEdits.append((from..<to, removal ? nil : pair.value))
    }
    for edit in spanEdits.sorted(by: { $0.range.lowerBound > $1.range.lowerBound }) {
      guard edit.range.lowerBound != edit.range.upperBound || edit.text != nil else { continue }
      var text = edit.text ?? ""
      // Replacements keep a separating space when the char before the value
      // span is not whitespace (removals swallow the key's own leading
      // boundary instead).
      if edit.text != nil, edit.range.lowerBound > result.startIndex,
        !isPdfWhitespace(result[result.index(before: edit.range.lowerBound)])
      {
        text = " \(text)"
      }
      result.replaceSubrange(edit.range, with: text)
    }
    // Missing keys append at the END of the current result — never at a
    // stale index captured before replacements changed its length (which
    // previously spliced "/AP <<…>>" inside a /V string value). Removal
    // sentinels for keys that are already absent are no-ops.
    for pair in pairs
    where pair.value != removeKeySentinel && !entries.contains(where: { $0.key == pair.key }) {
      result += " \(pair.key) \(pair.value)"
    }
    return result + tail
  }

  // MARK: - Incremental update

  /// Appends an incremental update redefining each edited object and adding
  /// any new objects, with a new xref section and `/Prev`-chained trailer.
  /// New objects are numbered sequentially after the highest existing object
  /// number; `/Size` is bumped to match. The source must remain a byte-exact
  /// prefix of the returned data (asserted after the write).
  public static func incrementalFieldUpdate(
    _ source: Data, edits: [ObjectEdit], newObjects: [String] = []
  ) throws -> Data {
    guard !edits.isEmpty || !newObjects.isEmpty else { return source }
    let xrefOffset = try findLastStartxrefOffset(source)
    let xref = try parseXref(source, offset: xrefOffset)
    guard xref.trailer["/Encrypt"] == nil else { throw WriterError.encryptedUnsupported }

    // Coalesce edits that target the same object: each appended copy is
    // rendered from the ORIGINAL object text, so two separate edits to one
    // object would produce two xref entries for the same number and the
    // later copy would silently drop the earlier copy's pairs (observed as
    // choice /V edits being clobbered by the /AP appearance edit on merged
    // field+widget objects). Merging pairs keeps every caller's keys — last
    // pair wins when the same key is edited twice.
    var merged: [Int: [String: String]] = [:]
    var order: [Int] = []
    for edit in edits {
      if merged[edit.objectNumber] == nil {
        merged[edit.objectNumber] = [:]
        order.append(edit.objectNumber)
      }
      for pair in edit.pairs {
        merged[edit.objectNumber]?[pair.0] = pair.1
      }
    }
    let coalescedEdits: [ObjectEdit] = order.map { number in
      let pairs = merged[number]!
      return ObjectEdit(
        objectNumber: number,
        pairs: pairs.map { ($0, $1) }.sorted { $0.0 < $1.0 })
    }

    var chunks: [Data] = [source]
    var total = source.count
    var subsections: [(objectNumber: Int, generation: Int, offset: Int)] = []

    for edit in coalescedEdits {
      let (generation, objectText) = try objectSpan(
        source, xref: xref, objectNumber: edit.objectNumber)
      let newBody = insertIntoDict(objectText, pairs: edit.pairs)
      var appended = latin1Bytes(newBody)
      appended.append(0x0A)
      let offset = total
      chunks.append(Data(appended))
      total += appended.count
      subsections.append((edit.objectNumber, generation, offset))
    }

    var nextNumber = max(xref.size, (edits.map { $0.objectNumber + 1 }.max() ?? 0))
    for body in newObjects {
      let objectNumber = nextNumber
      nextNumber += 1
      var appended = latin1Bytes("\(objectNumber) 0 obj\n\(body)\nendobj\n")
      let offset = total
      chunks.append(Data(appended))
      total += appended.count
      subsections.append((objectNumber, 0, offset))
    }

    var xrefBody = "xref\n"
    for entry in subsections {
      xrefBody += "\(entry.objectNumber) 1\n"
      xrefBody += String(format: "%010d %05d n \n", entry.offset, entry.generation)
    }
    let maxObject = max(xref.size, subsections.map { $0.objectNumber + 1 }.max() ?? 0)
    var trailer = "trailer\n<< /Size \(maxObject) /Prev \(xrefOffset)"
    for key in ["/Root", "/Encrypt", "/Info", "/ID"] {
      if let value = xref.trailer[key] { trailer += " \(key) \(value)" }
    }
    trailer += " >>\n"
    let xrefStart = total
    chunks.append(Data(latin1Bytes(xrefBody + trailer + "startxref\n\(xrefStart)\n%%EOF\n")))

    let output = chunks.reduce(Data(), +)
    // RG-017 invariant: the source must be a byte-exact prefix of the output.
    guard output.count > source.count, output.prefix(source.count) == source else {
      throw WriterError.malformedStructure("output is not a source-preserving prefix")
    }
    return output
  }

  // MARK: - Image stamp serialization (NM-T47, D-048 lane extension)

  struct StampPixels {
    let width: Int
    let height: Int
    let rgb: [UInt8]
    let alpha: [UInt8]?
  }

  /// Decodes encoded image bytes into normalized 8-bit device-RGB pixels plus
  /// an optional 8-bit alpha plane. PDF image XObjects carry straight alpha
  /// through a /SMask while CoreGraphics rasterizes premultiplied, so RGB
  /// values are un-premultiplied here — without this, translucent signature
  /// ink would render darkened in viewers.
  static func decodeStampPixels(_ data: Data) throws -> StampPixels {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
      throw WriterError.malformedStructure("the stamp image could not be decoded")
    }
    let width = image.width
    let height = image.height
    guard width > 0, height > 0, width * height <= 16_000_000 else {
      throw WriterError.malformedStructure(
        "the stamp image dimensions are invalid or exceed the 16M-pixel bound")
    }
    var rgba = [UInt8](repeating: 0, count: width * height * 4)
    let drawn = rgba.withUnsafeMutableBytes { buffer -> Bool in
      guard let context = CGContext(
        data: buffer.baseAddress, width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
      else { return false }
      context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
      return true
    }
    guard drawn else {
      throw WriterError.malformedStructure("the stamp image raster could not be built")
    }
    var rgb = [UInt8](repeating: 0, count: width * height * 3)
    var alpha = [UInt8](repeating: 0, count: width * height)
    var alphaUsed = false
    for pixel in 0..<(width * height) {
      let r = rgba[pixel * 4]
      let g = rgba[pixel * 4 + 1]
      let b = rgba[pixel * 4 + 2]
      let a = rgba[pixel * 4 + 3]
      if a < 255 { alphaUsed = true }
      if a == 255 || a == 0 {
        rgb[pixel * 3] = r
        rgb[pixel * 3 + 1] = g
        rgb[pixel * 3 + 2] = b
      } else {
        let scale = 255.0 / Double(a)
        rgb[pixel * 3] = UInt8(min(255, Int((Double(r) * scale).rounded())))
        rgb[pixel * 3 + 1] = UInt8(min(255, Int((Double(g) * scale).rounded())))
        rgb[pixel * 3 + 2] = UInt8(min(255, Int((Double(b) * scale).rounded())))
      }
      alpha[pixel] = a
    }
    return StampPixels(
      width: width, height: height, rgb: rgb, alpha: alphaUsed ? alpha : nil)
  }

  static func formatPdfNumber(_ value: CGFloat) -> String {
    let rounded = (value * 1000).rounded() / 1000
    if rounded == rounded.rounded() { return String(Int(rounded)) }
    return String(format: "%.3f", rounded)
  }

  /// Appends a source-preserving image stamp annotation (`/Subtype /Stamp`
  /// with an authored `/AP` appearance stream) as a chained incremental
  /// update. Placement is rotation-safe by construction — annotations live in
  /// page user space, which /Rotate never disturbs — and every existing
  /// object, including the page's other annotations, is preserved
  /// byte-for-byte (RG-017 prefix invariant, asserted below).
  ///
  /// The image is re-encoded as a FlateDecode RGB XObject plus a /SMask when
  /// the source carries transparency. Container passthrough is not attempted:
  /// PNG is not a valid PDF image filter, and DCTDecode cannot carry the
  /// alpha a signature stamp needs.
  public static func incrementalImageStamp(
    _ source: Data,
    pageIndex: Int,
    imageData: Data,
    bounds: CGRect,
    name: String
  ) throws -> Data {
    let pixels = try decodeStampPixels(imageData)
    guard bounds.width > 0, bounds.height > 0 else {
      throw WriterError.malformedStructure("the stamp bounds must have positive size")
    }

    let xrefOffset = try findLastStartxrefOffset(source)
    let xref = try parseXref(source, offset: xrefOffset)
    guard xref.trailer["/Encrypt"] == nil else { throw WriterError.encryptedUnsupported }
    guard let rootToken = xref.trailer["/Root"], let catalogNumber = refObjectNumber(rootToken)
    else {
      throw WriterError.malformedStructure("trailer has no usable /Root")
    }
    let pageObject = try pageObjectNumber(
      source, xref: xref, catalogObject: catalogNumber, pageIndex: pageIndex)

    // Existing /Annots: a direct array, a one-level indirect array (observed
    // on public-sample-form), or absent. All forms collapse into one direct
    // array carrying the existing refs plus the new annotation.
    let (_, pageText) = try objectSpan(source, xref: xref, objectNumber: pageObject)
    var existingAnnotRefs = ""
    if var annotsToken = valueOfKey("/Annots", in: pageText) {
      if !annotsToken.hasPrefix("["),
        let arrayNumber = refObjectNumber(annotsToken),
        let (_, arrayText) = try? objectSpan(source, xref: xref, objectNumber: arrayNumber),
        let open = arrayText.firstIndex(of: "["),
        let close = arrayText.lastIndex(of: "]"), open < close
      {
        annotsToken = String(arrayText[open...close])
      }
      existingAnnotRefs = arrayRefs(annotsToken).joined(separator: " ")
    }

    // New-object numbering must mirror incrementalFieldUpdate's baseline
    // exactly (max of xref size and the highest edited object + 1, in
    // newObjects order), or the appended xref would point at the wrong
    // bodies. The only edit below targets pageObject, so the baseline is
    // max(xref.size, pageObject + 1) on both sides.
    var nextNumber = max(xref.size, pageObject + 1)
    var newObjects: [String] = []

    // Foundation's compressed(using:) is unavailable on this toolchain (both
    // Data and NSData forms), so emit the RFC 1950 zlib stream by hand:
    // zlib header + raw deflate (COMPRESSION_ZLIB) + Adler-32. PDF
    // /FlateDecode requires the wrapped stream, not bare deflate.
    func zlib(_ bytes: [UInt8]) throws -> [UInt8] {
      let dstCapacity = bytes.count + bytes.count / 2 + 1024
      var dst = [UInt8](repeating: 0, count: dstCapacity)
      let encodedSize = dst.withUnsafeMutableBufferPointer { dstBuffer -> Int in
        bytes.withUnsafeBufferPointer { srcBuffer -> Int in
          guard let dstBase = dstBuffer.baseAddress,
            let srcBase = srcBuffer.baseAddress
          else { return 0 }
          return compression_encode_buffer(
            dstBase, dstCapacity, srcBase, bytes.count, nil, COMPRESSION_ZLIB)
        }
      }
      guard encodedSize > 0 else {
        throw WriterError.malformedStructure(
          "zlib compression failed for \(bytes.count) bytes")
      }
      var stream: [UInt8] = [0x78, 0x9C]
      stream.append(contentsOf: dst[0..<encodedSize])
      let adler = adler32(bytes)
      stream.append(UInt8((adler >> 24) & 0xFF))
      stream.append(UInt8((adler >> 16) & 0xFF))
      stream.append(UInt8((adler >> 8) & 0xFF))
      stream.append(UInt8(adler & 0xFF))
      return stream
    }

    func adler32(_ bytes: [UInt8]) -> UInt32 {
      var a: UInt32 = 1
      var b: UInt32 = 0
      for byte in bytes {
        a = (a + UInt32(byte)) % 65_521
        b = (b + a) % 65_521
      }
      return (b << 16) | a
    }
    func flateImageBody(_ header: String, _ payload: [UInt8]) throws -> String {
      "\(header) /Length \(payload.count) >>\nstream\n\(latin1(payload))\nendstream"
    }

    var smaskObjectNumber: Int?
    if let alpha = pixels.alpha {
      let number = nextNumber
      nextNumber += 1
      smaskObjectNumber = number
      newObjects.append(try flateImageBody(
        "<< /Type /XObject /Subtype /Image /Width \(pixels.width) /Height \(pixels.height)"
          + " /ColorSpace /DeviceGray /BitsPerComponent 8 /Filter /FlateDecode",
        try zlib(alpha)))
    }

    let imageNumber = nextNumber
    nextNumber += 1
    var imageHeader =
      "<< /Type /XObject /Subtype /Image /Width \(pixels.width) /Height \(pixels.height)"
      + " /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /FlateDecode"
    if let smask = smaskObjectNumber { imageHeader += " /SMask \(smask) 0 R" }
    newObjects.append(try flateImageBody(imageHeader, try zlib(pixels.rgb)))

    let appearanceNumber = nextNumber
    let annotationNumber = appearanceNumber + 1
    nextNumber += 2

    let width = formatPdfNumber(bounds.width)
    let height = formatPdfNumber(bounds.height)
    let appearanceStream = "q \(width) 0 0 \(height) 0 0 cm /Im0 Do Q"
    newObjects.append(
      "<< /Type /XObject /Subtype /Form /BBox [0 0 \(width) \(height)]"
        + " /Resources << /XObject << /Im0 \(imageNumber) 0 R >> >>"
        + " /Length \(appearanceStream.utf8.count) >>\nstream\n\(appearanceStream)\nendstream")

    let rect =
      "\(formatPdfNumber(bounds.minX)) \(formatPdfNumber(bounds.minY)) "
      + "\(formatPdfNumber(bounds.maxX)) \(formatPdfNumber(bounds.maxY))"
    let safeName = String(name.map {
      $0.isASCII && $0 != "(" && $0 != ")" && $0 != "\\" ? $0 : "-"
    })
    newObjects.append(
      "<< /Type /Annot /Subtype /Stamp /Rect [\(rect)] /F 4 /NM (\(safeName))"
        + " /P \(pageObject) 0 R /AP << /N \(appearanceNumber) 0 R >> >>")

    // /Annots must reference an ARRAY of annotation dictionaries (directly
    // or indirectly) — a bare "N 0 R" pointing at the annotation dict itself
    // is invalid and PDFKit silently drops the whole annotation set.
    let annotsValue = existingAnnotRefs.isEmpty
      ? "[\(annotationNumber) 0 R]"
      : "[\(existingAnnotRefs) \(annotationNumber) 0 R]"
    let pageEdit = PDFIncrementalFormWriter.ObjectEdit(
      objectNumber: pageObject,
      pairs: [("/Annots", annotsValue)])

    let updated = try incrementalFieldUpdate(
      source, edits: [pageEdit], newObjects: newObjects)
    guard updated.prefix(source.count) == source else {
      throw WriterError.malformedStructure("stamp output diverged from the source prefix")
    }
    return updated
  }

  /// Resolves the page-tree node for `pageIndex` in DOCUMENT order (via
  /// /Kids), which object-number scan order does not guarantee.
  private static func pageObjectNumber(
    _ source: Data, xref: XrefInfo, catalogObject: Int, pageIndex: Int
  ) throws -> Int {
    let (_, catalogText) = try objectSpan(source, xref: xref, objectNumber: catalogObject)
    guard let pagesToken = valueOfKey("/Pages", in: catalogText),
      let pagesNumber = refObjectNumber(pagesToken)
    else {
      throw WriterError.malformedStructure("catalog has no /Pages tree")
    }
    var index = pageIndex
    var visited: Set<Int> = []
    var current = pagesNumber
    while true {
      guard visited.insert(current).inserted else {
        throw WriterError.malformedStructure("cycle in the page tree")
      }
      let (_, text) = try objectSpan(source, xref: xref, objectNumber: current)
      guard let kidsToken = valueOfKey("/Kids", in: text) else {
        // Leaf page: reached the requested index or the tree is short.
        guard index == 0 else {
          throw WriterError.malformedStructure(
            "stamp page index \(pageIndex) is out of range")
        }
        return current
      }
      var descended = false
      for ref in arrayRefs(kidsToken) {
        guard let kid = refObjectNumber(ref) else { continue }
        if let count = subtreePageCount(source, xref: xref, objectNumber: kid), index >= count {
          index -= count
          continue
        }
        current = kid
        descended = true
        break
      }
      guard descended else {
        throw WriterError.malformedStructure("stamp page index \(pageIndex) is out of range")
      }
    }
  }

  private static func subtreePageCount(
    _ source: Data, xref: XrefInfo, objectNumber: Int
  ) -> Int? {
    guard let (_, text) = try? objectSpan(source, xref: xref, objectNumber: objectNumber)
    else { return nil }
    guard valueOfKey("/Kids", in: text) != nil
      || valueOfKey("/Type", in: text)?.hasPrefix("/Pages") == true
    else { return 1 }
    guard let token = valueOfKey("/Count", in: text) else { return nil }
    return Int(token.trimmingCharacters(in: .whitespaces))
  }

  // MARK: - AcroForm tree walking

  public struct FormObjectNode {
    public let objectNumber: Int
    public let fullyQualifiedName: String
    public let isWidget: Bool
    public let rect: [Double]?
    public let buttonStates: [String]
    public let fieldType: String?
    public let childObjectNumbers: [Int]
    /// Field-level value (`/V`): the export value for buttons, the string for
    /// text/choice. Names are stored without the leading slash (e.g. "1").
    public let value: String?
    /// Widget appearance state (`/AS`): which appearance the widget currently
    /// renders (e.g. "1"/"Off" for a radio kid). Name, no leading slash.
    public let appearanceState: String?
    /// Choice-field option values (`/Opt`) when the node carries them.
    /// Plain string arrays decode as themselves; `[export, display]` pair
    /// arrays decode as the export element (PDF 32000-1 §12.7.5.4, Table 247).
    public let optionValues: [String]
    /// Display strings for pair-form `/Opt` elements (`[export display]`).
    /// Index-aligned with `optionValues`; display == export for plain-string
    /// options. Viewers expose this string through their field APIs while
    /// `/V` carries the export — callers comparing viewer reads must accept
    /// either (Measured 2026-09-06: PDFKit `widgetStringValue` reports
    /// "Ground (5-7 days)" after an incremental write of /V=ground).
    public let optionDisplayValues: [String]
    /// The widget's /AP /N on-state name: any appearance-state key other than
    /// "Off". For /Opt-mapped radio groups the state name is producer-chosen
    /// (e.g. /0 /1) and unrelated to the export value — the mapping is
    /// positional via /Opt (Measured 2026-09-06, pdf-lib select()).
    public let appearanceStateOnName: String?
    /// True when the node declares the choice /Ff combo bit (18, value 262144).
    public let isCombo: Bool
    /// True when the node declares the choice /Ff multi-select bit
    /// (22, value 2097152 = 1 << 21). Multi-select listboxes carry an ARRAY
    /// /V (one string per selected export) and SHOULD carry /I, the sorted
    /// option indices of the selection (§12.7.5.4, Table 247; measured
    /// against pdf-lib PDFAcroChoice.setValues which writes both).
    public let isMultiSelect: Bool
    /// All string elements of /V when /V is an ARRAY (multi-select choice).
    /// Empty when /V is absent or single-valued (then `value` carries it).
    public let values: [String]
    /// Sorted option indices decoded from /I (multi-select selection),
    /// empty when /I is absent.
    public let selectedIndices: [Int]

    init(
      objectNumber: Int, fullyQualifiedName: String, isWidget: Bool, rect: [Double]?,
      buttonStates: [String], fieldType: String?, childObjectNumbers: [Int],
      value: String? = nil, appearanceState: String? = nil,
      optionValues: [String] = [], isCombo: Bool = false,
      optionDisplayValues: [String] = [],
      appearanceStateOnName: String? = nil,
      values: [String] = [],
      isMultiSelect: Bool = false,
      selectedIndices: [Int] = []
    ) {
      self.objectNumber = objectNumber
      self.fullyQualifiedName = fullyQualifiedName
      self.isWidget = isWidget
      self.rect = rect
      self.buttonStates = buttonStates
      self.fieldType = fieldType
      self.childObjectNumbers = childObjectNumbers
      self.value = value
      self.appearanceState = appearanceState
      self.optionValues = optionValues
      self.optionDisplayValues = optionDisplayValues
      self.appearanceStateOnName = appearanceStateOnName
        ?? buttonStates.first(where: {
          $0.lowercased() != "/off" && !$0.isEmpty && $0.lowercased() != "off"
        }).map { $0.hasPrefix("/") ? String($0.dropFirst()) : $0 }
      self.isCombo = isCombo
      self.values = values
      self.isMultiSelect = isMultiSelect
      self.selectedIndices = selectedIndices
    }
  }

  /// Extended AcroForm model with document-level safety facts.
  public struct AcroFormModel {
    public let nodes: [FormObjectNode]
    /// The /AcroForm dictionary's own object number (for NeedAppearances-style
    /// patches), when found as an indirect reference.
    public let acroFormObjectNumber: Int?
    /// Raw /SigFlags value from the AcroForm dict; nil when absent.
    public let sigFlags: Int?
    /// True when any walked field declares /FT /Sig.
    public let hasSignatureField: Bool
  }

  /// Walks the AcroForm field tree over raw (uncompressed) objects.
  public static func walkAcroForm(_ source: Data) throws -> [FormObjectNode] {
    try walkAcroFormModel(source).nodes
  }

  public static func walkAcroFormModel(_ source: Data) throws -> AcroFormModel {
    let xrefOffset = try findLastStartxrefOffset(source)
    let xref = try parseXref(source, offset: xrefOffset)
    guard xref.trailer["/Encrypt"] == nil else { throw WriterError.encryptedUnsupported }
    guard let rootToken = xref.trailer["/Root"], let catalogNumber = refObjectNumber(rootToken)
    else {
      throw WriterError.malformedStructure("trailer has no usable /Root")
    }
    let (_, catalogText) = try objectSpan(source, xref: xref, objectNumber: catalogNumber)
    guard let acroFormToken = valueOfKey("/AcroForm", in: catalogText),
      let acroFormNumber = refObjectNumber(acroFormToken)
    else {
      throw WriterError.malformedStructure("catalog has no indirect /AcroForm")
    }
    let (_, acroFormText) = try objectSpan(source, xref: xref, objectNumber: acroFormNumber)
    guard let fieldsToken = valueOfKey("/Fields", in: acroFormText) else {
      throw WriterError.malformedStructure("AcroForm has no /Fields")
    }
    var nodes: [FormObjectNode] = []
    var walkedObjects: Set<Int> = []
    for ref in arrayRefs(fieldsToken) {
      guard let number = refObjectNumber(ref) else { continue }
      try walkField(
        source, xref: xref, objectNumber: number, parentPath: "", visited: [],
        into: &nodes)
      walkedObjects.insert(number)
    }
    for node in nodes { walkedObjects.insert(node.objectNumber) }
    // Orphan-widget merge: some producers (and PDFKit's own writer — Observed
    // 2026-09-06 on public-sample-form: applicant.name / applicant.notes
    // carry /FT /Tx + /T but appear ONLY in the page /Annots arrays, not in
    // AcroForm /Fields) leave field widgets outside the field tree. Walk
    // every page's /Annots and merge the widgets the tree walk missed so
    // edits resolve for the same field set PDFKit exposes.
    for (_, pageText) in pageObjects(source, xref: xref) {
      guard var annotsToken = valueOfKey("/Annots", in: pageText) else { continue }
      // /Annots may be an indirect array object (Observed 2026-09-06 on
      // public-sample-form: /Annots 9 0 R where obj 9 is the bare array
      // [10 0 R …]). Resolve one level of indirection before parsing refs.
      if !annotsToken.hasPrefix("["), let arrNumber = refObjectNumber(annotsToken),
        let (_, arrText) = try? objectSpan(source, xref: xref, objectNumber: arrNumber)
      {
        // objectSpan returns the full "N 0 obj … endobj" region — extract the
        // bracketed array body for arrayRefs.
        if let open = arrText.firstIndex(of: "["), let close = arrText.lastIndex(of: "]"),
          open < close
        {
          annotsToken = String(arrText[open...close])
        }
      }
      for ref in arrayRefs(annotsToken) {
        guard let number = refObjectNumber(ref), !walkedObjects.contains(number)
        else { continue }
        let before = nodes.count
        try? walkField(
          source, xref: xref, objectNumber: number, parentPath: "", visited: [],
          into: &nodes)
        if nodes.count > before { walkedObjects.insert(number) }
      }
    }
    // RG-014 parity: signature-field presence through /SigFlags or /FT /Sig.
    var sigFlags: Int?
    if let sigFlagsToken = valueOfKey("/SigFlags", in: acroFormText) {
      sigFlags = Int(sigFlagsToken.trimmingCharacters(in: .whitespaces))
    }
    let hasSignatureField =
      nodes.contains { $0.fieldType == "Sig" } || (sigFlags.map { $0 != 0 } ?? false)
    return AcroFormModel(
      nodes: nodes, acroFormObjectNumber: acroFormNumber, sigFlags: sigFlags,
      hasSignatureField: hasSignatureField)
  }

  /// Yields every object in the file that is a page dictionary
  /// (`/Type /Page`). Used by the orphan-widget merge — producers may attach
  /// field widgets to a page's /Annots without listing them in AcroForm
  /// /Fields, and those fields must still resolve for edits.
  private static func pageObjects(
    _ source: Data, xref: XrefInfo
  ) -> [(number: Int, text: String)] {
    var pages: [(Int, String)] = []
    for number in 1..<xref.size {
      guard let (_, text) = try? objectSpan(source, xref: xref, objectNumber: number)
      else { continue }
      if valueOfKey("/Type", in: text)?.hasPrefix("/Page") == true {
        pages.append((number, text))
      }
    }
    return pages
  }

  private static func walkField(
    _ source: Data,
    xref: XrefInfo,
    objectNumber: Int,
    parentPath: String,
    visited: [Int],
    into nodes: inout [FormObjectNode]
  ) throws {
    guard !visited.contains(objectNumber) else {
      throw WriterError.malformedStructure("cycle in AcroForm tree at object \(objectNumber)")
    }
    let (_, text) = try objectSpan(source, xref: xref, objectNumber: objectNumber)
    let partial = valueOfKey("/T", in: text).map(decodePdfTextString)
    let fqn = partial.map { parentPath.isEmpty ? $0 : "\(parentPath).\($0)" } ?? parentPath
    let isWidget = valueOfKey("/Subtype", in: text)?.hasPrefix("/Widget") == true
      || valueOfKey("/Rect", in: text) != nil
    let rect = valueOfKey("/Rect", in: text).flatMap(parseNumberArray)
    let fieldType = valueOfKey("/FT", in: text).map(trimName)
    var buttonStates: [String] = []
    // Extract /AP state names on any node carrying an appearance dict:
    // widget kids inherit /FT from their parent, so keying on /FT alone
    // would miss radio/checkbox kid states.
    if let apToken = valueOfKey("/AP", in: text) {
      buttonStates = appearanceStates(source, xref: xref, apToken: apToken)
    }
    let kidRefs = valueOfKey("/Kids", in: text).map(arrayRefs) ?? []
    // /V may be a name (buttons: /1, /Off), a string (text/choice), or an
    // ARRAY of strings (multi-select choice). Array tokens do NOT populate
    // `value` — a decoded array token would be garbage; they land in
    // `values` below.
    let value: String?
    if let vToken = valueOfKey("/V", in: text), !vToken.hasPrefix("[") {
      if vToken.hasPrefix("/") {
        value = String(vToken.dropFirst())
      } else {
        value = decodePdfTextString(vToken)
      }
    } else {
      value = nil
    }
    // /AS is always a name on widget kids.
    let appearanceState = valueOfKey("/AS", in: text).map { String($0.dropFirst()) }
    // Choice fields carry their options in /Opt (§12.7.5.4): a string array,
    // or an array of [export, display] pairs — export element wins for the
    // structural value model, matching what /V must contain.
    var optionValues: [String] = []
    var optionDisplayValues: [String] = []
    // /Opt appears on choice fields AND on radio-group /Btn fields
    // (§12.7.5.4 Table 247: it positionally maps export values to widget
    // kids — Observed 2026-09-06 on compressed-acroform: /Btn radio with
    // /Opt [<hex email> <hex phone>] and kid states /0 /1). Parsing it only
    // for Ch made /Opt radios unresolvable for exports.
    if fieldType == "Ch" || fieldType == "Btn",
      let optToken = valueOfKey("/Opt", in: text)
    {
      optionValues = parseChoiceOptArray(optToken)
      optionDisplayValues = parseChoiceOptDisplayArray(optToken)
    }
    // Combo bit (18) on choice fields: editable text entry is allowed.
    let isCombo =
      fieldType == "Ch"
      && valueOfKey("/Ff", in: text).flatMap(Int.init).map { $0 & 262_144 != 0 } == true
    // Multi-select bit (22, 1 << 21 = 2097152) on choice fields: the /V may
    // hold an array of selected export values and /I the sorted selection
    // indices (PDF 32000-1 §12.7.5.4 Table 247).
    let isMultiSelect =
      fieldType == "Ch"
      && valueOfKey("/Ff", in: text).flatMap(Int.init).map { $0 & 2_097_152 != 0 } == true
    // Array /V: when present, /V is the multi-select value array. Elements
    // are text strings; names (unlikely but producer-seen) decode name-only.
    // Single-valued /V already landed in `value` above; arrays do NOT
    // populate `value` — callers must read `values` for the multi form so a
    // single-selection write can never masquerade as an array read.
    var values: [String] = []
    var selectedIndices: [Int] = []
    if let vToken = valueOfKey("/V", in: text), vToken.hasPrefix("[") {
      values = parseChoiceOptArray(vToken)
    }
    if let iTokens = valueOfKey("/I", in: text).flatMap({ parseNumberArray($0) }), !iTokens.isEmpty {
      selectedIndices = iTokens.map { Int($0) }.filter { $0 >= 0 }
    }
    let node = FormObjectNode(
      objectNumber: objectNumber,
      fullyQualifiedName: fqn,
      isWidget: isWidget,
      rect: rect,
      buttonStates: buttonStates,
      fieldType: fieldType,
      childObjectNumbers: kidRefs.compactMap(refObjectNumber),
      value: value,
      appearanceState: appearanceState,
      optionValues: optionValues,
      isCombo: isCombo,
      optionDisplayValues: optionDisplayValues,
      values: values,
      isMultiSelect: isMultiSelect,
      selectedIndices: selectedIndices
    )
    nodes.append(node)
    for kid in kidRefs {
      guard let kidNumber = refObjectNumber(kid) else { continue }
      try walkField(
        source, xref: xref, objectNumber: kidNumber, parentPath: fqn,
        visited: visited + [objectNumber], into: &nodes)
    }
  }

  /// Extracts the appearance-state names (/AP /N dict keys) for button fields.
  ///
  /// Producers differ in how /AP /N is stored, so resolution follows
  /// indirection like a viewer would:
  /// - inline:  `/AP << /N << /Yes 12 0 R /Off 13 0 R >> >>`
  /// - indirect: `/AP 18 0 R` where 18 is `<< /N 28 0 R >>` and 28 is
  ///   itself an appearance-characteristics dict (`<< /D … /N 33 0 R >>`)
  ///   whose /N finally maps state names to streams (Observed on the
  ///   PDFKit-produced public-acroform fixture).
  static func appearanceStates(_ source: Data, xref: XrefInfo, apToken: String) -> [String] {
    func resolveToDictText(_ token: String, hops: Int) -> String? {
      let t = token.trimmingCharacters(in: .whitespacesAndNewlines)
      if hops > 6 { return nil }
      if t.hasPrefix("<<") { return t }
      guard let number = refObjectNumber(t),
        let (_, text) = try? objectSpan(source, xref: xref, objectNumber: number)
      else { return nil }
      return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    func stateKeys(_ dictText: String) -> [String] {
      let entries = topLevelEntries(dictText)
      guard let n = entries.first(where: { $0.key == "/N" }),
        var current = resolveToDictText(
          String(dictText[n.valueRange]), hops: 0)
      else { return [] }
      // Follow the /N value through nested characteristic dicts until the
      // terminal state map (a dict whose keys are the state names).
      var hops = 0
      while hops < 6 {
        let keys = topLevelEntries(current).map { $0.key }
        // Appearance-characteristics dict: /D /R /N point at sub-dicts.
        // Re-enter via its /N (normal appearance) sub-map.
        if keys.contains("/N"), keys.count <= 3 {
          if let n = topLevelEntries(current).first(where: { $0.key == "/N" }),
            let next = resolveToDictText(
              String(current[n.valueRange]), hops: hops + 1) {
            current = next
            hops += 1
            continue
          }
        }
        return keys
      }
      return []
    }
    if apToken.hasPrefix("<<") { return stateKeys(apToken) }
    guard let apNumber = refObjectNumber(apToken),
      let (_, apText) = try? objectSpan(source, xref: xref, objectNumber: apNumber)
    else { return [] }
    return stateKeys(apText)
  }

  // MARK: - Token helpers

  static func refObjectNumber(_ token: String) -> Int? {
    let parts = token.split(whereSeparator: { isPdfWhitespace($0) }).map(String.init)
    guard parts.count >= 3, parts[2] == "R", let number = Int(parts[0]) else { return nil }
    return number
  }

  static func arrayRefs(_ token: String) -> [String] {
    guard token.hasPrefix("["), token.hasSuffix("]") else { return [] }
    let inner = token.dropFirst().dropLast()
    var refs: [String] = []
    var current = ""
    var depth = 0
    for ch in inner {
      if ch == "(" {
        depth += 1
      } else if ch == ")" && depth > 0 {
        depth -= 1
      }
      if ch == "R" && depth == 0 {
        current.append(ch)
        refs.append(current.trimmingCharacters(in: .whitespaces))
        current = ""
        continue
      }
      current.append(ch)
    }
    return refs
  }

  static func parseNumberArray(_ token: String) -> [Double]? {
    guard token.hasPrefix("["), token.hasSuffix("]") else { return nil }
    let numbers = token.dropFirst().dropLast()
      .split(whereSeparator: { isPdfWhitespace($0) }).compactMap { Double($0) }
    return numbers.isEmpty ? nil : numbers
  }

  /// Splits a PDF array token into its top-level elements (strings, names,
  /// numbers, or nested arrays), respecting string/nesting boundaries.
  static func topLevelArrayElements(_ token: String) -> [String] {
    guard token.hasPrefix("["), token.hasSuffix("]"), token.count >= 2 else { return [] }
    let inner = String(token.dropFirst().dropLast())
    var elements: [String] = []
    var current = ""
    var bracketDepth = 0
    var inString = false
    var escape = false
    for ch in inner {
      if escape {
        current.append(ch)
        escape = false
        continue
      }
      if inString {
        current.append(ch)
        if ch == "\\" {
          escape = true
        } else if ch == ")" {
          inString = false
        }
        continue
      }
      switch ch {
      case "(":
        inString = true
        current.append(ch)
      case "[":
        bracketDepth += 1
        current.append(ch)
      case "]":
        bracketDepth = max(0, bracketDepth - 1)
        current.append(ch)
      case " ", "\t", "\n", "\r":
        if bracketDepth == 0 {
          if !current.isEmpty { elements.append(current); current = "" }
        } else {
          current.append(ch)
        }
      default:
        current.append(ch)
      }
    }
    if !current.isEmpty { elements.append(current) }
    return elements
  }

  /// Decodes a choice field's `/Opt` array into export values.
  ///
  /// Per PDF 32000-1 §12.7.5.4 (Table 247) each element is either a text
  /// string (export value == display value) or a two-element array
  /// `[export, display]`. Anything else (names, numbers, malformed) is
  /// decoded best-effort; unparseable elements are skipped rather than
  /// invented, so callers never see phantom options.
  static func parseChoiceOptArray(_ token: String) -> [String] {
    var values: [String] = []
    for element in topLevelArrayElements(token) {
      let t = element.trimmingCharacters(in: .whitespacesAndNewlines)
      if t.hasPrefix("[") {
        // Pair form: first element is the export value.
        let pair = topLevelArrayElements(t)
        if let first = pair.first {
          values.append(decodePdfTextString(first))
        }
      } else if t.hasPrefix("(") || t.hasPrefix("<") {
        values.append(decodePdfTextString(t))
      } else if t.hasPrefix("/") {
        values.append(String(t.dropFirst()))
      }
    }
    return values
  }

  /// Decodes a choice field's `/Opt` array into the DISPLAY strings viewers
  /// show. Index-aligned with `parseChoiceOptArray` results; for plain string
  /// elements display == export, for pair form `[export display]` it is the
  /// second element (export when the pair omits it).
  static func parseChoiceOptDisplayArray(_ token: String) -> [String] {
    var values: [String] = []
    for element in topLevelArrayElements(token) {
      let t = element.trimmingCharacters(in: .whitespacesAndNewlines)
      if t.hasPrefix("[") {
        let pair = topLevelArrayElements(t)
        if pair.count >= 2 {
          values.append(decodePdfTextString(pair[1]))
        } else if let first = pair.first {
          values.append(decodePdfTextString(first))
        } else {
          values.append("")
        }
      } else if t.hasPrefix("(") || t.hasPrefix("<") {
        values.append(decodePdfTextString(t))
      } else if t.hasPrefix("/") {
        values.append(String(t.dropFirst()))
      } else {
        values.append("")
      }
    }
    return values
  }

  static func trimName(_ token: String) -> String {
    var t = token.trimmingCharacters(in: .whitespacesAndNewlines)
    if t.hasPrefix("/") { t.removeFirst() }
    return t
  }

  /// Decodes a PDF text string token (/T values): UTF-16BE hex strings with
  /// BOM, bare hex strings (PDFDocEncoding approximated as latin1), or literal
  /// strings. Field names in real-world AcroForms are frequently hex-encoded.
  static func decodePdfTextString(_ token: String) -> String {
    let t = token.trimmingCharacters(in: .whitespacesAndNewlines)
    if t.hasPrefix("<"), t.hasSuffix(">"), t.count >= 4 {
      let hex = t.dropFirst().dropLast()
      var bytes: [UInt8] = []
      var iterator = hex.makeIterator()
      while let high = iterator.next(), let low = iterator.next() {
        if let value = UInt8(String([high, low]), radix: 16) { bytes.append(value) }
      }
      if bytes.count >= 2, bytes[0] == 0xFE, bytes[1] == 0xFF {
        var codeUnits: [UInt16] = []
        var i = 2
        while i + 1 < bytes.count {
          codeUnits.append(UInt16(bytes[i]) << 8 | UInt16(bytes[i + 1]))
          i += 2
        }
        return String(utf16CodeUnits: codeUnits, count: codeUnits.count)
      }
      return latin1(bytes)
    }
    if t.hasPrefix("("), t.hasSuffix(")"), t.count >= 2 {
      // PDF literal strings support \ddd octal escapes (1–3 octal digits,
      // decoding to a single byte) plus \n \r \t \b \f \( \) \\.
      // Real-world producers escape non-ASCII partial names — e.g. PDFKit
      // writes (applicant\056contact) for a dotted field name — so the FQN
      // must be fully decoded or tree walkers cannot match "applicant.contact".
      return decodeLiteralString(String(t.dropFirst().dropLast()))
    }
    return t
  }

  /// Decodes a PDF literal-string body: \ddd octal escapes and the standard
  /// \n \r \t \b \f \( \) \\ escapes. Unknown escapes keep the escaped
  /// character literally.
  static func decodeLiteralString(_ body: String) -> String {
    var out: [UInt8] = []
    let scalars = Array(body.unicodeScalars)
    var i = 0
    while i < scalars.count {
      let c = scalars[i]
      if c != "\\" {
        if c.value < 256 {
          out.append(UInt8(c.value))
        } else {
          out.append(contentsOf: Array(String(c).utf8))
        }
        i += 1
        continue
      }
      // Escape sequence.
      guard i + 1 < scalars.count else { break }
      let next = scalars[i + 1]
      if next.value >= 0x30 && next.value <= 0x37 {
        // Octal \ddd: consume up to 3 octal digits.
        var value = 0
        var digits = 0
        var j = i + 1
        while j < scalars.count, digits < 3,
              scalars[j].value >= 0x30, scalars[j].value <= 0x37 {
          value = value * 8 + Int(scalars[j].value - 0x30)
          j += 1
          digits += 1
        }
        out.append(UInt8(value & 0xFF))
        i = j
      } else {
        switch next {
        case "n": out.append(0x0A)
        case "r": out.append(0x0D)
        case "t": out.append(0x09)
        case "b": out.append(0x08)
        case "f": out.append(0x0C)
        default:
          if next.value < 256 { out.append(UInt8(next.value)) }
        }
        i += 2
      }
    }
    return latin1(out)
  }

  static func valueOfKey(_ key: String, in objectText: String) -> String? {
    let entries = topLevelEntries(objectText)
    guard let match = entries.first(where: { $0.key == key }) else { return nil }
    return String(objectText[match.valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
// MARK: - Edit-plan resolution

extension PDFIncrementalFormWriter {
  /// A complete edit plan: redefinitions of existing objects plus brand-new
  /// objects (appearance streams, fonts) numbered by the writer.
  public struct ResolvedEditPlan {
    public let objectEdits: [ObjectEdit]
    public let newObjectBodies: [String]

    public init(objectEdits: [ObjectEdit], newObjectBodies: [String] = []) {
      self.objectEdits = objectEdits
      self.newObjectBodies = newObjectBodies
    }
  }

  /// Builds object-level edits for one native field-value operation.
  ///
  /// Semantics mirror the verified web lane: text/choice fields get `/V` on
  /// their terminal field node; radio groups get `/V` on the field node plus
  /// `/AS` on every widget kid (selected state on, `/Off` on siblings);
  /// merged field/widget objects get both keys on the same object.
  public static func resolveEdits(
    nodes: [FormObjectNode],
    targetFieldName: String,
    requestedValue: String
  ) throws -> [ObjectEdit] {
    // Compatibility wrapper without appearance generation (no source bytes).
    let fieldNodes = nodes.filter { $0.fullyQualifiedName == targetFieldName }
    guard !fieldNodes.isEmpty else { throw WriterError.fieldNotFound(targetFieldName) }
    let terminal =
      fieldNodes.first { !$0.isWidget || fieldNodes.count == 1 }
      ?? fieldNodes[0]
    let widgetKids = nodes.filter {
      $0.isWidget && $0.objectNumber != terminal.objectNumber
        && $0.fullyQualifiedName == targetFieldName
    }
    if terminal.fieldType == "Btn" {
      return try buttonEdits(
        terminal: terminal, widgetKids: widgetKids,
        targetFieldName: targetFieldName, requestedValue: requestedValue)
    }
    return [
      ObjectEdit(objectNumber: terminal.objectNumber, pairs: [("/V", pdfString(requestedValue))])
    ]
  }

  /// Full edit plan with appearance-stream generation for text/choice edits.
  ///
  /// The edited widget receives a self-contained `/AP /N` Form XObject
  /// (Helvetica, own /Resources) so strict viewers render the new value
  /// without relying on `/NeedAppearances` regeneration — which would force
  /// unrelated fields to re-render and is therefore deliberately avoided.
  /// Resolves the edit plan for setting a MULTI-SELECT listbox selection.
  ///
  /// PDF 32000-1 §12.7.5.4 (Table 247): with /Ff bit 22 set, /V is an array
  /// of selected export strings and /I the sorted option indices. Measured
  /// against pdf-lib PDFAcroChoice.setValues: for >1 selections it writes
  /// /V as a string array AND /I as sorted indices; for exactly one
  /// selection /V is a single string and /I is deleted; for an empty
  /// selection /V is deleted entirely. This plan reproduces all three
  /// shapes:
  /// - values empty:            delete /V (and /I) — empty multi-selection
  /// - values single:           /V as one string, /I removed
  /// - values multi:            /V array + /I sorted indices, /Ff OR bit 22
  ///
  /// Writes /V on the terminal field node (tree layout) or the merged
  /// field+widget object. Throws when any requested export is not in the
  /// field's /Opt vocabulary (fail closed — callers must not write phantom
  /// selections) or when the field is not a choice field.
  public static func resolveMultiSelectEditPlan(
    nodes: [FormObjectNode],
    targetFieldName: String,
    requestedValues: [String],
    source: Data
  ) throws -> ResolvedEditPlan {
    let fieldNodes = nodes.filter { $0.fullyQualifiedName == targetFieldName && $0.fieldType == "Ch" }
    guard let terminal = fieldNodes.first(where: { !$0.isWidget })
      ?? fieldNodes.first else {
      throw WriterError.fieldNotFound(targetFieldName)
    }
    let options = terminal.optionValues
    let displays = terminal.optionDisplayValues
    // Resolve each request against exports OR display strings (viewers
    // accept either; /Opt pairs map display→export positionally).
    func resolveExport(_ request: String) -> String? {
      if options.contains(request) { return request }
      if let idx = displays.firstIndex(of: request), idx < options.count {
        return options[idx]
      }
      return nil
    }
    // Dedup while preserving request order.
    var exports: [String] = []
    for request in requestedValues {
      guard let export = resolveExport(request) else {
        throw WriterError.requestedStateUnavailable(
          field: targetFieldName, state: request)
      }
      if !exports.contains(export) { exports.append(export) }
    }
    guard !exports.isEmpty || terminal.isMultiSelect || !options.isEmpty else {
      throw WriterError.malformedStructure(
        "\(targetFieldName): refusing to write a value to a field with no /Opt vocabulary")
    }

    var pairs: [(key: String, value: String)] = []
    if exports.isEmpty {
      // Empty multi-selection: /V deleted entirely (pdf-lib deletes the key;
      // measured on PDFAcroChoice.setValues). Empty-string values are the
      // sentinel this writer uses for "remove key" (insertIntoDict).
      pairs.append(("/V", removeKeySentinel))
      pairs.append(("/I", removeKeySentinel))
    } else if exports.count == 1 {
      // Single selection: /V single string, /I removed (pdf-lib deletes it
      // for singleton writes — measured on updateSelectedIndices).
      pairs.append(("/V", pdfString(exports[0])))
      pairs.append(("/I", removeKeySentinel))
    } else {
      // Fail closed: a multi-value write to a field WITHOUT bit 22 would
      // have to flip the field's /Ff semantics to be legal (pdf-lib's
      // PDFOptionList.select() auto-enables multiselect for its form-CREATION
      // convenience). This writer fills documents whose field semantics the
      // document author chose — silently upgrading single-select to
      // multi-select changes what the form means. Refuse; a caller that
      // genuinely wants the upgrade can write the /Ff bit itself as an
      // explicit, audited step.
      guard terminal.isMultiSelect else {
        throw WriterError.requestedStateUnavailable(
          field: targetFieldName,
          state: "multi-selection [\(exports.joined(separator: ", "))] on a single-select listbox")
      }
      let vArray = exports.map { pdfString($0) }.joined(separator: " ")
      pairs.append(("/V", "[\(vArray)]"))
      let indices = exports.compactMap { options.firstIndex(of: $0) }.sorted()
      let iArray = indices.map(String.init).joined(separator: " ")
      pairs.append(("/I", "[\(iArray)]"))
    }
    return ResolvedEditPlan(
      objectEdits: [ObjectEdit(objectNumber: terminal.objectNumber, pairs: pairs)],
      newObjectBodies: [])
  }

  public static func resolveEditPlan(
    nodes: [FormObjectNode],
    targetFieldName: String,
    requestedValue: String,
    source: Data,
    generateAppearances: Bool = true
  ) throws -> ResolvedEditPlan {
    // The terminal field node for a name: the deepest node with that FQN that
    // is not itself a pure widget kid of another node with the same FQN.
    let fieldNodes = nodes.filter { $0.fullyQualifiedName == targetFieldName }
    guard !fieldNodes.isEmpty else { throw WriterError.fieldNotFound(targetFieldName) }
    let terminal =
      fieldNodes.first { !$0.isWidget || fieldNodes.count == 1 }
      ?? fieldNodes[0]
    let widgetKids = nodes.filter {
      $0.isWidget && $0.objectNumber != terminal.objectNumber
        && $0.fullyQualifiedName == targetFieldName
    }

    if terminal.fieldType == "Btn" {
      return ResolvedEditPlan(
        objectEdits: try buttonEdits(
          terminal: terminal, widgetKids: widgetKids,
          targetFieldName: targetFieldName, requestedValue: requestedValue))
    }

    // Text and choice fields: /V with a PDF string on the terminal node.
    var objectEdits = [
      ObjectEdit(objectNumber: terminal.objectNumber, pairs: [("/V", pdfString(requestedValue))])
    ]
    var newObjects: [String] = []

    // Appearance generation: patch /AP /N on the widget leaf so the rendered
    // page shows the new value even in viewers that never regenerate.
    if generateAppearances {
      let widgetLeaf =
        widgetKids.first
        ?? (terminal.isWidget ? terminal : nil)
      if let leaf = widgetLeaf, let rect = leaf.rect, rect.count >= 4 {
        let width = abs(rect[2] - rect[0])
        let height = abs(rect[3] - rect[1])
        if width >= 4, height >= 4 {
          let xrefOffset = try findLastStartxrefOffset(source)
          let xref = try parseXref(source, offset: xrefOffset)
          let baseNumber = max(
            xref.size, objectEdits.map { $0.objectNumber + 1 }.max() ?? 0)
          let fontNumber = baseNumber
          let streamNumber = baseNumber + 1

          // Self-contained Helvetica font object (no /DR dependency).
          let fontBody =
            "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>"

          // Appearance stream: field-annotated text draw, left-aligned.
          let fontSize = max(6, min(14, height - 8))
          let baseline = Int(max(2, (height - fontSize) * 0.3))
          let content =
            "/Tx BMC\nq\nBT\n/Helv \(fontSize) Tf 0 g\n2 \(baseline) Td\n"
            + "\(pdfString(requestedValue)) Tj\nET\nQ\nEMC"
          let contentBytes = latin1Bytes(content)
          let streamBody =
            "<< /Type /XObject /Subtype /Form /FormType 1 "
            + "/BBox [0 0 \(Int(width.rounded())) \(Int(height.rounded()))] "
            + "/Resources << /Font << /Helv \(fontNumber) 0 R >> >> "
            + "/Length \(contentBytes.count) >>\nstream\n"
            + content + "\nendstream"

          newObjects = [fontBody, streamBody]
          objectEdits.append(
            ObjectEdit(
              objectNumber: leaf.objectNumber,
              pairs: [("/AP", "<< /N \(streamNumber) 0 R >>")]))
        }
      }
    }

    return ResolvedEditPlan(objectEdits: objectEdits, newObjectBodies: newObjects)
  }

  private static func buttonEdits(
    terminal: FormObjectNode,
    widgetKids: [FormObjectNode],
    targetFieldName: String,
    requestedValue: String
  ) throws -> [ObjectEdit] {
    // Normalize state names: /AP keys arrive as "/0", "/Off". The set of
    // selectable on-states is everything but the Off appearance.
    let stripSlash: (String) -> String = {
      $0.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
    let onStates = Set(
      (terminal.buttonStates + widgetKids.flatMap { $0.buttonStates }).map(stripSlash)
    )
    let namedOnStates = onStates.filter { $0.lowercased() != "off" }
    let normalized = requestedValue.trimmingCharacters(in: .whitespacesAndNewlines)
    let lowered = normalized.lowercased()
    // "Off-like" tokens only deselect when they are NOT a real export value of
    // this group. Radio groups legitimately use "0"/"1" as export vocabulary
    // (Observed: public-acroform's applicant.contact), so a literal "0"
    // request must select that state — not write /Off everywhere.
    let offTokens: Set<String> = ["off", "", "false", "no", "unchecked"]
    let booleanOnTokens: Set<String> = ["true", "yes", "on", "1", "checked"]
    let exactState = namedOnStates.first { $0.lowercased() == lowered }

    if offTokens.contains(lowered), exactState == nil {
      // Explicit deselect: /V /Off on the field node, /AS /Off on every widget.
      // Merge per object so no revision drops a pair (see note below).
      var deselectPairs: [Int: [(key: String, value: String)]] = [:]
      deselectPairs[terminal.objectNumber, default: []].append(("/V", "/Off"))
      let deselectWidgets = ([terminal] + widgetKids).filter { $0.isWidget }
      for widget in deselectWidgets {
        deselectPairs[widget.objectNumber, default: []].append(("/AS", "/Off"))
      }
      if deselectWidgets.isEmpty {
        deselectPairs[terminal.objectNumber, default: []].append(("/AS", "/Off"))
      }
      return deselectPairs
        .sorted { $0.key < $1.key }
        .map { ObjectEdit(objectNumber: $0.key, pairs: $0.value) }
    }

    let selectedState: String
    if let exact = exactState {
      selectedState = exact
    } else if namedOnStates.count == 1, booleanOnTokens.contains(lowered) {
      selectedState = namedOnStates.first!
    } else if let exportState = optMappedState(
      forExport: normalized, terminal: terminal, widgetKids: widgetKids)
    {
      // /Opt-mapped radio group (§12.7.5.4 Table 247): the requested value is
      // an EXPORT that maps positionally to a kid whose /AP /N state name is
      // producer-chosen (Observed 2026-09-06: /Opt [<hex email> <hex phone>]
      // with states /0 /1 — pdf-lib select('email') writes /V=/email
      // (spec says /V carries the export) and /AS=/0 on kid 0). The exact-
      // state match above cannot see this because the export never appears
      // in /AP, so resolve it here instead of failing with
      // requestedStateUnavailable.
      selectedState = exportState
    } else {
      throw WriterError.requestedStateUnavailable(field: targetFieldName, state: normalized)
    }

    let widgets = ([terminal] + widgetKids).filter { $0.isWidget }
    // The widget whose /AP can render the selected state is the AS carrier.
    // (buttonStates keys are stored with their leading slash, e.g. "/0".)
    let stateCarrier = widgets.first { $0.buttonStates.contains("/\(selectedState)") }
    // /V goes on the dedicated field node (tree layout), or on the state
    // carrier when field and widget are the same object (merged layout).
    let valueTarget = terminal.isWidget ? (stateCarrier ?? terminal) : terminal

    // One redefinition per object: incrementalFieldUpdate appends each edit as
    // its own object revision, so the last edit for an object wins — pairs for
    // the same object must be merged into a single ObjectEdit.
    var pairsByObject: [Int: [(key: String, value: String)]] = [:]
    func add(_ object: Int, _ key: String, _ value: String) {
      pairsByObject[object, default: []].append((key, value))
    }
    // State names serialize as PDF names (leading slash): /V /0, /AS /Off.
    add(valueTarget.objectNumber, "/V", "/\(selectedState)")
    if let carrier = stateCarrier {
      for widget in widgets {
        add(widget.objectNumber, "/AS",
            widget.objectNumber == carrier.objectNumber
              ? "/\(selectedState)" : "/Off")
      }
    } else if widgets.isEmpty {
      // Merged field+widget with no discovered appearances: keep /AS in sync
      // with /V on the same object.
      add(valueTarget.objectNumber, "/AS", "/\(selectedState)")
    }
    // No carrier and a dedicated field node: /V alone (widgets untouched);
    // viewers regenerate appearances via /NeedAppearances semantics.
    return pairsByObject
      .sorted { $0.key < $1.key }
      .map { ObjectEdit(objectNumber: $0.key, pairs: $0.value) }
  }

  /// Resolves an /Opt radio export to its kid's /AP /N state name
  /// (positional mapping: Opt[i] ↔ kid i). Returns nil when the group has no
  /// /Opt or the export is not listed.
  private static func optMappedState(
    forExport export: String, terminal: FormObjectNode, widgetKids: [FormObjectNode]
  ) -> String? {
    let options = terminal.optionValues
    guard !options.isEmpty, let idx = options.firstIndex(of: export) else { return nil }
    let widgets = ([terminal] + widgetKids).filter { $0.isWidget }
    guard idx < widgets.count else { return nil }
    return widgets[idx].appearanceStateOnName
  }

  /// Sentinel pair value telling insertIntoDict to REMOVE the key from the
  /// object dictionary. Non-empty and unrepresentable as PDF syntax (spaces
  /// are stripped by callers), so it can never collide with a real value.
  static let removeKeySentinel = "\u{0}remove-key\u{0}"

  /// Serializes a Swift string as a PDF literal string with required escapes.
  static func pdfString(_ value: String) -> String {
    var escaped = "("
    for ch in value {
      switch ch {
      case "(": escaped.append("\\(")
      case ")": escaped.append("\\)")
      case "\\": escaped.append("\\\\")
      case "\r": escaped.append("\\r")
      case "\n": escaped.append("\\n")
      case "\t": escaped.append("\\t")
      default:
        if let scalar = ch.unicodeScalars.first, scalar.value < 256 {
          escaped.append(Character(UnicodeScalar(scalar)))
        } else {
          escaped.append("?")
        }
      }
    }
    escaped.append(")")
    return escaped
  }
}
// PART2_SENTINEL
