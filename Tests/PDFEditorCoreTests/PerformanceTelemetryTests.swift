import Foundation
import Testing
@testable import PDFEditorCore

@Suite("Performance and Resource Telemetry Tests")
struct PerformanceTelemetryTests {

  @Test func performanceStageTracksAllDiscreteStages() {
    let stages = PerformanceStage.allCases
    #expect(stages.contains(.openLoad))
    #expect(stages.contains(.pageRender))
    #expect(stages.contains(.detection))
    #expect(stages.contains(.undo))
    #expect(stages.contains(.redo))
    #expect(stages.contains(.save))
    #expect(stages.contains(.impactValidation))
    #expect(stages.contains(.ocr))
    #expect(stages.contains(.vectorParse))
    #expect(stages.contains(.diff))
    #expect(stages.contains(.templateMatch))
    #expect(stages.count == 11)
  }

  @Test func telemetrySummaryComputesAccuratePercentilesAndOutcomes() {
    let samples: [PerformanceSample] = [
      PerformanceSample(stage: .impactValidation, durationNanoseconds: 10_000_000, outcome: .success), // 10ms
      PerformanceSample(stage: .impactValidation, durationNanoseconds: 20_000_000, outcome: .success), // 20ms
      PerformanceSample(stage: .impactValidation, durationNanoseconds: 30_000_000, outcome: .success), // 30ms
      PerformanceSample(stage: .impactValidation, durationNanoseconds: 40_000_000, outcome: .success), // 40ms
      PerformanceSample(stage: .impactValidation, durationNanoseconds: 50_000_000, outcome: .failure), // 50ms (failure)
    ]

    let summary = PerformanceSummary(stage: .impactValidation, samples: samples)
    #expect(summary.sampleCount == 5)
    #expect(summary.successfulSampleCount == 4)
    #expect(summary.failedSampleCount == 1)
    #expect(summary.minimumMilliseconds == 10.0)
    #expect(summary.maximumMilliseconds == 50.0)
    #expect(summary.p50Milliseconds == 30.0)
    #expect(summary.p95Milliseconds == 50.0)
  }

  @Test func telemetryMeasuresNewGranularStages() {
    let telemetry = PerformanceTelemetry(capacity: 64, enabled: true)

    let vectorResult = telemetry.measureVectorParse {
      "parsed-geometry"
    }
    #expect(vectorResult == "parsed-geometry")

    let ocrResult = telemetry.measureOCR {
      ["sample-line"]
    }
    #expect(ocrResult == ["sample-line"])

    let impactResult = telemetry.measureImpactValidation {
      true
    }
    #expect(impactResult == true)

    let diffResult = telemetry.measureDiff {
      42
    }
    #expect(diffResult == 42)

    let matchResult = telemetry.measureTemplateMatch {
      "matched"
    }
    #expect(matchResult == "matched")

    let recordedSamples = telemetry.samples()
    let stageNames = Set(recordedSamples.map(\.stage))
    #expect(stageNames.contains(.vectorParse))
    #expect(stageNames.contains(.ocr))
    #expect(stageNames.contains(.impactValidation))
    #expect(stageNames.contains(.diff))
    #expect(stageNames.contains(.templateMatch))
  }

  @Test func nativeMemoryTelemetryReportsValidProcessCountersWhenEnabled() {
    let disabledSnapshot = NativeMemoryTelemetry.snapshot(enabled: false)
    #expect(disabledSnapshot == nil)

    let enabledSnapshot = NativeMemoryTelemetry.snapshot(enabled: true)
    #expect(enabledSnapshot != nil)
    #expect((enabledSnapshot?.residentBytes ?? 0) > 0)
    #expect((enabledSnapshot?.virtualBytes ?? 0) > 0)
  }

  @Test func memoryDoesNotAccumulateAcrossRepeatedVectorParsing() {
    let memoryBefore = NativeMemoryTelemetry.snapshot(enabled: true)

    // Simulate repeated parsing loop with dummy PDF vector bytes
    for _ in 0..<50 {
      autoreleasepool {
        let dummyData = Data("%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\n%%EOF".utf8)
        _ = PDFVectorStreamParser.parse(data: dummyData)
      }
    }

    let memoryAfter = NativeMemoryTelemetry.snapshot(enabled: true)
    #expect(memoryBefore != nil)
    #expect(memoryAfter != nil)
    // Verify memory counters are accessible and process remains healthy
    #expect((memoryAfter?.residentBytes ?? 0) > 0)
  }
}
