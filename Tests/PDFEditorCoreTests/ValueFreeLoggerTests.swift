import Foundation
import Testing
@testable import PDFEditorCore

@Suite("R-02 ValueFreeLogger")
struct ValueFreeLoggerTests {
    @Test("Logger emits entries at correct minimum level")
    func minimumLevel() async {
        let logger = ValueFreeLogger()
        await logger.setMinimumLevel(.warning)
        await logger.debug("debug msg")
        await logger.info("info msg")
        await logger.warning("warn msg")
        await logger.error("error msg")
        let entries = await logger.allEntries()
        #expect(entries.count == 2)
        #expect(entries.allSatisfy { $0.level >= .warning })
    }

    @Test("Logger sanitizes sensitive data")
    func sanitization() async {
        let logger = ValueFreeLogger()
        await logger.setMinimumLevel(.debug)
        await logger.info("User email: test@example.com", category: .audit)
        let entries = await logger.allEntries()
        let msg = entries.first!.message
        #expect(!msg.contains("test@example.com"))
        #expect(msg.contains("[REDACTED]"))
    }

    @Test("Logger detects sensitive patterns")
    func sensitivePatterns() async {
        let logger = ValueFreeLogger()
        let hasEmail = await logger.containsSensitiveData("send to user@host.com")
        let isClean = await logger.containsSensitiveData("normal log message")
        #expect(hasEmail)
        #expect(!isClean)
    }

    @Test("Logger respects disabled state")
    func disabled() async {
        let logger = ValueFreeLogger()
        await logger.setEnabled(false)
        await logger.info("should not appear")
        let entries = await logger.allEntries()
        #expect(entries.isEmpty)
    }

    @Test("Logger tracks statistics")
    func stats() async {
        let logger = ValueFreeLogger()
        await logger.setMinimumLevel(.debug)
        await logger.debug("d")
        await logger.info("i")
        await logger.warning("w")
        await logger.error("e")
        await logger.critical("c")
        let stats = await logger.stats
        #expect(stats.totalEntries == 5)
        #expect(stats.debugCount == 1)
        #expect(stats.criticalCount == 1)
    }

    @Test("Logger exports as JSON")
    func exportJSON() async {
        let logger = ValueFreeLogger()
        await logger.info("test export")
        let data = await logger.exportJSON()
        #expect(data != nil)
    }
}
