import Foundation
import Testing
@testable import PDFEditorCore

@Suite("R-09 BatchReadProcessor")
struct BatchReadProcessorTests {
    @Test("Batch process with no files produces empty report")
    func emptyBatch() {
        let processor = BatchReadProcessor()
        let report = processor.process(files: [], jobType: .extractText)
        #expect(report.totalItems == 0)
        #expect(report.successCount == 0)
        #expect(report.successRate == 0)
    }

    @Test("Batch process with nonexistent file reports failure")
    func nonexistentFile() {
        let processor = BatchReadProcessor()
        let fakeURL = URL(fileURLWithPath: "/tmp/nonexistent-\(UUID()).pdf")
        let report = processor.process(files: [fakeURL], jobType: .extractText)
        #expect(report.totalItems == 1)
        #expect(report.failureCount == 1)
        #expect(report.results.first?.success == false)
    }

    @Test("Batch job report has correct structure")
    func reportStructure() {
        let processor = BatchReadProcessor()
        let report = processor.process(files: [], jobType: .summarize)
        #expect(report.jobType == .summarize)
        #expect(report.totalTimeSeconds >= 0)
    }

    @Test("All job types are representable")
    func jobTypes() {
        for jobType in BatchReadJobType.allCases {
            #expect(!jobType.displayName.isEmpty)
            #expect(!jobType.rawValue.isEmpty)
        }
    }
}
