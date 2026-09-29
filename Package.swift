// swift-tools-version: 6.2
import PackageDescription

/// Warnings are errors in our own targets only; the dependency keeps its own settings.
let strict: [SwiftSetting] = [.treatAllWarnings(as: .error)]
let whisperKit: Target.Dependency = .product(name: "WhisperKit", package: "argmax-oss-swift")

let package = Package(
    name: "dictate",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Dictate", targets: ["Dictate"]),
        .executable(name: "TestPad", targets: ["TestPad"]),
        .executable(name: "E2ERunner", targets: ["E2ERunner"]),
    ],
    dependencies: [
        // Speech recognition (MIT). Pinned exactly: only the `WhisperKit` product is used.
        .package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", exact: "1.1.0"),
    ],
    targets: [
        // Pure, testable logic. No system frameworks beyond Foundation.
        .target(name: "DictateCore", swiftSettings: strict),

        // CoreAudio device lookup by UID or name, shared by the app and the E2E runner.
        .target(name: "AudioDevices", swiftSettings: strict),

        // Speech recognition with WhisperKit; the only target that imports it.
        .target(name: "Transcription", dependencies: ["DictateCore", whisperKit], swiftSettings: strict),

        // The menu bar app.
        .executableTarget(name: "Dictate", dependencies: ["DictateCore", "AudioDevices"], swiftSettings: strict),

        // Test-only app: a text view and a password field the E2E suite drives via Accessibility.
        .executableTarget(name: "TestPad", dependencies: ["DictateCore", "E2ESupport"], swiftSettings: strict),

        // Shared between TestPad and E2ERunner.
        .target(name: "E2ESupport", swiftSettings: strict),

        // `make e2e` entry point.
        .executableTarget(name: "E2ERunner", dependencies: ["DictateCore", "E2ESupport", "AudioDevices"], swiftSettings: strict),

        // Unit tests never load a model: they cover DictateCore only.
        .testTarget(name: "DictateCoreTests", dependencies: ["DictateCore"], swiftSettings: strict),
    ],
    swiftLanguageModes: [.v6]
)
