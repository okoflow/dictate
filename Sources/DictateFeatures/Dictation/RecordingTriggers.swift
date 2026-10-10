import DictateCore
import Foundation

struct RecordingTriggers {
    private var dictation = PushToTalk()
    private var edit = PushToTalk()

    static func key(for purpose: RecordingPurpose, in settings: Settings) -> PushToTalkKey? {
        switch purpose {
        case .dictation: settings.pushToTalkKey
        case .edit: settings.editKey == settings.pushToTalkKey ? nil : settings.editKey
        }
    }

    mutating func handle(_ keyEvent: KeyEvent, settings: Settings) -> [RecordingTrigger] {
        RecordingPurpose.allCases.compactMap { purpose in
            guard let key = Self.key(for: purpose, in: settings), let event = key.event(for: keyEvent),
                  let action = handle(event, for: purpose, at: keyEvent.timestamp, settings: settings)
            else { return nil }

            return RecordingTrigger(purpose: purpose, key: key, action: action)
        }
    }

    mutating func handle(
        _ event: PushToTalk.Event,
        for purpose: RecordingPurpose,
        at time: TimeInterval,
        settings: Settings,
    ) -> PushToTalk.Action? {
        switch purpose {
        case .dictation:
            dictation.allowsHandsFree = settings.handsFreeDoubleTap

            return dictation.handle(event, at: time)

        case .edit:
            edit.allowsHandsFree = false

            return edit.handle(event, at: time)
        }
    }
}
