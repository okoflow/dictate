import AppKit
import Observation
import WaftCore

@Observable
package final class KeyRecorder {
    package enum Field: Hashable {
        case dictation
        case edit
    }

    package struct Rejection: Equatable {
        let field: Field
        let isTaken: Bool
    }

    private static let escapeKeyCode: UInt16 = 53

    package private(set) var field: Field?
    package private(set) var rejection: Rejection?
    package private(set) var rejections: [Field: Int] = [:]

    @ObservationIgnored private var monitor: Any?
    @ObservationIgnored private var takenKey: PushToTalkKey?
    @ObservationIgnored private var record: ((PushToTalkKey) -> Void)?

    package var isRecording: Bool {
        field != nil
    }

    func start(_ field: Field, excluding takenKey: PushToTalkKey?, _ record: @escaping (PushToTalkKey) -> Void) {
        stop()

        self.field = field
        self.takenKey = takenKey
        self.record = record
        rejection = nil
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
        field = nil
    }

    func isRecording(_ field: Field) -> Bool {
        self.field == field
    }

    private func handle(_ event: NSEvent) {
        if event.type == .keyDown, event.keyCode == Self.escapeKeyCode {
            stop()

            return
        }

        guard let field, let key = PushToTalkKey(keyCode: Int64(event.keyCode)) else {
            if event.type == .keyDown, let field {
                reject(in: field, isTaken: false)
            }

            return
        }

        if event.type == .flagsChanged, !key.isHeld(in: UInt64(event.modifierFlags.rawValue)) {
            return
        }

        guard key != takenKey else {
            reject(in: field, isTaken: true)

            return
        }

        record?(key)
        stop()
    }

    private func reject(in field: Field, isTaken: Bool) {
        rejection = Rejection(field: field, isTaken: isTaken)
        rejections[field, default: 0] += 1
    }
}
