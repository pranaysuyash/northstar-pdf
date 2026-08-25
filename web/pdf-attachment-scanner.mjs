// pdf-attachment-scanner.mjs
//
// RG-024 / RG-049: attachment inventory + path-traversal security scan.
//
// Enumerates the EmbeddedFiles name tree (including Kids subtrees), extracts
// each file specification, and flags suspicious names before any payload is
// ever extracted or executed: traversal segments, absolute paths, drive
// letters, control characters, oversized names, and executable extensions.
//
// Scope boundary (recorded): payload execution sandboxing and malware
// inspection are separate open gates; this scanner governs inventory and
// name-based safety at the inspection boundary.

import { inspectPdfWithPikepdf } from "./pdf-object-inspect.mjs";

const DETECT_SNIPPET = `
RESULT = {"attachments": [], "nameTreePresent": False}
root_names = p.Root.get('/Names')
ef = root_names.get('/EmbeddedFiles') if root_names is not None else None
if ef is not None:
    RESULT["nameTreePresent"] = True
    def walk(node):
        if node is None:
            return
        arr = node.get('/Names')
        if arr is not None:
            for i in range(0, len(arr) - 1, 2):
                entry = {"treeName": str(arr[i])}
                fs = arr[i + 1]
                try:
                    f = fs.get('/F')
                    uf = fs.get('/UF')
                    entry["filename"] = str(uf) if uf is not None else (str(f) if f is not None else None)
                    entry["dosName"] = str(f) if f is not None else None
                    ef_dict = fs.get('/EF')
                    if ef_dict is not None:
                        stream_ref = ef_dict.get('/UF') or ef_dict.get('/F')
                        if stream_ref is not None:
                            st = stream_ref
                            try:
                                entry["size"] = int(st.stream_dict.get('/Length', -1))
                            except Exception:
                                entry["size"] = None
                except Exception:
                    pass
                RESULT["attachments"].append(entry)
        kids = node.get('/Kids')
        if kids is not None:
            for kid in kids:
                walk(kid)
    walk(ef)
`;

const EXECUTABLE_EXTENSIONS = new Set([
  ".exe", ".bat", ".cmd", ".sh", ".com", ".scr", ".msi", ".ps1", ".vbs", ".jar"
]);

export function scanAttachments(srcBuf) {
  const facts = inspectPdfWithPikepdf(srcBuf, DETECT_SNIPPET);
  const seen = new Map();
  const attachments = (facts.attachments || []).map((a) => {
    const name = a.filename ?? a.treeName ?? "";
    const reasons = [];
    if (/^\//.test(name) || /^\\\\/.test(name)) reasons.push("absolutePath");
    if (/^[A-Za-z]:/.test(name)) reasons.push("driveLetter");
    if (/(^|\/)\.\.($|\/)/.test(name) || /(^|\\)\.\.($|\\)/.test(name)) reasons.push("traversalSegment");
    if (/[\u0000-\u001f\u007f]/.test(name)) reasons.push("controlCharacters");
    if (name.length > 255) reasons.push("oversizedName");
    const lower = name.toLowerCase();
    for (const ext of EXECUTABLE_EXTENSIONS) {
      if (lower.endsWith(ext)) { reasons.push(`executableExtension:${ext}`); break; }
    }
    seen.set(name, (seen.get(name) || 0) + 1);
    return {
      name,
      treeName: a.treeName,
      dosName: a.dosName ?? null,
      size: a.size ?? null,
      suspiciousReasons: reasons
    };
  });
  return {
    nameTreePresent: facts.nameTreePresent === true,
    count: attachments.length,
    duplicates: [...seen.entries()].filter(([, c]) => c > 1).map(([n]) => n),
    unsafe: attachments.filter((a) => a.suspiciousReasons.length > 0),
    attachments
  };
}

export function assertAttachmentsSafe(scan) {
  if (!scan || typeof scan.count !== "number") {
    throw new TypeError("assertAttachmentsSafe requires attachment scan facts.");
  }
  if (scan.unsafe.length > 0) {
    return {
      ok: false,
      blocked: true,
      reason: `${scan.unsafe.length} attachment(s) flagged: ` +
        scan.unsafe.map((a) => `${a.name} [${a.suspiciousReasons.join(",")}]`).join("; ")
    };
  }
  return { ok: true, blocked: false };
}
