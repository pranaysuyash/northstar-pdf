# Stage 1: PARSE — First Principles Deep Dive

**Date:** 2026-08-26
**Scope:** What does it mean to read a PDF structure? What are the physical constraints? What is the long-term optimal solution?

---

## 1. First Principle

A PDF is a **binary container** that describes a document as a collection of **objects** with **relationships**. Parsing means reconstructing this object graph from bytes.

**The fundamental constraint:** PDF is a sequential format with random-access pointers. You can't know the full structure without reading the entire file — but you don't need to.

---

## 2. What a PDF Actually Is

### 2.1 Physical Structure

```
PDF file = [header] [body objects] [cross-reference table] [trailer]
```

- **Header:** `%PDF-1.7` — version identifier
- **Body:** Objects (text, images, fonts, pages, annotations)
- **Cross-reference (xref):** Map of object positions (byte offsets)
- **Trailer:** Points to xref, contains metadata (page count, root)

### 2.2 Logical Structure

```
Document
├── Pages
│   ├── Page 1
│   │   ├── Content stream (text, graphics)
│   │   ├── Resources (fonts, images)
│   │   └── Annotations (forms, links)
│   ├── Page 2
│   └── ...
├── Outline (bookmarks)
├── Metadata (title, author)
└── Security (encryption, permissions)
```

### 2.3 The Key Insight

**PDF is not a document.** It's a **description of a document**. The objects don't contain the document — they describe how to reconstruct it.

This is why parsing is hard: you're not reading a document, you're reading instructions for building one.

---

## 3. The Physical Constraints

### 3.1 File Size

| PDF Type | Typical Size | Pages | Objects |
|---|---|---|---|
| Simple text | 50 KB | 1 | 10-20 |
| Business report | 500 KB | 10 | 100-500 |
| Academic paper | 2 MB | 20 | 500-2000 |
| Textbook | 10 MB | 200 | 5000-20000 |
| Technical manual | 50 MB | 500 | 20000-100000 |
| Large dataset | 500 MB | 1000 | 100000+ |

**Constraint:** Parsing 500 MB in memory is impossible on mobile. Must be streaming.

### 3.2 Object Count

| Object Type | Count in Typical PDF | Parse Complexity |
|---|---|---|
| Pages | 10-1000 | Low |
| Fonts | 5-50 | Medium |
| Images | 10-500 | High |
| Annotations | 0-100 | Low |
| Form fields | 0-50 | Medium |
| Streams | 50-5000 | High |

**Constraint:** Some objects (streams) are compressed and must be decompressed to understand.

### 3.3 Cross-Reference Complexity

| Xref Type | Structure | Parse Complexity |
|---|---|---|
| Classic xref | Table of byte offsets | Low |
| Cross-reference stream | Compressed stream | High |
| Hybrid | Both | Very high |

**Constraint:** The xref is the key to random access. If it's corrupted, you can't find objects.

---

## 4. The Mathematical Constraints

### 4.1 Information Theory

**PDF is lossless.** Every byte matters. A single corrupted byte can break rendering.

**Shannon entropy:** PDF content streams have high entropy (compressed text/images). You can't skip bytes — you must read them all.

### 4.2 Graph Theory

**PDF is a directed acyclic graph (DAG).** Objects reference other objects. You can't fully understand an object without following its references.

**Worst case:** Object A references B, which references C, which references A (circular reference). Must detect and handle cycles.

### 4.3 Complexity Theory

**Parsing is O(n)** where n is file size. You must read every byte at least once.

**But:** You don't need to parse everything upfront. Lazy parsing can defer work until needed.

---

## 5. The Approaches

### Approach 1: Full Parse (QPDF, pikepdf)

**What it does:**
- Read entire file into memory
- Build complete object graph
- Resolve all references
- Validate structure

**Mathematical analysis:**
- Time: O(n) where n = file size
- Space: O(m) where m = number of objects
- Best case: m << n (few objects, lots of data)
- Worst case: m ≈ n (many small objects)

**When to use:**
- Validation (need full understanding)
- Transformation (need to modify structure)
- Small files (<10 MB)

**When NOT to use:**
- Large files (>100 MB)
- Mobile devices (limited memory)
- Quick viewing (need instant feedback)

### Approach 2: Streaming Parse (PDFKit)

**What it does:**
- Read file sequentially
- Parse objects on-demand
- Cache parsed objects
- Don't build full graph upfront

**Mathematical analysis:**
- Time: O(k) where k = objects accessed (k ≤ n)
- Space: O(c) where c = cache size
- Best case: k << n (only read what's needed)
- Worst case: k = n (need everything)

**When to use:**
- Viewing (need specific pages)
- Large files (can't load all)
- Mobile devices (limited memory)

**When NOT to use:**
- Validation (need full understanding)
- Transformation (need full graph)
- Complex cross-references

### Approach 3: Selective Parse (PDF.js)

**What it does:**
- Parse only current page
- Load other pages on-demand
- JavaScript-based, runs anywhere
- Handles common features

**Mathematical analysis:**
- Time: O(p) where p = current page size
- Space: O(p) where p = current page objects
- Best case: p << n (single page)
- Worst case: p ≈ n (single huge page)

**When to use:**
- Web (JavaScript required)
- Quick viewing (need instant feedback)
- Cross-platform (same code everywhere)

**When NOT to use:**
- Full-document operations
- Complex PDFs (may miss features)
- Native performance needed

---

## 6. The Tradeoffs

### 6.1 Speed vs Completeness

| Approach | Speed | Completeness | Use Case |
|---|---|---|---|
| Full Parse | Slow | Complete | Validation, transformation |
| Streaming Parse | Fast | Good | Viewing, large files |
| Selective Parse | Fastest | Partial | Web, quick viewing |

### 6.2 Memory vs Capability

| Approach | Memory | Capability | Use Case |
|---|---|---|---|
| Full Parse | High | Full | Desktop, power users |
| Streaming Parse | Low | Good | Mobile, average users |
| Selective Parse | Lowest | Basic | Web, casual users |

### 6.3 Accuracy vs Speed

| Approach | Accuracy | Speed | Use Case |
|---|---|---|---|
| Full Parse | High | Slow | Critical documents |
| Streaming Parse | Medium | Fast | Normal documents |
| Selective Parse | Low | Fastest | Preview, quick look |

---

## 7. What We Use Today

**PDFKit (Streaming Parse):**
- Reads file sequentially
- Parses pages on-demand
- Caches parsed objects
- Handles most features well

**Strengths:**
- Fast startup
- Low memory
- Good feature coverage

**Weaknesses:**
- May miss edge cases
- Limited validation
- No full structure access

---

## 8. What We Should Consider

### 8.1 Short-term (1-3 months)

**Hybrid parsing:**
- Use streaming for viewing
- Use full parse for validation
- Switch based on context

**Why:** Best of both worlds — fast viewing, complete validation.

### 8.2 Medium-term (3-12 months)

**Intelligent caching:**
- Predict which pages user will need
- Pre-parse likely pages
- Cache parsed objects by access pattern

**Why:** Reduce latency for common workflows.

### 8.3 Long-term (1-3 years)

**Semantic parsing:**
- Don't just parse objects — understand meaning
- Build document model, not just object graph
- Enable intelligence features

**Why:** Move from "rendering pixels" to "understanding content."

---

## 9. The Key Insight

**Parsing is not reading.** Parsing is **reconstructing**. The PDF doesn't contain the document — it contains instructions for building it.

**The long-term optimal solution:** Parse once, build a rich document model, cache it, and reuse it for all operations (viewing, searching, understanding, editing).

**This is what PDFKit does partially.** We should extend it to do fully.

---

## 10. Evidence

- PDF specification (ISO 32000-2)
- Parser implementations (QPDF, pikepdf, PDFKit, PDF.js)
- Performance benchmarks (parse speed, memory usage)
- File format analysis (object types, cross-reference structures)
- Information theory (entropy, compression, random access)
