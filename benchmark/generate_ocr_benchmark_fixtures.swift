#!/usr/bin/env swift
// Run: swift benchmark/generate_ocr_benchmark_fixtures.swift
// Outputs Tesseract WER on each generated fixture for baseline measurement.

import Foundation

let corpusDir = "benchmark/results/ocr-corpus"
let fixtures = [
    ("clean-english", "The quick brown fox jumps over the lazy dog. Pack my box with five dozen liquor jugs. How vexingly quick daft zebras jump."),
    ("noisy-invoice", "Invoice Number: 2024-0831\nAmount Due: 1,234.56 dollars\nDate: August 31, 2026"),
    ("rotated-certificate", "Certificate of Achievement\nAwarded to: Dr. Alan Turing\nFor Excellence in Computer Science"),
    ("low-contrast", "Terms and Conditions apply to all purchases.\nPlease read carefully before signing.\nReturns accepted within 30 days of purchase."),
    ("dense-paragraph", "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur."),
    ("small-font", "Small font text tests the limits of OCR recognition accuracy at reduced sizes.\nThis line is also at 12pt to verify consistent OCR behavior.\nThird line for statistical confidence in the measurement."),
    ("mixed-punctuation", "Email: user@example.com | Phone: 555-123-4567\nFax: 1-800-555-0199\nOrder 12345-ABC. Total: 42.50 EUR (VAT included)"),
    ("multi-column", "Column One\nFirst paragraph of the left\ncolumn discusses the importance\nof structured document layout\nfor optical character recognition.\nColumn Two\nSecond paragraph covers the\ntechnical challenges of OCR\nincluding noise, rotation, and\nlow contrast text regions."),
]

func computeWER(hypothesis: String, reference: String) -> Double {
    let hypWords = hypothesis.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
    let refWords = reference.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
    guard !refWords.isEmpty else { return hypWords.isEmpty ? 0 : 1 }
    let m = hypWords.count, n = refWords.count
    var dp = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)
    for i in 0...m { dp[i][0] = i }
    for j in 0...n { dp[0][j] = j }
    for i in 1...m {
        for j in 1...n {
            if hypWords[i-1] == refWords[j-1] {
                dp[i][j] = dp[i-1][j-1]
            } else {
                dp[i][j] = min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1]) + 1
            }
        }
    }
    return Double(dp[m][n]) / Double(n)
}

print("OCR Benchmark Baseline (Tesseract 5.5.0)")
print(String(format: "%-22s %8s %8s %8s", "Fixture", "Words", "WER", "CER"))
print(String(repeating: "-", count: 50))

var totalWER = 0.0
var count = 0

for (name, gt) in fixtures {
    let pngPath = "\(corpusDir)/\(name).png"
    guard FileManager.default.fileExists(atPath: pngPath) else {
        print("\(name): MISSING")
        continue
    }
    // Run tesseract
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/tesseract")
    process.arguments = [pngPath, "-"]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    try? process.run()
    process.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let ocrText = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    
    let wer = computeWER(hypothesis: ocrText, reference: gt)
    let refWords = gt.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.count
    let refChars = gt.count
    let ocrChars = ocrText.count
    let cer = refChars > 0 ? Double(abs(ocrChars - refChars)) / Double(refChars) : 0
    
    print(String(format: "%-22s %8d %7.1f%% %7.1f%%", name, refWords, wer * 100, cer * 100))
    totalWER += wer
    count += 1
}

if count > 0 {
    print(String(repeating: "-", count: 50))
    print(String(format: "%-22s %8s %7.1f%%", "AVERAGE", "", (totalWER / Double(count)) * 100))
}
