import os

final class LevelMeter: Sendable {
    private let storage = OSAllocatedUnfairLock(initialState: Float(0))

    var value: Float {
        get { storage.withLock { $0 } }
        set { storage.withLock { $0 = newValue } }
    }
}
