import Compression
import Foundation

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
/// - Only native field-value edits (`/V`, `/AS`) are emitted; appearance
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
    var trailer: [String: String]
    var size: Int
  }

  static func parseXref(_ data: Data, offset: Int) throws -> XrefInfo {
    let bytes = [UInt8](data)
    guard offset < bytes.count else { throw WriterError.unsupportedXref("offset out of range") }
    let head = latin1(bytes[offset..<min(bytes.count, offset + 5)])
    if head.hasPrefix("xref") {
      return try parseClassicXref(bytes, offset: offset)
    }
    return try parseXrefStream(bytes, offset: offset)
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
    return XrefInfo(entries: entries, trailer: trailer, size: max(size, declaredSize))
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

  private static func parseXrefStream(_ bytes: [UInt8], offset: Int) throws -> XrefInfo {
    let region = latin1(bytes[offset...])
    guard let streamMarker = region.range(of: "stream") else {
      throw WriterError.unsupportedXref("xref stream has no stream keyword")
    }
    guard let dictClose = region.range(
      of: ">>", range: region.startIndex..<streamMarker.lowerBound)
    else { throw WriterError.unsupportedXref("xref stream dict") }
    let dict = String(region[region.startIndex..<dictClose.upperBound])
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

    var entries: [Int: (offset: Int, generation: Int)] = [:]
    var size = 0
    var pos = 0
    func readInt(_ at: Int, _ len: Int) -> Int {
      var v = 0
      for i in 0..<len where at + i < inflated.count {
        v = (v << 8) | Int(inflated[at + i])
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
        }
        // Type 2 entries (objects inside compressed object streams) are not
        // recorded; targeting such an object later fails closed precisely.
      }
    }
    let declaredSize = Int(trailer["/Size"]?.trimmingCharacters(in: .whitespaces) ?? "0") ?? size
    return XrefInfo(entries: entries, trailer: trailer, size: max(size, declaredSize))
  }

  static func inflateZlib(_ bytes: [UInt8]) -> [UInt8]? {
    guard bytes.count > 6 else { return nil }
    // zlib wrapper: 2-byte header + 4-byte Adler-32; COMPRESSION_ZLIB is raw
    // DEFLATE, so strip the wrapper before inflating.
    let raw = Array(bytes[2..<(bytes.count - 4)])
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

  // MARK: - Object access

  static func objectSpan(
    _ data: Data, xref: XrefInfo, objectNumber: Int
  ) throws -> (generation: Int, text: String) {
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

  // MARK: - Dictionary scanning

  struct DictEntry {
    let key: String
    let valueRange: Range<String.Index>
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
        entries.append(DictEntry(key: key, valueRange: valueStart..<valueEnd))
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
    var result = base
    // Replace from the end so earlier spans stay valid while editing.
    for pair in pairs.reversed() {
      if let existing = entries.first(where: { $0.key == pair.key }) {
        // Ensure a space separates the key from the new value
        let needsSpace = existing.valueRange.lowerBound > result.startIndex &&
          !isPdfWhitespace(result[result.index(before: existing.valueRange.lowerBound)])
        let replacement = needsSpace ? " \(pair.value)" : pair.value
        result.replaceSubrange(existing.valueRange, with: replacement)
      } else {
        result.insert(contentsOf: " \(pair.key) \(pair.value)", at: close)
      }
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

    var chunks: [Data] = [source]
    var total = source.count
    var subsections: [(objectNumber: Int, generation: Int, offset: Int)] = []

    for edit in edits {
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

  // MARK: - AcroForm tree walking

  public struct FormObjectNode {
    public let objectNumber: Int
    public let fullyQualifiedName: String
    public let isWidget: Bool
    public let rect: [Double]?
    public let buttonStates: [String]
    public let fieldType: String?
    public let childObjectNumbers: [Int]
  }

  /// Walks the AcroForm field tree over raw (uncompressed) objects.
  public static func walkAcroForm(_ source: Data) throws -> [FormObjectNode] {
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
    for ref in arrayRefs(fieldsToken) {
      guard let number = refObjectNumber(ref) else { continue }
      try walkField(
        source, xref: xref, objectNumber: number, parentPath: "", visited: [],
        into: &nodes)
    }
    return nodes
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
    let node = FormObjectNode(
      objectNumber: objectNumber,
      fullyQualifiedName: fqn,
      isWidget: isWidget,
      rect: rect,
      buttonStates: buttonStates,
      fieldType: fieldType,
      childObjectNumbers: kidRefs.compactMap(refObjectNumber)
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
  static func appearanceStates(_ source: Data, xref: XrefInfo, apToken: String) -> [String] {
    func statesFromDict(_ dictText: String) -> [String] {
      let entries = topLevelEntries(dictText)
      guard let n = entries.first(where: { $0.key == "/N" }) else { return [] }
      let value = String(dictText[n.valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
      guard value.hasPrefix("<<") else { return [] }
      return topLevelEntries(value).map { $0.key }
    }
    if apToken.hasPrefix("<<") { return statesFromDict(apToken) }
    guard let apNumber = refObjectNumber(apToken),
      let (_, apText) = try? objectSpan(source, xref: xref, objectNumber: apNumber)
    else { return [] }
    return statesFromDict(apText)
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
      return String(t.dropFirst().dropLast())
    }
    return t
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
    let onStates = Set(
      (terminal.buttonStates + widgetKids.flatMap { $0.buttonStates }).map {
        $0.trimmingCharacters(in: .whitespaces)
      }
    )
    let namedOnStates = onStates.filter { $0 != "/Off" }
    let normalized = requestedValue.trimmingCharacters(in: .whitespacesAndNewlines)
    let lowered = normalized.lowercased()
    let offTokens: Set<String> = ["off", "0", "", "false", "no", "unchecked"]
    let booleanOnTokens: Set<String> = ["true", "yes", "on", "1", "checked"]

    if offTokens.contains(lowered) {
      var edits = [ObjectEdit(objectNumber: terminal.objectNumber, pairs: [("/V", "/Off")])]
      for kid in widgetKids {
        edits.append(ObjectEdit(objectNumber: kid.objectNumber, pairs: [("/AS", "/Off")]))
      }
      if widgetKids.isEmpty {
        edits[0].pairs.append(("/AS", "/Off"))
      }
      return edits
    }

    let selectedState: String
    if let exact = namedOnStates.first(where: {
      $0.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased() == lowered
    }) {
      selectedState = exact
    } else if namedOnStates.count == 1, booleanOnTokens.contains(lowered) {
      selectedState = namedOnStates.first!
    } else {
      throw WriterError.requestedStateUnavailable(field: targetFieldName, state: normalized)
    }

    var edits = [ObjectEdit(objectNumber: terminal.objectNumber, pairs: [("/V", selectedState)])]
    if widgetKids.isEmpty {
      edits[0].pairs.append(("/AS", selectedState))
    } else {
      for kid in widgetKids {
        let kidStates = Set(kid.buttonStates)
        let kidState = kidStates.contains(selectedState) ? selectedState : "/Off"
        edits.append(ObjectEdit(objectNumber: kid.objectNumber, pairs: [("/AS", kidState)]))
      }
    }
    return edits
  }

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
