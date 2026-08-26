# JTBD-01: READ — Who and How Breakdown

**Date:** 2026-08-26
**Job:** "I need to consume this document's content"
**Scope:** Complete breakdown into user segments (who) and contexts (how)

---

## 1. The Framework

**Who** = user segment (identity, role, expertise)
**How** = context (what they're doing, why, how often)

The same person uses the reader differently depending on **what they're doing**.
The same context is experienced differently depending on **who's doing it**.

---

## 2. User Segments (Who)

### 2.1 Student

**Identity:** Learner, researcher, note-taker
**Expertise:** Subject matter (varies), not PDF tools
**Frequency:** Daily, hours at a time
**Primary motivation:** Understand and retain content

**What they need:**
- Read carefully (re-read sections)
- Take notes (annotations)
- Find key concepts (search, highlights)
- Share with study group (export, annotations)

**What they don't need:**
- Fast skimming (they read deeply)
- Form filling (rare)
- Signing (never)
- Batch processing (never)

**Reading patterns:**
- Long sessions (30-60 minutes)
- Sequential reading (page by page)
- Frequent backtracking
- Heavy annotation use

### 2.2 Lawyer

**Identity:** Legal professional, contract reviewer
**Expertise:** Legal terminology, contract structure
**Frequency:** Daily, multiple documents
**Primary motivation:** Find specific clauses, verify terms

**What they need:**
- Fast navigation (jump between clauses)
- Position persistence (return to where they were)
- Search (find specific terms)
- Comparison (diff between versions)

**What they don't need:**
- Deep reading (they skim)
- Visual fidelity (text matters, not layout)
- Form filling (rare)
- OCR (documents are digital)

**Reading patterns:**
- Short sessions (5-15 minutes per document)
- Non-sequential (jump around)
- Heavy search use
- Minimal annotation (comments, not highlights)

### 2.3 Executive

**Identity:** Decision-maker, reviewer
**Expertise:** Business, strategy (not PDF tools)
**Frequency:** Daily, multiple documents
**Primary motivation:** Skim summaries, make decisions

**What they need:**
- Fast rendering (instant page loads)
- Quick search (find key points)
- Outline navigation (jump to sections)
- Summary extraction (what's important?)

**What they don't need:**
- Deep reading (they skim)
- Visual fidelity (content matters, not colors)
- Form filling (delegates)
- Accessibility (not their concern)

**Reading patterns:**
- Very short sessions (2-5 minutes)
- Skim mode (headings, summaries)
- Heavy outline use
- Minimal interaction

### 2.4 Developer

**Identity:** Programmer, technical writer
**Expertise:** Code, technical documentation
**Frequency:** Weekly, reference material
**Primary motivation:** Find API references, code examples

**What they need:**
- Fast search (find specific functions)
- Code block detection (formatting)
- Bookmark management (save references)
- Keyboard navigation (hands-free)

**What they don't need:**
- Visual fidelity (text matters, not layout)
- Form filling (never)
- Signing (never)
- Deep reading (reference, not study)

**Reading patterns:**
- Short sessions (5-10 minutes)
- Search-first (⌘F, then read)
- Heavy bookmark use
- Keyboard-only navigation

### 2.5 Accountant

**Identity:** Financial professional
**Expertise:** Numbers, forms, tax codes
**Frequency:** Seasonal (tax season), daily otherwise
**Primary motivation:** Fill forms, extract data

**What they need:**
- Form filling (text, checkbox, dropdown)
- Data extraction (copy values)
- Calculation verification (check numbers)
- Batch processing (multiple forms)

**What they don't need:**
- Deep reading (forms, not prose)
- Visual fidelity (numbers matter, not layout)
- Search (forms are structured)
- Accessibility (not their concern)

**Reading patterns:**
- Medium sessions (15-30 minutes)
- Form-focused (tab through fields)
- Heavy copy/paste
- Minimal navigation

### 2.6 Designer

**Identity:** Visual professional
**Expertise:** Design, layout, colors
**Frequency:** Weekly, proofs and specs
**Primary motivation:** Check colors, layout, visual fidelity

**What they need:**
- Color accuracy (ICC profiles)
- Layout fidelity (exact positioning)
- Image quality (resolution, compression)
- Comparison (diff between versions)

**What they don't need:**
- Text search (visual, not textual)
- Form filling (rare)
- Deep reading (visual inspection)
- Accessibility (not their concern)

**Reading patterns:**
- Short sessions (5-10 minutes)
- Visual inspection (zoom, pan)
- Heavy zoom use
- Minimal text interaction

### 2.7 Admin

**Identity:** Administrative professional
**Expertise:** Office workflows, batch processing
**Frequency:** Daily, multiple documents
**Primary motivation:** Process documents efficiently

**What they need:**
- Batch processing (multiple documents)
- Form filling (standardized forms)
- Data extraction (copy to spreadsheets)
- Print (physical distribution)

**What they don't need:**
- Deep reading (processing, not comprehension)
- Visual fidelity (content matters, not layout)
- Search (batch, not individual)
- Accessibility (not their concern)

**Reading patterns:**
- Medium sessions (15-30 minutes)
- Batch-focused (open, process, close)
- Heavy keyboard shortcuts
- Minimal navigation

### 2.8 Archivist

**Identity:** Preservation professional
**Expertise:** Document preservation, metadata
**Frequency:** Rare (monthly or less)
**Primary motivation:** Preserve documents long-term

**What they need:**
- Metadata extraction (title, author, dates)
- Format verification (PDF/A compliance)
- Structural validation (xref, objects)
- Long-term storage (durable formats)

**What they don't need:**
- Rendering (preservation, not viewing)
- Search (rare access)
- Form filling (never)
- Accessibility (not their concern)

**Reading patterns:**
- Very rare access
- Full-document analysis
- Heavy validation use
- Minimal interaction

---

## 3. Contexts (How)

### 3.1 First Encounter

**What it means:** Opening a document for the first time
**User state:** Unfamiliar with content
**Goal:** Understand what this is about

**Reading behavior:**
- Look at title, author, date
- Skim first page
- Check outline/TOC
- Decide if worth reading

**What matters most:**
- Fast rendering (instant feedback)
- Metadata display (title, author)
- Outline navigation (structure)
- Search (find key terms)

### 3.2 Deep Reading

**What it means:** Reading carefully, end-to-end
**User state:** Committed to understanding
**Goal:** Comprehend all content

**Reading behavior:**
- Sequential page-by-page
- Re-read difficult sections
- Take notes (annotations)
- Track progress

**What matters most:**
- Visual clarity (sharp text)
- Position persistence (resume where left off)
- Annotation tools (highlights, notes)
- Progress tracking (pages read)

### 3.3 Skimming

**What it means:** Reading quickly, looking for key points
**User state:** Time-constrained
**Goal:** Find what's important

**Reading behavior:**
- Jump between sections
- Read headings and summaries
- Skip details
- Make quick decisions

**What matters most:**
- Fast rendering (instant page loads)
- Outline navigation (jump to sections)
- Search (find specific terms)
- Summary extraction (what's important?)

### 3.4 Reference Lookup

**What it means:** Finding specific information
**User state:** Has a question
**Goal:** Find the answer

**Reading behavior:**
- Search first (⌘F)
- Jump to result
- Read context
- Return to search

**What matters most:**
- Fast search (<50ms)
- Accurate results (no false positives)
- Keyboard navigation (hands-free)
- Bookmark management (save references)

### 3.5 Review/Approval

**What it means:** Checking document before approval
**User state:** Decision-maker
**Goal:** Verify content is correct

**Reading behavior:**
- Skim for issues
- Check specific sections
- Compare to previous version
- Approve or reject

**What matters most:**
- Fast rendering (instant feedback)
- Comparison tools (diff)
- Comment/annotation tools
- Position persistence (return to issues)

### 3.6 Form Filling

**What it means:** Completing interactive forms
**User state:** Task-focused
**Goal:** Fill fields correctly

**Reading behavior:**
- Tab through fields
- Enter values
- Check validation
- Submit/save

**What matters most:**
- Form field detection
- Keyboard navigation (tab, enter)
- Validation feedback
- Save/persistence

### 3.7 Signing

**What it means:** Adding digital signature
**User state:** Authorizing document
**Goal:** Sign legally

**Reading behavior:**
- Review document
- Add signature
- Verify signature
- Save/send

**What matters most:**
- Signature detection
- Signature validation
- Legal compliance
- Save/persistence

### 3.8 Printing

**What it means:** Creating physical copy
**User state:** Distributing document
**Goal:** Print correctly

**Reading behavior:**
- Check layout
- Adjust settings
- Print
- Verify output

**What matters most:**
- Layout fidelity (exact positioning)
- Color accuracy (print colors)
- Page sizing (correct dimensions)
- Print settings (paper, quality)

---

## 4. User × Context Matrix

| User | First Encounter | Deep Read | Skim | Reference | Review | Form | Sign | Print |
|---|---|---|---|---|---|---|---|---|
| **Student** | 🔴 | 🔴 | 🟡 | 🟡 | 🟢 | 🟢 | 🟢 | 🟡 |
| **Lawyer** | 🟡 | 🟢 | 🔴 | 🔴 | 🔴 | 🟢 | 🔴 | 🟡 |
| **Executive** | 🔴 | 🟢 | 🔴 | 🟡 | 🔴 | 🟢 | 🟡 | 🟡 |
| **Developer** | 🟡 | 🟢 | 🟡 | 🔴 | 🟢 | 🟢 | 🟢 | 🟢 |
| **Accountant** | 🟡 | 🟢 | 🟢 | 🟡 | 🟡 | 🔴 | 🟡 | 🔴 |
| **Designer** | 🔴 | 🟡 | 🟡 | 🟢 | 🔴 | 🟢 | 🟢 | 🔴 |
| **Admin** | 🟡 | 🟢 | 🟡 | 🟢 | 🟡 | 🔴 | 🟡 | 🔴 |
| **Archivist** | 🔴 | 🟡 | 🟢 | 🟡 | 🟡 | 🟢 | 🟢 | 🟢 |

**Legend:** 🔴 Critical | 🟡 Important | 🟢 Nice to have

---

## 5. The Insight

**One size does NOT fit all.**

A student doing deep reading needs **visual clarity** and **annotation tools**.
A lawyer doing reference lookup needs **fast search** and **keyboard navigation**.
An executive doing skimming needs **instant rendering** and **outline navigation**.

**The best reader adapts to both WHO and HOW.**

---

## 6. What This Means for Our Product

### 6.1 Current State

We have one reading mode that works "okay" for everyone.

### 6.2 What We Should Build

**Reading modes that optimize for context:**

| Mode | Optimized for | Key features |
|---|---|---|
| **Study** | Deep reading | Visual clarity, annotations, progress |
| **Review** | Review/approval | Fast nav, comparison, comments |
| **Skim** | Skimming | Instant render, outline, search |
| **Reference** | Reference lookup | Keyboard nav, bookmarks, search |
| **Form** | Form filling | Field detection, validation, save |
| **Print** | Printing | Layout fidelity, color accuracy |

### 6.3 Implementation Priority

1. **Study mode** — Most users, most value
2. **Skim mode** — Executive/decision-maker value
3. **Reference mode** — Developer value
4. **Review mode** — Lawyer/approver value
5. **Form mode** — Accountant/admin value
6. **Print mode** — Specialized use case

---

## 7. Evidence

- User interviews (implied from feature usage patterns)
- Competitive analysis (Adobe Acrobat modes, Preview behaviors)
- Product analytics (what features are actually used)
- JTBD framework (Clayton Christensen)
- First principles analysis (what is reading?)
