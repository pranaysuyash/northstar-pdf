# Stage 2: INTERPRET — First Principles Deep Dive

**Date:** 2026-08-26
**Scope:** What does it mean to understand PDF content? What are the physical constraints? What is the long-term optimal solution?

---

## 1. First Principle

Interpretation means **extracting meaning** from PDF objects. A PDF contains instructions for drawing graphics — interpretation means understanding what those graphics represent.

**The fundamental constraint:** PDF has no semantic layer. It doesn't know what "text" or "image" or "table" means. It only knows how to draw pixels.

---

## 2. What Interpretation Actually Means

### 2.1 Levels of Interpretation

| Level | What It Extracts | Example |
|---|---|---|
| **Glyph** | Individual characters | "H", "e", "l", "l", "o" |
| **Word** | Character sequences | "Hello" |
| **Line** | Word sequences | "Hello, world!" |
| **Paragraph** | Related lines | "Hello, world! How are you?" |
| **Section** | Related paragraphs | "Introduction" |
| **Document** | Related sections | Full report |

### 2.2 The Problem

**PDF only provides glyphs.** Everything above glyph level must be inferred.

```
PDF gives you:  H e l l o ,   w o r l d !
You must infer: [Word: "Hello"] [Punctuation: ","] [Word: "world"] [Punctuation: "!"]
```

This inference is **hard** because:
- Characters may be in any order (vertical text, columns)
- Characters may be rotated (sideways text)
- Characters may overlap (decorative fonts)
- Characters may be images (scanned documents)

---

## 3. The Physical Constraints

### 3.1 Text Extraction

| Challenge | Why It's Hard | Frequency |
|---|---|---|
| Vertical text | Characters stacked, not side-by-side | Rare |
| Columnar text | Text flows in columns, not lines | Common |
| Rotated text | Characters at angles | Common |
| Ligatures | Multiple characters as one glyph | Common |
| Kerning | Characters overlap | Common |
| Font encoding | Characters mapped to wrong codes | Rare |

### 3.2 Image Extraction

| Challenge | Why It's Hard | Frequency |
|---|---|---|
| Embedded images | JPEG, PNG, TIFF in PDF streams | Common |
| Vector graphics | Paths, not pixels | Common |
| Transparency | Blended layers | Common |
| Color spaces | CMYK, spot colors, ICC profiles | Common |
| Resolution | Different DPI per image | Common |

### 3.3 Structure Extraction

| Challenge | Why It's Hard | Frequency |
|---|---|---|
| Tables | Grid of cells, not lines | Common |
| Lists | Bullet points, numbering | Common |
| Headings | Larger/bolder text | Common |
| Figures | Images with captions | Common |
| Footnotes | Small text at bottom | Rare |

---

## 4. The Mathematical Constraints

### 4.1 Coordinate Systems

**PDF uses multiple coordinate systems:**

1. **Page coordinates** — origin at bottom-left
2. **User coordinates** — origin at top-left (for text)
3. **Device coordinates** — pixels on screen
4. **Normalized coordinates** — 0-1 range (for OCR)

**Conversion between systems requires:**
- Rotation matrices
- Scale factors
- Translation offsets
- Skew corrections

### 4.2 Text Flow Detection

**Problem:** Given a set of character positions, determine reading order.

**Algorithm:**
1. Cluster characters into lines (vertical proximity)
2. Cluster lines into paragraphs (horizontal proximity)
3. Order paragraphs (top-to-bottom, left-to-right)
4. Handle exceptions (columns, tables, rotated text)

**Complexity:** O(n log n) where n = number of characters

**Accuracy:** ~95% for simple layouts, ~70% for complex layouts

### 4.3 Table Detection

**Problem:** Given a set of text positions, identify table structure.

**Algorithm:**
1. Detect grid lines (horizontal and vertical)
2. Map text to cells
3. Infer row/column structure
4. Handle merged cells, spanning headers

**Complexity:** O(n²) where n = number of text elements

**Accuracy:** ~80% for simple tables, ~50% for complex tables

---

## 5. The Approaches

### Approach 1: Positional Extraction

**What it does:**
- Extract text by position (x, y coordinates)
- Order by position (top-to-bottom, left-to-right)
- No semantic understanding

**Mathematical analysis:**
- Time: O(n) where n = number of characters
- Space: O(n) for storing positions
- Accuracy: ~90% for simple layouts

**When to use:**
- Simple documents (single column, no tables)
- Quick extraction (need speed, not accuracy)
- Search (just need to find text)

**When NOT to use:**
- Complex layouts (columns, tables)
- Structured documents (forms, reports)
- Intelligence features (summarization, extraction)

### Approach 2: Heuristic Extraction

**What it does:**
- Apply rules to detect structure
- Use font size for headings
- Use spacing for paragraphs
- Use alignment for columns

**Mathematical analysis:**
- Time: O(n log n) for sorting and clustering
- Space: O(n) for storing features
- Accuracy: ~85% for common layouts

**When to use:**
- Business documents (reports, presentations)
- Academic papers (sections, references)
- Forms (field detection)

**When NOT to use:**
- Artistic documents (posters, flyers)
- Non-standard layouts
- Multi-language documents

### Approach 3: Machine Learning Extraction

**What it does:**
- Train models on labeled documents
- Learn layout patterns
- Predict structure from features

**Mathematical analysis:**
- Training: O(m × n) where m = training docs, n = features
- Inference: O(n) per document
- Accuracy: ~95% for common layouts, ~80% for complex

**When to use:**
- Large document collections (same format)
- High accuracy requirements
- Complex layouts

**When NOT to use:**
- Small datasets (not enough training data)
- Novel layouts (model hasn't seen them)
- Real-time requirements (inference too slow)

---

## 6. The Tradeoffs

### 6.1 Speed vs Accuracy

| Approach | Speed | Accuracy | Use Case |
|---|---|---|---|
| Positional | Fastest | Low | Search, quick look |
| Heuristic | Fast | Medium | Business documents |
| ML | Slow | High | Complex layouts |

### 6.2 Simplicity vs Capability

| Approach | Simplicity | Capability | Use Case |
|---|---|---|---|
| Positional | Simple | Basic | Simple PDFs |
| Heuristic | Medium | Good | Common layouts |
| ML | Complex | Excellent | Any layout |

### 6.3 Generalization vs Specificity

| Approach | Generalization | Specificity | Use Case |
|---|---|---|---|
| Positional | High | Low | Any PDF |
| Heuristic | Medium | Medium | Business PDFs |
| Low | High | Specific formats |

---

## 7. What We Use Today

**PDFKit (Positional + Heuristic):**
- Extracts text by position
- Basic heuristic for structure
- No ML, no semantics

**Strengths:**
- Fast
- Simple
- Works for most documents

**Weaknesses:**
- Misreads complex layouts
- No table detection
- No heading detection
- No semantic understanding

---

## 8. What We Should Consider

### 8.1 Short-term (1-3 months)

**Improved heuristics:**
- Better column detection
- Basic table detection
- Heading detection by font size

**Why:** Low effort, high impact for common documents.

### 8.2 Medium-term (3-12 months)

**Hybrid extraction:**
- Positional for simple layouts
- Heuristic for complex layouts
- ML for very complex layouts

**Why:** Best accuracy across all document types.

### 8.3 Long-term (1-3 years)

**Semantic understanding:**
- Don't just extract text — understand meaning
- Build document model with structure
- Enable intelligence features

**Why:** Move from "extracting pixels" to "understanding content."

---

## 9. The Key Insight

**Interpretation is inference.** PDF doesn't tell you what things mean — you must figure it out from positions, fonts, and spacing.

**The long-term optimal solution:** Build a rich document model that captures:
- Text content (what it says)
- Structure (how it's organized)
- Semantics (what it means)
- Relationships (how parts connect)

**This is what makes a PDF reader intelligent.**

---

## 10. Evidence

- PDF specification (ISO 32000-2)
- Text extraction algorithms (PDFMiner, pdf_oxide)
- Layout analysis research (table detection, reading order)
- Machine learning approaches (LayoutLM, DocFormer)
- User studies (what do users actually need?)
