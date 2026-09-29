import Foundation

/// Where the speech model lives on disk and whether a complete copy is there.
///
/// The layout under `baseDirectory` is the one WhisperKit's Hugging Face downloader creates
/// (`models/<repo>/<variant>`), so the app, `make model` and the test tools all agree on it.
public enum ModelStore {
    /// The model used when `--model` is not given: large-v3 (Sept 2024) quantised to 626 MB.
    public static let defaultModel = "openai_whisper-large-v3-v20240930_626MB"
    public static let repository = "argmaxinc/whisperkit-coreml"

    /// Never under `~/Documents`: that folder is synced and scanned by other apps.
    public static var defaultBaseDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "Dictate/Models", directoryHint: .isDirectory)
    }

    /// The folder of one model variant (may not exist yet).
    public static func folder(of model: String, in base: URL) -> URL {
        base.appending(path: "models/\(repository)/\(model)", directoryHint: .isDirectory)
    }

    /// True when every part of the model is on disk and no download is still in progress there.
    /// A download interrupted half way leaves `.incomplete` files in the Hugging Face cache.
    public static func isInstalled(_ model: String, in base: URL, fileManager: FileManager = .default) -> Bool {
        let folder = folder(of: model, in: base)
        let parts = ["AudioEncoder.mlmodelc", "MelSpectrogram.mlmodelc", "TextDecoder.mlmodelc", "config.json"]
        guard parts.allSatisfy({ fileManager.fileExists(atPath: folder.appending(path: $0).path) }) else { return false }
        let cache = folder.deletingLastPathComponent().appending(path: ".cache/huggingface/download")
        let pending = (try? fileManager.subpathsOfDirectory(atPath: cache.path)) ?? []
        return !pending.contains { $0.hasSuffix(".incomplete") }
    }

    /// Deletes what a failed download left behind so the next attempt starts clean.
    public static func removePartialDownload(of model: String, in base: URL, fileManager: FileManager = .default) {
        try? fileManager.removeItem(at: folder(of: model, in: base))
    }
}
