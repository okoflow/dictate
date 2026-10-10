import Foundation

package protocol Transcriber: Sendable {
    var modelDirectory: URL { get }

    func isModelInstalled() async -> Bool
    func downloadModel(progress: @escaping @Sendable (Double) -> Void) async throws
    func loadModel(for languages: [Language]) async throws -> Duration
    func deleteModel() async
    func transcribe(_ samples: [Float], in language: Language?, vocabulary: [String]) async throws -> Transcript?
    func transcribeFile(
        _ samples: [Float],
        in language: Language?,
        progress: @escaping @Sendable (Double) -> Void,
    ) async throws -> TimedTranscript?
}
