import AudioToolbox
import Foundation
import WaftCore

@MainActor
package final class SystemSoundPlayer: FeedbackSoundPlayer {
    private var soundIDs: [String: SystemSoundID] = [:]

    package init() {}

    package func play(_ sound: FeedbackSound) {
        let name = switch sound {
        case .recordingStarted: "Tink"
        case .recordingFinished: "Pop"
        }

        if let soundID = soundID(named: name) {
            AudioServicesPlaySystemSound(soundID)
        }
    }

    private func soundID(named name: String) -> SystemSoundID? {
        if let soundID = soundIDs[name] {
            return soundID
        }

        var soundID: SystemSoundID = 0
        let url = URL(filePath: "/System/Library/Sounds/\(name).aiff")
        guard AudioServicesCreateSystemSoundID(url as CFURL, &soundID) == kAudioServicesNoError else { return nil }

        soundIDs[name] = soundID

        return soundID
    }
}
