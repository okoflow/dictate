import AppKit
import Observation
import UniformTypeIdentifiers
import WaftCore

@Observable
package final class FileTranscriptionModel {
    package enum Phase: Equatable {
        case idle
        case reading
        case transcribing(Double)
        case finished(TimedTranscript)
        case failed(String)
    }

    enum Format {
        case text
        case subtitles
    }

    static let mediaTypes: [UTType] = [.audio, .movie, .audiovisualContent]

    package private(set) var phase = Phase.idle
    package private(set) var file: URL?
    package private(set) var copiedAt: Date?
    package var language: Language?
    package var isDropTargeted = false

    @ObservationIgnored private let transcriber: any Transcriber
    @ObservationIgnored private let decoder: any MediaDecoder
    @ObservationIgnored private let speechModel: SpeechModelController
    @ObservationIgnored private let clipboard: any Clipboard
    @ObservationIgnored private var task: Task<Void, Never>?

    var isWorking: Bool {
        switch phase {
        case .reading, .transcribing: true
        case .idle, .finished, .failed: false
        }
    }

    var transcript: TimedTranscript? {
        if case let .finished(transcript) = phase {
            return transcript
        }

        return nil
    }

    var notReadyMessage: String? {
        speechModel.state.isReady ? nil : speechModel.state.notReadyMessage
    }

    init(transcriber: any Transcriber, decoder: any MediaDecoder, speechModel: SpeechModelController, clipboard: any Clipboard) {
        self.transcriber = transcriber
        self.decoder = decoder
        self.speechModel = speechModel
        self.clipboard = clipboard
    }

    package func transcribe(_ url: URL) {
        cancel()
        file = url
        copiedAt = nil

        if let notReadyMessage {
            phase = .failed(notReadyMessage)

            return
        }

        phase = .reading
        task = Task { [weak self, transcriber, decoder, language] in
            do {
                let samples = try await decoder.samples(of: url)
                self?.phase = .transcribing(0)

                let transcript = try await transcriber.transcribeFile(samples, in: language) { progress in
                    Task { @MainActor in self?.update(progress) }
                }
                try Task.checkCancellation()

                self?.phase = transcript.map(Phase.finished) ?? .failed(String(localized: "There's no speech in this file."))
            } catch is CancellationError {
                return
            } catch {
                self?
                    .phase = .failed((error as? LocalizedError)?
                        .errorDescription ?? String(localized: "Waft can't read this file."))
            }
        }
    }

    package func reset() {
        cancel()
        phase = .idle
        file = nil
        copiedAt = nil
    }

    func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = Self.mediaTypes
        panel.allowsMultipleSelection = false
        panel.prompt = String(localized: "Transcribe")

        guard panel.runModal() == .OK, let url = panel.url else { return }

        transcribe(url)
    }

    func cancel() {
        task?.cancel()
        task = nil

        if isWorking {
            phase = .idle
        }
    }

    func copyText() {
        guard let transcript else { return }

        clipboard.copy(transcript.text)
        copiedAt = Date()

        let copied = copiedAt

        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.6))

            if self?.copiedAt == copied {
                self?.copiedAt = nil
            }
        }
    }

    func save(_ format: Format) {
        guard let transcript else { return }

        let panel = NSSavePanel()
        let name = file?.deletingPathExtension().lastPathComponent ?? String(localized: "Transcript")

        switch format {
        case .text:
            panel.allowedContentTypes = [.plainText]
            panel.nameFieldStringValue = name + ".txt"

        case .subtitles:
            panel.allowedContentTypes = [UTType(filenameExtension: "srt") ?? .plainText]
            panel.nameFieldStringValue = name + ".srt"
        }

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let contents = format == .text ? transcript.text + "\n" : SubtitleFormatter.srt(transcript)

        do {
            try contents.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    private func update(_ progress: Double) {
        guard case .transcribing = phase else { return }

        phase = .transcribing(progress)
    }
}
