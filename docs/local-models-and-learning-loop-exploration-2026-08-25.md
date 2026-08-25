# Local Models and Privacy-First Learning Loop Exploration

**Date:** 2026-08-25
**Status:** Active exploration; no model or provider adoption decision yet
**Scope:** Native macOS PDF editor, with implications for the browser/local web lane
**Owner:** Project owner
**Evidence rule:** Advertised framework capability is not native-runtime proof. Every recommendation must identify its input contract, output contract, privacy class, license/provenance, resource cost, fallback, and verification level.

## Objective

Explore whether the PDF editor can learn from reviewed user interactions such as opening a document, confirming a detected field, correcting a region, filling a field, signing or placing a signature, undoing an operation, and successfully exporting a reopened PDF. In parallel, evaluate local model families for the native app, including:

- vision and document understanding;
- embeddings and local retrieval;
- graph-backed evidence and provenance;
- agentic workflows and small language models;
- MLX Swift and Apple Silicon inference;
- Core ML and other local runtimes;
- model packaging, sandboxing, licensing, privacy, and update paths.

The intended outcome is a staged adoption recommendation, not an immediate model dependency.

## Authorization and side-effect boundary

The current user requested that this exploration be recorded, executed, and investigated with parallel subagents. This authorizes read-only inspection, bounded local probes, documentation, and tests within `/Users/pranay/Projects/pdf_editor`. It does not authorize Git staging, commits, pushes, fetches, branch changes, deletion, production deployment, external data uploads, or collection of real-user PDF/signature data.

The checkout was already dirty when this exploration began and concurrent PDF-editor tasks remain active. Existing edits and untracked files are preserved. This exploration writes only this document unless a later step records a separately named evidence artifact.

## Current architecture facts

These are live-repository observations, not assumptions:

1. `Sources/PDFEditorCore/PerformanceTelemetry.swift` is a bounded, opt-in, value-free timing recorder. Its samples contain stage, duration, and success/failure, not PDF content, paths, values, or error details.
2. `Sources/PDFEditorCore/DocumentSessionContracts.swift` persists source identity and operation metadata without source bytes or edit values. Payload values are intentionally outside the recovery envelope.
3. `Sources/PDFEditorCore/PDFKitProvider.swift` normalizes pages, native widgets, text-line evidence, links, attachments, metadata, security state, vector evidence, and static candidates into `DocumentInspection`.
4. `Sources/PDFEditorCore/TemplateContracts.swift` already defines privacy-minimized layout fingerprints, normalized region signatures, keyed structural tokens, and optional exact source digests.
5. `Sources/PDFEditorCore/TemplateCaptureContracts.swift` creates draft and reviewed template mappings and child revisions. A mapping cannot become active while it remains proposed.
6. `Sources/PDFEditorApp/AppModel.swift` owns the open, review, field-edit, overlay, candidate-confirmation, undo, redo, export, and recovery boundaries.
7. The native UI recognizes signature fields but currently disables the generic “Apply native field” action for them. A complete general signature capture/export workflow is not yet implemented.
8. `PDFKitProvider.export` currently rejects edits against existing document-level AcroForms because the current PDFKit writer cannot safely preserve their widget tree. This is a provider/preservation gate, not a training-data permission.
9. The repository’s existing document-intelligence exploration recommends learning only from reviewed corrections, separating corpus populations and rights, and not uploading document bytes merely to learn from corrections.

10. The concurrent dated PDF ecosystem research records that native Vision OCR, PDFKit, the vector parser, static detector, provider contracts, and preservation validators are already present. It also records that the browser currently lacks an OCR path and that the project intentionally keeps native and browser providers behind shared contracts. See [`docs/pdf-ecosystem-deep-research-2026-08-25.md`](pdf-ecosystem-deep-research-2026-08-25.md).
11. The current decisions record contains a measured partial OCR comparison. On six governed inputs, native Vision reached mean anchor recall `0.944`, median latency `92.5 ms`, and p95 latency `391.0 ms`; local Tesseract and browser WASM were weaker on the current noisy-scan gate. This makes Vision the current native OCR baseline, not a reason to add a second vision model immediately. See [`docs/decisions.md`](decisions.md:1324).
12. The current decisions record also requires semantic label gates and hard-negative calibration for static geometry. This is the right training-label boundary: reviewed positives, reviewed hard negatives, correction outcomes, and abstention should be more valuable than unreviewed raw PDFs. See [`docs/decisions.md`](decisions.md:1699).
13. A concurrent template-index implementation is present in `Sources/PDFEditorCore/TemplateIndexContracts.swift`, `web/template-index.mjs`, and `Tests/template_index_test.mjs`. The bounded test currently fails because a revoked exact source is returned as `exact` rather than the expected `stale`. This is an active ownership-scoped mismatch and must be resolved before template retrieval becomes a learning baseline.
14. The returned Vision research report cites a separate OCR evidence snapshot with Vision median latency `97.5 ms` and p95 latency `425.1 ms`. Because both snapshots describe a measured-partial lane but do not share an explicit run identifier in this record, the latency numbers must be reconciled before either is used as a release or user-facing performance claim. The stable conclusion is provider direction, not a single canonical latency number.

## Proposed learning boundary

### Default: local, event-only learning signals

The first learning surface should record structural outcomes, preferably locally:

| Event | Candidate label or product signal | Include by default | Exclude by default |
|---|---|---|---|
| `document_opened` | document shape and inspection path | page count, rotation, text/form class, provider version | filename, path, PDF bytes, extracted text |
| `candidate_reviewed` | accepted, rejected, unknown | candidate kind, normalized region, review outcome | label text, raw OCR, screenshot |
| `candidate_corrected` | correction distance and hard negative | before/after normalized geometry, correction category | entered value, raw page image |
| `field_completed` | completion usability signal | coarse field type, success/failure, validation state | field value, profile value |
| `signature_region_confirmed` | signature-placement label | region geometry, field class, placement outcome | signature image, strokes, certificate, biometric features |
| `operation_undone` | false-positive or UX signal | operation kind, candidate class, reason if user-selected | operation payload |
| `export_validated` | end-to-end safety label | reopenability, structural/visual validation result | output PDF bytes unless explicitly donated |

This data can support detector calibration, field-type ranking, template matching, abstention, and workflow UX analysis without becoming a raw document corpus.

### Optional: explicit structured contribution

If a future server-backed training corpus is justified, use a separate opt-in purpose with a fresh random contribution ID. The contribution should contain reviewed structural records, not a stable global document identifier. Local HMAC template tokens must not be assumed to be anonymous when transmitted outside their local key scope.

Suggested contribution fields:

```json
{
  "schemaVersion": 1,
  "contributionId": "random-per-contribution",
  "documentClass": "static_text_form",
  "pageShape": {"width": 612, "height": 792, "rotation": 0},
  "candidate": {
    "kind": "text_anchored",
    "fieldType": "text",
    "normalizedRect": {"x": 0.62, "y": 0.31, "width": 0.22, "height": 0.03},
    "groupMemberCount": 1
  },
  "review": {
    "outcome": "accepted",
    "corrected": false,
    "validation": "export_reopened"
  },
  "producer": {"detectorVersion": "detector-v1", "provider": "pdfkit"}
}
```

The first contract must reject or omit raw values, source text, screenshots, filenames, paths, passwords, profile data, signature content, stable device IDs, and unbounded error strings.

### Deferred: explicit document donation

Uploading a PDF or rendered page for training is a distinct high-risk feature. It requires source-rights checks, data-subject scope, metadata stripping, value removal, signature exclusion, retention, deletion, access audit, corpus provenance, model lineage, and a policy for removing or retraining derived models. It is not part of the first local-model adoption phase.

## Model objectives and acceptable inputs

| Objective | Local model family | Training signal | Initial recommendation |
|---|---|---|---|
| Field/region detection | vision encoder, classical geometry, or hybrid detector | reviewed candidate accept/reject/correct | Start with deterministic geometry plus reviewed labels; add a local vision model only after the corpus exposes a measurable gap |
| Field-type ranking | small classifier or vision/text hybrid | coarse field type and review outcome | Good candidate for Core ML or a small local model |
| Template/variant matching | embeddings plus structural fingerprint | confirmed mapping and known variant | Add only after the existing fingerprint/index contract is benchmarked |
| Semantic label normalization | embeddings or small local text model | reviewed semantic mapping | Keep raw labels local or keyed; measure multilingual and sensitive-label leakage |
| Evidence/provenance validation | graph and deterministic constraints | operation lineage and validation results | Prefer typed graph/ledger logic before graph neural networks |
| Review explanation | constrained SLM | evidence references and explicit contract state | Use only as an explanation assistant, never as the mutation authority |
| Repair/retry orchestration | agentic controller | typed failures and bounded recovery actions | Deterministic state machine first; agent may select among allowlisted tools |
| Signature placement | vision/geometry classifier | blank-region confirmation and placement success | Safe candidate for event-only labels; exclude signature appearance |
| Signature identity or verification | biometric/signature model | signature image or stroke data | Defer; separate legal, security, and product decision |

## Privacy and governance requirements

The learning loop must use separate purposes for essential document processing, product analytics, and optional model-improvement contribution. A vague “help improve the app” control is not sufficient for a training purpose. Consent, if used, must be granular, informed, affirmative, revocable, and recorded with a versioned purpose description. The design must support access, deletion, objection, portability where applicable, retention enforcement, and auditability.

The following users and data subjects must be considered separately:

- the person operating the PDF editor;
- people whose information appears in the PDF;
- the signer represented by a signature;
- an organization that owns or controls the document;
- any downstream recipient of a completed document.

Operator consent may not cover every person represented in a client, employment, medical, financial, identity, or legal document. The initial corpus should therefore use synthetic, rights-cleared public, and explicitly contributed structural records, with private real-world content excluded by default.

## Research lanes

Each lane must return:

1. capability and task fit;
2. input/output contract;
3. native Swift integration path;
4. Apple Silicon resource and latency considerations;
5. offline and sandbox behavior;
6. model/data/license provenance;
7. privacy class and sensitive-data failure modes;
8. fallback and rollback path;
9. exact bounded local experiment;
10. primary-source URLs and evidence level.

| Lane | Status | Assigned route | Required falsifier |
|---|---|---|---|
| Vision/document understanding | queued | Apple Vision, Core ML, local VLM/document models | Does it improve field-region precision/abstention on the reviewed corpus without unsafe suggestions? |
| Embeddings/retrieval | queued | NaturalLanguage, Core ML, sentence-transformer-style local models, MLX-compatible embeddings | Does retrieval improve template/label matching over keyed structural fingerprints at acceptable memory and latency? |
| Graph/evidence | queued | typed Swift graph, SQLite/index, graph embeddings/GNN only if justified | Does graph reasoning find provenance/constraint errors that the existing typed contracts miss? |
| Agentic/SLM | queued | constrained local SLM and deterministic tool controller | Can it explain or recover bounded failures without prompt injection or unauthorized mutation? |
| MLX Swift | queued | mlx-swift, MLX Swift Examples, Metal compatibility | Can a small model load and run in the native app environment with a reproducible test? |
| Runtime/deployment | queued | Core ML, MLX Swift, llama.cpp/GGUF, ONNX/TFLite, companion process | Which runtime meets licensing, packaging, memory, crash isolation, and offline gates? |
| Adversarial synthesis | queued | repository audit and independent review | Is local-model work actually the next bottleneck, or is corpus/provider/UI fidelity still the limiting factor? |

Parallel-agent note: the first spawn attempt could not start fresh lanes because the Codex agent-thread limit was already occupied by active PDF-editor tasks. Those tasks were not interrupted or repurposed. Several already-running relevant lanes subsequently returned reports covering Vision, embeddings, runtimes, MLX Swift, graphs, and bounded SLM/agentic orchestration. The returned reports are summarized below. A fresh independent lane for every requested topic was not possible within the active-thread limit, so the evidence level remains mixed between live checkout probes, returned static research, and primary-source documentation.

## Primary-source research snapshot

### Vision, Core ML, and Natural Language

Apple’s Vision framework provides on-device image and document analysis, including text recognition, rectangle/text detection, document recognition, and Core ML-backed requests. The current code already uses a native Vision OCR provider and reports normalized bounds, confidence aggregates, recall, and latency in benchmark results.

Core ML remains the preferred native runtime for a compact learned detector or classifier when a model can be converted to a supported `.mlmodel` or ML Program contract. `MLModelConfiguration` exposes compute-unit selection and related runtime settings, while `MLComputeUnits` can allow CPU, GPU, Neural Engine, or all available units. The application must still benchmark model load, prediction latency, memory, and fallback behavior on the target Mac.

Natural Language is useful for local language identification, tokenization, lemmatization, named-entity tagging, and lightweight semantic normalization. It is not a general-purpose embedding store or document-layout model. It should be considered an inexpensive pre-processing or label-normalization baseline before adding a neural embedding model.

Primary sources:

- [Apple Vision](https://developer.apple.com/documentation/vision)
- [Apple RecognizeTextRequest](https://developer.apple.com/documentation/vision/recognizetextrequest)
- [Apple VNCoreMLRequest](https://developer.apple.com/documentation/vision/vncoremlrequest)
- [Apple Core ML model configuration](https://developer.apple.com/documentation/coreml/mlmodelconfiguration)
- [Apple MLComputeUnits](https://developer.apple.com/documentation/coreml/mlcomputeunits)
- [Apple Natural Language](https://developer.apple.com/documentation/naturallanguage)

### Foundation Models and agentic assistance

Apple’s Foundation Models framework exposes structured output, language understanding, tool calling, and model/session abstractions. However, the current machine is macOS `15.7.7`, while Apple’s `SystemLanguageModel` documentation lists macOS `26.0` and later availability. The current SDK can typecheck an `import FoundationModels`, but that is compile-time availability evidence only. The native app must not depend on this framework for its macOS 15 runtime without an explicit availability fallback.

If the minimum OS later moves to macOS 26, Foundation Models could be evaluated for explanation, semantic mapping suggestions, and bounded tool selection. It should not own PDF mutation. The existing permission, source-binding, review, operation, undo, and validation paths remain authoritative.

Primary sources:

- [Apple Foundation Models](https://developer.apple.com/documentation/FoundationModels)
- [Apple SystemLanguageModel availability](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel)
- [Apple Foundation Models updates](https://developer.apple.com/documentation/Updates/FoundationModels)

### MLX Swift, MLX Swift LM, and embeddings

The official MLX Swift package declares macOS 14 as its package platform and uses Metal and Accelerate on Apple platforms. That is compatible with this project’s macOS 15 minimum in principle. `mlx-swift-lm` declares macOS 14 as well and provides `MLXLLM`, `MLXVLM`, `MLXLMCommon`, `MLXEmbedders`, guided generation, and optional Foundation Models integration.

The current `mlx-swift-lm` documentation lists embedding implementations and registered model families including very small BGE Micro and GTE Tiny models, MiniLM, multilingual E5, BGE variants, Nomic, Snowflake, Gemma embedding, and Qwen embedding families. This makes MLX Swift a credible candidate for local template or label retrieval, but the app would own model weights, tokenizer/download integration, compatibility checks, memory budgeting, model licensing, and update/rollback behavior.

The Foundation Models bridge inside `mlx-swift-lm` requires the macOS/iOS/visionOS 27 SDK. That bridge should be excluded for this project’s macOS 15 target. MLX LLM, VLM, and embedding libraries can still be evaluated independently if their package and model contracts build on the pinned toolchain.

The official repository also warns that `main` is a new 3.x major line with breaking API changes. A real integration should pin a reviewed release rather than depend on `main`, and should record the exact `mlx-swift`, `mlx-swift-lm`, Swift, SDK, Metal, model, tokenizer, and weight revisions.

Primary sources:

- [MLX Swift package](https://github.com/ml-explore/mlx-swift)
- [MLX Swift LM](https://github.com/ml-explore/mlx-swift-lm)
- [MLX Swift LM embedding reference](https://github.com/ml-explore/mlx-swift-lm/blob/main/skills/mlx-swift-lm/references/embeddings.md)
- [MLX Swift LM model compatibility](https://github.com/ml-explore/mlx-swift-lm/blob/main/Libraries/MLXLMCommon/Documentation.docc/model-compatibility.md)
- [MLX Swift LM release history](https://github.com/ml-explore/mlx-swift-lm/releases)

### Runtime alternatives

Core ML is the cleanest native path for fixed, compact detectors and classifiers. MLX Swift is more flexible for self-managed LLM, VLM, and embedding families, but adds a larger model/runtime lifecycle. ONNX Runtime can use a Core ML execution provider and is useful when an existing model is already in ONNX, but it introduces another native dependency and its Core ML provider is documented as an execution-provider layer rather than an application-level PDF abstraction. `llama.cpp` or a GGUF companion can be useful for local SLM experiments, but should remain a separate process or tightly bounded adapter until memory, crash, licensing, and prompt-injection behavior are measured.

Primary sources:

- [ONNX Runtime execution providers](https://onnxruntime.ai/docs/execution-providers/)
- [ONNX Runtime Core ML execution provider](https://onnxruntime.ai/docs/execution-providers/CoreML-ExecutionProvider.html)
- [MLX Swift LM model compatibility](https://github.com/ml-explore/mlx-swift-lm/blob/main/Libraries/MLXLMCommon/Documentation.docc/model-compatibility.md)

### Returned parallel research: graph, embeddings, agentic SLM, and runtime lanes

The graph lane recommends treating the graph as a derived typed projection over existing contracts. The live code already contains the conceptual nodes and relationships needed for a first graph experiment: document inspection, pages, native fields, candidates, evidence, fusion results, review decisions, edit-operation lineage, validation reports, template mappings, and template revisions. The graph should answer provenance questions such as:

- why a candidate was suggested;
- which evidence families support or contradict it;
- whether a review decision authorized a mapping or value;
- which operation produced which validation result;
- how a template revision relates to a parent and a stale source;
- which hard negatives resemble a current candidate.

The graph lane specifically recommends not adding SQLite, GRDB, Core Data, a graph database, graph embeddings, or a GNN yet. The first falsifier should be a typed Swift graph benchmark that asks whether multi-hop provenance and constraint queries find errors missed by the existing typed contracts. If the graph is useful, it should remain a query and explanation projection, not a second document truth model.

The embedding lane recommends preserving `PDFTemplateFingerprint` and deterministic `PDFTemplateIndex` as identity authorities. Embeddings may improve semantic label normalization, cross-language alias recall, and candidate ranking inside an already-compatible structural shortlist. They must not create `exact`, `knownVariant`, or `familyMatch`, override stale-source refusal, approve a mapping, select a profile value, or create an `EditOperation`.

The proposed order for semantic retrieval is:

1. Run a no-persistence `NaturalLanguage` sentence-embedding baseline and record actual language/revision availability on the target OS.
2. Run MLX Swift with a locally provisioned, pinned multilingual E5-small-style embedder, using the model’s declared pooling, normalization, prefix, tokenizer, and dimension contract.
3. Convert the same reference model to Core ML and compare tokenization, pooling, vector output, and top-k retrieval, making Core ML the shipping candidate only if semantic parity and resource gates pass.
4. Keep llama.cpp/GGUF as a portability and quantization comparison lane, not as the first native embedding dependency.

Embedding vectors are derived semantic content. Raw labels, vectors, and tokenized text should be memory-only by default. Any persistent semantic index should be separately versioned, encrypted or access-scoped, and invalidated when the model, tokenizer, pooling, normalization, dimension, or quantization changes. The existing keyed structural index should not silently become a semantic index.

The agentic/SLM lane recommends a bounded local intelligence plane:

```text
deterministic inspect and preflight
  -> model-assisted explanation, ranking, or extraction proposal
  -> deterministic schema, provenance, and source checks
  -> human review
  -> deterministic EditOperation materialization
  -> new-copy export, reopen, and independent validation
```

The model must not own PDF parsing, source integrity, field coordinates, native field identity, signature validity, redaction or sanitization completion, export authorization, recovery mutation, arbitrary tools, shell access, filesystem access, URL fetching, or network routing. For a future packaged SLM, the returned runtime comparison favors llama.cpp/GGUF behind an XPC or companion process for crash and memory isolation. MLX Swift is the Apple-only experiment path, and Ollama is a developer-comparison provider rather than a default product dependency. Apple Foundation Models remain an optional macOS 26-or-later capability and cannot be a baseline for this macOS 15 app.

The runtime lane separates the roles of the available technologies:

| Runtime or layer | Recommended role | Current disposition |
|---|---|---|
| Apple Vision and Core ML | Native OCR evidence, fixed detectors, classifiers, and converted small embedders | Baseline or first native path |
| MLX Swift and MLX Swift LM | Apple Silicon embeddings, VLMs, and small SLM experiments | Conditional, not admitted |
| llama.cpp and GGUF | Portable quantized SLM/VLM or embedding companion | Future provider, preferably isolated |
| ONNX Runtime | Portable fixed vision, embedding, or graph models | Fallback comparison lane |
| LiteRT/TFLite and MediaPipe | Task-specific edge models and graph pipelines | Conditional, not generic runtime |
| Ollama | Developer evaluation or explicit user-installed provider | Not a bundled authority |
| XPC or companion process | Crash, memory, and trust boundary for heavier or less-trusted runtimes | Recommended for future SLMs |

The runtime lane also reports a machine-specific MLX risk. This repository has no MLX dependency, model cache, or MLX artifact. The local Xcode installation lacks the Metal Toolchain, so a clean MLX shader build cannot currently be verified. A prior machine-level MLX artifact still reports a macOS 15 incompatibility when loading a Metal language version 4.0 metallib. This is not a repository-specific inference failure, but it is sufficient to keep MLX outside the default native target until an exact pinned package, model, metallib, and signed-app smoke test pass together.

The Vision lane confirms the current direction: PDFKit and direct PDF/vector inspection remain authoritative for authored PDF structure, native Vision OCR remains image-derived evidence, rectangle and segmentation requests remain geometry or preprocessing evidence, and newer structured document recognition should be treated as an availability-gated optional provider until macOS 15 behavior is proven. A custom Core ML detector should be considered only after reviewed labels show a specific gap that deterministic geometry, native fields, OCR, and Vision rectangles cannot close. No Vision or Core ML result should become an authored field, signature identity, signature validity claim, or edit operation without review and deterministic validation.

## Local probe results

### Environment

Observed on 2026-08-25:

```text
architecture: arm64
macOS: 15.7.7 (24G720)
Swift: 6.2.4
Xcode: 26.3 (17C529)
project minimum: macOS 15.0
Python mlx module: absent in the probed Python environment
```

### Framework imports

`swiftc -typecheck -target arm64-apple-macosx15.0` passed for imports of `Vision`, `CoreML`, and `NaturalLanguage`. It also passed for an `FoundationModels` import because the installed SDK exposes the declarations. This does not prove that `SystemLanguageModel` is available on the running macOS 15.7.7 system.

### Existing template-index test

Command:

```text
node Tests/template_index_test.mjs
```

Result: failed at `Tests/template_index_test.mjs:94` because the observed result was `exact` and the expected result was `stale` for a revoked exact template. This is a useful safety finding. The lifecycle rule for exact matches needs to be made explicit before any embedding or learned retrieval layer is allowed to select a template.

### Package metadata

`swift package dump-package` passed. The project currently targets macOS 15.0 and declares no external Swift package dependency for MLX, Core ML wrappers, vector databases, or language models. This supports a staged adapter experiment but also means there is no current package lock, model manifest, or inference-provider lifecycle in the native app.

## Current decision matrix

| Capability | Best first native path | Why | Defer or reject |
|---|---|---|---|
| OCR on scans | Apple Vision | Already implemented and measured; on-device; benchmark contract exists | Do not add a second VLM until the governed corpus proves a gap |
| Static field detection | Geometry + reviewed hard negatives, then Core ML if needed | Current contracts and calibration are explicit; avoids model opacity | Do not use a general VLM as an automatic field creator |
| Template matching | Existing keyed fingerprint/index, then small local embeddings | Deterministic structure is explainable and privacy-minimized | Do not replace the index with vector similarity before the lifecycle mismatch is fixed |
| Label normalization | Natural Language baseline, then MLXEmbedders/Core ML | Small scope and easy fallback | Do not transmit raw labels or build a global embedding service by default |
| Evidence graph | Typed Swift graph/ledger over existing contracts | Preserves provenance and deterministic validation | Do not add a GNN without a measured graph task |
| Explanation assistant | Deterministic evidence cards, then Foundation Models where OS permits or a bounded MLX SLM | Explanation can be useful without granting mutation authority | Do not let an SLM decide permissions, source binding, or export safety |
| Agentic repair | Explicit state machine with allowlisted actions | Retry/idempotency/failure behavior remains inspectable | Do not expose arbitrary shell, filesystem, network, or PDF actions to a model |
| Native runtime | Core ML for fixed models; MLX Swift for self-managed embeddings/LLM/VLM experiments | Clear separation by model class | Do not add both runtimes to the production target before a benchmark justifies it |

## Updated adoption recommendation

1. Keep the existing native Vision OCR lane as the baseline and make its evidence more reusable for field-region learning.
2. Finish and verify the template-index lifecycle contract before evaluating embeddings. The exact-versus-stale mismatch is a safety issue, not a cosmetic test failure.
3. Create a local-only, value-free learning-event fixture generator from candidate review and export validation. This is the corpus foundation for every later model family.
4. Evaluate a very small MLX embedder or Core ML classifier only against the deterministic baseline. The first experiment should use synthetic/public structural records, not real user PDFs.
5. Consider a vision model only for scanned or text-poor cases where Vision OCR plus geometry has a measured weakness.
6. Keep agentic/SLM work in an explanation and bounded-recovery lane. Treat Apple Foundation Models as a future macOS 26+ option, not a current macOS 15 dependency.
7. Keep MLX Swift as an experiment or optional provider until package pinning, model manifests, model-license review, weight distribution, memory limits, and Metal compatibility are verified on this machine.


## Adoption gates

No model is adopted for the native app until it clears the relevant gates:

1. **Contract fit:** output maps to `DocumentInspection`, evidence, template, operation, or validation contracts without a shadow source of truth.
2. **Safety:** model abstention and malformed/adversarial input behavior are explicit.
3. **Privacy:** no raw values or signatures enter the default path; contribution and deletion behavior are testable.
4. **Performance:** cold start, warm inference, memory, and UI-thread behavior are measured on the target Mac.
5. **Offline:** the app behavior when weights are absent, corrupted, incompatible, or unavailable is user-visible and bounded.
6. **Provider fallback:** deterministic or alternate-provider behavior exists for model failure.
7. **Provenance:** model, weights, code, license, revision, quantization, and packaging are recorded.
8. **Corpus quality:** synthetic, public, and private-contributed populations remain separate, rights-labeled, and independently benchmarked.
9. **Release:** model updates have compatibility, rollback, migration, and support plans.

## Initial staged recommendation

### Stage 0: finish the value-free learning contract

Create a local-only event contract and fixture generator for reviewed structural events. Do not send events to a service. Use synthetic and existing rights-cleared benchmark fixtures. Add privacy tests that fail if values, raw text, paths, or signature payloads enter the record.

### Stage 1: strengthen deterministic document intelligence

Benchmark the existing geometry, native-field, text, vector, and template-index paths. Add hard negatives and calibration from reviewed outcomes. This stage may create more value than adding a VLM immediately because the current detector and provider preservation gates remain material bottlenecks.

### Stage 2: embeddings for local retrieval and template variants

Evaluate a small multilingual embedding path against the existing template fingerprint and index. Keep embeddings local and encrypted or scoped to the workspace. Promote only reviewed mappings. Measure retrieval quality, memory, startup, and false-linking risk.

### Stage 3: vision model for scanned or text-poor pages

Only add a local vision model when the corpus demonstrates that native structure and geometry are insufficient. Keep the vision output as evidence with confidence and abstention, never as an automatic edit.

### Stage 4: constrained SLM or agentic assistant

Use a local SLM for explanation, mapping suggestions, and bounded recovery choices. Keep mutation behind existing permission, review, source-binding, and validation gates. The SLM must not receive arbitrary untrusted PDF instructions as authoritative tool commands.

### Stage 5: optional contribution and model update pipeline

Only after the local loop is useful should we consider explicit structured contribution. Raw document donation and signature-content training remain separate proposals requiring a privacy/security decision and a distinct corpus governance record.

## Evidence ledger

A row is promoted from proposed to verified only when the exact command, environment, artifact, and result are recorded. Returned static research is useful for design direction, but it is not a substitute for the missing runtime or model-quality proof.

| Capability | Candidate | Repo integration point | Current truth | Evidence needed | Decision |
|---|---|---|---|---|---|
| Vision | Apple Vision/Core ML/local model | provider inspection and evidence graph | Vision OCR measured partial; custom model proposed | native runtime, accuracy, geometry calibration, and abstention benchmark | Vision baseline, custom model open |
| Embeddings | NaturalLanguage/Core ML/MLX-compatible model | template fingerprint/index and semantic mapping | advisory retrieval only; no runtime model run yet | retrieval benchmark, hard negatives, stale refusal, and memory/latency run | open |
| Graph | typed Swift evidence graph | inspection/review/operation/validation lineage | conceptual graph already exists in current contracts | multi-hop provenance and constraint benchmark | typed projection first |
| SLM | constrained local model | explanation/review assistant only | proposed; no model dependency | prompt-injection, offline, latency, schema, and bounded-tool test | open |
| Agentic | deterministic controller plus optional SLM | review/recovery workflow | bounded state-machine design recommended | failure/retry/idempotency and permission test | open |
| MLX Swift | mlx-swift and mlx-swift-lm | optional native model adapter | package absent; Metal Toolchain missing; machine-level metallib blocker relevant | exact package build, model load, inference, signed bundle, macOS compatibility | not admitted |
| Runtime | Core ML/MLX/llama.cpp/ONNX/LiteRT/companion | provider-neutral inference boundary | capability-based adapter recommended | license, packaging, memory, crash isolation, fallback, and offline proof | open |

## Sources to verify

The research reports must prefer primary sources, including Apple Developer documentation, official Apple MLX repositories and examples, official runtime repositories, official model cards, and authoritative licensing documentation. Web claims are current as of the date checked and must not be copied into product claims without a local verification record.

## Review and revisit triggers

Revisit this record when:

- the template-index concurrent work is reconciled into the canonical path;
- a real signature capture/export workflow is implemented and validated;
- the reviewed correction corpus reaches a useful size;
- a local model demonstrates improvement over deterministic baselines;
- the native app’s target macOS and distribution/sandbox requirements are fixed;
- model packaging or network behavior changes;
- a user asks for cloud contribution, raw document donation, or signature-content training.
