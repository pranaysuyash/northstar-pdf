# Platform Options

**Status:** Proposed; browser-first web recommendation documented, owner decision
and engine adoption still open
**Reviewed:** 2026-08-23

## Current Product Input

The user has requested a PDF reader/editor and a new project workspace, but has
not yet selected a first-class platform in this conversation. Native macOS,
browser/local web, and shared-core options therefore remain live alternatives.
This document does not select a final PDF engine or authorize implementation.

## Option A: Native macOS Shell, Browser Web Surface

**Shape:** SwiftUI/AppKit document-based shell, with PDFKit as a native reading,
search, annotation, widget, and writing candidate; the browser web surface uses
PDF.js for rendering/inspection and pdf-lib for bounded writes. An optional
installed companion remains a separate lane for OCR and high-fidelity work.

**Strengths:** Best Mac document behavior, keyboard/menu integration, system
accessibility, and a fast path to a credible native reader.

**Risks:** Two provider implementations can diverge. PDFKit is an Apple system
framework, not open-source, and its save/reopen fidelity for the required corpus
must be tested. Static detection remains product-owned.

**Current status:** Preferred product shape; provider choice unaccepted.

## Option B: Shared Web Processing Core in Both Shells

**Shape:** A browser-oriented PDF.js/pdf-lib and detection core is reused by the
browser and embedded behind a native macOS shell boundary.

**Strengths:** Highest behavioral parity and one primary detection implementation;
permissive browser components are easier to distribute.

**Risks:** The macOS experience may feel like an embedded web editor rather than a
native document app. Large PDFs, memory limits, printing, file coordination, and
platform text/keyboard behavior need explicit proof.

**Current status:** Viable fallback if native provider parity is too expensive.

## Option C: Local PDFBox Service With Two Shells

**Shape:** A local JVM service owns PDF rendering, extraction, forms, and bounded
writes; native and browser shells call a versioned local contract.

**Strengths:** One permissively licensed PDF core covers more operations than the
browser pair and can centralize fidelity tests.

**Risks:** JVM packaging, process lifecycle, IPC, startup cost, sandboxing, and
distribution complexity become product concerns.

**Current status:** Strong benchmark control candidate, not the default shell.

## Option D: Native Open-Source Engine Core

**Shape:** MuPDF, Poppler, PoDoFo, PDFium, or another native provider behind a
Swift bridge and a separate browser adapter.

**Strengths:** Potentially strongest native fidelity and performance.

**Risks:** Provider APIs differ materially; MuPDF has an AGPL/commercial gate,
Poppler has GPL components, and exact dependency/license boundaries need review.

**Current status:** Must remain an evaluated option until corpus and licensing
results justify the complexity.

## Long-Term Direction

Proceed with a provider-neutral document/edit contract and bounded mutation
semantics. The long-term deployment direction is native macOS plus a browser
local core and an explicitly installed optional companion capability plane. The
companion is admitted capability by capability through the gates in
[`web-deployment-decision.md`](web-deployment-decision.md). Final provider
adoption still requires benchmark corpus, save/reopen tests, visual comparison,
performance checks, and exact license review.

## Native Design Constraints

- Treat the app as a document-based Mac app with standard File/Edit/View/Window/
  Help menus, standard shortcuts, undo/redo, multiple windows where useful, and
  VoiceOver labels.
- Keep document content separate from navigation and control chrome.
- Make native fields, static suggestions, annotations, and applied edits separate
  domain types.
- Keep all processing local by default and make any external processing explicit.
