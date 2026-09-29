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

    /// Written once a download has finished and the tokenizer is in place. Without it a folder that merely
    /// looks complete (files can appear before they are fully written) is never trusted.
    public static let completionMarker = ".dictate-complete"

    /// Where WhisperKit keeps the tokenizer of `model`, or `nil` for a model whose tokenizer we do not know.
    public static func tokenizerFile(for model: String, in base: URL) -> URL? {
        guard model.contains("large-v3") else { return nil }
        return base.appending(path: "models/openai/whisper-large-v3/tokenizer.json")
    }

    /// True when the download finished (marker), every part is there, the tokenizer is on disk, and the
    /// Hugging Face cache of this variant holds no `.incomplete` file. That way `make e2e`, `make bench`
    /// and the app's "ready" state never depend on a network fetch.
    public static func isInstalled(_ model: String, in base: URL, fileManager: FileManager = .default) -> Bool {
        let folder = folder(of: model, in: base)
        let parts = [completionMarker, "AudioEncoder.mlmodelc", "MelSpectrogram.mlmodelc", "TextDecoder.mlmodelc", "config.json"]
        guard parts.allSatisfy({ fileManager.fileExists(atPath: folder.appending(path: $0).path) }) else { return false }
        if let tokenizer = tokenizerFile(for: model, in: base), !fileManager.fileExists(atPath: tokenizer.path) {
            return false
        }
        let cache = folder.deletingLastPathComponent().appending(path: ".cache/huggingface/download/\(model)")
        let pending = (try? fileManager.subpathsOfDirectory(atPath: cache.path)) ?? []
        return !pending.contains { $0.hasSuffix(".incomplete") }
    }

    public static func markComplete(_ model: String, in base: URL) throws {
        try Data().write(to: folder(of: model, in: base).appending(path: completionMarker))
    }

    /// Deletes the whole model, for a copy that cannot be loaded. (A failed *download* is not cleaned up:
    /// the downloader resumes from the files that are complete.)
    public static func remove(_ model: String, in base: URL, fileManager: FileManager = .default) {
        try? fileManager.removeItem(at: folder(of: model, in: base))
    }
}
