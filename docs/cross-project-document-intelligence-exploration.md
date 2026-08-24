# Cross-Project Document Intelligence Exploration

**Date:** 2026-08-24  
**Status:** Research synthesis and planning baseline  
**Scope:** Local projects containing OCR, parsers, document extraction,
signature detection, PDF inspection, layout evidence, validation, or
privacy-first workflow patterns  
**Canonical owner:** `/Users/pranay/Projects/pdf_editor`  
**Evidence level:** Tier 1 static inspection unless a row says otherwise

## Why this document exists

The PDF editor should not be designed from PDF libraries alone. Several local
projects have already explored adjacent primitives: signature extraction and
placement, OCR, parser routing, field registries, provenance, synthetic data,
hard-negative mining, local privacy boundaries, and operator review.

This record makes that prior work recoverable without turning any neighboring
project into an accidental dependency or second source of truth. It separates:

- observed local capabilities and documents;
- reusable product primitives;
- ideas that remain proposals or research horizons;
- code that should remain owned by another project;
- falsifiers and checks required before importing a capability.

The user-facing thesis is:

> Make difficult PDFs faster to complete while preserving source content,
> showing why each suggestion exists, and leaving a recoverable proof of what
> changed.

The long-term moat thesis is:

> Accumulate a private, versioned, provenance-rich corpus of document evidence,
> reviewed corrections, hard negatives, operation lineage, and validation
> outcomes that compounds across engines and platforms.

That is more durable than selecting one “best” OCR or PDF engine.

## Doctrine and authorization boundary

This pass follows the shared operating doctrine and the relevant local project
doctrines:

- Start from live local truth. Neighboring projects were inspected at their
  current paths; previous summaries were treated as leads, not proof.
- Exploration widens the frontier. It does not authorize copying every idea or
  making every adjacent capability a PDF-editor commitment.
- Evidence status is preserved. Static file inspection is not runtime proof;
  historical benchmark claims are not re-run claims in this project.
- One canonical owner per pipeline and contract. The PDF editor owns its
  document, coordinate, candidate, operation, template, and validation
  contracts. SignKit, MetaExtract, Invoice Intelligence, and PhotoSearch keep
  ownership of their own source pipelines.
- Semantic salvage is allowed. Reusable concepts, fixtures, metrics, and
  failure taxonomies may inform this project after provenance, license, privacy,
  and compatibility review.
- The neighboring projects were read only. No adjacent source, dependency,
  fixture, database, generated file, or Git state was changed.

The PDF editor request authorizes documentation and planning in this project.
It does not authorize external service calls, data movement, Git mutation, or
cross-project code changes.

## Local source inventory

| Local project | What was inspected | Evidence-backed transfer value | Boundary |
| --- | --- | --- | --- |
| `/Users/pranay/Projects/Data_Science/computer_vision/proj6/signature-extractor-app` | SignKit detection, roadmap, ML, PDF, and extractor docs/source | Native-first inspection, AcroForm plus CV plus OCR evidence, one coordinate transform, candidate ranking, review, hard negatives, local corrections, benchmark ladder, audit/recovery | SignKit remains the owner of signature extraction, cleanup, assets, vault, and signature-specific claims. |
| `/Users/pranay/Projects/metaextract` | Extractor registry, observability, field registry, pipeline, and inventory docs | Registry routing, normalized fields, module provenance, conflicts, shadow mode, sensitive-field reporting, bounded parser inventory | MetaExtract remains a general metadata system; its field catalog and extractor tree are not PDF-editor runtime dependencies. |
| `/Users/pranay/Projects/invoice-intelligence` | Implementation writeup, rich schema, aliases, validation, OCR/parser requirements, benchmark docs | Digital/scanned routing, OCR/parser/vision fallback, strict schema, aliases, reviewed labels, synthetic degradation, math/completeness validation, latency/cost/failure metrics | Invoice-specific schema, prompts, and data remain there. Transfer routing and validation discipline only. |
| `/Users/pranay/Projects/Photosearch_experiment` | OCR search source, metadata gap/roadmap docs, doctrine/README | Region-level OCR with bounds, language and confidence, local model opt-in, caching, graceful missing-engine behavior | Photo/media search remains the owner of media metadata and catalog behavior. |
| `/Users/pranay/Projects/extracted_forms` | Project doctrine and bundled SignKit/form artifact surfaces | Separate artifact, legal, privacy, packaged-resource, and editable-form boundaries | Treat bundled resources as historical or packaged evidence until source ownership and fixture provenance are independently confirmed. |
| `/Users/pranay/Projects/Web_dev/signature_auto_detect_v1` | Historical web signature-detection file inventory | Early interaction and coordinate hypotheses | Low-confidence historical lead; no capability is promoted without source and test review. |

“Observed” means that a file or source surface exists. “Transfer value” means
that a concept is relevant. It does not mean that the capability is currently
verified here, production-ready, or legally cleared for redistribution.

## First-principles capability map

### 1. Source identity and immutable input handling

The PDF editor already binds sessions and operations to source digests. The
adjacent projects reinforce why that is foundational:

- SignKit separates original, cleaned, and enhanced representations and records
  provenance for assets and placement.
- Invoice Intelligence discovered that a reviewed label can be wrong and had to
  correct the label before grading a stronger extractor.
- MetaExtract's observability work puts extraction metadata in a separate
  `extraction_info` surface so compatibility is not silently changed.

**Import into PDF editor:** every inspection, candidate, operation, template
match, export, and validation report carries the source digest and the
contract/provider identity that produced it. A stale digest fails closed.

**Not imported:** copying a completed or cleaned PDF into a template store, or
treating a prior output as a new source without an explicit source relationship.

### 2. Multi-signal inspection before raster analysis

SignKit's documented PDF route is especially relevant:

```text
native image/vector/annotation extraction
-> rendered-page analysis
-> learned detector
-> classical fallback
-> user-assisted region selection
```

Its shipped signature-field detector combines AcroForm/widget inspection,
OpenCV layout heuristics, and OCR keyword hints, with a shared image-to-PDF
transform and overlap deduplication. The same decomposition applies to blank
field assistance:

1. inspect native fields and annotations;
2. extract text and geometry;
3. inspect vector lines, rectangles, and image regions;
4. render only when structural evidence is insufficient;
5. use OCR for text regions and labels when the page is text-poor;
6. fuse signals into candidate evidence;
7. require review before mutation.

**Import into PDF editor:** a provider-neutral `EvidenceGraph` concept behind
the existing candidate contract. Each evidence item records provider, method,
coordinate space, confidence semantics, and source region.

**Not imported:** a single detector score or an engine-specific object model as
the meaning of a field.

### 3. OCR as geometry-bearing evidence, not truth

The local projects converge on a useful rule:

- OCR emits text, bounding boxes, language/model information, and confidence.
- OCR may suggest labels, reading order, or nearby blank regions.
- OCR does not silently create fields, populate values, or validate a legal
  document.
- Missing OCR engines and model downloads are explicit capability states.

PhotoSearch demonstrates text-region records with bounding boxes, language, and
confidence. SignKit documents OCR keyword hints as lower-confidence placement
evidence. Invoice Intelligence treats OCR as one route in a hybrid pipeline and
then validates the resulting structured output. The PDF editor's F-014 has the
same boundary.

**Import into PDF editor:** OCR adapters emit the shared coordinate and
candidate-evidence contracts. Preserve raw OCR output only in an explicit local
evidence store with retention and privacy controls.

**Open research:** compare Vision, Tesseract, PaddleOCR, Docling, browser OCR,
and a possible companion on scanned, multilingual, rotated, low-DPI, skewed,
handwritten, and mixed digital/scanned pages. No engine is selected here.

### 4. Normalization and schema discipline

MetaExtract's registry work identifies the recurring failure mode: fields become
fragmented across modules, aliases, and clients. Invoice Intelligence addresses
a narrower version with a rich versioned schema and canonical alias map.

**Import into PDF editor:** maintain one versioned shared contract for document
facts, page boxes and transforms, native fields, text/geometry/OCR evidence,
candidate review, typed edit operations, template mappings, and validation
checks. Provider adapters normalize into it while retaining incompatible raw
facts and warnings.

**Open research:** whether a document-wide semantic field registry is useful,
and how to represent aliases without pretending that labels such as “date” have
one universal meaning.

### 5. Validation is part of extraction

Invoice Intelligence provides a transferable pattern: validate required fields,
normalize values, check internal relationships, return warnings, and measure
validation pass rate alongside accuracy, latency, and cost. SignKit's benchmark
ladder adds export fidelity, recovery, and end-to-end completion.

For the PDF editor, validation is lexicographic:

1. source digest binding and stale-source rejection;
2. operation support and authorization;
3. coordinate/page-box validity;
4. output reopenability and structural integrity;
5. unchanged-outside-region or equivalent preservation evidence;
6. candidate/field completion quality;
7. latency, memory, and file-size cost.

**Import into PDF editor:** add validation families for structural, visual,
semantic, provenance, and capability results. Unknown is a real result, not a
pass and not a failure disguised as confidence.

### 6. Human review and active learning

SignKit's research program is directly relevant to a safe moat:

- candidate ranking rather than one opaque answer;
- manual fallback for low-confidence pages;
- hard negatives for dates, initials, stamps, logos, underlines, checkmarks,
  table lines, decorative text, and OCR artifacts;
- local correction metadata;
- active learning only from reviewed corrections;
- no upload of document bytes merely to learn from corrections.

**Import into PDF editor:** record candidate acceptance, rejection, correction,
reason, and resulting validation outcome as local learning events. Promote only
reviewed, validated structural changes into a template revision. Do not train or
silently tune from unreviewed interaction telemetry.

### 7. Corpus and benchmark separation

The neighboring projects show why one aggregate score is misleading:

- SignKit separates synthetic, external scanned, controlled degradation,
  internal production-like, and end-to-end product populations.
- Invoice Intelligence generates document-type, layout, format, and degradation
  variants and preserves reviewed labels.
- The PDF editor currently has Form 6 and a public AcroForm, but lacks a full
  scanned, rotated, malformed, encrypted, handwritten, and mixed-content corpus.

**Import into PDF editor:** every fixture records population, source rights,
digest, page characteristics, expected evidence, expected operation, validator,
and failure taxonomy. Keep synthetic and real-world results separate. Measure
both “detector found it” and “document completed safely.”

### 8. Privacy and claim discipline

SignKit makes privacy a visible workflow property, not an absolute promise.
MetaExtract's sensitive-field reporting shows why extracted metadata can itself
be sensitive. PhotoSearch's local model opt-in and graceful dependency behavior
provide a useful UX pattern.

**Import into PDF editor:** expose processing mode, engine, network status,
model availability, retention, and export location. Keep source PDFs immutable;
keep templates free of raw document bytes, profile values, and screenshots by
default. State when a companion or external service is required.

**Not imported:** unconditional “private,” “offline,” “secure,” “accurate,” or
“legally valid” claims that exceed current implementation and evidence.

## The proposed compounding moat

The reusable architecture is an evidence and operation graph:

```text
immutable source bytes
        |
        v
multi-provider inspection
        |
        v
normalized evidence graph
  text | geometry | widget | vector | OCR | visual
        |
        v
reviewed candidate and explanation
        |
        v
typed, source-bound edit operation
        |
        v
new-copy export and validation report
        |
        v
reviewed correction / hard negative / template learning event
```

This graph is portable across PDFKit, PDF.js, pdf-lib, PDFBox, OCR workers, and
future companions. The engine is a replaceable evidence producer. The product
owns normalized meaning, review state, operation lineage, and the safety oracle.

### What compounds

- hard negatives categorized by document failure mode;
- page-space and crop/rotation transform fixtures;
- user-confirmed candidate-to-label mappings;
- source-bound operation histories and undo/replay behavior;
- provider divergence records;
- export reopen and independent-viewer outcomes;
- template fingerprints and reviewed revisions;
- calibrated confidence and abstention behavior;
- corpus provenance, licensing, consent, and retention metadata;
- workflow-level time-to-completion and recovery evidence.

### What does not constitute a moat by itself

- a list of OCR dependencies;
- one large model or one PDF engine;
- a high score on a synthetic dataset;
- a broad feature list without preservation or recovery proof;
- copied code from neighboring projects;
- a template database that stores completed PDFs or user values;
- cloud processing that removes local explainability and ownership.

## Ownership map

| Concern | PDF editor owner | Adjacent relationship |
| --- | --- | --- |
| PDF identity and page coordinates | `Sources/PDFEditorCore` shared contracts | Learn from SignKit's one-transform rule and MetaExtract provenance; keep PDF-editor semantics canonical here. |
| Native fields and static candidates | PDF editor adapters/contracts | SignKit's `field_detection.py` is a reference pattern, not a drop-in dependency. |
| Signature extraction and cleanup | SignKit | Consume a reviewed signature asset through an explicit adapter or operation payload; do not duplicate its extractor or vault. |
| Generic OCR/text regions | PDF editor OCR adapter contract | PhotoSearch and SignKit inform evidence shape; engine selection remains open. |
| General metadata/parser registry | MetaExtract | Use as an exploration reference or future companion, not the PDF-editor core runtime. |
| Invoice semantic extraction | Invoice Intelligence | Reuse routing, schema, review, and validation patterns; keep invoice fields outside the core. |
| Reusable form templates | PDF editor template contract | SignKit placement-template ideas inform hypotheses; this project owns the privacy boundary. |
| Corpus and experiment ledger | PDF editor fixture/benchmark docs | Salvage SignKit and Invoice Intelligence population separation and metric discipline. |
| Privacy and claim surface | Each product owns its own claims | Do not copy packaged legal text or absolute privacy claims across products. |

## Exploration roadmap

### P0: Cross-project evidence ledger

Create a machine-readable ledger for each candidate capability with project path,
source file, owner, truth status, license/provenance status, inputs/outputs,
coordinate space, privacy class, runtime evidence, and import decision. This
document is the human-readable synthesis; the ledger should be the next small
implementation artifact.

### P0: Native/web contract parity corpus

Run the same normalized inspection and edit-session serialization against the
existing PDF corpus in the Swift and browser lanes. Compare semantic records,
not PDF bytes. Include source digest, page boxes, widget facts, candidates,
operations, and validation states.

### P1: Multi-provider evidence fusion

Add a provider interface for native structure, PDF.js text/annotations, rendered
geometry, OCR regions, and optional companion evidence. Require each provider to
declare coordinate system, confidence semantics, time/resource cost, and failure
state. Fuse signals into candidate evidence without making any provider
authoritative by default.

### P1: Hard-negative and degradation program

Turn rejected candidates and real failures into categorized fixtures. Generate
controlled blur, skew, compression, low contrast, rotation, crop-box, text-layer,
stamp, table-line, handwriting, and OCR-corruption variants. Keep labels and
source rights explicit.

### P1: Reviewed correction and abstention loop

Measure candidate acceptance, correction distance, false-positive categories,
abstention rate, time to completion, undo frequency, and validation failures.
Use the results to tune ranking and review UX, not to silently mutate behavior.

### P2: OCR and companion bake-off

Only after the corpus requires it, compare browser-local OCR, native Vision,
Tesseract, PaddleOCR, Docling, and a local companion. Measure region quality and
workflow completion, plus model size, startup, memory, offline behavior,
licenses, update path, and security boundary.

### P2: Template learning

Implement the documented privacy-first template direction after contract parity.
Learn reviewed structure and mappings, not profile values or source content.
Require stale, ambiguous, and wrong-source abstention.

### P3: Shared local document-intelligence service

Consider a reusable local service only if multiple products need the same
normalized evidence graph. First prove that it reduces duplicate ownership
rather than becoming a broad, under-tested platform with unclear privacy and
support obligations.

## Research questions and falsifiers

| Question | Current status | Falsifier or next check |
| --- | --- | --- |
| Can one evidence contract represent native fields, static boxes, OCR regions, and signature placements? | Proposed | Contract fixture with cross-provider coordinate and confidence cases. |
| Does native inspection improve fidelity and speed over full-page raster analysis? | Inferred from SignKit design; not measured here | Benchmark native-first and raster-first on mixed corpus. |
| Can OCR improve label association without increasing unsafe suggestions? | Unknown | Paired precision/abstention test with OCR on/off and hard negatives. |
| Can browser-only processing handle the first target corpus? | Partly evidenced by bounded proof; not general | Add scanned, rotated, encrypted, large, and external-form fixtures. |
| Do user corrections create durable advantage? | Proposed | Track reviewed correction reuse and validated completion improvement. |
| Is a local companion worth installation cost? | Resolved for first web release by D-009; companion admission remains conditional | Compare measured browser failures with companion benefit and lifecycle burden before any optional beta. |
| Can adjacent code be reused safely? | Unknown per module | Review ownership, tests, dependency/license records, and adapter boundary. |
| Are local fixtures lawful and representative for future training? | Mixed/unknown | Build consent/license manifest and separate packaged, synthetic, public, and private populations. |

## Immediate plan change

The next implementation unit remains contract and corpus work, but its input set
now explicitly includes local adjacent evidence:

1. build the cross-project evidence ledger;
2. identify reusable fixture categories and failure labels;
3. compare native and web serialized contracts on the existing corpus;
4. only then add OCR, parser, companion, or template runtime dependencies.

No adjacent repository should be edited or added as a dependency during this
exploration phase. The first safe transfer is a contract fixture or documented
adapter boundary, not a copied pipeline.

## Completeness and limits

This is a broad local exploration pass, not a claim that every project under
`/Users/pranay/Projects` has been exhaustively audited. The highest-relevance
projects found through local inventory and the user's prior OCR/parser/signature
context are recorded above. Additional projects should be added when their
source surfaces materially affect PDF identity, layout, OCR, parsing, privacy,
or review architecture.

The current evidence is primarily static inspection. It does not establish:

- current runtime health of neighboring projects;
- compatibility of their dependencies with Swift, browser, or distribution;
- accuracy on the PDF editor corpus;
- legal clearance to redistribute their code, models, data, or bundled assets;
- production privacy, security, or accessibility claims.

Those are explicit follow-up gates, not implicit assumptions.

## Source register

The following local files were inspected as evidence inputs during this pass:

- `/Users/pranay/Projects/Data_Science/computer_vision/proj6/signature-extractor-app/docs/AUTO_DETECTION_ML.md`
- `/Users/pranay/Projects/Data_Science/computer_vision/proj6/signature-extractor-app/docs/analysis/2026-08-04_signkit_roadmap_intelligence.md`
- `/Users/pranay/Projects/Data_Science/computer_vision/proj6/signature-extractor-app/docs/SIGNKIT_PRODUCT_ML_DISCUSSION_2026-08-13.md`
- `/Users/pranay/Projects/Data_Science/computer_vision/proj6/signature-extractor-app/docs/SIGNKIT_S_TIER_PRODUCT_EXPANSION_MAP.md`
- `/Users/pranay/Projects/Data_Science/computer_vision/proj6/signature-extractor-app/desktop_app/processing/extractor.py`
- `/Users/pranay/Projects/metaextract/docs/EXTRACTOR_REGISTRY.md`
- `/Users/pranay/Projects/metaextract/docs/EXTRACTION_OBSERVABILITY.md`
- `/Users/pranay/Projects/metaextract/docs/UNIFIED_FIELD_REGISTRY_DESIGN.md`
- `/Users/pranay/Projects/metaextract/docs/extraction_pipeline_recommendations.md`
- `/Users/pranay/Projects/metaextract/docs/FIELD_INVENTORY_SYSTEM.md`
- `/Users/pranay/Projects/invoice-intelligence/docs/IMPLEMENTATION_WRITEUP.md`
- `/Users/pranay/Projects/invoice-intelligence/docs/RICH_INVOICE_SCHEMA.md`
- `/Users/pranay/Projects/invoice-intelligence/docs/FIELD_ALIAS_MAP.md`
- `/Users/pranay/Projects/invoice-intelligence/experiments/MODEL_BENCHMARKING.md`
- `/Users/pranay/Projects/Photosearch_experiment/src/enhanced_ocr_search.py`
- `/Users/pranay/Projects/Photosearch_experiment/METADATA_GAPS_ANALYSIS.md`
- `/Users/pranay/Projects/extracted_forms/OPERATING_DOCTRINE.md`
- `/Users/pranay/Projects/Web_dev/signature_auto_detect_v1`
