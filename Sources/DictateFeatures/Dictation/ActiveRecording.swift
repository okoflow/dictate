import DictateCore
import Foundation

struct ActiveRecording {
    let id: RecordingID
    var target: FocusTarget?
    var hasFailed = false
    var isRejected = false
    var isHandsFree = false
    var hudTask: Task<Void, Never>?
    var watchdogTimer: Timer?
}
