# Runbook: Add a New Operation Kind

**When:** You need a new type of PDF edit (e.g., image placement, form flattening, annotation deletion).
**Time:** 2-4 hours for a bounded operation; days for a complex one requiring provider work.

## Steps

### 1. Define the operation type

In `Sources/PDFEditorCore/SharedContracts.swift`, add a new case to the `EditOperation.Kind` enum:

```swift
case yourNewOperation  // e.g., .imagePlacement, .formFlatten
```

Update the `EditOperation` struct if the new kind needs additional fields (e.g., image data, flatten options).

### 2. Implement the provider adapter

**Native (PDFKit):**
- In `Sources/PDFEditorCore/PDFKitProvider.swift`, add handling in `export(url:operations:to:)`
- If the operation is source-preserving, use the incremental writer pattern
- If it requires full rewrite, use PDFKit's save API with validation

**Browser (pdf-lib):**
- In `web/pdf-contract-mutation-gate.mjs`, add the operation to the mutation gate
- In `web/pdf-incremental-form-writer.mjs` or the pdf-lib writer, implement the write
- Ensure source-prefix bytes are preserved for incremental operations

### 3. Write tests

**S1 (basic pass):**
```swift
@Test func yourNewOperationPassesBasic() throws {
  // Create fixture, apply operation, verify result
}
```

**S3 (mutation kill):**
```swift
@Test func yourNewOperationGuardKillsTampering() throws {
  // Prove the guard rejects invalid inputs
}
```

### 4. Update gate evidence

In `docs/release-gates.md`, update the relevant gate row with:
- What was delivered
- What evidence exists
- What remains open

### 5. Update documentation

- Add the operation to `docs/architecture.md` data flow section
- Add to `docs/capability-matrix.md` if it's a new capability
- Append to `progress.md` with evidence tier

### 6. Verify

```bash
swift test
node Tests/web_reader_contract_test.mjs
node Tests/pdf_contract_parity_mutation_test.mjs
```

## Common pitfalls

- **Forgetting the browser adapter** — every native operation needs a browser equivalent or an explicit `unsupported` state
- **Not updating the mutation gate** — the browser gate must reject unknown operations
- **Missing source-prefix preservation** — incremental operations must keep original bytes as prefix
- **No validation after export** — every export must be reopenable and validated
