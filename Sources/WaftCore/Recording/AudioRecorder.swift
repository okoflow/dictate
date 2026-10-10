import Foundation

package protocol AudioRecorder: Sendable {
    var events: AsyncStream<RecordingEvent> { get }
    var inputLevel: Float { get }

    func start(_ recording: RecordingID, deviceID: String?) async
    func stop(_ recording: RecordingID, releasedAt: TimeInterval?) async -> [Float]
    func failureReason(for recording: RecordingID) async -> String?
}
