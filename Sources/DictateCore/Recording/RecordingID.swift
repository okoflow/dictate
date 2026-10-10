package struct RecordingID: Comparable, Hashable, Sendable {
    package static let none = RecordingID(rawValue: 0)

    package let rawValue: Int

    package var next: RecordingID {
        RecordingID(rawValue: rawValue + 1)
    }

    package static func < (lhs: RecordingID, rhs: RecordingID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
