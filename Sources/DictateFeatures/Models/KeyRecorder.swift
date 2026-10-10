import AppKit
import DictateCore
import Observation

@Observable
package final class KeyRecorder {
    private static let escapeKeyCode: UInt16 = 53

    package private(set) var isRecording = false
    package private(set) var rejectedKey = false
    package private(set) var rejections = 0

    @ObservationIgnored private var monitor: Any?
    @ObservationIgnored private var record: ((PushToTalkKey) -> Void)?

    func start(_ record: @escaping (PushToTalkKey) -> Void) {
        guard !isRecording else { return }

        self.record = record
        isRecording = true
        rejectedKey = false
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            MainActor.assumeIsolated {
                self?.handle(event)
            }

            return nil
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }

        monitor = nil
        record = nil
        isRecording = false
    }

    private func handle(_ event: NSEvent) {
        if event.type == .keyDown, event.keyCode == Self.escapeKeyCode {
            stop()

            return
        }

        guard let key = PushToTalkKey(keyCode: Int64(event.keyCode)) else {
            if event.type == .keyDown {
                rejectedKey = true
                rejections += 1
            }

            return
        }

        if event.type == .flagsChanged, !key.isHeld(in: UInt64(event.modifierFlags.rawValue)) {
            return
        }

        record?(key)
        stop()
    }
}
