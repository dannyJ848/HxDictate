// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Scribe",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Scribe", targets: ["Scribe"]),
        .executable(name: "ScribeApp", targets: ["ScribeApp"])
    ],
    dependencies: [
        // We'll vendor whisper.cpp and llama.cpp as XCFrameworks or build from source
    ],
    targets: [
        .target(
            name: "Scribe",
            dependencies: [],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .executableTarget(
            name: "ScribeApp",
            dependencies: ["Scribe"]
        ),
        .testTarget(
            name: "ScribeTests",
            dependencies: ["Scribe"]
        )
    ]
)
