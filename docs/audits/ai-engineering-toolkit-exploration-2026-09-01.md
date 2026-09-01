# AI Engineering Toolkit — Full Exploration (2026-09-01)

**Skill source:** `ai-engineering-toolkit` (viliawang-pm, MIT license)
**Exploration scope:** All 6 skills evaluated against the pdf_editor project
**Status:** Exploration complete — implementation candidates identified

---

## Skill 1: Prompt Evaluator

### What it does
Scores prompts across 8 dimensions (Clarity, Specificity, Completeness, Conciseness, Structure, Grounding, Safety, Robustness) on 1-10 scale with weighted aggregation to 0-100. Identifies 3 weakest dimensions, generates rewrites.

### Application to project

**Prompts to evaluate:**

| Prompt | Location | Purpose |
|---|---|---|
| Companion bridge protocol | `Sources/PDFEditorCore/CompanionBridge.swift` | Capability handshake, request/response |
| OCR provider instructions | `Sources/PDFEditorCore/OCR.swift` | Provider selection, confidence thresholds |
| UserScript presets | `Sources/PDFEditorCore/UserScriptRunner.swift` | Batch workflow definitions |
| AgentCommandHUD | `Sources/PDFEditorApp/AgentCommandHUD.swift` | User-facing command palette |
| Reading mode configs | `Sources/PDFEditorCore/ReadingMode.swift` | Study/Skim/Reference/Review presets |

**Quick evaluation of companion bridge protocol:**
- Clarity: 7/10 — Well-structured capability handshake, but some fields undocumented
- Specificity: 6/10 — Missing: timeout values, retry policy, error taxonomy
- Completeness: 5/10 — No fallback for companion unavailability, no version negotiation
- Safety: 8/10 — Zero-egress enforced, value-free logging
- **Overall: ~65/100** — Functional but needs specificity improvements

**Recommendation:** This skill is most useful for **productionizing the companion bridge protocol** before external users interact with it.

---

## Skill 2: Context Budget Planner

### What it does
Analyzes token distribution across 5 context zones (System, Few-shot, User input, Retrieval, Output) and produces optimized allocation. Catches output zone squeeze.

### Application to project

**Context zones in the pdf_editor:**

| Zone | Current | What fills it |
|---|---|---|
| **System** | ~2K tokens | OPERATING_DOCTRINE.md, DOCUMENTATION_DOCTRINE.md |
| **Few-shot** | ~0 | No few-shot examples (rule-based, not LLM) |
| **User input** | ~variable | PDF content, annotations, search queries |
| **Retrieval** | ~variable | Extracted text, field values, entity lists |
| **Output** | ~variable | Summaries, citations, annotations |

**Key finding:** The project is primarily **rule-based**, not LLM-driven. The UNDERSTAND layer uses TF-IDF + TextRank (AISummarizer), not LLM calls. Context budget planning is less relevant here than for an LLM-heavy product.

**Where it IS relevant:**
- **Companion bridge** — when the companion is an LLM, context budget matters for the capability handshake
- **UserScript runner** — batch workflows that could be LLM-orchestrated
- **AI summarization** — if upgraded to LLM-based summarization

**Recommendation:** Low priority for current architecture. Relevant if/when LLM integration is added.

---

## Skill 3: RAG Pipeline Architect

### What it does
Walks through architecture decision tree: document format → parsing → chunking → embedding → retrieval → evaluation. Covers Naive, Advanced, and Modular RAG patterns.

### Application to project

**Current search architecture:**

```
PDF → PDFKit text extraction → exact string matching → highlights
     → TF-IDF term scoring → ranked results
     → LayoutFingerprintV2 → family matching (template detection)
```

**RAG-relevant gaps:**

| Gap | What exists | What RAG would add |
|---|---|---|
| **Chunking** | None (full-text search) | Semantic chunking by paragraph/section |
| **Embeddings** | None | Vector embeddings for semantic search |
| **Retrieval** | Exact + TF-IDF | Hybrid (vector + keyword + re-ranking) |
| **Evaluation** | None | Faithfulness, relevancy, context precision |

**Where RAG fits:**
1. **FIND job** — semantic search across document corpus (currently exact-only)
2. **UNDERSTAND job** — retrieve relevant context for summarization
3. **CITE job** — find related passages for citation generation

**Architecture decision:**
- **Naive RAG** sufficient for single-document search
- **Advanced RAG** needed for multi-document corpus search
- **Modular RAG** needed for cross-document knowledge synthesis

**Key constraint:** Zero-egress policy means embeddings must be computed locally. Use `sentence-transformers` or `mlx` for on-device embeddings.

**Recommendation:** High value for FIND job. Implement vector embeddings + hybrid retrieval for the document corpus.

---

## Skill 4: Agent Safety Guard

### What it does
65-point red-team audit across 5 attack categories: prompt injection, indirect injection, information extraction, tool abuse, goal hijacking.

### Application to project

**Attack surface analysis:**

| Category | Risk Level | What to audit |
|---|---|---|
| **Direct prompt injection** | LOW | No LLM user-facing interface (rule-based) |
| **Indirect injection** | MEDIUM | PDF content could contain malicious instructions if LLM reads it |
| **Information extraction** | LOW | Value-free logging prevents content leakage |
| **Tool abuse** | MEDIUM | Companion bridge could be exploited for file access |
| **Goal hijacking** | LOW | No autonomous agent loop |

**Key findings:**
1. **Zero-egress invariant** (RG-126) is a strong security control — blocks most exfiltration attacks
2. **Value-free logging** (RG-02) prevents content leakage through logs
3. **Companion bridge** needs capability handshake audit — what can a malicious companion do?
4. **PDF content** is a vector for indirect injection if ever fed to an LLM

**Specific vulnerabilities to test:**
- Can a crafted PDF inject instructions into the companion bridge?
- Can the UserScript runner execute arbitrary commands?
- Can the ScriptingCLI bypass sandboxing?

**Recommendation:** Run the 65-point checklist on the companion bridge and ScriptingCLI. Focus on tool abuse and indirect injection categories.

---

## Skill 5: Eval Harness Builder

### What it does
Designs evaluation metric systems for LLM applications. Includes LLM-as-Judge scoring with bias mitigation. Outputs CI/CD-ready evaluation pipeline templates.

### Application to project

**Existing eval infrastructure:**

| Component | What exists | What's missing |
|---|---|---|
| **OCR benchmark** | Tesseract, PaddleOCR, Vision, Marker WER | LLM-as-Judge for OCR quality |
| **Form detection** | Precision/recall on governed corpus | Human-evaluated ground truth |
| **Template matching** | LayoutFingerprintV2 calibration | A/B testing for threshold tuning |
| **Reading modes** | Manual testing | Automated user satisfaction scoring |

**Eval harness candidates:**

1. **OCR quality eval** — LLM-as-Judge scoring OCR output against ground truth
   - Metric: text accuracy, layout preservation, entity extraction F1
   - Bias mitigation: position bias (randomize ground truth order), verbosity bias (normalize length)

2. **Annotation quality eval** — score annotation suggestions against human judgments
   - Metric: highlight relevance, note completeness, entity correctness
   - Bias mitigation: self-enhancement bias (don't let model score its own output)

3. **Reading mode eval** — score mode effectiveness per document type
   - Metric: time-to-understand, comprehension score, user preference
   - Bias mitigation: anchoring bias (vary document order)

**Recommendation:** Build eval harness for OCR providers first (highest ROI). Wire into CI as automated quality gate.

---

## Skill 6: Product Sense Coach

### What it does
5-phase guided conversation: motivation → market opportunity → path → scenarios → competition.

### Application to project

**Phase 1: Motivation**
- **User problem:** Reading PDFs is fragmented across apps with no intelligence
- **Current solution:** Native macOS app + browser companion
- **Differentiator:** Local-first, zero-egress, evidence-based claims

**Phase 2: Market Opportunity**
- **Direct competitors:** Preview (free, built-in), PDF Expert ($80/yr), Acrobat ($230/yr)
- **Gap they miss:** Privacy-first + AI-assisted reading + template detection
- **Target:** Privacy-conscious professionals who read PDFs daily

**Phase 3: Path**
- **Current state:** Reader archetype complete (19 JTBDs), Creator archetype started (3 JTBDs)
- **Next milestone:** Creator archetype Phase 1 (AuthoringCanvasView)
- **Revenue model:** Open-source core + paid companion features

**Phase 4: Scenarios**
- **Primary scenario:** Lawyer reads 50-page contract → gets entity extraction, citation, summary
- **Secondary scenario:** Researcher compares 10 papers → template detection finds same-form family
- **Tertiary scenario:** Student annotates textbook → spaced repetition schedules review

**Phase 5: Competition**
- **Moat:** Local-first architecture + evidence-based claims + template detection
- **Risk:** Acrobat adds AI features, Preview adds basic intelligence
- **Defense:** Ship faster on privacy + local AI, build corpus intelligence

**Recommendation:** The creator archetype (Phase 1: AuthoringCanvasView) is the highest-leverage next step. It converts the reader into a creator, expanding the TAM.

---

## Summary: What to Implement

| Skill | Priority | ROI | Effort | Recommendation |
|---|---|---|---|---|
| **Prompt Evaluator** | LOW | Low | Small | Use for companion bridge before external release |
| **Context Budget** | LOW | Low | Small | Relevant only if LLM integration added |
| **RAG Pipeline** | HIGH | High | Medium | Implement vector search for FIND job |
| **Agent Safety** | HIGH | High | Medium | Run 65-point audit on companion bridge |
| **Eval Harness** | HIGH | High | Medium | Build OCR quality eval for CI |
| **Product Sense** | MEDIUM | High | Small | Guide creator archetype prioritization |

### Top 3 to implement now

1. **Eval Harness for OCR** — wire LLM-as-Judge scoring into CI, fail on quality regression
2. **Agent Safety Audit** — run 65-point checklist on companion bridge + ScriptingCLI
3. **RAG Pipeline for FIND** — add vector embeddings + hybrid retrieval for document search

### Documentation created
- This file: `docs/audits/ai-engineering-toolkit-exploration-2026-09-01.md`
- All 6 skills explored against project architecture
- Implementation candidates ranked by priority/ROI
