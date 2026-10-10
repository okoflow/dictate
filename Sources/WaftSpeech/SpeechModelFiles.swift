import Foundation
import WaftCore

package struct SpeechModelFiles: Sendable {
    package static let defaultModel = "openai_whisper-large-v3-v20240930_626MB"
    package static let repository = "argmaxinc/whisperkit-coreml"
    package static let defaultBaseDirectory = AppIdentity.supportDirectory.appending(path: "Models", directoryHint: .isDirectory)

    package static let completionMarker = ".waft-complete"

    private static let requiredParts = [
        completionMarker,
        "AudioEncoder.mlmodelc",
        "MelSpectrogram.mlmodelc",
        "TextDecoder.mlmodelc",
        "config.json",
    ]

    let model: String
    let baseDirectory: URL

    var folder: URL {
        baseDirectory.appending(path: "models/\(Self.repository)/\(model)", directoryHint: .isDirectory)
    }

    var tokenizerFile: URL? {
        guard model.contains("large-v3") else { return nil }

        return baseDirectory.appending(path: "models/openai/whisper-large-v3/tokenizer.json")
    }

    var isInstalled: Bool {
        let fileManager = FileManager.default
        let hasEveryPart = Self.requiredParts.allSatisfy { fileManager.fileExists(atPath: folder.appending(path: $0).path) }
        let hasTokenizer = tokenizerFile.map { fileManager.fileExists(atPath: $0.path) } ?? true

        return hasEveryPart && hasTokenizer && !hasIncompleteDownload
    }

    private var hasIncompleteDownload: Bool {
        let cache = folder.deletingLastPathComponent().appending(path: ".cache/huggingface/download/\(model)")
        let pending = (try? FileManager.default.subpathsOfDirectory(atPath: cache.path)) ?? []

        return pending.contains { $0.hasSuffix(".incomplete") }
    }

    func markComplete() throws {
        try Data().write(to: folder.appending(path: Self.completionMarker))
    }

    func remove() {
        try? FileManager.default.removeItem(at: folder)
    }
}
