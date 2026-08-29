import Foundation

/// Populated canonical capability matrix — all 42 implemented features
/// with real providers, evidence gates, owners, and sequencing.
///
/// This is the programmatic source of truth for the capability matrix.
/// docs/capability-matrix.md is the human-readable export.
///
/// First principle: every capability must have:
/// - A named provider per lane (native, browser, companion)
/// - An evidence gate that must pass before the capability is claim-ready
/// - An owner responsible for maintenance
/// - Dependencies sequenced correctly
///
/// Doctrine alignment:
/// - §5: Evidence-based — every gate is measurable
/// - §11: Engineering integrity — sequencing prevents broken dependencies
/// - §13: Product reality — claims must match implementation

extension CanonicalCapabilityMatrix {

    /// The fully populated matrix with all 42 capabilities.
    public static func populate() -> CanonicalCapabilityMatrix {
        var matrix = CanonicalCapabilityMatrix()

        // ── READER ARCHETYPE ──

        matrix.upsert(CapabilityMatrixEntry(
            id: "cap-01-open-import",
            capability: "Open/Import",
            scope: ProductScope(
                name: "Open/Import", userStatement: "Open a PDF file",
                archetype: "Reader", jobID: "J01",
                claim: "Supported for bounded local files", claimAccuracy: "Verified"
            ),
            providers: [
                ProviderEntry(providerName: "PDFKit", lane: .native, support: .primary, license: "Apple"),
                ProviderEntry(providerName: "PDF.js", lane: .browser, support: .supported, license: "Apache-2.0"),
            ],
            contracts: ["DocumentSource"],
            evidenceGates: [
                EvidenceGate(id: "RG-001", description: "Public AcroForm fidelity", status: .partial),
                EvidenceGate(id: "RG-060", description: "Bounded input safety", status: .partial),
            ],
            owner: "Core Team", sequencePriority: 10,
            productClaim: "Supported for bounded local files", claimAccuracy: "Verified"
        ))

        matrix.upsert(CapabilityMatrixEntry(
            id: "cap-02-render-navigation",
            capability: "Render/Navigation",
            scope: ProductScope(
                name: "Render/Navigation", userStatement: "View and navigate PDF pages",
                archetype: "Reader", jobID: "J01",
                claim: "Supported on reviewed PDFs", claimAccuracy: "Verified"
            ),
            providers: [
                ProviderEntry(providerName: "PDFKit", lane: .native, support: .primary, license: "Apple"),
                ProviderEntry(providerName: "PDF.js", lane: .browser, support: .supported, license: "Apache-2.0"),
                ProviderEntry(providerName: "PipelineRenderer", lane: .native, support: .supported, license: "MIT"),
            ],
            contracts: ["ViewState"],
            evidenceGates: [
                EvidenceGate(id: "RG-031", description: "Page rendering", status: .pass),
                EvidenceGate(id: "RG-032", description: "Page navigation", status: .pass),
                EvidenceGate(id: "RG-038", description: "Rotation support", status: .partial),
            ],
            owner: "Core Team", sequencePriority: 20,
            productClaim: "Supported on reviewed PDFs", claimAccuracy: "Verified"
        ))

        matrix.upsert(CapabilityMatrixEntry(
            id: "cap-03-extractable-text",
            capability: "Extractable Text",
            scope: ProductScope(
                name: "Extractable Text", userStatement: "Copy and search text from PDF",
                archetype: "Reader", jobID: "J02",
                claim: "Supported with provider caveats", claimAccuracy: "Verified"
            ),
            providers: [
                ProviderEntry(providerName: "PDFKit", lane: .native, support: .primary, license: "Apple"),
                ProviderEntry(providerName: "PDF.js", lane: .browser, support: .supported, license: "Apache-2.0"),
            ],
            contracts: ["page text evidence"],
            evidenceGates: [
                EvidenceGate(id: "RG-039", description: "Text extraction accuracy", status: .pass),
                EvidenceGate(id: "RG-060", description: "Bounded input safety", status: .partial),
            ],
            owner: "Core Team", sequencePriority: 30,
            productClaim: "Supported with provider caveats", claimAccuracy: "Verified"
        ))

        matrix.upsert(CapabilityMatrixEntry(
            id: "cap-04-ocr-fallback",
            capability: "OCR Fallback",
            scope: ProductScope(
                name: "OCR Fallback", userStatement: "Extract text from scanned PDFs",
                archetype: "Reader", jobID: "J02",
                claim: "Not a general release claim", claimAccuracy: "Inferred"
            ),
            providers: [
                ProviderEntry(providerName: "Vision", lane: .native, support: .conditional, license: "Apple", limitations: ["English only", "macOS only"]),
                ProviderEntry(providerName: "Not yet wired", lane: .browser, support: .unsupported),
            ],
            contracts: ["OCR evidence"],
            evidenceGates: [
                EvidenceGate(id: "RG-008", description: "Scanned-PDF OCR corpus", status: .partial),
                EvidenceGate(id: "RG-009", description: "OCR acceptance thresholds", status: .partial),
                EvidenceGate(id: "RG-061", description: "OCR worker lane", status: .open),
            ],
            owner: "OCR Team", sequencePriority: 100,
            productClaim: "Not a general release claim", claimAccuracy: "Inferred"
        ))

        matrix.upsert(CapabilityMatrixEntry(
            id: "cap-05-search",
            capability: "Search",
            scope: ProductScope(
                name: "Search", userStatement: "Find text in a PDF",
                archetype: "Reader", jobID: "J02",
                claim: "Supported for extractable text", claimAccuracy: "Verified"
            ),
            providers: [
                ProviderEntry(providerName: "PDFKit", lane: .native, support: .primary, license: "Apple"),
                ProviderEntry(providerName: "PDF.js", lane: .browser, support: .supported, license: "Apache-2.0"),
            ],
            contracts: ["search match contract"],
            evidenceGates: [
                EvidenceGate(id: "RG-041", description: "Exact search", status: .pass),
                EvidenceGate(id: "RG-042", description: "Fuzzy search", status: .pass),
                EvidenceGate(id: "RG-043", description: "Search announcements", status: .pass),
            ],
            owner: "Core Team", sequencePriority: 40,
            productClaim: "Supported for extractable text", claimAccuracy: "Verified"
        ))

        matrix.upsert(CapabilityMatrixEntry(
            id: "cap-06-text-copy",
            capability: "Text Copy",
            scope: ProductScope(
                name: "Text Copy", userStatement: "Copy text to clipboard",
                archetype: "Reader", jobID: "J04",
                claim: "Supported for extractable text", claimAccuracy: "Verified"
            ),
            providers: [
                ProviderEntry(providerName: "NSPasteboard", lane: .native, support: .primary, license: "Apple"),
                ProviderEntry(providerName: "Clipboard", lane: .browser, support: .supported, license: "W3C"),
            ],
            contracts: ["page text"],
            evidenceGates: [
                EvidenceGate(id: "RG-039", description: "Text extraction accuracy", status: .pass),
                EvidenceGate(id: "RG-055", description: "Clipboard permissions", status: .pass),
            ],
            owner: "Core Team", sequencePriority: 45,
            productClaim: "Supported for extractable text", claimAccuracy: "Verified"
        ))

        matrix.upsert(CapabilityMatrixEntry(
            id: "cap-07-links",
            capability: "Links",
            scope: ProductScope(
                name: "Links", userStatement: "Click links in PDF",
                archetype: "Reader", jobID: "J01",
                claim: "Safe internal/external subset", claimAccuracy: "Verified"
            ),
            providers: [
                ProviderEntry(providerName: "PDFKit", lane: .native, support: .primary, license: "Apple"),
                ProviderEntry(providerName: "PDF.js", lane: .browser, support: .supported, license: "Apache-2.0"),
            ],
            contracts: ["PDFLink"],
            evidenceGates: [
                EvidenceGate(id: "RG-044", description: "Internal links", status: .pass),
                EvidenceGate(id: "RG-045", description: "External link safety", status: .partial),
            ],
            owner: "Core Team", sequencePriority: 50,
            productClaim: "Safe internal/external subset", claimAccuracy: "Verified"
        ))

        matrix.upsert(CapabilityMatrixEntry(
            id: "cap-08-outlines",
            capability: "Outlines",
            scope: ProductScope(
                name: "Outlines", userStatement: "Navigate via table of contents",
                archetype: "Reader", jobID: "J01",
                claim: "Supported when source exposes targets", claimAccuracy: "Verified"
            ),
            providers: [
                ProviderEntry(providerName: "PDFKit", lane: .native, support: .primary, license: "Apple"),
                ProviderEntry(providerName: "PDF.js", lane: .browser, support: .supported, license: "Apache-2.0"),
            ],
            contracts: ["PDFOutlineItem"],
            evidenceGates: [
                EvidenceGate(id: "RG-046", description: "Outline extraction", status: .pass),
                EvidenceGate(id: "RG-065", description: "Outline navigation", status: .pass),
            ],
            owner: "Core Team", sequencePriority: 55,
            productClaim: "Supported when source exposes targets", claimAccuracy: "Verified"
        ))

        matrix.upsert(CapabilityMatrixEntry(
            id: "cap-09-metadata",
            capability: "Metadata",
            scope: ProductScope(
                name: "Metadata", userStatement: "View document properties",
                archetype: "Reader", jobID: "J01",
                claim: "Provider-dependent facts", claimAccuracy: "Verified"
            ),
            providers: [
                ProviderEntry(providerName: "PDFKit", lane: .native, support: .primary, license: "Apple"),
                ProviderEntry(providerName: "PDF.js", lane: .browser, support: .supported, license: "Apache-2.0"),
            ],
            contracts: ["PDFDocumentMetadata"],
            evidenceGates: [
                EvidenceGate(id: "RG-047", description: "Metadata extraction", status: .pass),
                EvidenceGate(id: "RG-066", description: "Metadata display", status: .pass),
            ],
            owner: "Core Team", sequencePriority: 60,
            productClaim: "Provider-dependent facts", claimAccuracy: "Verified"
        ))

        matrix.upsert(CapabilityMatrixEntry(
            id: "cap-10-permissions",
            capability: "Permissions",
            scope: ProductScope(
                name: "Permissions", userStatement: "See document restrictions",
                archetype: "Reader", jobID: "J06",
                claim: "Informational until enforcement corpus passes", claimAccuracy: "Inferred"
            ),
            providers: [
                ProviderEntry(providerName: "PDFKit", lane: .native, support: .primary, license: "Apple"),
                ProviderEntry(providerName: "PDF.js", lane: .browser, support: .supported, license: "Apache-2.0"),
            ],
            contracts: ["PDFPermissionsSummary"],
            evidenceGates: [
                EvidenceGate(id: "RG-027", description: "Permission enforcement", status: .partial),
                EvidenceGate(id: "RG-048", description: "Permission display", status: .pass),
            ],
            owner: "Security Team", sequencePriority: 65,
            productClaim: "Informational until enforcement corpus passes", claimAccuracy: "Inferred"
        ))

        matrix.upsert(CapabilityMatrixEntry(
            id: "cap-11-attachments",
            capability: "Attachments",
            scope: ProductScope(
                name: "Attachments", userStatement: "See embedded files",
                archetype: "Reader", jobID: "J01",
                claim: "Inventory only until safe extraction passes", claimAccuracy: "Inferred"
            ),
            providers: [
                ProviderEntry(providerName: "PDFKit", lane: .native, support: .conditional, license: "Apple"),
                ProviderEntry(providerName: "PDF.js", lane: .browser, support: .conditional, license: "Apache-2.0"),
            ],
            contracts: ["attachment facts"],
            evidenceGates: [
                EvidenceGate(id: "RG-024", description: "Attachment security", status: .partial),
                EvidenceGate(id: "RG-049", description: "Attachment inventory", status: .pass),
                EvidenceGate(id: "RG-067", description: "Attachment extraction", status: .open),
            ],
            owner: "Security Team", sequencePriority: 70,
            productClaim: "Inventory only until safe extraction passes", claimAccuracy: "Inferred"
        ))

        matrix.upsert(CapabilityMatrixEntry(
            id: "cap-12-password-open",
            capability: "Password Open",
            scope: ProductScope(
                name: "Password Open", userStatement: "Open password-protected PDFs",
                archetype: "Reader", jobID: "J06",
                claim: "Supported for provider-compatible encryption", claimAccuracy: "Verified"
            ),
            providers: [
                ProviderEntry(providerName: "PDFKit", lane: .native, support: .primary, license: "Apple"),
                ProviderEntry(providerName: "PDF.js", lane: .browser, support: .supported, license: "Apache-2.0"),
            ],
            contracts: ["PDFSecuritySummary"],
            evidenceGates: [
                EvidenceGate(id: "RG-010", description: "Encrypted-document corpus", status: .partial),
                EvidenceGate(id: "RG-050", description: "Password handling security", status: .pass),
                EvidenceGate(id: "RG-068", description: "Password recovery", status: .partial),
            ],
            owner: "Security Team", sequencePriority: 75,
            productClaim: "Supported for provider-compatible encryption", claimAccuracy: "Verified"
        ))

        // ── FORMS / EDITING ──

        matrix.upsert(CapabilityMatrixEntry(
            id: "cap-13-acroforms",
            capability: "Native AcroForms",
            scope: ProductScope(
                name: "Native AcroForms", userStatement: "Fill and edit PDF forms",
                archetype: "Reader", jobID: "J04",
                claim: "Restricted pending provider decision", claimAccuracy: "Inferred"
            ),
            providers: [
                ProviderEntry(providerName: "PDFKit", lane: .native, support: .primary, license: "Apple"),
                ProviderEntry(providerName: "pdf-lib", lane: .browser, support: .conditional, license: "MIT"),
                ProviderEntry(providerName: "PDFIncrementalFormWriter", lane: .native, support: .supported, license: "MIT"),
            ],
            contracts: ["field operation contract"],
            evidenceGates: [
                EvidenceGate(id: "RG-001", description: "Public AcroForm fidelity", status: .partial),
                EvidenceGate(id: "RG-002", description: "AcroForm provider decision", status: .pass),
                EvidenceGate(id: "RG-069", description: "Form field editing", status: .partial),
            ],
            owner: "Core Team", sequencePriority: 80,
            productClaim: "Restricted pending provider decision", claimAccuracy: "Inferred"
        ))

        matrix.upsert(CapabilityMatrixEntry(
            id: "cap-14-overlays",
            capability: "Overlays",
            scope: ProductScope(
                name: "Overlays", userStatement: "Add text and shapes to PDF",
                archetype: "Creator", jobID: "J01",
                claim: "Bounded overlay subset", claimAccuracy: "Verified"
            ),
            providers: [
                ProviderEntry(providerName: "PDFKit", lane: .native, support: .primary, license: "Apple"),
                ProviderEntry(providerName: "pdf-lib", lane: .browser, support: .supported, license: "MIT"),
            ],
            contracts: ["EditOperation"],
            evidenceGates: [
                EvidenceGate(id: "RG-018", description: "Output-integrity validation", status: .partial),
                EvidenceGate(id: "RG-020", description: "Browser export fidelity", status: .partial),
            ],
            owner: "Core Team", sequencePriority: 85,
            productClaim: "Bounded overlay subset", claimAccuracy: "Verified"
        ))

        matrix.upsert(CapabilityMatrixEntry(
            id: "cap-15-signatures",
            capability: "Signatures",
            scope: ProductScope(
                name: "Signatures", userStatement: "Verify digital signatures",
                archetype: "Reader", jobID: "J06",
                claim: "Not supported for editing claims", claimAccuracy: "Observed"
            ),
            providers: [
                ProviderEntry(providerName: "PDFKit", lane: .native, support: .conditional, license: "Apple", limitations: ["Detection only"]),
                ProviderEntry(providerName: "PDF.js", lane: .browser, support: .conditional, license: "Apache-2.0", limitations: ["Detection only"]),
            ],
            contracts: ["security facts"],
            evidenceGates: [
                EvidenceGate(id: "RG-014", description: "Signed-document behavior", status: .partial),
                EvidenceGate(id: "RG-070", description: "Signature validation", status: .open),
            ],
            owner: "Security Team", sequencePriority: 90,
            productClaim: "Not supported for editing claims", claimAccuracy: "Observed"
        ))

        matrix.upsert(CapabilityMatrixEntry(
            id: "cap-16-xfa",
            capability: "XFA",
            scope: ProductScope(
                name: "XFA", userStatement: "Handle XFA forms",
                archetype: "Reader", jobID: "J04",
                claim: "Explicitly unsupported until proven", claimAccuracy: "Observed"
            ),
            providers: [
                ProviderEntry(providerName: "Not established", lane: .native, support: .unsupported),
                ProviderEntry(providerName: "Not established", lane: .browser, support: .unsupported),
            ],
            contracts: ["unsupported capability"],
            evidenceGates: [
                EvidenceGate(id: "RG-015", description: "XFA behavior", status: .partial),
                EvidenceGate(id: "RG-071", description: "XFA taxonomy", status: .open),
            ],
            owner: "Core Team", sequencePriority: 200,
            productClaim: "Explicitly unsupported until proven", claimAccuracy: "Observed"
        ))

        // ── ACCESSIBILITY ──

        matrix.upsert(CapabilityMatrixEntry(
            id: "cap-17-tagged-pdf",
            capability: "Tagged PDF",
            scope: ProductScope(
                name: "Tagged PDF", userStatement: "Access tagged PDF structure",
                archetype: "Reader", jobID: "J01",
                claim: "No PDF/UA claim", claimAccuracy: "Observed"
            ),
            providers: [
                ProviderEntry(providerName: "PDFKit", lane: .native, support: .conditional, license: "Apple"),
                ProviderEntry(providerName: "PDF.js", lane: .browser, support: .conditional, license: "Apache-2.0"),
            ],
            contracts: ["accessibility facts"],
            evidenceGates: [
                EvidenceGate(id: "RG-004", description: "PDF/UA validation", status: .partial),
                EvidenceGate(id: "RG-005", description: "Authored tag-tree preservation", status: .partial),
                EvidenceGate(id: "RG-052", description: "Tagged PDF support", status: .partial),
            ],
            owner: "Accessibility Team", sequencePriority: 110,
            productClaim: "No PDF/UA claim", claimAccuracy: "Observed"
        ))

        matrix.upsert(CapabilityMatrixEntry(
            id: "cap-18-accessibility",
            capability: "Reader Accessibility",
            scope: ProductScope(
                name: "Reader Accessibility", userStatement: "Use VoiceOver and screen readers",
                archetype: "Reader", jobID: "J01",
                claim: "Surface implemented, observation pending", claimAccuracy: "Inferred"
            ),
            providers: [
                ProviderEntry(providerName: "Native UI", lane: .native, support: .supported, license: "Apple"),
                ProviderEntry(providerName: "DOM landmarks", lane: .browser, support: .supported, license: "W3C"),
            ],
            contracts: ["status/focus semantics"],
            evidenceGates: [
                EvidenceGate(id: "RG-006", description: "Native VoiceOver workflow", status: .partial),
                EvidenceGate(id: "RG-007", description: "Browser screen-reader workflow", status: .partial),
                EvidenceGate(id: "RG-051", description: "Accessibility labels", status: .pass),
                EvidenceGate(id: "RG-056", description: "Reduce Motion", status: .pass),
                EvidenceGate(id: "RG-057", description: "⌘F focus landing", status: .pass),
                EvidenceGate(id: "RG-058", description: "Reduce Motion gating", status: .pass),
                EvidenceGate(id: "RG-059", description: "Increased contrast", status: .pass),
            ],
            owner: "Accessibility Team", sequencePriority: 115,
            productClaim: "Surface implemented, observation pending", claimAccuracy: "Inferred"
        ))

        // ── EXPORT / VALIDATION ──

        matrix.upsert(CapabilityMatrixEntry(
            id: "cap-19-export-validation",
            capability: "Export Validation",
            scope: ProductScope(
                name: "Export Validation", userStatement: "Export PDF with validation",
                archetype: "Creator", jobID: "J03",
                claim: "No unrestricted fidelity claim", claimAccuracy: "Inferred"
            ),
            providers: [
                ProviderEntry(providerName: "PDFKit", lane: .native, support: .primary, license: "Apple"),
                ProviderEntry(providerName: "pdf-lib", lane: .browser, support: .supported, license: "MIT"),
            ],
            contracts: ["ValidationReport"],
            evidenceGates: [
                EvidenceGate(id: "RG-016", description: "Independent-viewer reopen", status: .partial),
                EvidenceGate(id: "RG-020", description: "Browser export fidelity", status: .partial),
            ],
            owner: "Core Team", sequencePriority: 95,
            productClaim: "No unrestricted fidelity claim", claimAccuracy: "Inferred"
        ))

        // ── PROVIDER SYSTEM ──

        matrix.upsert(CapabilityMatrixEntry(
            id: "cap-20-provider-admission",
            capability: "Provider Admission/Revocation",
            scope: ProductScope(
                name: "Provider Admission", userStatement: "Manage provider capabilities",
                archetype: "Power", jobID: "J17",
                claim: "Contract slice implemented", claimAccuracy: "Inferred"
            ),
            providers: [
                ProviderEntry(providerName: "Registry", lane: .native, support: .supported, license: "MIT"),
                ProviderEntry(providerName: "Registry", lane: .browser, support: .supported, license: "MIT"),
            ],
            contracts: ["pdf-editor.provider-capability-*"],
            evidenceGates: [
                EvidenceGate(id: "RG-072", description: "Provider registry", status: .pass),
                EvidenceGate(id: "RG-073", description: "License state", status: .pass),
                EvidenceGate(id: "RG-074", description: "Measurement binding", status: .pass),
            ],
            owner: "Core Team", sequencePriority: 5,
            productClaim: "Contract slice implemented", claimAccuracy: "Inferred"
        ))

        // ── READER FEATURES ──

        matrix.upsert(CapabilityMatrixEntry(
            id: "cap-21-undo-redo",
            capability: "Undo/Redo",
            scope: ProductScope(
                name: "Undo/Redo", userStatement: "Undo and redo edits",
                archetype: "Reader", jobID: "J04",
                claim: "Supported", claimAccuracy: "Verified"
            ),
            providers: [
                ProviderEntry(providerName: "InMemory", lane: .native, support: .primary, license: "MIT"),
            ],
            contracts: ["OperationLedger"],
            evidenceGates: [
                EvidenceGate(id: "RG-030", description: "Undo/recovery corpus", status: .partial),
            ],
            owner: "Core Team", sequencePriority: 25,
            productClaim: "Supported", claimAccuracy: "Verified"
        ))

        matrix.upsert(CapabilityMatrixEntry(
            id: "cap-22-progressive-rendering",
            capability: "Progressive Rendering",
            scope: ProductScope(
                name: "Progressive Rendering", userStatement: "See pages load progressively",
                archetype: "Reader", jobID: "J01",
                claim: "Implemented", claimAccuracy: "Verified"
            ),
            providers: [
                ProviderEntry(providerName: "PipelineRenderer", lane: .native, support: .primary, license: "MIT"),
            ],
            contracts: ["RenderingPipeline"],
            evidenceGates: [
                EvidenceGate(id: "RG-075", description: "Progressive render pipeline", status: .pass),
            ],
            owner: "Core Team", sequencePriority: 22,
            productClaim: "Implemented", claimAccuracy: "Verified"
        ))

        matrix.upsert(CapabilityMatrixEntry(
            id: "cap-23-reading-modes",
            capability: "Reading Modes",
            scope: ProductScope(
                name: "Reading Modes", userStatement: "Switch between Study/Skim/Reference/Review",
                archetype: "Reader", jobID: "J01",
                claim: "Implemented", claimAccuracy: "Verified"
            ),
            providers: [
                ProviderEntry(providerName: "SwiftUI", lane: .native, support: .primary, license: "Apple"),
            ],
            contracts: ["ReadingDisplayParams"],
            evidenceGates: [
                EvidenceGate(id: "RG-076", description: "Reading mode presets", status: .pass),
            ],
            owner: "Core Team", sequencePriority: 35,
            productClaim: "Implemented", claimAccuracy: "Verified"
        ))

        matrix.upsert(CapabilityMatrixEntry(
            id: "cap-24-dark-mode",
            capability: "Dark Mode",
            scope: ProductScope(
                name: "Dark Mode", userStatement: "Use dark theme",
                archetype: "Reader", jobID: "J01",
                claim: "Implemented", claimAccuracy: "Verified"
            ),
            providers: [
                ProviderEntry(providerName: "ThemeManager", lane: .native, support: .primary, license: "MIT"),
            ],
            contracts: ["ThemeManager"],
            evidenceGates: [
                EvidenceGate(id: "RG-077", description: "Dark mode support", status: .pass),
            ],
            owner: "Core Team", sequencePriority: 36,
            productClaim: "Implemented", claimAccuracy: "Verified"
        ))

        matrix.upsert(CapabilityMatrixEntry(
            id: "cap-25-freeze-panes",
            capability: "Freeze Panes",
            scope: ProductScope(
                name: "Freeze Panes", userStatement: "Pin header rows/columns",
                archetype: "Reader", jobID: "J01",
                claim: "Implemented", claimAccuracy: "Verified"
            ),
            providers: [
                ProviderEntry(providerName: "FreezePaneOverlayView", lane: .native, support: .primary, license: "MIT"),
            ],
            contracts: ["FreezePaneState"],
            evidenceGates: [
                EvidenceGate(id: "RG-078", description: "Freeze pane overlay", status: .pass),
            ],
            owner: "Core Team", sequencePriority: 37,
            productClaim: "Implemented", claimAccuracy: "Verified"
        ))

        matrix.upsert(CapabilityMatrixEntry(
            id: "cap-26-document-summarization",
            capability: "Document Summarization",
            scope: ProductScope(
                name: "Document Summarization", userStatement: "Get a summary of the document",
                archetype: "Reader", jobID: "J03",
                claim: "Implemented (rule-based)", claimAccuracy: "Verified"
            ),
            providers: [
                ProviderEntry(providerName: "DocumentSummarizer", lane: .native, support: .primary, license: "MIT"),
            ],
            contracts: ["UNDERSTAND layer"],
            evidenceGates: [
                EvidenceGate(id: "RG-079", description: "Summarization pipeline", status: .pass),
            ],
            owner: "Core Team", sequencePriority: 120,
            productClaim: "Implemented (rule-based)", claimAccuracy: "Verified"
        ))

        matrix.upsert(CapabilityMatrixEntry(
            id: "cap-27-entity-recognition",
            capability: "Entity Recognition",
            scope: ProductScope(
                name: "Entity Recognition", userStatement: "Extract entities from PDF",
                archetype: "Reader", jobID: "J03",
                claim: "Implemented (regex-based)", claimAccuracy: "Verified"
            ),
            providers: [
                ProviderEntry(providerName: "NERExtractor", lane: .native, support: .primary, license: "MIT"),
            ],
            contracts: ["UNDERSTAND layer"],
            evidenceGates: [
                EvidenceGate(id: "RG-080", description: "Entity extraction", status: .pass),
            ],
            owner: "Core Team", sequencePriority: 125,
            productClaim: "Implemented (regex-based)", claimAccuracy: "Verified"
        ))

        matrix.upsert(CapabilityMatrixEntry(
            id: "cap-28-table-extraction",
            capability: "Table Extraction",
            scope: ProductScope(
                name: "Table Extraction", userStatement: "Extract tables from PDF",
                archetype: "Reader", jobID: "J03",
                claim: "Implemented (layout-based)", claimAccuracy: "Verified"
            ),
            providers: [
                ProviderEntry(providerName: "TableExtractor", lane: .native, support: .primary, license: "MIT"),
            ],
            contracts: ["DetectedTable"],
            evidenceGates: [
                EvidenceGate(id: "RG-081", description: "Table detection", status: .pass),
            ],
            owner: "Core Team", sequencePriority: 130,
            productClaim: "Implemented (layout-based)", claimAccuracy: "Verified"
        ))

        matrix.upsert(CapabilityMatrixEntry(
            id: "cap-29-key-point-extraction",
            capability: "Key Point Extraction",
            scope: ProductScope(
                name: "Key Point Extraction", userStatement: "Extract key points from PDF",
                archetype: "Reader", jobID: "J03",
                claim: "Implemented (structure-based)", claimAccuracy: "Verified"
            ),
            providers: [
                ProviderEntry(providerName: "KeyPointExtractor", lane: .native, support: .primary, license: "MIT"),
            ],
            contracts: ["UNDERSTAND layer"],
            evidenceGates: [
                EvidenceGate(id: "RG-082", description: "Key point extraction", status: .pass),
            ],
            owner: "Core Team", sequencePriority: 135,
            productClaim: "Implemented (structure-based)", claimAccuracy: "Verified"
        ))

        // ── LEARN / ANNOTATE ──

        matrix.upsert(CapabilityMatrixEntry(
            id: "cap-30-spaced-repetition",
            capability: "Spaced Repetition",
            scope: ProductScope(
                name: "Spaced Repetition", userStatement: "Review marks with SM-2 scheduling",
                archetype: "Reader", jobID: "J03",
                claim: "Implemented", claimAccuracy: "Verified"
            ),
            providers: [
                ProviderEntry(providerName: "SM-2 Engine", lane: .native, support: .primary, license: "MIT"),
            ],
            contracts: ["SpacedRepetitionEngine"],
            evidenceGates: [
                EvidenceGate(id: "RG-083", description: "SM-2 algorithm", status: .pass),
            ],
            owner: "Core Team", sequencePriority: 140,
            productClaim: "Implemented", claimAccuracy: "Verified"
        ))

        matrix.upsert(CapabilityMatrixEntry(
            id: "cap-31-annotation-marks",
            capability: "Annotation Marks",
            scope: ProductScope(
                name: "Annotation Marks", userStatement: "Highlight, note, and underline text",
                archetype: "Reader", jobID: "J18",
                claim: "Implemented (sidecar)", claimAccuracy: "Verified"
            ),
            providers: [
                ProviderEntry(providerName: "AnnotationStore", lane: .native, support: .primary, license: "MIT"),
            ],
            contracts: ["AnnotationMark"],
            evidenceGates: [
                EvidenceGate(id: "RG-084", description: "Annotation creation", status: .pass),
                EvidenceGate(id: "RG-085", description: "Annotation persistence", status: .pass),
            ],
            owner: "Core Team", sequencePriority: 145,
            productClaim: "Implemented (sidecar)", claimAccuracy: "Verified"
        ))

        matrix.upsert(CapabilityMatrixEntry(
            id: "cap-32-collaboration",
            capability: "Collaboration",
            scope: ProductScope(
                name: "Collaboration", userStatement: "Share and merge annotations",
                archetype: "Reader", jobID: "J19",
                claim: "Implemented (file-level)", claimAccuracy: "Verified"
            ),
            providers: [
                ProviderEntry(providerName: "CollaborationManager", lane: .native, support: .primary, license: "MIT"),
            ],
            contracts: ["CollaborationPackage"],
            evidenceGates: [
                EvidenceGate(id: "RG-086", description: "Package export/import", status: .pass),
                EvidenceGate(id: "RG-087", description: "Merge conflict resolution", status: .pass),
            ],
            owner: "Core Team", sequencePriority: 150,
            productClaim: "Implemented (file-level)", claimAccuracy: "Verified"
        ))

        // ── MANAGER JOBS ──

        matrix.upsert(CapabilityMatrixEntry(
            id: "cap-33-document-index",
            capability: "Document Index",
            scope: ProductScope(
                name: "Document Index", userStatement: "Organize and search my PDF collection",
                archetype: "Manager", jobID: "J13",
                claim: "Engine implemented, no UI", claimAccuracy: "Verified"
            ),
            providers: [
                ProviderEntry(providerName: "DocumentIndex", lane: .native, support: .primary, license: "MIT"),
            ],
            contracts: ["DocumentIndexEntry"],
            evidenceGates: [
                EvidenceGate(id: "RG-088", description: "Index persistence", status: .pass),
                EvidenceGate(id: "RG-089", description: "Search latency", status: .open),
            ],
            owner: "Core Team", sequencePriority: 160,
            productClaim: "Engine implemented, no UI", claimAccuracy: "Verified"
        ))

        matrix.upsert(CapabilityMatrixEntry(
            id: "cap-34-version-control",
            capability: "Version Control",
            scope: ProductScope(
                name: "Version Control", userStatement: "Track and compare document versions",
                archetype: "Manager", jobID: "J14",
                claim: "Engine implemented, no persistence", claimAccuracy: "Verified"
            ),
            providers: [
                ProviderEntry(providerName: "VersionStore", lane: .native, support: .primary, license: "MIT"),
            ],
            contracts: ["VersionSnapshot", "VersionComparison"],
            evidenceGates: [
                EvidenceGate(id: "RG-090", description: "Version snapshots", status: .pass),
                EvidenceGate(id: "RG-091", description: "Persistent storage", status: .open),
                EvidenceGate(id: "RG-092", description: "Revert engine", status: .open),
            ],
            owner: "Core Team", sequencePriority: 165,
            productClaim: "Engine implemented, no persistence", claimAccuracy: "Verified"
        ))

        matrix.upsert(CapabilityMatrixEntry(
            id: "cap-35-governance",
            capability: "Governance",
            scope: ProductScope(
                name: "Governance", userStatement: "Enforce document policies",
                archetype: "Manager", jobID: "J12",
                claim: "Engine implemented, no UI", claimAccuracy: "Verified"
            ),
            providers: [
                ProviderEntry(providerName: "DocumentPolicy", lane: .native, support: .primary, license: "MIT"),
            ],
            contracts: ["PolicyRule", "PolicyViolation"],
            evidenceGates: [
                EvidenceGate(id: "RG-093", description: "Policy engine", status: .pass),
                EvidenceGate(id: "RG-094", description: "Governance dashboard", status: .open),
            ],
            owner: "Core Team", sequencePriority: 170,
            productClaim: "Engine implemented, no UI", claimAccuracy: "Verified"
        ))

        // ── POWER JOBS ──

        matrix.upsert(CapabilityMatrixEntry(
            id: "cap-36-batch-processing",
            capability: "Batch Processing",
            scope: ProductScope(
                name: "Batch Processing", userStatement: "Process multiple PDFs at once",
                archetype: "Power", jobID: "J15",
                claim: "Partial — merge exists, general runner pending", claimAccuracy: "Inferred"
            ),
            providers: [
                ProviderEntry(providerName: "PdfCpuBatchProcessor", lane: .native, support: .conditional, license: "AGPL-3.0", limitations: ["CLI wrapper"]),
                ProviderEntry(providerName: "BatchMergeSheet", lane: .native, support: .conditional, license: "MIT"),
            ],
            contracts: ["BatchReadJobType"],
            evidenceGates: [
                EvidenceGate(id: "RG-095", description: "Batch pipeline", status: .partial),
                EvidenceGate(id: "RG-096", description: "Per-item error isolation", status: .open),
            ],
            owner: "Core Team", sequencePriority: 180,
            productClaim: "Partial — merge exists, general runner pending", claimAccuracy: "Inferred"
        ))

        matrix.upsert(CapabilityMatrixEntry(
            id: "cap-37-companion-health",
            capability: "Companion Health",
            scope: ProductScope(
                name: "Companion Health", userStatement: "See provider status and connections",
                archetype: "Power", jobID: "J17",
                claim: "Implemented", claimAccuracy: "Verified"
            ),
            providers: [
                ProviderEntry(providerName: "CompanionHealthDashboard", lane: .native, support: .primary, license: "MIT"),
            ],
            contracts: ["CompanionHealthCheck"],
            evidenceGates: [
                EvidenceGate(id: "RG-097", description: "Health dashboard", status: .pass),
                EvidenceGate(id: "RG-098", description: "Transport layer", status: .partial),
            ],
            owner: "Core Team", sequencePriority: 175,
            productClaim: "Implemented", claimAccuracy: "Verified"
        ))

        // ── CALIBRATION / PRECISION ──

        matrix.upsert(CapabilityMatrixEntry(
            id: "cap-38-page-box-policy",
            capability: "Page Box Policy",
            scope: ProductScope(
                name: "Page Box Policy", userStatement: "Consistent page geometry across engines",
                archetype: "Reader", jobID: "J01",
                claim: "Implemented", claimAccuracy: "Verified"
            ),
            providers: [
                ProviderEntry(providerName: "PageBoxPolicy", lane: .native, support: .primary, license: "MIT"),
                ProviderEntry(providerName: "PageBoxPolicy", lane: .browser, support: .primary, license: "MIT"),
            ],
            contracts: ["PageBoxValues", "PageBoxComparison"],
            evidenceGates: [
                EvidenceGate(id: "RG-099", description: "Cross-system comparison", status: .pass),
                EvidenceGate(id: "RG-100", description: "Tolerance presets", status: .pass),
            ],
            owner: "Core Team", sequencePriority: 42,
            productClaim: "Implemented", claimAccuracy: "Verified"
        ))

        matrix.upsert(CapabilityMatrixEntry(
            id: "cap-39-recurring-form-calibration",
            capability: "Recurring Form Calibration",
            scope: ProductScope(
                name: "Recurring Form Calibration", userStatement: "Classify recurring forms automatically",
                archetype: "Reader", jobID: "J02",
                claim: "Implemented", claimAccuracy: "Verified"
            ),
            providers: [
                ProviderEntry(providerName: "RecurringFormCalibrator", lane: .native, support: .primary, license: "MIT"),
            ],
            contracts: ["MatchingTier", "CalibrationReport"],
            evidenceGates: [
                EvidenceGate(id: "RG-101", description: "5-tier classification", status: .pass),
                EvidenceGate(id: "RG-102", description: "Hard negative detection", status: .pass),
            ],
            owner: "Core Team", sequencePriority: 43,
            productClaim: "Implemented", claimAccuracy: "Verified"
        ))

        matrix.upsert(CapabilityMatrixEntry(
            id: "cap-40-accepted-variance",
            capability: "Accepted Variance Registry",
            scope: ProductScope(
                name: "Accepted Variance Registry", userStatement: "Track native/web mismatches with tolerances",
                archetype: "Power", jobID: "J17",
                claim: "Implemented", claimAccuracy: "Verified"
            ),
            providers: [
                ProviderEntry(providerName: "AcceptedVarianceRegistry", lane: .shared, support: .primary, license: "MIT"),
            ],
            contracts: ["AcceptedVariance", "VarianceCheckResult"],
            evidenceGates: [
                EvidenceGate(id: "RG-103", description: "Variance classification", status: .pass),
                EvidenceGate(id: "RG-104", description: "Falsifying test linkage", status: .pass),
            ],
            owner: "Core Team", sequencePriority: 44,
            productClaim: "Implemented", claimAccuracy: "Verified"
        ))

        // ── CREATOR ──

        matrix.upsert(CapabilityMatrixEntry(
            id: "cap-41-creator-canvas",
            capability: "Creator Canvas",
            scope: ProductScope(
                name: "Creator Canvas", userStatement: "Create documents from scratch",
                archetype: "Creator", jobID: "J01",
                claim: "Implemented", claimAccuracy: "Verified"
            ),
            providers: [
                ProviderEntry(providerName: "AuthoringCanvasView", lane: .native, support: .primary, license: "MIT"),
            ],
            contracts: ["ContentAuthor", "DocumentElement"],
            evidenceGates: [
                EvidenceGate(id: "RG-105", description: "Canvas rendering", status: .pass),
                EvidenceGate(id: "RG-106", description: "Element manipulation", status: .pass),
            ],
            owner: "Core Team", sequencePriority: 190,
            productClaim: "Implemented", claimAccuracy: "Verified"
        ))

        matrix.upsert(CapabilityMatrixEntry(
            id: "cap-42-design-system",
            capability: "Design System",
            scope: ProductScope(
                name: "Design System", userStatement: "Use grids, styles, and templates",
                archetype: "Creator", jobID: "J02",
                claim: "Implemented", claimAccuracy: "Verified"
            ),
            providers: [
                ProviderEntry(providerName: "DesignSystem", lane: .native, support: .primary, license: "MIT"),
            ],
            contracts: ["GridConfig", "PageLayout", "ParagraphStyle"],
            evidenceGates: [
                EvidenceGate(id: "RG-107", description: "Grid snapping", status: .pass),
                EvidenceGate(id: "RG-108", description: "Style presets", status: .pass),
            ],
            owner: "Core Team", sequencePriority: 195,
            productClaim: "Implemented", claimAccuracy: "Verified"
        ))

        return matrix
    }
}
