import Darwin
import Foundation
import Testing

import PDFEditorRecovery

@Suite(.serialized)
struct RecoveryCrashInterruptionTests {
  private enum ScenarioMode: String {
    case firstSave = "first-save"
    case update
  }

  private let fileManager = FileManager.default

  @Test("payload interruption preserves the previous committed generation")
  func payloadInterruptionPreservesPreviousGeneration() async throws {
    try await assertInterruption(
      phase: .payload,
      mode: .update,
      expectedGeneration: 1,
      expectedOperationCount: 1
    )
  }

  @Test("pair interruption preserves the previous committed generation")
  func pairInterruptionPreservesPreviousGeneration() async throws {
    try await assertInterruption(
      phase: .pairManifest,
      mode: .update,
      expectedGeneration: 1,
      expectedOperationCount: 1
    )
  }

  @Test("metadata interruption makes the successfully written generation authoritative")
  func metadataInterruptionCommitsNewGeneration() async throws {
    try await assertInterruption(
      phase: .metadataEnvelope,
      mode: .update,
      expectedGeneration: 2,
      expectedOperationCount: 2
    )
  }

  @Test("first-save interruption leaves no discoverable recovery")
  func firstSaveInterruptionIsSafelyAbsent() async throws {
    for phase in RecoveryInterruptionPhase.allCases {
      try await assertInterruption(
        phase: phase,
        mode: .firstSave,
        expectedGeneration: phase == .metadataEnvelope ? 1 : nil,
        expectedOperationCount: phase == .metadataEnvelope ? 1 : 0
      )
    }
  }

  private func assertInterruption(
    phase: RecoveryInterruptionPhase,
    mode: ScenarioMode,
    expectedGeneration: Int?,
    expectedOperationCount: Int
  ) async throws {
    let rootURL = fileManager.temporaryDirectory
      .appendingPathComponent("pdf-editor-recovery-interruption-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: rootURL) }

    let sourceURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("benchmark/results/public-sample-form.pdf")
      .standardizedFileURL
    #expect(fileManager.fileExists(atPath: sourceURL.path))

    let eventURL = rootURL.appendingPathComponent("boundary.event")
    let keyAccount = "interruption-\(UUID().uuidString)"
    let keyData = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
    let childURL = try childExecutableURL()
    let process = Process()
    process.executableURL = childURL
    process.environment = ProcessInfo.processInfo.environment.merging([
      RecoveryInterruptionTestSupport.testModeEnvironment: "1",
      RecoveryInterruptionTestSupport.childEnvironment: "1",
      RecoveryInterruptionTestSupport.rootEnvironment: rootURL.path,
      RecoveryInterruptionTestSupport.sourceEnvironment: sourceURL.path,
      RecoveryInterruptionTestSupport.modeEnvironment: mode.rawValue,
      RecoveryInterruptionTestSupport.phaseEnvironment: phase.rawValue,
      RecoveryInterruptionTestSupport.eventEnvironment: eventURL.path,
      RecoveryInterruptionTestSupport.keyAccountEnvironment: keyAccount,
      RecoveryInterruptionTestSupport.keyDataEnvironment: keyData.base64EncodedString(),
      RecoveryInterruptionTestSupport.blockEnvironment: "1"
    ]) { _, right in right }
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()

    let deadline = Date().addingTimeInterval(20)
    var observed = false
    while Date() < deadline {
      if let data = try? Data(contentsOf: eventURL),
        String(decoding: data, as: UTF8.self) == phase.rawValue
      {
        observed = true
        break
      }
      if !process.isRunning { break }
      try await Task.sleep(nanoseconds: 20_000_000)
    }

    #expect(observed)
    if process.isRunning {
      _ = kill(process.processIdentifier, SIGKILL)
    }
    process.waitUntilExit()
    #expect(process.terminationReason == .uncaughtSignal)

    let observation = await awaitObservation(
      rootURL: rootURL,
      sourceURL: sourceURL,
      keyAccount: keyAccount,
      keyData: keyData
    )
    #expect(observation.committedGeneration == expectedGeneration)
    #expect(observation.discoveredEnvelopeCount == (expectedGeneration == nil ? 0 : 1))
    #expect(observation.replayedOperationCount == expectedOperationCount)
    if observation.recoveryStatus != (expectedGeneration == nil ? "none" : "replayable"),
      let diagnostic = observation.recoveryDiagnostic
    {
      Issue.record("Recovery diagnostic: \(diagnostic)")
    }
    if expectedGeneration == nil {
      #expect(observation.recoveryStatus == "none")
    } else {
      #expect(observation.recoveryStatus == "replayable")
    }
  }

  private func awaitObservation(
    rootURL: URL,
    sourceURL: URL,
    keyAccount: String,
    keyData: Data
  ) async -> RecoveryInterruptionObservation {
    await MainActor.run {
      RecoveryInterruptionTestSupport.reopenAndObserve(
        rootURL: rootURL,
        sourceURL: sourceURL,
        keyAccount: keyAccount,
        keyData: keyData
      )
    }
  }

  private func childExecutableURL() throws -> URL {
    let rootURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .standardizedFileURL
    let candidates = [
      rootURL.appendingPathComponent(".build/debug/PDFRecoveryInterruptionHarness"),
      rootURL.appendingPathComponent(".build/arm64-apple-macosx/debug/PDFRecoveryInterruptionHarness")
    ]
    if let childURL = candidates.first(where: { fileManager.isExecutableFile(atPath: $0.path) }) {
      return childURL
    }
    throw NSError(
      domain: "PDFEditorAppRecoveryTests",
      code: 1,
      userInfo: [NSLocalizedDescriptionKey: "Recovery interruption harness was not built."]
    )
  }
}
