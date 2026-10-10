// swift-tools-version: 6.2
import PackageDescription

let strictConcurrency: [SwiftSetting] = [
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .treatAllWarnings(as: .error),
]

let mainActorByDefault = strictConcurrency + [.defaultIsolation(MainActor.self)]

let package = Package(
    name: "Dictate",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Dictate", targets: ["Dictate"]),
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", exact: "1.1.1"),
    ],
    targets: [
        .target(
            name: "DictateCore",
            swiftSettings: strictConcurrency,
        ),
        .target(
            name: "DictateSpeech",
            dependencies: [
                "DictateCore",
                .product(name: "WhisperKit", package: "argmax-oss-swift"),
            ],
            swiftSettings: strictConcurrency,
        ),
        .target(
            name: "DictatePlatform",
            dependencies: ["DictateCore"],
            swiftSettings: strictConcurrency,
        ),
        .target(
            name: "DictateFeatures",
            dependencies: ["DictateCore"],
            swiftSettings: mainActorByDefault,
        ),
        .executableTarget(
            name: "Dictate",
            dependencies: ["DictateCore", "DictateFeatures", "DictatePlatform", "DictateSpeech"],
            swiftSettings: mainActorByDefault,
        ),
    ],
    swiftLanguageModes: [.v6],
)
