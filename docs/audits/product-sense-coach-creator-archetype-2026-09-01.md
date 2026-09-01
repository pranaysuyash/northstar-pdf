# Product Sense Coach — Creator Archetype (2026-09-01)

**Framework:** AI Engineering Toolkit — Skill 6: Product Sense Coach (5-phase)
**Subject:** CREATE / DESIGN / PUBLISH creator archetype
**Date:** 2026-09-01
**Existing analysis:** `jtbd-creator-archetype-create-design-publish-2026-08-28.md` (22-dimension), `creator-archetype-implementation-2026-08-28.md` (implementation)

---

## Phase 1: Motivation — Why Does This Problem Exist?

### The User Problem

Reading PDFs is a solved problem. Every device has a viewer. But **creating PDFs** is broken:

| Current Solution | What It Does | What It Doesn't Do |
|---|---|---|
| **macOS Preview** | View, basic annotate | No creation, no design, no forms |
| **Pages/Word** | Create documents | Export to PDF is lossy (fonts, layout break) |
| **Google Docs** | Create + collaborate | PDF export loses formatting |
| **Adobe Acrobat** | Full PDF creation | $240/year, subscription, complex |
| **PDF Expert** | Good reader + basic edit | $80/year, limited creation |
| **LaTeX** | Perfect PDF output | Requires technical expertise, slow iteration |
| **Canva** | Visual document creation | Web-only, not local-first, PDF export limited |

**The gap:** There is no local-first, privacy-respecting, professional PDF creation tool that:
1. Creates PDFs from scratch without cloud dependency
2. Produces print-quality output with design constraints
3. Preserves source data (no lossy conversion)
4. Works offline with full functionality
5. Costs nothing (open-source)

### Who Cares?

| Persona | Pain Point | Current Workaround | Willingness to Switch |
|---|---|---|---|
| **Independent author** | Needs to self-publish PDFs without paying Adobe | Uses Word → PDF (lossy) or LaTeX (complex) | High — if creation is easy |
| **Teacher** | Creates worksheets, tests, handouts weekly | Uses Google Docs → PDF | Medium — if templates work |
| **Small business** | Creates invoices, proposals, reports | Uses Canva or Word | Medium — if design is good |
| **Legal professional** | Creates contracts, filings | Uses Word + Acrobat | Low — needs PDF/A compliance |
| **Researcher** | Creates papers, posters | Uses LaTeX or PowerPoint | Low — needs equation support |
| **Student** | Creates simple documents | Uses Google Docs | High — if it's free and easy |

### Why Now?

1. **PDF editor market is $5.5B in 2026, growing 18% CAGR** — the market is expanding, not shrinking
2. **AI is reshaping creation** — local AI (MLX, CoreML) enables smart creation without cloud
3. **Privacy consciousness is rising** — users want local-first tools that don't send data to the cloud
4. **The Reader archetype is complete** — 19 jobs, full pipeline, deep analysis. The engine is ready for creation.
5. **ContentAuthor engine exists** — 534 lines, state machine, undo/redo, element model. The foundation is solid.

### Motivation Verdict

**Strong.** The problem is real (PDF creation is broken), the market is large ($5.5B), the timing is right (privacy + local AI), and the foundation exists (ContentAuthor engine). The question is not "should we build this" but "how fast can we ship the first useful version."

---

## Phase 2: Market Opportunity — Who Else Is Solving This?

### Competitive Landscape

| Competitor | Price | Creation | Design | Privacy | Local-First | AI |
|---|---|---|---|---|---|---|
| **Adobe Acrobat** | $240/yr | ✅ Full | ✅ Full | ❌ Cloud | ❌ | ⚠️ Firefly |
| **PDF Expert** | $80/yr | ⚠️ Basic | ⚠️ Basic | ⚠️ Partial | ⚠️ Partial | ❌ |
| **Pages** | Free | ✅ Good | ✅ Good | ✅ Local | ✅ | ❌ |
| **Canva** | Free/$13/mo | ✅ Visual | ✅ Excellent | ❌ Cloud | ❌ | ✅ Magic Design |
| **Figma** | Free/$15/mo | ✅ Design | ✅ Excellent | ❌ Cloud | ❌ | ✅ AI features |
| **Notion** | Free/$10/mo | ⚠️ Blocks | ⚠️ Basic | ❌ Cloud | ❌ | ✅ AI writing |
| **LaTeX** | Free | ✅ Perfect | ✅ Perfect | ✅ Local | ✅ | ❌ |
| **PDFgear** | Free | ⚠️ Basic | ⚠️ Basic | ⚠️ Unknown | ⚠️ | ❌ |
| **Our App** | Free | ⚠️ Engine only | ⚠️ Engine only | ✅ Zero-egress | ✅ | ⚠️ Local OCR |

### Where We Win

| Dimension | Our Advantage | Competitor Weakness |
|---|---|---|
| **Privacy** | Zero-egress, value-free logging, local-only | Adobe/Canva/Notion send data to cloud |
| **Cost** | Free, open-source | Adobe $240/yr, PDF Expert $80/yr |
| **Local-first** | Full functionality offline | Canva/Figma require internet |
| **Evidence-based** | Every claim backed by tests | Competitors make marketing claims |
| **Template detection** | LayoutFingerprintV2 finds form families | No competitor does this |
| **OCR** | Multi-provider (Vision, Tesseract, PaddleOCR) | Most competitors use single OCR |

### Where We Lose

| Dimension | Our Gap | Competitor Advantage |
|---|---|---|
| **Feature completeness** | No authoring canvas UI yet | Adobe/Pages have full creation |
| **Design tools** | No grid, styles, master pages | Canva/Figma have excellent design |
| **Ecosystem** | No templates, no marketplace | Canva has millions of templates |
| **Platform** | macOS only | Most competitors are cross-platform |
| **Brand** | Unknown | Adobe is household name |
| **Speed to market** | Engine exists, UI doesn't | Competitors have shipped |

### Market Sizing

| Segment | TAM | Our Share (Current) | Our Share (Year 1) |
|---|---|---|---|
| Privacy-conscious professionals | $500M | 0% | 0.1% ($500K) |
| Open-source PDF tools | $200M | 0% | 0.5% ($1M) |
| Education (teachers + students) | $1B | 0% | 0.05% ($500K) |
| Small business PDF creation | $2B | 0% | 0.02% ($400K) |
| **Total addressable** | **$3.7B** | **0%** | **$2.4M** |

### Market Opportunity Verdict

**Large but competitive.** The market is $5.5B and growing. Our differentiation is privacy + local-first + open-source — a niche that Adobe, Canva, and Notion cannot serve. The risk is that Pages (free, local, Apple) already covers the "basic creation" use case. Our moat is the combination of creation + privacy + evidence-based claims + template intelligence.

---

## Phase 3: Path — How Do We Get There?

### Current State Assessment

| Component | Lines | Status | What It Does |
|---|---|---|---|
| ContentAuthor | 534 | ✅ Complete | State machine, undo/redo, element management |
| DocumentElement | 404 | ✅ Complete | Text, image, shape, form field, frame, z-index |
| AuthoringCanvasView | 598 | ✅ Complete | Interactive canvas, tool picker, element placement |
| DesignSystem | 278 | ✅ Complete | Grid, page layouts, master elements, styles |
| PublishPipeline | 289 | ✅ Complete | 4 destinations, optimization, audit trail |
| **Total** | **2,103** | **Engine + UI exist** | |

### What's Missing (from the 22-dimension analysis)

| Priority | Gap | Job | Impact | Effort | Phase |
|---|---|---|---|---|---|
| 1 | Paragraph text flow (word-wrap) | CREATE | 🔴 Critical | HIGH | Phase 1 |
| 2 | Rich text editing (bold/italic per-character) | CREATE | 🔴 Critical | HIGH | Phase 1 |
| 3 | Image resize handles | CREATE | 🟡 High | MEDIUM | Phase 1 |
| 4 | Table creation tool | CREATE | 🟡 Medium | HIGH | Phase 2 |
| 5 | CSS-like style cascading | DESIGN | 🟡 Medium | HIGH | Phase 2 |
| 6 | Print dialog integration | PUBLISH | 🟡 Medium | MEDIUM | Phase 2 |
| 7 | PDF/A compliance | PUBLISH | 🟡 Medium | HIGH | Phase 3 |
| 8 | Email integration | PUBLISH | 🟢 Low | LOW | Phase 3 |

### The Path (3 Phases)

**Phase 1 — Make It Usable (4-6 weeks)**
Ship a minimum viable creation tool that can:
- Create a document from scratch with text, images, and shapes
- Flow text across lines and paragraphs
- Apply basic formatting (font, size, color, bold/italic)
- Export as PDF

**Phase 2 — Make It Professional (6-8 weeks)**
Add design constraints that make output look good:
- Grid snapping and alignment tools
- Master pages (headers, footers, page numbers)
- Style system (paragraph + character styles)
- Table creation

**Phase 3 — Make It Complete (8-12 weeks)**
Fill the remaining gaps:
- Print dialog integration
- PDF/A compliance
- Email/web export
- Batch creation pipeline

### First Milestone: The 5-Minute Test

Can a user create a professional-looking 1-page document in under 5 minutes? Today: No. After Phase 1: Yes.

The 5-minute test:
1. Open app → Cmd+N → blank canvas (10 seconds)
2. Type heading → bold, 24pt, centered (30 seconds)
3. Type body text → flows to multiple lines (30 seconds)
4. Drag in a logo → resize and position (30 seconds)
5. Add a footer with page number (30 seconds)
6. Export as PDF (10 seconds)
7. **Total: ~2.5 minutes** — under the 5-minute budget

### Path Verdict

**Clear and achievable.** The engine exists (2,103 lines). The gap is the presentation layer — specifically paragraph flow, rich text editing, and image resize. Phase 1 is the highest leverage: it turns the engine into a usable tool.

---

## Phase 4: Scenarios — How Will Users Actually Use This?

### Scenario 1: The Teacher (Weekly, High Frequency)

**Sarah, 8th grade science teacher**

- **Monday:** Opens app → Cmd+N → selects "Worksheet" template → types questions → adds answer lines → exports PDF → prints 30 copies
- **Wednesday:** Creates a lab report template → saves as template → students fill it in
- **Friday:** Creates a quiz from last week's material → exports → emails to absent student

**Current workaround:** Google Docs → Print to PDF → formatting breaks → manually fix margins

**Our value:** Templates + consistent formatting + local privacy (student data stays on device)

### Scenario 2: The Freelance Writer (Monthly, Medium Frequency)

**Marcus, self-published author**

- **Monthly:** Creates a newsletter → writes articles → adds images → exports as PDF → uploads to Substack
- **Quarterly:** Creates a press kit → resume, bio, sample chapters → exports as multi-page PDF
- **Yearly:** Creates an annual report for his writing group

**Current workaround:** Canva (cloud, costs money for premium features) or Pages (lossy PDF export)

**Our value:** Local-first (manuscripts stay on device) + free + professional output

### Scenario 3: The Small Business Owner (Weekly, High Frequency)

**Priya, consulting firm owner**

- **Weekly:** Creates proposals → company logo, project scope, pricing table → exports PDF → sends to clients
- **Monthly:** Creates invoices → line items, totals, tax → exports PDF → sends to clients
- **Quarterly:** Creates reports → charts, tables, executive summary → exports PDF → presents to board

**Current workaround:** Word → PDF (formatting breaks) or Canva ($13/month, internet required)

**Our value:** Professional output + templates + local (client data stays on device) + free

### Scenario 4: The Student (Occasional, Low Frequency)

**Alex, college sophomore**

- **Semesterly:** Creates a lab report → title page, sections, figures, bibliography → exports PDF → submits
- **Monthly:** Creates a presentation outline → bullet points, images → exports PDF → prints for study group

**Current workaround:** Google Docs → PDF (works, but cloud-based)

**Our value:** Free + local + doesn't require Google account

### Scenario 5: The Developer (Weekly, High Frequency)

**Jordan, iOS developer**

- **Weekly:** Generates API documentation PDFs from code comments
- **Monthly:** Creates user guides for apps → screenshots, code blocks, step-by-step instructions
- **Quarterly:** Creates compliance documents → structured format, versioned

**Current workaround:** Markdown → pandoc → PDF (command-line, no design control)

**Our value:** Programmatic creation via ScriptingCLI + local + version-controlled

### Scenario 6: The Privacy-Conscious Professional (Daily, High Frequency)

**Dr. Chen, healthcare researcher**

- **Daily:** Creates research notes → encrypted, local, never touches cloud
- **Weekly:** Creates consent forms → structured PDF with fillable fields
- **Monthly:** Creates IRB submissions → multi-page document with tables and figures

**Current workaround:** LaTeX (complex) or Word (sends to Microsoft cloud)

**Our value:** Zero-egress + evidence-based + local-only + encrypted

### Scenario Summary

| Scenario | Frequency | Key Need | Our Best Feature |
|---|---|---|---|
| Teacher | Weekly | Templates + printing | DesignSystem presets |
| Freelance writer | Monthly | Professional output | PublishPipeline |
| Small business | Weekly | Proposals + invoices | ContentAuthor + templates |
| Student | Occasional | Simple creation | Free + local |
| Developer | Weekly | Programmatic creation | ScriptingCLI |
| Privacy professional | Daily | Local + encrypted | Zero-egress + encryption |

---

## Phase 5: Competition — What's Our Moat?

### The Competitive Matrix

| Dimension | Adobe | Canva | Pages | LaTeX | **Us** |
|---|---|---|---|---|---|
| **Creation** | ✅ Full | ✅ Visual | ✅ Good | ✅ Perfect | ⚠️ Engine (no UI yet) |
| **Design** | ✅ Full | ✅ Excellent | ✅ Good | ✅ Perfect | ⚠️ Constraints exist |
| **Publish** | ✅ Full | ✅ Good | ✅ Good | ✅ Perfect | ⚠️ PDF export only |
| **Privacy** | ❌ Cloud | ❌ Cloud | ✅ Local | ✅ Local | ✅ Zero-egress |
| **Cost** | $240/yr | Free/$13/mo | Free | Free | Free |
| **AI** | ✅ Firefly | ✅ Magic | ❌ | ❌ | ⚠️ Local OCR |
| **Templates** | ✅ Many | ✅ Millions | ✅ Some | ❌ | ⚠️ Few |
| **Open-source** | ❌ | ❌ | ❌ | ✅ | ✅ |
| **Evidence-based** | ❌ | ❌ | ❌ | ❌ | ✅ |
| **Template intelligence** | ❌ | ❌ | ❌ | ❌ | ✅ (LayoutFingerprintV2) |

### Our Moat (What Competitors Can't Copy)

1. **Zero-egress invariant** — Adobe, Canva, Notion are cloud businesses. They cannot go local-first without destroying their revenue model.

2. **Evidence-based claims** — We prove our claims with tests. Adobe says "fastest PDF editor." We say "0.23s average page render, measured on 192-fixture corpus, verified by automated gate." This is a fundamentally different value proposition.

3. **Template intelligence** — LayoutFingerprintV2 detects form families across PDFs. No competitor does this. It's a unique capability that emerges from the Reader archetype's depth.

4. **Open-source + free** — We can never be out-priced. Adobe charges $240/yr. Canva charges $13/mo. We charge $0.

5. **Local AI** — As on-device AI improves (MLX, CoreML), we can add smart features (auto-layout, content suggestions, design hints) without cloud dependency. Competitors are locked into cloud AI.

### What Competitors Could Do to Hurt Us

| Threat | Likelihood | Impact | Our Defense |
|---|---|---|---|
| Apple adds PDF creation to Pages | HIGH | HIGH | Pages lacks privacy evidence + template intelligence |
| Adobe makes Acrobat free | MEDIUM | HIGH | Adobe's business model depends on subscriptions |
| Canva adds offline mode | LOW | MEDIUM | Canva's infrastructure is cloud-native |
| Open-source competitor (e.g., PDF.js creator) | MEDIUM | MEDIUM | We have deeper engine + evidence-based claims |
| Google adds PDF creation to Docs | HIGH | MEDIUM | Google is cloud-first, privacy is antithetical |

### The Positioning Statement

> **For** privacy-conscious professionals who create PDFs regularly, **our product** is a local-first PDF creation tool that **unlike** Adobe Acrobat and Canva, **never sends your data to the cloud**, **unlike** Pages and LaTeX, **provides professional design constraints**, and **unlike** all competitors, **backs every claim with automated tests**.

### The One-Line Pitch

> "The only PDF creator that proves it works."

### Competition Verdict

**Defensible niche.** We cannot compete with Adobe on features or Canva on templates. But we can own the intersection of privacy + evidence + local-first. This is a $500M-$1B niche within the $5.5B market. The moat is structural (zero-egress is incompatible with cloud business models) and reputational (evidence-based claims build trust over time).

---

## Summary: The 5-Phase Verdict

| Phase | Key Finding | Confidence |
|---|---|---|
| **1. Motivation** | PDF creation is broken. Market is $5.5B. Foundation exists. | HIGH |
| **2. Market** | Large but competitive. Our niche is privacy + evidence + free. | HIGH |
| **3. Path** | Engine exists (2,103 lines). Gap is presentation layer. 3 phases. | HIGH |
| **4. Scenarios** | 6 clear user personas. Teacher and small business are highest frequency. | MEDIUM |
| **5. Competition** | Defensible niche. Moat is structural (zero-egress) + reputational (evidence). | HIGH |

### The Decision

**Build it.** The motivation is strong, the market is large, the path is clear, the scenarios are real, and the competition is beatable in our niche. The first milestone is the 5-minute test: can a user create a professional 1-page document in under 5 minutes?

### What to Build First (Phase 1 Priority)

| # | Feature | Why First | Effort |
|---|---|---|---|
| 1 | Paragraph text flow | Without this, text creation is unusable | HIGH |
| 2 | Rich text editing (bold/italic) | Without this, documents look plain | HIGH |
| 3 | Image resize handles | Without this, images can't be positioned | MEDIUM |
| 4 | Font size picker | Without this, typography is impossible | LOW |
| 5 | Export preview | Without this, users can't see output before export | MEDIUM |

### What NOT to Build Yet

| Feature | Why Not Now |
|---|---|
| Table creation | Tables are complex; ship text + images first |
| Style system | Styles need paragraph flow first |
| Print dialog | PDF export is sufficient for v1 |
| Email integration | Can share PDF file manually for v1 |
| PDF/A compliance | Niche requirement, not v1 |
