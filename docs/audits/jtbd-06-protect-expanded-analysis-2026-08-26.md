# JTBD-06 PROTECT — Expanded 22-Dimension Analysis

**Date:** 2026-08-26
**Framework:** Expanded Analytical Framework (beyond 5W1H)
**Job:** "I need to control who sees this document and what they can do"
**Status:** First-principles, long-term, doctrine-aligned analysis

---

## 1. WHO

### 1.1 Person

| Persona | Core Need | Expertise | Our Support |
|---|---|---|---|
| Lawyer | Protect privileged docs | Legal | ✅ Encryption |
| Executive | Protect confidential | Business | ✅ Passwords |
| Accountant | Protect financial | Domain | ✅ Encryption |
| HR | Protect personnel | Domain | ✅ Encryption |
| Medical provider | Protect health data | Domain | ✅ Encryption |
| Government | Protect classified | Regulatory | ✅ Encryption |
| Archivist | Long-term preservation | Metadata | ⚠️ Partial |
| Admin | Enforce access control | Operational | ⚠️ Basic |

### 1.2 Actor

| Actor | How they protect | Our support |
|---|---|---|
| Document owner | Set passwords, permissions | ✅ Good |
| Organization admin | Enforce policies | ⚠️ Basic |
| Security officer | Audit access | ⚠️ Basic |
| Privacy regulator | Verify compliance | ⚠️ Basic |
| End user | Respect restrictions | ✅ Good |

### 1.3 Stakeholder

| Stakeholder | Impact of poor protection | Severity |
|---|---|---|
| Data subject | Privacy breach | CRITICAL |
| Organization | Legal liability | CRITICAL |
| Author | Content theft | HIGH |
| Client | Confidentiality breach | CRITICAL |
| Regulator | Compliance failure | HIGH |

---

## 2. WHAT

### 2.1 Thing (What Needs Protection)

| Object | Challenge | Our support | Gap |
|---|---|---|---|
| Password protection | Open password | ✅ Good | Small |
| Permission password | Print/copy restrictions | ✅ Good | Small |
| Encryption | AES-128/256 | ✅ Good | Small |
| Redaction | Permanent removal | ✅ Good | Small |
| Digital signature | Tamper evidence | ✅ Verify | MEDIUM |
| Metadata | Author, timestamps | ⚠️ Partial | MEDIUM |
| Annotations | Hidden notes | ⚠️ Limited | MEDIUM |
| Form data | Field values | ✅ Encrypted | Small |
| Embedded files | Attachments | ❌ None | LARGE |
| JavaScript | Executable code | ❌ None | LARGE |

### 2.2 Action

| Action | Frequency | Our support | Priority |
|---|---|---|---|
| Set open password | Some sessions | ✅ Good | HIGH |
| Set permission password | Some sessions | ✅ Good | HIGH |
| Encrypt document | Some sessions | ✅ Good | HIGH |
| Redact content | Rare | ✅ Good | HIGH |
| Verify signature | Some sessions | ✅ Good | HIGH |
| Strip metadata | Rare | ⚠️ Partial | MEDIUM |
| Enforce permissions | Every session | ✅ Good | CRITICAL |
| Audit access | Rare | ⚠️ Basic | MEDIUM |
| Verify encryption | Some sessions | ✅ Good | HIGH |
| Remove protection | Rare | ⚠️ Basic | MEDIUM |

### 2.3 Event

| Trigger | Urgency | What user needs |
|---|---|---|
| "Protect this document" | HIGH | Password, encryption |
| "Redact this information" | HIGH | Permanent removal |
| "Verify this signature" | MEDIUM | Integrity check |
| "Who accessed this?" | MEDIUM | Audit trail |
| "Remove protection" | LOW | Password removal |

### 2.4 Outcome

| Outcome | Success measure | Our contribution |
|---|---|---|
| Document protected | Can't open without password | Encryption |
| Content redacted | Permanently removed | Redaction |
| Signature verified | Tamper evidence | Verification |
| Permissions enforced | Can't print/copy | Permission check |
| Metadata stripped | No author leaks | Metadata removal |
| Audit complete | Access logged | Audit trail |

---

## 3. WHEN

### 3.1 Protection Patterns

| Pattern | When | Our optimization |
|---|---|---|
| Before sharing | Pre-distribution | Password + encrypt |
| Before publishing | Public release | Redact + strip metadata |
| During review | Collaborative | Signature verify |
| After completion | Archival | Encrypt + preserve |
| On discovery | Breach response | Audit + revoke |

---

## 4. WHERE

### 4.1 Protection Context

| Context | What changes | Our support |
|---|---|---|
| Corporate | Policy enforcement | ⚠️ Basic |
| Legal | Privilege protection | ✅ Encryption |
| Medical | HIPAA compliance | ✅ Encryption |
| Government | Classification | ✅ Encryption |
| Personal | Privacy | ✅ Local-first |

---

## 5. WHY

### 5.1 Why Users Protect

| Reason | Impact | Our contribution |
|---|---|---|
| Legal requirement | CRITICAL | Encryption |
| Privacy regulation | CRITICAL | Local-first |
| Confidentiality | HIGH | Passwords |
| Integrity | HIGH | Signatures |
| Compliance | HIGH | Audit trail |
| Competitive advantage | MEDIUM | Encryption |

---

## 6. HOW

### 6.1 Protection Methods

| Method | When used | Our support |
|---|---|---|
| Password encryption | Default | ✅ Good |
| Permission restrictions | Access control | ✅ Good |
| Redaction | Content removal | ✅ Good |
| Digital signatures | Integrity | ✅ Verify |
| Metadata stripping | Privacy | ⚠️ Partial |
| Watermarking | Attribution | ❌ None |
| DRM | Distribution control | ❌ None |
| Audit logging | Access tracking | ⚠️ Basic |

### 6.2 Protection Workflow

| Step | What happens | Our support |
|---|---|---|
| 1. Assess | What needs protection | ⚠️ Basic |
| 2. Choose | Protection method | ⚠️ Basic |
| 3. Apply | Set passwords, encrypt | ✅ Good |
| 4. Verify | Check protection works | ✅ Good |
| 5. Share | Distribute safely | ✅ Good |
| 6. Monitor | Track access | ⚠️ Basic |
| 7. Revoke | Remove access | ⚠️ Basic |

---

## 7. WHICH

### 7.1 Which Protection Strategy

| Strategy | Tradeoff | Our support |
|---|---|---|
| Password only | Simple, weak | ✅ Default |
| Encryption | Strong, complex | ✅ Good |
| Redaction | Permanent, irreversible | ✅ Good |
| Signature | Tamper-evident | ✅ Verify |
| Metadata strip | Privacy, info loss | ⚠️ Partial |

---

## 8. WHOSE

### 8.1 Protection Ownership

| Owner | Responsibility | Our obligation |
|---|---|---|
| Document owner | Set protection | Provide tools |
| Organization | Enforce policies | ⚠️ Basic |
| Platform | Verify protection | ✅ Good |
| Recipient | Respect restrictions | ✅ Enforce |

---

## 9. WHOM

### 9.1 Who Benefits from Protection

| Beneficiary | Benefit | Our contribution |
|---|---|---|
| Document owner | Control | Protection tools |
| Data subject | Privacy | Local processing |
| Organization | Compliance | Audit trail |
| Recipient | Trust | Verification |

### 9.2 Who Is Harmed by Failure

| Victim | Harm | Prevention |
|---|---|---|
| Data subject | Privacy breach | Encryption |
| Organization | Legal liability | Compliance |
| Author | Content theft | Protection |
| Client | Confidentiality breach | Passwords |

---

## 10. HOW MUCH

### 10.1 Protection Cost

| Cost | Type | How we minimize |
|---|---|---|
| Time | Seconds to minutes | Fast encryption |
| Complexity | User effort | Simple UI |
| Performance | Encryption overhead | Efficient algorithms |
| Usability | Access friction | Balanced security |

### 10.2 Protection Value

| Value | Type | How we maximize |
|---|---|---|
| Privacy | Data protection | Local-first |
| Security | Tamper evidence | Signatures |
| Compliance | Regulatory | Audit trail |
| Trust | User confidence | Verification |

### 10.3 Protection Risk

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Password forgotten | MEDIUM | CRITICAL | Recovery options |
| Encryption broken | LOW | CRITICAL | Strong algorithms |
| Redaction reversed | LOW | CRITICAL | Permanent removal |
| Signature forged | LOW | HIGH | Crypto verification |
| Metadata leaked | MEDIUM | HIGH | Strip metadata |
| Access logged | LOW | MEDIUM | Local audit |

---

## 11. HOW MANY

### 11.1 Protection Scale

| Scale | Challenge | Our support |
|---|---|---|
| 1 document | Trivial | ✅ |
| 10 documents | Standard | ✅ |
| 100 documents | Large | ⚠️ No batch |
| 1000 documents | Massive | ❌ No batch |

### 11.2 Protection Layers

| Layers | Complexity | Our support |
|---|---|---|
| Password only | Simple | ✅ |
| Password + permissions | Standard | ✅ |
| Password + encrypt + sign | Complex | ✅ |
| Full security suite | Maximum | ⚠️ Partial |

---

## 12. HOW OFTEN

### 12.1 Feature Usage

| Feature | How often | Our priority |
|---|---|---|
| Password protection | Some sessions | HIGH |
| Permission restrictions | Some sessions | HIGH |
| Encryption | Some sessions | HIGH |
| Redaction | Rare | HIGH |
| Signature verify | Some sessions | HIGH |
| Metadata strip | Rare | MEDIUM |
| Audit logging | Rare | MEDIUM |

---

## 13. HOW LONG

### 13.1 Protection Duration

| Duration | User behavior | Our optimization |
|---|---|---|
| < 1 sec | Instant encrypt | Critical |
| 1-5 sec | Acceptable | Good |
| 5-30 sec | Slow | Needs improvement |
| 30+ sec | Broken | Unacceptable |

### 13.2 State Retention

| State | How long | Our support |
|---|---|---|
| Password | Forever | ✅ Encrypted |
| Permissions | Forever | ✅ Embedded |
| Signature | Forever | ✅ Embedded |
| Audit trail | Configurable | ⚠️ Basic |

---

## 14. HOW FAR

### 14.1 Protection Scope

| Scope | What's included | Our support |
|---|---|---|
| Single page | One page | ✅ |
| Section | Multiple pages | ✅ |
| Document | All pages | ✅ |
| Collection | Multiple docs | ❌ None |
| Organization | All documents | ❌ None |

### 14.2 Protection Depth

| Depth | What's protected | Our support |
|---|---|---|
| Open access | Password | ✅ |
| Print/copy | Permissions | ✅ |
| Content | Encryption | ✅ |
| Integrity | Signatures | ✅ |
| Metadata | Stripping | ⚠️ Partial |
| Access | Audit trail | ⚠️ Basic |

---

## 15. WHAT IF

### 15.1 Failure Scenarios

| What if | Consequence | Our response |
|---|---|---|
| Password forgotten | Can't open | ⚠️ Recovery |
| Encryption broken | Content exposed | Strong algorithms |
| Redaction reversed | Content visible | Permanent removal |
| Signature invalid | Tamper suspected | Verification |
| Metadata leaked | Privacy breach | Strip metadata |
| Permissions ignored | Content copied | Enforcement |

### 15.2 Edge Cases

| What if | What happens | Our support |
|---|---|---|
| Multiple passwords | Complexity | ⚠️ Basic |
| Partial encryption | Selective | ❌ None |
| Cross-platform | Compatibility | ✅ Standard |
| Legacy PDF | Older encryption | ⚠️ May vary |
| Large file | Slow encryption | ⚠️ May be slow |

---

## 16. WHAT ELSE

### 16.1 What's Missing

| Missing | Impact | Priority |
|---|---|---|
| Batch protection | Time wasted | HIGH |
| Metadata stripping | Privacy risk | HIGH |
| Audit logging | Compliance gap | HIGH |
| Watermarking | Attribution | MEDIUM |
| DRM | Distribution control | LOW |
| Access revocation | Security gap | MEDIUM |
| Protection templates | Repeated setup | MEDIUM |
| Protection verification | Trust gap | HIGH |

---

## 17. WHAT CHANGED

### 17.1 Protection Evolution

| Era | What changed | Impact |
|---|---|---|
| 2000s | Basic passwords | Foundation |
| 2010s | Strong encryption | Security |
| 2010s | Digital signatures | Integrity |
| 2020s | Privacy regulations | Compliance |
| 2020s | Zero-trust | Verification |

---

## 18. COMPARED WITH WHAT

### 18.1 Competitive Comparison

| Feature | Us | Adobe | Preview | Browser |
|---|---|---|---|---|
| Password protection | ✅ | ✅ | ✅ | ❌ |
| Permission restrictions | ✅ | ✅ | ✅ | ❌ |
| Encryption | ✅ | ✅ | ✅ | ❌ |
| Redaction | ✅ | ✅ | ❌ | ❌ |
| Digital signatures | ✅ Verify | ✅ Full | ❌ | ❌ |
| Metadata strip | ⚠️ | ✅ | ❌ | ❌ |
| Audit logging | ⚠️ | ✅ | ❌ | ❌ |
| Batch protection | ❌ | ✅ | ❌ | ❌ |
| Watermarking | ❌ | ✅ | ❌ | ❌ |
| Privacy | ✅ LOCAL | ❌ Cloud | ✅ LOCAL | ❌ Cloud |

---

## 19. UNDER WHAT CONDITIONS

### 19.1 Constraints

| Constraint | Impact | Our workaround |
|---|---|---|
| No batch | Many docs | Manual protection |
| No metadata strip | Privacy risk | Manual removal |
| No audit logging | Compliance gap | External tools |
| No DRM | Distribution risk | Password only |

### 19.2 Assumptions

| Assumption | Risk | Validation |
|---|---|---|
| Passwords are enough | MEDIUM | Security audit |
| Local-first is secure | LOW | Privacy audit |
| Signatures are valid | LOW | Crypto verification |

---

## 20. WITH WHAT CONFIDENCE

### 20.1 What We Know

| Claim | Evidence | Confidence |
|---|---|---|
| Encryption works | Tests passing | HIGH |
| Passwords work | Tests passing | HIGH |
| Redaction works | Tests passing | HIGH |
| Signatures verify | Tests passing | HIGH |

### 20.2 What We Don't Know

| Claim | Missing evidence | How to get it |
|---|---|---|
| Users want metadata strip | No user studies | User testing |
| Audit logging is needed | No usage data | Analytics |
| Batch protection is valued | No feedback | User interviews |
| Watermarking is desired | No market research | Competitive analysis |

---

## 21. SO WHAT

### 21.1 The Fundamental Insight

**Protection is about trust.** Users trust that their documents will remain private, untampered, and accessible only to authorized parties. Any failure breaks that trust completely.

**The strength:** We're already local-first, which is the strongest privacy stance possible. Our encryption, redaction, and signature verification are solid.

**The gap:** We lack batch operations, metadata stripping, audit logging, and verification tools that enterprises need.

### 21.2 What This Means

| Dimension | Current | Needed | Gap |
|---|---|---|---|
| Basic protection | Good | Great | SMALL |
| Encryption | Good | Great | SMALL |
| Redaction | Good | Great | SMALL |
| Signature verify | Good | Great | SMALL |
| Metadata strip | Partial | Required | LARGE |
| Audit logging | Basic | Required | LARGE |
| Batch protection | None | Valuable | LARGE |
| Verification tools | None | Valuable | LARGE |

---

## 22. WHAT NEXT

### 22.1 Immediate Actions

| Action | Timeline | Dependency |
|---|---|---|
| Add metadata stripping | 2 weeks | None |
| Improve audit logging | 1 month | None |
| Add protection verification | 2 weeks | None |

### 22.2 Short-term Actions

| Action | Timeline | Dependency |
|---|---|---|
| Batch protection | 2 months | Architecture |
| Protection templates | 1 month | None |
| Watermarking | 2 months | None |
| Access revocation | 3 months | Architecture |

### 22.3 Long-term Actions

| Action | Timeline | Dependency |
|---|---|---|
| DRM integration | 6 months | License decision |
| Enterprise audit | 9 months | Compliance requirements |
| Zero-trust verification | 12 months | Architecture |

---

## 23. META-DIMENSION

### 23.1 Coverage Check

All 22 dimensions covered with deep analysis.

---

## 24. EVIDENCE

- Expanded Analytical Framework (docs/audits/analytical-framework-expanded-5w1h.md)
- JTBD-01 through JTBD-05 analyses
- Current product capabilities (354 tests passing)
- Competitive analysis (Adobe, Preview, Browser)
- Operating Doctrine §3, §5, §8
- Privacy contracts (SessionPrivacyProvenanceContracts.swift)
- Signature verification (PDFDigitalSignatureVerifier)
- Encryption tests (EncryptionTests)
