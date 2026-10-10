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
    name: "Waft",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Waft", targets: ["Waft"]),
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", exact: "1.1.1"),
    ],
    targets: [
        .target(
            name: "WaftCore",
            swiftSettings: strictConcurrency,
        ),
        .target(
            name: "WaftSpeech",
            dependencies: [
                "WaftCore",
                .product(name: "WhisperKit", package: "argmax-oss-swift"),
            ],
            swiftSettings: strictConcurrency,
        ),
        .target(
            name: "WaftPlatform",
            dependencies: ["WaftCore"],
            swiftSettings: strictConcurrency,
        ),
        .target(
            name: "WaftFeatures",
            dependencies: ["WaftCore"],
            swiftSettings: mainActorByDefault,
        ),
        .executableTarget(
            name: "Waft",
            dependencies: ["WaftCore", "WaftFeatures", "WaftPlatform", "WaftSpeech"],
            swiftSettings: mainActorByDefault,
        ),
    ],
    swiftLanguageModes: [.v6],
)
