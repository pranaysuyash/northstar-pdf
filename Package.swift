// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PDFEditor",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "PDFEditorCore",
            targets: ["PDFEditorCore"]
        ),
        .library(
            name: "PDFEditorRecovery",
            targets: ["PDFEditorRecovery"]
        ),
        .executable(
            name: "PDFEditor",
            targets: ["PDFEditorApp"]
        ),
        .executable(
            name: "PDFRecoveryInterruptionHarness",
            targets: ["PDFRecoveryInterruptionHarness"]
        ),
        .executable(
            name: "PDFContractHarness",
            targets: ["PDFContractHarness"]
        ),
        .executable(
            name: "PDFTemplateParityHarness",
            targets: ["PDFTemplateParityHarness"]
        ),
        .executable(
            name: "PDFExperimentParityHarness",
            targets: ["PDFExperimentParityHarness"]
        ),
        .executable(
            name: "PDFOCRBenchmark",
            targets: ["PDFOCRBenchmark"]
        ),
        .executable(
            name: "PDFTextRunOCRBenchmark",
            targets: ["PDFTextRunOCRBenchmark"]
        ),
        .executable(
            name: "PDFPerformanceBenchmark",
            targets: ["PDFPerformanceBenchmark"]
        ),
    ],
    targets: [
        .target(
            name: "PDFEditorCore"
        ),
        .target(
            name: "PDFEditorRecovery",
            dependencies: ["PDFEditorCore"]
        ),
        .executableTarget(
            name: "PDFEditorApp",
            dependencies: ["PDFEditorCore", "PDFEditorRecovery"]
        ),
        .executableTarget(
            name: "PDFRecoveryInterruptionHarness",
            dependencies: ["PDFEditorRecovery"]
        ),
        .executableTarget(
            name: "PDFContractHarness",
            dependencies: ["PDFEditorCore"]
        ),
        .executableTarget(
            name: "PDFTemplateParityHarness",
            dependencies: ["PDFEditorCore"]
        ),
        .executableTarget(
            name: "PDFExperimentParityHarness",
            dependencies: ["PDFEditorCore"]
        ),
        .executableTarget(
            name: "PDFOCRBenchmark",
            dependencies: ["PDFEditorCore"]
        ),
        .executableTarget(
            name: "PDFTextRunOCRBenchmark",
            dependencies: ["PDFEditorCore"]
        ),
        .executableTarget(
            name: "PDFPerformanceBenchmark",
            dependencies: ["PDFEditorCore"]
        ),
        .testTarget(
            name: "PDFEditorCoreTests",
            dependencies: ["PDFEditorCore"]
        ),
        .testTarget(
            name: "PDFEditorAppRecoveryTests",
            dependencies: ["PDFEditorRecovery"]
        )
    ]
)
