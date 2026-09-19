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
    try await SharedHeavyTestResourceLock.withLock {
      try await assertInterruptionUnlocked(
        phase: phase,
        mode: mode,
        expectedGeneration: expectedGeneration,
        expectedOperationCount: expectedOperationCount
      )
    }
  }

  private func assertInterruptionUnlocked(
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

    // Load-tolerant startup deadline: the child pays process spawn + model
    // construction + full source-document inspection before it can emit its
    // phase event. Under heavy machine load (Observed: builds co-running at
    // load 100-230) that can exceed the original 20s; inside a full
    // `swift test` run the OCR Companion Benchmark suite (~30 min of 5 real
    // OCR providers) saturates the machine and exceeded 60s too (3/3 full
    // runs, passed standalone every time — docs/flaky-register.md 2026-09-07).
    // 480s bounds a genuinely hung child at 8 minutes while absorbing the
    // cold-start cost of a 2-vCPU CI runner (Observed 2026-09-14: the child
    // was still running — not hung — at 240s on macos-15 during a full suite).
    // Environment-scaled (2026-09-18, audit: same class as the semaphore
    // bound): explicit PDF_EDITOR_RECOVERY_STARTUP_DEADLINE (seconds)
    // overrides so a load-saturated environment can widen the window without
    // editing code; the failure message below reports the effective value —
    // a deadline failure must state what fired, or starvation-vs-regression
    // classification is manual guesswork (Observed 2026-09-12 chunk-A triage).
    let startupDeadlineSeconds: TimeInterval = {
      if let raw = ProcessInfo.processInfo.environment["PDF_EDITOR_RECOVERY_STARTUP_DEADLINE"],
         let parsed = Double(raw), parsed > 0 {
        return parsed
      }
      return 480
    }()
    let deadline = Date().addingTimeInterval(startupDeadlineSeconds)
    var observed = false
    var childExitedEarly = false
    var childExitStatus: Int32 = -1
    while Date() < deadline {
      if let data = try? Data(contentsOf: eventURL),
        String(decoding: data, as: UTF8.self) == phase.rawValue
      {
        observed = true
        break
      }
      if !process.isRunning {
        childExitedEarly = true
        process.waitUntilExit()
        childExitStatus = process.terminationStatus
        break
      }
      try await Task.sleep(nanoseconds: 20_000_000)
    }

    // A child that exits before emitting its phase is a HARNESS failure
    // (crash, missing dependency, store init error) — diagnose it as such
    // instead of letting it masquerade as a recovery-semantics regression.
    if !observed, childExitedEarly {
      Issue.record(
        Comment(rawValue: "child harness exited before emitting phase '\(phase.rawValue)' (exit status \(childExitStatus)) — harness/dependency failure, not a recovery-semantics failure"))
    }
    let deadlineNote =
      childExitedEarly
      ? "(exited early, status \(childExitStatus))"
      : "(still running at deadline)"
    #expect(
      observed,
      Comment(rawValue: "child did not reach phase '\(phase.rawValue)' within the \(Int(startupDeadlineSeconds))s startup deadline \(deadlineNote); override with PDF_EDITOR_RECOVERY_STARTUP_DEADLINE if the environment is load-saturated"))
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

/// Serializes the two process-heavy integration lanes across Swift Testing
/// tasks and SwiftPM test processes. A suite-local `.serialized` trait cannot
/// prevent OCR workers from starving the recovery child-process handshake.
private enum SharedHeavyTestResourceLock {
  private static let name = "/pdf-editor-heavy-2"

  static func withLock<T>(_ operation: () async throws -> T) async throws -> T {
    let failed = UnsafeMutablePointer<sem_t>(bitPattern: -1)
    guard let semaphore = sem_open(name, O_CREAT, S_IRUSR | S_IWUSR, 1), semaphore != failed else {
      throw NSError(
        domain: "PDFEditorAppRecoveryTests",
        code: 2,
        userInfo: [NSLocalizedDescriptionKey: "Could not open heavy test resource semaphore"]
      )
    }
    // Bounded acquire (2026-09-12, docs/flaky-register.md same date): POSIX
    // named semaphores do NOT auto-release when a holder is SIGKILLed, so a
    // timeout-killed run leaks the lock and the previous unbounded spin hung
    // every later heavy-lane run silently forever. Bound converts the silent
    // hang into a fail-closed error that names the exact remediation.
    // Environment-scaled acquire bound (2026-09-18; same design as
    // OCRConfirmLaneTests): explicit PDF_EDITOR_HEAVY_SEMAPHORE_ACQUIRE_BOUND
    // (seconds) overrides; CI (GITHUB_ACTIONS/XCODE_ACTION) gets 5400s —
    // no operator can remediate a leak mid-run and waiters must cover the
    // ~74-minute serialized benchmark suite — locally 600s keeps
    // leak-discovery latency bounded (a leak cannot be inherited across
    // machines; the mechanism needs a killed holder in the same kernel).
    // History: 300s (09-12) → 600s (09-15) → 5400s flat (09-15) → scaled.
    let acquireBoundSeconds: TimeInterval = {
      if let raw = ProcessInfo.processInfo.environment["PDF_EDITOR_HEAVY_SEMAPHORE_ACQUIRE_BOUND"],
         let parsed = Double(raw), parsed > 0 {
        return parsed
      }
      let env = ProcessInfo.processInfo.environment
      let onCI = env["GITHUB_ACTIONS"] == "true" || env["XCODE_ACTION"] == "true"
      return onCI ? 5400 : 600
    }()
    let acquireDeadline = Date().addingTimeInterval(acquireBoundSeconds)
    var acquired = false
    while !acquired {
      if sem_trywait(semaphore) == 0 {
        acquired = true
      } else if errno == EAGAIN || errno == EINTR {
        guard Date() < acquireDeadline else { break }
        try await Task.sleep(nanoseconds: 20_000_000)
      } else {
        break
      }
    }
    guard acquired else {
      _ = sem_close(semaphore)
      throw NSError(
        domain: "PDFEditorAppRecoveryTests",
        code: 3,
        userInfo: [NSLocalizedDescriptionKey: "Heavy test resource semaphore '\(name)' not acquired within \(Int(acquireBoundSeconds))s (environment-scaled: 600s locally, 5400s on CI; override with PDF_EDITOR_HEAVY_SEMAPHORE_ACQUIRE_BOUND). Known cause (flaky-register 2026-09-12): a previous run holding the lock was killed, leaking the kernel-persistent named semaphore. Remediate with: pkill -f swiftpm-testing-helper (confirm orphans first), then sem_unlink('\(name)') — the next sem_open(O_CREAT) recreates it."]
      )
    }
    defer {
      _ = sem_post(semaphore)
      _ = sem_close(semaphore)
    }
    return try await operation()
  }
}
