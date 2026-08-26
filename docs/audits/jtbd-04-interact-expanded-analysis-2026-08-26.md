# JTBD-04 INTERACT — Expanded 22-Dimension Analysis

**Date:** 2026-08-26
**Framework:** Expanded Analytical Framework (beyond 5W1H)
**Job:** "I need to fill forms, sign documents, and modify content"
**Status:** First-principles, long-term, doctrine-aligned analysis

---

## 1. WHO

### 1.1 Person

| Persona | Core Need | Expertise | Our Support |
|---|---|---|---|
| Student | Fill assignment forms | Subject expert | ✅ Basic forms |
| Lawyer | Sign contracts | Legal | ✅ Signature verify |
| Executive | Approve documents | Business | ✅ Signature verify |
| Accountant | Fill tax forms | Domain | ✅ AcroForm |
| Admin | Batch fill forms | Operational | ❌ No batch |
| HR | Fill personnel forms | Domain | ✅ Basic forms |

### 1.2 Actor

| Actor | How they interact | Our support |
|---|---|---|
| Human (sighted) | Mouse/keyboard | ✅ Good |
| Screen reader user | VoiceOver | ⚠️ Partial |
| Keyboard-only user | Tab, arrows | ✅ Good |
| Touch user (iPad) | Fingers | ❌ No iPad |
| Automated process | Programmatic | ⚠️ Basic |

### 1.3 Stakeholder

| Stakeholder | Impact of poor interaction | Severity |
|---|---|---|
| Filler | Wasted time, errors | HIGH |
| Approver | Wrong approval | CRITICAL |
| Organization | Compliance failure | HIGH |
| Data subject | Incorrect data | HIGH |

---

## 2. WHAT

### 2.1 Thing (What Is Being Interacted With)

| Object | Challenge | Our support | Gap |
|---|---|---|---|
| Text field | Input, validation | ✅ Good | Small |
| Checkbox | Toggle, state | ✅ Good | Small |
| Radio button | Selection | ⚠️ PDFKit bug | MEDIUM |
| Dropdown | Selection | ✅ Good | Small |
| Signature field | Placement | ✅ Partial | MEDIUM |
| Date field | Format, picker | ⚠️ Basic | MEDIUM |
| Calculated field | Formulas | ❌ None | LARGE |
| XFA form | Complex | ❌ None | LARGE |
| Digital signature | Cryptographic | ✅ Verify | MEDIUM |

### 2.2 Action

| Action | Frequency | Our support | Priority |
|---|---|---|---|
| Fill text field | Every session | ✅ Good | CRITICAL |
| Toggle checkbox | Most sessions | ✅ Good | HIGH |
| Select radio | Some sessions | ⚠️ Bug | HIGH |
| Select dropdown | Some sessions | ✅ Good | HIGH |
| Place signature | Rare | ✅ Partial | MEDIUM |
| Validate form | Some sessions | ⚠️ Basic | HIGH |
| Save form | Every session | ✅ Good | CRITICAL |
| Undo changes | Some sessions | ✅ Good | HIGH |
| Print filled form | Rare | ✅ Native | MEDIUM |
| Export filled form | Rare | ✅ Good | MEDIUM |

### 2.3 Event

| Trigger | Urgency | What user needs |
|---|---|---|
| "Fill this out" | HIGH | Fast, accurate forms |
| "Sign this" | HIGH | Clear signature flow |
| "Correct this" | MEDIUM | Easy editing |
| "Submit this" | HIGH | Validation, export |

### 2.4 Outcome

| Outcome | Success measure | Our contribution |
|---|---|---|
| Form completed | All fields filled | Form UX |
| Form validated | No errors | Validation |
| Document signed | Signature placed | Signature flow |
| Changes saved | Data persisted | Save mechanism |
| Form submitted | Exported/sent | Export capability |

---

## 3. WHEN

### 3.1 Interaction Patterns

| Pattern | When | Our optimization |
|---|---|---|
| One-shot fill | Quick form | Fast open, fill, save |
| Iterative fill | Complex form | Undo, validation |
| Review-fill-sign | Legal workflow | Clear flow |
| Batch fill | Many forms | ❌ No batch |

---

## 4. WHERE

### 4.1 Interaction Context

| Context | What changes | Our support |
|---|---|---|
| Office | Desktop, keyboard | ✅ Good |
| Mobile | Touch, small screen | ❌ No mobile |
| Web | Browser, limited | ✅ Good |
| Field | Offline, rugged | ✅ Offline-first |

---

## 5. WHY

### 5.1 Why Users Interact

| Reason | Impact | Our contribution |
|---|---|---|
| Complete required form | HIGH | Form UX |
| Sign legal document | CRITICAL | Signature flow |
| Correct errors | MEDIUM | Easy editing |
| Provide data | HIGH | Form fields |

---

## 6. HOW

### 6.1 Interaction Methods

| Method | When used | Our support |
|---|---|---|
| Direct fill | Default | ✅ Good |
| Tab navigation | Keyboard | ✅ Good |
| Batch fill | Many forms | ❌ None |
| Import data | Spreadsheet | ❌ None |
| Auto-fill | Browser data | ❌ None |

### 6.2 Interaction Workflow

| Step | What happens | Our support |
|---|---|---|
| 1. Open | Load form | ✅ Fast |
| 2. Detect | Find fields | ✅ PDFKit |
| 3. Fill | Enter data | ✅ Good |
| 4. Validate | Check errors | ⚠️ Basic |
| 5. Save | Persist | ✅ Good |
| 6. Sign | Place signature | ✅ Partial |
| 7. Export | Submit | ✅ Good |

---

## 7. WHICH

### 7.1 Which Interaction Strategy

| Strategy | Tradeoff | Our support |
|---|---|---|
| Manual fill | Precise but slow | ✅ Default |
| Auto-fill | Fast but may be wrong | ❌ None |
| Batch fill | Efficient but complex | ❌ None |
| Import data | Automated but setup | ❌ None |

---

## 8. WHOSE

### 8.1 Interaction Ownership

| Owner | Responsibility | Our obligation |
|---|---|---|
| Filler | Accuracy | Good UX |
| Form owner | Design | Preserve structure |
| Organization | Compliance | Validation |

---

## 9. WHOM

### 9.1 Who Benefits from Interaction

| Beneficiary | Benefit | Our contribution |
|---|---|---|
| Filler | Time saved | Fast forms |
| Approver | Correct data | Validation |
| Organization | Compliance | Audit trail |

---

## 10. HOW MUCH

### 10.1 Interaction Cost

| Cost | Type | How we minimize |
|---|---|---|
| Time | Minutes per form | Fast forms |
| Effort | Clicks, typing | Smart detection |
| Errors | Wrong data | Validation |

### 10.2 Interaction Risk

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Data loss | LOW | CRITICAL | Auto-save |
| Validation error | MEDIUM | MEDIUM | Clear messages |
| Signature break | LOW | HIGH | Integrity checks |
| Form corruption | LOW | CRITICAL | Incremental save |

---

## 11. HOW MANY

### 11.1 Interaction Scale

| Scale | Challenge | Our support |
|---|---|---|
| 1 field | Trivial | ✅ |
| 10 fields | Standard | ✅ |
| 100 fields | Complex | ⚠️ No sections |
| 1000 fields | Massive | ❌ No batch |

---

## 12. HOW OFTEN

### 12.1 Feature Usage

| Feature | How often | Our priority |
|---|---|---|
| Text fill | Every session | CRITICAL |
| Checkbox | Most sessions | HIGH |
| Radio button | Some sessions | HIGH |
| Dropdown | Some sessions | HIGH |
| Signature | Rare | MEDIUM |
| Validation | Some sessions | HIGH |

---

## 13. HOW LONG

### 13.1 Interaction Duration

| Duration | User behavior | Our optimization |
|---|---|---|
| < 1 min | Quick fill | Fast forms |
| 1-5 min | Standard form | Good UX |
| 5-30 min | Complex form | Undo, validation |
| 30+ min | Many forms | ❌ No batch |

---

## 14. HOW FAR

### 14.1 Interaction Scope

| Scope | What's included | Our support |
|---|---|---|
| Single field | One field | ✅ |
| Section | Multiple fields | ⚠️ No sections |
| Page | All fields on page | ✅ |
| Document | All fields | ✅ |
| Corpus | Many documents | ❌ None |

---

## 15. WHAT IF

### 15.1 Failure Scenarios

| What if | Consequence | Our response |
|---|---|---|
| Form won't fill | Frustration | ⚠️ Basic error |
| Data lost on save | Data loss | Auto-save |
| Signature breaks | Invalid document | Integrity check |
| Validation fails | Wrong submission | Clear messages |

### 15.2 Edge Cases

| What if | What happens | Our support |
|---|---|---|
| XFA form | Complex | ❌ Detection only |
| Calculated field | No formula | ❌ None |
| Required field | Must fill | ⚠️ Basic |
| Read-only field | Can't fill | ✅ Respected |

---

## 16. WHAT ELSE

### 16.1 What's Missing

| Missing | Impact | Priority |
|---|---|---|
| Batch form fill | Time wasted | HIGH |
| Form validation rules | Errors missed | HIGH |
| Auto-fill integration | Manual entry | MEDIUM |
| Form templates | Repeated forms | MEDIUM |
| Form data export | Data analysis | MEDIUM |
| XFA support | Complex forms | HIGH |

---

## 17. WHAT CHANGED

### 17.1 Interaction Evolution

| Era | What changed | Impact |
|---|---|---|
| 2000s | Basic forms | Foundation |
| 2010s | Digital signatures | Legal validity |
| 2020s | AI-assisted fill | Smart completion |
| 2020s | Mobile forms | Touch interaction |

---

## 18. COMPARED WITH WHAT

### 18.1 Competitive Comparison

| Feature | Us | Adobe | Preview | Browser |
|---|---|---|---|---|
| Text fields | ✅ | ✅ | ❌ | ✅ |
| Checkboxes | ✅ | ✅ | ❌ | ✅ |
| Radio buttons | ⚠️ Bug | ✅ | ❌ | ✅ |
| Dropdowns | ✅ | ✅ | ❌ | ✅ |
| Signatures | ✅ Verify | ✅ Full | ❌ | ❌ |
| Batch fill | ❌ | ✅ | ❌ | ❌ |
| XFA | ❌ | ✅ | ❌ | ❌ |
| Validation | ⚠️ Basic | ✅ Full | ❌ | ❌ |
| Privacy | ✅ LOCAL | ❌ Cloud | ✅ LOCAL | ❌ Cloud |

---

## 19. UNDER WHAT CONDITIONS

### 19.1 Constraints

| Constraint | Impact | Our workaround |
|---|---|---|
| PDFKit radio bug | Data loss | Workaround code |
| No XFA | Complex forms | Detection + warning |
| No batch | Many forms | Manual only |

---

## 20. WITH WHAT CONFIDENCE

### 20.1 What We Know

| Claim | Evidence | Confidence |
|---|---|---|
| Basic forms work | Tests passing | HIGH |
| Signatures verify | Tests passing | HIGH |
| Incremental save works | Tests passing | HIGH |

### 20.2 What We Don't Know

| Claim | Missing evidence | How to get it |
|---|---|---|
| Users want batch fill | No user studies | User testing |
| XFA is critical | No usage data | Analytics |
| Validation is adequate | No audit | Competitive analysis |

---

## 21. SO WHAT

### 21.1 The Fundamental Insight

**Interaction is about trust.** Users trust that their data will be captured correctly, saved securely, and signed validly. Any failure breaks that trust.

**The gap:** We handle basic forms well, but complex workflows (batch, XFA, calculated fields) are missing.

### 21.2 What This Means

| Dimension | Current | Needed | Gap |
|---|---|---|---|
| Basic forms | Good | Great | SMALL |
| Radio buttons | Buggy | Fixed | MEDIUM |
| Signatures | Verify only | Full flow | LARGE |
| Batch fill | None | Required | LARGE |
| XFA | None | Valuable | LARGE |
| Validation | Basic | Full rules | LARGE |

---

## 22. WHAT NEXT

### 22.1 Immediate Actions

| Action | Timeline | Dependency |
|---|---|---|
| Fix radio button bug | 1 week | PDFKit workaround |
| Improve form validation | 2 weeks | None |
| Add signature placement | 1 month | UI design |

### 22.2 Short-term Actions

| Action | Timeline | Dependency |
|---|---|---|
| Batch form fill | 2 months | Architecture |
| Form validation rules | 2 months | Rule engine |
| Auto-fill integration | 3 months | OS integration |

### 22.3 Long-term Actions

| Action | Timeline | Dependency |
|---|---|---|
| XFA support | 6 months | Parser |
| AI-assisted fill | 9 months | ML model |
| Form templates | 6 months | Template system |

---

## 23. META-DIMENSION

All 22 dimensions covered with deep analysis.

---

## 24. EVIDENCE

- Expanded Analytical Framework
- JTBD analyses (01-03)
- Current product capabilities (354 tests)
- Competitive analysis
- Operating Doctrine §3, §5, §8
