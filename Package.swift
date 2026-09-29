// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "dictate",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Dictate", targets: ["Dictate"]),
        .executable(name: "TestPad", targets: ["TestPad"]),
        .executable(name: "E2ERunner", targets: ["E2ERunner"]),
    ],
    targets: [
        // Pure, testable logic. No system frameworks beyond Foundation.
        .target(name: "DictateCore"),

        // The menu bar app.
        .executableTarget(name: "Dictate", dependencies: ["DictateCore"]),

        // Test-only app: a text view and a password field the E2E suite drives via Accessibility.
        .executableTarget(name: "TestPad", dependencies: ["DictateCore", "E2ESupport"]),

        // Shared between TestPad and E2ERunner.
        .target(name: "E2ESupport"),

        // `make e2e` entry point.
        .executableTarget(name: "E2ERunner", dependencies: ["DictateCore", "E2ESupport"]),

        .testTarget(name: "DictateCoreTests", dependencies: ["DictateCore"]),
    ],
    swiftLanguageModes: [.v6]
)
