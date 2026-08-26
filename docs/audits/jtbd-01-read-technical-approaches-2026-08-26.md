# JTBD-01: READ — Technical Approaches

**Date:** 2026-08-26
**Job:** "I need to consume this document's content"
**Scope:** Different technical ways to achieve the job, and their tradeoffs

---

## 1. The Rendering Pipeline

A PDF goes through stages before the user sees it:

```
PDF bytes → Parse → Interpret → Rasterize → Display
            ↓         ↓           ↓          ↓
         Structure  Content    Pixels    Screen
```

Each stage has multiple technical approaches. The choice determines quality, speed, and capability.

---

## 2. Stage 1: Parsing — Reading the PDF Structure

### Approach A: Full Parser (QPDF, pikepdf)
- Reads entire PDF structure into memory
- Builds complete object graph
- Handles all PDF features (cross-reference streams, compressed objects)
- **Pros:** Complete understanding, can validate structure
- **Cons:** Slow for large PDFs, high memory usage

### Approach B: Streaming Parser (PDFKit)
- Reads PDF incrementally
- Renders pages on-demand
- Handles common features well
- **Pros:** Fast startup, low memory
- **Cons:** May miss edge cases, limited validation

### Approach C: Selective Parser (PDF.js)
- Parses only what's needed for current view
- Lazy-loads remaining pages
- JavaScript-based, works everywhere
- **Pros:** Fast initial render, cross-platform
- **Cons:** May miss features, slower for full-document operations

### Tradeoff Matrix

| Approach | Speed | Memory | Completeness | Platform |
|---|---|---|---|---|
| Full Parser | Slow | High | Complete | Native |
| Streaming Parser | Fast | Low | Good | Native |
| Selective Parser | Fast | Low | Partial | Cross-platform |

---

## 3. Stage 2: Interpretation — Understanding Content

### Approach A: Visual-Only (Most readers)
- Renders pixels only
- No text extraction
- No semantic understanding
- **Pros:** Simple, fast
- **Cons:** Can't search, can't copy, can't summarize

### Approach B: Text + Visual (PDFKit, PDF.js)
- Extracts text layer
- Renders visual layer
- Maps text to coordinates
- **Pros:** Searchable, copyable
- **Cons:** May miss formatting, no semantic understanding

### Approach C: Semantic (Advanced)
- Extracts structure (headings, tables, lists)
- Identifies content types (text, image, form)
- Builds document model
- **Pros:** Understands meaning, enables intelligence
- **Cons:** Complex, slower, may misclassify

### Tradeoff Matrix

| Approach | Speed | Search | Understanding | Intelligence |
|---|---|---|---|---|
| Visual-Only | Fast | No | None | None |
| Text + Visual | Medium | Yes | Basic | None |
| Semantic | Slow | Yes | Deep | Enabled |

---

## 4. Stage 3: Rasterization — Turning Into Pixels

### Approach A: CPU Rendering (Most engines)
- Renders on main thread
- Blocks UI during render
- Single-core processing
- **Pros:** Simple, reliable
- **Cons:** Slow for large pages, blocks interaction

### Approach B: GPU Rendering (PDFium, Chrome)
- Uses graphics card for rendering
- Parallel processing
- Hardware acceleration
- **Pros:** Fast, smooth scrolling
- **Cons:** Requires GPU, may have driver issues

### Approach C: Hybrid (PDFKit on macOS)
- CPU for structure, GPU for display
- Smart caching
- Progressive rendering
- **Pros:** Balanced speed and quality
- **Cons:** Complex implementation

### Tradeoff Matrix

| Approach | Speed | Quality | GPU Required | Battery |
|---|---|---|---|---|
| CPU Rendering | Slow | High | No | Low |
| GPU Rendering | Fast | High | Yes | High |
| Hybrid | Medium | High | Optional | Medium |

---

## 5. Stage 4: Display — Showing to User

### Approach A: Full Page Render
- Renders entire page at once
- Displays when complete
- **Pros:** Consistent, no artifacts
- **Cons:** Slow for large pages

### Approach B: Progressive Render
- Renders low-res first, then high-res
- Shows preview immediately
- **Pros:** Perceived speed, instant feedback
- **Cons:** Temporary blurriness

### Approach C: Tile-Based Render
- Divides page into tiles
- Renders visible tiles first
- **Pros:** Fast scrolling, smooth interaction
- **Cons:** Complex, may show tile boundaries

### Tradeoff Matrix

| Approach | Perceived Speed | Quality | Memory | Complexity |
|---|---|---|---|---|
| Full Page | Slow | Highest | High | Low |
| Progressive | Fast | Varies | Medium | Medium |
| Tile-Based | Fastest | Good | Low | High |

---

## 6. Text Extraction Approaches

### Approach A: PDF-native Text
- Extracts text from PDF content streams
- Preserves original text exactly
- **Pros:** Accurate, fast
- **Cons:** May be scrambled in complex layouts

### Approach B: OCR (Optical Character Recognition)
- Renders page to image
- Runs character recognition
- **Pros:** Works on scanned PDFs
- **Cons:** Slow, may have errors

### Approach C: Hybrid
- Try native text first
- Fall back to OCR if needed
- **Pros:** Best of both worlds
- **Cons:** Complex, may misclassify

### Tradeoff Matrix

| Approach | Speed | Accuracy | Scanned PDFs | Layout |
|---|---|---|---|---|
| PDF-native | Fast | High | No | Preserved |
| OCR | Slow | Medium | Yes | Lost |
| Hybrid | Medium | High | Yes | Preserved |

---

## 7. Color Management Approaches

### Approach A: Pass-Through
- Renders colors as-is
- No color space conversion
- **Pros:** Fast, original colors
- **Cons:** May look wrong on different displays

### Approach B: Color Management (ICC)
- Converts color spaces using ICC profiles
- Ensures consistent color
- **Pros:** Accurate color
- **Cons:** Slower, complex

### Approach C: Device-Adaptive
- Detects display capabilities
- Adjusts rendering accordingly
- **Pros:** Best appearance per device
- **Cons:** Complex, may vary

### Tradeoff Matrix

| Approach | Speed | Accuracy | Cross-Device | Complexity |
|---|---|---|---|---|
| Pass-Through | Fast | Low | No | Low |
| ICC Management | Slow | High | Yes | High |
| Device-Adaptive | Medium | Medium | Yes | Medium |

---

## 8. Performance Strategies

### Strategy A: Lazy Loading
- Render only visible pages
- Load ahead by N pages
- **Pros:** Fast startup, low memory
- **Cons:** May stutter on fast scrolling

### Strategy B: Pre-rendering
- Render all pages in background
- Cache rendered pages
- **Pros:** Smooth scrolling
- **Cons:** High memory, slow startup

### Strategy C: Adaptive
- Start with lazy loading
- Switch to pre-rendering based on behavior
- **Pros:** Best of both worlds
- **Cons:** Complex, may mispredict

### Tradeoff Matrix

| Strategy | Startup | Scroll | Memory | Battery |
|---|---|---|---|---|
| Lazy Loading | Fast | May stutter | Low | Low |
| Pre-rendering | Slow | Smooth | High | High |
| Adaptive | Fast | Smooth | Medium | Medium |

---

## 9. What We Use Today

| Stage | Our Approach | Tradeoff |
|---|---|---|
| Parsing | PDFKit (streaming) | Fast, good coverage |
| Interpretation | Text + Visual | Searchable, no semantics |
| Rasterization | CPU (hybrid on macOS) | Reliable, may be slow |
| Display | Full page | Consistent, may be slow |
| Text | PDF-native | Accurate, no scanned PDFs |
| Color | Pass-Through | Fast, may be inaccurate |
| Performance | Lazy loading | Fast startup, may stutter |

---

## 10. What We Should Consider

### Short-term improvements:
- **Progressive rendering** — show preview immediately
- **GPU acceleration** — use graphics card for speed
- **Better caching** — remember rendered pages

### Medium-term improvements:
- **Semantic parsing** — understand document structure
- **Hybrid text extraction** — OCR fallback for scanned PDFs
- **Color management** — ICC profiles for accuracy

### Long-term improvements:
- **AI-powered understanding** — summarize, extract, explain
- **Collaborative reading** — share annotations, track progress
- **Adaptive rendering** — learn user preferences

---

## 11. The Key Insight

**There's no single "best" approach.** Each tradeoff depends on the user's context:

- **Student** needs accuracy (color management, semantic parsing)
- **Lawyer** needs speed (lazy loading, streaming parser)
- **Executive** needs instant feedback (progressive rendering, GPU)
- **Designer** needs fidelity (ICC profiles, full page render)

**The best reader adapts its technical approach to the user's context.**

---

## 12. Evidence

- PDF specification (ISO 32000)
- Engine comparisons (PDFKit vs PDF.js vs PDFium)
- Performance benchmarks (rendering speed, memory usage)
- User behavior patterns (what do users actually need?)
- Competitive analysis (what do others do?)
