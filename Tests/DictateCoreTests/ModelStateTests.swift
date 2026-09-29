@testable import DictateCore
import Foundation
import Testing

struct ModelStateTests {
    private func state(after events: [ModelState.Event]) -> ModelState {
        var state = ModelState()
        for event in events {
            _ = state.handle(event)
        }
        return state
    }

    @Test func startsNotDownloaded() {
        let state = ModelState()
        #expect(state.phase == .notDownloaded)
        #expect(!state.isReady)
    }

    @Test func aModelOnDiskGoesStraightToLoading() {
        var state = ModelState()
        #expect(state.handle(.start(installed: true)) == [.load])
        #expect(state.phase == .loading)
        #expect(state.handle(.loaded).isEmpty)
        #expect(state.isReady)
    }

    @Test func aMissingModelIsDownloadedThenLoaded() {
        var state = ModelState()
        #expect(state.handle(.start(installed: false)) == [.download])
        #expect(state.phase == .downloading(progress: 0))
        #expect(state.handle(.downloadProgress(0.42)).isEmpty)
        #expect(state.statusText == "Downloading model… 42%")
        #expect(state.handle(.downloaded) == [.load])
        #expect(state.statusText == "Loading model…")
        _ = state.handle(.loaded)
        #expect(state.statusText == "Ready")
    }

    @Test func progressNeverGoesBackwardsAndStopsAtOne() {
        let state = state(after: [.start(installed: false), .downloadProgress(0.6), .downloadProgress(0.3), .downloadProgress(7)])
        #expect(state.phase == .downloading(progress: 1))
    }

    @Test func aFailedDownloadRetriesAndKeepsTheFinishedFiles() {
        var state = state(after: [.start(installed: false), .downloadProgress(0.5), .failed("offline")])
        #expect(state.phase == .failed(reason: "offline", during: .download))
        #expect(state.canRetry)
        #expect(state.statusText == "Model failed: offline")
        #expect(state.handle(.retry) == [.download])
        #expect(state.phase == .downloading(progress: 0))
        #expect(!state.canRetry)
    }

    @Test func aFailedLoadDeletesTheModelAndDownloadsItAgain() {
        var state = state(after: [.start(installed: true), .failed("corrupt")])
        #expect(state.phase == .failed(reason: "corrupt", during: .load))
        #expect(state.handle(.retry) == [.removeModel, .download])
        #expect(state.phase == .downloading(progress: 0))
    }

    @Test func unrelatedEventsAreIgnored() {
        var state = ModelState()
        #expect(state.handle(.loaded).isEmpty)
        #expect(state.handle(.retry).isEmpty)
        #expect(state.handle(.downloadProgress(0.5)).isEmpty)
        #expect(state.phase == .notDownloaded)

        state = self.state(after: [.start(installed: true), .loaded])
        #expect(state.handle(.failed("late")).isEmpty)
        #expect(state.handle(.start(installed: false)).isEmpty)
        #expect(state.isReady)
    }

    @Test func notReadyMessageFollowsThePhase() {
        var state = ModelState()
        #expect(state.notReadyMessage == "Model not ready")
        _ = state.handle(.start(installed: false))
        _ = state.handle(.downloadProgress(0.25))
        #expect(state.notReadyMessage == "Downloading model… 25%")
        _ = state.handle(.downloaded)
        #expect(state.notReadyMessage == "Loading model (first launch ≈1 min)…")
        _ = state.handle(.failed("x"))
        #expect(state.notReadyMessage == "Model failed: see the menu")
    }

    @Test func statusTextForAModelThatIsNotThereYet() {
        #expect(ModelState().statusText == "Model not downloaded")
    }
}

struct FixtureManifestTests {
    @Test func decodesOptionalAlternatives() throws {
        let json = """
        [{"id":"ru-plain-1","language":"ru","voice":"Milena","text":"в три часа","alternatives":["в 3 часа"],"tags":["plain"]},
         {"id":"en-plain-2","language":"en","voice":"Samantha","text":"hello","tags":["plain"]}]
        """
        let fixtures = try JSONDecoder().decode([Fixture].self, from: Data(json.utf8))
        #expect(fixtures.map(\.id) == ["ru-plain-1", "en-plain-2"])
        #expect(fixtures[0].alternatives == ["в 3 часа"])
        #expect(fixtures[1].alternatives.isEmpty)
        #expect(fixtures[0].language == .ru)
    }
}

struct ModelStoreTests {
    private func makeBase() throws -> URL {
        let base = FileManager.default.temporaryDirectory.appending(path: "dictate-model-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    /// Lays out a complete copy of `model`; `missing` leaves one part out, `marked: false` skips the marker.
    private func install(_ model: String, in base: URL, missing: String? = nil, marked: Bool = true) throws {
        let folder = ModelStore.folder(of: model, in: base)
        let parts = ["AudioEncoder.mlmodelc", "MelSpectrogram.mlmodelc", "TextDecoder.mlmodelc", "config.json"]
        for part in parts where part != missing {
            try FileManager.default.createDirectory(at: folder.appending(path: part), withIntermediateDirectories: true)
        }
        if let tokenizer = ModelStore.tokenizerFile(for: model, in: base) {
            try FileManager.default.createDirectory(at: tokenizer.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data().write(to: tokenizer)
        }
        if marked {
            try ModelStore.markComplete(model, in: base)
        }
    }

    private func addIncompleteFile(for model: String, in base: URL) throws {
        let repository = ModelStore.folder(of: model, in: base).deletingLastPathComponent()
        let cache = repository.appending(path: ".cache/huggingface/download/\(model)")
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        try Data().write(to: cache.appending(path: "weights.bin.abc.incomplete"))
    }

    @Test func folderFollowsTheHubLayout() {
        let base = URL(filePath: "/base")
        #expect(ModelStore.folder(of: "m", in: base).path == "/base/models/argmaxinc/whisperkit-coreml/m")
    }

    @Test func defaultBaseIsUnderApplicationSupportNotDocuments() {
        let path = ModelStore.defaultBaseDirectory.path
        #expect(path.hasSuffix("Application Support/Dictate/Models"))
        #expect(!path.contains("/Documents/"))
    }

    @Test func aCompleteModelIsInstalled() throws {
        let base = try makeBase()
        defer { try? FileManager.default.removeItem(at: base) }
        #expect(!ModelStore.isInstalled("m", in: base))
        try install("m", in: base)
        #expect(ModelStore.isInstalled("m", in: base))
    }

    @Test func aModelMissingAPartIsNotInstalled() throws {
        let base = try makeBase()
        defer { try? FileManager.default.removeItem(at: base) }
        try install("m", in: base, missing: "TextDecoder.mlmodelc")
        #expect(!ModelStore.isInstalled("m", in: base))
    }

    @Test func aFolderWithoutTheCompletionMarkerIsNotInstalled() throws {
        let base = try makeBase()
        defer { try? FileManager.default.removeItem(at: base) }
        try install("m", in: base, marked: false)
        #expect(!ModelStore.isInstalled("m", in: base))
    }

    @Test func largeV3NeedsItsTokenizerOnDisk() throws {
        let base = try makeBase()
        defer { try? FileManager.default.removeItem(at: base) }
        let model = "openai_whisper-large-v3-v20240930_626MB"
        try install(model, in: base)
        #expect(ModelStore.isInstalled(model, in: base))
        try FileManager.default.removeItem(at: #require(ModelStore.tokenizerFile(for: model, in: base)))
        #expect(!ModelStore.isInstalled(model, in: base))
    }

    @Test func anUnknownModelHasNoKnownTokenizer() {
        #expect(ModelStore.tokenizerFile(for: "openai_whisper-small", in: URL(filePath: "/b")) == nil)
    }

    @Test func anIncompleteFileOfThisVariantMeansNotInstalled() throws {
        let base = try makeBase()
        defer { try? FileManager.default.removeItem(at: base) }
        try install("m", in: base)
        try addIncompleteFile(for: "m", in: base)
        #expect(!ModelStore.isInstalled("m", in: base))
    }

    @Test func anIncompleteFileOfAnotherVariantIsIgnored() throws {
        let base = try makeBase()
        defer { try? FileManager.default.removeItem(at: base) }
        try install("m", in: base)
        try addIncompleteFile(for: "other", in: base)
        #expect(ModelStore.isInstalled("m", in: base))
    }

    @Test func removeDeletesTheWholeModel() throws {
        let base = try makeBase()
        defer { try? FileManager.default.removeItem(at: base) }
        try install("m", in: base)
        ModelStore.remove("m", in: base)
        #expect(!FileManager.default.fileExists(atPath: ModelStore.folder(of: "m", in: base).path))
        #expect(!ModelStore.isInstalled("m", in: base))
    }
}
