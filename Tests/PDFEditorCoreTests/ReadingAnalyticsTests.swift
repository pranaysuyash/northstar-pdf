import Foundation
import Testing
@testable import PDFEditorCore

@Suite("R-17 ReadingAnalytics")
struct ReadingAnalyticsTests {
    @Test("Start and end session")
    @MainActor
    func sessionLifecycle() {
        let analytics = ReadingAnalytics()
        analytics.startSession(documentID: "doc1", startPage: 0)
        #expect(analytics.currentSession != nil)
        analytics.endSession()
        #expect(analytics.currentSession == nil)
        #expect(analytics.sessions.count == 1)
    }

    @Test("Record page visit")
    @MainActor
    func pageVisit() {
        let analytics = ReadingAnalytics()
        analytics.startSession(documentID: "doc1", startPage: 0)
        analytics.recordPageVisit(5)
        analytics.recordPageVisit(5)
        #expect(analytics.pageData[5]?.visitCount == 2)
    }

    @Test("Record time spent")
    @MainActor
    func timeSpent() {
        let analytics = ReadingAnalytics()
        analytics.recordTimeSpent(30.0, onPage: 0)
        analytics.recordTimeSpent(15.0, onPage: 0)
        #expect(analytics.pageData[0]?.timeSpentSeconds == 45.0)
    }

    @Test("Statistics computation")
    @MainActor
    func statistics() {
        let analytics = ReadingAnalytics()
        analytics.recordPageVisit(0)
        analytics.recordTimeSpent(10.0, onPage: 0)
        analytics.recordPageVisit(1)
        analytics.recordTimeSpent(20.0, onPage: 1)
        analytics.recordPageVisit(2)
        analytics.recordTimeSpent(5.0, onPage: 2)
        let stats = analytics.statistics
        #expect(stats.uniquePagesRead == 3)
        #expect(stats.totalTimeSeconds == 35.0)
        #expect(stats.topPages.first?.pageIndex == 1)
    }

    @Test("Multiple sessions tracked")
    @MainActor
    func multipleSessions() {
        let analytics = ReadingAnalytics()
        analytics.startSession(documentID: "doc1", startPage: 0)
        analytics.endSession()
        analytics.startSession(documentID: "doc1", startPage: 5)
        analytics.endSession()
        #expect(analytics.sessions.count == 2)
        #expect(analytics.statistics.sessionCount == 2)
    }
}
