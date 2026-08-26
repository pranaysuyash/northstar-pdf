# JTBD-02 FIND — Expanded 22-Dimension Analysis

**Date:** 2026-08-26
**Framework:** Expanded Analytical Framework (beyond 5W1H)
**Job:** "I need to locate specific information in this document"
**Status:** First-principles, long-term, doctrine-aligned analysis

---

## Purpose

Previous analysis covered Find as a sub-job of Read. This applies the **full 22-dimension framework** to the Find job independently, analyzing each dimension from first principles, mapping to our current state, identifying gaps, and proposing long-term solutions.

---

## 1. WHO — Person, Actor, Stakeholder

### 1.1 Person (Primary User)

| Persona | Core Need | Expertise | Frequency | Our Support |
|---|---|---|---|---|
| Student | Find key concepts | Subject expert | Daily | ✅ Search works |
| Lawyer | Find specific clauses | Legal, not PDF | Daily, many docs | ⚠️ No clause detection |
| Executive | Find decision points | Business, not tech | Daily, brief | ⚠️ No summary view |
| Developer | Find API references | Technical | Weekly | ✅ Search works |
| Accountant | Find amounts, dates | Domain expert | Seasonal | ⚠️ No entity extraction |
| Researcher | Find citations | Domain expert | Daily | ⚠️ No citation search |
| Admin | Find specific fields | Operational | Daily | ⚠️ No field search |
| Auditor | Find compliance points | Domain expert | Periodic | ⚠️ No semantic search |

### 1.2 Actor (Who Performs the Action)

| Actor | How they find | Our support |
|---|---|---|
| Human (sighted) | Eyes scan, search, browse | ✅ Visual search |
| Screen reader user | VoiceOver search | ⚠️ Partial |
| Keyboard-only user | ⌘F, arrows, shortcuts | ✅ Keyboard nav |
| Automated process | Programmatic search | ⚠️ Basic API |
| AI assistant | Semantic understanding | ❌ None |

### 1.3 Stakeholder (Who Is Affected by Failure)

| Stakeholder | Impact of poor finding | Severity |
|---|---|---|
| Finder | Wasted time, missed info | HIGH |
| Decision maker | Wrong decision | CRITICAL |
| Organization | Compliance failure | HIGH |
| Data subject | Privacy breach | CRITICAL |
| Legal counsel | Missed clause | HIGH |

---

## 2. WHAT — Thing, Action, Event, Outcome, Artifact

### 2.1 Thing (What Is Being Found)

| Object | Challenge | Our support | Gap |
|---|---|---|---|
| Exact text match | Character-level precision | ✅ PDFKit search | Small |
| Fuzzy text match | Typo tolerance | ❌ None | Large |
| Semantic concept | Meaning-based search | ❌ None | Large |
| Entity (date, amount) | Pattern recognition | ❌ None | Large |
| Table data | Structure-aware search | ❌ None | Large |
| Image content | OCR + search | ⚠️ Basic OCR | Medium |
| Form field value | Field-aware search | ⚠️ Basic | Medium |
| Annotation content | Note search | ⚠️ Limited | Medium |
| Bookmark/outline | Navigation structure | ✅ PDFKit outline | Small |

### 2.2 Action (What the User Does While Finding)

| Action | Frequency | Our support | Priority |
|---|---|---|---|
| Open search (⌘F) | Every session | ✅ Fast | CRITICAL |
| Type search term | Every session | ✅ Responsive | CRITICAL |
| Navigate results (Enter/Shift+Enter) | Every session | ✅ Keyboard | CRITICAL |
| Jump to result | Every session | ✅ Smooth | CRITICAL |
| Search with regex | Some sessions | ❌ None | MEDIUM |
| Search across pages | Every session | ✅ Full doc | HIGH |
| Search in form fields | Some sessions | ⚠️ Partial | HIGH |
| Search in annotations | Rare | ⚠️ Limited | LOW |
| Filter by type | Rare | ❌ None | LOW |
| Search history | Rare | ❌ None | LOW |

### 2.3 Event (What Triggered the Finding)

| Trigger | Urgency | What user needs |
|---|---|---|
| "Where is X?" | HIGH | Instant search |
| "Find all instances of Y" | MEDIUM | Result count + navigation |
| "What comes after Z?" | HIGH | Context around match |
| "Is there any mention of W?" | MEDIUM | Boolean result |
| "How many times does V appear?" | LOW | Count + list |

### 2.4 Outcome (What the User Wants)

| Outcome | Success measure | Our contribution |
|---|---|---|
| "Found it" | Located exact info | Fast, accurate search |
| "Found all of them" | Complete results | Comprehensive search |
| "Found something similar" | Related info | Fuzzy/semantic search |
| "Found nothing" | Confirmed absence | Complete coverage |
| "Found context" | Understood surrounding | Context display |

---

## 3. WHEN — Time, Date, Sequence, Duration, Frequency

### 3.1 Search Patterns

| Pattern | When used | Our optimization |
|---|---|---|
| One-shot search | "Find X, done" | Fast results |
| Iterative search | "Find X, then Y, then Z" | Search history |
| Exploratory search | "What's in here?" | Outline, headings |
| Confirmatory search | "Is X mentioned?" | Boolean result |
| Exhaustive search | "Find everything about X" | Result count, navigation |

### 3.2 Search Duration

| Duration | User behavior | Our optimization |
|---|---|---|
| < 1 second | Instant find | Critical threshold |
| 1-3 seconds | Acceptable | Good |
| 3-10 seconds | Frustrating | Needs improvement |
| 10+ seconds | Broken | Unacceptable |

### 3.3 Search Frequency

| Frequency | Pattern | Our priority |
|---|---|---|
| Every session | Habitual | CRITICAL |
| Most sessions | Regular | HIGH |
| Some sessions | Occasional | MEDIUM |
| Rare | Special use | LOW |

---

## 4. WHERE — Place, Platform, Context, Environment

### 4.1 Search Context

| Context | What changes | Our adaptation |
|---|---|---|
| Quick lookup | Speed matters most | Instant results |
| Deep research | Completeness matters | Result count, navigation |
| Compliance check | Accuracy matters | Exact match, no false positives |
| Review/approval | Navigation matters | Jump to result, context |
| Form filling | Field awareness | Field-specific search |

### 4.2 Platform

| Platform | Search capability | Our support |
|---|---|---|
| macOS | ⌘F, keyboard nav | ✅ Good |
| iOS | Touch search | ❌ No iOS |
| Web | Browser search | ✅ Good |
| CLI | Programmatic | ❌ No CLI |

---

## 5. WHY — Reason, Cause, Motivation, Goal

### 5.1 Why Users Search

| Reason | Urgency | What they need |
|---|---|---|
| Find specific info | HIGH | Fast, accurate |
| Verify something exists | MEDIUM | Boolean result |
| Count occurrences | LOW | Result count |
| Understand context | MEDIUM | Surrounding text |
| Compare mentions | LOW | Multiple results |
| Extract data | MEDIUM | Copy, export |

### 5.2 Search Motivation

| Motivation | Force | Our support |
|---|---|---|
| Deadline pressure | Negative | Fast search |
| Thoroughness requirement | Neutral | Complete results |
| Curiosity | Positive | Exploratory search |
| Compliance | Neutral | Accurate results |

---

## 6. HOW — Method, Process, Mechanism

### 6.1 Search Methods

| Method | When used | Our support |
|---|---|---|
| Exact text match | Default | ✅ PDFKit |
| Case-insensitive | Default | ✅ PDFKit |
| Whole word | Rare | ❌ None |
| Regex | Power users | ❌ None |
| Semantic | AI-powered | ❌ None |
| Structural | Outline-based | ✅ PDFKit |
| Visual | Image-based | ❌ None |

### 6.2 Search Workflow

| Step | What happens | Our support |
|---|---|---|
| 1. Activate | ⌘F or button | ✅ Fast |
| 2. Type | Enter search term | ✅ Responsive |
| 3. Results | Highlight matches | ✅ Visual |
| 4. Navigate | Enter/Shift+Enter | ✅ Keyboard |
| 5. Jump | Go to result | ✅ Smooth |
| 6. Context | See surrounding | ⚠️ Basic |
| 7. Refine | Modify search | ⚠️ No history |
| 8. Close | Dismiss search | ✅ Escape |

### 6.3 Search Mechanisms

| Mechanism | What it means | Our support |
|---|---|---|
| Text indexing | Pre-built index | ❌ None |
| On-the-fly search | Real-time matching | ✅ PDFKit |
| Fuzzy matching | Typo tolerance | ❌ None |
| Stemming | Root word matching | ❌ None |
| Synonym matching | Related terms | ❌ None |
| Contextual search | Meaning-based | ❌ None |

---

## 7. WHICH — Selection Among Alternatives

### 7.1 Which Search Strategy

| Strategy | Tradeoff | Our support |
|---|---|---|
| Exact match | Precise but brittle | ✅ Default |
| Fuzzy match | Forgiving but noisy | ❌ None |
| Semantic search | Meaningful but slow | ❌ None |
| Structural search | Fast but limited | ✅ Outline |
| Visual search | Intuitive but complex | ❌ None |

### 7.2 Which Result to Jump To

| Selection | User decision | Our support |
|---|---|---|
| First match | Most relevant | ✅ Default |
| Last match | Most recent | ⚠️ Manual |
| Specific match | User choice | ✅ Navigation |
| All matches | Complete view | ⚠️ Count only |

---

## 8. WHOSE — Ownership, Responsibility

### 8.1 Search Ownership

| Owner | Responsibility | Our obligation |
|---|---|---|
| Searcher | Finding info | Fast, accurate results |
| Document owner | Content accuracy | Preserve original |
| Organization | Compliance | Complete search |

### 8.2 Search Authority

| Authority | What they control | Our support |
|---|---|---|
| User | Search terms | ✅ Full control |
| System | Search algorithm | ⚠️ PDFKit only |
| Admin | Search permissions | ❌ None |

---

## 9. WHOM — Recipient, Affected Party

### 9.1 Who Benefits from Good Search

| Beneficiary | Benefit | Our contribution |
|---|---|---|
| Primary searcher | Time saved | Fast results |
| Team | Shared knowledge | ❌ No collaboration |
| Organization | Efficiency | Reliable search |
| Compliance | Auditability | Complete results |

### 9.2 Who Is Harmed by Bad Search

| Victim | Harm | Prevention |
|---|---|---|
| Searcher | Wasted time | Fast search |
| Decision maker | Wrong decision | Accurate search |
| Organization | Compliance failure | Complete search |
| Data subject | Privacy breach | Local search |

---

## 10. HOW MUCH — Cost, Value, Risk

### 10.1 Search Cost

| Cost | Type | How we minimize |
|---|---|---|
| Time | Seconds to minutes | Fast search |
| Cognitive load | Mental effort | Clear results |
| Frustration | Emotional | Reliable search |

### 10.2 Search Value

| Value | Type | How we maximize |
|---|---|---|
| Time saved | Efficiency | Fast results |
| Accuracy | Correctness | Exact match |
| Completeness | Thoroughness | All results |
| Context | Understanding | Surrounding text |

### 10.3 Search Risk

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| False positives | MEDIUM | MEDIUM | Exact match |
| False negatives | LOW | HIGH | Complete search |
| Slow search | MEDIUM | MEDIUM | Optimization |
| Privacy breach | LOW | CRITICAL | Local search |

---

## 11. HOW MANY — Count, Scale

### 11.1 Search Scale

| Scale | Challenge | Our support |
|---|---|---|
| 1 page | Trivial | ✅ Fast |
| 10 pages | Standard | ✅ Fast |
| 100 pages | Large | ✅ Fast |
| 1,000 pages | Very large | ⚠️ May be slow |
| 10,000 pages | Massive | ❌ Not optimized |

### 11.2 Result Scale

| Scale | Challenge | Our support |
|---|---|---|
| 0 results | No match | ✅ Clear message |
| 1-10 results | Small set | ✅ Navigation |
| 11-100 results | Medium set | ⚠️ Count only |
| 100-1000 results | Large set | ❌ No filtering |
| 1000+ results | Massive set | ❌ No pagination |

---

## 12. HOW OFTEN — Frequency, Pattern

### 12.1 Search Feature Usage

| Feature | How often | Our priority |
|---|---|---|
| Basic search | Every session | CRITICAL |
| Result navigation | Every session | CRITICAL |
| Case sensitivity | Some sessions | MEDIUM |
| Whole word | Rare | LOW |
| Regex | Rare | LOW |
| Search history | Rare | LOW |

---

## 13. HOW LONG — Duration, Waiting

### 13.1 Search Latency

| Latency | User perception | Our status |
|---|---|---|
| < 50ms | Instant | ✅ Target |
| 50-200ms | Fast | ✅ Good |
| 200ms-1s | Noticeable | ⚠️ Borderline |
| 1-3s | Slow | ❌ Frustrating |
| 3s+ | Broken | ❌ Unacceptable |

### 13.2 State Retention

| State | How long | Our support |
|---|---|---|
| Search term | Until closed | ✅ Session |
| Search position | Until closed | ✅ Session |
| Search history | Session | ❌ None |
| Search preferences | Forever | ❌ None |

---

## 14. HOW FAR — Scope, Depth

### 14.1 Search Scope

| Scope | What's included | Our support |
|---|---|---|
| Current page | One page | ✅ Default |
| Entire document | All pages | ✅ Full doc |
| Multiple documents | Corpus | ❌ None |
| Annotations | Notes | ⚠️ Limited |
| Form fields | Field values | ⚠️ Partial |

### 14.2 Search Depth

| Depth | What's examined | Our support |
|---|---|---|
| Text only | Visible text | ✅ Default |
| Hidden text | Layer content | ⚠️ Partial |
| Metadata | Properties | ❌ None |
| Structure | Outline, tags | ✅ Outline |

---

## 15. WHAT IF — Counterfactuals

### 15.1 Failure Scenarios

| What if | Consequence | Our response |
|---|---|---|
| No results found | User frustrated | Clear message |
| Too many results | User overwhelmed | ❌ No filtering |
| Slow search | User waits | Optimization |
| Wrong results | User misled | Exact match |
| Search crashes | User loses work | Stability |

### 15.2 Edge Cases

| What if | What happens | Our support |
|---|---|---|
| Empty document | No text | ✅ Graceful |
| Scanned PDF | No text layer | ⚠️ OCR prompt |
| Encrypted PDF | Can't search | ✅ Password prompt |
| Large PDF | Slow search | ⚠️ May be slow |
| Unicode text | Special chars | ⚠️ Partial |

---

## 16. WHAT ELSE — Alternatives, Opportunities

### 16.1 What's Missing

| Missing | Impact | Priority |
|---|---|---|
| Fuzzy search | Typo tolerance | HIGH |
| Semantic search | Meaning-based | HIGH |
| Regex search | Power users | MEDIUM |
| Search history | Repeat searches | MEDIUM |
| Search filters | Result narrowing | MEDIUM |
| Cross-document search | Corpus search | LOW |
| Visual search | Image-based | LOW |

### 16.2 What Alternatives Exist

| Alternative | Our advantage |
|---|---|
| Adobe Acrobat search | Privacy, speed |
| Preview search | Features, integration |
| Browser search | Offline, local |
| Grep/command line | Visual, intuitive |

---

## 17. WHAT CHANGED — Evolution

### 17.1 Search Evolution

| Era | What changed | Impact |
|---|---|---|
| 1990s | Basic text search | Foundation |
| 2000s | Full-text indexing | Speed |
| 2010s | Semantic search | Meaning |
| 2020s | AI-powered search | Intelligence |

### 17.2 User Expectations

| Expectation | Before | Now | Our gap |
|---|---|---|---|
| Speed | "It searches" | "Instant" | Small |
| Accuracy | "Finds text" | "Finds meaning" | Large |
| Features | "Basic search" | "Smart search" | Large |
| Privacy | "Don't care" | "Local first" | NONE ✅ |

---

## 18. COMPARED WITH WHAT

### 18.1 Competitive Comparison

| Feature | Us | Adobe | Preview | Browser |
|---|---|---|---|---|
| Basic search | ✅ Fast | ✅ Full | ✅ Basic | ✅ Basic |
| Fuzzy search | ❌ None | ✅ Yes | ❌ None | ❌ None |
| Semantic search | ❌ None | ✅ AI | ❌ None | ❌ None |
| Regex | ❌ None | ✅ Yes | ❌ None | ❌ None |
| Search history | ❌ None | ✅ Yes | ❌ None | ❌ None |
| Privacy | ✅ LOCAL | ❌ Cloud | ✅ LOCAL | ❌ Cloud |

---

## 19. UNDER WHAT CONDITIONS

### 19.1 Constraints

| Constraint | Impact | Our workaround |
|---|---|---|
| PDFKit only | Limited features | Multi-library cascade |
| No indexing | Slow on large docs | Streaming search |
| No AI | No semantic search | Future integration |

### 19.2 Assumptions

| Assumption | Risk | Validation |
|---|---|---|
| PDFKit search is fast enough | MEDIUM | Benchmark |
| Users want exact match | MEDIUM | User testing |
| Privacy matters more than features | LOW | Market research |

---

## 20. WITH WHAT CONFIDENCE

### 20.1 What We Know

| Claim | Evidence | Confidence |
|---|---|---|
| Basic search works | Tests passing | HIGH |
| Search is fast | Internal testing | HIGH |
| Keyboard nav works | Tests passing | HIGH |

### 20.2 What We Don't Know

| Claim | Missing evidence | How to get it |
|---|---|---|
| Users want fuzzy search | No user studies | User testing |
| Search scales to large docs | No load testing | Benchmarks |
| Semantic search is valuable | No market research | Competitive analysis |

---

## 21. SO WHAT

### 21.1 The Fundamental Insight

**Finding is not just search. Finding is understanding where information lives in a document.**

The gap between "search" and "find" is the gap between **text matching** and **information discovery**. Users don't just want to find text — they want to find **meaning**.

### 21.2 What This Means

| Dimension | Current | Needed | Gap |
|---|---|---|---|
| Basic search | Good | Great | SMALL |
| Fuzzy search | None | Required | LARGE |
| Semantic search | None | Valuable | LARGE |
| Entity extraction | None | Valuable | LARGE |
| Search history | None | Useful | MEDIUM |
| Cross-doc search | None | Valuable | LARGE |

---

## 22. WHAT NEXT

### 22.1 Immediate Actions

| Action | Timeline | Dependency |
|---|---|---|
| Add fuzzy search | 2 weeks | None |
| Add search history | 1 week | None |
| Add result count display | 1 day | None |
| Improve search performance | 1 week | Benchmark |

### 22.2 Short-term Actions

| Action | Timeline | Dependency |
|---|---|---|
| Regex search | 1 month | Parser |
| Search filters | 1 month | UI design |
| Entity extraction | 2 months | NLP model |
| Cross-document search | 3 months | Architecture |

### 22.3 Long-term Actions

| Action | Timeline | Dependency |
|---|---|---|
| Semantic search | 6 months | AI model |
| AI-powered search | 9 months | Model selection |
| Visual search | 12 months | CV model |

---

## 23. META-DIMENSION

### 23.1 Coverage Check

| Dimension | Covered | Depth |
|---|---|---|
| Who (1.1-1.3) | ✅ | Deep |
| What (2.1-2.4) | ✅ | Deep |
| When (3.1-3.3) | ✅ | Deep |
| Where (4.1-4.2) | ✅ | Deep |
| Why (5.1-5.2) | ✅ | Deep |
| How (6.1-6.3) | ✅ | Deep |
| Which (7.1-7.2) | ✅ | Deep |
| Whose (8.1-8.2) | ✅ | Deep |
| Whom (9.1-9.2) | ✅ | Deep |
| How much (10.1-10.3) | ✅ | Deep |
| How many (11.1-11.2) | ✅ | Deep |
| How often (12.1) | ✅ | Deep |
| How long (13.1-13.2) | ✅ | Deep |
| How far (14.1-14.2) | ✅ | Deep |
| What if (15.1-15.2) | ✅ | Deep |
| What else (16.1-16.2) | ✅ | Deep |
| What changed (17.1-17.2) | ✅ | Deep |
| Compared with what (18.1) | ✅ | Deep |
| Under what conditions (19.1-19.2) | ✅ | Deep |
| With what confidence (20.1-20.2) | ✅ | Deep |
| So what (21.1-21.2) | ✅ | Deep |
| What next (22.1-22.3) | ✅ | Deep |

---

## 24. EVIDENCE

- Expanded Analytical Framework (docs/audits/analytical-framework-expanded-5w1h.md)
- JTBD-01 Read Analysis (docs/audits/jtbd-01-read-expanded-analysis-2026-08-26.md)
- PDFKit search capabilities (tests passing)
- Competitive analysis (Adobe, Preview, Browser)
- Operating Doctrine §3, §5, §8
