import DictateCore
import Foundation
import Observation
import Transcription

/// Gets the speech model from "maybe not on disk" to "loaded": downloads it on the first launch,
/// loads it in the background, and lets the menu show the progress. The decisions live in
/// `ModelState`; this class only does what that state machine asks for.
@MainActor
@Observable
final class ModelController {
    private(set) var state = ModelState()

    @ObservationIgnored let transcriber: Transcriber
    @ObservationIgnored private let model: String
    @ObservationIgnored private let baseDirectory = ModelStore.defaultBaseDirectory
    @ObservationIgnored private let eventLog: EventLogWriter

    init(model: String, eventLog: EventLogWriter) {
        self.model = model
        self.eventLog = eventLog
        transcriber = Transcriber(model: model, baseDirectory: ModelStore.defaultBaseDirectory)
    }

    func start() {
        apply(.start(installed: ModelStore.isInstalled(model, in: baseDirectory)))
    }

    func retry() {
        apply(.retry)
    }

    private func apply(_ event: ModelState.Event) {
        for effect in state.handle(event) {
            perform(effect)
        }
    }

    private func perform(_ effect: ModelState.Effect) {
        switch effect {
        case .removeModel:
            ModelStore.remove(model, in: baseDirectory)
        case .download:
            Task { await download() }
        case .load:
            Task { await load() }
        }
    }

    private func download() async {
        do {
            try await Transcriber.download(model: model, into: baseDirectory) { [weak self] fraction in
                Task { @MainActor in self?.apply(.downloadProgress(fraction)) }
            }
            apply(.downloaded)
        } catch {
            apply(.failed(error.localizedDescription))
        }
    }

    private func load() async {
        do {
            let seconds = try await transcriber.load()
            apply(.loaded)
            eventLog.log(.modelReady(name: model, loadSeconds: seconds))
        } catch {
            apply(.failed(error.localizedDescription))
        }
    }
}
