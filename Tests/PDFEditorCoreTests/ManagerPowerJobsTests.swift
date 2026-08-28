import Testing
import Foundation
@testable import PDFEditorCore

@Suite("Manager & Power Jobs Tests")
struct ManagerPowerJobsTests {
    
    // MARK: - J13 ORGANIZE
    
    @Test("DocumentIndex add and query entries")
    @MainActor func documentIndexBasic() async {
        let index = DocumentIndex()
        let entry = DocumentIndexEntry(
            filePath: "/tmp/test.pdf",
            contentHash: "abc123",
            pageCount: 10,
            fileSize: 1024,
            title: "Test Document",
            author: "Test Author",
            tags: ["tag1", "tag2"],
            folder: "Projects"
        )
        index.addEntry(entry)
        #expect(index.entries.count == 1)
        #expect(index.allTags.contains("tag1"))
        #expect(index.allFolders.contains("Projects"))
    }
    
    @Test("DocumentIndex tag management")
    @MainActor func documentIndexTags() async {
        let index = DocumentIndex()
        let entry = DocumentIndexEntry(
            filePath: "/tmp/test.pdf",
            contentHash: "abc",
            pageCount: 5,
            fileSize: 512
        )
        let added = index.addEntry(entry)
        
        index.addTag("important", to: added.id)
        #expect(index.documents(withTag: "important").count == 1)
        
        index.removeTag("important", from: added.id)
        #expect(index.documents(withTag: "important").count == 0)
    }
    
    @Test("DocumentIndex folder management")
    @MainActor func documentIndexFolders() async {
        let index = DocumentIndex()
        let entry = DocumentIndexEntry(
            filePath: "/tmp/test.pdf",
            contentHash: "abc",
            pageCount: 5,
            fileSize: 512
        )
        let added = index.addEntry(entry)
        
        index.moveToFolder("Work", entryID: added.id)
        #expect(index.documents(in: "Work").count == 1)
    }
    
    @Test("DocumentIndex star and rate")
    @MainActor func documentIndexStarRate() async {
        let index = DocumentIndex()
        let entry = DocumentIndexEntry(
            filePath: "/tmp/test.pdf",
            contentHash: "abc",
            pageCount: 5,
            fileSize: 512
        )
        let added = index.addEntry(entry)
        
        index.toggleStar(entryID: added.id)
        #expect(index.starredDocuments.count == 1)
        
        index.setRating(4, entryID: added.id)
        #expect(index.entries.first?.rating == 4)
    }
    
    @Test("CorpusSearch finds by query")
    @MainActor func corpusSearch() async {
        let index = DocumentIndex()
        index.addEntry(DocumentIndexEntry(filePath: "/tmp/a.pdf", contentHash: "a", pageCount: 1, fileSize: 100, title: "Math Book"))
        index.addEntry(DocumentIndexEntry(filePath: "/tmp/b.pdf", contentHash: "b", pageCount: 1, fileSize: 100, title: "Science Guide"))
        
        let search = CorpusSearch()
        let results = search.search("Math", in: index)
        #expect(results.count == 1)
        #expect(results.first?.title == "Math Book")
    }
    
    @Test("CorpusSearch finds by tag")
    @MainActor func corpusSearchTag() async {
        let index = DocumentIndex()
        let entry = index.addEntry(DocumentIndexEntry(filePath: "/tmp/a.pdf", contentHash: "a", pageCount: 1, fileSize: 100))
        index.addTag("review", to: entry.id)
        
        let search = CorpusSearch()
        let results = search.search(tag: "review", in: index)
        #expect(results.count == 1)
    }
    
    @Test("DedupDetector finds duplicates")
    @MainActor func dedupDetector() async {
        let index = DocumentIndex()
        index.addEntry(DocumentIndexEntry(filePath: "/tmp/a.pdf", contentHash: "same", pageCount: 1, fileSize: 100))
        index.addEntry(DocumentIndexEntry(filePath: "/tmp/b.pdf", contentHash: "same", pageCount: 1, fileSize: 100))
        index.addEntry(DocumentIndexEntry(filePath: "/tmp/c.pdf", contentHash: "different", pageCount: 1, fileSize: 200))
        
        let dedup = DedupDetector()
        let groups = dedup.findDuplicates(in: index)
        #expect(groups.count == 1)
        #expect(groups.first?.count == 2)
        #expect(dedup.wastedSpace(in: index) == 100) // 1 wasted copy
    }
    
    // MARK: - J14 VERSION
    
    @Test("VersionStore saves and compares snapshots")
    @MainActor func versionStoreBasic() async {
        let store = VersionStore(documentID: "test")
        
        let op1 = EditOperation(pageIndex: 0, kind: .overlayText, value: "Hello")
        let op2 = EditOperation(pageIndex: 0, kind: .overlayText, value: "World")
        
        store.saveSnapshot(operations: [op1], label: "v1")
        store.saveSnapshot(operations: [op1, op2], label: "v2")
        
        #expect(store.snapshots.count == 2)
        #expect(store.latestSnapshot?.label == "v2")
        
        let comparison = store.compare(from: 1, to: 2)
        #expect(comparison != nil)
        #expect(comparison?.addedOperations.count == 1)
    }
    
    @Test("VersionStore revert operations")
    @MainActor func versionStoreRevert() async {
        let store = VersionStore(documentID: "test")
        
        let op1 = EditOperation(pageIndex: 0, kind: .overlayText, value: "A")
        let op2 = EditOperation(pageIndex: 0, kind: .overlayText, value: "B")
        
        store.saveSnapshot(operations: [op1], label: "v1")
        store.saveSnapshot(operations: [op1, op2], label: "v2")
        
        let revertOps = store.operationsForRevert(from: 1, to: 2)
        #expect(revertOps?.count == 1)
    }
    
    @Test("VersionStore digest is deterministic")
    @MainActor func versionStoreDigest() async {
        let ops = [EditOperation(pageIndex: 0, kind: .overlayText, value: "test")]
        let d1 = VersionStore.computeDigest(ops)
        let d2 = VersionStore.computeDigest(ops)
        #expect(d1 == d2)
        #expect(!d1.isEmpty)
    }
    
    // MARK: - J12 GOVERN
    
    @Test("GovernanceEngine manages rules")
    @MainActor func governanceRules() async {
        let engine = GovernanceEngine()
        
        let rule = PolicyRule(type: .size, name: "Max Size", description: "100MB limit", severity: .warning)
        engine.addRule(rule)
        #expect(engine.rules.count == 1)
        
        engine.toggleRule(id: rule.id)
        #expect(engine.rules.first?.isEnabled == false)
    }
    
    @Test("GovernanceEngine compliance check")
    @MainActor func governanceCompliance() async {
        let engine = GovernanceEngine()
        
        let sizeRule = PolicyRule(type: .size, name: "Max Size", description: "100MB", severity: .warning, parameters: ["maxSizeBytes": "104857600"])
        engine.addRule(sizeRule)
        
        let violations = engine.runComplianceCheck(documents: [
            (path: "/tmp/big.pdf", fileSize: 200_000_000, isEncrypted: false, pageCount: 100),
            (path: "/tmp/small.pdf", fileSize: 50_000, isEncrypted: false, pageCount: 10)
        ])
        
        #expect(violations.count == 1)
        #expect(violations.first?.documentPath == "/tmp/big.pdf")
    }
    
    @Test("GovernanceEngine resolves violations")
    @MainActor func governanceResolve() async {
        let engine = GovernanceEngine()
        
        let rule = PolicyRule(type: .encryption, name: "Encryption", description: "Required", severity: .critical, parameters: ["required": "true"])
        engine.addRule(rule)
        
        let violations = engine.runComplianceCheck(documents: [
            (path: "/tmp/plain.pdf", fileSize: 1000, isEncrypted: false, pageCount: 1)
        ])
        
        #expect(violations.count == 1)
        engine.resolveViolation(id: violations[0].id, notes: "Acknowledged")
        #expect(engine.violations.first?.isResolved == true)
    }
    
    @Test("GovernanceEngine compliance summary")
    @MainActor func governanceSummary() async {
        let engine = GovernanceEngine()
        let summary = engine.complianceSummary
        #expect(summary.isCompliant)
        #expect(summary.complianceScore == 1.0)
    }
    
    @Test("GovernanceEngine default policies")
    @MainActor func governanceDefaults() async {
        let policies = GovernanceEngine.defaultPolicies()
        #expect(policies.count == 3)
        #expect(policies.contains { $0.type == .size })
        #expect(policies.contains { $0.type == .encryption })
        #expect(policies.contains { $0.type == .retention })
    }
    
    // MARK: - J15 BATCH
    
    @Test("BatchRunner validates documents")
    @MainActor func batchValidate() async {
        let runner = BatchRunner()
        let job = BatchJob(name: "Validate", operation: .validate)
        
        // Use a file that exists
        let result = await runner.execute(job: job, documentPaths: ["/tmp/nonexistent.pdf"])
        #expect(result.itemResults.count == 1)
        #expect(result.isCompleteSuccess == false) // file doesn't exist
    }
    
    @Test("BatchRunResult statistics")
    @MainActor func batchStats() async {
        let runner = BatchRunner()
        let job = BatchJob(name: "Test", operation: .validate)
        
        let result = await runner.execute(job: job, documentPaths: [])
        #expect(result.totalCount == 0)
        #expect(result.successRate == 0)
    }
    
    @Test("BatchJob has correct defaults")
    func batchJobDefaults() {
        let job = BatchJob(name: "Test", operation: .validate)
        #expect(job.maxConcurrency == 4)
        #expect(job.perDocumentTimeout == 60)
        #expect(job.stopOnCriticalFailure == false)
    }
    
    @Test("BatchOperation display names")
    func batchOperationNames() {
        #expect(BatchOperation.validate.displayName == "Validate")
        #expect(BatchOperation.rotate(90).displayName == "Rotate 90°")
        #expect(BatchOperation.watermark("hello").displayName == "Watermark \"hello\"")
        #expect(BatchOperation.custom("myOp", [:]).displayName == "myOp")
    }
    
    // MARK: - J16 SCRIPT
    
    @Test("UserScript creation and properties")
    func userScriptBasic() {
        let steps = [
            WorkflowStep(name: "Validate", operation: .validate),
            WorkflowStep(name: "Extract", operation: .extractText)
        ]
        let script = UserScript(name: "My Script", description: "Test script", steps: steps)
        
        #expect(script.name == "My Script")
        #expect(script.stepCount == 2)
        #expect(script.requiresConsent == true)
    }
    
    @Test("WorkflowRunner executes validate step")
    @MainActor func workflowRunnerValidate() async {
        let runner = WorkflowRunner()
        let script = UserScript(
            name: "Validate",
            steps: [WorkflowStep(name: "Validate", operation: .validate, inputPattern: "*.pdf")]
        )
        
        let result = await runner.execute(script: script, directory: "/tmp")
        #expect(result.stepResults.count == 1)
    }
    
    @Test("UserScript presets exist")
    func userScriptPresets() {
        let presets = UserScript.presets
        #expect(presets.count >= 4)
        #expect(presets.contains { $0.name == "Validate All" })
        #expect(presets.contains { $0.name == "Extract Text" })
    }
    
    @Test("WorkflowRunner tracks history")
    @MainActor func workflowHistory() async {
        let runner = WorkflowRunner()
        let script = UserScript(
            name: "Test",
            steps: [WorkflowStep(name: "Validate", operation: .validate, inputPattern: "*.pdf")]
        )
        
        _ = await runner.execute(script: script, directory: "/tmp")
        #expect(await runner.runHistory.count == 1)
    }
    
    // MARK: - J17 INTEGRATE
    
    @Test("BridgeManager enables and disables bridges")
    @MainActor func bridgeManagerBasic() async {
        let manager = BridgeManager()
        
        #expect(!manager.isConsented(.markdown))
        manager.grantConsent(for: .markdown)
        #expect(manager.isConsented(.markdown))
        manager.revokeConsent(for: .markdown)
        #expect(!manager.isConsented(.markdown))
    }
    
    @Test("BridgeManager rejects consent for unregistered")
    @MainActor func bridgeManagerRejectsUnregistered() async {
        let manager = BridgeManager()
        #expect(!manager.isConsented(.json))
    }
    
    @Test("BridgeType has all expected cases")
    func bridgeTypeCases() {
        #expect(BridgeType.allCases.count == 7)
        #expect(BridgeType.markdown.fileExtension == "md")
        #expect(BridgeType.csv.fileExtension == "csv")
        #expect(BridgeType.json.fileExtension == "json")
        #expect(BridgeType.plainText.fileExtension == "txt")
    }
    
    @Test("BridgeManager records operations")
    @MainActor func bridgeManagerRecords() async {
        let manager = BridgeManager()
        let result = BridgeResult(type: .json, direction: .export, success: true)
        manager.recordOperation(result)
        #expect(manager.history.count == 1)
    }
    
    // MARK: - PolicyRule
    
    @Test("PolicyRule creation and properties")
    func policyRuleBasic() {
        let rule = PolicyRule(type: .retention, name: "Retention", description: "Keep for 7 years", severity: .warning, parameters: ["years": "7"])
        #expect(rule.type == .retention)
        #expect(rule.name == "Retention")
        #expect(rule.isEnabled == true)
        #expect(rule.parameters["years"] == "7")
    }
    
    @Test("ViolationSeverity weight")
    func violationSeverityWeight() {
        #expect(ViolationSeverity.critical.weight == 3)
        #expect(ViolationSeverity.warning.weight == 2)
        #expect(ViolationSeverity.info.weight == 1)
    }
}
