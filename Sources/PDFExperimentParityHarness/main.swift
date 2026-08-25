import CryptoKit
import Foundation

private struct Version: Codable, Equatable {
    let major: Int
    let minor: Int
}

private struct CoordinatePolicy: Codable, Equatable {
    let unit: String
    let origin: String
    let pageBox: String
    let rotationDegrees: Int
}

private struct ReviewPolicy: Codable, Equatable {
    let requiresSourceRunEvidence: Bool
    let requiresUserConfirmation: Bool
    let allowsSilentMutation: Bool
    let requiresAbstentionOnUnsupported: Bool
}

private struct ExpectedSemantics: Codable, Equatable {
    let executionState: String
    let sourceBound: Bool
    let reviewRequired: Bool
    let abstainIfUnsupported: Bool
    let privacyClass: String
    let validationKinds: [String]
}

private struct RuntimeEvidence: Codable, Equatable {
    let tier: Int
    let status: String
}

private struct ExperimentEntry: Codable, Equatable {
    let id: String
    let version: Version
    let title: String
    let inspiredCapability: String
    let sourceRefs: [String]
    let provenanceStatus: String
    let licenseStatus: String
    let runtimeEvidence: RuntimeEvidence
    let truthStatus: String
    let owner: String
    let sourceFixture: String
    let corpusClass: String
    let operationKind: String
    let privacyClass: String
    let coordinatePolicy: CoordinatePolicy
    let reviewPolicy: ReviewPolicy
    let validationKinds: [String]
    let hardNegatives: [String]
    let falsifier: String
    let rollback: String
    let parityCases: [String]
}

private struct ParityCase: Codable, Equatable {
    let id: String
    let experimentID: String
    let sourceFixture: String
    let scenario: String
    let operationKind: String
    let coordinate: CoordinatePolicy
    let expected: ExpectedSemantics
}

private struct Ledger: Codable {
    let ledgerName: String
    let ledgerVersion: Version
    let generatedOn: String
    let truthStatus: String
    let sourceDocument: String
    let entries: [ExperimentEntry]
    let parityCases: [ParityCase]
}

private struct SemanticParity: Codable {
    let operationKind: String
    let coordinateSpace: CoordinatePolicy
    let sourceFixture: String
    let reviewPolicy: ReviewPolicy
}

private struct NativeCase: Codable {
    let id: String
    let experimentID: String
    let sourceFixture: String
    let sourceDigest: String?
    let operationKind: String
    let coordinate: CoordinatePolicy
    let executionState: String
    let sourceBound: Bool
    let reviewRequired: Bool
    let abstainIfUnsupported: Bool
    let privacyClass: String
    let validationKinds: [String]
    let ledgerVersion: Version
    let semanticParity: SemanticParity
}

private struct Report: Codable {
    let harness: String
    let version: Version
    let ledgerName: String
    let sourceDocument: String
    let entryCount: Int
    let caseCount: Int
    let passed: Bool
    let cases: [NativeCase]
}

private enum HarnessError: Error, LocalizedError {
    case invalidArgument(String)
    case inputMissing(String)
    case invalidLedger(String)

    var errorDescription: String? {
        switch self {
        case let .invalidArgument(message), let .inputMissing(message), let .invalidLedger(message): message
        }
    }
}

private struct Arguments {
    let ledgerURL: URL
    let outputURL: URL
    let rootURL: URL
}

private let currentVersion = Version(major: 1, minor: 0)
private let requiredIDs = ["E-001", "E-002", "E-003", "E-004", "E-005", "E-006"]
private let requiredCoordinate = CoordinatePolicy(unit: "points", origin: "lowerLeft", pageBox: "crop", rotationDegrees: 0)

private func parseArguments() throws -> Arguments {
    let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    var ledgerURL = rootURL.appendingPathComponent("Tests/fixtures/ihatepdf_experiment_ledger.json")
    var outputURL = rootURL.appendingPathComponent("benchmark/results/ihatepdf-experiments/2026-08-24-native-parity.json")
    var index = 1
    while index < CommandLine.arguments.count {
        switch CommandLine.arguments[index] {
        case "--ledger":
            guard index + 1 < CommandLine.arguments.count else { throw HarnessError.invalidArgument("--ledger requires a path") }
            ledgerURL = URL(fileURLWithPath: CommandLine.arguments[index + 1], relativeTo: rootURL).standardizedFileURL
            index += 2
        case "--output":
            guard index + 1 < CommandLine.arguments.count else { throw HarnessError.invalidArgument("--output requires a path") }
            outputURL = URL(fileURLWithPath: CommandLine.arguments[index + 1], relativeTo: rootURL).standardizedFileURL
            index += 2
        default:
            throw HarnessError.invalidArgument("Unknown argument: \(CommandLine.arguments[index])")
        }
    }
    guard FileManager.default.fileExists(atPath: ledgerURL.path) else {
        throw HarnessError.inputMissing("ihatepdf experiment ledger was not found: \(ledgerURL.path)")
    }
    return Arguments(ledgerURL: ledgerURL, outputURL: outputURL, rootURL: rootURL)
}

private func sha256(for url: URL) throws -> String {
    let data = try Data(contentsOf: url)
    return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func validate(_ ledger: Ledger) throws {
    guard ledger.ledgerName == "pdf-editor.ihatepdf-experiment-ledger",
          ledger.ledgerVersion == currentVersion,
          ledger.truthStatus == "proposed-experiment",
          ledger.entries.count == requiredIDs.count,
          ledger.parityCases.count == requiredIDs.count else {
        throw HarnessError.invalidLedger("Ledger identity, version, truth state, or count is invalid.")
    }
    for id in requiredIDs {
        guard let entry = ledger.entries.first(where: { $0.id == id }),
              let parityCase = ledger.parityCases.first(where: { $0.experimentID == id }),
              entry.version == currentVersion,
              entry.truthStatus == "proposed-experiment",
              entry.provenanceStatus == "observed-public-claim-not-runtime-proof",
              entry.licenseStatus == "not-adopted-unverified",
              entry.runtimeEvidence.tier == 1,
              entry.runtimeEvidence.status == "not-run",
              entry.coordinatePolicy == requiredCoordinate,
              parityCase.coordinate == requiredCoordinate,
              entry.operationKind == parityCase.operationKind,
              parityCase.expected.sourceBound,
              parityCase.expected.abstainIfUnsupported else {
            throw HarnessError.invalidLedger("Ledger entry or parity case is invalid for \(id).")
        }
    }
}

private func makeCase(_ parityCase: ParityCase, entry: ExperimentEntry, digest: String?) -> NativeCase {
    NativeCase(
        id: parityCase.id,
        experimentID: parityCase.experimentID,
        sourceFixture: parityCase.sourceFixture,
        sourceDigest: digest,
        operationKind: parityCase.operationKind,
        coordinate: parityCase.coordinate,
        executionState: parityCase.expected.executionState,
        sourceBound: parityCase.expected.sourceBound,
        reviewRequired: parityCase.expected.reviewRequired,
        abstainIfUnsupported: parityCase.expected.abstainIfUnsupported,
        privacyClass: parityCase.expected.privacyClass,
        validationKinds: parityCase.expected.validationKinds.sorted(),
        ledgerVersion: entry.version,
        semanticParity: SemanticParity(
            operationKind: entry.operationKind,
            coordinateSpace: entry.coordinatePolicy,
            sourceFixture: entry.sourceFixture,
            reviewPolicy: entry.reviewPolicy
        )
    )
}

@main
struct PDFExperimentParityHarness {
    static func main() throws {
        let arguments = try parseArguments()
        let ledger = try JSONDecoder().decode(Ledger.self, from: Data(contentsOf: arguments.ledgerURL))
        try validate(ledger)
        let cases = try ledger.parityCases.map { parityCase -> NativeCase in
            guard let entry = ledger.entries.first(where: { $0.id == parityCase.experimentID }) else {
                throw HarnessError.invalidLedger("Missing entry for \(parityCase.experimentID).")
            }
            let sourceURL = arguments.rootURL.appendingPathComponent(parityCase.sourceFixture).standardizedFileURL
            guard FileManager.default.fileExists(atPath: sourceURL.path) else {
                throw HarnessError.inputMissing("Source fixture is missing: \(parityCase.sourceFixture)")
            }
            return makeCase(parityCase, entry: entry, digest: try sha256(for: sourceURL))
        }
        let report = Report(
            harness: "pdf-editor-native-ihatepdf-experiment-parity",
            version: currentVersion,
            ledgerName: ledger.ledgerName,
            sourceDocument: ledger.sourceDocument,
            entryCount: ledger.entries.count,
            caseCount: cases.count,
            passed: cases.count == requiredIDs.count && cases.allSatisfy { $0.sourceDigest != nil },
            cases: cases
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(at: arguments.outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(report).write(to: arguments.outputURL, options: .atomic)
        FileHandle.standardOutput.write(try encoder.encode(report))
        FileHandle.standardOutput.write(Data([10]))
        if !report.passed { throw HarnessError.invalidLedger("Native experiment parity report did not pass.") }
    }
}
