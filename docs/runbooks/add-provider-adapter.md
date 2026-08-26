# Runbook: Add a Provider Adapter

**When:** You need to support a new PDF engine (PDFBox, MuPDF, Vision OCR, Tesseract, etc.).
**Time:** 1-2 weeks for a full adapter; days for a partial/read-only adapter.

## Prerequisites

- The provider must be licensable for your distribution model
- You need a test fixture corpus to validate fidelity
- You need an independent viewer for oracle checks (Poppler, qpdf, MuPDF)

## Steps

### 1. Register the provider

In `Sources/PDFEditorCore/ProviderCapabilityLaneContracts.swift` and `web/pdf-capability-lanes.mjs`:

```swift
case pdfbox  // or .mupdf, .visionOCR, etc.
```

Set initial state to `.unknown` or `.blocked` with evidence requirements.

### 2. Implement the adapter protocol

Create `Sources/PDFEditorCore/YourProviderAdapter.swift`:

```swift
struct YourProviderAdapter: PDFProviderAdapter {
  func inspect(url: URL) throws -> DocumentInspection { ... }
  func export(url: URL, operations: [EditOperation], to: URL) throws -> ExportReport { ... }
  func validate(output: URL, against source: URL) throws -> ValidationReport { ... }
}
```

The adapter translates between the provider's object model and the shared contracts.

### 3. Wire into the provider registry

In the provider admission system, add:
- License state check (reject if AGPL and you're not compliant)
- Source limits (max pages, max bytes, encryption support)
- Capability mapping (which operations the provider supports)

### 4. Run the full corpus

```bash
# Run all fixtures through the new provider
for pdf in benchmark/results/corpus-sweep-2026-08-25/*.pdf; do
  echo "Testing: $pdf"
  # Run your adapter's inspect + export + validate
done
```

### 5. Compare with existing providers

Run the parity tests to ensure the new provider produces equivalent results:
```bash
node Tests/pdf_contract_parity_mutation_test.mjs
node Tests/native_browser_semantic_parity_report_test.mjs
```

### 6. Update gates

- RG-091 (provider admission): add the new provider
- RG-016 (independent-viewer reopen): add the new provider as an oracle
- Any capability-specific gates (RG-008 for OCR, RG-014 for signatures, etc.)

### 7. Evidence requirements

Before activating the provider:
- [ ] License compliance verified
- [ ] Source digest binding works
- [ ] All operation kinds either pass or explicitly abstain
- [ ] Independent viewer confirms output
- [ ] No external network requests (local-only invariant)
- [ ] Failure modes documented (malformed, encrypted, large)
