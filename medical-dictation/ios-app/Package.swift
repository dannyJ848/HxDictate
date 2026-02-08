// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Scribe",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Scribe", targets: ["Scribe"]),
        .executable(name: "ScribeApp", targets: ["ScribeApp"])
    ],
    dependencies: [],
    targets: [
        // C target for whisper.cpp wrapper
        .target(
            name: "CWhisper",
            dependencies: [],
            path: "CWhisper",
            sources: ["whisper_wrapper.c"],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("../scripts/build/whisper.cpp/include"),
                .headerSearchPath("../scripts/build/whisper.cpp/ggml/include"),
                .define("GGML_USE_METAL", to: "1"),
                .define("GGML_USE_CPU", to: "1")
            ],
            linkerSettings: [
                .linkedLibrary("whisper"),
                .linkedLibrary("ggml"),
                .linkedLibrary("ggml-base"),
                .linkedLibrary("ggml-cpu"),
                .linkedLibrary("ggml-metal"),
                .linkedLibrary("ggml-blas"),
                .linkedFramework("Accelerate"),
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("MetalPerformanceShaders")
            ]
        ),
        // C target for llama.cpp wrapper
        .target(
            name: "CLlama",
            dependencies: [],
            path: "CLlama",
            sources: ["llama_wrapper.c"],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("../scripts/build/llama.cpp/include"),
                .headerSearchPath("../scripts/build/llama.cpp/ggml/include"),
                .define("GGML_USE_METAL", to: "1"),
                .define("GGML_USE_CPU", to: "1")
            ],
            linkerSettings: [
                .linkedLibrary("llama"),
                .linkedLibrary("ggml"),
                .linkedLibrary("ggml-base"),
                .linkedLibrary("ggml-cpu"),
                .linkedLibrary("ggml-metal"),
                .linkedLibrary("ggml-blas"),
                .linkedFramework("Accelerate"),
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("MetalPerformanceShaders")
            ]
        ),
        // Main Scribe library
        .target(
            name: "Scribe",
            dependencies: ["CWhisper", "CLlama"],
            path: "Sources/Scribe",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                .unsafeFlags(["-import-objc-header", "../Scribe-Bridging-Header.h"])
            ]
        ),
        // App executable
        .executableTarget(
            name: "ScribeApp",
            dependencies: ["Scribe"],
            path: "Sources/ScribeApp"
        )
    ]
)
