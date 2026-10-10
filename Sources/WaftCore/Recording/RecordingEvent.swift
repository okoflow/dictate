package enum RecordingEvent: Sendable {
    case started(RecordingID, deviceName: String)
    case failed(RecordingID, reason: String)
}
