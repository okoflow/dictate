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
    ],
    dependencies: [
        // Speech recognition (MIT). Pinned exactly: only the `WhisperKit` product is used.
        .package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", exact: "1.1.0"),
    ],
    targets: [
        // Pure, testable logic. No system frameworks beyond Foundation.
        .target(name: "DictateCore", swiftSettings: strict),

        // CoreAudio device lookup by UID or name, used by the app.
        .target(name: "AudioDevices", swiftSettings: strict),

        // Speech recognition with WhisperKit; the only target that imports it.
        .target(name: "Transcription", dependencies: ["DictateCore", whisperKit], swiftSettings: strict),

        // The menu bar app.
        .executableTarget(name: "Dictate", dependencies: ["DictateCore", "AudioDevices", "Transcription"], swiftSettings: strict),
    ],
    swiftLanguageModes: [.v6]
)
