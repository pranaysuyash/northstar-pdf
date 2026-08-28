import Testing
import Foundation
@testable import PDFEditorCore

@Suite("Collaboration Approval Tests")
struct CollaborationApprovalTests {
    
    // MARK: - Approval Request
    
    @Test("Approval request creation")
    func requestCreation() {
        let request = ApprovalRequest(
            requester: "Alice",
            documentName: "report.pdf",
            requiredApprovers: ["Bob", "Carol"],
            notes: "Please review by Friday"
        )
        #expect(request.requester == "Alice")
        #expect(request.documentName == "report.pdf")
        #expect(request.requiredApprovers.count == 2)
        #expect(request.status == .pending)
        #expect(request.records.isEmpty)
        #expect(request.isFullyApproved == false)
        #expect(request.isRejected == false)
    }
    
    @Test("Approval request full approval")
    func requestFullApproval() {
        var request = ApprovalRequest(
            requester: "Alice",
            documentName: "report.pdf",
            requiredApprovers: ["Bob", "Carol"]
        )
        
        let record1 = ApprovalRecord(approver: "Bob", status: .approved, reason: "Looks good", documentName: "report.pdf")
        let record2 = ApprovalRecord(approver: "Carol", status: .approved, reason: "Approved", documentName: "report.pdf")
        
        request.addRecord(record1)
        #expect(request.isFullyApproved == false)
        #expect(request.status == .pending)
        
        request.addRecord(record2)
        #expect(request.isFullyApproved == true)
        #expect(request.status == .approved)
    }
    
    @Test("Approval request rejection")
    func requestRejection() {
        var request = ApprovalRequest(
            requester: "Alice",
            documentName: "report.pdf",
            requiredApprovers: ["Bob", "Carol"]
        )
        
        let record = ApprovalRecord(approver: "Bob", status: .rejected, reason: "Needs changes", documentName: "report.pdf")
        request.addRecord(record)
        
        #expect(request.isRejected == true)
        #expect(request.status == .rejected)
    }
    
    @Test("Approval request pending approvers")
    func requestPendingApprovers() {
        var request = ApprovalRequest(
            requester: "Alice",
            documentName: "report.pdf",
            requiredApprovers: ["Bob", "Carol", "Dave"]
        )
        
        let record = ApprovalRecord(approver: "Bob", status: .approved, documentName: "report.pdf")
        request.addRecord(record)
        
        #expect(request.pendingApprovers == ["Carol", "Dave"])
        #expect(request.completionRate == 1.0 / 3.0)
    }
    
    @Test("Approval request deadline expiry")
    func requestDeadlineExpiry() {
        var request = ApprovalRequest(
            requester: "Alice",
            documentName: "report.pdf",
            requiredApprovers: ["Bob"],
            deadline: Date().addingTimeInterval(-3600) // 1 hour ago
        )
        
        #expect(request.isExpired == true)
    }
    
    @Test("Approval request without deadline never expires")
    func requestNoDeadline() {
        let request = ApprovalRequest(
            requester: "Alice",
            documentName: "report.pdf",
            requiredApprovers: ["Bob"]
        )
        
        #expect(request.isExpired == false)
    }
    
    // MARK: - Approval Workflow
    
    @MainActor
    @Test("Workflow creates and records decisions")
    func workflowBasic() async {
        let workflow = ApprovalWorkflow()
        workflow.clearAll()
        
        let request = workflow.createRequest(
            requester: "Alice",
            documentName: "report.pdf",
            requiredApprovers: ["Bob"]
        )
        
        #expect(workflow.requests.count == 1)
        #expect(workflow.pendingRequests.count == 1)
        
        workflow.recordDecision(
            requestID: request.id,
            approver: "Bob",
            status: .approved,
            reason: "LGTM"
        )
        
        #expect(workflow.pendingRequests.count == 0)
        #expect(workflow.approvedRequests.count == 1)
        #expect(workflow.decisionHistory.count == 1)
    }
    
    @MainActor
    @Test("Workflow queries by approver")
    func workflowQueryByApprover() async {
        let workflow = ApprovalWorkflow()
        workflow.clearAll()
        
        let r1 = workflow.createRequest(requester: "Alice", documentName: "a.pdf", requiredApprovers: ["Bob"])
        let r2 = workflow.createRequest(requester: "Alice", documentName: "b.pdf", requiredApprovers: ["Carol"])
        let r3 = workflow.createRequest(requester: "Alice", documentName: "c.pdf", requiredApprovers: ["Bob", "Carol"])
        
        let bobRequests = workflow.requests(forApprover: "Bob")
        #expect(bobRequests.count == 2)
    }
    
    @MainActor
    @Test("Workflow summary aggregates correctly")
    func workflowSummary() async {
        let workflow = ApprovalWorkflow()
        workflow.clearAll()
        
        let r1 = workflow.createRequest(requester: "Alice", documentName: "a.pdf", requiredApprovers: ["Bob"])
        workflow.recordDecision(requestID: r1.id, approver: "Bob", status: .approved)
        
        _ = workflow.createRequest(requester: "Alice", documentName: "b.pdf", requiredApprovers: ["Carol"])
        
        let summary = workflow.summary
        #expect(summary.totalRequests == 2)
        #expect(summary.approvedCount == 1)
        #expect(summary.pendingCount == 1)
    }
    
    // MARK: - Approval Record
    
    @Test("Approval record has correct properties")
    func recordProperties() {
        let record = ApprovalRecord(
            approver: "Bob",
            status: .approved,
            reason: "Looks good",
            documentName: "report.pdf",
            versionNumber: 3
        )
        
        #expect(record.approver == "Bob")
        #expect(record.status == .approved)
        #expect(record.reason == "Looks good")
        #expect(record.documentName == "report.pdf")
        #expect(record.versionNumber == 3)
    }
    
    // MARK: - Approval Status
    
    @Test("Approval status display names")
    func statusDisplayNames() {
        #expect(ApprovalStatus.pending.displayName == "Pending")
        #expect(ApprovalStatus.approved.displayName == "Approved")
        #expect(ApprovalStatus.rejected.displayName == "Rejected")
        #expect(ApprovalStatus.withdrawn.displayName == "Withdrawn")
        #expect(ApprovalStatus.expired.displayName == "Expired")
    }
}

// MARK: - Multi-Package Merge Tests

@Suite("Multi-Package Merge Tests")
struct MultiPackageMergerTests {
    
    @Test("Multi-package merge combines marks")
    func multiPackageMerge() {
        let localMarks = [
            AnnotationMark(type: .highlight, pageIndex: 0, bounds: PDFRect(x: 0, y: 0, width: 100, height: 20), selectedText: "Local text")
        ]
        let partner1Marks = [
            AnnotationMark(type: .note, pageIndex: 0, bounds: PDFRect(x: 50, y: 50, width: 100, height: 20), note: "Partner 1 note")
        ]
        let partner2Marks = [
            AnnotationMark(type: .note, pageIndex: 1, bounds: PDFRect(x: 0, y: 0, width: 100, height: 20), note: "Partner 2 note")
        ]
        
        let result = MultiPackageMerger.merge(
            localMarks: localMarks,
            packages: [
                (packageID: UUID(), partnerMarks: partner1Marks),
                (packageID: UUID(), partnerMarks: partner2Marks)
            ]
        )
        
        #expect(result.packageResults.count == 2)
        #expect(result.totalAdded == 2)
        #expect(result.finalMarks.count == 3) // 1 local + 2 partner
    }
    
    @Test("Multi-package merge with conflicts")
    func multiPackageMergeConflicts() {
        let localMarks = [
            AnnotationMark(type: .highlight, pageIndex: 0, bounds: PDFRect(x: 10, y: 10, width: 100, height: 20), selectedText: "Same text")
        ]
        let partnerMarks = [
            AnnotationMark(type: .highlight, pageIndex: 0, bounds: PDFRect(x: 10, y: 10, width: 100, height: 20), selectedText: "Different text")
        ]
        
        let result = MultiPackageMerger.merge(
            localMarks: localMarks,
            packages: [
                (packageID: UUID(), partnerMarks: partnerMarks)
            ]
        )
        
        #expect(result.totalConflicts.count == 1)
    }
    
    @Test("Multi-package merge with defaults resolves automatically")
    func multiPackageMergeDefaults() {
        let localMarks = [
            AnnotationMark(type: .highlight, pageIndex: 0, bounds: PDFRect(x: 0, y: 0, width: 100, height: 20), selectedText: "Local")
        ]
        let partnerMarks = [
            AnnotationMark(type: .highlight, pageIndex: 0, bounds: PDFRect(x: 0, y: 0, width: 100, height: 20), selectedText: "Partner")
        ]
        
        let finalMarks = MultiPackageMerger.mergeWithDefaults(
            localMarks: localMarks,
            packages: [(packageID: UUID(), partnerMarks: partnerMarks)],
            defaultResolution: .keepBoth
        )
        
        #expect(finalMarks.count == 2) // Both kept
    }
    
    @Test("Multi-package merge complexity analysis")
    func mergeComplexity() {
        let localMarks = [
            AnnotationMark(type: .highlight, pageIndex: 0, bounds: PDFRect(x: 0, y: 0, width: 100, height: 20), selectedText: "text")
        ]
        let partnerMarks = [
            AnnotationMark(type: .highlight, pageIndex: 0, bounds: PDFRect(x: 0, y: 0, width: 100, height: 20), selectedText: "text2")
        ]
        
        let complexity = MultiPackageMerger.analyzeComplexity(
            localMarks: localMarks,
            packages: [(packageID: UUID(), partnerMarks: partnerMarks)]
        )
        
        #expect(complexity.packageCount == 1)
        #expect(complexity.level == .simple || complexity.level == .trivial || complexity.level == .moderate)
    }
    
    @Test("Complexity levels have correct display names")
    func complexityLevels() {
        #expect(ComplexityLevel.trivial.displayName == "Trivial")
        #expect(ComplexityLevel.simple.displayName == "Simple")
        #expect(ComplexityLevel.moderate.displayName == "Moderate")
        #expect(ComplexityLevel.complex.displayName == "Complex")
    }
}
