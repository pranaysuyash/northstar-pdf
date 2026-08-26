# Stage 3: RASTERIZE — First Principles Deep Dive

**Date:** 2026-08-26
**Scope:** What does it mean to turn PDF content into pixels? What are the physical constraints? What is the long-term optimal solution?

---

## 1. First Principle

Rasterization means **converting mathematical descriptions into pixels**. A PDF contains vectors (lines, curves, text glyphs) — rasterization means turning those vectors into a grid of colored dots.

**The fundamental constraint:** Vectors are infinite resolution. Pixels are finite resolution. Rasterization is lossy — you must choose a resolution.

---

## 2. What Rasterization Actually Means

### 2.1 The Input

PDF content streams contain instructions like:

```
BT
/F1 12 Tf
100 700 Td
(Hello, world!) Tj
ET
```

This means:
- Begin text object
- Use font F1 at 12pt
- Move to position (100, 700)
- Show text "Hello, world!"
- End text object

### 2.2 The Output

A grid of pixels:

```
Row 0: [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
Row 1: [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
Row 2: [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
...
Row 12: [0,0,255,255,255,0,0,0,0,0,0,0,0,0,0,0]
Row 13: [0,0,255,255,255,0,0,0,0,0,0,0,0,0,0,0]
...
```

### 2.3 The Process

```
PDF instructions → Interpret → Transform → Rasterize → Anti-alias → Output
                  ↓           ↓           ↓           ↓          ↓
               Graphics    Coordinate   Scanline    Smooth    Pixels
               state       mapping      conversion  edges
```

---

## 3. The Physical Constraints

### 3.1 Resolution

**DPI (dots per inch):**

| DPI | Quality | Use Case |
|---|---|---|
| 72 | Low | Screen (old) |
| 96 | Medium | Screen (Windows) |
| 150 | Good | Screen (Mac) |
| 300 | High | Print |
| 600 | Very high | High-quality print |
| 1200 | Ultra | Professional print |

**Constraint:** Higher DPI = more pixels = more memory + slower rendering.

**Memory calculation:**
- Page size: 8.5" × 11" = 935 pixels × 1210 pixels at 110 DPI
- At 300 DPI: 2550 × 3300 = 8.4 million pixels
- At 4 bytes per pixel (RGBA): 33.6 MB per page

**Constraint:** 33.6 MB × 100 pages = 3.36 GB. Can't pre-render all pages at high DPI.

### 3.2 Color Depth

| Color Depth | Colors | Memory per Pixel |
|---|---|---|
| 1-bit | 2 (B&W) | 0.125 bytes |
| 8-bit grayscale | 256 | 1 byte |
| 8-bit indexed | 256 | 1 byte |
| 24-bit RGB | 16.7 million | 3 bytes |
| 32-bit RGBA | 16.7M + transparency | 4 bytes |
| 48-bit RGB | 281 trillion | 6 bytes |

**Constraint:** Higher color depth = more memory + slower rendering.

### 3.3 Anti-aliasing

**Problem:** Vectors have infinite resolution. Pixels have finite resolution. Without anti-aliasing, edges look jagged.

**Solution:** Blend pixel colors at edges to create smooth appearance.

**Cost:**
- 4x oversampling: 4x memory, 4x compute
- Post-filter anti-alias: 1x memory, 1x compute (lower quality)
- Hardware anti-alias: 0x memory, 0x compute (GPU handles it)

**Constraint:** Better anti-aliasing = more computation = slower rendering.

---

## 4. The Mathematical Constraints

### 4.1 Coordinate Transformation

**PDF coordinates → Screen coordinates:**

```
screen_x = (pdf_x - page_left) × (screen_width / page_width)
screen_y = (page_height - pdf_y) × (screen_height / page_height)
```

**But:** PDF pages can be:
- Rotated (0°, 90°, 180°, 270°)
- Cropped (MediaBox ≠ CropBox)
- Scaled (different DPI)
- Flipped (mirror image)

**Each transformation requires matrix multiplication:**

```
[x']   [a b 0]   [x]
[y'] = [c d 0] × [y]
[1 ]   [e f 1]   [1]
```

**Constraint:** 6 matrix multiplications per coordinate. millions of coordinates per page.

### 4.2 Scanline Conversion

**Problem:** Convert vector paths to pixel rows.

**Algorithm:**
1. For each scanline (row of pixels)
2. Find intersections with vector paths
3. Determine inside/outside for each pixel
4. Fill pixels accordingly

**Complexity:** O(n × m) where n = number of paths, m = number of pixels

**Constraint:** 1000 paths × 1000 pixels = 1 million operations per row. 1000 rows = 1 billion operations per page.

### 4.3 Text Rendering

**Problem:** Convert font glyphs to pixels.

**Steps:**
1. Look up glyph outline in font
2. Transform outline to page coordinates
3. Fill outline with color
4. Apply hinting (grid-fitting)
5. Apply anti-aliasing

**Complexity:** O(g × p) where g = number of glyphs, p = points per glyph

**Constraint:** 1000 glyphs × 100 points = 100,000 operations. At 300 DPI, each glyph = 1000 pixels.

---

## 5. The Approaches

### Approach 1: CPU Rendering

**What it does:**
- Renders on main thread
- Uses CPU for all calculations
- Single-core processing

**Mathematical analysis:**
- Time: O(n × m) where n = complexity, m = resolution
- Space: O(w × h) where w = width, h = height
- Best case: Simple document, low resolution
- Worst case: Complex document, high resolution

**When to use:**
- Simple documents
- Low-resolution preview
- No GPU available

**When NOT to use:**
- Large documents
- High-resolution rendering
- Real-time interaction

### Approach 2: GPU Rendering

**What it does:**
- Uses graphics card for rendering
- Parallel processing (thousands of cores)
- Hardware acceleration

**Mathematical analysis:**
- Time: O(n × m / cores) where cores = GPU cores
- Space: O(w × h) in GPU memory
- Best case: Highly parallel operations
- Worst case: Sequential operations (branch-heavy)

**When to use:**
- Complex documents
- High-resolution rendering
- Real-time interaction

**When NOT to use:**
- No GPU available
- Low-memory devices
- Battery-constrained devices

### Approach 3: Hybrid Rendering

**What it does:**
- CPU for structure (parsing, layout)
- GPU for display (rasterization, compositing)
- Smart caching

**Mathematical analysis:**
- Time: O(n_cpu + n_gpu) where n_cpu = CPU work, n_gpu = GPU work
- Space: O(w × h) in GPU memory + cache
- Best case: Balanced workload
- Worst case: One bottleneck

**When to use:**
- Most documents
- Most devices
- Most use cases

**When NOT to use:**
- Extremely simple documents (CPU only is fine)
- Extremely complex documents (GPU may not help)

---

## 6. The Tradeoffs

### 6.1 Speed vs Quality

| Approach | Speed | Quality | Use Case |
|---|---|---|---|
| CPU, low DPI | Fastest | Low | Preview |
| CPU, high DPI | Slow | High | Print |
| GPU, low DPI | Fast | Low | Screen |
| GPU, high DPI | Medium | High | High-quality screen |

### 6.2 Memory vs Quality

| Approach | Memory | Quality | Use Case |
|---|---|---|---|
| Low DPI | Low | Low | Mobile |
| Medium DPI | Medium | Medium | Desktop |
| High DPI | High | High | Print |

### 6.3 Battery vs Quality

| Approach | Battery | Quality | Use Case |
|---|---|---|---|
| CPU | Low | Medium | Battery saver |
| GPU | High | High | Plugged in |
| Adaptive | Medium | Medium | Smart |

---

## 7. What We Use Today

**PDFKit (CPU + Hybrid on macOS):**
- CPU rendering on iOS
- Hybrid rendering on macOS (GPU for display)
- Lazy loading (render on-demand)

**Strengths:**
- Reliable
- Good quality
- Works everywhere

**Weaknesses:**
- May be slow on complex documents
- No GPU acceleration on iOS
- No progressive rendering

---

## 8. What We Should Consider

### 8.1 Short-term (1-3 months)

**Progressive rendering:**
- Render low-res first (instant feedback)
- Render high-res in background (smooth upgrade)
- Cache rendered pages

**Why:** Perceived speed improvement without quality loss.

### 8.2 Medium-term (3-12 months)

**GPU acceleration:**
- Use Metal (iOS/macOS) for rendering
- Parallelize rasterization
- Hardware anti-aliasing

**Why:** 10x speed improvement for complex documents.

### 8.3 Long-term (1-3 years)

**Adaptive rendering:**
- Detect device capabilities
- Adjust DPI based on display
- Optimize for battery vs quality
- Learn user preferences

**Why:** Best experience on every device.

---

## 9. The Key Insight

**Rasterization is lossy.** You're converting infinite-resolution vectors to finite-resolution pixels. The quality depends on DPI, anti-aliasing, and color depth.

**The long-term optimal solution:** Render at the exact DPI needed for the current display, use GPU for speed, cache aggressively, and adapt to device capabilities.

**This is what modern PDF readers do.** We should do it better.

---

## 10. Evidence

- Graphics programming (scanline conversion, anti-aliasing)
- GPU programming (Metal, CUDA, OpenCL)
- PDF rendering engines (PDFKit, PDFium, MuPDF)
- Performance benchmarks (render speed, memory usage)
- Display technology (Retina, OLED, HDR)
