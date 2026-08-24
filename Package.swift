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
        .executable(
            name: "PDFEditor",
            targets: ["PDFEditorApp"]
        ),
        .executable(
            name: "PDFContractHarness",
            targets: ["PDFContractHarness"]
        )
    ],
    targets: [
        .target(
            name: "PDFEditorCore"
        ),
        .executableTarget(
            name: "PDFEditorApp",
            dependencies: ["PDFEditorCore"]
        ),
        .executableTarget(
            name: "PDFContractHarness",
            dependencies: ["PDFEditorCore"]
        ),
        .testTarget(
            name: "PDFEditorCoreTests",
            dependencies: ["PDFEditorCore"]
        )
    ]
)
