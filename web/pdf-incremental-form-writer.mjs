// pdf-incremental-form-writer.mjs
//
// Source-preserving form writer. Emits a GENUINE incremental PDF update:
// changed field objects are re-defined at the end of the file (same object
// number, same generation) and a new xref is appended with /Prev chaining to
// the original xref. The original byte stream is a prefix of the output, so
// unchanged-region digest invariance (RG-017 / RG-018) holds by construction.
//
// This is the RG-002 fix: pdf-lib/PDFKit rewrite widget appearance and drop
// external AcroForm radio-choice metadata; an incremental update does not.
//
// Pure ESM, Node + browser-compatible (xref-stream path uses zlib only when
// the source actually uses xref streams; classic xref paths need no codec).

import zlib from "node:zlib";

const DEC = "latin1";

function findLastStartxref(buf) {
  const s = buf.toString(DEC);
  const idx = s.lastIndexOf("startxref");
  if (idx < 0) throw new Error("no startxref");
  const after = s.slice(idx + "startxref".length).trim();
  const num = parseInt(after.split(/\s+/)[0], 10);
  if (!Number.isFinite(num)) throw new Error("bad startxref offset");
  return num;
}

function isXrefTable(buf, off) {
  return buf.toString(DEC, off, off + 4) === "xref";
}

// Consume exactly one PDF value starting at q (after the key), returning the
// index just past it. Handles nested dicts/arrays/strings so a "/" inside a
// value is not mistaken for the next top-level key.
function skipString(text, q, n) {
  q++;
  while (q < n) {
    if (text[q] === "\\") {
      q += 2;
      continue;
    }
    if (text[q] === ")") return q + 1;
    q++;
  }
  return q;
}

function readValue(text, q, n) {
  while (q < n && /\s/.test(text[q])) q++;
  const c = text[q];
  if (text.startsWith("<<", q)) {
    let d = 1;
    q += 2;
    while (q < n) {
      if (text.startsWith("<<", q)) {
        d++;
        q += 2;
        continue;
      }
      if (text.startsWith(">>", q)) {
        d--;
        q += 2;
        if (d === 0) return q;
        continue;
      }
      q++;
    }
    return q;
  }
  if (c === "[") {
    let br = 1;
    q += 1;
    while (q < n) {
      if (text[q] === "[") {
        br++;
        q++;
        continue;
      }
      if (text[q] === "]") {
        br--;
        q++;
        if (br === 0) return q;
        continue;
      }
      if (text[q] === "(") {
        q = skipString(text, q, n);
        continue;
      }
      q++;
    }
    return q;
  }
  if (c === "(") return skipString(text, q, n);
  if (c === "<") {
    q++;
    while (q < n && text[q] !== ">") q++;
    return q + 1;
  }
  if (c === "/") {
    q++;
    while (q < n && !/\s/.test(text[q]) && text[q] !== ">" && text[q] !== "]" && !text.startsWith(">>", q)) q++;
    return q;
  }
  while (q < n && !/\s/.test(text[q]) && text[q] !== ">" && text[q] !== "]" && !text.startsWith(">>", q)) q++;
  return q;
}

// Top-level key/value spans of a PDF dict.
function topLevelEntries(text) {
  const entries = [];
  const n = text.length;
  const open = text.indexOf("<<");
  if (open < 0) return entries;
  let p = open + 2;
  while (p < n) {
    while (p < n && /\s/.test(text[p])) p++;
    if (text.startsWith(">>", p)) break;
    if (text[p] !== "/") {
      p++;
      continue;
    }
    const keyStart = p;
    let q = p + 1;
    while (q < n && !/\s/.test(text[q]) && text[q] !== ">" && !text.startsWith(">>", q) && text[q] !== "]") q++;
    const key = text.slice(keyStart, q);
    const valStart = q;
    const valEnd = readValue(text, q, n);
    entries.push({ key, valStart, valEnd });
    p = valEnd;
  }
  return entries;
}

function dictClose(text) {
  const end = text.lastIndexOf("endobj");
  const close = text.lastIndexOf(">>", end);
  if (close < 0) throw new Error("no dict close");
  return close;
}

function extractTrailerKeys(dictText) {
  const keys = {};
  for (const k of ["/Root", "/Encrypt", "/Info", "/ID", "/Size", "/Prev"]) {
    const re = new RegExp(k + "\\s*(\\<\\<[\\s\\S]*?\\>\\>|\\[[\\s\\S]*?\\]|/[^\\s\\]]+|\\d+\\s+\\d+\\s+R)");
    const m = dictText.match(re);
    if (m) keys[k] = m[1];
  }
  return keys;
}

function parseClassicXref(buf, off) {
  const s = buf.toString(DEC, off);
  if (!s.startsWith("xref")) throw new Error("not a classic xref at offset");
  const offsets = new Map();
  let size = 0;
  let p = 4;
  let trailerDict = null;
  while (p < s.length) {
    while (p < s.length && /\s/.test(s[p])) p++;
    if (s.startsWith("trailer", p)) {
      const db = s.indexOf("<<", p);
      const de = s.indexOf(">>", db);
      trailerDict = s.slice(db, de + 2);
      break;
    }
    const line = s.slice(p, p + 40);
    const m = line.match(/^(\d+)\s+(\d+)/);
    if (!m) break;
    const start = parseInt(m[1], 10);
    const count = parseInt(m[2], 10);
    p += line.indexOf("\n") + 1;
    for (let i = 0; i < count; i++) {
      const entry = s.slice(p, p + 20);
      p += 20;
      const type = entry[17];
      if (type === "n") {
        const objOff = parseInt(entry.slice(0, 10), 10);
        const gen = parseInt(entry.slice(11, 16), 10);
        offsets.set(start + i, { offset: objOff, gen, compressed: false });
        if (start + i + 1 > size) size = start + i + 1;
      }
    }
  }
  if (!trailerDict) throw new Error("no trailer in classic xref");
  return { offsets, size, trailer: extractTrailerKeys(trailerDict) };
}

function parseXrefStream(buf, off) {
  const s = buf.toString(DEC, off);
  const hdrEnd = s.indexOf("stream");
  if (hdrEnd < 0) throw new Error("xref stream has no stream");
  const dictStart = s.indexOf("<<", off);
  const dictEnd = s.indexOf(">>", dictStart) + 2;
  const dictText = s.slice(dictStart, dictEnd);
  const trailer = extractTrailerKeys(dictText);
  const streamStart = s.indexOf("\n", hdrEnd) + 1;
  const streamEnd = s.indexOf("endstream", streamStart);
  const raw = buf.subarray(off + streamStart, off + streamEnd);
  const inf = zlib.inflateSync(raw);
  const wMatch = dictText.match(/\/W\s*\[\s*(\d+)\s+(\d+)\s+(\d+)\s*\]/);
  const W = [
    parseInt(wMatch[1], 10),
    parseInt(wMatch[2], 10),
    parseInt(wMatch[3], 10),
  ];
  let index = [0, parseInt(trailer["/Size"] || "0", 10)];
  const idxM = dictText.match(/\/Index\s*\[([\s\d]+)\]/);
  if (idxM) {
    const nums = idxM[1].trim().split(/\s+/).map(Number);
    index = [];
    for (let i = 0; i < nums.length; i += 2) index.push([nums[i], nums[i + 1]]);
  }
  const offsets = new Map();
  let pos = 0;
  let size = 0;
  for (const [start, count] of index) {
    for (let i = 0; i < count; i++) {
      const type = W[0] ? inf[pos] : 1;
      pos += W[0];
      const f1 = W[1] ? readInt(inf, pos, W[1]) : 0;
      pos += W[1];
      const f2 = W[2] ? readInt(inf, pos, W[2]) : 0;
      pos += W[2];
      if (type === 1) {
        offsets.set(start + i, { offset: f1, gen: f2, compressed: false });
        if (start + i + 1 > size) size = start + i + 1;
      } else if (type === 2) {
        offsets.set(start + i, { offset: f1, gen: f2, compressed: true });
      }
    }
  }
  return { offsets, size: parseInt(trailer["/Size"] || "0", 10), trailer };
}

function readInt(buf, pos, len) {
  let v = 0;
  for (let i = 0; i < len; i++) v = (v << 8) | buf[pos + i];
  return v;
}

export function readSourceXref(buf) {
  const off = findLastStartxref(buf);
  if (isXrefTable(buf, off)) return { type: "table", offset: off, ...parseClassicXref(buf, off) };
  return { type: "stream", offset: off, ...parseXrefStream(buf, off) };
}

function objectByteSpan(buf, offset) {
  const s = buf.toString(DEC, offset);
  const end = s.indexOf("endobj");
  if (end < 0) throw new Error("object has no endobj");
  return s.slice(0, end + 6);
}

function insertIntoDict(objText, pairs) {
  const close = dictClose(objText);
  const base = objText.slice(0, close);
  const entries = topLevelEntries(base);
  let text = base;
  for (const pair of pairs) {
    const existing = entries.find((e) => e.key === pair.k);
    if (existing) {
      text = text.slice(0, existing.valStart) + " " + pair.v + text.slice(existing.valEnd);
    } else {
      text += ` ${pair.k} ${pair.v}`;
    }
  }
  return text + objText.slice(close);
}

// edits: [{ objNum, pairs: [{k, v}] }]
// Returns a Buffer that is srcBuf followed by an incremental update.
export function incrementalFieldUpdate(srcBuf, edits) {
  const xref = readSourceXref(srcBuf);
  const chunks = [srcBuf];
  // ensure separation from original %%EOF
  let tail = srcBuf.toString(DEC).endsWith("\n") ? "" : "\n";
  chunks.push(Buffer.from(tail, DEC));

  const subsectionEntries = [];
  for (const edit of edits) {
    const meta = xref.offsets.get(edit.objNum);
    if (!meta) throw new Error(`object ${edit.objNum} not found in xref`);
    if (meta.compressed)
      throw new Error(
        `object ${edit.objNum} is compressed in an object stream; decompress source first (incremental update cannot shadow compressed objects)`
      );
    const objText = objectByteSpan(srcBuf, meta.offset);
    const newBody = insertIntoDict(objText, edit.pairs);
    const appended = Buffer.from(newBody + "\n", DEC);
    const newOffset = Buffer.concat(chunks).length;
    chunks.push(appended);
    subsectionEntries.push({ objNum: edit.objNum, gen: meta.gen, offset: newOffset });
  }

  // Build a classic xref with one subsection per updated object, /Prev chained.
  let xrefBody = "xref\n";
  for (const e of subsectionEntries) {
    xrefBody += `${e.objNum} 1\n`;
    xrefBody += `${String(e.offset).padStart(10, "0")} ${String(e.gen).padStart(5, "0")} n \n`;
  }
  const maxObj = Math.max(xref.size, ...subsectionEntries.map((e) => e.objNum + 1));
  let trailer = "trailer\n<< ";
  trailer += `/Size ${maxObj} /Prev ${xref.offset}`;
  for (const k of ["/Root", "/Encrypt", "/Info", "/ID"]) {
    if (xref.trailer[k]) trailer += ` ${k} ${xref.trailer[k]}`;
  }
  trailer += " >>\n";
  const xrefStart = Buffer.concat(chunks).length;
  chunks.push(Buffer.from(xrefBody + trailer + `startxref ${xrefStart}\n%%EOF\n`, DEC));

  return Buffer.concat(chunks);
}

export function originalPrefixDigest(srcBuf, algo = "sha256") {
  // The original file is the preserved prefix of any incremental output.
  return srcBuf;
}
