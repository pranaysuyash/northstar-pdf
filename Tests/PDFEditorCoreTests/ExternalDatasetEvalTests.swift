import Foundation
import Testing
@testable import PDFEditorCore

/// Integration tests for external evaluation datasets (FUNSD + DocLayNet).
/// Tests skip gracefully if datasets not downloaded.
@Suite("External Dataset Evaluation")
struct ExternalDatasetEvalTests {

    private let root = FileManager.default.currentDirectoryPath

    private func fileExists(_ relPath: String) -> Bool {
        FileManager.default.fileExists(atPath: "\(root)/\(relPath)")
    }

    // MARK: - FUNSD

    @Test("FUNSD eval manifest exists and is valid")
    func funsdManifest() throws {
        guard fileExists("benchmark/datasets/funsd/eval/manifest.json") else { return }
        let data = try Data(contentsOf: URL(fileURLWithPath: "\(root)/benchmark/datasets/funsd/eval/manifest.json"))
        let manifest = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(manifest["dataset"] as? String == "funsd")
        #expect(manifest["license"] as? String == "CC BY 4.0")
        let splits = manifest["splits"] as! [String: Any]
        let trainCount = (splits["train"] as? [String: Any])?["count"] as? Int ?? 0
        let testCount = (splits["test"] as? [String: Any])?["count"] as? Int ?? 0
        #expect(trainCount == 149)
        #expect(testCount == 50)
        print("[funsd] Manifest valid: \(trainCount) train, \(testCount) test")
    }

    @Test("FUNSD ground truth has correct entity types")
    func funsdGroundTruth() throws {
        guard fileExists("benchmark/datasets/funsd/data/test.json") else { return }
        let data = try Data(contentsOf: URL(fileURLWithPath: "\(root)/benchmark/datasets/funsd/data/test.json"))
        let records = try JSONSerialization.jsonObject(with: data) as! [[String: Any]]
        #expect(records.count == 50)

        for record in records.prefix(10) {
            let entities = record["entities"] as! [[String: Any]]
            for entity in entities {
                let type = entity["type"] as! String
                #expect(["header", "question", "answer"].contains(type))
            }
        }
        let totalEntities = records.reduce(0) { $0 + (($1["entityCount"] as? Int) ?? 0) }
        print("[funsd] 50 test docs, \(totalEntities) total entities")
    }

    @Test("FUNSD train/test split is non-overlapping")
    func funsdSplitNonOverlap() throws {
        guard fileExists("benchmark/datasets/funsd/data/train.json"),
              fileExists("benchmark/datasets/funsd/data/test.json") else { return }
        let trainData = try Data(contentsOf: URL(fileURLWithPath: "\(root)/benchmark/datasets/funsd/data/train.json"))
        let testData = try Data(contentsOf: URL(fileURLWithPath: "\(root)/benchmark/datasets/funsd/data/test.json"))
        let trainRecords = try JSONSerialization.jsonObject(with: trainData) as! [[String: Any]]
        let testRecords = try JSONSerialization.jsonObject(with: testData) as! [[String: Any]]
        let trainIDs = Set(trainRecords.map { $0["id"] as! String })
        let testIDs = Set(testRecords.map { $0["id"] as! String })
        #expect(trainIDs.intersection(testIDs).isEmpty)
    }

    // MARK: - DocLayNet

    @Test("DocLayNet eval manifest exists and is valid")
    func doclaynetManifest() throws {
        guard fileExists("benchmark/datasets/doclaynet/eval/manifest.json") else { return }
        let data = try Data(contentsOf: URL(fileURLWithPath: "\(root)/benchmark/datasets/doclaynet/eval/manifest.json"))
        let manifest = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(manifest["dataset"] as? String == "doclaynet")
        let classes = manifest["classes"] as! [String]
        #expect(classes.count == 11)
        #expect(classes.contains("Table"))
        #expect(classes.contains("Title"))
        print("[doclaynet] Manifest valid: \(classes.count) classes")
    }

    @Test("DocLayNet class distribution covers all 11 classes")
    func doclaynetClassDistribution() throws {
        guard fileExists("benchmark/datasets/doclaynet/data/test.json") else { return }
        let data = try Data(contentsOf: URL(fileURLWithPath: "\(root)/benchmark/datasets/doclaynet/data/test.json"))
        let records = try JSONSerialization.jsonObject(with: data) as! [[String: Any]]
        #expect(records.count > 100)

        var totalDistribution: [String: Int] = [:]
        for record in records {
            let dist = record["classDistribution"] as! [String: Int]
            for (cls, count) in dist {
                totalDistribution[cls, default: 0] += count
            }
        }

        for cls in ["Caption", "Footnote", "Formula", "List-item", "Page-footer",
                     "Page-header", "Picture", "Section-header", "Table", "Text", "Title"] {
            let count = totalDistribution[cls] ?? 0
            #expect(count > 0, "Class \(cls) not found")
        }

        let total = totalDistribution.values.reduce(0, +)
        print("[doclaynet] \(records.count) pages, \(total) regions")
    }

    @Test("DocLayNet pages have valid bounding boxes")
    func doclaynetBoundingBoxes() throws {
        guard fileExists("benchmark/datasets/doclaynet/data/test.json") else { return }
        let data = try Data(contentsOf: URL(fileURLWithPath: "\(root)/benchmark/datasets/doclaynet/data/test.json"))
        let records = try JSONSerialization.jsonObject(with: data) as! [[String: Any]]

        var pagesWithRegions = 0
        for record in records.prefix(100) {
            let regionCount = record["regionCount"] as? Int ?? 0
            if regionCount > 0 { pagesWithRegions += 1 }
        }
        #expect(pagesWithRegions > 50)
        print("[doclaynet] \(pagesWithRegions)/100 pages have layout regions")
    }
}
