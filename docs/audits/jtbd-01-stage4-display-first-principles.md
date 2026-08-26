# Stage 4: DISPLAY — First Principles Deep Dive

**Date:** 2026-08-26
**Scope:** What does it mean to show PDF content to the user? What are the physical constraints? What is the long-term optimal solution?

---

## 1. First Principle

Display means **presenting rendered content to the user's senses**. After parsing, interpreting, and rasterizing, the content must reach the user's eyes (or screen reader) with minimal friction.

**The fundamental constraint:** The user's attention is limited. Every millisecond of delay, every pixel of blur, every awkward interaction breaks their flow.

---

## 2. What Display Actually Means

### 2.1 The Display Pipeline

```
Rendered pixels → Buffer → Composite → Scale → Output → User
                  ↓         ↓          ↓       ↓       ↓
              Frame      Layer      DPI     Color   Screen
              buffer     merging    matching space   or print
```

### 2.2 The User's Perception

The user doesn't see pixels. They see:
- **Content** — what the document says
- **Layout** — how it's organized
- **Quality** — how clear it is
- **Responsiveness** — how fast it responds

### 2.3 The Interaction Loop

```
User action → System response → User perception → User decision → User action
     ↓              ↓                ↓                ↓              ↓
   Scroll         Render          See page         Read more      Scroll
   Zoom           Scale           See detail       Find info      Search
   Click          Navigate        See target       Understand     Annotate
```

**The loop must be fast.** If any step is slow, the user notices.

---

## 3. The Physical Constraints

### 3.1 Display Hardware

| Display Type | Resolution | Color Space | Refresh Rate |
|---|---|---|---|
| Standard LCD | 1920×1080 | sRGB | 60 Hz |
| Retina | 2560×1600 | P3 | 60 Hz |
| 4K | 3840×2160 | HDR | 60-144 Hz |
| Mobile | 1170×2532 | P3 | 60-120 Hz |
| E-ink | 1404×1872 | Grayscale | 15 Hz |

**Constraint:** Each display has different capabilities. Content must adapt.

### 3.2 Human Perception

| Perception | Threshold | Budget |
|---|---|---|
| Visual reaction | 200ms | <100ms for "instant" |
| Motion detection | 50ms | <16ms for 60fps |
| Color differentiation | 1 million colors | 24-bit RGB sufficient |
| Text readability | 8pt minimum | Must scale properly |
| Brightness adaptation | 0.1-100,000 nits | Must handle HDR |

**Constraint:** Human perception sets the quality requirements.

### 3.3 Network/Storage

| Medium | Speed | Latency |
|---|---|---|
| SSD | 500 MB/s | 0.1ms |
| HDD | 100 MB/s | 5ms |
| Wi-Fi | 50 MB/s | 10ms |
| 4G | 10 MB/s | 50ms |
| 3G | 1 MB/s | 200ms |

**Constraint:** Content must load fast enough to not break flow.

---

## 4. The Mathematical Constraints

### 4.1 Frame Timing

**60fps = 16.67ms per frame**

```
Time budget per frame:
- Parse input: 1ms
- Process: 5ms
- Render: 5ms
- Composite: 2ms
- Output: 1ms
- Buffer: 2.67ms
Total: 16.67ms
```

**Constraint:** If any step exceeds its budget, frame drops.

### 4.2 Scaling Mathematics

**Zoom factor Z:**

```
screen_pixel = (original_pixel - origin) × Z + origin
```

**At 200% zoom:**
- Each pixel becomes 4 pixels (2×2)
- Must interpolate or tile
- Memory usage = 4× original

**At 50% zoom:**
- Each 4 pixels become 1 pixel
- Must downsample or discard
- Memory usage = 0.25× original

**Constraint:** Scaling affects both quality and memory.

### 4.3 Scrolling Mathematics

**Scroll position P, viewport height H, document height D:**

```
visible_start = P
visible_end = P + H
clamped_start = max(0, min(P, D - H))
clamped_end = max(H, min(P + H, D))
```

**For smooth scrolling:**
- Need to render ahead (preload)
- Need to render behind (for back-scroll)
- Need to cache rendered pages

**Constraint:** Smooth scrolling requires predictive rendering.

---

## 5. The Approaches

### Approach 1: Full Page Display

**What it does:**
- Render entire page at once
- Display when complete
- No progressive loading

**Mathematical analysis:**
- Time: O(page_render_time) per page
- Memory: O(page_pixels) per page
- Quality: Highest (full resolution)
- Latency: Highest (wait for full render)

**When to use:**
- Print (need full quality)
- Static viewing (no interaction)
- Simple documents (fast render)

**When NOT to use:**
- Large documents (slow)
- Interactive viewing (need speed)
- Mobile devices (limited memory)

### Approach 2: Progressive Display

**What it does:**
- Render low-res first (instant preview)
- Render high-res in background
- Upgrade when ready

**Mathematical analysis:**
- Time: O(low_res_time) for preview, O(full_time) for quality
- Memory: O(low_res_pixels + full_res_pixels) temporarily
- Quality: Varies (low to high)
- Latency: Lowest (instant feedback)

**When to use:**
- Large documents (need speed)
- Interactive viewing (need responsiveness)
- Mobile devices (limited memory)

**When NOT to use:**
- Print (need full quality immediately)
- Static viewing (no benefit)

### Approach 3: Tile-Based Display

**What it does:**
- Divide page into tiles (e.g., 256×256 pixels)
- Render visible tiles first
- Render off-screen tiles later
- Cache rendered tiles

**Mathematical analysis:**
- Time: O(visible_tiles × tile_render_time) per frame
- Memory: O(visible_tiles × tile_pixels) per frame
- Quality: Good (tiles are full resolution)
- Latency: Lowest (only render what's visible)

**When to use:**
- Large documents (need efficiency)
- Interactive viewing (need smooth scrolling)
- Zoom operations (need detail on demand)

**When NOT to use:**
- Print (need full page)
- Simple documents (overhead not worth it)

---

## 6. The Tradeoffs

### 6.1 Latency vs Quality

| Approach | Latency | Quality | Use Case |
|---|---|---|---|
| Full Page | High | Highest | Print, static |
| Progressive | Lowest | Varies | Interactive |
| Tile-Based | Low | Good | Large documents |

### 6.2 Memory vs Responsiveness

| Approach | Memory | Responsiveness | Use Case |
|---|---|---|---|
| Full Page | High | Low | Desktop, small docs |
| Progressive | Medium | High | Mobile, large docs |
| Tile-Based | Low | Highest | Any device, any doc |

### 6.3 Complexity vs Capability

| Approach | Complexity | Capability | Use Case |
|---|---|---|---|
| Full Page | Low | Basic | Simple readers |
| Progressive | Medium | Good | Modern readers |
| Tile-Based | High | Excellent | Professional readers |

---

## 7. What We Use Today

**PDFKit (Full Page + Lazy Loading):**
- Renders full page when needed
- Lazy loads pages (not all at once)
- Basic caching

**Strengths:**
- Simple
- Reliable
- Good quality

**Weaknesses:**
- May be slow on large documents
- No progressive rendering
- No tile-based rendering
- No predictive loading

---

## 8. What We Should Consider

### 8.1 Short-term (1-3 months)

**Progressive rendering:**
- Show low-res immediately
- Upgrade to high-res in background
- Cache rendered pages

**Why:** Instant feedback without quality loss.

### 8.2 Medium-term (3-12 months)

**Tile-based rendering:**
- Divide pages into tiles
- Render visible tiles first
- Cache tiles across pages
- Smooth scrolling

**Why:** Best performance for large documents.

### 8.3 Long-term (1-3 years)

**Predictive display:**
- Predict user's next action
- Pre-render likely content
- Pre-load likely pages
- Adapt to user behavior

**Why:** Zero-latency experience.

---

## 9. The Key Insight

**Display is perception.** The user doesn't care about rendering — they care about seeing content. The best display is invisible.

**The long-term optimal solution:**
1. Render at exact DPI for current display
2. Use progressive rendering for instant feedback
3. Use tile-based rendering for efficiency
4. Cache aggressively
5. Predict and pre-load

**This is what makes a PDF reader feel instant.**

---

## 10. Evidence

- Display technology (LCD, OLED, Retina, E-ink)
- Human perception (reaction time, color, motion)
- Frame timing (60fps, 120fps, variable refresh)
- Graphics programming (compositing, scaling, anti-aliasing)
- User experience research (what makes UIs feel fast?)
