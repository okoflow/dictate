import DictateCore
import Foundation

struct ActiveRecording {
    let id: RecordingID
    let purpose: RecordingPurpose
    let key: PushToTalkKey
    var target: FocusTarget?
    var selection: String?
    var hasFailed = false
    var isRejected = false
    var isHandsFree = false
    var hudTask: Task<Void, Never>?
    var watchdogTimer: Timer?
}
