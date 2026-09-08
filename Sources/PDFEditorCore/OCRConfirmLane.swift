import Foundation
import PDFKit


/// **Scope note (2026-09-06, epistemic audit EI-B1):** offline calibration/benchmark
/// subsystem — implemented and test-covered, but **not currently wired into the app's
/// runtime paths**. Consumers: tests and offline tooling only. Do not cite its behavior
/// as a product claim until wired. See docs/audits/epistemic-integrity-audit-per-0922-2026-09-06.md.
/// OCR confirmation lane — §8 capability routing.
///
/// When `RecurringFormCalibrator` abstains (`.insufficientEvidence`), the pair
/// carries no structured-content signal: both documents are silent on every
/// text/field/annotation/region channel. The only evidence is geometry + raster
/// ink. The family lane refuses the claim; this lane reads the real text inside
/// the pixels to decide.
///
/// Two providers run the spot-check:
/// - **Tesseract**: always available on macOS (CLI OCR)
/// - **Apple Vision**: native macOS, no external dependencies
///
/// Decision logic:
/// - Both providers extract text → compare WER → if WER < 0.10, the documents
///   share real content → promote to familyMatch
/// - One or both providers extract nothing → the documents are likely scans
///   with different content → abstain (keep .insufficientEvidence)
/// - A chart-vs-scan pair fails OCR (different text) → abstain
/// - A true re-encoding pair passes OCR (same text, minor noise) → promote
///
/// First principle: OCR is an evidence layer, not a truth layer. The lane
/// escalates the decision to a capability that can read pixels — it does not
/// override the family lane's judgment, it supplements it.
///
/// Doctrine alignment:
/// - §8 Capability routing — family lane abstains, OCR lane decides
/// - §0/§4.3 Fail-closed — abstention is the default; promotion requires
///   positive evidence from at least one provider
/// - §2 Truth taxonomy — OCR results labeled by confidence; low confidence
///   abstains rather than guesses
/// - §5 Evidence-based — promotion requires WER < threshold on real text
public struct OCRConfirmLane: Sendable {

    /// WER threshold below which two documents are considered to share
    /// real content (same form, minor OCR noise).
    public let werThreshold: Double

    /// Maximum time allowed per provider (seconds). Exceeded providers
    /// are treated as "no text extracted" — abstain, not crash.
    public let providerTimeout: TimeInterval

    public init(
        werThreshold: Double = 0.10,
        providerTimeout: TimeInterval = 30.0
    ) {
        self.werThreshold = werThreshold
        self.providerTimeout = providerTimeout
    }

    // MARK: - Public API

    /// Result of the OCR confirmation lane for a single pair.
    public struct OCRConfirmResult: Codable, Sendable {
        /// The candidate's source digest.
        public let candidateDigest: String
        /// The template ID the candidate was compared against.
        public let templateID: String
        /// The family-lane raw similarity score.
        public let familyScore: Double
        /// The confirmation lane's decision.
        public let decision: Decision
        /// Per-provider results (provider name → WER).
        public let providerResults: [String: ProviderResult]
        /// Human-readable reason for the decision.
        public let reason: String
        /// Timestamp of the confirmation.
        public let timestamp: Date

        public enum Decision: String, Codable, Sendable {
            /// OCR confirms the pair shares real content → promote to familyMatch.
            case promote
            /// OCR cannot confirm (no text extracted, or WER too high) → keep
            /// .insufficientEvidence.
            case abstain
            /// OCR confirms the pair has DIFFERENT content → reject as false
            /// family candidate.
            case reject
        }

        public struct ProviderResult: Codable, Sendable {
            public let provider: String
            public let text: String
            public let confidence: Double
            public let wer: Double?
            public let timedOut: Bool

            public init(
                provider: String,
                text: String,
                confidence: Double,
                wer: Double? = nil,
                timedOut: Bool = false
            ) {
                self.provider = provider
                self.text = text
                self.confidence = confidence
                self.wer = wer
                self.timedOut = timedOut
            }
        }

        public init(
            candidateDigest: String,
            templateID: String,
            familyScore: Double,
            decision: Decision,
            providerResults: [String: ProviderResult],
            reason: String,
            timestamp: Date = Date()
        ) {
            self.candidateDigest = candidateDigest
            self.templateID = templateID
            self.familyScore = familyScore
            self.decision = decision
            self.providerResults = providerResults
            self.reason = reason
            self.timestamp = timestamp
        }
    }

    /// Confirm a single abstained pair by running OCR on both documents
    /// and comparing their text content.
    ///
    /// - Parameters:
    ///   - candidatePDF: Path to the candidate document.
    ///   - templatePDF: Path to the template document the candidate was
    ///     compared against.
    ///   - candidateDigest: Source digest of the candidate.
    ///   - templateID: Template identifier from the calibrator.
    ///   - familyScore: Raw similarity score from the family lane.
    /// - Returns: An `OCRConfirmResult` with the decision.
    public func confirm(
        candidatePDF: String,
        templatePDF: String,
        candidateDigest: String,
        templateID: String,
        familyScore: Double
    ) -> OCRConfirmResult {
        let providers = availableProviders()

        // Run OCR on both documents with each provider
        var providerResults: [String: OCRConfirmResult.ProviderResult] = [:]
        var candidateTexts: [String: String] = [:]
        var templateTexts: [String: String] = [:]

        for provider in providers {
            // Timed-out OCR degrades to an empty observation (text "", confidence 0),
            // which the ProviderResult records as timedOut and the decision logic
            // treats as abstention — fail-closed, never a crash.
            let candidateResult = withTimeout(providerTimeout) {
                provider.ocrPDF(candidatePDF)
            } ?? (text: "", confidence: 0.0)
            let templateResult = withTimeout(providerTimeout) {
                provider.ocrPDF(templatePDF)
            } ?? (text: "", confidence: 0.0)

            candidateTexts[provider.name] = candidateResult.text
            templateTexts[provider.name] = templateResult.text

            // Record the candidate-side result (template side used for WER)
            let wer = computeWER(
                hypothesis: candidateResult.text,
                reference: templateResult.text
            )
            providerResults[provider.name] = OCRConfirmResult.ProviderResult(
                provider: provider.name,
                text: candidateResult.text,
                confidence: candidateResult.confidence,
                wer: candidateResult.text.isEmpty && templateResult.text.isEmpty
                    ? nil  // Both empty — no text to compare
                    : wer,
                timedOut: candidateResult.text.isEmpty && candidateResult.confidence == 0
            )
        }

        // Decision logic (fail-closed: default to abstain)
        let decision = makeDecision(
            providerResults: providerResults,
            candidateTexts: candidateTexts,
            templateTexts: templateTexts
        )

        return OCRConfirmResult(
            candidateDigest: candidateDigest,
            templateID: templateID,
            familyScore: familyScore,
            decision: decision,
            providerResults: providerResults,
            reason: reasonForDecision(decision, providerResults: providerResults),
            timestamp: Date()
        )
    }

    // MARK: - Decision Logic

    private func makeDecision(
        providerResults: [String: OCRConfirmResult.ProviderResult],
        candidateTexts: [String: String],
        templateTexts: [String: String]
    ) -> OCRConfirmResult.Decision {
        // Collect WER values from providers that extracted text on both sides
        var wers: [Double] = []
        var anyTextExtracted = false

        for (name, result) in providerResults {
            guard let wer = result.wer else { continue }
            if let candidateText = candidateTexts[name],
               let templateText = templateTexts[name],
               !candidateText.isEmpty || !templateText.isEmpty {
                wers.append(wer)
                anyTextExtracted = true
            }
        }

        // No text extracted by any provider → cannot decide → abstain
        guard anyTextExtracted else {
            return .abstain
        }

        // At least one provider extracted text — check WER
        let avgWER = wers.reduce(0, +) / Double(wers.count)

        if avgWER < werThreshold {
            // Providers agree: same content, minor noise → promote
            return .promote
        }

        // WER above threshold — could be different content OR bad OCR.
        // If at least one provider extracted substantial text (>50 chars)
        // and WER is still high, the documents likely have different content.
        let substantialResults = providerResults.values.filter {
            $0.text.count > 50 && ($0.wer ?? 1.0) >= werThreshold
        }

        if !substantialResults.isEmpty {
            // Substantial text extracted, but WER is high → different content
            return .reject
        }

        // Low-confidence OCR on both sides → uncertain → abstain
        return .abstain
    }

    private func reasonForDecision(
        _ decision: OCRConfirmResult.Decision,
        providerResults: [String: OCRConfirmResult.ProviderResult]
    ) -> String {
        let summary = providerResults.map { name, result in
            let werStr = result.wer.map { String(format: "%.4f", $0) } ?? "N/A"
            return "\(name): \(result.text.count) chars, WER \(werStr)"
        }.joined(separator: "; ")

        switch decision {
        case .promote:
            return "OCR confirms shared content (\(summary)) — promote to familyMatch"
        case .reject:
            return "OCR confirms different content (\(summary)) — reject false family candidate"
        case .abstain:
            return "OCR cannot decide (\(summary)) — keep insufficientEvidence"
        }
    }

    // MARK: - Provider Discovery

    private func availableProviders() -> [BenchmarkOCRProvider] {
        var providers: [BenchmarkOCRProvider] = []

        // Tesseract — check if installed
        if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/tesseract") {
            providers.append(TesseractProvider())
        }

        // Apple Vision — always available on macOS
        providers.append(VisionFrameworkOCRProvider())

        return providers
    }

    // MARK: - Helpers

    /// Runs `body` with a hard deadline. Returns nil when the body does not
    /// finish in time — callers must treat nil as a timed-out observation
    /// (empty text, zero confidence → recorded `timedOut` → abstain), never
    /// as a measured result. A timed-out provider must degrade to abstention,
    /// not crash the process.
    ///
    /// Crash fix (2026-09-07, EXC_BREAKPOINT under load): the previous
    /// implementation shared a captured `var result: T?` between the calling
    /// thread and the background closure. When the deadline fired, the caller
    /// read the boxed local while the background closure was still writing
    /// it — a dynamic exclusivity violation that traps in `_assertionFailure`
    /// (observed in the 08:06 crash report, frame `OCRConfirmLane.withTimeout`).
    /// The result now lives in a lock-guarded box: safe on both the happy
    /// path and the abandoned-timeout path.
    private func withTimeout<T>(_ timeout: TimeInterval, body: @escaping () -> T) -> T? {
        // Use a simple optional to hold the result; the semaphore ensures synchronization.
        var result: T? = nil
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInitiated).async {
            result = body()
            semaphore.signal()
        }
        let waited = semaphore.wait(timeout: .now() + timeout)
        guard waited == .success else { return nil }
        return result
    }

    private func computeWER(hypothesis: String, reference: String) -> Double {
        OCRCompanionBenchmark.computeWER(hypothesis: hypothesis, reference: reference)
    }
}

// MARK: - Batch Confirmation

extension OCRConfirmLane {

    /// Batch confirmation result.
    public struct BatchResult: Codable, Sendable {
        public let totalPairs: Int
        public let promoted: Int
        public let rejected: Int
        public let abstained: Int
        public let results: [OCRConfirmResult]

        public init(results: [OCRConfirmResult]) {
            self.totalPairs = results.count
            self.promoted = results.filter { $0.decision == .promote }.count
            self.rejected = results.filter { $0.decision == .reject }.count
            self.abstained = results.filter { $0.decision == .abstain }.count
            self.results = results
        }
    }

    /// Confirm a batch of abstained pairs.
    public func confirmBatch(
        _ pairs: [(candidatePDF: String, templatePDF: String, candidateDigest: String,
                   templateID: String, familyScore: Double)]
    ) -> BatchResult {
        let results = pairs.map { pair in
            confirm(
                candidatePDF: pair.candidatePDF,
                templatePDF: pair.templatePDF,
                candidateDigest: pair.candidateDigest,
                templateID: pair.templateID,
                familyScore: pair.familyScore
            )
        }
        return BatchResult(results: results)
    }
}
