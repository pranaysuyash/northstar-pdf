import Foundation
import PDFEditorCore

private struct Arguments {
    let corpusURL: URL
    let outputURL: URL
}

private enum HarnessError: Error, LocalizedError {
    case invalidArgument(String)
    case inputMissing(String)

    var errorDescription: String? {
        switch self {
        case let .invalidArgument(message), let .inputMissing(message): message
        }
    }
}

private func parseArguments() throws -> Arguments {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    var corpusURL = root.appendingPathComponent("benchmark/results/template-matching/2026-08-24-reviewed-corpus.json")
    var outputURL = root.appendingPathComponent("benchmark/results/template-matching/2026-08-24-native-run.json")
    var index = 1
    while index < CommandLine.arguments.count {
        switch CommandLine.arguments[index] {
        case "--corpus":
            guard index + 1 < CommandLine.arguments.count else {
                throw HarnessError.invalidArgument("--corpus requires a path")
            }
            corpusURL = URL(fileURLWithPath: CommandLine.arguments[index + 1], relativeTo: root).standardizedFileURL
            index += 2
        case "--output":
            guard index + 1 < CommandLine.arguments.count else {
                throw HarnessError.invalidArgument("--output requires a path")
            }
            outputURL = URL(fileURLWithPath: CommandLine.arguments[index + 1], relativeTo: root).standardizedFileURL
            index += 2
        default:
            throw HarnessError.invalidArgument("Unknown argument: \(CommandLine.arguments[index])")
        }
    }
    guard FileManager.default.fileExists(atPath: corpusURL.path) else {
        throw HarnessError.inputMissing("Template benchmark corpus was not found: \(corpusURL.path)")
    }
    return Arguments(corpusURL: corpusURL, outputURL: outputURL)
}

@main
struct PDFTemplateParityHarness {
    static func main() throws {
        let arguments = try parseArguments()
        let corpus = try JSONDecoder().decode(
            PDFTemplateBenchmarkCorpus.self,
            from: Data(contentsOf: arguments.corpusURL)
        )
        let report = PDFTemplateBenchmarkMatcher.run(corpus: corpus)
        try FileManager.default.createDirectory(
            at: arguments.outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(report).write(to: arguments.outputURL, options: .atomic)
        FileHandle.standardOutput.write(try encoder.encode(report))
        FileHandle.standardOutput.write(Data([10]))
        if !report.passed {
            throw HarnessError.invalidArgument("Native template benchmark failed one or more reviewed cases.")
        }
    }
}
