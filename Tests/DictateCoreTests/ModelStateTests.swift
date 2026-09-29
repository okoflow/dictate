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

    @Test func aFailedDownloadRetriesAfterRemovingTheLeftovers() {
        var state = state(after: [.start(installed: false), .downloadProgress(0.5), .failed("offline")])
        #expect(state.phase == .failed(reason: "offline", during: .download))
        #expect(state.canRetry)
        #expect(state.statusText == "Model failed: offline")
        #expect(state.handle(.retry) == [.removePartialDownload, .download])
        #expect(state.phase == .downloading(progress: 0))
        #expect(!state.canRetry)
    }

    @Test func aFailedLoadRetriesTheLoadOnly() {
        var state = state(after: [.start(installed: true), .failed("corrupt")])
        #expect(state.phase == .failed(reason: "corrupt", during: .load))
        #expect(state.handle(.retry) == [.load])
        #expect(state.phase == .loading)
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

    private func install(_ model: String, in base: URL, missing: String? = nil) throws {
        let folder = ModelStore.folder(of: model, in: base)
        let parts = ["AudioEncoder.mlmodelc", "MelSpectrogram.mlmodelc", "TextDecoder.mlmodelc", "config.json"]
        for part in parts where part != missing {
            try FileManager.default.createDirectory(at: folder.appending(path: part), withIntermediateDirectories: true)
        }
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

    @Test func anIncompleteDownloadIsNotInstalledAndCanBeRemoved() throws {
        let base = try makeBase()
        defer { try? FileManager.default.removeItem(at: base) }
        try install("m", in: base)
        let repository = ModelStore.folder(of: "m", in: base).deletingLastPathComponent()
        let cache = repository.appending(path: ".cache/huggingface/download/m")
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        try Data().write(to: cache.appending(path: "weights.bin.abc.incomplete"))
        #expect(!ModelStore.isInstalled("m", in: base))

        ModelStore.removePartialDownload(of: "m", in: base)
        #expect(!FileManager.default.fileExists(atPath: ModelStore.folder(of: "m", in: base).path))
    }
}
